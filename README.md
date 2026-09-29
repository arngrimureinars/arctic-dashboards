# Arctic Analytics – Mælaborð

Public showcase dashboards built as code on open Icelandic data. Every day a GitHub
Action pulls fresh data, transforms and tests it with dbt, builds a static Evidence
site and publishes it to Cloudflare Pages.

```
Hagstofa PxWeb API ──┐
ECB Data API ────────┤
Veðurstofa EDR API ──┤
Seðlabanki (xlsx) ───┼─► extract/ ──► data/raw/*.parquet       (raw zone)
data/files/*.csv ────┘
                                        │
                                        ▼
                     transform/ (dbt-duckdb): staging ─► marts   (tests must pass)
                                        │                 └─► dbt docs → /lineage
                                        ▼
                     dashboards/ (Evidence): SQL + Markdown ─► static site ─► Cloudflare Pages
```

## Run locally

Needs [uv](https://docs.astral.sh/uv/) and Node 22.

```bash
uv sync                          # Python, DuckDB, dbt
npm install --prefix dashboards  # Evidence
make refresh                     # extract → dbt build → lineage docs → dashboard build
make dev                         # dashboard dev server with live reload
```

## Dashboards

| Page | Sources |
|---|---|
| `/verdbolga` – Verðbólga á Íslandi | Hagstofa (VIS01000, VIS01300) |
| `/lifeyrissjodir` – Lífeyrissjóðirnir (overview + one page per fund) | Seðlabanki: quarterly investment breakdown per fund (Q3 2017→), annual financial statement summaries (2019→) |
| `/ferdathjonusta` – Ferðaþjónustan á Íslandi | Hagstofa (SAM01601, SAM02001), ECB (ISK/EUR, USD/EUR), Veðurstofa (8 stations) |

## Sources and resilience

Each source has its own module in `extract/` (`hagstofa.py`, `ecb.py`, `vedur.py`, `sedlabanki.py`, `files.py`)
sharing `extract/common.py`: requests are spaced out and retried on HTTP 429/5xx
(Hagstofa rate-limits), and if a source fails the previous Parquet file is kept. CI
caches `data/raw` between runs, so a flaky API means yesterday's data rather than a
broken site. dbt tests and `dbt source freshness` guard what gets published.

Regions (landshlutar) are the shared dimension across sources: `transform/seeds/regions.csv`
maps each region to its Hagstofa name and a representative Veðurstofa station.

## Add a dataset from Hagstofa

1. Find the table at [px.hagstofa.is](https://px.hagstofa.is) and note its path, e.g.
   `Efnahagur/visitolur/1_vnv/1_vnv/VIS01000.px`.
2. Add it to `extract/sources.yml` (optionally filter dimensions under `query`).
3. `uv run python extract/hagstofa.py` → `data/raw/hagstofa/<name>.parquet`.
4. Declare it in `transform/models/staging/_sources.yml`, add a `stg_` model and a mart
   in `transform/models/marts/`, with descriptions and tests in the `.yml` files.
5. `make transform` – all tests must pass.

For a one-off file, drop a `.csv` or `.xlsx` into `data/files/`; it lands in
`data/raw/files/` and is declared as a dbt source the same way.

## Add a dashboard

1. Expose the mart to Evidence: `dashboards/sources/warehouse/<name>.sql` →
   `select * from marts.<model>`.
2. Create `dashboards/pages/<slug>.md` with SQL blocks and components
   (see `pages/verdbolga.md` and the [Evidence docs](https://docs.evidence.dev)).
3. `make dev` to preview, then open a pull request – the Action builds it as a check.
   Merging to `main` publishes it.

## Notes

- **Evidence version:** pinned to the last open-source release (`@evidence-dev/evidence`
  40.x, MIT). Newer Evidence is a hosted product with a different syntax.
- **DuckDB-WASM from jsDelivr:** Evidence bundles ~35 MB wasm files, over Cloudflare
  Pages' 25 MiB file limit. `dashboards/scripts/cdn-wasm.mjs` points the build at the
  identical files on jsDelivr (same version) after every build.
- **No tracking:** Evidence and dbt usage statistics are switched off, including dbt's
  tracker in the published lineage docs.
- **Pension fund data:** the Central Bank publishes Excel workbooks whose report tabs
  sit on a raw long-format sheet (`Tegundaflokkun` quarterly, `Gögn` annual); only those
  sheets are read. File ids live in `extract/sources.yml` – add the new annual file each
  June. Every fund and asset-class name must be mapped in `transform/seeds/`
  (`pension_fund_names.csv`, `asset_classes.csv`), otherwise the build fails on purpose.

