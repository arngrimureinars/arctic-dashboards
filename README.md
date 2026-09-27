# Arctic Analytics – Mælaborð

Public showcase dashboards built as code on open Icelandic data. Every day a GitHub
Action pulls fresh data, transforms and tests it with dbt, builds a static Evidence
site and publishes it to Cloudflare Pages.

```
Hagstofa PxWeb API ─┐
data/files/*.csv ───┴─► extract/ ──► data/raw/*.parquet        (raw zone)
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
