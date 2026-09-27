---
title: Verðbólga á Íslandi
description: Vísitala neysluverðs frá 1988 – verðbólga, verðbólga án húsnæðis og áhrif einstakra liða.
---

```sql months_is
-- Icelandic month names, used for labels
select * from (values
  (1, 'janúar'), (2, 'febrúar'), (3, 'mars'), (4, 'apríl'), (5, 'maí'), (6, 'júní'),
  (7, 'júlí'), (8, 'ágúst'), (9, 'september'), (10, 'október'), (11, 'nóvember'), (12, 'desember')
) as t(n, name)
```

```sql latest
with cpi as (
  select
    month,
    index_code,
    change_yoy_pct,
    change_mom_pct,
    lag(change_yoy_pct) over (partition by index_code order by month) as prev_yoy_pct
  from warehouse.cpi_monthly
)
select
  cpi.month,
  m.name || ' ' || year(cpi.month) as month_label,
  max(change_yoy_pct) filter (where index_code = 'CPI') as yoy,
  max(change_yoy_pct - prev_yoy_pct) filter (where index_code = 'CPI') as yoy_delta,
  max(change_mom_pct) filter (where index_code = 'CPI') as mom,
  max(change_yoy_pct) filter (where index_code = 'CPILH') as yoy_ex_housing,
  2.5 as target
from cpi
join ${months_is} m on m.n = month(cpi.month)
where cpi.month = (select max(month) from warehouse.cpi_monthly)
group by all
```

```sql freshness
select strftime(max(source_updated_at), '%d.%m.%Y') as source_updated
from warehouse.data_freshness
```

<p class="text-sm opacity-70">
Nýjustu tölur: <b><Value data={latest} column=month_label /></b> · Heimild: Hagstofa Íslands (uppfært <Value data={freshness} column=source_updated />)
</p>

<Grid cols=4>
  <BigValue data={latest} value=yoy title="Verðbólga (12 mán.)" fmt='0.0"%"' comparison=yoy_delta comparisonFmt='+0.0" pp";-0.0" pp"' comparisonTitle="frá fyrri mánuði" downIsGood=true />
  <BigValue data={latest} value=yoy_ex_housing title="Án húsnæðis (12 mán.)" fmt='0.0"%"' />
  <BigValue data={latest} value=mom title="Breyting milli mánaða" fmt='0.00"%"' />
  <BigValue data={latest} value=target title="Verðbólgumarkmið Seðlabankans" fmt='0.0"%"' />
</Grid>

## Þróun verðbólgu

<ButtonGroup name=period>
  <ButtonGroupItem valueLabel="5 ár" value=5 />
  <ButtonGroupItem valueLabel="10 ár" value=10 default />
  <ButtonGroupItem valueLabel="20 ár" value=20 />
  <ButtonGroupItem valueLabel="Frá 1989" value=40 />
</ButtonGroup>

```sql inflation
select
  month,
  case index_code when 'CPI' then 'Vísitala neysluverðs' else 'Án húsnæðis' end as series,
  change_yoy_pct
from warehouse.cpi_monthly
where change_yoy_pct is not null
  and month > (select max(month) from warehouse.cpi_monthly) - interval (${inputs.period}) year
order by month
```

<LineChart
  data={inflation}
  x=month
  y=change_yoy_pct
  series=series
  yFmt='0"%"'
  yAxisTitle="Ársbreyting"
  chartAreaHeight=320
>
  <ReferenceLine y=2.5 label="Markmið 2,5%" color=positive lineType=dashed hideValue=true />
</LineChart>

## Hvað hækkaði verðlag síðasta mánuð?

Áhrif hvers flokks á mánaðarbreytingu vísitölunnar, í prósentustigum.

```sql effects
select
  category_name as flokkur,
  effect_pct_points,
  change_mom_pct,
  weight_pct
from warehouse.cpi_category_effects
where month = (select max(month) from warehouse.cpi_category_effects)
order by effect_pct_points desc
```

<BarChart
  data={effects}
  x=flokkur
  y=effect_pct_points
  swapXY=true
  sort=false
  yFmt='0.00" pp"'
  yAxisTitle="Áhrif á vísitöluna (prósentustig)"
  chartAreaHeight=380
/>

## Hvert fara útgjöld heimilanna?

Vægi flokka í vísitölunni – hve stór hluti af útgjöldum heimila fer í hvern flokk.

<DataTable data={effects} rows=all>
  <Column id=flokkur title="Flokkur" />
  <Column id=weight_pct title="Vægi" fmt='0.0"%"' contentType=bar barColor="#7cc4ef" />
  <Column id=change_mom_pct title="Breyting milli mánaða" fmt='0.00"%"' contentType=delta />
  <Column id=effect_pct_points title="Áhrif (pp)" fmt='0.00' contentType=delta />
</DataTable>

---

<p class="text-sm opacity-70">
Gögnin eru sótt daglega frá <a href="https://px.hagstofa.is/pxis/pxweb/is/Efnahagur/Efnahagur__visitolur__1_vnv/">Hagstofu Íslands</a>, hreinsuð og prófuð með dbt. <a href="/lineage/index.html">Sjá hvernig gögnin verða til →</a>
</p>
