-- The top-level COICOP groups should make up the whole basket each month.
select month, sum(weight_pct) as total_weight
from {{ ref('fct_cpi_category_effects') }}
group by month
having abs(sum(weight_pct) - 100) > 0.5
