-- Price change log: one row per store, product and day its price or stock changed.
select
    snapshot_date::date as snapshot_date,
    store,
    store_product_id,
    store || ':' || store_product_id as product_id,
    name,
    price_isk,
    regular_price_isk,
    in_stock,
    listed
from {{ source('alcohol_snapshots', 'price_changes') }}
