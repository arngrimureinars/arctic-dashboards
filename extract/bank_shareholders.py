"""Snapshot the shareholder lists that Íslandsbanki and Arion banki publish on their websites.

Both banks must publish every owner above 1 % (Act 161/2002, art. 19) but only show the
current list, so each run writes this month's snapshot to
data/snapshots/bank_shareholders/<TICKER>_<YYYY-MM>.csv (overwritten until the month ends;
CI commits these files so history builds up), then combines all snapshots into
data/raw/bank_shareholders/owners.parquet.
"""

from __future__ import annotations

import csv
import html
import json
import re
from datetime import date

from common import RAW, ROOT, PoliteSession, load_sources, run_safely, write_parquet

SNAPSHOTS = ROOT / "data" / "snapshots" / "bank_shareholders"
TARGET = RAW / "bank_shareholders" / "owners.parquet"
FIELDS = ["snapshot_date", "ticker", "owner_name", "owner_id", "shares", "pct", "holding_date"]


def islandsbanki(session: PoliteSession, cfg: dict) -> list[dict]:
    holdings = session.get(cfg["api_url"])
    holdings.raise_for_status()
    # The page embeds {"owner_name", "owner_id", "owner_ssn"} for each owner; ssn = kennitala.
    page = session.get(cfg["page_url"])
    page.raise_for_status()
    ssn = {m.group(1): m.group(2) for m in re.finditer(r'"owner_id":"(\d+)","owner_ssn":"(\d*)"', page.text)}
    return [
        {
            "owner_name": r["ownerName"].strip(),
            "owner_id": ssn.get(str(r["ownerId"]), ""),
            "shares": r["numOfShares"],
            "pct": r["capital"] * 100,
            "holding_date": r.get("holdingDate"),
        }
        for r in holdings.json()
    ]


ROW = re.compile(r"<tr[^>]*>(.*?)</tr>", re.S)
CELL = re.compile(r"<t[dh][^>]*>(.*?)</t[dh]>", re.S)


def arion(session: PoliteSession, cfg: dict) -> list[dict]:
    page = session.get(cfg["page_url"])
    page.raise_for_status()
    rows = []
    for tr in ROW.findall(page.text):
        cells = CELL.findall(tr)
        if len(cells) < 3:
            continue
        name = html.unescape(re.sub(r"<[^>]+>", "", cells[0])).strip()
        shares = re.sub(r"[^\d]", "", re.sub(r"<[^>]+>", "", cells[1]))
        pct = re.sub(r"<[^>]+>", "", cells[2]).strip().replace("%", "").replace(".", "").replace(",", ".")
        if not shares or not re.fullmatch(r"[\d.]+", pct) or name.lower().startswith("number of issued"):
            continue
        kt = re.search(r"kennitala/(\d{10})", tr)
        rows.append({"owner_name": name, "owner_id": kt.group(1) if kt else "", "shares": int(shares), "pct": float(pct), "holding_date": None})
    if len(rows) < 5:
        raise ValueError(f"only {len(rows)} shareholder rows found – page layout changed?")
    return rows


def main() -> bool:
    config = load_sources()["bank_shareholders"]
    session = PoliteSession(min_interval=1.0)
    today = date.today()
    SNAPSHOTS.mkdir(parents=True, exist_ok=True)

    def snapshot(name: str, fetch) -> None:
        cfg = config[name]
        rows = fetch(session, cfg)
        path = SNAPSHOTS / f"{cfg['ticker']}_{today:%Y-%m}.csv"
        with path.open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=FIELDS)
            w.writeheader()
            for r in rows:
                w.writerow({"snapshot_date": today.isoformat(), "ticker": cfg["ticker"], **r})
        print(f"bank_shareholders.{cfg['ticker']}: {len(rows)} owners → {path.name}")

    ok = all([
        run_safely("bank_shareholders.ISB", SNAPSHOTS / f"ISB_{today:%Y-%m}.csv", lambda: snapshot("islandsbanki", islandsbanki)),
        run_safely("bank_shareholders.ARION", SNAPSHOTS / f"ARION_{today:%Y-%m}.csv", lambda: snapshot("arion", arion)),
    ])

    rows = []
    for path in sorted(SNAPSHOTS.glob("*.csv")):
        with path.open(encoding="utf-8") as f:
            rows += list(csv.DictReader(f))
    for r in rows:
        r["shares"] = float(r["shares"])
        r["pct"] = float(r["pct"])
        r["holding_date"] = r["holding_date"] or None
    if rows:
        write_parquet(rows, TARGET, source_updated=max(r["snapshot_date"] for r in rows))
        print(f"bank_shareholders: {len(rows)} rows from {len(list(SNAPSHOTS.glob('*.csv')))} snapshot(s)")
    return ok


if __name__ == "__main__":
    raise SystemExit(0 if main() else 1)
