-- Matched bottles priced under a third or over three times Vínbúðin's price are almost
-- certainly matching errors (different size, vintage or product): fix with alcohol_match_overrides.
select product_id, name, unit_price_isk, vinbudin_price_isk, match_method
from {{ ref('fct_alcohol_products') }}
where vs_vinbudin_pct is not null
  and (vs_vinbudin_pct < -0.67 or vs_vinbudin_pct > 2)
