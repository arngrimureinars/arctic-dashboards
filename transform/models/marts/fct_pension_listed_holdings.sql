-- Pension fund holdings per month and company (a fund's divisions summed; companies keyed by
-- current ticker, since a company can have had more than one ISIN), with the change
-- from 12 months earlier. Only holdings large enough to be in a company's top-20 list.
with h as (
    select record_date, fund_key, ticker, any_value(company_name) as company_name,
           sum(shares) as shares, sum(pct) as pct,
           string_agg(distinct division_label, ', ') filter (where division_label is not null) as divisions,
           any_value(list_source) as list_source, max(as_of) as as_of
    from {{ ref('fct_listed_top20_monthly') }}
    where is_pension_fund
    group by record_date, fund_key, ticker
)
select
    concat_ws('|', h.record_date, h.fund_key, h.ticker) as id,
    h.*,
    -- Change from the same month a year earlier (null if the stake wasn't in the top 20 then).
    h.pct - prev.pct as pct_change_12m
from h
left join h as prev
    on prev.fund_key = h.fund_key
   and prev.ticker = h.ticker
   and prev.record_date = last_day(h.record_date - interval 12 month)
