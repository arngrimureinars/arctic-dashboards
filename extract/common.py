"""Shared helpers for the extract step: a polite HTTP client and the raw-zone writer."""

from __future__ import annotations

import json
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

import duckdb
import requests
import yaml

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
TIMEOUT = 60


def load_sources() -> dict:
    return yaml.safe_load((Path(__file__).parent / "sources.yml").read_text(encoding="utf-8"))


class PoliteSession(requests.Session):
    """requests.Session that waits between calls and retries 429/5xx.

    Hagstofa in particular rate-limits (HTTP 429 with Retry-After), so every
    request waits at least `min_interval` seconds after the previous one.
    """

    def __init__(self, min_interval: float = 1.0, retries: int = 6):
        super().__init__()
        self.min_interval = min_interval
        self.retries = retries
        self._last = 0.0
        self.headers["User-Agent"] = "arctic-dashboards (+https://github.com/arngrimureinars/arctic-dashboards)"

    def request(self, method, url, **kwargs):
        kwargs.setdefault("timeout", TIMEOUT)
        for attempt in range(self.retries + 1):
            wait = self.min_interval - (time.monotonic() - self._last)
            if wait > 0:
                time.sleep(wait)
            self._last = time.monotonic()
            resp = super().request(method, url, **kwargs)
            if resp.status_code != 429 and resp.status_code < 500:
                return resp
            if attempt == self.retries:
                return resp
            retry_after = resp.headers.get("Retry-After", "")
            delay = float(retry_after) if retry_after.isdigit() else 2 ** attempt * 5
            print(f"  {resp.status_code} from {url.split('?')[0]}, retrying in {delay:.0f}s")
            time.sleep(delay)
        return resp


def write_parquet(rows: list[dict], target: Path, source_updated: str | None = None) -> None:
    """Write rows to Parquet with _source_updated/_loaded_at columns (types inferred by DuckDB)."""
    if not rows:
        raise ValueError(f"No rows to write to {target}")
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
            SELECT * FROM read_json_auto('{tmp.name}', format = 'newline_delimited', sample_size = -1)
        ) TO '{target}' (FORMAT parquet)
        """
    )
    Path(tmp.name).unlink()


class State:
    """Remembers per-table source timestamps so unchanged tables can be skipped."""

    def __init__(self, path: Path):
        self.path = path
        self.data = json.loads(path.read_text()) if path.exists() else {}

    def get(self, key: str):
        return self.data.get(key)

    def set(self, key: str, value) -> None:
        self.data[key] = value
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(json.dumps(self.data, indent=2))


def run_safely(name: str, target: Path, fn) -> bool:
    """Run one table's extract; on failure keep the previous file (if any) and carry on.

    Returns False when the table failed and there is no previous file to fall back on.
    """
    try:
        fn()
        return True
    except Exception as exc:  # noqa: BLE001 – one flaky source shouldn't stop the others
        if target.exists():
            print(f"WARNING {name}: {exc!s:.200} – keeping previous data")
            return True
        print(f"ERROR {name}: {exc!s:.200} – no previous data")
        return False
