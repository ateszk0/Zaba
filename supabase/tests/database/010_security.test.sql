-- Security: what each role may and may not do. Run with `supabase test db`.
begin;
select plan(20);

create function pg_temp.act_as(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  set local role authenticated;
end $$;

create function pg_temp.act_as_anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  set local role anon;
end $$;

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-00000000000a', 'a@example.test'),
  ('00000000-0000-4000-8000-00000000000b', 'b@example.test');

-- --- structure -------------------------------------------------------------
select is(
  (select count(*)::integer
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  0,
  'every table in public has row level security enabled'
);

select is(
  (select count(*)::integer from public.profiles where id = '00000000-0000-4000-8000-00000000000a'),
  1,
  'a new account automatically gets a profile'
);

-- --- anonymous visitors ----------------------------------------------------
select pg_temp.act_as_anon();

select is((select count(*)::integer from public.catalog_products), 45, 'anon can read the menu');
select is((select count(*)::integer from public.delivery_zones), 2, 'anon can read the delivery zones');
select throws_ok($$select * from public.orders$$, '42501', null, 'anon cannot read orders');
select throws_ok($$select * from public.profiles$$, '42501', null, 'anon cannot read profiles');
select throws_ok(
  $$insert into public.products (id, category_id, name) values ('x', 'pasta', 'x')$$,
  '42501', null, 'anon cannot write products'
);
select throws_ok(
  $$select public.place_order('k', '[]'::jsonb, '1051', 'x', gen_random_uuid())$$,
  '42501', null, 'anon cannot place an order'
);
select throws_ok(
  $$select public.get_delivery_slots()$$,
  '42501', null, 'anon cannot list delivery slots'
);

-- --- a signed-in customer ---------------------------------------------------
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-00000000000a');

select throws_ok(
  $$insert into public.orders (user_id, slot_id, delivery_postal_code, delivery_street, subtotal_huf, delivery_fee_huf, idempotency_key)
    values (auth.uid(), gen_random_uuid(), '1051', 'x', 1, 1, 'k')$$,
  '42501', null, 'a customer cannot insert an order directly'
);
select throws_ok(
  $$update public.orders set status = 'delivered'$$,
  '42501', null, 'a customer cannot update an order directly'
);
select throws_ok(
  $$insert into public.order_status_history (order_id, to_status, actor) values (gen_random_uuid(), 'delivered', 'customer')$$,
  '42501', null, 'a customer cannot write the status history'
);
select throws_ok(
  $$select public.apply_payment_event('fake', 'e1', gen_random_uuid(), 'succeeded')$$,
  '42501', null, 'a customer cannot report a payment event'
);
select throws_ok(
  $$select private.transition_order(gen_random_uuid(), 'received', 'payment')$$,
  '42501', null, 'a customer cannot call the internal state machine'
);
select throws_ok($$select * from public.payment_events$$, '42501', null, 'a customer cannot read payment events');
select throws_ok($$select * from public.delivery_slots$$, '42501', null, 'a customer cannot read the slot table directly');

-- Profiles and addresses are private to their owner.
select is(
  (select count(*)::integer from public.profiles),
  1,
  'a customer sees only their own profile'
);
insert into public.addresses (postal_code, street) values ('1051', 'Váci utca 12.');
select is(
  (select count(*)::integer from public.addresses where user_id = auth.uid()),
  1,
  'a customer can save an address (the owner is filled in automatically)'
);

reset role;
select pg_temp.act_as('00000000-0000-4000-8000-00000000000b');

select is((select count(*)::integer from public.addresses), 0, 'another customer does not see that address');
select throws_ok(
  $$insert into public.addresses (user_id, postal_code, street)
    values ('00000000-0000-4000-8000-00000000000a', '1051', 'x')$$,
  '42501', null, 'a customer cannot save an address for somebody else'
);

select * from finish();
rollback;
