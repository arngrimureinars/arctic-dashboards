-- For months with a full regional breakdown, the eight regions should add up to the
-- national total (within 1% to allow for rounding/suppressed cells).
with regional as (
    select month, sum(stays_total) as regions_sum, count(*) as regions
    from {{ ref('fct_tourism_region_monthly') }}
    group by month
)
select r.month, r.regions_sum, n.stays_total
from regional r
join {{ ref('fct_tourism_monthly') }} n using (month)
where r.regions = 8
  and abs(r.regions_sum - n.stays_total) > 0.01 * n.stays_total
