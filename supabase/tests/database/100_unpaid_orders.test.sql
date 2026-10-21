-- Unpaid orders: the per-customer limit and the expiry that gives the places back.
--
-- Written to hold on any database state (its own customer, relative numbers), not only on a
-- freshly seeded one.
begin;
select plan(17);

create function pg_temp.act_as(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  set local role authenticated;
end $$;

insert into auth.users (id, email) values ('00000000-0000-4000-8000-0000000000e1', 'expiry@example.test');

create temp table fixture (slot_id uuid, booked_before integer, cancelled_order uuid);
grant all on fixture to authenticated, service_role;

-- The slot with the most free places, so five orders fit even where other data took some.
select pg_temp.act_as('00000000-0000-4000-8000-0000000000e1');
insert into fixture (slot_id)
  select slot_id from public.get_delivery_slots() order by remaining desc, starts_at limit 1;
reset role;
update fixture set booked_before = (select booked from public.delivery_slots where id = fixture.slot_id);

-- --- the limit -------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-0000000000e1');

select is(
  (select count(*)::integer from (
     select public.place_order('limit-' || g, '[{"product_id":"carbonara","quantity":2}]', '1051', 'Váci utca 12.',
                               (select slot_id from fixture)) from generate_series(1, 5) g) placed),
  5,
  'a customer can have five orders waiting for payment'
);
select throws_ok(
  $$select public.place_order('limit-6', '[{"product_id":"carbonara","quantity":2}]', '1051', 'Váci utca 12.', (select slot_id from fixture))$$,
  'P0001', 'too_many_unpaid_orders',
  'the sixth one is refused'
);
select is(
  (public.place_order('limit-1', '[{"product_id":"carbonara","quantity":2}]', '1051', 'Váci utca 12.', (select slot_id from fixture)) ->> 'replayed'),
  'true',
  'a repeated request still gets its order at the limit'
);

-- --- who may expire ----------------------------------------------------------
select throws_ok(
  $$select public.expire_unpaid_orders()$$, '42501', null,
  'a customer cannot expire orders'
);

reset role;
set local role service_role;
select lives_ok($$select public.expire_unpaid_orders()$$, 'the service role can expire orders');
select throws_ok(
  $$select public.expire_unpaid_orders(interval '1 minute')$$, 'P0001', 'invalid_request',
  'a limit shorter than five minutes is refused (a typo must not cancel orders being paid)'
);
reset role;

select is(
  (select count(*)::integer from public.orders
    where user_id = '00000000-0000-4000-8000-0000000000e1' and status = 'pending_payment'),
  5,
  'orders that are not old are not expired'
);

-- --- the expiry --------------------------------------------------------------
-- The customer's orders are two hours old now, and one of them was paid meanwhile.
update public.orders set created_at = now() - interval '2 hours'
 where user_id = '00000000-0000-4000-8000-0000000000e1';
update public.orders set status = 'received', payment_status = 'succeeded'
 where id = (select id from public.orders
              where user_id = '00000000-0000-4000-8000-0000000000e1' order by number limit 1);

set local role service_role;
select lives_ok($$select public.expire_unpaid_orders()$$, 'expiring the old orders works');
reset role;

select is(
  (select count(*)::integer from public.orders
    where user_id = '00000000-0000-4000-8000-0000000000e1' and status = 'cancelled'),
  4,
  'the four unpaid old orders are cancelled'
);
select is(
  (select count(*)::integer from public.orders
    where user_id = '00000000-0000-4000-8000-0000000000e1' and status = 'received' and payment_status = 'succeeded'),
  1,
  'the paid order is not touched, however old'
);
select is(
  (select count(*)::integer from public.orders
    where user_id = '00000000-0000-4000-8000-0000000000e1' and status = 'cancelled' and payment_status = 'cancelled'),
  4,
  'the cancelled orders show that their payment was abandoned'
);
select is(
  (select count(*)::integer from public.order_status_history h
     join public.orders o on o.id = h.order_id
    where o.user_id = '00000000-0000-4000-8000-0000000000e1' and h.to_status = 'cancelled' and h.actor = 'payment'),
  4,
  'the history says the payment side ended them'
);
select is(
  (select booked from public.delivery_slots where id = (select slot_id from fixture)),
  (select booked_before + 1 from fixture),
  'the four places are free again in the slot (only the paid order keeps one)'
);
select ok(
  exists (select 1 from public.audit_log
           where action = 'orders.expire_unpaid' and (details ->> 'count')::integer >= 4),
  'the expiry is written to the audit log'
);

-- --- after the expiry --------------------------------------------------------
update fixture set cancelled_order = (
  select id from public.orders
   where user_id = '00000000-0000-4000-8000-0000000000e1' and status = 'cancelled' order by number limit 1);

set local role service_role;
select is(
  (public.apply_payment_event('fake', 'evt-after-expiry', (select cancelled_order from fixture), 'succeeded', '{}'::jsonb) ->> 'reason'),
  'order_not_pending',
  'a success event that arrives after the expiry changes nothing'
);
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-0000000000e1');
select is(
  (public.place_order('again-1', '[{"product_id":"carbonara","quantity":2}]', '1051', 'Váci utca 12.', (select slot_id from fixture)) ->> 'replayed'),
  'false',
  'the customer can order again, the limit counts only orders still waiting'
);
reset role;

set local role service_role;
do $$ begin perform public.expire_unpaid_orders(); end $$;
reset role;
select is(
  (select status::text from public.orders
    where user_id = '00000000-0000-4000-8000-0000000000e1' and idempotency_key = 'again-1'),
  'pending_payment',
  'a fresh order survives the next expiry run'
);

select * from finish();
rollback;
