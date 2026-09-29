-- Warn when the newest quarter is more than ~7 months old: the Central Bank may have
-- published a new quarter under a different file id (update extract/sources.yml).
{{ config(severity='warn') }}
select max(quarter_end) as latest_quarter
from {{ ref('fct_pension_fund_quarterly') }}
having max(quarter_end) < current_date - interval 210 day
