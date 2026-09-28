-- National monthly tourism pulse: foreign departures via Keflavík, overnight stays,
-- the króna rate and year-on-year changes.
with kef as (
    select
        month,
        max(passengers) filter (where row_type = 'foreign') as foreign_departures,
        max(passengers) filter (where row_type = 'icelandic') as icelandic_departures
    from {{ ref('stg_hagstofa__kef_passengers') }}
    group by month
),
stays as (
    select
        month,
        max(overnight_stays) filter (where nationality_group = 'total') as stays_total,
        max(overnight_stays) filter (where nationality_group = 'foreign') as stays_foreign
    from {{ ref('stg_hagstofa__overnight_stays') }}
    where region_code = 'IS'
    group by month
),
joined as (
    select
        coalesce(kef.month, stays.month) as month,
        kef.foreign_departures,
        kef.icelandic_departures,
        stays.stays_total,
        stays.stays_foreign,
        fx.isk_per_eur,
        fx.isk_per_eur_yoy_pct
    from kef
    full join stays using (month)
    left join {{ ref('fct_fx_monthly') }} fx on fx.month = coalesce(kef.month, stays.month)
)
select
    *,
    100 * (foreign_departures / lag(foreign_departures, 12) over (order by month) - 1) as foreign_departures_yoy_pct,
    100 * (stays_foreign / lag(stays_foreign, 12) over (order by month) - 1) as stays_foreign_yoy_pct
from joined
