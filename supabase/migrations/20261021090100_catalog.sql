-- Menu: categories, products with their current price, and stock.

create table public.categories (
  id text primary key default gen_random_uuid()::text,
  name text not null check (length(btrim(name)) > 0),
  -- Which icon the app draws; the app maps the key to an icon.
  icon_key text not null default 'restaurant',
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.products (
  id text primary key default gen_random_uuid()::text,
  category_id text not null references public.categories (id) on delete restrict,
  name text not null check (length(btrim(name)) > 0),
  description text not null default '',
  -- Hungarian VAT rates. Which rate applies to which dish has to be confirmed
  -- with an accountant; the demo data is illustrative.
  vat_rate_percent smallint not null default 27 check (vat_rate_percent in (0, 5, 18, 27)),
  allergens text[] not null default '{}' check (allergens <@ private.allergen_codes()),
  vegetarian boolean not null default false,
  -- Higher is more popular; drives the default order of the menu.
  popularity integer not null default 0,
  -- Path of the product photo relative to the image base URL.
  image_path text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index products_category_idx on public.products (category_id);

create trigger products_touch_updated_at
  before update on public.products
  for each row execute function private.touch_updated_at();

-- Price history. The current price is the row without `valid_to`; a unique
-- index allows at most one of those per product. Gross, in whole forints.
create table public.product_prices (
  id bigint generated always as identity primary key,
  product_id text not null references public.products (id) on delete cascade,
  amount_huf integer not null check (amount_huf >= 0),
  valid_from timestamptz not null default now(),
  valid_to timestamptz,
  check (valid_to is null or valid_to > valid_from)
);

create unique index product_prices_one_current_idx
  on public.product_prices (product_id)
  where valid_to is null;

-- Stock. `quantity` null means "not tracked" (unlimited). The demo does not
-- reserve stock at checkout; the MVP adds reservations on top of this table.
create table public.inventory (
  product_id text primary key references public.products (id) on delete cascade,
  quantity integer check (quantity is null or quantity >= 0),
  updated_at timestamptz not null default now()
);

-- What the app lists: active products with their current price.
create view public.catalog_products
with (security_invoker = true)
as
select
  p.id,
  p.category_id,
  p.name,
  p.description,
  pr.amount_huf as price_huf,
  p.vat_rate_percent,
  p.allergens,
  p.vegetarian,
  p.popularity,
  p.image_path
from public.products p
join public.product_prices pr
  on pr.product_id = p.id
 and pr.valid_to is null
where p.is_active;
