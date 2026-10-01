-- Most products should get a category from the shop's own categories (alcohol_category_map);
-- many guessed or unclassified ones mean a shop renamed its categories.
select store,
       avg(case when category_guessed then 1.0 else 0.0 end) as guessed_share,
       avg(case when category = 'Óflokkað' then 1.0 else 0.0 end) as unclassified_share
from {{ ref('stg_alcohol__products') }}
group by store
having avg(case when category_guessed then 1.0 else 0.0 end) > 0.2
    or avg(case when category = 'Óflokkað' then 1.0 else 0.0 end) > 0.15
