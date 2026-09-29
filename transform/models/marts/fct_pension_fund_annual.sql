-- Fund-level annual key figures: net-asset-weighted averages of the divisions' ratios,
-- summed assets and head counts. Head counts are summed over divisions, so a person with
-- rights in two divisions counts twice.
select
    concat_ws('|', year, fund_key, fund_type) as id,
    year,
    fund_key,
    fund_type,
    sum(net_assets) as net_assets,
    sum(real_return_pct * net_assets) / nullif(sum(net_assets) filter (where real_return_pct is not null), 0) as real_return_pct,
    sum(real_return_5y_pct * net_assets) / nullif(sum(net_assets) filter (where real_return_5y_pct is not null), 0) as real_return_5y_pct,
    sum(real_return_10y_pct * net_assets) / nullif(sum(net_assets) filter (where real_return_10y_pct is not null), 0) as real_return_10y_pct,
    sum(cost_pct_of_assets * net_assets) / nullif(sum(net_assets) filter (where cost_pct_of_assets is not null), 0) as cost_pct_of_assets,
    sum(actuarial_total_pct * net_assets) / nullif(sum(net_assets) filter (where actuarial_total_pct is not null), 0) as actuarial_total_pct,
    sum(members) as members,
    sum(active_members) as active_members,
    sum(pensioners) as pensioners,
    count(*) as divisions
from {{ ref('fct_pension_key_figures_annual') }}
group by all
