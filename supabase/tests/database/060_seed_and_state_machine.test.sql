-- The seed data and the order state machine table.
begin;
select plan(13);

select is((select count(*)::integer from public.categories), 7, '7 menu categories');
select is((select count(*)::integer from public.products), 45, '45 products');
select is(
  (select count(*)::integer
     from public.products p
    where (select count(*) from public.product_prices pr where pr.product_id = p.id and pr.valid_to is null) <> 1),
  0,
  'every product has exactly one current price'
);
select is(
  (select count(*)::integer from public.product_prices where amount_huf <= 0),
  0,
  'every price is positive whole forints'
);
select is((select count(*)::integer from public.catalog_products), 45, 'the menu view lists every active product');
select is(
  (select count(*)::integer from public.products where image_path ~ '^[a-z0-9-]+\.webp$'),
  41,
  '41 products have a photo; the other 4 show the tile'
);

select is(
  (select zone_id from public.delivery_zone_prefixes where prefix = '105'),
  'inner', 'district V is in the inner zone'
);
select is(
  (select zone_id from public.delivery_zone_prefixes where prefix = '104'),
  'outer', 'district IV is in the outer zone'
);
select is(
  (select id from public.delivery_zones where is_estimate_default),
  'inner', 'the inner zone is the default for estimates'
);
select is(
  (select string_agg(weekday || ' ' || opens_at || '-' || closes_at, ', ' order by weekday) from public.opening_hours),
  '1 11:00:00-21:00:00, 2 11:00:00-21:00:00, 3 11:00:00-21:00:00, 4 11:00:00-21:00:00, '
  '5 11:00:00-21:00:00, 6 11:00:00-21:00:00, 7 11:00:00-20:00:00',
  'open every day from 11:00, Sunday until 20:00, the other days until 21:00'
);
select is(
  (select row(timezone, lead_time_minutes, days_ahead, slot_minutes, slot_capacity)::text from public.delivery_settings),
  row('Europe/Budapest', 45, 3, 60, 10)::text,
  'the delivery settings'
);

-- The state machine: the whole table, in one place. If this test changes, the
-- rules of the business changed.
select is(
  (select string_agg(from_status || ' > ' || to_status || ' by ' || array_to_string(allowed_actors, '+'), E'\n'
                     order by from_status, to_status)
     from public.order_status_transitions),
  concat_ws(
    E'\n',
    'pending_payment > received by payment',
    'pending_payment > cancelled by customer+operator+payment',
    'received > preparing by operator',
    'received > cancelled by customer+operator',
    'preparing > out_for_delivery by operator',
    'preparing > cancelled by operator',
    'out_for_delivery > delivered by operator'
  ),
  'the order state machine'
);
select is(
  (select count(*)::integer from public.order_status_transitions where from_status in ('delivered', 'cancelled')),
  0,
  'delivered and cancelled are final: nothing leaves them'
);

select * from finish();
rollback;
