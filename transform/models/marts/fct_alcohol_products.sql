-- Every product on sale today, per store, with its match across stores and its price
-- compared with the same bottle at Vínbúðin.
with products as (
    select p.*, m.product_key, m.matched_to, m.match_method, m.match_score
    from {{ ref('stg_alcohol__products') }} p
    join {{ ref('int_alcohol_product_match') }} m using (product_id)
),

vinbudin as (
    select product_key, unit_price_isk as vinbudin_price_isk
    from products
    where store = 'vinbudin'
),

stores_per_key as (
    select product_key, count(distinct store) as stores_selling
    from products
    group by product_key
)

select
    p.product_id,
    p.store,
    s.name as store_name,
    s.store_type,
    s.sort_order as store_order,
    p.store_product_id,
    p.name,
    p.producer,
    p.category,
    p.category_guessed,
    p.volume_ml,
    p.volume_assumed,
    p.abv,
    p.pack_size,
    p.unit_price_isk,
    p.unit_regular_price_isk,
    p.on_sale,
    p.price_per_litre,
    p.price_per_litre_alcohol,
    p.in_stock,
    p.special_order,
    p.product_key,
    p.match_method,
    p.match_score,
    k.stores_selling,
    v.vinbudin_price_isk,
    case when p.store <> 'vinbudin' and v.vinbudin_price_isk > 0 then p.unit_price_isk / v.vinbudin_price_isk - 1 end as vs_vinbudin_pct,
    p.country,
    p.url,
    p.fetched_at
from products p
join {{ ref('alcohol_stores') }} s using (store)
join stores_per_key k using (product_key)
left join vinbudin v using (product_key)
