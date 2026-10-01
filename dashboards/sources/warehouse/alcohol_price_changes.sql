-- Price changes seen since the first snapshot. Evidence can't load an empty result, so until the
-- first change there is one placeholder row (changed_on is null) that the page filters out.
select changed_on, store_name, name, previous_price_isk, price_isk, change_pct
from marts.fct_alcohol_price_changes
union all
select null, null, null, null, null, null
where not exists (select 1 from marts.fct_alcohol_price_changes)
