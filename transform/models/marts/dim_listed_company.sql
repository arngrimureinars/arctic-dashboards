-- One row per listed company (current ticker); a company can have had several ISINs.
select c.ticker, any_value(c.name) as name, string_agg(distinct c.isin, ', ') as isins,
       string_agg(distinct c.note, '; ') filter (where c.note is not null) as note,
       min(t.record_date) as first_month, max(t.record_date) as last_month
from {{ ref('listed_companies') }} c
left join {{ ref('stg_nasdaq_csd__top20') }} t using (isin)
group by c.ticker
