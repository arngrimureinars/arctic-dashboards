-- When each source was last updated by Hagstofa and last loaded by the pipeline.
select 'cpi' as dataset, max(source_updated_at) as source_updated_at, max(loaded_at) as loaded_at
from {{ ref('stg_hagstofa__cpi') }}
union all
select 'cpi_subindices', max(source_updated_at), max(loaded_at)
from {{ ref('stg_hagstofa__cpi_subindices') }}
union all
select 'overnight_stays', max(source_updated_at), max(loaded_at)
from (select _source_updated as source_updated_at, _loaded_at as loaded_at from {{ source('hagstofa', 'overnight_stays') }})
union all
select 'kef_passengers', max(source_updated_at), max(loaded_at)
from (select _source_updated as source_updated_at, _loaded_at as loaded_at from {{ source('hagstofa', 'kef_passengers') }})
union all
select 'fx', max(month)::timestamp, max(loaded_at) from {{ ref('stg_ecb__fx_monthly') }}
union all
select 'weather', max(month)::timestamp, max(loaded_at) from {{ ref('stg_vedur__weather_monthly') }}

union all
select 'alcohol', max(fetched_at)::timestamp, max(fetched_at)::timestamp from {{ ref('stg_alcohol__products') }}
