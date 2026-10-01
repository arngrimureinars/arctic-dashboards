"""Pull the product catalogues and prices of Icelandic alcohol retailers into the raw zone.

One adapter per shop platform (Vínbúðin's own search API, Shopify, WooCommerce) turns each
catalogue into the same row shape; volume, ABV and pack size are parsed from the product
title where the shop has no structured field for them. Each store lands in
data/raw/alcohol/<store>.parquet.

The shops only show today's prices, so price history is kept as a change log in
data/snapshots/alcohol/prices_<date>.parquet (committed by CI): the first file holds every
product, later files only the products that are new, changed price or stock, or were
delisted (listed = false).
"""

from __future__ import annotations

import html
import json
import re
from datetime import date, datetime, timezone

import duckdb

from common import RAW, ROOT, PoliteSession, load_sources, run_safely, write_parquet

TARGET = RAW / "alcohol"
SNAPSHOTS = ROOT / "data" / "snapshots" / "alcohol"
SNAPSHOT_COLUMNS = ["store", "store_product_id", "name", "price_isk", "regular_price_isk", "in_stock", "listed"]

VOLUME = re.compile(r"(\d+(?:[.,]\d+)?)\s*(ml|cl|ltr|lítr|l)\b", re.I)
ABV = re.compile(r"(\d{1,2}(?:[.,]\d+)?)\s*%")
# Most explicit first: "12stk", "6 pk", "kassinn er 12 stykki", then "x24" / "x 24" (not "Boli X 4,8%").
PACKS = [
    re.compile(r"\b(\d{1,2})\s*(?:stk|pk|pack)\b", re.I),
    re.compile(r"kassinn er (\d{1,2}) st", re.I),
    re.compile(r"\b(\d{1,2})\s*x\s*\d+(?:[.,]\d+)?\s*(?:ml|cl)\b", re.I),  # 24x330ml, 5x20ml
    re.compile(r"\b(\d{1,2})\s*x\b(?!\s*\d)", re.I),
    re.compile(r"\bx\s*(\d{1,2})\b(?![.,]\d|\s*%)", re.I),
]
VINTAGE = re.compile(r"\((?:19|20)\d\d\)|\b(?:19|20)\d\d\b")


def _num(text: str) -> float:
    return float(text.replace(",", "."))


def parse_volume_ml(text: str) -> float | None:
    """'700ml' → 700, '0.5L' → 500, '75 cl' → 750; the last match wins ('5x20ml' → 20)."""
    matches = VOLUME.findall(text or "")
    if not matches:
        return None
    value, unit = matches[-1]
    unit = unit.lower()
    ml = _num(value) * (1 if unit == "ml" else 10 if unit == "cl" else 1000)
    return ml if 20 <= ml <= 10000 else None


def parse_abv(text: str) -> float | None:
    m = ABV.search(text or "")
    if not m:
        return None
    abv = _num(m.group(1))
    return abv if 0 <= abv <= 80 else None


def parse_pack(text: str) -> int:
    """Units per sale: '12stk', '6 pk', 'x24', 'Kassinn er 12 stykki' → n; otherwise 1."""
    for pattern in PACKS:
        if m := pattern.search(text or ""):
            n = int(m.group(1))
            return n if 2 <= n <= 48 else 1
    return 1


def clean(text: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", text or ""))).strip()


def vinbudin(session: PoliteSession, cfg: dict) -> list[dict]:
    rows, skip = [], 0
    while True:
        resp = session.get(
            cfg["api_url"],
            params={"category": "", "skip": skip, "count": cfg["page_size"], "orderBy": "name asc"},
            headers={"Content-Type": "application/json; charset=utf-8"},
        )
        resp.raise_for_status()
        page = json.loads(resp.json()["d"])
        for p in page["data"]:
            rows.append({
                "store_product_id": str(p["ProductID"]),
                "name": p["ProductName"].strip(),
                "producer": (p.get("ProductProducer") or "").strip(),
                "category_raw": [p["ProductCategory"]["name"]],
                "volume_ml": p["ProductBottledVolume"] or None,
                "abv": p["ProductAlchoholVolume"],
                "pack_size": 1,
                "price_isk": p["ProductPrice"],
                "regular_price_isk": p["ProductPrice"],
                "ean": None,
                "sku": str(p["ProductID"]),
                "country": (p.get("ProductCountryOfOrigin") or "").strip(),
                "container": p.get("ProductContainerType"),
                "url": f"https://www.vinbudin.is/heim/vorur/stoek-vara.aspx/?productid={p['ProductID']:0>5}",
                # Special-order products (sérpöntun) aren't on the shelves; the rest are.
                "in_stock": bool(p["ProductIsAvailableInStores"]),
                "special_order": bool(p["ProductIsSpecialOrder"]),
            })
        if len(page["data"]) < cfg["page_size"]:
            break
        skip += cfg["page_size"]
    if len(rows) != page["total"]:
        raise ValueError(f"got {len(rows)} of {page['total']} products")
    return rows


def shopify(session: PoliteSession, cfg: dict) -> list[dict]:
    exclude = {t.lower() for t in cfg.get("exclude_types", [])}
    rows, page = [], 1
    while True:
        resp = session.get(f"{cfg['base_url']}/products.json", params={"limit": 250, "page": page})
        resp.raise_for_status()
        products = resp.json()["products"]
        for p in products:
            if p["product_type"].strip().lower() in exclude:
                continue
            # Single bottles: the first variant (Vínklúbburinn also sells 6-bottle cases).
            v = p["variants"][0]
            title = clean(p["title"])
            text = f"{title} {v['title'] if v['title'] != 'Default Title' else ''}"
            price = float(v["price"])
            regular = float(v["compare_at_price"]) if v.get("compare_at_price") else price
            sku = (v.get("sku") or "").strip()
            volume = parse_volume_ml(text) or (cfg.get("default_volume_ml") if not re.search(r"magnum", text, re.I) else 1500)
            rows.append({
                "store_product_id": str(p["id"]),
                "name": title,
                "producer": p.get("vendor") or "",
                "category_raw": [p["product_type"], *p["tags"]],
                "volume_ml": volume,
                "abv": parse_abv(text),
                "pack_size": parse_pack(text),
                "price_isk": price,
                "regular_price_isk": max(regular, price),
                "ean": sku if re.fullmatch(r"\d{13}", sku) else None,
                "sku": sku or None,
                "country": None,
                "container": None,
                "url": f"{cfg['base_url']}/products/{p['handle']}",
                "in_stock": any(x["available"] for x in p["variants"]),
                "special_order": False,
            })
        if len(products) < 250:
            break
        page += 1
    return rows


def woocommerce(session: PoliteSession, cfg: dict) -> list[dict]:
    rows, page = [], 1
    while True:
        resp = session.get(f"{cfg['base_url']}/wp-json/wc/store/v1/products", params={"per_page": 100, "page": page})
        resp.raise_for_status()
        products = resp.json()
        for p in products:
            attrs = {a["name"]: ", ".join(t["name"] for t in a["terms"]) for a in p.get("attributes", [])}
            name = clean(p["name"])
            description = clean(p.get("short_description", "") + " " + p.get("description", ""))
            categories = [clean(c["name"]) for c in p["categories"]]
            # Beer is often sold by the case; the case size is only in the description.
            pack_text = f"{name} {description}" if {"Bjór", "Blandaðir drykkir"} & set(categories) else name
            minor = p["prices"]["currency_minor_unit"]
            price = int(p["prices"]["price"]) / 10**minor
            regular = int(p["prices"]["regular_price"]) / 10**minor
            rows.append({
                "store_product_id": str(p["id"]),
                "name": name,
                "producer": ", ".join(b["name"] for b in p.get("brands", [])),
                "category_raw": categories,
                # The size is often only in the URL slug ("…-250-ml-11/").
                "volume_ml": parse_volume_ml(attrs.get("Flöskustærð", "") or attrs.get("Stærð", ""))
                or parse_volume_ml(name)
                or parse_volume_ml(re.sub(r"(\d)-(\d)", r"\1,\2", p["slug"]).replace("-", " ")),
                "abv": parse_abv(attrs.get("Áfengisinnihald", "")) or parse_abv(name),
                # Some single cans also mention the case size, so a pack below 150 kr a unit isn't one.
                "pack_size": pack if (pack := parse_pack(pack_text)) == 1 or price / pack >= 150 else 1,
                "price_isk": price,
                "regular_price_isk": max(regular, price),
                "ean": p["sku"] if re.fullmatch(r"\d{13}", p.get("sku") or "") else None,
                "sku": p.get("sku") or None,
                "country": attrs.get("Land"),
                "container": None,
                "url": p["permalink"],
                "in_stock": bool(p["is_in_stock"]),
                "special_order": False,
            })
        if len(products) < 100:
            break
        page += 1
    return rows


ADAPTERS = {"vinbudin": vinbudin, "shopify": shopify, "woocommerce": woocommerce}


def write_snapshot(today: date) -> None:
    """Append today's price changes to the change log in data/snapshots/alcohol/."""
    SNAPSHOTS.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    cols = ", ".join(SNAPSHOT_COLUMNS[:-1])
    con.execute(f"create table today as select {cols}, true as listed from read_parquet('{TARGET}/*.parquet', union_by_name = true)")
    previous = sorted(p for p in SNAPSHOTS.glob("prices_*.parquet") if p.stem < f"prices_{today}")
    if previous:
        files = ", ".join(f"'{p}'" for p in previous)
        # Latest known state per product from the change log so far.
        con.execute(f"""
            create table known as
            select * exclude (snapshot_date) from read_parquet([{files}])
            qualify row_number() over (partition by store, store_product_id order by snapshot_date desc) = 1
        """)
        con.execute(f"""
            create table changes as
            select t.* from today t
            left join known k using (store, store_product_id)
            where k.store is null or not k.listed
               or k.price_isk is distinct from t.price_isk
               or k.regular_price_isk is distinct from t.regular_price_isk
               or k.in_stock is distinct from t.in_stock
            union all
            -- Delisted: known and listed before, gone today (only for stores fetched today).
            select k.store, k.store_product_id, k.name, k.price_isk, k.regular_price_isk, false, false
            from known k
            where k.listed and k.store in (select distinct store from today)
              and not exists (select 1 from today t where t.store = k.store and t.store_product_id = k.store_product_id)
        """)
    else:
        con.execute("create table changes as select * from today")
    n = con.execute("select count(*) from changes").fetchone()[0]
    target = SNAPSHOTS / f"prices_{today}.parquet"
    if n == 0:
        target.unlink(missing_ok=True)
        print("alcohol: no price changes since the last snapshot")
        return
    con.execute(f"copy (select '{today}'::date as snapshot_date, * from changes order by store, store_product_id) to '{target}' (format parquet, compression zstd)")
    print(f"alcohol: {n} new/changed prices → {target.name}")


def main() -> bool:
    config = load_sources()["alcohol"]
    session = PoliteSession(min_interval=config.get("min_interval", 1.0))
    fetched_at = datetime.now(timezone.utc).isoformat()
    ok = True
    for store, cfg in config["stores"].items():
        target = TARGET / f"{store}.parquet"

        def fetch(store=store, cfg=cfg, target=target):
            rows = ADAPTERS[cfg["platform"]](session, cfg)
            if len(rows) < cfg.get("min_products", 1):
                raise ValueError(f"only {len(rows)} products – catalogue layout changed?")
            write_parquet([{"store": store, **r, "fetched_at": fetched_at} for r in rows], target)
            print(f"alcohol.{store}: {len(rows)} products")

        ok &= run_safely(f"alcohol.{store}", target, fetch)
    write_snapshot(date.today())
    return ok


if __name__ == "__main__":
    raise SystemExit(0 if main() else 1)
