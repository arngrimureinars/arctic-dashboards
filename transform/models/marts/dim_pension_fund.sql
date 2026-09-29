-- Pension funds and custodians, with where they appear in the data.
with quarterly as (
    select distinct n.fund_key
    from {{ ref('stg_sedlabanki__pension_investments') }} i
    join {{ ref('pension_fund_names') }} n on n.raw_name = i.raw_fund_name
),
annual as (
    select distinct n.fund_key
    from {{ ref('stg_sedlabanki__pension_annual') }} a
    join {{ ref('pension_fund_names') }} n on n.raw_name = a.raw_fund_name
)
select
    f.*,
    f.fund_key in (select fund_key from quarterly) as has_quarterly,
    f.fund_key in (select fund_key from annual) as has_annual
from {{ ref('pension_funds') }} f
