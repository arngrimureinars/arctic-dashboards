-- Today's products per store in one shape: common category, price per unit (cases split into
-- cans/bottles), price per litre and per litre of pure alcohol, and a normalised name for matching.
with products as (
    select
        store,
        store_product_id,
        trim(name) as name,
        nullif(trim(producer), '') as producer,
        category_raw,
        volume_ml,
        abv,
        coalesce(pack_size, 1) as pack_size,
        price_isk,
        regular_price_isk,
        nullif(trim(ean), '') as ean,
        nullif(trim(sku), '') as sku,
        nullif(trim(country), '') as country,
        container,
        url,
        in_stock,
        special_order,
        fetched_at::timestamptz as fetched_at
    from {{ source('alcohol', 'products') }}
),

mapped as (
    -- The shop's category names and tags → common category; the lowest priority wins.
    select p.store, p.store_product_id, min_by(m.category, m.priority) as category
    from products p, unnest(p.category_raw) as t(raw)
    join {{ ref('alcohol_category_map') }} m on m.raw_category = lower(trim(t.raw))
    group by all
),

categorised as (
    select
        p.*,
        coalesce(
            m.category,
            -- Fallback for products without a usable category: keywords in the name, then ABV.
            case
                when p.abv >= 20 then 'Sterkt áfengi'
                when regexp_matches(lower(p.name), '\b(ros[eé]|rosado|rosato)\b') then 'Rósavín'
                when regexp_matches(lower(p.name), '\b(cava|prosecco|champagne|cr[eé]mant|spumante|sparkling|brut)\b') then 'Freyðivín'
                when regexp_matches(lower(p.name), '\b(white|blanc|blanco|bianco|hvítt?|weiss)\b') then 'Hvítvín'
                when regexp_matches(lower(p.name), '\b(red|rouge|rosso|tinto|rautt|rauðvín)\b') then 'Rauðvín'
                when regexp_matches(lower(p.name), '\b(ipa|lager|pils|pilsner|stout|ale|bjór)\b') then 'Bjór'
                else 'Óflokkað'
            end
        ) as category,
        m.category is null as category_guessed
    from products p
    left join mapped m using (store, store_product_id)
),

normalised as (
    select
        *,
        -- Wine without a stated size is a 75 cl bottle.
        coalesce(volume_ml, case when category in ('Rauðvín', 'Hvítvín', 'Rósavín', 'Freyðivín') then 750 end) as volume_ml_filled,
        volume_ml is null and category in ('Rauðvín', 'Hvítvín', 'Rósavín', 'Freyðivín') as volume_assumed,
        -- Name for matching: no accents, case, sizes, ABV, pack counts, vintages or punctuation.
        trim(regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(
            lower(strip_accents(replace(replace(name, 'ð', 'd'), 'þ', 'th'))),
            '\bcab\.?\s+sauv\b\.?', 'cabernet sauvignon', 'g'),          -- common abbreviations
            '\bsauv\.?\s+blanc\b', 'sauvignon blanc', 'g'),
            '\d+(?:[.,]\d+)?\s*(?:ml|cl|ltr|l)\b', ' ', 'g'),             -- 750ml, 0,5l
            '\d+(?:[.,]\d+)?\s*%', ' ', 'g'),                             -- 12,5%
            '\b\d{1,2}\s*(?:stk|pk|pack|x)\b|\bx\s*\d{1,2}\b', ' ', 'g'),  -- 12stk, x24
            '\b(?:19|20)\d\d\b', ' ', 'g'),                               -- vintages
            '[^a-z0-9]+', ' ', 'g')) as name_key
    from categorised
)

select
    store,
    store_product_id,
    store || ':' || store_product_id as product_id,
    name,
    producer,
    category,
    category_guessed,
    volume_ml_filled as volume_ml,
    volume_assumed,
    abv,
    pack_size,
    price_isk / pack_size as unit_price_isk,
    regular_price_isk / pack_size as unit_regular_price_isk,
    price_isk < regular_price_isk as on_sale,
    price_isk / pack_size / (volume_ml_filled / 1000) as price_per_litre,
    case when abv > 0 then price_isk / pack_size / (volume_ml_filled / 1000 * abv / 100) end as price_per_litre_alcohol,
    ean,
    sku,
    country,
    container,
    url,
    in_stock,
    special_order,
    fetched_at,
    name_key,
    -- Words that carry meaning for matching (filler words dropped).
    list_distinct(list_filter(
        string_split(name_key, ' '),
        x -> (length(x) > 1 or regexp_full_match(x, '\d')) and not list_contains(
            ['de', 'du', 'des', 'la', 'le', 'les', 'del', 'della', 'di', 'da', 'do', 'the', 'and', 'et', 'og', 'y', 'e',
             'vin', 'vino', 'wine', 'dos', 'flaska', 'fl', 'gler', 'can', 'bottle', 'stk', 'chateau', 'domaine', 'bodegas'], x)
    )) as name_tokens
from normalised
where category <> '(ekki með)'
  and coalesce(abv, 1) > 0  -- alcohol-free beer and soft drinks
  -- Not bottles: gift cards, memberships, tastings, mystery/monthly boxes, soft drinks.
  and not regexp_matches(lower(name), 'gjafabr[eé]f|a[ðd]ild a[ðd]|^v[ií]nkl[uú]bburinn|v[ií]nsm[oö]kkun|kassi m[aá]na[ðd]arins|lukkukassi|villibr[aá][ðd]arkass|coca cola|pepsi')
