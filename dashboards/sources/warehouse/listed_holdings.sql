-- Pension fund stakes per month and company (top-20 lists), with fund labels
select h.record_date, h.fund_key, f.short_name as fund, f.slug, h.ticker, h.company_name,
       h.shares, h.pct / 100 as pct, h.pct_change_12m / 100 as pct_change_12m, h.divisions
from marts.fct_pension_listed_holdings h
join marts.dim_pension_fund f using (fund_key)
