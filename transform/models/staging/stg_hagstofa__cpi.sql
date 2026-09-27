select
    strptime("Mánuður", '%YM%m')::date as month,
    "Vísitala" as index_code,
    "Vísitala_label" as index_name,
    "Liður" as measure,
    value,
    _source_updated as source_updated_at,
    _loaded_at as loaded_at
from {{ source('hagstofa', 'cpi') }}
where value is not null
