-- A product of an inactive category is not on the menu and cannot be ordered.
--
-- Written to hold on any database state: it makes its own category and product.
begin;
select plan(9);

create function pg_temp.act_as_anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  set local role anon;
end $$;

insert into public.categories (id, name, icon_key) values ('tap-category', 'Teszt kategória', 'soup');
insert into public.products (id, category_id, name) values ('tap-product', 'tap-category', 'Teszt étel');
insert into public.product_prices (product_id, amount_huf) values ('tap-product', 4000);

-- --- the category is active ---------------------------------------------------
select pg_temp.act_as_anon();
select is(
  (select count(*)::integer from public.catalog_products where id = 'tap-product'),
  1,
  'a product of an active category is on the menu'
);
select is(
  jsonb_array_length(public.quote_cart('[{"product_id":"tap-product","quantity":1}]', '1051') -> 'lines'),
  1,
  'and it is priced'
);
reset role;

-- --- the category is switched off ------------------------------------------------
update public.categories set is_active = false where id = 'tap-category';

select pg_temp.act_as_anon();
select is(
  (select count(*)::integer from public.catalog_products where id = 'tap-product'),
  0,
  'the product leaves the menu with its category'
);
select is(
  (select count(*)::integer from public.catalog_products where category_id = 'tap-category'),
  0,
  'no product of the category is listed'
);
select is(
  jsonb_array_length(public.quote_cart('[{"product_id":"tap-product","quantity":1}]', '1051') -> 'lines'),
  0,
  'a cart that still holds it is priced without it'
);
select ok(
  (select count(*) from public.catalog_products) > 0,
  'products of other categories are unaffected'
);
reset role;

-- The product itself is untouched: only the category decides.
select is(
  (select is_active from public.products where id = 'tap-product'),
  true,
  'the product row is not switched off'
);

-- --- the category is back --------------------------------------------------------
update public.categories set is_active = true where id = 'tap-category';

select pg_temp.act_as_anon();
select is(
  (select count(*)::integer from public.catalog_products where id = 'tap-product'),
  1,
  'reactivating the category brings the product back'
);
select is(
  jsonb_array_length(public.quote_cart('[{"product_id":"tap-product","quantity":1}]', '1051') -> 'lines'),
  1,
  'and it can be priced again'
);
reset role;

select * from finish();
rollback;
