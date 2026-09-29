-- At most 20 owners per company and month, and their % can't exceed 100.
select record_date, isin, count(*) as owners, sum(pct) as total_pct
from {{ ref('stg_nasdaq_csd__top20') }}
group by record_date, isin
having count(*) > 20 or sum(pct) > 100.5
