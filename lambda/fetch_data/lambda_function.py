import os
import json
import time
import logging
import urllib.request
import urllib.error
import boto3
import gzip
import io
from datetime import datetime, timezone
from collections import defaultdict

BUCKET = os.environ.get("BUCKET_NAME")
URL    = os.environ.get("DATA_URL")
PREFIX_RAW    = os.environ.get("PREFIX_RAW", "raw")
PREFIX_SERIES = os.environ.get("PREFIX_SERIES", "series")
AGG_MODE = os.environ.get("AGG_MODE", "cumulative").lower()  # 'cumulative' | 'daily'
MAX_GAP_DAYS = int(os.environ.get("MAX_GAP_DAYS", "31"))

s3 = boto3.client("s3")

logger = logging.getLogger()
if not logger.handlers:
    logging.basicConfig(level=logging.INFO)
logger.setLevel(logging.INFO)

def _now_iso_date_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")

def _to_iso(date_str: str) -> str:
    try:
        datetime.strptime(date_str, "%Y-%m-%d")
        return date_str
    except ValueError:
        pass
    for fmt in ("%m/%d/%y", "%m/%d/%Y"):
        try:
            return datetime.strptime(date_str, fmt).strftime("%Y-%m-%d")
        except ValueError:
            continue
    return date_str

def _http_get_with_retries(url: str, retries: int = 3, timeout: int = 20) -> bytes:
    last_err = None
    for attempt in range(1, retries + 1):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "epi-mvp/1.0"})
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                if resp.status != 200:
                    raise urllib.error.HTTPError(url, resp.status, resp.reason, resp.headers, None)
                return resp.read()
        except Exception as e:
            last_err = e
            logger.warning("HTTP attempt %d/%d failed: %s", attempt, retries, e)
            if attempt < retries:
                time.sleep(1.5 * attempt)
    raise last_err

def _coerce_int(x, default=0):
    try:
        return int(x) if x is not None else default
    except (TypeError, ValueError):
        return default

def _country_name(item: dict) -> str:
    return item.get("country") or item.get("countryRegion") or "Unknown"

def _extract_timeline(item: dict):
    tl = item.get("timeline") or {}
    return (
        tl.get("cases") or {},
        tl.get("deaths") or {},
        tl.get("recovered") or {}
    )

def _sorted_iso_dates(keys_mdy):
    iso = [_to_iso(k) for k in keys_mdy]
    return sorted({d for d in iso if d})

def _accumulate_cumulative(records: list[dict]) -> dict[tuple[str, str], dict]:
    acc = defaultdict(lambda: {"cases": 0, "deaths": 0, "recovered": 0})
    for item in records:
        country = _country_name(item)
        cases_map, deaths_map, rec_map = _extract_timeline(item)
        all_dates_iso = _sorted_iso_dates(set(cases_map) | set(deaths_map) | set(rec_map))
        for iso in all_dates_iso:
            dt = datetime.strptime(iso, "%Y-%m-%d")
            mdy = f"{dt.month}/{dt.day}/{str(dt.year)[2:]}"  # 'M/D/YY'
            acc[(iso, country)]["cases"]     += _coerce_int(cases_map.get(mdy))
            acc[(iso, country)]["deaths"]    += _coerce_int(deaths_map.get(mdy))
            acc[(iso, country)]["recovered"] += _coerce_int(rec_map.get(mdy))
    return acc

def _to_daily_from_cumulative(series_by_date: dict[str, dict]) -> dict[str, dict]:
    out = {}
    prev_vals = {"cases": 0, "deaths": 0, "recovered": 0}
    prev_date = None
    for iso in sorted(series_by_date.keys()):
        cur = series_by_date[iso]
        gap_bad = False
        if prev_date is not None:
            d_cur  = datetime.strptime(iso, "%Y-%m-%d").date()
            d_prev = datetime.strptime(prev_date, "%Y-%m-%d").date()
            gap_bad = (d_cur - d_prev).days > MAX_GAP_DAYS

        if prev_date is None or gap_bad:
            out[iso] = {"cases": None, "deaths": None, "recovered": None}
        else:
            out[iso] = {
                "cases":     max(0, _coerce_int(cur.get("cases"))     - _coerce_int(prev_vals.get("cases"))),
                "deaths":    max(0, _coerce_int(cur.get("deaths"))    - _coerce_int(prev_vals.get("deaths"))),
                "recovered": max(0, _coerce_int(cur.get("recovered")) - _coerce_int(prev_vals.get("recovered"))),
            }
        prev_vals = cur
        prev_date = iso
    return out


def _normalize_grouped(records: list[dict], target_date: str | None = None) -> dict[str, list[str]]:

    acc = _accumulate_cumulative(records)

    by_country: dict[str, dict[str, dict]] = defaultdict(dict)
    for (iso, country), vals in acc.items():
        by_country.setdefault(country, {})[iso] = vals

    grouped: dict[str, list[str]] = defaultdict(list)
    for country, series_by_date in by_country.items():
        if AGG_MODE == "daily":
            series_by_date = _to_daily_from_cumulative(series_by_date)

        dates_sorted = sorted(series_by_date.keys())
        dates_iter = [target_date] if (target_date and target_date in series_by_date) else dates_sorted

        for iso in dates_iter:
            v = series_by_date.get(iso) or {"cases": 0, "deaths": 0, "recovered": 0}
            row = {
                "date": iso,
                "country": country,
                "cases": _coerce_int(v.get("cases")) if v.get("cases") is not None else None,
                "deaths": _coerce_int(v.get("deaths")) if v.get("deaths") is not None else None,
                "recovered": _coerce_int(v.get("recovered")) if v.get("recovered") is not None else None,
            }
            grouped[iso].append(json.dumps(row, ensure_ascii=False))
    return grouped

def _put_gzip_ndjson(bucket: str, key: str, lines: list[str]) -> int:
    ndjson = ("\n".join(lines)).encode("utf-8")
    buf = io.BytesIO()
    with gzip.GzipFile(fileobj=buf, mode="wb") as gz:
        gz.write(ndjson)
    gz_bytes = buf.getvalue()
    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=gz_bytes,
        ContentType="application/x-ndjson",
        ContentEncoding="gzip",
    )
    return len(gz_bytes)

def lambda_handler(event, context):
    if not BUCKET or not URL:
        raise RuntimeError("Missing BUCKET_NAME or DATA_URL environment variables")

    effective_url = URL
    if isinstance(event, dict):
        effective_url = event.get("url") or effective_url

    target_date = None
    if isinstance(event, dict):
        target_date = event.get("date") or event.get("target_date")
        if target_date:
            target_date = _to_iso(target_date)

    today = _now_iso_date_utc()
    part_date = target_date or today

    backfill_all = (
        os.environ.get("BACKFILL_ALL") == "true" or
        (isinstance(event, dict) and bool(event.get("backfill_all")))
    )

    logger.info("Fetching %s", effective_url)
    body = _http_get_with_retries(effective_url)

    raw_key = f"{PREFIX_RAW}/date={part_date}/data.json"
    s3.put_object(Bucket=BUCKET, Key=raw_key, Body=body, ContentType="application/json")
    logger.info("Saved raw to s3://%s/%s (%d bytes)", BUCKET, raw_key, len(body))

    try:
        payload = json.loads(body)
    except json.JSONDecodeError as e:
        logger.error("JSON decode error: %s", e)
        raise

    if isinstance(payload, dict):
        records = [payload]
    elif isinstance(payload, list):
        if not payload:
            raise ValueError("Empty list payload from source API")
        records = payload
    else:
        raise TypeError("Unexpected payload type")

    grouped = _normalize_grouped(records, target_date=None if backfill_all else part_date)

    written = []  # [(date, key, lines, bytes_gz)]
    ts = datetime.now(timezone.utc).strftime("%H%M%S")

    if backfill_all:
        for iso in sorted(grouped.keys()):
            lines = grouped[iso]
            if not lines:
                continue
            key = f"{PREFIX_SERIES}/date={iso}/part-backfill-{ts}.ndjson.gz"
            size = _put_gzip_ndjson(BUCKET, key, lines)
            written.append((iso, key, len(lines), size))
        logger.info("Backfill written parts: %d", len(written))
    else:
        lines = grouped.get(part_date, [])
        if not lines:
            logger.warning("No lines produced for %s; check source or filters.", part_date)
        key = f"{PREFIX_SERIES}/date={part_date}/part-{ts}.ndjson.gz"
        size = _put_gzip_ndjson(BUCKET, key, lines)
        written.append((part_date, key, len(lines), size))
        logger.info("Saved series to s3://%s/%s (%d lines, %d bytes gzip)", BUCKET, key, len(lines), size)

    return {
        "status": "ok",
        "bucket": BUCKET,
        "raw_key": raw_key,
        "written": [
            {"date": d, "key": k, "lines": n, "bytes_gzip": b}
            for (d, k, n, b) in written
        ],
        "mode": AGG_MODE,
        "backfill_all": backfill_all,
        "url": effective_url,
    }
