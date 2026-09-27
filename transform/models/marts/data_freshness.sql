-- When each source was last updated by Hagstofa and last loaded by the pipeline.
select 'cpi' as dataset, max(source_updated_at) as source_updated_at, max(loaded_at) as loaded_at
from {{ ref('stg_hagstofa__cpi') }}
union all
select 'cpi_subindices', max(source_updated_at), max(loaded_at)
from {{ ref('stg_hagstofa__cpi_subindices') }}
