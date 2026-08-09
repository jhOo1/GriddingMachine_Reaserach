#!/usr/bin/env python3
"""Collect Zenodo metadata and optionally download the 14 gm2 land files.

All file content is written below 03_04_data/downloads. The script performs
read-only Zenodo API/file requests and verifies size plus Zenodo MD5 before
promoting each .part file. SHA-256 is then recorded for the paper catalog test.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import time
import urllib.error
import urllib.request
from pathlib import Path


ROOT = Path.cwd().resolve()
if not (ROOT / Path(__file__).name).is_file():
    raise RuntimeError("Run this script from its 03_04_data directory")
DATA_ROOT = ROOT.parents[2] / "experiment_data" / "03_04"
INVENTORY = ROOT / "required_datasets_2020.csv"
DOWNLOADS = DATA_ROOT / "downloads"
OUTPUT = ROOT / "land_files_2020_metadata.csv"
LOCAL_CATALOG = ROOT / "Artifacts.land.local.yaml"
RECORD_FOR_TAG = {"LM_4X_1Y_V1": "17709092"}
DEFAULT_RECORD = "17732092"
USER_AGENT = "GriddingMachine-paper-validation/0.1"


def hash_file(path: Path, algorithm: str) -> str:
    digest = hashlib.new(algorithm)
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def api_record(record_id: str) -> dict:
    request = urllib.request.Request(
        f"https://zenodo.org/api/records/{record_id}",
        headers={"User-Agent": USER_AGENT},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def request_file(url: str, destination: Path, expected_size: int) -> None:
    part = destination.with_suffix(destination.suffix + ".part")
    for attempt in range(1, 6):
        current = part.stat().st_size if part.exists() else 0
        if current > expected_size:
            raise RuntimeError(f"Oversized partial file: {part} ({current}>{expected_size})")
        headers = {"User-Agent": USER_AGENT}
        if current:
            headers["Range"] = f"bytes={current}-"
        request = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                status = getattr(response, "status", response.getcode())
                mode = "ab" if current and status == 206 else "wb"
                with part.open(mode) as output:
                    while True:
                        block = response.read(1024 * 1024)
                        if not block:
                            break
                        output.write(block)
            if part.stat().st_size == expected_size:
                break
        except (TimeoutError, ConnectionError, urllib.error.URLError) as error:
            if attempt == 5:
                raise
            print(f"  attempt {attempt} interrupted: {error}; resuming")
            time.sleep(attempt)
    actual_size = part.stat().st_size
    if actual_size != expected_size:
        raise RuntimeError(
            f"Incomplete download for {destination.name}: {actual_size}/{expected_size}"
        )
    os.replace(part, destination)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--download",
        action="store_true",
        help="Download and validate file content after collecting metadata",
    )
    args = parser.parse_args()

    with INVENTORY.open(encoding="utf-8") as stream:
        required = [row for row in csv.DictReader(stream) if row["group"] == "gm2"]
    records = {
        record_id: api_record(record_id)
        for record_id in sorted({DEFAULT_RECORD, *RECORD_FOR_TAG.values()})
    }
    record_files = {
        record_id: {item["key"]: item for item in record["files"]}
        for record_id, record in records.items()
    }

    if args.download:
        DOWNLOADS.mkdir(parents=True, exist_ok=True)
    rows = []
    for index, item in enumerate(required, start=1):
        tag = item["tag"]
        filename = f"{tag}.nc"
        record_id = RECORD_FOR_TAG.get(tag, DEFAULT_RECORD)
        remote = record_files[record_id].get(filename)
        if remote is None:
            raise KeyError(f"{filename} is absent from Zenodo record {record_id}")
        expected_size = int(remote["size"])
        expected_md5 = remote["checksum"].removeprefix("md5:").lower()
        destination = DOWNLOADS / filename
        sha256 = ""
        status = "metadata_only"
        if args.download:
            print(f"[{index}/{len(required)}] {filename} ({expected_size} bytes)")
            already_valid = (
                destination.is_file()
                and destination.stat().st_size == expected_size
                and hash_file(destination, "md5") == expected_md5
            )
            if not already_valid:
                content_url = remote["links"].get("content", remote["links"].get("self"))
                if not content_url:
                    raise KeyError(f"Zenodo content link missing for {filename}")
                request_file(content_url, destination, expected_size)
            actual_md5 = hash_file(destination, "md5")
            if actual_md5 != expected_md5:
                raise RuntimeError(
                    f"MD5 mismatch for {filename}: {actual_md5} != {expected_md5}"
                )
            sha256 = hash_file(destination, "sha256")
            status = "verified"
        rows.append(
            {
                "tag": tag,
                "field": item["field"],
                "record_id": record_id,
                "doi": records[record_id]["metadata"]["doi"],
                "filename": filename,
                "size_bytes": expected_size,
                "zenodo_md5": expected_md5,
                "sha256": sha256,
                "status": status,
                "content_url": remote["links"].get("content", remote["links"].get("self", "")),
            }
        )

    with OUTPUT.open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    if args.download:
        with LOCAL_CATALOG.open("w", encoding="utf-8") as stream:
            for row in rows:
                stream.write(f"{row['tag']}:\n")
                stream.write("  PATH: downloads\n")
                stream.write("  URL:\n")
                stream.write(f"    - \"{row['content_url']}\"\n")
                stream.write(f"  SIZE: {row['size_bytes']}\n")
                stream.write(f"  SHA256: {row['sha256']}\n")
    print(f"Files: {len(rows)}")
    print(f"Total bytes: {sum(row['size_bytes'] for row in rows)}")
    print(f"Mode: {'download and verify' if args.download else 'metadata only'}")


if __name__ == "__main__":
    main()
