-- Pricing: VAT rounding, the cart quote, delivery fees and input validation.
begin;
select plan(27);

create function pg_temp.act_as_anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  set local role anon;
end $$;

-- --- VAT -------------------------------------------------------------------
select is(private.vat_from_gross(1290, 27::smallint), 274, 'VAT in 1 290 Ft at 27 %: 274.25 rounds to 274');
select is(private.vat_from_gross(1000, 27::smallint), 213, 'VAT in 1 000 Ft at 27 %: 212.6 rounds to 213');
select is(private.vat_from_gross(1590, 5::smallint), 76, 'VAT in 1 590 Ft at 5 %: 75.7 rounds to 76');
select is(private.vat_from_gross(990, 5::smallint), 47, 'VAT in 990 Ft at 5 %: 47.1 rounds to 47');
select is(private.vat_from_gross(0, 27::smallint), 0, 'no VAT in zero');
select is(private.vat_from_gross(1000, 0::smallint), 0, 'no VAT at 0 %');

-- --- the quote -------------------------------------------------------------
select is(
  public.quote_cart('[{"product_id":"carbonara","quantity":2}]', '1051'),
  jsonb_build_object(
    'lines', jsonb_build_array(jsonb_build_object(
      'product_id', 'carbonara', 'name', 'Spagetti carbonara', 'quantity', 2,
      'unit_price_huf', 2790, 'vat_rate_percent', 27, 'line_total_huf', 5580)),
    'subtotal_huf', 5580, 'delivery_fee_huf', 990, 'total_huf', 6570,
    'min_order_huf', 3500, 'free_delivery_from_huf', 15000, 'zone_id', 'inner', 'estimated', false
  ),
  'two carbonaras to district V: 5 580 + 990 delivery = 6 570 Ft'
);

select is(
  (public.quote_cart('[{"product_id":"carbonara","quantity":5}]', '1051') ->> 'delivery_fee_huf')::integer,
  990, 'below the free-delivery threshold the fee applies'
);
select is(
  (public.quote_cart('[{"product_id":"carbonara","quantity":6}]', '1051') ->> 'delivery_fee_huf')::integer,
  0, 'from 15 000 Ft the inner zone delivers free'
);
select is(
  (public.quote_cart('[{"product_id":"carbonara","quantity":10}]', '1041') ->> 'delivery_fee_huf')::integer,
  1490, 'the outer zone never delivers free and charges 1 490 Ft'
);
select is(
  (public.quote_cart('[{"product_id":"carbonara","quantity":1}]', '1041') ->> 'min_order_huf')::integer,
  5000, 'the outer zone has a 5 000 Ft minimum order'
);
select is(
  public.quote_cart('[{"product_id":"carbonara","quantity":1}]') ->> 'estimated',
  'true', 'without an address the quote is an estimate'
);
select is(
  public.quote_cart('[{"product_id":"carbonara","quantity":1}]') ->> 'zone_id',
  'inner', 'the estimate uses the default zone'
);
select is(
  public.quote_cart('[]', '1051') -> 'delivery_fee_huf',
  '0'::jsonb, 'an empty cart has no delivery fee'
);

-- The same product twice is one line; unknown products are left out.
select is(
  public.quote_cart('[{"product_id":"carbonara","quantity":1},{"product_id":"carbonara","quantity":2},{"product_id":"ghost","quantity":4}]', '1051') -> 'lines',
  jsonb_build_array(jsonb_build_object(
    'product_id', 'carbonara', 'name', 'Spagetti carbonara', 'quantity', 3,
    'unit_price_huf', 2790, 'vat_rate_percent', 27, 'line_total_huf', 8370)),
  'duplicate lines are merged and unknown products ignored'
);

update public.products set is_active = false where id = 'carbonara';
select is(
  jsonb_array_length(public.quote_cart('[{"product_id":"carbonara","quantity":1}]', '1051') -> 'lines'),
  0, 'an inactive product cannot be priced'
);
update public.products set is_active = true where id = 'carbonara';

-- --- validation ------------------------------------------------------------
select throws_ok($$select public.quote_cart('[{"product_id":"carbonara","quantity":1}]', '1181')$$,
  'P0001', 'out_of_delivery_area', 'a postal code outside the zones is rejected');
select throws_ok($$select public.quote_cart('[{"product_id":"carbonara","quantity":1}]', '9999')$$,
  'P0001', 'out_of_delivery_area', 'a non-Budapest postal code is rejected');
select throws_ok($$select public.quote_cart('[{"product_id":"carbonara","quantity":1}]', 'abcd')$$,
  'P0001', 'out_of_delivery_area', 'a malformed postal code is rejected');
select throws_ok($$select public.quote_cart('{"product_id":"carbonara","quantity":1}', '1051')$$,
  'P0001', 'invalid_lines', 'the cart must be an array');
select throws_ok($$select public.quote_cart('[{"product_id":"carbonara","quantity":0}]', '1051')$$,
  'P0001', 'invalid_lines', 'a quantity of zero is rejected');
select throws_ok($$select public.quote_cart('[{"product_id":"carbonara","quantity":100}]', '1051')$$,
  'P0001', 'invalid_lines', 'a quantity above 99 is rejected');
select throws_ok($$select public.quote_cart('[{"product_id":"carbonara","quantity":60},{"product_id":"carbonara","quantity":60}]', '1051')$$,
  'P0001', 'invalid_lines', 'merged quantities above 99 are rejected');
select throws_ok($$select public.quote_cart('[{"product_id":"carbonara","quantity":"x"}]', '1051')$$,
  'P0001', 'invalid_lines', 'a non-numeric quantity is rejected');
select throws_ok($$select public.quote_cart('[{"product_id":"carbonara","quantity":1.5}]', '1051')$$,
  'P0001', 'invalid_lines', 'a fractional quantity is rejected');
select throws_ok($$select public.quote_cart('[{"quantity":1}]', '1051')$$,
  'P0001', 'invalid_lines', 'a line without a product is rejected');

-- --- who may ask -----------------------------------------------------------
select pg_temp.act_as_anon();
select is(
  (public.quote_cart('[{"product_id":"carbonara","quantity":2}]', '1051') ->> 'total_huf')::integer,
  6570, 'a visitor who is not signed in can get a quote'
);

select * from finish();
rollback;
