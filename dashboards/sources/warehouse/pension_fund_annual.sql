select a.*, a.net_assets / 1e9 as net_assets_bn, f.name, f.short_name, f.slug
from marts.fct_pension_fund_annual a
join marts.dim_pension_fund f using (fund_key)
