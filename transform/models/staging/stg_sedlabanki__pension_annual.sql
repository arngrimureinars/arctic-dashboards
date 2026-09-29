-- Annual financial statement line items per fund and division.
select
    year,
    trim(fund_name) as raw_fund_name,
    trim(division) as division,
    fund_type,
    item_key,
    section,
    trim(item_name) as item_name,
    value,
    net_assets,
    _loaded_at as loaded_at
from {{ source('sedlabanki', 'pension_annual') }}
