-- Price changes seen after the first snapshot day: old and new price per store and product.
with changes as (
    select
        *,
        lag(price_isk) over (partition by product_id order by snapshot_date) as previous_price_isk,
        lag(listed) over (partition by product_id order by snapshot_date) as previously_listed
    from {{ ref('stg_alcohol__price_changes') }}
)

select
    c.snapshot_date as changed_on,
    c.product_id,
    c.store,
    s.name as store_name,
    c.name,
    c.previous_price_isk,
    c.price_isk,
    c.price_isk / c.previous_price_isk - 1 as change_pct,
    c.price_isk < c.regular_price_isk as on_sale
from changes c
join {{ ref('alcohol_stores') }} s using (store)
where c.listed and c.previously_listed and c.price_isk is distinct from c.previous_price_isk
