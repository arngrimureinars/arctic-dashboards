# Pipeline: extract → transform (dbt) → docs (lineage) → dashboards (Evidence).
# `make refresh` runs everything; `make dev` starts the dashboard dev server.

export send_anonymous_usage_stats = no
export DBT_SEND_ANONYMOUS_USAGE_STATS = false

DBT_ARGS = --project-dir transform --profiles-dir transform

.PHONY: refresh extract transform docs dashboards dev clean

refresh: extract transform docs dashboards

# Each source keeps its previous data if it fails, so one flaky API doesn't stop the rest.
extract:
	uv run python extract/hagstofa.py
	uv run python extract/ecb.py
	uv run python extract/vedur.py
	uv run python extract/files.py

transform:
	uv run dbt build $(DBT_ARGS)

docs:
	uv run dbt docs generate --static $(DBT_ARGS)
	mkdir -p dashboards/static/lineage
	cp transform/target/static_index.html dashboards/static/lineage/index.html

dashboards:
	cd dashboards && npm run sources && npm run build

dev:
	cd dashboards && npm run sources && npm run dev

clean:
	rm -rf data/raw data/warehouse.duckdb transform/target transform/logs dashboards/build dashboards/static/lineage
