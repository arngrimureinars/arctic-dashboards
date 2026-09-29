---
title: Lífeyrissjóður
hide_title: true
sidebar_link: false
---

```sql fund
select * from warehouse.pension_funds where slug = '${params.fund}'
```

```sql types
select distinct fund_type from warehouse.pension_fund_quarterly f
join warehouse.pension_funds p using (fund_key)
where p.slug = '${params.fund}'
order by fund_type
```

# {fund[0]?.name ?? 'Sjóður'}

{#if fund[0]?.note}
<p class="text-sm opacity-70">{fund[0].note}</p>
{/if}

<ButtonGroup name=ftype title="Tegund">
  <ButtonGroupItem valueLabel="Allt" value="%" default />
  <ButtonGroupItem valueLabel="Samtrygging" value="Samtrygging" />
  <ButtonGroupItem valueLabel="Séreign" value="Séreign" />
</ButtonGroup>

```sql latest_q
select max(quarter_end) as q,
       quarter(max(quarter_end)) || '. ársfj. ' || year(max(quarter_end)) as label
from warehouse.pension_fund_quarterly q
join warehouse.pension_funds p using (fund_key)
where p.slug = '${params.fund}'
```

```sql kpis
with base as (
  select q.* from warehouse.pension_fund_quarterly q
  join warehouse.pension_funds p using (fund_key)
  where p.slug = '${params.fund}' and q.fund_type like '${inputs.ftype}'
),
cur as (
  select sum(total_bn) as total_bn, sum(total_bn * foreign_share) / nullif(sum(total_bn), 0) as foreign_share,
         sum(divisions) as divisions
  from base where quarter_end = (select q from ${latest_q})
),
prev as (select sum(total_bn) as total_bn from base where quarter_end = (select q from ${latest_q}) - interval 1 year)
select cur.*, cur.total_bn / nullif(prev.total_bn, 0) - 1 as yoy from cur, prev
```

<p class="text-sm opacity-70">Staða í lok <b><Value data={latest_q} column=label /></b> · Fjárhæðir í milljörðum króna (ma.kr.) · Tegundir: {types.map(t => t.fund_type).join(' og ')}</p>

<Grid cols=3>
  <BigValue data={kpis} value=total_bn title="Eignir" fmt='#,##0.0" ma.kr."' comparison=yoy comparisonFmt=pct1 comparisonTitle="á einu ári" />
  <BigValue data={kpis} value=foreign_share title="Í erlendum gjaldmiðlum" fmt=pct1 />
  <BigValue data={kpis} value=divisions title="Deildir" />
</Grid>

## Eignasamsetning

```sql classes_now
select c.asset_class as eignaflokkur, c.class_order, sum(c.amount_bn) as ma_kr,
       sum(c.foreign_bn) / nullif(sum(c.amount_bn), 0) as erlent
from warehouse.pension_class_quarterly c
join warehouse.pension_funds p using (fund_key)
where p.slug = '${params.fund}' and c.fund_type like '${inputs.ftype}' and c.quarter_end = (select q from ${latest_q})
group by all
having sum(c.amount_bn) > 0
order by ma_kr desc
```

<BarChart data={classes_now} x=eignaflokkur y=ma_kr swapXY=true sort=false yFmt='#,##0.0' yAxisTitle="ma.kr." chartAreaHeight=360 />

## Þróun frá 2017

```sql history
select c.quarter_end, c.asset_group_name as flokkur, c.group_order, sum(c.amount_bn) as ma_kr
from warehouse.pension_class_quarterly c
join warehouse.pension_funds p using (fund_key)
where p.slug = '${params.fund}' and c.fund_type like '${inputs.ftype}'
group by all
order by c.quarter_end, c.group_order
```

<AreaChart data={history} x=quarter_end y=ma_kr series=flokkur yFmt='#,##0' yAxisTitle="ma.kr." chartAreaHeight=300 />

## Gjaldmiðlar

```sql currencies
select c.currency as gjaldmiðill, sum(c.amount_bn) as ma_kr
from warehouse.pension_currency_quarterly c
join warehouse.pension_funds p using (fund_key)
where p.slug = '${params.fund}' and c.fund_type like '${inputs.ftype}' and c.quarter_end = (select q from ${latest_q})
group by all
having sum(c.amount_bn) > 0
order by ma_kr desc
```

<BarChart data={currencies} x=gjaldmiðill y=ma_kr yFmt='#,##0.0' yAxisTitle="ma.kr." sort=false />

## Deildir

```sql divisions
select d.fund_type as tegund, d.division as deild, d.total_bn, d.foreign_share
from warehouse.pension_division_quarterly d
join warehouse.pension_funds p using (fund_key)
where p.slug = '${params.fund}' and d.fund_type like '${inputs.ftype}' and d.quarter_end = (select q from ${latest_q})
order by d.total_bn desc
```

<DataTable data={divisions} rows=all>
  <Column id=tegund title="Tegund" />
  <Column id=deild title="Deild" />
  <Column id=total_bn title="Eignir (ma.kr.)" fmt='#,##0.0' contentType=bar barColor="#7cc4ef" />
  <Column id=foreign_share title="Erlent" fmt=pct0 />
</DataTable>

## Lykiltölur úr ársreikningum

```sql annual
select cast(a.year as integer)::varchar as ár, a.fund_type as tegund,
       a.real_return_pct / 100 as raunávöxtun,
       a.real_return_5y_pct / 100 as meðaltal_5_ára,
       a.real_return_10y_pct / 100 as meðaltal_10_ára,
       a.cost_pct_of_assets / 100 as kostnaður,
       a.actuarial_total_pct / 100 as tryggingafræðileg_staða,
       a.members as sjóðfélagar, a.pensioners as lífeyrisþegar, a.net_assets_bn
from warehouse.pension_fund_annual a
join warehouse.pension_funds p using (fund_key)
where p.slug = '${params.fund}' and a.fund_type like '${inputs.ftype}'
order by a.year, a.fund_type
```

{#if annual.length > 0}

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

<LineChart data={returns_chart} x=ár y={['raunávöxtun', 'meðaltal_5_ára', 'meðaltal_10_ára']} xFmt=yyyy yFmt=pct1 title={'Hrein raunávöxtun – ' + (returns_chart[0]?.fund_type ?? '')} chartAreaHeight=260 />

<DataTable data={annual} rows=all>
  <Column id=ár title="Ár" />
  <Column id=tegund title="Tegund" />
  <Column id=raunávöxtun title="Raunávöxtun" fmt=pct2 contentType=delta />
  <Column id=meðaltal_5_ára title="5 ára meðaltal" fmt=pct2 />
  <Column id=meðaltal_10_ára title="10 ára meðaltal" fmt=pct2 />
  <Column id=kostnaður title="Kostnaður (% eigna)" fmt=pct2 />
  <Column id=tryggingafræðileg_staða title="Tryggingafr. staða" fmt=pct1 contentType=delta />
  <Column id=sjóðfélagar title="Sjóðfélagar" fmt='#,##0' />
  <Column id=lífeyrisþegar title="Lífeyrisþegar" fmt='#,##0' />
</DataTable>

<p class="text-xs opacity-60">Ávöxtun, kostnaður og tryggingafræðileg staða eru vegin meðaltöl deilda eftir hreinni eign. Sjóðfélagar eru lagðir saman yfir deildir, svo sami einstaklingur getur verið talinn oftar en einu sinni.</p>

{:else}

<p class="opacity-70">Engar lykiltölur úr ársreikningum fyrir þennan aðila.</p>

{/if}

---

<p class="text-sm opacity-70"><a href="/lifeyrissjodir">← Allir lífeyrissjóðir</a> · Heimild: Seðlabanki Íslands · <a href="/lineage/index.html">Sjá hvernig gögnin verða til →</a></p>
