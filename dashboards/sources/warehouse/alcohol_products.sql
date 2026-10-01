-- Every alcohol product listed today per store, with its price compared with Vínbúðin
select product_id, store, store_name, store_order, name, category, volume_ml, abv, pack_size,
       unit_price_isk, on_sale, price_per_litre, price_per_litre_alcohol, in_stock, special_order,
       product_key, match_method, stores_selling, vinbudin_price_isk, vs_vinbudin_pct, fetched_at
from marts.fct_alcohol_products
