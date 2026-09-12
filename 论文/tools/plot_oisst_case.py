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
    navy = "#102F4A"
    teal = "#007C83"
    slate = "#405568"
    mpl.rcParams.update(
        {
            "font.family": "DejaVu Sans",
            "font.size": 7.6,
            "axes.labelcolor": slate,
            "axes.edgecolor": "#B9C4CC",
            "axes.linewidth": 0.65,
            "axes.titlecolor": navy,
            "axes.titleweight": "semibold",
            "axes.titlesize": 8.7,
            "xtick.color": slate,
            "ytick.color": slate,
            "xtick.major.width": 0.55,
            "ytick.major.width": 0.55,
            "svg.fonttype": "none",
        }
    )
    figure = plt.figure(figsize=(7.2, 4.8), layout="constrained", facecolor="white")
    grid = figure.add_gridspec(
        2, 2, height_ratios=(2.22, 1.0), width_ratios=(1.18, 0.82),
        hspace=0.06, wspace=0.06,
    )

    map_axis = figure.add_subplot(grid[0, :])
    colormap = mpl.colors.LinearSegmentedColormap.from_list(
        "oisst_thermal",
        [
            "#123B73", "#1464A0", "#00A6CA", "#54C8A6",
            "#F0DB4F", "#F18D3F", "#D94B3D", "#8E244D",
        ],
    )
    colormap.set_bad("#DDE2E6")
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
    map_axis.set_title("(a) OISST V2.1 after standardization", loc="left", pad=5)
    map_axis.text(
        1.0, 1.018, "25 February 2022", transform=map_axis.transAxes,
        ha="right", va="bottom", fontsize=7.0, color="#6B7C89",
    )
    map_axis.set_xlabel("Longitude (°)")
    map_axis.set_ylabel("Latitude (°)")
    map_axis.set_xticks(np.arange(-180, 181, 60))
    map_axis.set_yticks(np.arange(-90, 91, 30))
    map_axis.grid(color="white", linewidth=0.35, alpha=0.38)
    map_axis.tick_params(length=2.5, labelsize=7.0)
    colorbar = figure.colorbar(
        image, ax=map_axis, orientation="vertical", pad=0.012,
        shrink=0.92, aspect=28,
    )
    colorbar.set_label("Sea-surface temperature (°C)")
    colorbar.outline.set_linewidth(0.55)
    colorbar.ax.tick_params(length=2.3, width=0.5, labelsize=6.8)

    flow_axis = figure.add_subplot(grid[1, 0])
    flow_axis.set_title("(b) Source-to-standard transformation", loc="left", pad=4)
    flow_axis.set_xlim(0, 1)
    flow_axis.set_ylim(0, 1)
    flow_axis.axis("off")
    boxes = [
        (0.015, "01", "Source array", "time × zlev × lat × lon\nInt16 + scale factor", "#2563A6", "#EAF2FA"),
        (0.355, "02", "Standardize", "extract singleton axes\ndecode stored values\nreorder longitude", "#D55E00", "#FFF0E5"),
        (0.695, "03", "Standard grid", "lon × lat\n1440 × 720\nFloat32", "#00875A", "#E8F6EF"),
    ]
    for x, number, heading, body, accent, fill in boxes:
        patch = mpl.patches.FancyBboxPatch(
            (x, 0.20), 0.285, 0.54,
            boxstyle="round,pad=0.016,rounding_size=0.025",
            linewidth=1.05, edgecolor=accent, facecolor=fill,
        )
        flow_axis.add_patch(patch)
        flow_axis.add_patch(
            mpl.patches.FancyBboxPatch(
                (x + 0.018, 0.62), 0.052, 0.082,
                boxstyle="round,pad=0.006,rounding_size=0.018",
                linewidth=0, facecolor=accent,
            )
        )
        flow_axis.text(
            x + 0.044, 0.661, number, ha="center", va="center", fontsize=5.3,
            weight="bold", color="white",
        )
        flow_axis.text(
            x + 0.16, 0.555, heading, ha="center", va="center",
            fontsize=7.2, weight="bold", color=navy,
        )
        flow_axis.text(
            x + 0.1425, 0.355, body, ha="center", va="center",
            fontsize=5.35, linespacing=1.24, color=slate,
        )
    for start in (0.305, 0.645):
        flow_axis.annotate(
            "", xy=(start + 0.044, 0.47), xytext=(start, 0.47),
            arrowprops=dict(arrowstyle="-|>", lw=1.25, color=navy),
        )

    evidence_axis = figure.add_subplot(grid[1, 1])
    evidence_axis.set_title("(c) Independent-reference agreement", loc="left", pad=4)
    evidence_axis.set_xlim(0, 1)
    evidence_axis.set_ylim(0, 1)
    evidence_axis.axis("off")
    comparison = pipeline["comparison"]
    checks = [
        ("Coordinates", "longitude and latitude matched", "#2563A6", "#EEF5FC"),
        ("Grid mask", f'{comparison["finite_count"]:,} finite · {comparison["missing_count"]:,} missing', "#007C83", "#EAF7F7"),
        ("Physical values", f'max |Δ| = {comparison["maximum_absolute_difference"]:.1f} °C', "#D55E00", "#FFF1E8"),
        ("Repeated output", f'{pipeline["case"]["runs"]}/{pipeline["case"]["runs"]} file digests identical', "#6B4FA1", "#F3EFFA"),
    ]
    for row, (label, value, accent, fill) in enumerate(checks):
        y = 0.68 - row * 0.185
        evidence_axis.add_patch(
            mpl.patches.FancyBboxPatch(
                (0.02, y), 0.96, 0.145,
                boxstyle="round,pad=0.010,rounding_size=0.020",
                linewidth=0.85, edgecolor=accent, facecolor=fill,
            )
        )
        evidence_axis.add_patch(
            mpl.patches.Circle((0.073, y + 0.0725), 0.026, facecolor=accent, edgecolor="none")
        )
        evidence_axis.text(
            0.073, y + 0.0725, "✓", color="white", ha="center", va="center",
            fontsize=6.5, weight="bold",
        )
        evidence_axis.text(
            0.12, y + 0.0725, label, ha="left", va="center",
            fontsize=6.0, weight="semibold", color=navy,
        )
        evidence_axis.text(
            0.96, y + 0.0725, value, ha="right", va="center",
            fontsize=5.55, color=slate,
        )

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
