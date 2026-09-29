-- All top-20 owners per company and month (for the company view)
select record_date, ticker, company_name, owner_name, is_pension_fund, fund_key, shares, pct / 100 as pct
from marts.fct_listed_top20_monthly
