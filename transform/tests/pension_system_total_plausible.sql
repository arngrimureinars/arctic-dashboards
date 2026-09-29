-- Total pension assets per quarter should be in a plausible range (1–25 trillion ISK).
select quarter_end, sum(total_assets) as total
from {{ ref('fct_pension_fund_quarterly') }}
group by quarter_end
having sum(total_assets) not between 1e12 and 25e12
