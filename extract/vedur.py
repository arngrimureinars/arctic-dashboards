"""Pull monthly weather per station from Veðurstofa Íslands (OGC EDR / CoverageJSON).

One row per station, month and parameter → data/raw/vedur/weather_monthly.parquet.
"""

from __future__ import annotations

from datetime import date

from common import RAW, PoliteSession, load_sources, run_safely, write_parquet

TARGET = RAW / "vedur" / "weather_monthly.parquet"


def fetch_station(session: PoliteSession, config: dict, station: dict) -> list[dict]:
    resp = session.get(
        f"{config['base_url']}/{station['id']}",
        params={
            "parameter-name": ",".join(config["parameters"]),
            "datetime": f"{config['start']}T00:00:00Z/{date.today().isoformat()}T00:00:00Z",
        },
    )
    resp.raise_for_status()
    rows = []
    for coverage in resp.json().get("coverages", []):
        times = coverage["domain"]["axes"]["t"]["values"]
        for param, rng in coverage["ranges"].items():
            for t, value in zip(times, rng["values"]):
                rows.append({"station_id": station["id"], "station_name": station["name"], "month": t[:10], "parameter": param, "value": value})
    return rows


def extract() -> None:
    config = load_sources()["vedur"]
    session = PoliteSession(min_interval=0.5)
    rows = []
    for station in config["stations"]:
        station_rows = fetch_station(session, config, station)
        print(f"  vedur {station['name']}: {len(station_rows)} values")
        rows.extend(station_rows)
    write_parquet(rows, TARGET, source_updated=max(r["month"] for r in rows))
    print(f"vedur.weather_monthly: {len(rows)} rows")


def main() -> bool:
    return run_safely("vedur.weather_monthly", TARGET, extract)


if __name__ == "__main__":
    raise SystemExit(0 if main() else 1)
