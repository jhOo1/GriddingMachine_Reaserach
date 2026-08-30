from __future__ import annotations

from pathlib import Path
import tomllib

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np


ROOT = Path(__file__).resolve().parents[2]
CASE_ROOT = ROOT / "experiment_data" / "03_08"
SUMMARY_FILE = CASE_ROOT / "reference_summary.toml"
PIPELINE_FILE = CASE_ROOT / "pipeline_result.toml"
BINARY_FILE = CASE_ROOT / "reference" / "oisst_reference_20220225_f32.bin"
OUTPUT_PNG = ROOT / "论文" / "figures" / "图2_OISST真实产品标准化结果.png"
OUTPUT_SVG = ROOT / "论文" / "figures" / "图2_OISST真实产品标准化结果.svg"


def main() -> None:
    with SUMMARY_FILE.open("rb") as stream:
        summary = tomllib.load(stream)
    with PIPELINE_FILE.open("rb") as stream:
        pipeline = tomllib.load(stream)

    shape = tuple(summary["target"]["shape"])
    data = np.fromfile(BINARY_FILE, dtype="<f4").reshape(shape, order="F")
    lons = np.linspace(
        summary["target"]["lon_first"], summary["target"]["lon_last"], shape[0]
    )
    lats = np.linspace(
        summary["target"]["lat_first"], summary["target"]["lat_last"], shape[1]
    )
    mpl.rcParams.update(
        {
            "font.family": "DejaVu Sans",
            "font.size": 8.2,
            "axes.linewidth": 0.7,
            "axes.titleweight": "semibold",
            "axes.titlesize": 9.0,
            "xtick.major.width": 0.6,
            "ytick.major.width": 0.6,
            "svg.fonttype": "none",
        }
    )
    figure = plt.figure(figsize=(7.2, 5.15), constrained_layout=True)
    grid = figure.add_gridspec(2, 2, height_ratios=(2.35, 1.0), hspace=0.08)

    map_axis = figure.add_subplot(grid[0, :])
    colormap = mpl.colormaps["turbo"].copy()
    colormap.set_bad("#e8ebef")
    image = map_axis.imshow(
        data.T,
        origin="lower",
        extent=(-180, 180, -90, 90),
        cmap=colormap,
        vmin=-2,
        vmax=32,
        interpolation="nearest",
        aspect="auto",
        rasterized=True,
    )
    map_axis.set_title("(a) Standardized NOAA OISST V2.1 sea-surface temperature, 25 February 2022", loc="left")
    map_axis.set_xlabel("Longitude (°)")
    map_axis.set_ylabel("Latitude (°)")
    map_axis.set_xticks(np.arange(-180, 181, 60))
    map_axis.set_yticks(np.arange(-90, 91, 30))
    map_axis.grid(color="white", linewidth=0.35, alpha=0.45)
    colorbar = figure.colorbar(image, ax=map_axis, orientation="vertical", pad=0.015, shrink=0.96)
    colorbar.set_label("Sea-surface temperature (°C)")

    flow_axis = figure.add_subplot(grid[1, 0])
    flow_axis.set_title("(b) Source-to-standard transformation", loc="left")
    flow_axis.set_xlim(0, 1)
    flow_axis.set_ylim(0, 1)
    flow_axis.axis("off")
    boxes = [
        (0.02, "Source layout", "time × zlev ×\nlat × lon\nInt16 + scale"),
        (0.355, "YAML", "extract singleton\ndecode values\nreorder longitude"),
        (0.69, "Standard grid", "lon × lat\n1440 × 720\nFloat32"),
    ]
    for x, heading, body in boxes:
        patch = mpl.patches.FancyBboxPatch(
            (x, 0.20), 0.285, 0.56,
            boxstyle="round,pad=0.018,rounding_size=0.025",
            linewidth=0.9, edgecolor="#347A8A", facecolor="#EFF8F8"
        )
        flow_axis.add_patch(patch)
        flow_axis.text(x + 0.1425, 0.62, heading, ha="center", va="center", fontsize=6.7, weight="semibold", color="#164A57")
        flow_axis.text(x + 0.1425, 0.38, body, ha="center", va="center", fontsize=5.8, linespacing=1.15, color="#334155")
    for start in (0.307, 0.642):
        flow_axis.annotate("", xy=(start + 0.042, 0.48), xytext=(start, 0.48), arrowprops=dict(arrowstyle="-|>", lw=1.1, color="#347A8A"))

    evidence_axis = figure.add_subplot(grid[1, 1])
    evidence_axis.set_title("(c) Reference agreement", loc="left")
    evidence_axis.set_xlim(0, 1)
    evidence_axis.set_ylim(0, 1)
    evidence_axis.axis("off")
    comparison = pipeline["comparison"]
    checks = [
        ("Coordinates", "lon / lat matched"),
        ("Finite mask", f'{comparison["finite_count"]:,} / {comparison["missing_count"]:,}'),
        ("Physical values", f'max |Δ| = {comparison["maximum_absolute_difference"]:.1f} °C'),
        ("Reproducibility", f'{pipeline["case"]["runs"]}/{pipeline["case"]["runs"]} digests identical'),
    ]
    card_positions = [(0.02, 0.54), (0.515, 0.54), (0.02, 0.15), (0.515, 0.15)]
    for (label, value), (x, y) in zip(checks, card_positions):
        evidence_axis.add_patch(
            mpl.patches.FancyBboxPatch(
                (x, y), 0.455, 0.28,
                boxstyle="round,pad=0.014,rounding_size=0.025",
                linewidth=0.75, edgecolor="#A7D8D0", facecolor="#F2FAF8"
            )
        )
        evidence_axis.add_patch(mpl.patches.Circle((x + 0.055, y + 0.14), 0.027, facecolor="#168C78", edgecolor="none"))
        evidence_axis.text(x + 0.055, y + 0.14, "✓", color="white", ha="center", va="center", fontsize=7.2, weight="bold")
        evidence_axis.text(x + 0.105, y + 0.175, label, ha="left", va="center", fontsize=6.2, weight="semibold", color="#1F2937")
        evidence_axis.text(x + 0.105, y + 0.09, value, ha="left", va="center", fontsize=5.6, color="#52606D")

    OUTPUT_PNG.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(OUTPUT_PNG, dpi=450, bbox_inches="tight", facecolor="white")
    figure.savefig(OUTPUT_SVG, bbox_inches="tight", facecolor="white")
    plt.close(figure)
    svg_text = OUTPUT_SVG.read_text(encoding="utf-8")
    OUTPUT_SVG.write_text(
        "\n".join(line.rstrip() for line in svg_text.splitlines()) + "\n",
        encoding="utf-8",
    )
    print(OUTPUT_PNG)
    print(OUTPUT_SVG)


if __name__ == "__main__":
    main()
