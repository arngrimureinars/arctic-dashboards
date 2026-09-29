-- Combined % of each company held by pension funds (among its top-20 owners), per month.
select
    concat_ws('|', record_date, ticker) as id,
    record_date,
    ticker,
    any_value(company_name) as company_name,
    sum(pct) filter (where is_pension_fund) as pension_pct,
    sum(pct) as top20_pct,
    count(distinct fund_key) filter (where is_pension_fund) as pension_funds
from {{ ref('fct_listed_top20_monthly') }}
group by record_date, ticker
