#!/usr/bin/env python3
"""Filter downloaded trip and NOAA CSV files to an inclusive demo date range."""

from __future__ import annotations

import argparse
import csv
import os
from pathlib import Path


def filter_csv(path: Path, date_field: str, start: str, end: str) -> tuple[int, int]:
    temp = path.with_suffix(path.suffix + ".filtered.tmp")
    read_rows = 0
    kept_rows = 0

    with path.open("r", encoding="utf-8-sig", newline="") as source:
        reader = csv.DictReader(source)
        if not reader.fieldnames or date_field not in reader.fieldnames:
            raise ValueError(f"{path}: missing date field {date_field!r}")

        with temp.open("w", encoding="utf-8", newline="") as target:
            writer = csv.DictWriter(target, fieldnames=reader.fieldnames)
            writer.writeheader()
            for row in reader:
                read_rows += 1
                date_value = (row.get(date_field) or "")[:10]
                if start <= date_value <= end:
                    writer.writerow(row)
                    kept_rows += 1

    os.replace(temp, path)
    return read_rows, kept_rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", required=True, type=Path)
    parser.add_argument("--start", required=True)
    parser.add_argument("--end", required=True)
    args = parser.parse_args()

    root = args.project_root.resolve()
    targets: list[tuple[Path, str]] = []
    targets.extend(
        (path, "started_at")
        for path in sorted((root / "A_datasets/A1_citibike/extracted").rglob("*.csv"))
        if not path.name.startswith("._")
    )
    targets.extend(
        (path, "started_at")
        for path in sorted((root / "A_datasets/A2_divvy/extracted").rglob("*.csv"))
        if not path.name.startswith("._")
    )
    targets.extend(
        (path, "DATE")
        for path in sorted((root / "A_datasets/A3_noaa_lcd_v2").glob("*_01-05.csv"))
    )

    if not targets:
        raise SystemExit("No extracted trip/NOAA CSV files found")

    total_read = 0
    total_kept = 0
    for path, field in targets:
        read_rows, kept_rows = filter_csv(path, field, args.start, args.end)
        total_read += read_rows
        total_kept += kept_rows
        print(f"{path.relative_to(root)}: read={read_rows:,} kept={kept_rows:,}")

    print(f"TOTAL: read={total_read:,} kept={total_kept:,}")


if __name__ == "__main__":
    main()
