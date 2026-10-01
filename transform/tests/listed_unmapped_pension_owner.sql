-- An owner whose name looks like a pension fund but whose kennitala isn't in
-- seeds/pension_fund_owners.csv – add it (or mark is_pension = false). Covers both the CSD
-- lists and the banks' own lists (which use English names like "Gildi Pension Fund").
with owners as (
    select owner_id, owner_name from {{ ref('stg_nasdaq_csd__top20') }}
    union all
    select owner_id, owner_name from {{ ref('stg_bank_shareholders__owners') }}
)
select distinct owner_id, owner_name
from owners
where regexp_matches(lower(owner_name), 'lífeyr|lifeyr|pension fund|gildi - |stapi |birta |festa - |^brú |lífsbraut|lífsverk|almenni|söfnunarsj|eftirlaun|frjálsi')
  and coalesce(owner_id, '') not in (select owner_id from {{ ref('pension_fund_owners') }})
