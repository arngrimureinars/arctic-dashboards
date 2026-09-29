-- Per quarter, fund, fund type and currency; ma.kr.
select quarter_end, fund_key, fund_type, currency, sum(amount) / 1e9 as amount_bn
from marts.fct_pension_assets_quarterly
group by all
