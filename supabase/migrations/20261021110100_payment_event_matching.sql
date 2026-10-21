-- A payment event must belong to a payment attempt that is still open.
--
-- Before, a success event for an order whose attempt was already closed (a
-- declined card, then a stale "succeeded" event) found no open attempt, updated
-- nothing, and still marked the order as paid. Now the event is recorded (so it
-- is not processed twice) but changes nothing unless it matches an attempt that
-- is waiting for its result. When the event names the attempt (`payment_id` in
-- the payload, as the payment webhook always does), that attempt is the one it
-- must match.

create or replace function public.apply_payment_event(
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
   where order_id = p_order_id
     and status = 'pending'
     and (coalesce(p_payload, '{}'::jsonb) ->> 'payment_id' is null
          or id::text = p_payload ->> 'payment_id')
   order by created_at desc
   limit 1;
  if v_payment_id is null then
    return jsonb_build_object('applied', false, 'reason', 'no_matching_payment');
  end if;

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
