"""Pull exchange-rate series from the ECB Data API (SDMX CSV) into data/raw/ecb/."""

from __future__ import annotations

import csv
import io

from common import RAW, PoliteSession, load_sources, run_safely, write_parquet

TARGET = RAW / "ecb"


def fetch_series(session: PoliteSession, base_url: str, series: dict) -> None:
    resp = session.get(
        f"{base_url}/{series['key']}",
        params={"format": "csvdata", "startPeriod": series.get("start", "2010-01")},
    )
    resp.raise_for_status()
    rows = [
        {"time_period": r["TIME_PERIOD"], "value": float(r["OBS_VALUE"]), "currency": r["CURRENCY"], "obs_status": r.get("OBS_STATUS")}
        for r in csv.DictReader(io.StringIO(resp.text))
        if r.get("OBS_VALUE")
    ]
    target = TARGET / f"{series['name']}.parquet"
    write_parquet(rows, target, source_updated=max(r["time_period"] for r in rows))
    print(f"ecb.{series['name']}: {len(rows)} rows (latest {rows[-1]['time_period']})")


def main() -> bool:
    config = load_sources()["ecb"]
    session = PoliteSession(min_interval=0.5)
    return all(
        run_safely(f"ecb.{s['name']}", TARGET / f"{s['name']}.parquet", lambda s=s: fetch_series(session, config["base_url"], s))
        for s in config["series"]
    )


if __name__ == "__main__":
    raise SystemExit(0 if main() else 1)
