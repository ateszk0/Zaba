-- Security: nothing is reachable unless it is granted below.
--
--   * Row Level Security is on for every table. A table without a policy for a
--     role is closed to it.
--   * Beyond RLS, write privileges are simply not granted, so a missing policy
--     can never open a write path by accident.
--   * Functions are closed by default, too, and opened one by one.

-- Anything created in the future starts closed as well.
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;
alter default privileges in schema private revoke execute on functions from public, anon, authenticated;

revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;
revoke all on all functions in schema private from public;

alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.product_prices enable row level security;
alter table public.inventory enable row level security;
alter table public.delivery_zones enable row level security;
alter table public.delivery_zone_prefixes enable row level security;
alter table public.opening_hours enable row level security;
alter table public.delivery_settings enable row level security;
alter table public.delivery_slots enable row level security;
alter table public.profiles enable row level security;
alter table public.addresses enable row level security;
alter table public.admin_users enable row level security;
alter table public.audit_log enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_status_history enable row level security;
alter table public.order_status_transitions enable row level security;
alter table public.deliveries enable row level security;
alter table public.payments enable row level security;
alter table public.payment_events enable row level security;

-- Menu and delivery terms: public to read, not writable through the API.
-- (`inventory`, `delivery_slots` and `payment_events` have no policy at all:
-- they are only touched by functions and the service role.)
create policy categories_read on public.categories
  for select to anon, authenticated using (is_active);
create policy products_read on public.products
  for select to anon, authenticated using (is_active);
create policy product_prices_read on public.product_prices
  for select to anon, authenticated using (valid_to is null);
create policy delivery_zones_read on public.delivery_zones
  for select to anon, authenticated using (true);
create policy delivery_zone_prefixes_read on public.delivery_zone_prefixes
  for select to anon, authenticated using (true);
create policy opening_hours_read on public.opening_hours
  for select to anon, authenticated using (true);
create policy delivery_settings_read on public.delivery_settings
  for select to anon, authenticated using (true);
create policy order_status_transitions_read on public.order_status_transitions
  for select to authenticated using (true);

grant select on
  public.categories, public.products, public.product_prices, public.catalog_products,
  public.delivery_zones, public.delivery_zone_prefixes, public.opening_hours, public.delivery_settings
  to anon, authenticated;
grant select on public.order_status_transitions to authenticated;

-- A customer sees and edits their own profile and addresses, nothing else.
create policy profiles_select_own on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

grant select on public.profiles to authenticated;
grant update (full_name, phone, avoid_allergens) on public.profiles to authenticated;

alter table public.addresses alter column user_id set default auth.uid();

create policy addresses_own on public.addresses
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

grant select, insert, update, delete on public.addresses to authenticated;

-- Staff may read every order; a customer only their own. Nobody writes
-- directly: orders change through the functions only.
create policy orders_read on public.orders
  for select to authenticated
  using (user_id = (select auth.uid()) or private.is_staff());

-- The related tables follow the order: you see them if you can see the order
-- (the subquery runs under the policy above).
create policy order_items_read on public.order_items
  for select to authenticated
  using (exists (select 1 from public.orders o where o.id = order_id));
create policy order_status_history_read on public.order_status_history
  for select to authenticated
  using (exists (select 1 from public.orders o where o.id = order_id));
create policy deliveries_read on public.deliveries
  for select to authenticated
  using (exists (select 1 from public.orders o where o.id = order_id));
create policy payments_read on public.payments
  for select to authenticated
  using (exists (select 1 from public.orders o where o.id = order_id));

grant select on
  public.orders, public.order_items, public.order_status_history, public.deliveries, public.payments
  to authenticated;

-- A user can see whether they are staff; only the service role creates staff.
create policy admin_users_read_own on public.admin_users
  for select to authenticated using (user_id = (select auth.uid()));
grant select on public.admin_users to authenticated;

-- The audit log is for administrators only (not for operators).
create policy audit_log_read on public.audit_log
  for select to authenticated using (private.admin_role() = 'admin');
grant select on public.audit_log to authenticated;

-- Functions that may be called through the API.
grant execute on function public.quote_cart(jsonb, text) to anon, authenticated;
grant execute on function public.get_delivery_slots() to authenticated;
grant execute on function public.place_order(text, jsonb, text, text, uuid, text) to authenticated;
grant execute on function public.cancel_order(uuid) to authenticated;
grant execute on function public.start_payment(uuid) to authenticated;
grant execute on function public.admin_set_order_status(uuid, public.order_status) to authenticated;
-- Only the payment webhook handler (service role) reports payment events.
grant execute on function public.apply_payment_event(text, text, uuid, text, jsonb) to service_role;

-- Live updates for the app and the admin page. Realtime applies the RLS
-- policies above, so everybody receives only what they may read.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.orders, public.order_status_history;
  end if;
end;
$$;
