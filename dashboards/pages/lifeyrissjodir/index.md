---
title: Lífeyrissjóðirnir
description: Eignir allra íslenskra lífeyrissjóða og vörsluaðila séreignar eftir eignaflokkum, gjaldmiðlum og sjóðum.
full_width: true
hide_toc: true
hide_title: true
hide_breadcrumbs: true
sidebar: hide
---

<PensionTabs active="overview" />

```sql quarters
select distinct strftime(quarter_end, '%Y-%m-%d') as q,
       quarter(quarter_end) || '. ársfj. ' || year(quarter_end) as label,
       quarter_end
from warehouse.pension_fund_quarterly
order by quarter_end desc
```

<ReportHero eyebrow="Mælaborð · Lífeyrissjóðir" title="Lífeyrissjóðirnir" subtitle="Heimild: Seðlabanki Íslands · Fjárhæðir í milljörðum króna (ma.kr.) á bókfærðu virði">
  <div slot="filters" class="flex flex-wrap items-end gap-3">
    <ButtonGroup name=ftype title="Tegund">
      <ButtonGroupItem valueLabel="Allt" value="%" default />
      <ButtonGroupItem valueLabel="Samtrygging" value="Samtrygging" />
      <ButtonGroupItem valueLabel="Séreign" value="Séreign" />
    </ButtonGroup>
    <Dropdown data={quarters} name=quarter value=q label=label order="q desc" title="Ársfjórðungur" defaultValue={quarters[0]?.q} />
  </div>
</ReportHero>

```sql system_series
-- System totals per quarter up to the selected quarter (for KPI sparklines); newest first.
with s as (
  select quarter_end, sum(total_bn) as total_bn,
         sum(total_bn * foreign_share) / sum(total_bn) as foreign_share,
         count(distinct fund_key) as funds
  from warehouse.pension_fund_quarterly
  where fund_type like '${inputs.ftype}' and quarter_end <= '${inputs.quarter.value}'::date
  group by quarter_end
)
select *,
       total_bn / lag(total_bn, 4) over (order by quarter_end) - 1 as yoy,
       foreign_share - lag(foreign_share, 4) over (order by quarter_end) as foreign_yoy
from s
order by quarter_end desc
```

```sql system_return
-- Asset-weighted net real return of the whole system, latest annual accounts
select max(year) as year,
       sum(real_return_pct * net_assets) / sum(net_assets) filter (where real_return_pct is not null) / 100 as real_return,
       sum(real_return_5y_pct * net_assets) / sum(net_assets) filter (where real_return_5y_pct is not null) / 100 as real_return_5y
from warehouse.pension_fund_annual
where year = (select max(year) from warehouse.pension_fund_annual) and fund_type like '${inputs.ftype}'
```

<div class="report-grid">
  <div class="tile span-3">
    <BigValue data={system_series} value=total_bn title="Heildareignir" fmt='#,##0" ma.kr."' sparkline=quarter_end sparklineType=area comparison=yoy comparisonFmt=pct1 comparisonTitle="á einu ári" />
  </div>
  <div class="tile span-3">
    <BigValue data={system_series} value=foreign_share title="Í erlendum gjaldmiðlum" fmt=pct1 sparkline=quarter_end comparison=foreign_yoy comparisonFmt='+0.0%;-0.0%' comparisonTitle="á einu ári" />
  </div>
  <div class="tile span-3">
    <BigValue data={system_return} value=real_return title="Hrein raunávöxtun (síðasta ár)" fmt=pct1 comparison=real_return_5y comparisonFmt=pct1 comparisonTitle="meðaltal 5 ára" />
  </div>
  <div class="tile span-3">
    <BigValue data={system_series} value=funds title="Sjóðir og vörsluaðilar" />
  </div>
</div>

```sql fund_mix
with mix as (
  select f.short_name as sjóður, c.asset_group_name as flokkur, c.group_order, sum(c.amount_bn) as ma_kr
  from warehouse.pension_class_quarterly c
  join warehouse.pension_funds f using (fund_key)
  where c.quarter_end = '${inputs.quarter.value}'::date and c.fund_type like '${inputs.ftype}'
  group by all
)
select *, sum(ma_kr) over (partition by sjóður) as fund_total
from mix
where ma_kr > 0
order by fund_total desc, group_order
```

```sql top_returns
-- Net real return per fund in the latest annual accounts: last year and 5-year average
select f.short_name as sjóður, f.name as fullt_nafn,
       sum(a.real_return_pct * a.net_assets) / nullif(sum(a.net_assets) filter (where a.real_return_pct is not null), 0) / 100 as síðasta_ár,
       sum(a.real_return_5y_pct * a.net_assets) / nullif(sum(a.net_assets) filter (where a.real_return_5y_pct is not null), 0) / 100 as meðaltal_5_ára,
       max(a.year) as ár
from warehouse.pension_fund_annual a
join warehouse.pension_funds f using (fund_key)
where a.year = (select max(year) from warehouse.pension_fund_annual) and a.fund_type like '${inputs.ftype}'
group by all
having meðaltal_5_ára is not null
order by meðaltal_5_ára desc
```

```sql actuarial_now
-- Actuarial position (net assets in excess of total obligations), latest year, samtrygging
select f.short_name as sjóður, f.name as fullt_nafn, a.actuarial_total_pct / 100 as staða, a.year
from warehouse.pension_fund_annual a
join warehouse.pension_funds f using (fund_key)
where a.fund_type = 'Samtrygging' and a.actuarial_total_pct is not null
  and a.year = (select max(year) from warehouse.pension_fund_annual)
order by staða desc
```

```sql actuarial_history
-- Actuarial position over time for the eight largest samtrygging funds
with big as (
  select fund_key from warehouse.pension_fund_annual
  where fund_type = 'Samtrygging' and year = (select max(year) from warehouse.pension_fund_annual) and actuarial_total_pct is not null
  order by net_assets desc limit 8
)
select make_date(cast(a.year as integer), 1, 1) as ár, f.short_name as sjóður, a.actuarial_total_pct / 100 as staða
from warehouse.pension_fund_annual a
join warehouse.pension_funds f using (fund_key)
where a.fund_type = 'Samtrygging' and a.fund_key in (select fund_key from big) and a.actuarial_total_pct is not null
order by a.year
```

<script>
  // Colours for the asset groups, shared by the charts below.
  const groupColors = { 'Skuldabréf': '#0e5a8a', 'Innlán': '#14b8a6', 'Hlutabréf': '#7cc4ef', 'Sjóðir': '#8b5cf6', 'Annað': '#f59e0b' };
  // Asset mix per fund as 100 % stacked horizontal bars at a fixed height (Evidence's
  // BarChart grows one row per category, which made this chart very tall).
  $: mixFunds = [...new Set(Array.from(fund_mix ?? []).map((r) => r.sjóður))].reverse();
  $: mixGroups = [...new Set(Array.from(fund_mix ?? []).sort((a, b) => a.group_order - b.group_order).map((r) => r.flokkur))];
  $: mixTotals = Object.fromEntries(Array.from(fund_mix ?? []).map((r) => [r.sjóður, r.fund_total]));
  $: mixConfig = {
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' },
      valueFormatter: (v) => (v == null ? '–' : `${v.toLocaleString('is-IS', { maximumFractionDigits: 1 })} %`) },
    legend: { top: 0, icon: 'circle', itemWidth: 9, itemHeight: 9, itemGap: 14, textStyle: { fontSize: 11, padding: [0, 0, 0, 2] } },
    grid: { top: 26, left: 4, right: 12, bottom: 4, containLabel: true },
    xAxis: { type: 'value', max: 100, axisLabel: { formatter: '{value} %', fontSize: 10 }, splitLine: { lineStyle: { opacity: 0.3 } } },
    yAxis: { type: 'category', data: mixFunds, axisLabel: { fontSize: 10 }, axisTick: { show: false } },
    series: mixGroups.map((g) => ({
      name: g, type: 'bar', stack: 'mix', barWidth: '70%', itemStyle: { color: groupColors[g] },
      data: mixFunds.map((f) => {
        const row = Array.from(fund_mix).find((r) => r.sjóður === f && r.flokkur === g);
        return row ? Math.round((1000 * row.ma_kr) / mixTotals[f]) / 10 : null;
      })
    }))
  };
  // Top net real returns: 5-year average (sorted) with last year beside it, fixed height.
  $: retRows = Array.from(top_returns ?? []);
  $: pctFmt = (v) => (v == null ? '–' : `${(v * 100).toLocaleString('is-IS', { minimumFractionDigits: 1, maximumFractionDigits: 1 })} %`);
  $: returnsConfig = {
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' }, valueFormatter: pctFmt },
    legend: { top: 0, icon: 'circle', itemWidth: 9, itemHeight: 9, itemGap: 14, textStyle: { fontSize: 11 } },
    grid: { top: 26, left: 4, right: 40, bottom: 4, containLabel: true },
    xAxis: { type: 'value', axisLabel: { formatter: (v) => `${Math.round(v * 1000) / 10} %`, fontSize: 10 }, splitLine: { lineStyle: { opacity: 0.3 } } },
    yAxis: { type: 'category', inverse: true, data: retRows.map((r) => r.sjóður), axisLabel: { fontSize: 10 }, axisTick: { show: false } },
    series: [
      { name: 'Meðaltal 5 ára', type: 'bar', barGap: '10%', itemStyle: { color: '#14b8a6' }, data: retRows.map((r) => r.meðaltal_5_ára),
        label: { show: true, position: 'right', fontSize: 9, formatter: (p) => pctFmt(p.value) } },
      { name: `Síðasta ár (${retRows[0]?.ár ?? ''})`, type: 'bar', itemStyle: { color: '#7cc4ef' }, data: retRows.map((r) => r.síðasta_ár) }
    ]
  };

  // Actuarial position, latest year: green above zero, red below.
  $: actRows = Array.from(actuarial_now ?? []);
  $: actuarialConfig = {
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' }, valueFormatter: pctFmt },
    grid: { top: 4, left: 4, right: 44, bottom: 4, containLabel: true },
    xAxis: { type: 'value', axisLabel: { formatter: (v) => `${Math.round(v * 100)} %`, fontSize: 10 }, splitLine: { lineStyle: { opacity: 0.3 } } },
    yAxis: { type: 'category', inverse: true, data: actRows.map((r) => r.sjóður), axisLabel: { fontSize: 10 }, axisTick: { show: false } },
    series: [{ type: 'bar', barWidth: '65%',
      data: actRows.map((r) => ({ value: r.staða, itemStyle: { color: r.staða >= 0 ? '#14b8a6' : '#f87171' } })),
      label: { show: true, position: 'right', fontSize: 9, formatter: (p) => pctFmt(p.value) },
      markLine: { silent: true, symbol: 'none', lineStyle: { color: '#94a3b8' }, data: [{ xAxis: 0 }], label: { show: false } } }]
  };
</script>

<div class="report-grid">
  <div class="tile span-7">
    <p class="tile-title">Eignasamsetning hvers sjóðs (hlutfall)</p>
    <ECharts config={mixConfig} height="440px" />
  </div>
  <div class="tile span-5">
    <p class="tile-title">Hæsta hreina raunávöxtun – 5 ára meðaltal og síðasta ár</p>
    <ECharts config={returnsConfig} height="440px" />
  </div>
</div>

```sql ranking
with q as (
  select fund_key, sum(total_bn) as total_bn, sum(total_bn * foreign_share) / sum(total_bn) as foreign_share
  from warehouse.pension_fund_quarterly
  where quarter_end = '${inputs.quarter.value}'::date and fund_type like '${inputs.ftype}'
  group by fund_key
),
a as (
  select fund_key,
         sum(real_return_5y_pct * net_assets) / nullif(sum(net_assets) filter (where real_return_5y_pct is not null), 0) / 100 as return_5y,
         sum(cost_pct_of_assets * net_assets) / nullif(sum(net_assets) filter (where cost_pct_of_assets is not null), 0) / 100 as cost,
         sum(members) as members
  from warehouse.pension_fund_annual
  where year = (select max(year) from warehouse.pension_fund_annual) and fund_type like '${inputs.ftype}'
  group by fund_key
)
select f.short_name as sjóður, f.name as fullt_nafn, '/lifeyrissjodir/' || f.slug as link,
       case f.kind when 'vörsluaðili' then 'Vörsluaðili' else 'Lífeyrissjóður' end as tegund,
       q.total_bn, q.foreign_share, a.return_5y, a.cost, a.members
from q
join warehouse.pension_funds f using (fund_key)
left join a using (fund_key)
order by q.total_bn desc
```

<div class="report-grid" id="sjodir">
  <div class="tile span-7">
    <p class="tile-title">Samanburður sjóða – smelltu á sjóð fyrir nánari sundurliðun</p>
    <DataTable data={ranking} link=link rows=12 search=true compact=true>
      <Column id=sjóður title="Sjóður" />
      <Column id=total_bn title="Eignir (ma.kr.)" fmt='#,##0' contentType=bar barColor="#7cc4ef" />
      <Column id=foreign_share title="Erlent" fmt=pct0 />
      <Column id=return_5y title="Raunávöxtun 5 ár" fmt=pct2 contentType=delta />
      <Column id=cost title="Kostnaður" fmt=pct2 />
      <Column id=members title="Sjóðfélagar" fmt='#,##0' />
    </DataTable>
  </div>
  <div class="tile span-5">
    <p class="tile-title">Erlent hlutfall og raunávöxtun (5 ára meðaltal) – stærð = eignir</p>
    <BubbleChart data={ranking} x=foreign_share y=return_5y size=total_bn series=tegund tooltipTitle=fullt_nafn xFmt=pct0 yFmt=pct1 xAxisTitle="Erlent" yAxisTitle="Raunávöxtun" chartAreaHeight=330 />
  </div>
</div>

<div class="report-grid">
  <div class="tile span-5">
    <p class="tile-title">Tryggingafræðileg staða samtryggingar – eignir umfram heildarskuldbindingar ({actuarial_now[0]?.year ?? ''})</p>
    <ECharts config={actuarialConfig} height="360px" />
  </div>
  <div class="tile span-7">
    <p class="tile-title">Tryggingafræðileg staða frá 2019 – átta stærstu sjóðirnir</p>
    <LineChart data={actuarial_history} x=ár y=staða series=sjóður xFmt=yyyy yFmt=pct0 chartAreaHeight=300>
      <ReferenceLine y=0 color=base-content-muted />
    </LineChart>
    <p class="text-xs opacity-60 mt-1">Vegið meðaltal deilda eftir hreinni eign. Deildir með ábyrgð ríkis eða sveitarfélaga (t.d. B-deild LSR) geta verið verulega neikvæðar og draga meðaltal sjóðsins niður.</p>
  </div>
</div>

```sql system_mix
-- One column per year-end (Q4) plus the selected quarter, as shares of the total.
select case when month(quarter_end) = 12 and quarter_end <> '${inputs.quarter.value}'::date
            then year(quarter_end)::varchar
            else quarter(quarter_end) || '. ársfj. ' || year(quarter_end) end as tímabil,
       quarter_end, asset_group_name as flokkur, group_order, sum(amount_bn) as ma_kr
from warehouse.pension_class_quarterly
where fund_type like '${inputs.ftype}'
  and quarter_end <= '${inputs.quarter.value}'::date
  and (month(quarter_end) = 12 or quarter_end = '${inputs.quarter.value}'::date)
group by all
order by quarter_end, group_order
```

```sql classes_now
select asset_class as eignaflokkur, class_order,
       sum(amount_bn) - coalesce(sum(foreign_bn), 0) as innlent,
       coalesce(sum(foreign_bn), 0) as erlent
from warehouse.pension_class_quarterly
where quarter_end = '${inputs.quarter.value}'::date and fund_type like '${inputs.ftype}'
group by all
having sum(amount_bn) > 0.5
order by innlent + erlent desc
```

```sql currencies
select currency as gjaldmiðill, sum(amount_bn) as ma_kr
from warehouse.pension_currency_quarterly
where quarter_end = '${inputs.quarter.value}'::date and fund_type like '${inputs.ftype}' and currency <> 'ISK'
group by all
having sum(amount_bn) > 0.5
order by ma_kr desc
limit 8
```

<div class="report-grid">
  <div class="tile span-5">
    <p class="tile-title">Eignasamsetning kerfisins í árslok</p>
    <BarChart data={system_mix} x=tímabil y=ma_kr series=flokkur type=stacked100 sort=false yFmt=pct0 chartAreaHeight=230 />
  </div>
  <div class="tile span-4">
    <p class="tile-title">Eignaflokkar – innlent og erlent (ma.kr.)</p>
    <BarChart data={classes_now} x=eignaflokkur y={['innlent', 'erlent']} swapXY=true sort=false yFmt='#,##0' chartAreaHeight=230 />
  </div>
  <div class="tile span-3">
    <p class="tile-title">Erlendar eignir eftir gjaldmiðlum (ma.kr.)</p>
    <BarChart data={currencies} x=gjaldmiðill y=ma_kr yFmt='#,##0' sort=false swapXY=true chartAreaHeight=230 />
  </div>
</div>

<details class="text-xs opacity-70 mt-1">
<summary class="cursor-pointer">Um gögnin</summary>
<p class="mt-1">Sundurliðun fjárfestinga er ársfjórðungsleg skýrsla lífeyrissjóða og vörsluaðila séreignarsparnaðar til fjármálaeftirlits Seðlabankans, flokkuð eftir fjárfestingarheimildum laga nr. 129/1997 (A.a–F.b), frá 3. ársfj. 2017. Ávöxtun, kostnaður og sjóðfélagar eru úr samantekt Seðlabankans úr ársreikningum (frá 2019), vegin meðaltöl deilda eftir hreinni eign. Almenni lífeyrissjóðurinn og Lífsverk sameinuðust 2026. <a class="underline" href="/lineage/index.html">Sjá hvernig gögnin verða til →</a></p>
</details>

```sql fund_links
select name, slug from warehouse.pension_funds order by name
```

<div class="hidden">
{#each fund_links as f}<a href="/lifeyrissjodir/{f.slug}">{f.name}</a>{/each}
</div>
