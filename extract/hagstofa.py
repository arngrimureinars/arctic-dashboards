"""Pull tables from Statistics Iceland's PxWeb API into the raw zone.

Each table in sources.yml is fetched as json-stat2, flattened to a long table (one
row per combination of dimension values) and written to data/raw/hagstofa/<name>.parquet.
A table is skipped when Hagstofa's "updated" timestamp hasn't changed since the
last download, unless --force is given. Hagstofa rate-limits, so requests are spaced
out and retried (see common.PoliteSession).
"""

from __future__ import annotations

import argparse
import itertools

from common import RAW, PoliteSession, State, load_sources, run_safely, write_parquet

TARGET = RAW / "hagstofa"


def table_updated(session: PoliteSession, base_url: str, path: str) -> str | None:
    """Hagstofa's last-updated timestamp for a table, from its folder listing."""
    folder, _, table_id = path.rpartition("/")
    resp = session.get(f"{base_url}/{folder}/")
    resp.raise_for_status()
    for item in resp.json():
        if item.get("id") == table_id:
            return item.get("updated")
    return None


def fetch(session: PoliteSession, base_url: str, path: str, filters: dict[str, list[str]]) -> dict:
    query = [
        {"code": code, "selection": {"filter": "item", "values": values}}
        for code, values in (filters or {}).items()
    ]
    resp = session.post(f"{base_url}/{path}", json={"query": query, "response": {"format": "json-stat2"}})
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
        value = values[i] if isinstance(values, list) else values.get(str(i))
        row["value"] = float(value) if value is not None else None
        rows.append(row)
    return rows


def main() -> bool:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="download even if unchanged")
    args = parser.parse_args()

    config = load_sources()["hagstofa"]
    base_url = config["base_url"]
    state = State(TARGET / "_state.json")
    session = PoliteSession(min_interval=2.0)

    def extract(table: dict) -> None:
        name, path = table["name"], table["path"]
        target = TARGET / f"{name}.parquet"
        updated = table_updated(session, base_url, path)
        if not args.force and target.exists() and updated and state.get(name) == updated:
            print(f"hagstofa.{name}: unchanged since {updated}, skipping")
            return
        rows = flatten(fetch(session, base_url, path, table.get("query", {})))
        write_parquet(rows, target, updated)
        state.set(name, updated)
        print(f"hagstofa.{name}: {len(rows)} rows (source updated {updated})")

    return all(
        run_safely(f"hagstofa.{t['name']}", TARGET / f"{t['name']}.parquet", lambda t=t: extract(t))
        for t in config["tables"]
    )


if __name__ == "__main__":
    raise SystemExit(0 if main() else 1)
