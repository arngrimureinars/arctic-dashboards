-- Overnight stays per month, region and nationality group. Region 'IS' is the national total.
select
    make_date(cast("Ár" as integer), cast("Mánuður" as integer), 1) as month,
    "Landshluti" as region_code,
    "Landshluti_label" as region_name,
    case "Þjóðerni" when 'Total' then 'total' when 'IS' then 'icelandic' else 'foreign' end as nationality_group,
    value as overnight_stays,
    _loaded_at as loaded_at
from {{ source('hagstofa', 'overnight_stays') }}
where value is not null
