-- A customer sees the delivery window of their own orders (the app shows it on
-- the order). Nobody else's slots, and no other slot rows: the policy follows
-- the order, whose own policy already limits it to the customer (or staff).
-- Only the window itself is readable, not the capacity.

create policy delivery_slots_read_ordered on public.delivery_slots
  for select to authenticated
  using (exists (select 1 from public.orders o where o.slot_id = delivery_slots.id));

grant select (id, starts_at, ends_at) on public.delivery_slots to authenticated;
