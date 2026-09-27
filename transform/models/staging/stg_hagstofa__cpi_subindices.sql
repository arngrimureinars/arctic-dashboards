select
    strptime("Mánuður", '%YM%m')::date as month,
    "Undirvísitala" as category_code,
    -- labels look like "01 Matur og óáfengir drykkir"; drop the leading COICOP number
    trim(regexp_replace("Undirvísitala_label", '^[0-9]+\s+', '')) as category_name,
    -- CP00 is the total, CP01 a top-level group, CP011 a sub-group, ...
    case when "Undirvísitala" = 'CP00' then 0 else length("Undirvísitala") - 3 end as category_level,
    "Liður" as measure,
    value,
    _source_updated as source_updated_at,
    _loaded_at as loaded_at
from {{ source('hagstofa', 'cpi_subindices') }}
where value is not null
