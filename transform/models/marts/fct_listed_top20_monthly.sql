-- Largest registered owners per listed company and month, with pension funds identified by
-- kennitala. Two sources:
--   * Nasdaq CSD's monthly top-20 lists (most companies, from Feb 2022)
--   * the banks' own lists of owners above 1 % (ISB, ARION; snapshots from Sep 2026). For each
--     CSD month the latest bank snapshot on or before that month is used, and the newest CSD
--     month also takes the newest bank snapshot.
with csd as (
    select
        t.record_date,
        t.isin,
        c.ticker,
        c.name as company_name,
        t.owner_name,
        t.owner_id,
        t.shares,
        t.total_issued,
        t.pct,
        'csd_top20' as list_source,
        t.record_date as as_of
    from {{ ref('stg_nasdaq_csd__top20') }} t
    left join {{ ref('listed_companies') }} c using (isin)
),
months as (
    select distinct record_date from csd
),
bank_snapshot_for_month as (
    select
        m.record_date,
        b.ticker,
        case
            when m.record_date = (select max(record_date) from months) then max(b.snapshot_date)
            else max(b.snapshot_date) filter (where b.snapshot_date <= m.record_date)
        end as snapshot_date
    from months m
    cross join (select distinct ticker, snapshot_date from {{ ref('stg_bank_shareholders__owners') }}) b
    group by m.record_date, b.ticker
),
banks as (
    select
        s.record_date,
        c.isin,
        b.ticker,
        c.name as company_name,
        b.owner_name,
        b.owner_id,
        b.shares,
        null::double as total_issued,
        b.pct,
        'bank_over_1pct' as list_source,
        b.snapshot_date as as_of
    from bank_snapshot_for_month s
    join {{ ref('stg_bank_shareholders__owners') }} b using (ticker, snapshot_date)
    left join {{ ref('listed_companies') }} c on c.ticker = b.ticker
),
all_rows as (
    select * from csd
    union all
    select * from banks
)
select
    concat_ws('|', a.record_date, a.isin, coalesce(a.owner_id, ''), a.owner_name) as id,
    a.record_date,
    a.isin,
    a.ticker,
    a.company_name,
    a.owner_name,
    a.owner_id,
    coalesce(o.is_pension, false) as is_pension_fund,
    o.fund_key,
    o.division_label,
    a.shares,
    a.total_issued,
    a.pct,
    a.list_source,
    a.as_of
from all_rows a
left join {{ ref('pension_fund_owners') }} o on o.owner_id = a.owner_id
