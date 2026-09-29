---
title: Lífeyrissjóður
hide_title: true
hide_breadcrumbs: true
hide_toc: true
full_width: true
sidebar: hide
sidebar_link: false
---

```sql fund
select * from warehouse.pension_funds where slug = '${params.fund}'
```

```sql types
select distinct q.fund_type from warehouse.pension_fund_quarterly q
join warehouse.pension_funds p using (fund_key)
where p.slug = '${params.fund}'
order by q.fund_type
```

```sql quarters
select distinct strftime(q.quarter_end, '%Y-%m-%d') as q,
       quarter(q.quarter_end) || '. ársfj. ' || year(q.quarter_end) as label,
       q.quarter_end
from warehouse.pension_fund_quarterly q
join warehouse.pension_funds p using (fund_key)
where p.slug = '${params.fund}'
order by q.quarter_end desc
```

<div class="flex flex-wrap items-end justify-between gap-x-6 gap-y-2 mb-3">
  <div>
    <a class="text-xs text-primary hover:underline" href="/lifeyrissjodir">← Allir lífeyrissjóðir</a>
    <h1 class="text-2xl font-bold tracking-tight">{fund[0]?.name ?? 'Sjóður'}</h1>
    <p class="text-xs opacity-60">{fund[0]?.note ?? ''} {fund[0]?.note ? '·' : ''} Tegundir: {types.map((t) => t.fund_type).join(' og ')} · Fjárhæðir í ma.kr. · Heimild: Seðlabanki Íslands</p>
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

```sql series
-- The fund's totals per quarter up to the selected quarter (KPI sparklines); newest first.
with s as (
  select q.quarter_end, sum(q.total_bn) as total_bn,
         sum(q.total_bn * q.foreign_share) / nullif(sum(q.total_bn), 0) as foreign_share,
         sum(q.divisions) as divisions
  from warehouse.pension_fund_quarterly q
  join warehouse.pension_funds p using (fund_key)
  where p.slug = '${params.fund}' and q.fund_type like '${inputs.ftype}' and q.quarter_end <= '${inputs.quarter.value}'::date
  group by q.quarter_end
)
select *,
       total_bn / nullif(lag(total_bn, 4) over (order by quarter_end), 0) - 1 as yoy,
       foreign_share - lag(foreign_share, 4) over (order by quarter_end) as foreign_yoy
from s
order by quarter_end desc
```

```sql latest_annual
select a.year, a.real_return_pct / 100 as real_return, a.real_return_5y_pct / 100 as real_return_5y,
       a.members, a.pensioners, a.cost_pct_of_assets / 100 as cost
from warehouse.pension_fund_annual a
join warehouse.pension_funds p using (fund_key)
where p.slug = '${params.fund}'
  and a.fund_type = coalesce(nullif('${inputs.ftype}', '%'), (select min(fund_type) from ${types}))
order by a.year desc
limit 1
```

<div class="report-grid">
  <div class="tile span-3">
    <BigValue data={series} value=total_bn title="Eignir" fmt='#,##0.0" ma.kr."' sparkline=quarter_end sparklineType=area comparison=yoy comparisonFmt=pct1 comparisonTitle="á einu ári" />
  </div>
  <div class="tile span-3">
    <BigValue data={series} value=foreign_share title="Í erlendum gjaldmiðlum" fmt=pct1 sparkline=quarter_end comparison=foreign_yoy comparisonFmt='+0.0%;-0.0%' comparisonTitle="á einu ári" />
  </div>
  <div class="tile span-3">
    <BigValue data={latest_annual} value=real_return title={'Hrein raunávöxtun ' + (latest_annual[0]?.year ?? '')} fmt=pct1 comparison=real_return_5y comparisonFmt=pct1 comparisonTitle="meðaltal 5 ára" />
  </div>
  <div class="tile span-3">
    <BigValue data={latest_annual} value=members title="Sjóðfélagar" fmt='#,##0' comparison=cost comparisonFmt=pct2 comparisonTitle="kostnaður af eignum" comparisonDelta=false />
  </div>
</div>

```sql classes_now
select c.asset_class as eignaflokkur, c.class_order,
       sum(c.amount_bn) - coalesce(sum(c.foreign_bn), 0) as innlent,
       coalesce(sum(c.foreign_bn), 0) as erlent
from warehouse.pension_class_quarterly c
join warehouse.pension_funds p using (fund_key)
where p.slug = '${params.fund}' and c.fund_type like '${inputs.ftype}' and c.quarter_end = '${inputs.quarter.value}'::date
group by all
having sum(c.amount_bn) > 0.05
order by innlent + erlent desc
```

```sql vs_system
-- The fund's asset-group mix next to the whole system's, same quarter and fund type
with g as (
  select c.asset_group_name as flokkur, c.group_order,
         sum(c.amount_bn) filter (where p.slug = '${params.fund}') as fund_bn,
         sum(c.amount_bn) as system_bn
  from warehouse.pension_class_quarterly c
  join warehouse.pension_funds p using (fund_key)
  where c.fund_type like '${inputs.ftype}' and c.quarter_end = '${inputs.quarter.value}'::date
  group by all
)
select flokkur, group_order,
       coalesce(fund_bn, 0) / sum(coalesce(fund_bn, 0)) over () as sjóðurinn,
       system_bn / sum(system_bn) over () as allir_sjóðir
from g
order by group_order
```

```sql currencies
select c.currency as gjaldmiðill, sum(c.amount_bn) as ma_kr
from warehouse.pension_currency_quarterly c
join warehouse.pension_funds p using (fund_key)
where p.slug = '${params.fund}' and c.fund_type like '${inputs.ftype}' and c.quarter_end = '${inputs.quarter.value}'::date
group by all
having sum(c.amount_bn) > 0.05
order by ma_kr desc
limit 8
```

<div class="report-grid">
  <div class="tile span-5">
    <p class="tile-title">Eignaflokkar – innlent og erlent (ma.kr.)</p>
    <BarChart data={classes_now} x=eignaflokkur y={['innlent', 'erlent']} swapXY=true sort=false yFmt='#,##0' chartAreaHeight=250 />
  </div>
  <div class="tile span-4">
    <p class="tile-title">Samsetning miðað við alla sjóði</p>
    <BarChart data={vs_system} x=flokkur y={['sjóðurinn', 'allir_sjóðir']} type=grouped sort=false yFmt=pct0 chartAreaHeight=250 />
  </div>
  <div class="tile span-3">
    <p class="tile-title">Gjaldmiðlar (ma.kr.)</p>
    <BarChart data={currencies} x=gjaldmiðill y=ma_kr swapXY=true sort=false yFmt='#,##0' chartAreaHeight=250 />
  </div>
</div>

```sql history
-- One column per year-end (Q4) plus the selected quarter, as shares of the fund's total.
select case when month(c.quarter_end) = 12 and c.quarter_end <> '${inputs.quarter.value}'::date
            then year(c.quarter_end)::varchar
            else quarter(c.quarter_end) || '. ársfj. ' || year(c.quarter_end) end as tímabil,
       c.quarter_end, c.asset_group_name as flokkur, c.group_order, sum(c.amount_bn) as ma_kr
from warehouse.pension_class_quarterly c
join warehouse.pension_funds p using (fund_key)
where p.slug = '${params.fund}' and c.fund_type like '${inputs.ftype}'
  and c.quarter_end <= '${inputs.quarter.value}'::date
  and (month(c.quarter_end) = 12 or c.quarter_end = '${inputs.quarter.value}'::date)
group by all
order by c.quarter_end, c.group_order
```

```sql returns_chart
-- One fund type at a time: the selected one, or samtrygging when "Allt" is selected.
select make_date(cast(a.year as integer), 1, 1) as ár, a.fund_type,
       a.real_return_pct / 100 as raunávöxtun,
       a.real_return_5y_pct / 100 as meðaltal_5_ára,
       a.real_return_10y_pct / 100 as meðaltal_10_ára
from warehouse.pension_fund_annual a
join warehouse.pension_funds p using (fund_key)
where p.slug = '${params.fund}'
  and a.fund_type = coalesce(nullif('${inputs.ftype}', '%'), (select min(fund_type) from ${types}))
order by a.year
```

<div class="report-grid">
  <div class="tile span-7">
    <p class="tile-title">Eignasamsetning í árslok</p>
    <BarChart data={history} x=tímabil y=ma_kr series=flokkur type=stacked100 sort=false yFmt=pct0 chartAreaHeight=220 />
  </div>
  <div class="tile span-5">
    <p class="tile-title">Hrein raunávöxtun – {returns_chart[0]?.fund_type ?? ''}</p>
    {#if returns_chart.length > 0}
    <LineChart data={returns_chart} x=ár y={['raunávöxtun', 'meðaltal_5_ára', 'meðaltal_10_ára']} xFmt=yyyy yFmt=pct1 chartAreaHeight=220 />
    {:else}
    <p class="text-sm opacity-60 py-8">Engar lykiltölur úr ársreikningum.</p>
    {/if}
  </div>
</div>

```sql divisions
select d.fund_type as tegund, d.division as deild, d.total_bn, d.foreign_share
from warehouse.pension_division_quarterly d
join warehouse.pension_funds p using (fund_key)
where p.slug = '${params.fund}' and d.fund_type like '${inputs.ftype}' and d.quarter_end = '${inputs.quarter.value}'::date
order by d.total_bn desc
```

```sql annual
select cast(a.year as integer)::varchar as ár, a.fund_type as tegund,
       a.real_return_pct / 100 as raunávöxtun,
       a.real_return_5y_pct / 100 as meðaltal_5_ára,
       a.cost_pct_of_assets / 100 as kostnaður,
       a.actuarial_total_pct / 100 as tryggingafræðileg_staða,
       a.members as sjóðfélagar, a.pensioners as lífeyrisþegar
from warehouse.pension_fund_annual a
join warehouse.pension_funds p using (fund_key)
where p.slug = '${params.fund}' and a.fund_type like '${inputs.ftype}'
order by a.year desc, a.fund_type
```

<div class="report-grid">
  <div class="tile span-5">
    <p class="tile-title">Deildir</p>
    <DataTable data={divisions} rows=8 compact=true>
      <Column id=tegund title="Tegund" />
      <Column id=deild title="Deild" />
      <Column id=total_bn title="Eignir (ma.kr.)" fmt='#,##0.0' contentType=bar barColor="#7cc4ef" />
      <Column id=foreign_share title="Erlent" fmt=pct0 />
    </DataTable>
  </div>
  <div class="tile span-7">
    <p class="tile-title">Lykiltölur úr ársreikningum</p>
    <DataTable data={annual} rows=8 compact=true>
      <Column id=ár title="Ár" />
      <Column id=tegund title="Tegund" />
      <Column id=raunávöxtun title="Raunávöxtun" fmt=pct2 contentType=delta />
      <Column id=meðaltal_5_ára title="5 ára" fmt=pct2 />
      <Column id=kostnaður title="Kostnaður" fmt=pct2 />
      <Column id=tryggingafræðileg_staða title="Tryggingafr. staða" fmt=pct1 contentType=delta />
      <Column id=sjóðfélagar title="Sjóðfélagar" fmt='#,##0' />
      <Column id=lífeyrisþegar title="Lífeyrisþegar" fmt='#,##0' />
    </DataTable>
  </div>
</div>

<p class="text-xs opacity-60">Ávöxtun, kostnaður og tryggingafræðileg staða eru vegin meðaltöl deilda eftir hreinni eign; sjóðfélagar eru lagðir saman yfir deildir. <a class="underline" href="/lineage/index.html">Sjá hvernig gögnin verða til →</a></p>
