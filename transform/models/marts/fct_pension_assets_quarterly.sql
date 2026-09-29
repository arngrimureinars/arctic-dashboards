-- Pension fund assets per quarter, fund, fund type, division, harmonised asset class and currency (ISK).
-- Left joins so unmapped fund or asset-class names surface as nulls and fail the not_null tests.
with lines as (
    select
        i.quarter_end,
        n.fund_key,
        i.raw_fund_name,
        i.fund_type,
        i.division,
        c.asset_class_key,
        i.raw_investment_type,
        i.currency,
        i.amount
    from {{ ref('stg_sedlabanki__pension_investments') }} i
    left join {{ ref('pension_fund_names') }} n on n.raw_name = i.raw_fund_name
    left join {{ ref('asset_classes') }} c on c.raw_name = i.raw_investment_type
)
select
    concat_ws('|', quarter_end, fund_key, fund_type, division, asset_class_key, currency) as id,
    quarter_end,
    fund_key,
    fund_type,
    division,
    asset_class_key,
    currency,
    currency <> 'ISK' as is_foreign_currency,
    sum(amount) as amount
from lines
group by all
