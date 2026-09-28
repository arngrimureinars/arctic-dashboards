-- One row per month: ISK per EUR and ISK per USD (via USD per EUR).
with isk as (
    select strptime(time_period, '%Y-%m')::date as month, value as isk_per_eur, _loaded_at
    from {{ source('ecb', 'fx_isk_eur') }}
),
usd as (
    select strptime(time_period, '%Y-%m')::date as month, value as usd_per_eur
    from {{ source('ecb', 'fx_usd_eur') }}
)
select
    isk.month,
    isk.isk_per_eur,
    isk.isk_per_eur / usd.usd_per_eur as isk_per_usd,
    isk._loaded_at as loaded_at
from isk
join usd using (month)
