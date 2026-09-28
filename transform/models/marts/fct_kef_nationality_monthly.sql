-- Foreign departures through Keflavík per nationality and month (totals excluded).
select
    month || '-' || nationality_code as id,
    month,
    nationality_code,
    nationality_name,
    passengers
from {{ ref('stg_hagstofa__kef_passengers') }}
where row_type = 'country'
