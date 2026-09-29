-- Per quarter, fund, fund type and division (deild); ma.kr.
select quarter_end, fund_key, fund_type, division,
       sum(amount) / 1e9 as total_bn,
       sum(amount) filter (where is_foreign_currency) / nullif(sum(amount), 0) as foreign_share
from marts.fct_pension_assets_quarterly
group by all
