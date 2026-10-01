-- Per store and category (and all categories together, category = 'Allt'): range, sale items,
-- and how its prices compare with Vínbúðin on the bottles both sell.
with products as (
    select * from {{ ref('fct_alcohol_products') }}
),

with_total as (
    select * from products
    union all
    select * replace ('Allt' as category) from products
)

select
    store,
    any_value(store_name) as store_name,
    any_value(store_type) as store_type,
    any_value(store_order) as store_order,
    category,
    count(*) as products,
    count(*) filter (where in_stock) as products_in_stock,
    count(*) filter (where on_sale) as products_on_sale,
    median(unit_price_isk) as median_price_isk,
    median(price_per_litre) as median_price_per_litre,
    count(vs_vinbudin_pct) as matched_with_vinbudin,
    median(vs_vinbudin_pct) as median_vs_vinbudin_pct,
    avg(case when vs_vinbudin_pct < -0.005 then 1.0 when vs_vinbudin_pct is not null then 0.0 end) as share_cheaper_than_vinbudin,
    avg(case when abs(vs_vinbudin_pct) <= 0.005 then 1.0 when vs_vinbudin_pct is not null then 0.0 end) as share_same_as_vinbudin
from with_total
group by store, category
