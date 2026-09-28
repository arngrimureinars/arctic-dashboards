-- Departing passengers through Keflavík per month and nationality.
-- Codes 0/1/2 are totals: all passengers, Icelanders, all foreigners.
select
    strptime("Mánuður", '%YM%m')::date as month,
    cast("Ríkisfang" as integer) as nationality_code,
    "Ríkisfang_label" as nationality_name,
    case cast("Ríkisfang" as integer)
        when 0 then 'total' when 1 then 'icelandic' when 2 then 'foreign' else 'country'
    end as row_type,
    value as passengers,
    _loaded_at as loaded_at
from {{ source('hagstofa', 'kef_passengers') }}
where value is not null
