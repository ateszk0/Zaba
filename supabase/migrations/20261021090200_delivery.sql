-- Delivery: zones, opening hours, slot settings and the bookable slots.

create table public.delivery_zones (
  id text primary key,
  name text not null,
  delivery_fee_huf integer not null check (delivery_fee_huf >= 0),
  min_order_huf integer not null check (min_order_huf >= 0),
  -- Order value from which delivery is free; null if it never is.
  free_delivery_from_huf integer check (free_delivery_from_huf is null or free_delivery_from_huf >= 0),
  eta_min_minutes integer not null check (eta_min_minutes > 0),
  eta_max_minutes integer not null check (eta_max_minutes >= eta_min_minutes),
  -- The zone assumed for estimates before the customer has given an address.
  is_estimate_default boolean not null default false,
  sort_order integer not null default 0
);

-- At most one default zone.
create unique index delivery_zones_one_default_idx
  on public.delivery_zones ((true))
  where is_estimate_default;

-- A zone covers the Budapest postal codes that start with these three digits:
-- "1" + the two-digit district number, e.g. "105" is district V. The primary
-- key keeps a prefix from belonging to two zones.
create table public.delivery_zone_prefixes (
  prefix text primary key check (prefix ~ '^[0-9]{3}$'),
  zone_id text not null references public.delivery_zones (id) on delete cascade
);

create index delivery_zone_prefixes_zone_idx on public.delivery_zone_prefixes (zone_id);

-- Opening hours per ISO weekday (1 = Monday ... 7 = Sunday), local time.
-- A weekday without a row is closed.
create table public.opening_hours (
  weekday smallint primary key check (weekday between 1 and 7),
  opens_at time not null,
  closes_at time not null,
  check (closes_at > opens_at)
);

-- One row of settings (the primary key can only ever be `true`).
create table public.delivery_settings (
  id boolean primary key default true check (id),
  timezone text not null default 'Europe/Budapest',
  -- A slot stops being bookable this long before it starts.
  lead_time_minutes integer not null default 45 check (lead_time_minutes >= 0),
  -- How many calendar days (today included) can be booked.
  days_ahead integer not null default 3 check (days_ahead between 1 and 14),
  slot_minutes integer not null default 60 check (slot_minutes between 15 and 240),
  -- How many orders one slot takes.
  slot_capacity integer not null default 10 check (slot_capacity > 0)
);

-- Bookable windows, created on demand by `get_delivery_slots()`. `booked` can
-- never exceed `capacity`: the database refuses an overbooking.
create table public.delivery_slots (
  id uuid primary key default gen_random_uuid(),
  starts_at timestamptz not null,
  ends_at timestamptz not null check (ends_at > starts_at),
  capacity integer not null check (capacity > 0),
  booked integer not null default 0 check (booked >= 0 and booked <= capacity),
  unique (starts_at, ends_at)
);
