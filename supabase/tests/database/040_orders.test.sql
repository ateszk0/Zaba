-- Placing and cancelling orders as a customer.
begin;
select plan(24);

create function pg_temp.act_as(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  set local role authenticated;
end $$;

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-00000000000a', 'a@example.test'),
  ('00000000-0000-4000-8000-00000000000b', 'b@example.test');

-- Two carbonaras, a lemonade and a cola: 5 580 + 790 + 590 = 6 960 Ft.
create temp table fixture (order_id uuid, slot_id uuid, full_slot uuid);
grant all on fixture to authenticated;

-- --- placing ---------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-00000000000a');

insert into fixture (slot_id) select slot_id from public.get_delivery_slots() order by starts_at limit 1;

select matches(
  (public.place_order(
     'key-1',
     '[{"product_id":"carbonara","quantity":2},{"product_id":"lemonade","quantity":1},{"product_id":"cola","quantity":1}]',
     '1051', '  Váci utca 12.  ', (select slot_id from fixture), '  csengő nem működik  ') ->> 'number'),
  '^ZB-\d+$',
  'an order is created and gets a ZB number'
);

update fixture set order_id = (select id from public.orders limit 1);

select is(
  (select row(status, payment_status, subtotal_huf, delivery_fee_huf, total_huf,
              delivery_postal_code, delivery_street, note)::text
     from public.orders where id = (select order_id from fixture)),
  row('pending_payment', 'pending', 6960, 990, 7950, '1051', 'Váci utca 12.', 'csengő nem működik')::text,
  'the order waits for payment, is priced by the server and trimmed'
);
select is(
  (select jsonb_agg(row_to_json(i) order by i.product_id)
     from (select product_id, name, quantity, unit_price_huf, vat_rate_percent, line_total_huf
             from public.order_items where order_id = (select order_id from fixture)) i),
  '[{"product_id":"carbonara","name":"Spagetti carbonara","quantity":2,"unit_price_huf":2790,"vat_rate_percent":27,"line_total_huf":5580},
    {"product_id":"cola","name":"Kóla 0,33 l","quantity":1,"unit_price_huf":590,"vat_rate_percent":27,"line_total_huf":590},
    {"product_id":"lemonade","name":"Házi limonádé 0,4 l","quantity":1,"unit_price_huf":790,"vat_rate_percent":27,"line_total_huf":790}]'::jsonb,
  'the lines are a snapshot of name, price and VAT rate'
);
select is(
  (select count(*)::integer from public.order_status_history
    where order_id = (select order_id from fixture) and from_status is null and to_status = 'pending_payment'),
  1,
  'the status history starts with pending_payment'
);

reset role;
select is(
  (select booked from public.delivery_slots where id = (select slot_id from fixture)),
  1,
  'the order takes one place in the slot'
);

-- --- idempotency -----------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-00000000000a');

select is(
  (public.place_order('key-1', '[{"product_id":"carbonara","quantity":2}]', '1051', 'x', (select slot_id from fixture)) ->> 'replayed'),
  'true',
  'the same idempotency key is recognised as a replay'
);
select is(
  (public.place_order('key-1', '[{"product_id":"carbonara","quantity":2}]', '1051', 'x', (select slot_id from fixture)) ->> 'id')::uuid,
  (select order_id from fixture),
  'and returns the original order'
);
select is((select count(*)::integer from public.orders), 1, 'no second order was created');
reset role;
select is(
  (select booked from public.delivery_slots where id = (select slot_id from fixture)),
  1,
  'and the slot was not charged twice'
);

-- --- rejections ------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-00000000000a');

select throws_ok(
  $$select public.place_order('k-empty', '[{"product_id":"ghost","quantity":1}]', '1051', 'x', (select slot_id from fixture))$$,
  'P0001', 'empty_cart', 'a cart with nothing orderable is rejected'
);
select throws_ok(
  $$select public.place_order('k-area', '[{"product_id":"carbonara","quantity":2}]', '1181', 'x', (select slot_id from fixture))$$,
  'P0001', 'out_of_delivery_area', 'an address outside the delivery area is rejected'
);
select throws_ok(
  $$select public.place_order('k-min', '[{"product_id":"lemonade","quantity":1}]', '1051', 'x', (select slot_id from fixture))$$,
  'P0001', 'below_minimum_order', 'an order below the minimum value is rejected'
);
select throws_ok(
  $$select public.place_order('k-slot', '[{"product_id":"carbonara","quantity":2}]', '1051', 'x', gen_random_uuid())$$,
  'P0001', 'slot_unavailable', 'an unknown slot is rejected'
);
select throws_ok(
  $$select public.place_order('k-street', '[{"product_id":"carbonara","quantity":2}]', '1051', '   ', (select slot_id from fixture))$$,
  'P0001', 'invalid_request', 'an empty street is rejected'
);
select throws_ok(
  $$select public.place_order('k-zip', '[{"product_id":"carbonara","quantity":2}]', '12', 'x', (select slot_id from fixture))$$,
  'P0001', 'invalid_request', 'a malformed postal code is rejected'
);

reset role;
-- A slot in the past, and a real, bookable-looking slot that is full.
insert into public.delivery_slots (id, starts_at, ends_at, capacity, booked) values
  ('00000000-0000-4000-8000-0000000000e1', now() - interval '2 hours', now() - interval '1 hour', 10, 0);
update fixture set full_slot = (select id from private.generate_delivery_slots(now()) order by starts_at offset 1 limit 1);
update public.delivery_slots set booked = capacity where id = (select full_slot from fixture);

select pg_temp.act_as('00000000-0000-4000-8000-00000000000a');
select throws_ok(
  $$select public.place_order('k-past', '[{"product_id":"carbonara","quantity":2}]', '1051', 'x', '00000000-0000-4000-8000-0000000000e1')$$,
  'P0001', 'slot_unavailable', 'a slot in the past is rejected'
);
select throws_ok(
  $$select public.place_order('k-full', '[{"product_id":"carbonara","quantity":2}]', '1051', 'x', (select full_slot from fixture))$$,
  'P0001', 'slot_unavailable', 'a full slot is rejected'
);

select is((select count(*)::integer from public.orders), 1, 'none of the rejected requests left an order behind');

-- --- other customers -------------------------------------------------------
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-00000000000b');

select is((select count(*)::integer from public.orders), 0, 'another customer cannot see the order');
select is((select count(*)::integer from public.order_items), 0, 'nor its lines');
select throws_ok(
  $$select public.cancel_order((select order_id from fixture))$$,
  'P0001', 'order_not_found', 'nor cancel it'
);

-- --- cancelling ------------------------------------------------------------
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-00000000000a');

select lives_ok(
  $$select public.cancel_order((select order_id from fixture))$$,
  'the customer can cancel an order that is still unpaid'
);
reset role;
select is(
  (select row(o.status, s.booked)::text
     from public.orders o join public.delivery_slots s on s.id = o.slot_id
    where o.id = (select order_id from fixture)),
  row('cancelled', 0)::text,
  'it is cancelled and its place in the slot is free again'
);
select pg_temp.act_as('00000000-0000-4000-8000-00000000000a');
select throws_ok(
  $$select public.cancel_order((select order_id from fixture))$$,
  'P0001', 'invalid_transition', 'a cancelled order cannot be cancelled again'
);

select * from finish();
rollback;
