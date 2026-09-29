-- Every top-20 row, with pension funds identified by kennitala. Left joins so an unknown
-- company surfaces as a null company name (tested).
select
    concat_ws('|', t.record_date, t.isin, t.owner_id, t.owner_name) as id,
    t.record_date,
    t.isin,
    c.ticker,
    c.name as company_name,
    t.owner_name,
    t.owner_id,
    coalesce(o.is_pension, false) as is_pension_fund,
    o.fund_key,
    o.division_label,
    t.shares,
    t.total_issued,
    t.pct
from {{ ref('stg_nasdaq_csd__top20') }} t
left join {{ ref('listed_companies') }} c using (isin)
left join {{ ref('pension_fund_owners') }} o on o.owner_id = t.owner_id
