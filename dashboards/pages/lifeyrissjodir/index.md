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

<div class="flex flex-wrap items-end justify-between gap-x-6 gap-y-2 mb-3">
  <div>
    <h1 class="text-2xl font-bold tracking-tight">Lífeyrissjóðirnir</h1>
    <p class="text-xs opacity-60">Heimild: Seðlabanki Íslands · Fjárhæðir í milljörðum króna (ma.kr.) á bókfærðu virði</p>
  </div>
  <div class="flex flex-wrap items-end gap-3">
    <ButtonGroup name=ftype title="Tegund">
      <ButtonGroupItem valueLabel="Allt" value="%" default />
      <ButtonGroupItem valueLabel="Samtrygging" value="Samtrygging" />
      <ButtonGroupItem valueLabel="Séreign" value="Séreign" />
    </ButtonGroup>
    <Dropdown data={quarters} name=quarter value=q label=label order="q desc" title="Ársfjórðungur" defaultValue={quarters[0]?.q} />
  </div>
</div>

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

```sql fund_tree
select f.short_name as sjóður, c.asset_group_name as flokkur, c.group_order, sum(c.amount_bn) as ma_kr
from warehouse.pension_class_quarterly c
join warehouse.pension_funds f using (fund_key)
where c.quarter_end = '${inputs.quarter.value}'::date and c.fund_type like '${inputs.ftype}'
group by all
having sum(c.amount_bn) > 0
order by sjóður, group_order
```

<script>
  // Treemap: one box per fund, split into asset groups; box area = assets.
  const groupColors = { 'Skuldabréf': '#0e5a8a', 'Innlán': '#14b8a6', 'Hlutabréf': '#7cc4ef', 'Sjóðir': '#8b5cf6', 'Annað': '#f59e0b' };
  $: treeData = Object.values(
    Array.from(fund_tree ?? []).reduce((acc, r) => {
      acc[r.sjóður] ??= { name: r.sjóður, children: [] };
      acc[r.sjóður].children.push({ name: r.flokkur, value: Math.round(r.ma_kr * 10) / 10, itemStyle: { color: groupColors[r.flokkur] } });
      return acc;
    }, {})
  );
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
  $: treemapConfig = {
    tooltip: { formatter: (p) => `${p.treePathInfo.map((t) => t.name).filter(Boolean).join(' › ')}<br/><b>${Math.round(p.value).toLocaleString('is-IS')} ma.kr.</b>` },
    series: [{
      type: 'treemap', data: treeData, roam: false, nodeClick: false, breadcrumb: { show: false },
      top: 4, left: 4, right: 4, bottom: 4,
      label: { show: true, formatter: '{b}', fontSize: 10, color: '#fff', overflow: 'truncate' },
      upperLabel: { show: true, height: 18, color: '#fff', fontWeight: 'bold', fontSize: 11, backgroundColor: 'rgba(6,18,28,0.55)' },
      itemStyle: { borderColor: 'rgba(6,18,28,0.9)', borderWidth: 1, gapWidth: 1 },
      levels: [{ itemStyle: { borderWidth: 3, gapWidth: 3, borderColor: 'rgba(6,18,28,0.9)' } }, { itemStyle: { gapWidth: 1 } }]
    }]
  };
</script>

<div class="report-grid">
  <div class="tile span-7">
    <p class="tile-title">Eignasamsetning hvers sjóðs (hlutfall)</p>
    <ECharts config={mixConfig} height="440px" />
  </div>
  <div class="tile span-5">
    <p class="tile-title">Stærð og samsetning – hver reitur er sjóður, flatarmál = eignir</p>
    <ECharts config={treemapConfig} height="440px" />
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
