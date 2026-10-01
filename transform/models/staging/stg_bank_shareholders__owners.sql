-- Monthly snapshots of the banks' own shareholder lists (owners above 1 %).
select
    snapshot_date::date as snapshot_date,
    ticker,
    trim(owner_name) as owner_name,
    nullif(trim(cast(owner_id as varchar)), '') as owner_id,
    shares,
    pct,
    holding_date
from {{ source('bank_shareholders', 'owners') }}
