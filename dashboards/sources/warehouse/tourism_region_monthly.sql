select t.*, r.name_is as region_name, r.sort_order
from marts.fct_tourism_region_monthly t
join marts.dim_region r using (region_key)
