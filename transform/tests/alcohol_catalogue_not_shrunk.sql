-- A store's feed losing over 20 % of its products in a day is far more likely a broken scraper
-- than a real clear-out: fail so it gets looked at before the dashboard shows it.
with latest as (select max(snapshot_date) as day from {{ ref('stg_alcohol__price_changes') }}),

state_before as (
    select store, product_id, listed
    from {{ ref('stg_alcohol__price_changes') }}
    where snapshot_date < (select day from latest)
    qualify row_number() over (partition by product_id order by snapshot_date desc) = 1
),

delisted_today as (
    select store, count(*) as delisted
    from {{ ref('stg_alcohol__price_changes') }}
    where snapshot_date = (select day from latest) and not listed
    group by store
)

select d.store, d.delisted, count(*) as listed_before
from delisted_today d
join state_before b on b.store = d.store and b.listed
group by d.store, d.delisted
having d.delisted > 0.2 * count(*)
