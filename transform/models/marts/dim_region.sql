-- The eight regions (landshlutar), shared by the tourism and weather facts.
select region_key, name_is, name_en, station_id, station_name, sort_order
from {{ ref('regions') }}
