-- One row per station and month with mean temperature and precipitation.
select
    station_id,
    any_value(station_name) as station_name,
    month::date as month,
    max(value) filter (where parameter = 't') as mean_temp_c,
    max(value) filter (where parameter = 'r09') as precipitation_mm,
    max(_loaded_at) as loaded_at
from {{ source('vedur', 'weather_monthly') }}
group by station_id, month
