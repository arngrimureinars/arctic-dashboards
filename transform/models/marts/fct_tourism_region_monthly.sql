-- Overnight stays per region and month next to that region's weather.
-- Only months where Hagstofa has published the regional breakdown.
with stays as (
    select
        s.month,
        r.region_key,
        max(s.overnight_stays) filter (where s.nationality_group = 'total') as stays_total,
        max(s.overnight_stays) filter (where s.nationality_group = 'foreign') as stays_foreign,
        max(s.overnight_stays) filter (where s.nationality_group = 'icelandic') as stays_icelandic
    from {{ ref('stg_hagstofa__overnight_stays') }} s
    join {{ ref('dim_region') }} r on r.name_is = s.region_name
    group by s.month, r.region_key
)
select
    stays.month || '-' || stays.region_key as id,
    stays.*,
    w.mean_temp_c,
    w.precipitation_mm
from stays
left join {{ ref('fct_weather_region_monthly') }} w using (month, region_key)
