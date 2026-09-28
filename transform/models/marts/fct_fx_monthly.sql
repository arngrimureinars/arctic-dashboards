-- Monthly króna exchange rates with year-on-year change (positive = weaker króna).
select
    month,
    isk_per_eur,
    isk_per_usd,
    100 * (isk_per_eur / lag(isk_per_eur, 12) over (order by month) - 1) as isk_per_eur_yoy_pct
from {{ ref('stg_ecb__fx_monthly') }}
