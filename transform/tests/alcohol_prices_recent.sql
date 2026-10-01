-- Warn if a store's prices haven't been fetched for three days (its feed keeps failing).
{{ config(severity='warn') }}
select store, max(fetched_at) as latest
from {{ ref('stg_alcohol__products') }}
group by store
having max(fetched_at) < now() - interval 3 day
