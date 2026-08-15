#!/usr/bin/env python3
"""Zenodo real-download observation on macOS with explicit IP resolution.

Background: the default resolver in this network poisons zenodo.org to 0.0.0.0,
so the stock Julia-Downloads run failed at connect. This supplemental run resolves
zenodo.org to its real IP (188.185.48.75, cross-checked against 8.8.8.8/1.1.1.1)
and downloads each tag once per repetition, recording timing, size, SHA-256 and
whether the transfer completed. Truncated transfers are retained as failures, not
silently retried, so the data reflects real single-attempt behaviour.
"""
import csv
import hashlib
import subprocess
import time
from datetime import datetime
from pathlib import Path

OUT_DIR = Path(__file__).resolve().parent
WORK = OUT_DIR / "work"
WORK.mkdir(exist_ok=True)

RESOLVE = "zenodo.org:443:188.185.48.75"
RECORD = "https://zenodo.org/records/17732092/files/{tag}.nc"
REPETITIONS = 3
TIMEOUT = 240

CANDIDATES = [
    ("SC_2X_1Y_V1", 90987, "a752c43b9c383890bb221f428554eec4bba3ae1b1ba3b7165340f8acc61f8d42"),
    ("SLA_2X_1Y_V1", 505273, "352c864477922925057605b70fc20810b6e738989b5a96e70e4fb8701a0f6179"),
    ("ELEV_4X_1Y_V1", 810299, "642a485fda9517d267a71a63f8cbbb79b924bb19b2ff18a6471c0305b5be6f0f"),
    ("CH_20X_1Y_V1", 4207244, "77492a5d621103e895ca940208299bdd5b8bc4f93702f6fb4bdbe4476b2745c4"),
]


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    rows = []
    for tag, exp_size, exp_sha in CANDIDATES:
        for rep in range(1, REPETITIONS + 1):
            target = WORK / f"{tag}-zenodo-{rep}.nc"
            if target.exists():
                target.unlink()
            url = RECORD.format(tag=tag)
            started = time.monotonic()
            proc = subprocess.run(
                ["curl", "-s", "--resolve", RESOLVE, "--max-time", str(TIMEOUT),
                 "-o", str(target), url],
                capture_output=True, text=True,
            )
            elapsed = time.monotonic() - started
            actual_size = target.stat().st_size if target.exists() else 0
            actual_sha = sha256_file(target) if target.exists() else ""
            success = (actual_size == exp_size) and (actual_sha == exp_sha)
            note = ""
            if proc.returncode == 18:
                note = "curl_exit_18_partial_transfer"
            elif proc.returncode != 0:
                note = f"curl_exit_{proc.returncode}"
            rows.append({
                "tag": tag, "repetition": rep, "mirror": "zenodo",
                "url": url, "resolve_override": RESOLVE,
                "elapsed_s": round(elapsed, 6),
                "success": success,
                "expected_size": exp_size, "actual_size": actual_size,
                "expected_sha256": exp_sha, "actual_sha256": actual_sha,
                "note": note,
            })
            print(f"{tag} rep{rep}: size={actual_size} ok={success} "
                  f"t={elapsed:.2f}s {note}")
            if target.exists():
                target.unlink()

    raw = OUT_DIR / "zenodo_verified_raw.csv"
    with open(raw, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    ok = sum(1 for r in rows if r["success"])
    print(f"\nZenodo verified observation: {ok}/{len(rows)} downloads completed "
          f"with SIZE+SHA256 match -> {raw.name}")


if __name__ == "__main__":
    main()
