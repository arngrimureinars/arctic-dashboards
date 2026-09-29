-- An owner whose name looks like a pension fund but whose kennitala isn't in
-- seeds/pension_fund_owners.csv – add it (or mark is_pension = false).
select distinct owner_id, owner_name
from {{ ref('stg_nasdaq_csd__top20') }}
where regexp_matches(lower(owner_name), 'lífeyr|lifeyr|gildi - |stapi |birta |festa - |^brú |lífsbraut|lífsverk|almenni|söfnunarsj|eftirlaun|frjálsi')
  and owner_id not in (select owner_id from {{ ref('pension_fund_owners') }})
