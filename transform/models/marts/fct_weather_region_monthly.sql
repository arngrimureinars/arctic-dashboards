-- Monthly weather per region, from its representative Veðurstofa station.
select
    w.month || '-' || r.region_key as id,
    w.month,
    r.region_key,
    w.mean_temp_c,
    w.precipitation_mm
from {{ ref('stg_vedur__weather_monthly') }} w
join {{ ref('dim_region') }} r using (station_id)
