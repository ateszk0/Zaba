-- A payment event only counts for an attempt that is still open, and a
-- customer can read the delivery window of their own orders only.
begin;
select plan(13);

create function pg_temp.act_as(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  set local role authenticated;
end $$;

create function pg_temp.act_as_service() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  set local role service_role;
end $$;

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-00000000000a', 'a@example.test'),
  ('00000000-0000-4000-8000-00000000000b', 'b@example.test');

create temp table o (name text primary key, id uuid, slot uuid);
create temp table attempt (name text primary key, payment_id uuid);
grant all on o, attempt to authenticated, service_role;

select pg_temp.act_as('00000000-0000-4000-8000-00000000000a');
create temp table s as
  select slot_id, (row_number() over (order by starts_at))::integer as rn from public.get_delivery_slots();
grant all on s to authenticated, service_role;
insert into o (name, id, slot)
select t.n,
       (public.place_order('key-' || t.n, '[{"product_id":"carbonara","quantity":2}]', '1051', 'Váci utca 12.', s.slot_id) ->> 'id')::uuid,
       s.slot_id
  from unnest(array['right', 'stale', 'never', 'other']) with ordinality t (n, i)
  join s on s.rn = t.i;

-- --- payment matching ---------------------------------------------------------
insert into attempt
select n, (public.start_payment((select id from o where name = n)) ->> 'payment_id')::uuid
  from unnest(array['right', 'stale']) n;

reset role;
select pg_temp.act_as_service();

select is(
  public.apply_payment_event('fake', 'evt-wrong-id', (select id from o where name = 'right'), 'succeeded',
    jsonb_build_object('payment_id', gen_random_uuid())),
  '{"applied": false, "reason": "no_matching_payment"}'::jsonb,
  'an event that names another attempt is recorded but changes nothing'
);
reset role;
select is(
  (select row(status, payment_status)::text from public.orders where id = (select id from o where name = 'right')),
  row('pending_payment', 'pending')::text,
  'the order is still waiting for payment'
);

select pg_temp.act_as_service();
select is(
  public.apply_payment_event('fake', 'evt-right-id', (select id from o where name = 'right'), 'succeeded',
    jsonb_build_object('payment_id', (select payment_id from attempt where name = 'right'))),
  '{"applied": true}'::jsonb,
  'an event that names the open attempt is applied'
);
reset role;
select is(
  (select row(status, payment_status)::text from public.orders where id = (select id from o where name = 'right')),
  row('received', 'succeeded')::text,
  'and the order is paid'
);

-- A declined attempt is closed: a late "succeeded" for it must not pay the order.
select pg_temp.act_as_service();
select public.apply_payment_event('fake', 'evt-stale-1', (select id from o where name = 'stale'), 'failed',
  jsonb_build_object('payment_id', (select payment_id from attempt where name = 'stale')));
select is(
  public.apply_payment_event('fake', 'evt-stale-2', (select id from o where name = 'stale'), 'succeeded',
    jsonb_build_object('payment_id', (select payment_id from attempt where name = 'stale'))),
  '{"applied": false, "reason": "no_matching_payment"}'::jsonb,
  'a success for an attempt that already failed is ignored'
);
select is(
  public.apply_payment_event('fake', 'evt-stale-3', (select id from o where name = 'stale'), 'succeeded'),
  '{"applied": false, "reason": "no_matching_payment"}'::jsonb,
  'and so is one without an attempt named, when none is open'
);
reset role;
select is(
  (select row(status, payment_status)::text from public.orders where id = (select id from o where name = 'stale')),
  row('pending_payment', 'failed')::text,
  'the order stays unpaid'
);

-- An order that never started a payment cannot be paid by an event either.
select pg_temp.act_as_service();
select is(
  public.apply_payment_event('fake', 'evt-never', (select id from o where name = 'never'), 'succeeded'),
  '{"applied": false, "reason": "no_matching_payment"}'::jsonb,
  'an order without any payment attempt cannot be paid'
);
reset role;
select is(
  (select status::text from public.orders where id = (select id from o where name = 'never')),
  'pending_payment',
  'it stays waiting'
);

-- --- slot visibility ------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-00000000000a');
select is(
  (select count(*)::integer from public.delivery_slots),
  4,
  'a customer sees the slots of their own orders, and no others'
);
select is(
  (select count(*)::integer from public.delivery_slots where id = (select slot from o where name = 'right')),
  1,
  'including the window of a given order'
);
select throws_ok(
  $$select capacity from public.delivery_slots limit 1$$,
  '42501', null, 'but not the capacity'
);

reset role;
select pg_temp.act_as('00000000-0000-4000-8000-00000000000b');
select is(
  (select count(*)::integer from public.delivery_slots),
  0,
  'another customer sees none of them'
);

reset role;
select * from finish();
rollback;
