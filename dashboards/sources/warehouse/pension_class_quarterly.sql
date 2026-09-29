-- Per quarter, fund, fund type and harmonised asset class (divisions and currencies summed); ma.kr.
select a.quarter_end, a.fund_key, a.fund_type,
       c.asset_class_key, c.name_is as asset_class, c.sort_order as class_order,
       g.asset_group, g.name_is as asset_group_name, g.sort_order as group_order,
       sum(a.amount) / 1e9 as amount_bn,
       sum(a.amount) filter (where a.is_foreign_currency) / 1e9 as foreign_bn
from marts.fct_pension_assets_quarterly a
join (select distinct asset_class_key, name_is, asset_group, sort_order from reference.asset_classes) c using (asset_class_key)
join reference.asset_groups g on g.asset_group = c.asset_group
group by all
