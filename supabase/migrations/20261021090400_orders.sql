-- Orders, their lines, status history, the order state machine, deliveries
-- and payments.
--
-- Nothing here is written by the client. Orders and payments change only
-- through the functions in the following migrations.

create sequence public.order_number_seq start 1001;

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  -- The human-readable number, e.g. ZB-1001.
  number text not null unique default ('ZB-' || nextval('public.order_number_seq')),
  -- `restrict`: an order must outlive account clean-up (accounting). Deleting an
  -- account is handled by anonymising it in the MVP.
  user_id uuid not null references auth.users (id) on delete restrict,
  status public.order_status not null default 'pending_payment',
  -- Denormalised from `payments` so the app can show it without a join.
  payment_status public.payment_status not null default 'pending',
  zone_id text references public.delivery_zones (id),
  slot_id uuid not null references public.delivery_slots (id),
  delivery_postal_code text not null check (delivery_postal_code ~ '^[0-9]{4}$'),
  delivery_street text not null check (length(btrim(delivery_street)) > 0),
  note text not null default '' check (length(note) <= 500),
  subtotal_huf integer not null check (subtotal_huf >= 0),
  delivery_fee_huf integer not null check (delivery_fee_huf >= 0),
  total_huf integer generated always as (subtotal_huf + delivery_fee_huf) stored,
  -- Chosen by the client once per checkout attempt. Sending the same key again
  -- returns the same order instead of creating a second one.
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, idempotency_key)
);

create index orders_user_created_idx on public.orders (user_id, created_at desc);
create index orders_status_created_idx on public.orders (status, created_at desc);
create index orders_slot_idx on public.orders (slot_id);

create trigger orders_touch_updated_at
  before update on public.orders
  for each row execute function private.touch_updated_at();

-- A snapshot of what was ordered: later menu or price changes do not alter it.
create table public.order_items (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.orders (id) on delete cascade,
  product_id text not null references public.products (id) on delete restrict,
  name text not null,
  quantity integer not null check (quantity between 1 and 99),
  unit_price_huf integer not null check (unit_price_huf >= 0),
  vat_rate_percent smallint not null,
  line_total_huf integer generated always as (unit_price_huf * quantity) stored
);

create index order_items_order_idx on public.order_items (order_id);

create table public.order_status_history (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.orders (id) on delete cascade,
  from_status public.order_status,
  to_status public.order_status not null,
  -- Who caused the change: the customer, an operator, or the payment provider.
  actor text not null check (actor in ('customer', 'operator', 'payment')),
  actor_id uuid,
  created_at timestamptz not null default now()
);

create index order_status_history_order_idx on public.order_status_history (order_id, created_at);

-- THE order state machine: the only place that says which status may follow
-- which, and who may make the move. `transition_order` enforces it; the app
-- only displays labels and a timeline.
create table public.order_status_transitions (
  from_status public.order_status not null,
  to_status public.order_status not null,
  allowed_actors text[] not null check (
    cardinality(allowed_actors) > 0
    and allowed_actors <@ array['customer', 'operator', 'payment']::text[]
  ),
  primary key (from_status, to_status)
);

insert into public.order_status_transitions (from_status, to_status, allowed_actors) values
  -- Only a payment event makes an order paid.
  ('pending_payment', 'received', array['payment']),
  ('pending_payment', 'cancelled', array['customer', 'operator']),
  ('received', 'preparing', array['operator']),
  -- Customers may cancel until the kitchen starts.
  ('received', 'cancelled', array['customer', 'operator']),
  ('preparing', 'out_for_delivery', array['operator']),
  ('preparing', 'cancelled', array['operator']),
  ('out_for_delivery', 'delivered', array['operator']);

-- Delivery of an order. Manual for now (the operator sets the status); the
-- table is separate so live courier tracking can be added without touching
-- the order logic.
create table public.deliveries (
  order_id uuid primary key references public.orders (id) on delete cascade,
  courier_name text,
  dispatched_at timestamptz,
  delivered_at timestamptz
);

-- One row per payment attempt of an order.
create table public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  provider text not null default 'fake',
  provider_reference text,
  amount_huf integer not null check (amount_huf >= 0),
  currency char(3) not null default 'HUF' check (currency = 'HUF'),
  status public.payment_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index payments_order_idx on public.payments (order_id, created_at desc);

create trigger payments_touch_updated_at
  before update on public.payments
  for each row execute function private.touch_updated_at();

-- What the payment provider reported (on the real backend: webhooks). The
-- unique key makes processing idempotent: the same event delivered twice is
-- recorded once and applied once. `order_id` has no foreign key on purpose, so
-- an event for an unknown order can still be recorded.
create table public.payment_events (
  id bigint generated always as identity primary key,
  provider text not null,
  provider_event_id text not null,
  order_id uuid,
  event_type text not null check (event_type in ('succeeded', 'failed', 'cancelled')),
  payload jsonb not null default '{}'::jsonb,
  received_at timestamptz not null default now(),
  unique (provider, provider_event_id)
);
