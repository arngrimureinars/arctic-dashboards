-- Annual key figures per fund and division from the financial statement summaries.
-- The source shows 0 where a figure doesn't apply (e.g. a 10-year average for a young
-- division, actuarial position for séreign), so exact zeros in ratios are treated as missing.
-- A few funds report the actuarial position in krónur instead of %; values outside ±100
-- can't be percentages and are dropped.
with items as (
    select
        a.year,
        n.fund_key,
        a.raw_fund_name,
        a.fund_type,
        a.division,
        a.item_key,
        a.value,
        a.net_assets
    from {{ ref('stg_sedlabanki__pension_annual') }} a
    left join {{ ref('pension_fund_names') }} n on n.raw_name = a.raw_fund_name
),
pivoted as (
    select
        year,
        fund_key,
        fund_type,
        division,
        max(net_assets) as net_assets,
        max(value) filter (where item_key = 'LANK010002000000') as real_return_pct,
        max(value) filter (where item_key = 'LANK010003000000') as real_return_5y_pct,
        max(value) filter (where item_key = 'LANK010004000000') as real_return_10y_pct,
        max(value) filter (where item_key = 'LANK010008000000') as members,
        max(value) filter (where item_key = 'LANK010007000000') as active_members,
        max(value) filter (where item_key = 'LANK010009000000') as pensioners,
        max(value) filter (where item_key = 'LANK010020000000') as cost_pct_of_assets,
        max(value) filter (where item_key = 'LANK010001010000') as actuarial_total_pct,
        max(value) filter (where item_key = 'LANK010001020000') as actuarial_accrued_pct
    from items
    group by all
)
select
    concat_ws('|', year, fund_key, fund_type, division) as id,
    year,
    fund_key,
    fund_type,
    division,
    net_assets,
    nullif(real_return_pct, 0) as real_return_pct,
    nullif(real_return_5y_pct, 0) as real_return_5y_pct,
    nullif(real_return_10y_pct, 0) as real_return_10y_pct,
    members,
    active_members,
    pensioners,
    nullif(cost_pct_of_assets, 0) as cost_pct_of_assets,
    case when actuarial_total_pct between -100 and 100 then nullif(actuarial_total_pct, 0) end as actuarial_total_pct,
    case when actuarial_accrued_pct between -100 and 100 then nullif(actuarial_accrued_pct, 0) end as actuarial_accrued_pct
from pivoted
