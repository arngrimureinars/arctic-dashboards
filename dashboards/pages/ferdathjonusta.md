---
title: Ferðaþjónustan á Íslandi
description: Erlendir ferðamenn, gistinætur eftir landshlutum, gengi krónunnar og veður – úr fjórum gagnalindum.
---

```sql months_is
select * from (values
  (1, 'jan'), (2, 'feb'), (3, 'mar'), (4, 'apr'), (5, 'maí'), (6, 'jún'),
  (7, 'júl'), (8, 'ágú'), (9, 'sep'), (10, 'okt'), (11, 'nóv'), (12, 'des')
) as t(n, name)
```

```sql months_full
select * from (values
  (1, 'janúar'), (2, 'febrúar'), (3, 'mars'), (4, 'apríl'), (5, 'maí'), (6, 'júní'),
  (7, 'júlí'), (8, 'ágúst'), (9, 'september'), (10, 'október'), (11, 'nóvember'), (12, 'desember')
) as t(n, name)
```

```sql latest
select
  t.month,
  m.name || ' ' || year(t.month) as month_label,
  t.foreign_departures,
  t.foreign_departures_yoy_pct / 100 as dep_yoy,
  t.stays_foreign,
  t.stays_foreign_yoy_pct / 100 as stays_yoy,
  t.isk_per_eur,
  t.isk_per_eur_yoy_pct / 100 as eur_yoy
from warehouse.tourism_monthly t
join ${months_full} m on m.n = month(t.month)
where t.month = (select max(month) from warehouse.tourism_monthly where foreign_departures is not null and stays_foreign is not null)
```

```sql outside_capital
-- Share of foreign overnight stays outside the capital region over the last 12 months with regional data
with last12 as (
  select * from warehouse.tourism_region_monthly
  where month > (select max(month) from warehouse.tourism_region_monthly) - interval 12 month
)
select
  sum(stays_foreign) filter (where region_key <> 'capital') / sum(stays_foreign) as share,
  strftime(min(month), '%m/%Y') || '–' || strftime(max(month), '%m/%Y') as period
from last12
```

```sql freshness
select strftime(max(loaded_at), '%d.%m.%Y') as loaded from warehouse.data_freshness
```

<p class="text-sm opacity-70">
Nýjustu tölur: <b><Value data={latest} column=month_label /></b> · Heimildir: Hagstofa Íslands, Ferðamálastofa, Seðlabanki Evrópu (ECB) og Veðurstofa Íslands · Sótt <Value data={freshness} column=loaded />
</p>

<Grid cols=4>
  <BigValue data={latest} value=foreign_departures title="Erlendir ferðamenn (brottfarir)" fmt='#,##0' comparison=dep_yoy comparisonFmt=pct1 comparisonTitle="frá fyrra ári" />
  <BigValue data={latest} value=stays_foreign title="Gistinætur útlendinga" fmt='#,##0' comparison=stays_yoy comparisonFmt=pct1 comparisonTitle="frá fyrra ári" />
  <BigValue data={latest} value=isk_per_eur title="Evra í krónum" fmt='0.0" kr."' comparison=eur_yoy comparisonFmt=pct1 comparisonTitle="frá fyrra ári" downIsGood=true />
  <BigValue data={outside_capital} value=share title="Gistinætur útlendinga utan höfuðborgarsvæðis (12 mán.)" fmt=pct0 />
</Grid>

## Árstíðasveiflan

Erlendir ferðamenn eftir mánuðum – hvert ár sín lína. Sumarið er stærst, en norðurljósaveturinn hefur vaxið.

```sql seasonality
select
  month(t.month) as month_no,
  m.name as mánuður,
  cast(year(t.month) as varchar) as ár,
  t.foreign_departures
from warehouse.tourism_monthly t
join ${months_is} m on m.n = month(t.month)
where t.foreign_departures is not null
  and year(t.month) >= (select max(year(month)) from warehouse.tourism_monthly) - 4
  or (year(t.month) = 2019 and t.foreign_departures is not null)
order by ár, month_no
```

<LineChart
  data={seasonality}
  x=mánuður
  y=foreign_departures
  series=ár
  sort=false
  yFmt='#,##0'
  yAxisTitle="Brottfarir erlendra farþega"
  chartAreaHeight=300
/>

## Króna og ferðamenn

Fjöldi erlendra ferðamanna síðustu 12 mánuði á móti gengi evrunnar. Þegar krónan veikist (evran hækkar) verður Ísland ódýrara fyrir ferðamenn.

```sql fx_vs_visitors
select
  month,
  sum(foreign_departures) over (order by month rows between 11 preceding and current row) as ferðamenn,
  isk_per_eur as evran
from warehouse.tourism_monthly
where foreign_departures is not null
qualify month >= date '2018-12-01' and isk_per_eur is not null
order by month
```

<LineChart
  data={fx_vs_visitors}
  x=month
  y=ferðamenn
  y2=evran
  yFmt='#,##0'
  y2Fmt='0" kr."'
  yAxisTitle="Ferðamenn, síðustu 12 mán."
  y2AxisTitle="Evra í krónum"
  chartAreaHeight=300
/>

## Hvar gista ferðamenn?

<Dropdown data={region_years} name=region_year value=ár title="Ár" defaultValue={region_years[0]?.ár} />

```sql region_years
select distinct cast(year(month) as varchar) as ár
from warehouse.tourism_region_monthly
where year(month) >= 2015
group by year(month)
having count(distinct month) = 12
order by ár desc
```

```sql regions
select region_name as landshluti, sort_order,
       sum(stays_foreign) as útlendingar,
       sum(stays_icelandic) as íslendingar
from warehouse.tourism_region_monthly
where cast(year(month) as varchar) = '${inputs.region_year.value}'
group by all
order by útlendingar desc
```

<BarChart
  data={regions}
  x=landshluti
  y={['útlendingar', 'íslendingar']}
  swapXY=true
  sort=false
  yFmt='#,##0'
  yAxisTitle="Gistinætur"
  chartAreaHeight=300
/>

## Árstíðir landshlutanna

Gistinætur útlendinga eftir landshlutum og mánuðum, og meðalhiti á sama tíma. Utan höfuðborgarsvæðisins er ferðaþjónustan mun háðari sumrinu.

```sql region_season
select
  t.region_name as landshluti,
  t.sort_order,
  month(t.month) as month_no,
  m.name as mánuður,
  t.stays_foreign,
  t.mean_temp_c
from warehouse.tourism_region_monthly t
join ${months_is} m on m.n = month(t.month)
where cast(year(t.month) as varchar) = '${inputs.region_year.value}'
order by t.sort_order, month_no
```

<Grid cols=1>
  <Heatmap data={region_season} x=mánuður y=landshluti value=stays_foreign valueFmt='#,##0' title="Gistinætur útlendinga" xSort=month_no ySort=sort_order />
  <Heatmap data={region_season} x=mánuður y=landshluti value=mean_temp_c valueFmt='0.0"°"' title="Meðalhiti (°C)" xSort=month_no ySort=sort_order colorScale={['#1e3a8a', '#e0f2fe', '#f59e0b']} />
</Grid>

## Hvaðan koma ferðamennirnir?

Brottfarir erlendra farþega síðustu 12 mánuði eftir ríkisfangi.

```sql nationalities
select nationality_name as ríkisfang, sum(passengers) as ferðamenn
from warehouse.kef_nationality_monthly
where month > (select max(month) from warehouse.kef_nationality_monthly) - interval 12 month
  and nationality_name <> 'Önnur þjóðerni'
group by all
order by ferðamenn desc
limit 12
```

<BarChart data={nationalities} x=ríkisfang y=ferðamenn swapXY=true sort=false yFmt='#,##0' chartAreaHeight=340 />

---

<p class="text-sm opacity-70">
Gögn: <a href="https://px.hagstofa.is/pxis/pxweb/is/Atvinnuvegir/">Hagstofa Íslands</a> (gistinætur, SAM01601; farþegar um Keflavíkurflugvöll, SAM02001), <a href="https://data.ecb.europa.eu/">ECB</a> (gengi) og <a href="https://api.vedur.is/weather/">Veðurstofa Íslands</a> (mánaðarmeðaltöl á einni stöð í hverjum landshluta). Nýjustu mánuðir gistinátta birtast fyrst fyrir landið allt og síðar eftir landshlutum. Gengi krónunnar hjá ECB nær aftur til 2018. <a href="/lineage/index.html">Sjá hvernig gögnin verða til →</a>
</p>
