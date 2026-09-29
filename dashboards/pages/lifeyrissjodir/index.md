---
title: Lífeyrissjóðirnir
description: Eignir allra íslenskra lífeyrissjóða og vörsluaðila séreignar eftir eignaflokkum, gjaldmiðlum og sjóðum.
---

<ButtonGroup name=ftype title="Tegund">
  <ButtonGroupItem valueLabel="Allt" value="%" default />
  <ButtonGroupItem valueLabel="Samtrygging" value="Samtrygging" />
  <ButtonGroupItem valueLabel="Séreign" value="Séreign" />
</ButtonGroup>

```sql latest_q
select max(quarter_end) as q,
       quarter(max(quarter_end)) || '. ársfj. ' || year(max(quarter_end)) as label
from warehouse.pension_fund_quarterly
```

```sql kpis
with cur as (
  select sum(total_bn) as total_bn, sum(total_bn * foreign_share) / sum(total_bn) as foreign_share,
         count(distinct fund_key) as funds
  from warehouse.pension_fund_quarterly
  where quarter_end = (select q from ${latest_q}) and fund_type like '${inputs.ftype}'
),
prev as (
  select sum(total_bn) as total_bn from warehouse.pension_fund_quarterly
  where quarter_end = (select q from ${latest_q}) - interval 1 year and fund_type like '${inputs.ftype}'
)
select cur.*, cur.total_bn / prev.total_bn - 1 as yoy from cur, prev
```

<p class="text-sm opacity-70">
Staða í lok <b><Value data={latest_q} column=label /></b> · Heimild: Seðlabanki Íslands (fjármálaeftirlit), sundurliðun fjárfestinga og samantekt úr ársreikningum lífeyrissjóða · Fjárhæðir í milljörðum króna (ma.kr.) á bókfærðu virði
</p>

<Grid cols=3>
  <BigValue data={kpis} value=total_bn title="Heildareignir" fmt='#,##0" ma.kr."' comparison=yoy comparisonFmt=pct1 comparisonTitle="á einu ári" />
  <BigValue data={kpis} value=foreign_share title="Í erlendum gjaldmiðlum" fmt=pct1 />
  <BigValue data={kpis} value=funds title="Sjóðir og vörsluaðilar" />
</Grid>

## Eignasamsetning hvers sjóðs

Hlutfallsleg skipting eigna eftir eignaflokkum. Sjóðunum er raðað eftir stærð.

```sql fund_mix
with mix as (
  select f.short_name as sjóður, c.asset_group_name as flokkur, c.group_order, sum(c.amount_bn) as ma_kr
  from warehouse.pension_class_quarterly c
  join warehouse.pension_funds f using (fund_key)
  where c.quarter_end = (select q from ${latest_q}) and c.fund_type like '${inputs.ftype}'
  group by all
)
select *, sum(ma_kr) over (partition by sjóður) as fund_total
from mix
where ma_kr > 0
order by fund_total desc, group_order
```

<BarChart
  data={fund_mix}
  x=sjóður
  y=ma_kr
  series=flokkur
  type=stacked100
  swapXY=true
  sort=false
  chartAreaHeight=560
  yFmt=pct0
/>

## Samanburður sjóða

Smelltu á sjóð til að sjá nánari sundurliðun. Ávöxtun og kostnaður eru úr ársreikningum síðasta árs (vegið meðaltal deilda).

```sql ranking
with q as (
  select fund_key, sum(total_bn) as total_bn, sum(total_bn * foreign_share) / sum(total_bn) as foreign_share
  from warehouse.pension_fund_quarterly
  where quarter_end = (select q from ${latest_q}) and fund_type like '${inputs.ftype}'
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
select f.name as sjóður, '/lifeyrissjodir/' || f.slug as link, f.kind as tegund,
       q.total_bn, q.foreign_share, a.return_5y, a.cost, a.members
from q
join warehouse.pension_funds f using (fund_key)
left join a using (fund_key)
order by q.total_bn desc
```

<DataTable data={ranking} link=link rows=all>
  <Column id=sjóður title="Sjóður" />
  <Column id=tegund title="Tegund" />
  <Column id=total_bn title="Eignir (ma.kr.)" fmt='#,##0' contentType=bar barColor="#7cc4ef" />
  <Column id=foreign_share title="Erlent" fmt=pct0 />
  <Column id=return_5y title="Raunávöxtun 5 ár" fmt=pct2 contentType=delta />
  <Column id=cost title="Kostnaður" fmt=pct2 />
  <Column id=members title="Sjóðfélagar" fmt='#,##0' />
</DataTable>

## Eignasamsetning kerfisins frá 2017

```sql system_mix
select quarter_end, asset_group_name as flokkur, group_order, sum(amount_bn) as ma_kr
from warehouse.pension_class_quarterly
where fund_type like '${inputs.ftype}'
group by all
order by quarter_end, group_order
```

<AreaChart data={system_mix} x=quarter_end y=ma_kr series=flokkur yFmt='#,##0' yAxisTitle="ma.kr." chartAreaHeight=320 />

## Erlendar eignir eftir gjaldmiðlum

```sql currencies
select currency as gjaldmiðill, sum(amount_bn) as ma_kr
from warehouse.pension_currency_quarterly
where quarter_end = (select q from ${latest_q}) and fund_type like '${inputs.ftype}' and currency <> 'ISK'
group by all
order by ma_kr desc
```

<BarChart data={currencies} x=gjaldmiðill y=ma_kr yFmt='#,##0' yAxisTitle="ma.kr." sort=false />

## Allir sjóðir

```sql fund_links
select name, slug from warehouse.pension_funds order by name
```

<ul class="columns-1 sm:columns-2 lg:columns-3 text-sm">
{#each fund_links as f}
  <li class="py-0.5"><a class="text-primary hover:underline" href="/lifeyrissjodir/{f.slug}">{f.name}</a></li>
{/each}
</ul>

---

<p class="text-sm opacity-70">
<b>Um gögnin.</b> Sundurliðun fjárfestinga er ársfjórðungsleg skýrsla lífeyrissjóða og vörsluaðila séreignarsparnaðar til fjármálaeftirlits Seðlabankans, flokkuð eftir fjárfestingarheimildum laga nr. 129/1997 (A.a–F.b), og nær aftur til 3. ársfj. 2017. Ávöxtun, kostnaður og sjóðfélagar eru úr samantekt Seðlabankans úr ársreikningum (frá 2019). Almenni lífeyrissjóðurinn og Lífsverk sameinuðust 2026. <a href="/lineage/index.html">Sjá hvernig gögnin verða til →</a>
</p>
