-- The functions that create and change orders and payments. They are the only
-- way to write that data. Every error is a short code as the message.

create function private.require_user()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  return v_uid;
end;
$$;

-- Moves an order to a new status if the state machine allows it for this
-- actor, and records the move. The one place where order status changes.
-- Cancelling also gives the delivery slot back and, for a paid order, marks
-- the payment as refunded (in the demo immediately; the MVP asks the payment
-- provider for the refund).
--
-- The order row is updated exactly once, status and payment status together:
-- anybody following the order live (Realtime) then never sees a half-done
-- state such as "paid, but still waiting for payment".
create function private.transition_order(
  p_order_id uuid,
  p_to public.order_status,
  p_actor text,
  p_actor_id uuid default null,
  p_payment_status public.payment_status default null
)
returns public.orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_from public.order_status;
  v_payment public.payment_status;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'order_not_found';
  end if;
  v_from := v_order.status;

  if not exists (
    select 1
      from public.order_status_transitions t
     where t.from_status = v_from
       and t.to_status = p_to
       and p_actor = any (t.allowed_actors)
  ) then
    raise exception 'invalid_transition' using detail = format('%s -> %s by %s', v_from, p_to, p_actor);
  end if;

  -- A paid order that is cancelled is refunded.
  v_payment := case
    when p_to = 'cancelled' and v_order.payment_status = 'succeeded' then 'refunded'::public.payment_status
    else coalesce(p_payment_status, v_order.payment_status)
  end;

  update public.orders
     set status = p_to, payment_status = v_payment
   where id = p_order_id
   returning * into v_order;

  insert into public.order_status_history (order_id, from_status, to_status, actor, actor_id)
  values (p_order_id, v_from, p_to, p_actor, p_actor_id);

  if p_to = 'out_for_delivery' then
    insert into public.deliveries (order_id, dispatched_at) values (p_order_id, now())
    on conflict (order_id) do update set dispatched_at = excluded.dispatched_at;
  elsif p_to = 'delivered' then
    update public.deliveries set delivered_at = now() where order_id = p_order_id;
  elsif p_to = 'cancelled' then
    update public.delivery_slots set booked = greatest(booked - 1, 0) where id = v_order.slot_id;
    if v_payment = 'refunded' then
      update public.payments set status = 'refunded' where order_id = p_order_id and status = 'succeeded';
    end if;
  end if;

  return v_order;
end;
$$;

-- Places an order for the signed-in customer. Prices the cart again on the
-- server (the client's numbers are never trusted), checks the delivery area,
-- the minimum order value and the slot, and creates the order waiting for
-- payment. Idempotent: the same key returns the same order.
create function public.place_order(
  p_idempotency_key text,
  p_lines jsonb,
  p_postal_code text,
  p_street text,
  p_slot_id uuid,
  p_note text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_existing public.orders;
  v_quote jsonb;
  v_slot public.delivery_slots;
  v_order public.orders;
begin
  if p_idempotency_key is null or length(btrim(p_idempotency_key)) = 0 or length(p_idempotency_key) > 100
     or p_street is null or length(btrim(p_street)) = 0 or length(p_street) > 200
     or p_postal_code is null or p_postal_code !~ '^[0-9]{4}$'
     or length(coalesce(p_note, '')) > 500 then
    raise exception 'invalid_request';
  end if;

  -- Two requests with the same key (a double tap) wait for each other, so the
  -- second one finds the order of the first.
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':' || p_idempotency_key, 0));

  select * into v_existing
    from public.orders
   where user_id = v_uid and idempotency_key = p_idempotency_key;
  if found then
    return jsonb_build_object('id', v_existing.id, 'number', v_existing.number, 'replayed', true);
  end if;

  v_quote := private.compute_quote(p_lines, p_postal_code);
  if jsonb_array_length(v_quote -> 'lines') = 0 then
    raise exception 'empty_cart';
  end if;
  if (v_quote ->> 'subtotal_huf')::integer < (v_quote ->> 'min_order_huf')::integer then
    raise exception 'below_minimum_order';
  end if;

  -- The slot must be bookable by the same rule that lists the slots (opening
  -- hours, lead time, window, capacity). Then lock it and check once more,
  -- because another order may have taken the last place meanwhile.
  perform 1 from private.generate_delivery_slots(now()) g where g.id = p_slot_id;
  if not found then
    raise exception 'slot_unavailable';
  end if;
  select * into v_slot from public.delivery_slots where id = p_slot_id for update;
  if v_slot.booked >= v_slot.capacity then
    raise exception 'slot_unavailable';
  end if;
  update public.delivery_slots set booked = booked + 1 where id = v_slot.id;

  insert into public.orders (
    user_id, zone_id, slot_id, delivery_postal_code, delivery_street, note,
    subtotal_huf, delivery_fee_huf, idempotency_key
  )
  values (
    v_uid, v_quote ->> 'zone_id', v_slot.id, p_postal_code, btrim(p_street), btrim(coalesce(p_note, '')),
    (v_quote ->> 'subtotal_huf')::integer, (v_quote ->> 'delivery_fee_huf')::integer, p_idempotency_key
  )
  returning * into v_order;

  insert into public.order_items (order_id, product_id, name, quantity, unit_price_huf, vat_rate_percent)
  select
    v_order.id,
    l.value ->> 'product_id',
    l.value ->> 'name',
    (l.value ->> 'quantity')::integer,
    (l.value ->> 'unit_price_huf')::integer,
    (l.value ->> 'vat_rate_percent')::smallint
  from jsonb_array_elements(v_quote -> 'lines') l;

  insert into public.order_status_history (order_id, from_status, to_status, actor, actor_id)
  values (v_order.id, null, 'pending_payment', 'customer', v_uid);

  return jsonb_build_object('id', v_order.id, 'number', v_order.number, 'replayed', false);
end;
$$;

-- The customer cancels their own order (while the state machine allows it).
create function public.cancel_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_owner uuid;
begin
  select user_id into v_owner from public.orders where id = p_order_id;
  -- The same answer for "not yours" and "does not exist".
  if v_owner is distinct from v_uid then
    raise exception 'order_not_found';
  end if;
  perform private.transition_order(p_order_id, 'cancelled', 'customer', v_uid);
end;
$$;

-- Returns the payment attempt to pay now: the open one, or a new one after a
-- failed or abandoned attempt.
create function public.start_payment(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_order public.orders;
  v_payment public.payments;
begin
  select * into v_order from public.orders where id = p_order_id and user_id = v_uid for update;
  if not found then
    raise exception 'order_not_found';
  end if;
  if v_order.status <> 'pending_payment' then
    raise exception 'order_not_payable';
  end if;

  select * into v_payment
    from public.payments
   where order_id = p_order_id and status = 'pending'
   order by created_at desc
   limit 1;
  if not found then
    insert into public.payments (order_id, amount_huf)
    values (p_order_id, v_order.total_huf)
    returning * into v_payment;
    -- Only when it really changes: every write to the order is a live event.
    update public.orders set payment_status = 'pending' where id = p_order_id and payment_status <> 'pending';
  end if;

  return jsonb_build_object(
    'payment_id', v_payment.id,
    'amount_huf', v_payment.amount_huf,
    'currency', v_payment.currency,
    'provider', v_payment.provider
  );
end;
$$;

-- What the payment provider reported. The ONLY thing that can make an order
-- paid. Called by the webhook handler (service role), never by a customer.
-- Idempotent: an event id that was seen before changes nothing.
create function public.apply_payment_event(
  p_provider text,
  p_event_id text,
  p_order_id uuid,
  p_type text,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_recorded bigint;
  v_order public.orders;
  v_payment_id uuid;
begin
  if p_type not in ('succeeded', 'failed', 'cancelled') then
    raise exception 'invalid_event';
  end if;

  insert into public.payment_events (provider, provider_event_id, order_id, event_type, payload)
  values (p_provider, p_event_id, p_order_id, p_type, coalesce(p_payload, '{}'::jsonb))
  on conflict (provider, provider_event_id) do nothing
  returning id into v_recorded;
  if v_recorded is null then
    return jsonb_build_object('applied', false, 'reason', 'duplicate');
  end if;

  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    return jsonb_build_object('applied', false, 'reason', 'unknown_order');
  end if;
  -- Events only matter while the order waits for payment. A success for an
  -- order that was cancelled meanwhile would need a refund; that comes with
  -- the real payment provider.
  if v_order.status <> 'pending_payment' then
    return jsonb_build_object('applied', false, 'reason', 'order_not_pending');
  end if;

  select id into v_payment_id
    from public.payments
   where order_id = p_order_id and status = 'pending'
   order by created_at desc
   limit 1;

  if p_type = 'succeeded' then
    update public.payments set status = 'succeeded' where id = v_payment_id;
    perform private.transition_order(p_order_id, 'received', 'payment', null, 'succeeded');
  elsif p_type = 'failed' then
    update public.payments set status = 'failed' where id = v_payment_id;
    update public.orders set payment_status = 'failed' where id = p_order_id;
  else
    update public.payments set status = 'cancelled' where id = v_payment_id;
    update public.orders set payment_status = 'cancelled' where id = p_order_id;
  end if;

  return jsonb_build_object('applied', true);
end;
$$;

-- An operator moves an order along. Allowed for any staff member (admin and
-- operator); the state machine decides which moves are valid. Audited.
create function public.admin_set_order_status(p_order_id uuid, p_status public.order_status)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_before public.order_status;
begin
  if not private.is_staff() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select status into v_before from public.orders where id = p_order_id;
  if not found then
    raise exception 'order_not_found';
  end if;

  perform private.transition_order(p_order_id, p_status, 'operator', v_uid);

  insert into public.audit_log (actor_id, action, entity, entity_id, details)
  values (
    v_uid, 'order.set_status', 'orders', p_order_id::text,
    jsonb_build_object('from', v_before, 'to', p_status)
  );
end;
$$;
