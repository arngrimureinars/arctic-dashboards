---
title: Eignarhald í skráðum félögum
description: Eignarhlutir íslenskra lífeyrissjóða í skráðum félögum samkvæmt mánaðarlegum lista Nasdaq CSD yfir 20 stærstu hluthafa.
full_width: true
hide_toc: true
hide_title: true
hide_breadcrumbs: true
sidebar: hide
sidebar_link: false
---

```sql months_is
select * from (values
  (1, 'janúar'), (2, 'febrúar'), (3, 'mars'), (4, 'apríl'), (5, 'maí'), (6, 'júní'),
  (7, 'júlí'), (8, 'ágúst'), (9, 'september'), (10, 'október'), (11, 'nóvember'), (12, 'desember')
) as t(n, name)
```

```sql months
select distinct strftime(s.record_date, '%Y-%m-%d') as m, m2.name || ' ' || year(s.record_date) as label, s.record_date
from warehouse.listed_pension_share s
join ${months_is} m2 on m2.n = month(s.record_date)
order by s.record_date desc
```

```sql companies
select distinct ticker, company_name, ticker || ' – ' || company_name as label
from warehouse.listed_pension_share
where record_date = '${inputs.month.value}'::date
order by ticker
```

<div class="flex flex-wrap items-end justify-between gap-x-6 gap-y-2 mb-3">
  <div>
    <a class="text-xs text-primary hover:underline" href="/lifeyrissjodir">← Lífeyrissjóðirnir</a>
    <h1 class="text-2xl font-bold tracking-tight">Eignarhald lífeyrissjóða í skráðum félögum</h1>
    <p class="text-xs opacity-60">Heimild: Nasdaq CSD Iceland – 20 stærstu skráðu hluthafar hvers félags, mánaðarlega frá febrúar 2022</p>
  </div>
  <div class="flex flex-wrap items-end gap-3">
    <Dropdown data={months} name=month value=m label=label order="m desc" title="Mánuður" defaultValue={months[0]?.m} />
    <Dropdown data={companies} name=company value=ticker label=label title="Félag" defaultValue="SIMINN" />
  </div>
</div>

```sql kpis
select count(*) as companies,
       median(pension_pct) as median_pension_pct,
       count(*) filter (where pension_pct > 0.5) as majority,
       arg_max(ticker, pension_pct) as top_company,
       max(pension_pct) as top_pct
from warehouse.listed_pension_share
where record_date = '${inputs.month.value}'::date
```

```sql top_holder
select fund, count(*) as positions, sum(pct) as sum_pct,
       'af ' || (select count(*) from warehouse.listed_pension_share where record_date = '${inputs.month.value}'::date) as companies
from warehouse.listed_holdings
where record_date = '${inputs.month.value}'::date
group by fund
order by positions desc, sum_pct desc
limit 1
```

<div class="report-grid">
  <div class="tile span-3">
    <BigValue data={kpis} value=companies title="Skráð félög á listanum" />
  </div>
  <div class="tile span-3">
    <BigValue data={kpis} value=median_pension_pct title="Hlutur lífeyrissjóða – miðgildi félaga" fmt=pct0 />
  </div>
  <div class="tile span-3">
    <BigValue data={kpis} value=majority title="Félög þar sem lífeyrissjóðir eiga meirihluta" comparison=top_pct comparisonFmt=pct0 comparisonTitle={'mest í ' + (kpis[0]?.top_company ?? '')} comparisonDelta=false />
  </div>
  <div class="tile span-3">
    <BigValue data={top_holder} value=positions title={'Flestir eignarhlutir: ' + (top_holder[0]?.fund ?? '')} comparison=companies comparisonTitle="félögum á listanum" comparisonDelta=false />
  </div>
</div>

```sql heat
select h.fund as sjóður, h.ticker as félag, h.pct,
       sum(h.pct) over (partition by h.fund) as fund_sum
from warehouse.listed_holdings h
where h.record_date = '${inputs.month.value}'::date
order by fund_sum desc
```

```sql pension_share
select ticker as félag, pension_pct as lífeyrissjóðir, top20_pct - pension_pct as aðrir_í_topp_20
from warehouse.listed_pension_share
where record_date = '${inputs.month.value}'::date
order by pension_pct desc
```

<div class="tile mb-3">
  <p class="tile-title">Hver á hvað? Eignarhlutur hvers lífeyrissjóðs í hverju félagi (– = ekki meðal 20 stærstu)</p>
  <Heatmap data={heat} x=félag y=sjóður value=pct valueFmt=pct1 colorScale={['#e0f2fe', '#0e5a8a']} ySort=fund_sum ySortOrder=desc />
</div>

```sql owners
select owner_name as hluthafi,
       case when is_pension_fund then 'Lífeyrissjóður' else 'Annar hluthafi' end as tegund,
       pct
from warehouse.listed_top20
where record_date = '${inputs.month.value}'::date and ticker = '${inputs.company.value}'
order by pct desc
```

```sql company_history
-- The biggest pension holders of the selected company over time (their current top 6)
with top as (
  select fund from warehouse.listed_holdings
  where ticker = '${inputs.company.value}' and record_date = '${inputs.month.value}'::date
  order by pct desc limit 6
)
select record_date, fund as sjóður, pct
from warehouse.listed_holdings
where ticker = '${inputs.company.value}' and fund in (select fund from top)
  and record_date <= '${inputs.month.value}'::date
order by record_date
```

<script>
  // Combined pension share per company, horizontal and fixed height (labels stay readable).
  $: shareRows = Array.from(pension_share ?? []);
  $: shareConfig = {
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' }, valueFormatter: (v) => (v == null ? '' : `${(v * 100).toLocaleString('is-IS', { maximumFractionDigits: 1 })} %`) },
    legend: { top: 0, icon: 'circle', itemWidth: 9, itemHeight: 9, itemGap: 14, textStyle: { fontSize: 11 } },
    grid: { top: 24, left: 4, right: 16, bottom: 4, containLabel: true },
    xAxis: { type: 'value', max: 1, axisLabel: { formatter: (v) => `${Math.round(v * 100)} %`, fontSize: 10 }, splitLine: { lineStyle: { opacity: 0.3 } } },
    yAxis: { type: 'category', inverse: true, data: shareRows.map((r) => r.félag), axisLabel: { fontSize: 10 }, axisTick: { show: false } },
    series: [
      { name: 'Lífeyrissjóðir', type: 'bar', stack: 's', barWidth: '70%', itemStyle: { color: '#14b8a6' }, data: shareRows.map((r) => r.lífeyrissjóðir) },
      { name: 'Aðrir meðal 20 stærstu', type: 'bar', stack: 's', itemStyle: { color: '#94a3b8' }, data: shareRows.map((r) => r.aðrir_í_topp_20) }
    ]
  };

  // Top-20 owners of the selected company, pension funds highlighted, fixed height.
  $: ownerRows = Array.from(owners ?? []);
  $: ownersConfig = {
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' }, valueFormatter: (v) => (v == null ? '' : `${(v * 100).toLocaleString('is-IS', { maximumFractionDigits: 2 })} %`) },
    grid: { top: 4, left: 4, right: 36, bottom: 4, containLabel: true },
    xAxis: { type: 'value', axisLabel: { formatter: (v) => `${Math.round(v * 100)} %`, fontSize: 10 }, splitLine: { lineStyle: { opacity: 0.3 } } },
    yAxis: { type: 'category', inverse: true, data: ownerRows.map((r) => r.hluthafi), axisLabel: { fontSize: 10, width: 170, overflow: 'truncate' }, axisTick: { show: false } },
    series: [{
      type: 'bar', barWidth: '70%',
      data: ownerRows.map((r) => ({ value: r.pct, itemStyle: { color: r.tegund === 'Lífeyrissjóður' ? '#14b8a6' : '#94a3b8' } })),
      label: { show: true, position: 'right', fontSize: 9, formatter: (p) => `${(p.value * 100).toFixed(1)} %` }
    }]
  };
</script>

<div class="report-grid">
  <div class="tile span-3">
    <p class="tile-title">Samanlagður hlutur lífeyrissjóða</p>
    <ECharts config={shareConfig} height="420px" />
  </div>
  <div class="tile span-4">
    <p class="tile-title">20 stærstu hluthafar {inputs.company.value} – <span style="color:#14b8a6">lífeyrissjóðir</span> og aðrir</p>
    <ECharts config={ownersConfig} height="420px" />
  </div>
  <div class="tile span-5">
    <p class="tile-title">Eignarhlutur stærstu lífeyrissjóðanna í {inputs.company.value} frá 2022</p>
    <LineChart data={company_history} x=record_date y=pct series=sjóður yFmt=pct0 chartAreaHeight=360 />
  </div>
</div>

```sql holdings_table
select h.fund as sjóður, '/lifeyrissjodir/' || h.slug as link, h.ticker as félag, h.company_name as nafn,
       h.pct, h.pct_change_12m, h.shares, h.divisions as deildir
from warehouse.listed_holdings h
where h.record_date = '${inputs.month.value}'::date
order by h.pct desc
```

<div class="tile mb-3">
  <p class="tile-title">Allir eignarhlutir lífeyrissjóða á topp-20 listunum – leitaðu að sjóði eða félagi</p>
  <DataTable data={holdings_table} link=link rows=10 search=true compact=true>
    <Column id=sjóður title="Lífeyrissjóður" />
    <Column id=félag title="Félag" />
    <Column id=nafn title="Nafn" />
    <Column id=pct title="Eignarhlutur" fmt=pct2 contentType=bar barColor="#14b8a6" />
    <Column id=pct_change_12m title="Breyting á 12 mán. (pp)" fmt='+0.00%;-0.00%' contentType=delta />
    <Column id=shares title="Fjöldi hluta" fmt='#,##0' />
    <Column id=deildir title="Deildir" />
  </DataTable>
</div>

<details class="text-xs opacity-70">
<summary class="cursor-pointer">Um gögnin – hvað sést og hvað ekki</summary>
<p class="mt-1">Nasdaq CSD Iceland birtir mánaðarlega lista yfir 20 stærstu skráðu hluthafa þeirra félaga sem eru á listanum. Lífeyrissjóðir eru auðkenndir með kennitölu. <b>Aðeins 20 stærstu hluthafar</b> hvers félags birtast, svo minni eignarhlutir sjást ekki. <b>Aðeins bein skráning</b>: hlutir sem lífeyrissjóðir eiga í gegnum verðbréfasjóði eða vörslureikninga sjást ekki, og skráin sýnir ekki endanlega eigendur. <b>Ekki á listanum</b>: m.a. Arion banki, Íslandsbanki, Alvotech og Amaroq. Hlutur „lífeyrissjóða samanlagt“ er summa þeirra lífeyrissjóða sem eru á topp-20 listanum. <a class="underline" href="/lineage/index.html">Sjá hvernig gögnin verða til →</a></p>
</details>
