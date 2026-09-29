-- Warn if no new monthly CSD report has arrived for ~70 days.
{{ config(severity='warn') }}
select max(record_date) as latest from {{ ref('stg_nasdaq_csd__top20') }}
having max(record_date) < current_date - interval 70 day
