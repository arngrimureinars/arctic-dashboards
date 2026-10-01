-- Daily price level per store and category, from the price change log: on each day, the median
-- price compared with Vínbúðin for the bottles matched today (fixed basket), and an index of the
-- store's own prices (first day = 100).
with days as (
    select unnest(generate_series(
        (select min(snapshot_date) from {{ ref('stg_alcohol__price_changes') }}),
        (select max(snapshot_date) from {{ ref('stg_alcohol__price_changes') }}),
        interval 1 day
    ))::date as day
),

changes as (
    select * from {{ ref('stg_alcohol__price_changes') }}
),

-- Each product's price on each day: its latest change on or before that day.
daily as (
    select d.day, c.product_id, c.store, c.price_isk, c.listed
    from days d
    join changes c on c.snapshot_date <= d.day
    qualify row_number() over (partition by d.day, c.product_id order by c.snapshot_date desc) = 1
),

basket as (
    select product_id, product_key, category, pack_size from {{ ref('fct_alcohol_products') }}
),

priced as (
    select d.day, d.store, b.product_key, b.category, d.product_id, d.price_isk / b.pack_size as unit_price_isk
    from daily d
    join basket b using (product_id)
    where d.listed
),

with_vinbudin as (
    select p.*, v.unit_price_isk as vinbudin_price_isk,
           first_value(p.unit_price_isk) over (partition by p.product_id order by p.day) as first_price_isk
    from priced p
    left join priced v on v.day = p.day and v.product_key = p.product_key and v.store = 'vinbudin'
),

with_total as (
    select * from with_vinbudin
    union all
    select * replace ('Allt' as category) from with_vinbudin
)

select
    day,
    store,
    category,
    count(*) as products,
    median(unit_price_isk / vinbudin_price_isk - 1) filter (where store <> 'vinbudin') as median_vs_vinbudin_pct,
    100 * exp(avg(ln(unit_price_isk / first_price_isk))) as price_index
from with_total
group by day, store, category
