#!/usr/bin/env python3
"""Run KPI SQL against dw_dds and write filled markdown report."""

from __future__ import annotations

import csv
import io
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]  # G_reporting/
PROJECT = ROOT.parent
SQL_PATH = ROOT / "sql" / "kpi_report_actuals_2026_jan_may.sql"
OUT_PATH = ROOT / "kpi_report_2026_jan_may.md"
CONTAINER = "hcmus-bi-official-db-dw-dds-postgres"
DB = "dw_dds"

KPI_META = {
    "A": {
        "name": "Mức mất cân bằng xe trung bình mỗi trạm/giờ (AVG abs_imbalance)",
        "target": "4.0",
        "section": "ops",
        "fmt": "1",
    },
    "B": {
        "name": "Tỷ lệ station-hour mất cân bằng nghiêm trọng (abs_imbalance ≥ 4)",
        "target": "10.0%",
        "section": "ops",
        "fmt": "pct1",
    },
    "C": {
        "name": "Số lần trạm–ngày rút cạn kéo dài hơn 6 tiếng (net_flow < 0)",
        "target": "5",
        "section": "ops",
        "fmt": "int",
    },
    "D": {
        "name": "Mức mất cân bằng giờ cao điểm (07:00–08:00 và 17:00–18:00 vào ngày thường) so với giờ thường",
        "target": "1.50",
        "section": "ops",
        "fmt": "1",
    },
    "E": {
        "name": "Chênh lệch mất cân bằng trung bình giữa Chicago và New York (|AVG_CHI − AVG_NYC|)",
        "target": "1.0",
        "section": "ops",
        "fmt": "1",
    },
    "F": {
        "name": "Chênh lệch mất cân bằng khi trời mưa so với trời quang (AVG_Rain − AVG_Clear)",
        "target": "—",
        "section": "ops",
        "fmt": "1",
    },
    "G": {
        "name": "Số chuyến đi bắt đầu trung bình mỗi trạm/giờ (AVG trips_started)",
        "target": "3.0",
        "section": "demand",
        "fmt": "1",
    },
    "H": {
        "name": "Tỷ lệ chuyến đi Member/Casual (SUM member ÷ SUM casual)",
        "target": "2.00",
        "section": "demand",
        "fmt": "2",
    },
    "I": {
        "name": "Tỷ lệ sử dụng xe điện trên tổng chuyến classic + electric",
        "target": "30%",
        "section": "demand",
        "fmt": "pct1",
    },
    "J": {
        "name": "Mức sụt giảm nhu cầu khi mưa/tuyết so với trời quang (% giảm AVG trips_started)",
        "target": "15%",
        "section": "demand",
        "fmt": "pct1",
    },
    "K": {
        "name": "Tổng số chuyến đi bắt đầu theo thành phố (CHI / NYC)",
        "target": "—",
        "section": "demand",
        "fmt": "city",
    },
}

MONTHS = ["1", "2", "3", "4", "5"]
MONTH_LABELS = ["Jan", "Feb", "Mar", "Apr", "May"]


def format_value(fmt: str, value: float | None) -> str:
    if value is None:
        return "—"
    if fmt == "int":
        return str(int(round(value)))
    if fmt == "1":
        return f"{value:.1f}"
    if fmt == "2":
        return f"{value:.2f}"
    if fmt == "pct1":
        return f"{value:.1f}%"
    if fmt == "city":
        return str(int(round(value)))
    return str(value)


def run_sql() -> list[dict]:
    sql = SQL_PATH.read_text(encoding="utf-8")
    # Copy SQL into container and run as CSV
    subprocess.run(
        ["docker", "cp", str(SQL_PATH), f"{CONTAINER}:/tmp/kpi_report_actuals.sql"],
        check=True,
    )
    proc = subprocess.run(
        [
            "docker",
            "exec",
            CONTAINER,
            "psql",
            "-U",
            "postgres",
            "-d",
            DB,
            "-v",
            "ON_ERROR_STOP=1",
            "-A",
            "-F",
            "\t",
            "-P",
            "footer=off",
            "-f",
            "/tmp/kpi_report_actuals.sql",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    # Keep header + data rows (tab-separated; names may contain commas)
    lines = []
    for line in proc.stdout.splitlines():
        parts = line.split("\t")
        if not parts:
            continue
        if parts[0] in ("kpi_code", *KPI_META.keys()):
            lines.append(line)
    if not lines:
        raise RuntimeError(f"No TSV rows from psql. stdout:\n{proc.stdout}\nstderr:\n{proc.stderr}")

    reader = csv.DictReader(io.StringIO("\n".join(lines)), delimiter="\t")
    rows = []
    for r in reader:
        city = r.get("city_code") or ""
        if city in ("", "NULL"):
            city = None
        val_raw = r.get("actual_value")
        if val_raw in (None, "", "NULL"):
            val = None
        else:
            val = float(val_raw)
        rows.append(
            {
                "kpi_code": r["kpi_code"],
                "kpi_name": r["kpi_name"],
                "period": r["period"],
                "city_code": city,
                "actual_value": val,
            }
        )
    return rows


def index_rows(rows: list[dict]):
    """kpi_code -> period -> value (float) or for K: period -> {CHI: n, NYC: m}"""
    simple: dict[str, dict[str, float | None]] = defaultdict(dict)
    city: dict[str, dict[str, dict[str, float]]] = defaultdict(lambda: defaultdict(dict))
    for r in rows:
        code = r["kpi_code"]
        period = r["period"]
        if code == "K":
            if r["city_code"]:
                city[code][period][r["city_code"]] = r["actual_value"]
        else:
            simple[code][period] = r["actual_value"]
    return simple, city


def format_city_cell(by_city: dict[str, float] | None) -> str:
    if not by_city:
        return "—"
    chi = by_city.get("CHI")
    nyc = by_city.get("NYC")
    chi_s = "—" if chi is None else str(int(round(chi)))
    nyc_s = "—" if nyc is None else str(int(round(nyc)))
    return f"CHI: {chi_s} / NYC: {nyc_s}"


def sanity_check(simple, city) -> list[str]:
    problems = []
    for code, meta in KPI_META.items():
        if code == "K":
            for p in MONTHS + ["YTD"]:
                if p not in city[code] or not city[code][p]:
                    problems.append(f"K missing period {p}")
                else:
                    for c in ("CHI", "NYC"):
                        if c not in city[code][p]:
                            problems.append(f"K missing {c} for {p}")
            continue
        for p in MONTHS + ["YTD"]:
            if p not in simple[code]:
                problems.append(f"{code} missing period {p}")
                continue
            v = simple[code][p]
            if v is None:
                problems.append(f"{code} NULL for {p}")
            elif abs(v) == float("inf"):
                problems.append(f"{code} Inf for {p}")
    return problems


def render_section(title: str, codes: list[str], simple, city) -> str:
    lines = [
        f"## {title}",
        "",
        "| Code | KPI (Priority) | Row | YTD | Target | Jan | Feb | Mar | Apr | May |",
        "| ---- | -------------- | --- | --- | ------ | --- | --- | --- | --- | --- |",
    ]
    for code in codes:
        meta = KPI_META[code]
        name = meta["name"]
        target = meta["target"]
        plan_ytd = target
        plan_months = [target] * 5

        if code == "K":
            actual_ytd = format_city_cell(city[code].get("YTD"))
            actual_months = [format_city_cell(city[code].get(m)) for m in MONTHS]
        else:
            fmt = meta["fmt"]
            actual_ytd = format_value(fmt, simple[code].get("YTD"))
            actual_months = [format_value(fmt, simple[code].get(m)) for m in MONTHS]

        lines.append(
            "| {code} | {name} | Plan | {ytd} | {target} | {jan} | {feb} | {mar} | {apr} | {may} |".format(
                code=code,
                name=name,
                ytd=plan_ytd,
                target=target,
                jan=plan_months[0],
                feb=plan_months[1],
                mar=plan_months[2],
                apr=plan_months[3],
                may=plan_months[4],
            )
        )
        lines.append(
            "| {code} | {name} | Actual | {ytd} | {target} | {jan} | {feb} | {mar} | {apr} | {may} |".format(
                code=code,
                name=name,
                ytd=actual_ytd,
                target=target,
                jan=actual_months[0],
                feb=actual_months[1],
                mar=actual_months[2],
                apr=actual_months[3],
                may=actual_months[4],
            )
        )
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    print(f"Running SQL: {SQL_PATH}")
    rows = run_sql()
    print(f"Fetched {len(rows)} result rows")
    simple, city = index_rows(rows)
    problems = sanity_check(simple, city)
    if problems:
        print("SANITY CHECK FAILED:")
        for p in problems:
            print(" -", p)
        return 1
    print("Sanity check OK")

    body = []
    body.append("# KPI Report — Jan–May 2026")
    body.append("")
    body.append("Source: `dds.fact_station_hour_balance` (+ dims) via `sql/kpi_report_actuals_2026_jan_may.sql`.")
    body.append("")
    body.append("- **Plan** = Target (constant).")
    body.append("- **Actual** = queried from `dw_dds`.")
    body.append("- **YTD** = same formula recomputed over Jan–May 2026 (not average of monthly Actuals).")
    body.append("")
    body.append("Thresholds: serious imbalance `abs_imbalance >= 4`; prolonged depletion `> 6` hours with `net_flow < 0` per station-day.")
    body.append("")
    body.append(render_section("KPI Vận hành", list("ABCDEF"), simple, city))
    body.append(render_section("KPI - Nhu cầu & Hành vi người dùng", list("GHIJK"), simple, city))

    OUT_PATH.write_text("\n".join(body), encoding="utf-8")
    print(f"Wrote {OUT_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
