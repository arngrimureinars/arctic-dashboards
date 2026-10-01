-- Daily price level per store and category since 1 October 2026
select h.*, s.name as store_name, s.sort_order as store_order
from marts.fct_alcohol_price_history h
join reference.alcohol_stores s using (store)
