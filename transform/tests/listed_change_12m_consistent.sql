-- pct_change_12m must equal this year's % minus the % in the same month a year earlier.
select a.id
from {{ ref('fct_pension_listed_holdings') }} a
join {{ ref('fct_pension_listed_holdings') }} b
  on b.fund_key = a.fund_key and b.ticker = a.ticker
 and b.record_date = last_day(a.record_date - interval 12 month)
where abs(a.pct_change_12m - (a.pct - b.pct)) > 1e-9
