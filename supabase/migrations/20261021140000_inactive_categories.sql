-- A product of an inactive category is not on the menu.
--
-- Deactivating a category hid the category, but its products stayed in `catalog_products` and
-- could still be put in an order: the app showed them nowhere (its menu lists products under
-- their categories), the server still sold them. Both the menu view and the pricing now treat a
-- product as available only when its category is active as well, so the two cannot disagree.
-- Nothing is copied or switched off: reactivating the category brings its products back.

create or replace view public.catalog_products
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
join public.categories c on c.id = p.category_id and c.is_active
join public.product_prices pr
  on pr.product_id = p.id
 and pr.valid_to is null
where p.is_active;

-- `compute_quote` as in 20261021090500, with one more join: the product's category must be active.
-- (`create or replace` keeps the grants; the function was already restricted to its two callers.)
create or replace function private.compute_quote(p_lines jsonb, p_postal_code text)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_zone public.delivery_zones;
  v_lines jsonb;
  v_subtotal integer;
  v_fee integer;
begin
  -- 1. The cart must be a short array of {product_id, quantity 1..99}.
  begin
    if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) > 100 then
      raise exception 'invalid_lines';
    end if;
    if exists (
      select 1
        from jsonb_array_elements(p_lines) e
       where jsonb_typeof(e.value) <> 'object'
          or (e.value ->> 'product_id') is null
          or (e.value ->> 'quantity') is null
          or (e.value ->> 'quantity')::integer not between 1 and 99
    ) then
      raise exception 'invalid_lines';
    end if;
  exception when invalid_text_representation or numeric_value_out_of_range then
    -- A quantity that is not a whole number.
    raise exception 'invalid_lines';
  end;

  -- 2. The delivery zone: of the address, or the default one for an estimate.
  if p_postal_code is null then
    select z.* into v_zone from public.delivery_zones z where z.is_estimate_default;
    if not found then
      raise exception 'delivery_not_configured';
    end if;
  else
    if p_postal_code !~ '^[0-9]{4}$' then
      raise exception 'out_of_delivery_area';
    end if;
    select z.* into v_zone
      from public.delivery_zones z
      join public.delivery_zone_prefixes p on p.zone_id = z.id
     where p.prefix = left(p_postal_code, 3);
    if not found then
      raise exception 'out_of_delivery_area';
    end if;
  end if;

  -- 3. Price the lines. The same product twice is one line; unknown and
  -- inactive products (and products of an inactive category) are left out.
  with raw as (
    select
      e.ordinality as position,
      e.value ->> 'product_id' as product_id,
      (e.value ->> 'quantity')::integer as quantity
    from jsonb_array_elements(p_lines) with ordinality as e (value, ordinality)
  ), agg as (
    select product_id, sum(quantity)::integer as quantity, min(position) as position
      from raw
     group by product_id
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'product_id', a.product_id,
          'name', p.name,
          'quantity', a.quantity,
          'unit_price_huf', pr.amount_huf,
          'vat_rate_percent', p.vat_rate_percent,
          'line_total_huf', pr.amount_huf * a.quantity
        )
        order by a.position
      ),
      '[]'::jsonb
    ),
    coalesce(sum(pr.amount_huf::bigint * a.quantity), 0)::integer
  into v_lines, v_subtotal
  from agg a
  join public.products p on p.id = a.product_id and p.is_active
  join public.categories c on c.id = p.category_id and c.is_active
  join public.product_prices pr on pr.product_id = p.id and pr.valid_to is null;

  if exists (select 1 from jsonb_array_elements(v_lines) l where (l.value ->> 'quantity')::integer > 99) then
    raise exception 'invalid_lines';
  end if;

  v_fee := case
    when v_subtotal = 0 then 0
    when v_zone.free_delivery_from_huf is not null
         and v_subtotal >= v_zone.free_delivery_from_huf then 0
    else v_zone.delivery_fee_huf
  end;

  return jsonb_build_object(
    'lines', v_lines,
    'subtotal_huf', v_subtotal,
    'delivery_fee_huf', v_fee,
    'total_huf', v_subtotal + v_fee,
    'min_order_huf', v_zone.min_order_huf,
    'free_delivery_from_huf', v_zone.free_delivery_from_huf,
    'zone_id', v_zone.id,
    'estimated', p_postal_code is null
  );
end;
$$;
