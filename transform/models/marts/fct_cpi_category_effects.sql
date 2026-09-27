-- Top-level COICOP groups per month: their weight in the basket, monthly price change
-- and how many percentage points they added to the total monthly CPI change.
select
    month || '-' || category_code as id,
    month,
    category_code,
    any_value(category_name) as category_name,
    max(value) filter (where measure = 'breakdown') as weight_pct,
    max(value) filter (where measure = 'change_M') as change_mom_pct,
    max(value) filter (where measure = 'effect') as effect_pct_points
from {{ ref('stg_hagstofa__cpi_subindices') }}
where category_level = 1
group by month, category_code
