#!/usr/bin/env python3
"""Cross-platform pilot for direct NetCDF versus an outer tar.gz package.

All network traffic is restricted to a temporary HTTP server bound to
127.0.0.1. Large inputs and generated archives stay in this directory.
"""

from __future__ import annotations

import csv
import hashlib
import http.server
import json
import math
import os
import platform
import random
import shutil
import socketserver
import sys
import tarfile
import tempfile
import threading
import time
import urllib.request
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path.cwd().resolve()
if not (ROOT / Path(__file__).name).is_file():
    raise RuntimeError("Run this script from its 03_02_data directory")
sys.path.insert(0, str(ROOT / "python_env"))

from netCDF4 import Dataset  # noqa: E402
import netCDF4  # noqa: E402


INPUTS = (
    "ELEV_4X_1Y_V1.nc",
    "LAI_MODIS_2X_8D_2020_V1.nc",
)
REPETITIONS = 10
SEED = 20260809
BOOTSTRAP_SAMPLES = 5000


def file_hash(path: Path, algorithm: str = "sha256") -> str:
    digest = hashlib.new(algorithm)
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def percentile(values: list[float], probability: float) -> float:
    ordered = sorted(values)
    position = (len(ordered) - 1) * probability
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    fraction = position - lower
    return ordered[lower] * (1 - fraction) + ordered[upper] * fraction


def bootstrap_median_ci(values: list[float], seed: int) -> tuple[float, float]:
    rng = random.Random(seed)
    medians = []
    for _ in range(BOOTSTRAP_SAMPLES):
        sample = [rng.choice(values) for _ in values]
        medians.append(percentile(sample, 0.5))
    return percentile(medians, 0.025), percentile(medians, 0.975)


def first_value(path: Path) -> tuple[float, object]:
    started = time.perf_counter_ns()
    with Dataset(os.path.relpath(path, ROOT), "r") as dataset:
        variable = dataset.variables["data"]
        value = variable[tuple(0 for _ in variable.shape)]
        value = value.item() if hasattr(value, "item") else value
    return (time.perf_counter_ns() - started) / 1e6, value


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_args: object) -> None:
        return


class ReusableThreadingServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


@contextmanager
def local_server(directory: Path):
    handler = lambda *args, **kwargs: QuietHandler(  # noqa: E731
        *args, directory=str(directory), **kwargs
    )
    server = ReusableThreadingServer(("127.0.0.1", 0), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield f"http://127.0.0.1:{server.server_port}"
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


def download(url: str, destination: Path) -> None:
    with urllib.request.urlopen(url, timeout=120) as response:
        with destination.open("wb") as output:
            shutil.copyfileobj(response, output, length=1024 * 1024)


def package(source: Path, archive: Path) -> float:
    started = time.perf_counter_ns()
    with tarfile.open(archive, "w:gz", compresslevel=6) as bundle:
        bundle.add(source, arcname=source.name)
    return (time.perf_counter_ns() - started) / 1e6


def describe_netcdf(path: Path) -> dict[str, object]:
    with Dataset(os.path.relpath(path, ROOT), "r") as dataset:
        data = dataset.variables["data"]
        return {
            "dimensions": {name: len(dim) for name, dim in dataset.dimensions.items()},
            "data_shape": list(data.shape),
            "data_dtype": str(data.dtype),
            "data_filters": data.filters(),
        }


def run_case(
    base_url: str,
    source: Path,
    archive: Path,
    distribution: str,
    repeat: int,
    sequence: int,
    source_sha256: str,
    package_ms: float,
    work_root: Path,
) -> dict[str, object]:
    transfer = source if distribution == "nc" else archive
    with tempfile.TemporaryDirectory(dir=work_root, prefix="case-") as temp_name:
        temp = Path(temp_name)
        downloaded = temp / transfer.name
        started = time.perf_counter_ns()
        download(f"{base_url}/{transfer.name}", downloaded)
        download_ms = (time.perf_counter_ns() - started) / 1e6

        extract_ms = 0.0
        readable = downloaded
        if distribution == "tar.gz":
            extract_started = time.perf_counter_ns()
            with tarfile.open(downloaded, "r:gz") as bundle:
                member = bundle.getmember(source.name)
                # The archive is created immediately above from one known basename.
                bundle.extract(member, path=temp)
            extract_ms = (time.perf_counter_ns() - extract_started) / 1e6
            readable = temp / source.name

        read_ms, value = first_value(readable)
        end_to_end_ms = (time.perf_counter_ns() - started) / 1e6
        output_sha256 = file_hash(readable)
        hash_ok = output_sha256 == source_sha256
        if not hash_ok:
            raise RuntimeError(f"SHA-256 mismatch for {source.name} ({distribution})")

        transfer_bytes = transfer.stat().st_size
        source_bytes = source.stat().st_size
        temporary_bytes = (
            source_bytes if distribution == "nc" else transfer_bytes + source_bytes
        )
        return {
            "dataset": source.stem,
            "repeat": repeat,
            "sequence": sequence,
            "distribution": distribution,
            "source_bytes": source_bytes,
            "transfer_bytes": transfer_bytes,
            "outer_compression_ratio": 0.0
            if distribution == "nc"
            else 1.0 - transfer_bytes / source_bytes,
            "package_ms": 0.0 if distribution == "nc" else package_ms,
            "download_ms": download_ms,
            "extract_ms": extract_ms,
            "first_read_ms": read_ms,
            "end_to_end_ms": end_to_end_ms,
            "temporary_bytes": temporary_bytes,
            "final_bytes": source_bytes,
            "sha256_ok": hash_ok,
            "first_value": repr(value),
        }


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    platform_slug = os.environ.get("PILOT_PLATFORM", platform.system()).lower()
    if platform_slug not in {"windows", "macos", "linux"}:
        raise RuntimeError(f"Unsupported PILOT_PLATFORM={platform_slug}")
    inputs = [ROOT / name for name in INPUTS]
    missing = [str(path) for path in inputs if not path.is_file()]
    if missing:
        raise FileNotFoundError(f"Missing pilot inputs: {missing}")

    work_root = ROOT / "work"
    work_root.mkdir(exist_ok=True)
    archives: dict[str, Path] = {}
    package_times: dict[str, float] = {}
    source_hashes: dict[str, str] = {}
    metadata: dict[str, object] = {}

    for source in inputs:
        archive = ROOT / f"{source.name}.tar.gz"
        package_times[source.name] = package(source, archive)
        archives[source.name] = archive
        source_hashes[source.name] = file_hash(source)
        metadata[source.name] = {
            "bytes": source.stat().st_size,
            "sha256": source_hashes[source.name],
            "archive_bytes": archive.stat().st_size,
            "archive_sha256": file_hash(archive),
            "package_ms": package_times[source.name],
            **describe_netcdf(source),
        }

    rows: list[dict[str, object]] = []
    rng = random.Random(SEED)
    cases = [
        (source, distribution, repeat)
        for repeat in range(1, REPETITIONS + 1)
        for source in inputs
        for distribution in ("nc", "tar.gz")
    ]
    rng.shuffle(cases)

    with local_server(ROOT) as base_url:
        # One unrecorded warm-up for every dataset/distribution combination.
        warm_sequence = 0
        for source in inputs:
            for distribution in ("nc", "tar.gz"):
                run_case(
                    base_url,
                    source,
                    archives[source.name],
                    distribution,
                    0,
                    warm_sequence,
                    source_hashes[source.name],
                    package_times[source.name],
                    work_root,
                )
                warm_sequence += 1

        for sequence, (source, distribution, repeat) in enumerate(cases, start=1):
            rows.append(
                run_case(
                    base_url,
                    source,
                    archives[source.name],
                    distribution,
                    repeat,
                    sequence,
                    source_hashes[source.name],
                    package_times[source.name],
                    work_root,
                )
            )

    raw_path = ROOT / f"pilot_{platform_slug}_raw.csv"
    write_csv(raw_path, rows)

    summaries: list[dict[str, object]] = []
    for source in inputs:
        for distribution in ("nc", "tar.gz"):
            selected = [
                row
                for row in rows
                if row["dataset"] == source.stem
                and row["distribution"] == distribution
            ]
            for metric in (
                "download_ms",
                "extract_ms",
                "first_read_ms",
                "end_to_end_ms",
                "temporary_bytes",
            ):
                values = [float(row[metric]) for row in selected]
                ci_low, ci_high = bootstrap_median_ci(
                    values, SEED + len(summaries) * 101 + len(metric)
                )
                summaries.append(
                    {
                        "dataset": source.stem,
                        "distribution": distribution,
                        "metric": metric,
                        "n": len(values),
                        "median": percentile(values, 0.5),
                        "q1": percentile(values, 0.25),
                        "q3": percentile(values, 0.75),
                        "ci95_low": ci_low,
                        "ci95_high": ci_high,
                    }
                )

    write_csv(ROOT / f"pilot_{platform_slug}_summary.csv", summaries)
    run_metadata = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "status": "pilot",
        "scope": "distribution format only; not a GriddingMachine API benchmark",
        "cache_condition": (
            "warm operating-system cache after one explicit application warm-up; "
            f"no privileged {platform_slug} cache eviction was performed"
        ),
        "http": "127.0.0.1 ephemeral port; no external network traffic",
        "tar_gzip_level": 6,
        "repetitions_per_combination": REPETITIONS,
        "random_seed": SEED,
        "bootstrap_samples": BOOTSTRAP_SAMPLES,
        "python": sys.version,
        "netcdf4_python": netCDF4.__version__,
        "platform": platform.platform(),
        "processor": platform.processor(),
        "datasets": metadata,
    }
    with (ROOT / f"pilot_{platform_slug}_metadata.json").open("w", encoding="utf-8") as stream:
        json.dump(run_metadata, stream, ensure_ascii=False, indent=2)
        stream.write("\n")

    print(f"Wrote {raw_path.name}: {len(rows)} measured cases")
    print("All extracted SHA-256 checks passed")


if __name__ == "__main__":
    main()
