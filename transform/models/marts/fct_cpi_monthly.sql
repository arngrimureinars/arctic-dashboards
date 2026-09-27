-- One row per month and index (CPI, CPI excl. housing) with the index level and its changes.
select
    month || '-' || index_code as id,
    month,
    index_code,
    any_value(index_name) as index_name,
    max(value) filter (where measure = 'index') as index_value,
    max(value) filter (where measure = 'change_M') as change_mom_pct,
    max(value) filter (where measure = 'change_A') as change_yoy_pct
from {{ ref('stg_hagstofa__cpi') }}
group by month, index_code
