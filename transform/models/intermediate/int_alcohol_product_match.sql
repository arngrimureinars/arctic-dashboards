-- Which store products are the same bottle? Every product gets a product_key shared by its
-- matches in other stores. Vínbúðin is the anchor (largest range): a private store's product
-- matched to a Vínbúðin product takes its key; products not sold by Vínbúðin can still match
-- each other.
--
-- Rules, strongest first (shops have no common barcode field):
--   override – alcohol_match_overrides (manual fixes)
--   sku      – the store's SKU is the Vínbúðin product number (importers that sell through both)
--              and the names share a word
--   name     – same size (±1 %), compatible ABV and category, and names that agree: ≥ 2 shared
--              words of which ≥ 1 distinctive (not a grape, region, style or spirit type), every
--              distinctive word of one name found in the other and at most 3 extra in the other,
--              and the same numbers (ages, editions), grapes and qualifiers (Reserva vs Gran Reserva …),
--              and a price within 0.4–2.5× (further apart is a different vintage, size or product)
-- Each product keeps its best-scoring match, one per store.
{% set qualifiers = [
    'gran', 'grand', 'reserva', 'riserva', 'reserve', 'crianza', 'superiore', 'classico', 'ripasso', 'amarone',
    'brut', 'nature', 'extra', 'dry', 'sec', 'demi', 'doux', 'rose', 'rosado', 'blanc', 'blanco', 'bianco',
    'rouge', 'rosso', 'tinto', 'white', 'red', 'pink', 'xo', 'vs', 'vsop', 'gold', 'silver', 'black', 'spiced',
    'light', 'lite', 'zero', 'cask', 'single', 'blush', 'sweet', 'oaked', 'unoaked'
] %}
{% set grapes = [
    'cabernet', 'sauvignon', 'merlot', 'pinot', 'noir', 'grigio', 'gris', 'chardonnay', 'syrah', 'shiraz', 'tempranillo',
    'riesling', 'malbec', 'sangiovese', 'nebbiolo', 'barbera', 'primitivo', 'zinfandel', 'grenache', 'garnacha',
    'verdejo', 'albarino', 'vermentino', 'montepulciano', 'nero', 'avola', 'carmenere', 'pinotage', 'chenin',
    'viognier', 'gewurztraminer', 'moscato', 'muscat', 'franc', 'petit', 'verdot', 'corvina', 'garganega'
] %}
{% set generic = qualifiers + grapes + [
    'prosecco', 'cava', 'champagne', 'cremant', 'asti', 'rioja', 'ribera', 'duero', 'chianti', 'valpolicella',
    'bordeaux', 'bourgogne', 'burgundy', 'rhone', 'cote', 'cotes', 'napa', 'valley', 'sonoma', 'california',
    'toscana', 'piemonte', 'veneto', 'sicilia', 'puglia', 'abruzzo', 'mendoza', 'marlborough', 'alsace',
    'igt', 'doc', 'docg', 'aoc', 'aop', 'do', 'doca', 'dop', 'collection', 'private', 'selection', 'estate',
    'vineyards', 'vineyard', 'family', 'familia', 'cuvee', 'special', 'edition', 'organic', 'bio', 'vegan',
    'bib', 'box', 'kassi', 'kasssa', 'ks', 'gin', 'vodka', 'rum', 'romm', 'whisky', 'whiskey', 'viski', 'tequila',
    'liqueur', 'ara', 'year', 'years', 'aged', 'malt', 'london', 'lager', 'pilsner', 'pils', 'ipa', 'ale', 'beer', 'bjor'
] %}
with products as (
    select
        *,
        list_filter(name_tokens, x -> not list_contains(['{{ generic | join("', '") }}'], x)) as key_tokens,
        list_sort(list_intersect(name_tokens, ['{{ qualifiers | join("', '") }}'])) as qualifier_tokens,
        list_sort(list_filter(name_tokens, x -> regexp_full_match(x, '\d+'))) as number_tokens,
        list_sort(list_intersect(name_tokens, ['{{ grapes | join("', '") }}'])) as grape_tokens
    from {{ ref('stg_alcohol__products') }}
),

pairs as (
    select
        a.product_id as a_id,
        a.store as a_store,
        b.product_id as b_id,
        b.store as b_store,
        a.name_key = b.name_key as same_name,
        a.sku is not null and b.store = 'vinbudin' and a.sku = b.store_product_id as sku_hit,
        len(list_intersect(a.name_tokens, b.name_tokens)) as shared,
        least(len(a.name_tokens), len(b.name_tokens)) as shorter,
        len(a.name_tokens) + len(b.name_tokens) - len(list_intersect(a.name_tokens, b.name_tokens)) as union_size,
        a.qualifier_tokens = b.qualifier_tokens and a.number_tokens = b.number_tokens
            and (len(a.grape_tokens) = 0 or len(b.grape_tokens) = 0 or a.grape_tokens = b.grape_tokens) as qualifiers_agree,
        a.unit_price_isk / b.unit_price_isk as price_ratio,
        len(list_intersect(a.key_tokens, b.key_tokens)) as shared_key,
        len(list_filter(a.key_tokens, x -> not list_contains(b.name_tokens, x))) as a_missing,
        len(list_filter(b.key_tokens, x -> not list_contains(a.name_tokens, x))) as b_missing
    from products a
    join products b
      on a.store <> b.store
     and a.store <> 'vinbudin'
     and (b.store = 'vinbudin' or a.store < b.store)
     and abs(a.volume_ml - b.volume_ml) <= 0.01 * b.volume_ml
     and (a.abv is null or b.abv is null or abs(a.abv - b.abv) <= 0.6)
     and (a.category = b.category or a.category_guessed or b.category_guessed)
     and list_has_any(a.name_tokens, b.name_tokens)
),

scored as (
    select
        *,
        shared / shorter as containment,
        shared / union_size as jaccard,
        case
            when sku_hit then 'sku'
            when same_name then 'name'
            -- A name match more than 2.5× off in price is a different vintage, size or product.
            when shared >= 2 and least(a_missing, b_missing) = 0 and greatest(a_missing, b_missing) <= 3
                 and (shared_key >= 2 or (shared_key = 1 and a_missing + b_missing <= 1))
                 and qualifiers_agree and price_ratio between 0.4 and 2.5 then 'name'
        end as method
    from pairs
),

candidates as (
    select a_id, a_store, b_id, b_store, method,
           (case when method = 'sku' then 2 else 0 end) + (case when same_name then 1 else 0 end)
               + containment + jaccard - 0.1 * greatest(a_missing, b_missing) as score,
           -- Tie-break between equally good names (e.g. vintages listed under one name): closest price.
           abs(ln(price_ratio)) as price_gap
    from scored
    where method is not null
),

overrides as (
    select o.store || ':' || o.store_product_id as a_id, o.store as a_store,
           'vinbudin:' || o.vinbudin_product_id as b_id, o.vinbudin_product_id is not null as is_match
    from {{ ref('alcohol_match_overrides') }} o
),

-- Private store → Vínbúðin: best Vínbúðin product per store product, then one store product per
-- Vínbúðin product and store.
vinbudin_links as (
    select a_id, b_id, 'override' as method, 99 as score, 0 as price_gap from overrides where is_match
    union all
    select c.a_id, c.b_id, c.method, c.score, c.price_gap
    from candidates c
    where c.b_store = 'vinbudin' and c.a_id not in (select a_id from overrides)
),

vinbudin_best as (
    select * from vinbudin_links
    qualify row_number() over (partition by a_id order by score desc, price_gap, b_id) = 1
        and row_number() over (partition by b_id, split_part(a_id, ':', 1) order by score desc, price_gap, a_id) = 1
),

-- Private ↔ private, for products Vínbúðin doesn't sell: mutual best matches.
private_pairs as (
    select c.*
    from candidates c
    where c.b_store <> 'vinbudin'
      and c.a_id not in (select a_id from vinbudin_best)
      and c.b_id not in (select a_id from vinbudin_best)
      and c.a_id not in (select a_id from overrides)
      and c.b_id not in (select a_id from overrides)
),

private_directed as (
    select a_id as id, b_id as other, method, score, price_gap from private_pairs
    union all
    select b_id, a_id, method, score, price_gap from private_pairs
),

private_best as (
    select * from private_directed
    qualify row_number() over (partition by id order by score desc, price_gap, other) = 1
),

private_mutual as (
    select p.id, least(p.id, p.other) as product_key, p.other as matched_to, p.method, p.score
    from private_best p
    join private_best q on q.id = p.other and q.other = p.id
)

select
    p.product_id,
    p.store,
    coalesce(v.b_id, m.product_key, p.product_id) as product_key,
    coalesce(v.b_id, m.matched_to) as matched_to,
    coalesce(v.method, m.method, case when p.store = 'vinbudin' then 'anchor' end) as match_method,
    coalesce(v.score, m.score) as match_score
from products p
left join vinbudin_best v on v.a_id = p.product_id
left join private_mutual m on m.id = p.product_id
