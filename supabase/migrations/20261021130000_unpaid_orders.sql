-- Unpaid orders must not hold delivery slots for ever.
--
-- `place_order` takes a place in the slot when the order is created, before it is paid.
-- Nothing gave that place back when the customer walked away, so anybody with an account
-- (sign-up is open, and confirmed on the spot in the demo) could take every place of every
-- slot with orders that are never paid, and real customers would find nothing to book.
--
-- Two measures:
--   1. A customer can have at most five orders waiting for payment; `place_order` refuses
--      the sixth with `too_many_unpaid_orders`.
--   2. `expire_unpaid_orders()` cancels the orders that waited longer than a limit and gives
--      their places back. The service role calls it on a schedule (docs/real-life-plan.md).

-- The payment side may end an order that is still waiting for its payment: the time for
-- paying has run out. It shows in the history as "payment", not as the kitchen's decision.
update public.order_status_transitions
   set allowed_actors = array['customer', 'operator', 'payment']
 where from_status = 'pending_payment' and to_status = 'cancelled';

-- Cancels every order that has waited for payment for longer than [p_older_than], closes its
-- open payment attempts and returns how many orders it ended. Orders that are being paid at
-- this very moment (their row is locked by the webhook) are skipped and caught next time.
create function public.expire_unpaid_orders(p_older_than interval default interval '30 minutes')
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_count integer := 0;
begin
  -- A typo (seconds instead of minutes) must not cancel orders that are being paid now.
  if p_older_than is null or p_older_than < interval '5 minutes' then
    raise exception 'invalid_request';
  end if;

  for v_id in
    select o.id
      from public.orders o
     where o.status = 'pending_payment'
       and o.created_at < now() - p_older_than
     order by o.created_at
       for update skip locked
  loop
    update public.payments set status = 'cancelled' where order_id = v_id and status = 'pending';
    perform private.transition_order(v_id, 'cancelled', 'payment', null, 'cancelled');
    v_count := v_count + 1;
  end loop;

  if v_count > 0 then
    insert into public.audit_log (actor_id, action, entity, details)
    values (null, 'orders.expire_unpaid', 'orders',
            jsonb_build_object('count', v_count, 'older_than', p_older_than::text));
  end if;
  return v_count;
end;
$$;

-- PostgreSQL gives every new function to PUBLIC (everybody, guests included), and the
-- "default privileges" of 20261021090700 cannot take that away: only an explicit revoke can.
-- Every function added to this project from now on needs these two lines.
revoke all on function public.expire_unpaid_orders(interval) from public, anon, authenticated;
grant execute on function public.expire_unpaid_orders(interval) to service_role;

-- `place_order`, unchanged except for the check that a customer does not have too many orders
-- waiting for payment (after the idempotency replay, so a repeated request still gets its order).
create or replace function public.place_order(
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

  -- Places in a slot are taken before payment, so unpaid orders are limited per customer.
  if (select count(*) from public.orders o where o.user_id = v_uid and o.status = 'pending_payment') >= 5 then
    raise exception 'too_many_unpaid_orders';
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
