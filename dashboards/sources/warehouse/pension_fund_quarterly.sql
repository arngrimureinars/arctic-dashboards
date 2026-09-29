-- Per quarter, fund and fund type (samtrygging/séreign); amounts in ma.kr. (billions ISK)
select q.quarter_end, q.fund_key, q.fund_type, f.name, f.short_name, f.slug, f.kind,
       q.total_assets / 1e9 as total_bn, q.foreign_share, q.divisions,
       q.bonds / 1e9 as bonds_bn, q.deposits / 1e9 as deposits_bn, q.equities / 1e9 as equities_bn,
       q.funds / 1e9 as funds_bn, q.other / 1e9 as other_bn
from marts.fct_pension_fund_quarterly q
join marts.dim_pension_fund f using (fund_key)
