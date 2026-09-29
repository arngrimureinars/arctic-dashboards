-- One row per quarter, fund and fund type: total assets, foreign-currency share and the coarse asset mix.
select
    concat_ws('|', a.quarter_end, a.fund_key, a.fund_type) as id,
    a.quarter_end,
    a.fund_key,
    a.fund_type,
    sum(a.amount) as total_assets,
    sum(a.amount) filter (where a.is_foreign_currency) / nullif(sum(a.amount), 0) as foreign_share,
    sum(a.amount) filter (where c.asset_group = 'bonds') as bonds,
    sum(a.amount) filter (where c.asset_group = 'deposits') as deposits,
    sum(a.amount) filter (where c.asset_group = 'equities') as equities,
    sum(a.amount) filter (where c.asset_group = 'funds') as funds,
    sum(a.amount) filter (where c.asset_group = 'other') as other,
    count(distinct a.division) as divisions
from {{ ref('fct_pension_assets_quarterly') }} a
join (select distinct asset_class_key, asset_group from {{ ref('asset_classes') }}) c using (asset_class_key)
group by all
