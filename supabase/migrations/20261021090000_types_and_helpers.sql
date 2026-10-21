-- Foundation: the private schema for internal functions, shared enums and
-- small helpers.
--
-- Conventions for every migration in this project:
--   * Money is stored as whole forints in `integer` columns (`*_huf`), gross
--     (VAT included). Never a float.
--   * Timestamps are `timestamptz` (UTC). Local time is only used when slots
--     are generated, with the time zone from `delivery_settings`.
--   * Anything that changes order or payment state goes through a function
--     (`place_order`, `cancel_order`, ...) and is never written by the client
--     directly. Tables carry RLS; writes are not granted.

-- Internal functions live here. The schema is not exposed through the API
-- (see `api.schemas` in config.toml), so nothing in it is callable over HTTP.
create schema if not exists private;
grant usage on schema private to anon, authenticated, service_role;

create type public.order_status as enum (
  'pending_payment',
  'received',
  'preparing',
  'out_for_delivery',
  'delivered',
  'cancelled'
);

create type public.payment_status as enum (
  'pending',
  'succeeded',
  'failed',
  'cancelled',
  'refunded'
);

create type public.admin_role as enum ('admin', 'operator');

-- The 14 allergens that must be declared in the EU. Used by CHECK constraints
-- so a typo cannot end up in the data.
create function private.allergen_codes()
returns text[]
language sql
immutable
parallel safe
set search_path = ''
as $$
  select array[
    'gluten', 'crustaceans', 'egg', 'fish', 'peanut', 'soy', 'milk',
    'nuts', 'celery', 'mustard', 'sesame', 'sulphites', 'lupin', 'molluscs'
  ]::text[]
$$;

-- VAT contained in a gross amount, rounded half up to whole forints.
-- The one place where the VAT rounding rule lives.
-- Example: 1290 Ft at 27 % -> 1290 * 27 / 127 = 274.25 -> 274.
create function private.vat_from_gross(p_gross integer, p_rate smallint)
returns integer
language sql
immutable
parallel safe
set search_path = ''
as $$
  select ((p_gross::bigint * p_rate * 2 + (100 + p_rate)) / (2 * (100 + p_rate)))::integer
$$;

create function private.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

grant execute on function private.allergen_codes() to anon, authenticated, service_role;
grant execute on function private.vat_from_gross(integer, smallint) to anon, authenticated, service_role;
