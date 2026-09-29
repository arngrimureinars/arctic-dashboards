-- Top-20 registered shareholders per listed company and month.
select
    record_date::date as record_date,
    isin,
    ticker as ticker_at_date,
    owner_name,
    owner_id,
    shares,
    total_issued,
    pct,
    _source_updated as published_on
from {{ source('nasdaq_csd', 'top20') }}
