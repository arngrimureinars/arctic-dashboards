-- Bottles sold by two or more stores, one row each: the price in every store side by side,
-- the cheapest store and the spread between the cheapest and dearest.
{% set stores = ['vinbudin', 'desma', 'vinklubburinn', 'vin_is'] %}
with products as (
    select * from {{ ref('fct_alcohol_products') }}
    where stores_selling >= 2
),

ranked as (
    select
        *,
        rank() over (partition by product_key order by unit_price_isk) as price_rank,
        count(*) over (partition by product_key, unit_price_isk) as tied
    from products
)

select
    product_key,
    -- Vínbúðin's name where it sells the bottle (its names are the most regular), else the shortest.
    coalesce(max(name) filter (where store = 'vinbudin'), arg_min(name, length(name))) as name,
    coalesce(max(category) filter (where store = 'vinbudin'), mode(category)) as category,
    max(volume_ml) as volume_ml,
    coalesce(max(abv) filter (where store = 'vinbudin'), max(abv)) as abv,
    count(*) as stores_selling,
    {% for s in stores %}
    max(unit_price_isk) filter (where store = '{{ s }}') as price_{{ s }},
    {% endfor %}
    min(unit_price_isk) as min_price_isk,
    max(unit_price_isk) as max_price_isk,
    max(unit_price_isk) / min(unit_price_isk) - 1 as spread_pct,
    case when max(tied) filter (where price_rank = 1) > 1 then 'Jafnt'
         else max(store_name) filter (where price_rank = 1) end as cheapest_store,
    min(unit_price_isk) filter (where store <> 'vinbudin') / max(unit_price_isk) filter (where store = 'vinbudin') - 1
        as best_private_vs_vinbudin_pct,
    string_agg(distinct match_method, ', ') filter (where match_method <> 'anchor') as match_methods
from ranked
group by product_key
