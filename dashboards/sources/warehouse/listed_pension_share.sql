select record_date, ticker, company_name, pension_pct / 100 as pension_pct, top20_pct / 100 as top20_pct, pension_funds
from marts.fct_listed_pension_share
