-- Demo delivery terms. In production the operator manages these in the admin.
-- Mirrors app/lib/features/delivery/data/demo_zones.dart.

insert into public.delivery_settings (id, timezone, lead_time_minutes, days_ahead, slot_minutes, slot_capacity)
values (true, 'Europe/Budapest', 45, 3, 60, 10);

-- Monday to Saturday 11:00-21:00, Sunday 11:00-20:00.
insert into public.opening_hours (weekday, opens_at, closes_at) values
  (1, '11:00', '21:00'),
  (2, '11:00', '21:00'),
  (3, '11:00', '21:00'),
  (4, '11:00', '21:00'),
  (5, '11:00', '21:00'),
  (6, '11:00', '21:00'),
  (7, '11:00', '20:00');

insert into public.delivery_zones
  (id, name, delivery_fee_huf, min_order_huf, free_delivery_from_huf, eta_min_minutes, eta_max_minutes, is_estimate_default, sort_order)
values
  ('inner', 'Belső kerületek', 990, 3500, 15000, 35, 50, true, 1),
  ('outer', 'Külső kerületek', 1490, 5000, null, 45, 60, false, 2);

-- Inner: districts I, II, V-IX, XI-XIII. Outer: III, IV, X, XIV-XVI.
-- A postal code starts with "1" + the district number, e.g. 1051 = district V.
insert into public.delivery_zone_prefixes (prefix, zone_id) values
  ('101', 'inner'), ('102', 'inner'), ('105', 'inner'), ('106', 'inner'), ('107', 'inner'),
  ('108', 'inner'), ('109', 'inner'), ('111', 'inner'), ('112', 'inner'), ('113', 'inner'),
  ('103', 'outer'), ('104', 'outer'), ('110', 'outer'), ('114', 'outer'), ('115', 'outer'), ('116', 'outer');
