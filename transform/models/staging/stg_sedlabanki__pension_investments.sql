-- Quarterly pension fund investments, one row per source line.
select
    quarter_end::date as quarter_end,
    fund_type,
    trim(fund_name) as raw_fund_name,
    trim(division) as division,
    trim(investment_type) as raw_investment_type,
    currency,
    amount,
    _loaded_at as loaded_at
from {{ source('sedlabanki', 'pension_investments') }}
where amount is not null
