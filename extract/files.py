"""Load hand-delivered files from data/files/ into the raw zone.

Every .csv or .xlsx file becomes data/raw/files/<file name>.parquet (first sheet for
Excel). Column names and types are kept as DuckDB infers them; dbt does the cleaning.
"""

from __future__ import annotations

from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "data" / "files"
RAW = ROOT / "data" / "raw" / "files"


def main() -> None:
    files = sorted(p for p in SOURCE.glob("*") if p.suffix.lower() in {".csv", ".xlsx"})
    if not files:
        print("files: nothing in data/files/")
        return
    RAW.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    for f in files:
        target = RAW / f"{f.stem}.parquet"
        if f.suffix.lower() == ".csv":
            reader = f"read_csv_auto('{f}')"
        else:
            con.execute("INSTALL excel; LOAD excel;")
            reader = f"read_xlsx('{f}')"
        con.execute(f"COPY (SELECT * FROM {reader}) TO '{target}' (FORMAT parquet)")
        count = con.execute(f"SELECT count(*) FROM '{target}'").fetchone()[0]
        print(f"files.{f.stem}: {count} rows")


if __name__ == "__main__":
    main()
