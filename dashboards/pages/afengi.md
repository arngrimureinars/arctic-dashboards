---
title: Áfengismarkaðurinn
description: Vöruúrval og verð áfengis hjá Vínbúðinni og íslenskum netverslunum – sama flaska borin saman milli verslana.
full_width: true
hide_toc: true
hide_title: true
hide_breadcrumbs: true
sidebar: hide
---

```sql categories
select 'Allt' as category, 0 as o
union all
select category, 1 from (select distinct category from warehouse.alcohol_products where category <> 'Óflokkað')
order by o, category
```

```sql fetched
select strftime(max(fetched_at), '%d.%m.%Y') as day from warehouse.alcohol_products
```

<ReportHero eyebrow="Mælaborð · Áfengi" title="Áfengismarkaðurinn – verð og úrval" subtitle={'Heimildir: vörulistar Vínbúðarinnar, Desma, Vínklúbbsins og Vin.is · Verð sótt ' + (fetched[0]?.day ?? '') + ' · Verð á flösku/dós í krónum'}>
  <div slot="filters" class="flex flex-wrap items-end gap-3">
    <Dropdown data={categories} name=category value=category order="o, category" title="Flokkur" defaultValue="Allt" />
  </div>
</ReportHero>

```sql kpis
with p as (
  select * from warehouse.alcohol_products
  where '${inputs.category.value}' = 'Allt' or category = '${inputs.category.value}'
),
m as (
  select * from warehouse.alcohol_matched
  where '${inputs.category.value}' = 'Allt' or category = '${inputs.category.value}'
)
select
  (select count(*) from p) as products,
  (select count(distinct product_key) from p) as distinct_products,
  (select count(*) from m) as matched,
  (select count(*) from m where price_vinbudin is not null and best_private_vs_vinbudin_pct is not null) as matched_vb,
  (select avg(case when best_private_vs_vinbudin_pct < -0.005 then 1.0 else 0.0 end) from m where best_private_vs_vinbudin_pct is not null) as private_cheaper_share,
  (select median(vs_vinbudin_pct) from p where vs_vinbudin_pct is not null) as median_private_vs_vb,
  'af ' || (select count(*) from m where best_private_vs_vinbudin_pct is not null) || ' flöskum sem Vínbúðin selur líka' as cheaper_note,
  'í ' || (select count(distinct store) from p) || ' verslunum' as store_note,
  'flöskur sem fást á fleiri en einum stað' as matched_note,
  'á sömu flöskum' as median_note,
  (select count(distinct day) from warehouse.alcohol_price_history) as history_days
```

<div class="report-grid">
  <div class="tile span-3">
    <BigValue data={kpis} value=products title="Vörur í úrtakinu" fmt='#,##0' comparison=store_note comparisonTitle="" comparisonDelta=false />
  </div>
  <div class="tile span-3">
    <BigValue data={kpis} value=matched title="Sama flaska í fleiri en einni verslun" fmt='#,##0' comparison=matched_note comparisonTitle="" comparisonDelta=false />
  </div>
  <div class="tile span-3">
    <BigValue data={kpis} value=private_cheaper_share title="Netverslun ódýrari en Vínbúðin" fmt=pct0 comparison=cheaper_note comparisonTitle="" comparisonDelta=false />
  </div>
  <div class="tile span-3">
    <BigValue data={kpis} value=median_private_vs_vb title="Netverslanir miðað við Vínbúðina – miðgildi" fmt='+0.0%;-0.0%' comparison=median_note comparisonTitle="" comparisonDelta=false />
  </div>
</div>

```sql store_index
select store_name, store_order, products, matched_with_vinbudin, median_vs_vinbudin_pct,
       share_cheaper_than_vinbudin as cheaper, share_same_as_vinbudin as same,
       1 - share_cheaper_than_vinbudin - share_same_as_vinbudin as dearer
from warehouse.alcohol_store_category
where category = '${inputs.category.value}' and store <> 'vinbudin' and matched_with_vinbudin > 0
order by store_order
```

```sql assortment
select store_name, store_order, category, products
from warehouse.alcohol_store_category
where category <> 'Allt' and category <> 'Óflokkað'
  and ('${inputs.category.value}' = 'Allt' or category = '${inputs.category.value}')
order by store_order
```

```sql litre_spread
-- Price per litre: quartiles per store for the selected category (boxplot)
select store_name, store_order, count(*) as n,
       quantile_cont(price_per_litre, 0.05) as p05, quantile_cont(price_per_litre, 0.25) as q1,
       median(price_per_litre) as med, quantile_cont(price_per_litre, 0.75) as q3, quantile_cont(price_per_litre, 0.95) as p95
from warehouse.alcohol_products
where ('${inputs.category.value}' = 'Allt' or category = '${inputs.category.value}') and price_per_litre is not null
group by store_name, store_order
order by store_order
```

<script>
  const storeColors = { 'Vínbúðin': '#0e5a8a', 'Desma': '#f59e0b', 'Vínklúbburinn': '#8b5cf6', 'Vin.is': '#14b8a6' };
  const pct = (v, d = 0) => (v == null ? '' : `${(v * 100).toLocaleString('is-IS', { maximumFractionDigits: d })} %`);
  const kr = (v) => (v == null ? '' : `${Math.round(v).toLocaleString('is-IS')} kr.`);

  // Median price difference from Vínbúðin per store (same bottles), signed bars.
  $: indexRows = Array.from(store_index ?? []);
  $: indexConfig = {
    animation: false,
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' }, formatter: (ps) => { const r = indexRows[ps[0].dataIndex]; return `<b>${r.store_name}</b><br/>Miðgildi: ${pct(r.median_vs_vinbudin_pct, 1)}<br/>${r.matched_with_vinbudin} flöskur sem Vínbúðin selur líka`; } },
    grid: { top: 18, left: 4, right: 48, bottom: 4, containLabel: true },
    xAxis: { type: 'value', axisLabel: { formatter: (v) => pct(v), fontSize: 10 }, splitLine: { lineStyle: { opacity: 0.3 } } },
    yAxis: { type: 'category', inverse: true, data: indexRows.map((r) => r.store_name), axisLabel: { fontSize: 11 }, axisTick: { show: false } },
    series: [{
      type: 'bar', barWidth: '55%',
      data: indexRows.map((r) => ({ value: r.median_vs_vinbudin_pct, itemStyle: { color: storeColors[r.store_name], borderRadius: 3 } })),
      label: { show: true, position: 'right', fontSize: 10, formatter: (p) => (p.value > 0 ? '+' : '') + pct(p.value, 1) },
      markLine: { silent: true, symbol: 'none', lineStyle: { color: '#0e5a8a', type: 'dashed' }, label: { formatter: 'Vínbúðin', fontSize: 9, position: 'end' }, data: [{ xAxis: 0 }] }
    }]
  };

  // Cheaper / same / dearer than Vínbúðin, 100 % bars per store.
  $: shareConfig = {
    animation: false,
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' }, valueFormatter: (v) => pct(v) },
    legend: { top: 0, icon: 'circle', itemWidth: 9, itemHeight: 9, itemGap: 14, textStyle: { fontSize: 11 } },
    grid: { top: 26, left: 4, right: 12, bottom: 4, containLabel: true },
    xAxis: { type: 'value', max: 1, axisLabel: { formatter: (v) => pct(v), fontSize: 10 }, splitLine: { show: false } },
    yAxis: { type: 'category', inverse: true, data: indexRows.map((r) => r.store_name), axisLabel: { fontSize: 11 }, axisTick: { show: false } },
    series: [
      { name: 'Ódýrari', key: 'cheaper', color: '#14b8a6' },
      { name: 'Sama verð', key: 'same', color: '#94a3b8' },
      { name: 'Dýrari', key: 'dearer', color: '#f97316' }
    ].map((s) => ({
      name: s.name, type: 'bar', stack: 's', barWidth: '55%', itemStyle: { color: s.color },
      data: indexRows.map((r) => r[s.key]),
      label: { show: true, fontSize: 10, color: '#fff', formatter: (p) => (p.value >= 0.08 ? pct(p.value) : '') }
    }))
  };

  // Assortment: products per store, stacked by category.
  $: assortRows = Array.from(assortment ?? []);
  $: assortStores = [...new Map(assortRows.map((r) => [r.store_name, r.store_order])).entries()].sort((a, b) => a[1] - b[1]).map((e) => e[0]);
  $: assortCats = [...new Set(assortRows.map((r) => r.category))].sort();
  const catColors = { 'Rauðvín': '#881337', 'Hvítvín': '#eab308', 'Rósavín': '#f472b6', 'Freyðivín': '#7dd3fc', 'Bjór': '#d97706',
    'Síder og blöndur': '#84cc16', 'Sterkt áfengi': '#0e5a8a', 'Líkjörar og skot': '#8b5cf6', 'Styrkt og annað vín': '#64748b' };
  $: assortConfig = {
    animation: false,
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
    legend: { top: 0, type: 'scroll', icon: 'circle', itemWidth: 9, itemHeight: 9, itemGap: 10, textStyle: { fontSize: 10 } },
    grid: { top: 30, left: 4, right: 12, bottom: 4, containLabel: true },
    xAxis: { type: 'category', data: assortStores, axisLabel: { fontSize: 11 }, axisTick: { show: false } },
    yAxis: { type: 'value', axisLabel: { fontSize: 10, formatter: (v) => v.toLocaleString('is-IS') }, splitLine: { lineStyle: { opacity: 0.3 } } },
    series: assortCats.map((c, i) => ({
      name: c, type: 'bar', stack: 'a', barWidth: '50%', itemStyle: { color: catColors[c] ?? '#94a3b8' },
      data: assortStores.map((s) => assortRows.find((r) => r.store_name === s && r.category === c)?.products ?? 0)
    }))
  };

  // Price per litre spread per store: boxplot (5–95 % whiskers).
  $: spreadRows = Array.from(litre_spread ?? []);
  $: spreadConfig = {
    animation: false,
    tooltip: { trigger: 'item', formatter: (p) => { const r = spreadRows[p.dataIndex]; return `<b>${r.store_name}</b> (${r.n} vörur)<br/>Miðgildi: ${kr(r.med)}/l<br/>Miðhelmingur: ${kr(r.q1)} – ${kr(r.q3)}/l<br/>5–95 %: ${kr(r.p05)} – ${kr(r.p95)}/l`; } },
    grid: { top: 10, left: 4, right: 16, bottom: 4, containLabel: true },
    xAxis: { type: 'category', data: spreadRows.map((r) => r.store_name), axisLabel: { fontSize: 11 }, axisTick: { show: false } },
    yAxis: { type: 'value', axisLabel: { fontSize: 10, formatter: (v) => `${(v / 1000).toLocaleString('is-IS')} þ.kr.` }, splitLine: { lineStyle: { opacity: 0.3 } } },
    series: [{
      type: 'boxplot', boxWidth: ['25%', '45%'],
      data: spreadRows.map((r) => ({ value: [r.p05, r.q1, r.med, r.q3, r.p95], itemStyle: { color: storeColors[r.store_name] + '33', borderColor: storeColors[r.store_name], borderWidth: 1.5 } }))
    }]
  };
</script>

<div class="report-grid">
  <div class="tile span-4">
    <p class="tile-title">Verð miðað við Vínbúðina – miðgildi á sömu flöskum</p>
    <ECharts config={indexConfig} height="230px" />
  </div>
  <div class="tile span-4">
    <p class="tile-title">Hve oft er netverslunin ódýrari, jafndýr eða dýrari?</p>
    <ECharts config={shareConfig} height="230px" />
  </div>
  <div class="tile span-4">
    <p class="tile-title">Verð á lítra – dreifing eftir verslun (5–95 %)</p>
    <ECharts config={spreadConfig} height="230px" />
  </div>
</div>

```sql matched_table
select name as vara, category as flokkur, volume_ml / 1000 as lítrar, abv / 100 as styrkur,
       price_vinbudin, price_desma, price_vinklubburinn, price_vin_is,
       cheapest_store as ódýrast, spread_pct as verðmunur, stores_selling as verslanir
from warehouse.alcohol_matched
where '${inputs.category.value}' = 'Allt' or category = '${inputs.category.value}'
order by stores_selling desc, spread_pct desc
```

```sql history
select day, store_name, store_order, median_vs_vinbudin_pct
from warehouse.alcohol_price_history
where category = '${inputs.category.value}' and store <> 'vinbudin'
order by day, store_order
```

<div class="report-grid">
  <div class="tile span-8">
    <p class="tile-title">Sama flaska, mismunandi verð – leitaðu að vöru (verð á flösku/dós í kr.)</p>
    <DataTable data={matched_table} rows=15 search=true compact=true>
      <Column id=vara title="Vara" />
      <Column id=lítrar title="L" fmt='0.00#' />
      <Column id=styrkur title="Styrkur" fmt=pct1 />
      <Column id=price_vinbudin title="Vínbúðin" fmt='#,##0' />
      <Column id=price_desma title="Desma" fmt='#,##0' />
      <Column id=price_vinklubburinn title="Vínklúbburinn" fmt='#,##0' />
      <Column id=price_vin_is title="Vin.is" fmt='#,##0' />
      <Column id=ódýrast title="Ódýrast" />
      <Column id=verðmunur title="Munur hæsta og lægsta" fmt=pct0 contentType=bar barColor="#f59e0b" />
    </DataTable>
  </div>
  <div class="span-4 flex flex-col gap-3">
    <div class="tile">
      <p class="tile-title">Vöruúrval eftir verslun og flokki</p>
      <ECharts config={assortConfig} height="230px" />
    </div>
    <div class="tile">
      <p class="tile-title">Verð miðað við Vínbúðina yfir tíma (saga frá 1. október 2026)</p>
      {#if kpis[0]?.history_days >= 3}
        <LineChart data={history} x=day y=median_vs_vinbudin_pct series=store_name yFmt=pct0 chartAreaHeight=140 markers=true colorPalette={['#f59e0b', '#8b5cf6', '#14b8a6']} />
      {:else}
        <p class="text-sm opacity-70 py-6">Verslanirnar sýna aðeins verð dagsins, svo verðsagan safnast upp dag frá degi frá 1. október 2026. Línuritið birtist þegar nokkrir dagar eru komnir.</p>
      {/if}
    </div>
  </div>
</div>

```sql changes
select changed_on, store_name, name, previous_price_isk, price_isk, change_pct
from warehouse.alcohol_price_changes
where changed_on is not null
order by changed_on desc, abs(change_pct) desc
limit 200
```

{#if changes.length > 0}
<div class="tile mb-3">
  <p class="tile-title">Nýjustu verðbreytingar</p>
  <DataTable data={changes} rows=8 compact=true>
    <Column id=changed_on title="Dags." fmt='dd.mm.yyyy' />
    <Column id=store_name title="Verslun" />
    <Column id=name title="Vara" />
    <Column id=previous_price_isk title="Áður" fmt='#,##0' />
    <Column id=price_isk title="Nú" fmt='#,##0' />
    <Column id=change_pct title="Breyting" fmt='+0.0%;-0.0%' contentType=delta downIsGood=true />
  </DataTable>
</div>
{/if}

<details class="text-xs opacity-70">
<summary class="cursor-pointer">Um gögnin – hvað sést og hvað ekki</summary>
<p class="mt-1"><b>Markmið</b>: að lýsa áfengismarkaðnum – verðlagi, verðdreifingu og vöruúrvali – ekki að auglýsa einstakar vörur eða verslanir. Engir tenglar eru á verslanir. <b>Heimildir</b>: opnir vörulistar verslananna, sóttir daglega: vöruleit Vínbúðarinnar og vörustraumar netverslananna Desma, Vínklúbbsins og Vin.is. <b>Ekki með (enn)</b>: Santé, Heimkaup, Veigar (Hagkaup) og fleiri, sem hafa ekki opinn vörustraum; Smáríkið, sem lokar á sjálfvirkar fyrirspurnir. <b>Sama flaska</b>: verslanirnar nota ekki sameiginleg strikamerki, svo vörur eru paraðar sjálfvirkt – eftir vörunúmeri Vínbúðarinnar þar sem það fylgir, annars eftir nafni, stærð, styrk, flokki og þrúgu. Pörunin er yfirfarin en getur skeikað, t.d. milli árganga sem seldir eru undir sama nafni. <b>Verð</b> er á flösku eða dós; kassaverð er deilt niður á einingar. Heimsendingargjöld og afslættir í áskrift eru ekki með. Verð Vínbúðarinnar er það sama um allt land; sérpantaðar vörur eru taldar með. Vín án uppgefinnar stærðar er talið 75 cl. <b>Saga</b>: verslanirnar sýna aðeins verð dagsins, svo verðsaga safnast frá 1. október 2026. <a class="underline" href="/lineage/index.html">Sjá hvernig gögnin verða til →</a></p>
</details>
