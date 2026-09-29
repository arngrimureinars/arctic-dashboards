"""Pull Nasdaq CSD Iceland's monthly top-20 shareholder lists into the raw zone.

The CSD publishes a market notice each month ("monthly report on the 20 largest
shareholders and shares held by issuer") with an Excel attachment listing the 20 largest
registered owners of each covered company, with the owner's kennitala. Each month is
written to data/raw/nasdaq_csd/top20_<record date>.parquet; months already on disk are
skipped, since a published month doesn't change.
"""

from __future__ import annotations

import io
from datetime import date, datetime, timedelta

import xlrd
from openpyxl import load_workbook

from common import RAW, PoliteSession, load_sources, run_safely, write_parquet

TARGET = RAW / "nasdaq_csd"
COLUMNS = ["record_date", "ticker", "isin", "owner_name", "owner_id", "shares", "total_issued", "pct"]
PAGE = 100


def list_reports(session: PoliteSession, config: dict) -> list[dict]:
    """All CSD top-20 announcements, oldest first, as {release, url, file_name}."""
    reports, start = [], 0
    while True:
        resp = session.get(config["api_url"], params={**config["query"], "limit": PAGE, "start": start})
        resp.raise_for_status()
        items = resp.json()["results"]["item"]
        for item in items:
            if not all(s in item["headline"] for s in config["headline_must_contain"]):
                continue
            for att in item.get("attachment", []):
                name = att["fileName"].lower()
                if any(s in name for s in config["attachment_name_contains"]) and not any(
                    s in name for s in config.get("attachment_name_excludes", [])
                ):
                    reports.append({"release": item["releaseTime"][:10], "url": att["attachmentUrl"], "file_name": att["fileName"]})
                    break
        if len(items) < PAGE:
            break
        start += PAGE
    return sorted(reports, key=lambda r: r["release"])


def _excel_date(value, datemode: int = 0) -> str:
    if isinstance(value, datetime):
        return value.date().isoformat()
    if isinstance(value, (int, float)):
        return (date(1899, 12, 30) + timedelta(days=int(value))).isoformat()
    return datetime.strptime(str(value).strip()[:10], "%Y-%m-%d").date().isoformat()


def parse(content: bytes) -> list[dict]:
    if content[:2] == b"PK":  # .xlsx
        sheet = load_workbook(io.BytesIO(content), read_only=True, data_only=True).worksheets[0]
        values = [list(r) for r in sheet.iter_rows(values_only=True)]
    else:  # legacy .xls
        sheet = xlrd.open_workbook(file_contents=content).sheet_by_index(0)
        values = [sheet.row_values(r) for r in range(sheet.nrows)]
    header = [str(v).strip().lower() for v in values[0]]
    if header[:3] != ["record date", "instrument short name", "isin code"]:
        raise ValueError(f"unexpected header {values[0]}")
    rows = []
    for v in values[1:]:
        if not v or v[1] in (None, ""):
            continue
        row = dict(zip(COLUMNS, v[:8]))
        row["record_date"] = _excel_date(row["record_date"])
        row["ticker"] = str(row["ticker"]).strip()
        row["owner_name"] = str(row["owner_name"]).strip()
        owner_id = row["owner_id"]
        row["owner_id"] = str(int(owner_id)) if isinstance(owner_id, float) else str(owner_id or "").strip()
        row["owner_id"] = row["owner_id"].zfill(10) if row["owner_id"].isdigit() else row["owner_id"]
        for k in ("shares", "total_issued", "pct"):
            row[k] = float(row[k]) if row[k] not in (None, "") else None
        rows.append(row)
    return rows


def main() -> bool:
    config = load_sources()["nasdaq_csd"]
    session = PoliteSession(min_interval=0.5)
    reports = list_reports(session, config)
    print(f"nasdaq_csd: {len(reports)} monthly reports ({reports[0]['release']} → {reports[-1]['release']})")
    existing = {p.stem for p in TARGET.glob("top20_*.parquet")}
    released = {p.name for p in TARGET.glob("_released_*")}
    ok = True
    for report in reports:
        marker = f"_released_{report['release']}"
        if marker in released:
            continue

        def fetch(report=report, marker=marker):
            resp = session.get(report["url"])
            resp.raise_for_status()
            rows = parse(resp.content)
            record_date = rows[0]["record_date"]
            write_parquet(rows, TARGET / f"top20_{record_date}.parquet", source_updated=report["release"])
            (TARGET / marker).touch()
            print(f"  top20_{record_date}: {len(rows)} rows, {len({r['ticker'] for r in rows})} companies")

        ok &= run_safely(f"nasdaq_csd.{report['release']}", TARGET / marker, fetch)
    new = {p.stem for p in TARGET.glob("top20_*.parquet")} - existing
    print(f"nasdaq_csd: {len(new)} new month(s)")
    return ok


if __name__ == "__main__":
    raise SystemExit(0 if main() else 1)
