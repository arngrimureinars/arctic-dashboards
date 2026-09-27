"""Pull tables from Statistics Iceland's PxWeb API into the raw zone.

Each table in sources.yml is fetched as json-stat2, flattened to a long table (one
row per combination of dimension values) and written to data/raw/hagstofa/<name>.parquet.
A table is skipped when Hagstofa's "updated" timestamp hasn't changed since the
last download, unless --force is given.
"""

from __future__ import annotations

import argparse
import itertools
import json
import tempfile
from datetime import datetime, timezone
from pathlib import Path

import duckdb
import requests
import yaml

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw" / "hagstofa"
STATE = RAW / "_state.json"
TIMEOUT = 60


def table_updated(base_url: str, path: str) -> str | None:
    """Hagstofa's last-updated timestamp for a table, from its folder listing."""
    folder, _, table_id = path.rpartition("/")
    resp = requests.get(f"{base_url}/{folder}/", timeout=TIMEOUT)
    resp.raise_for_status()
    for item in resp.json():
        if item.get("id") == table_id:
            return item.get("updated")
    return None


def fetch(base_url: str, path: str, filters: dict[str, list[str]]) -> dict:
    query = [
        {"code": code, "selection": {"filter": "item", "values": values}}
        for code, values in (filters or {}).items()
    ]
    resp = requests.post(
        f"{base_url}/{path}",
        json={"query": query, "response": {"format": "json-stat2"}},
        timeout=TIMEOUT,
    )
    resp.raise_for_status()
    return resp.json()


def flatten(dataset: dict) -> list[dict]:
    """json-stat2 → rows with <dim> (code), <dim>_label and value columns."""
    dims = []
    for dim_id in dataset["id"]:
        category = dataset["dimension"][dim_id]["category"]
        codes = sorted(category["index"], key=category["index"].get)
        labels = category.get("label", {})
        dims.append((dim_id, [(code, labels.get(code, code)) for code in codes]))

    values = dataset["value"]
    rows = []
    # json-stat2 values are row-major in the order of dataset["id"].
    for i, combo in enumerate(itertools.product(*(cats for _, cats in dims))):
        row = {}
        for (dim_id, _), (code, label) in zip(dims, combo):
            row[dim_id] = code
            row[f"{dim_id}_label"] = label
        row["value"] = values[i] if isinstance(values, list) else values.get(str(i))
        rows.append(row)
    return rows


def write_parquet(rows: list[dict], target: Path, source_updated: str | None) -> None:
    loaded_at = datetime.now(timezone.utc).isoformat()
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False, encoding="utf-8") as tmp:
        for row in rows:
            tmp.write(json.dumps({**row, "_source_updated": source_updated, "_loaded_at": loaded_at}, ensure_ascii=False))
            tmp.write("\n")
    con = duckdb.connect()
    con.execute(
        f"""
        COPY (
            SELECT * REPLACE (CAST(value AS DOUBLE) AS value)
            FROM read_json_auto('{tmp.name}', format = 'newline_delimited', sample_size = -1)
        ) TO '{target}' (FORMAT parquet)
        """
    )
    Path(tmp.name).unlink()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="download even if unchanged")
    args = parser.parse_args()

    config = yaml.safe_load((Path(__file__).parent / "sources.yml").read_text(encoding="utf-8"))["hagstofa"]
    base_url = config["base_url"]
    state = json.loads(STATE.read_text()) if STATE.exists() else {}

    for table in config["tables"]:
        name, path = table["name"], table["path"]
        target = RAW / f"{name}.parquet"
        updated = table_updated(base_url, path)
        if not args.force and target.exists() and updated and state.get(name) == updated:
            print(f"hagstofa.{name}: unchanged since {updated}, skipping")
            continue
        rows = flatten(fetch(base_url, path, table.get("query", {})))
        write_parquet(rows, target, updated)
        state[name] = updated
        print(f"hagstofa.{name}: {len(rows)} rows (source updated {updated})")

    RAW.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(state, indent=2))


if __name__ == "__main__":
    main()
