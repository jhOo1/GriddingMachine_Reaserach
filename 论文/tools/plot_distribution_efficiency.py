"""Create Figure 2 directly from the archived Windows/macOS summary CSV files."""

from __future__ import annotations

import csv
from pathlib import Path

import matplotlib.pyplot as plt


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "experiments" / "03_02_data"
FIGURES = ROOT / "figures"
STEM = FIGURES / "图2_直接NetCDF分发效率"

PLATFORMS = {
    "Windows": DATA / "pilot_windows_summary.csv",
    "macOS": DATA / "pilot_macos_summary.csv",
}
DATASETS = [
    ("ELEV_4X_1Y_V1", "ELEV"),
    ("LAI_MODIS_2X_8D_2020_V1", "LAI"),
]
COLORS = {"nc": "#1F5A85", "tar.gz": "#C56A16"}


def load_end_to_end(path: Path) -> dict[tuple[str, str], dict[str, float]]:
    selected: dict[tuple[str, str], dict[str, float]] = {}
    with path.open(encoding="utf-8-sig", newline="") as stream:
        for row in csv.DictReader(stream):
            if row["metric"] != "end_to_end_ms":
                continue
            selected[(row["dataset"], row["distribution"])] = {
                key: float(row[key])
                for key in ("median", "ci95_low", "ci95_high")
            }
    return selected


def main() -> None:
    records = {platform: load_end_to_end(path) for platform, path in PLATFORMS.items()}
    plt.rcParams.update(
        {
            "font.family": "DejaVu Sans",
            "font.size": 9,
            "axes.labelcolor": "#23313F",
            "axes.edgecolor": "#A8B2BC",
            "xtick.color": "#425466",
            "ytick.color": "#425466",
        }
    )
    figure, axes = plt.subplots(1, 2, figsize=(7.2, 3.25), constrained_layout=True)
    width = 0.32
    x_positions = [0, 1]

    for panel_index, ((dataset, short_name), axis) in enumerate(zip(DATASETS, axes)):
        for distribution, offset in (("nc", -width / 2), ("tar.gz", width / 2)):
            medians = []
            lower = []
            upper = []
            for platform in PLATFORMS:
                values = records[platform][(dataset, distribution)]
                medians.append(values["median"])
                lower.append(values["median"] - values["ci95_low"])
                upper.append(values["ci95_high"] - values["median"])
            bars = axis.bar(
                [position + offset for position in x_positions],
                medians,
                width=width,
                color=COLORS[distribution],
                edgecolor="white",
                linewidth=0.7,
                label="Direct NetCDF" if distribution == "nc" else "NetCDF in tar.gz",
                yerr=[lower, upper],
                capsize=3,
                error_kw={"elinewidth": 1, "ecolor": "#374957"},
                zorder=3,
            )
            for bar, value in zip(bars, medians):
                axis.text(
                    bar.get_x() + bar.get_width() / 2,
                    bar.get_height(),
                    f"{value:.1f}",
                    ha="center",
                    va="bottom",
                    fontsize=8,
                    color="#23313F",
                )

        for position, platform in zip(x_positions, PLATFORMS):
            direct = records[platform][(dataset, "nc")]["median"]
            archived = records[platform][(dataset, "tar.gz")]["median"]
            reduction = (1 - direct / archived) * 100
            y = max(direct, archived) * 1.18
            axis.text(
                position,
                y,
                f"−{reduction:.1f}%",
                ha="center",
                va="bottom",
                fontsize=8.5,
                fontweight="bold",
                color="#6A3A0E",
            )

        axis.set_title(f"({chr(97 + panel_index)}) {short_name}", loc="left", fontweight="bold")
        axis.set_xticks(x_positions, list(PLATFORMS))
        axis.set_ylabel("Median end-to-end time (ms)")
        axis.grid(axis="y", color="#E5E9ED", linewidth=0.8, zorder=0)
        axis.spines[["top", "right"]].set_visible(False)
        ymax = max(
            records[platform][(dataset, distribution)]["ci95_high"]
            for platform in PLATFORMS
            for distribution in ("nc", "tar.gz")
        )
        axis.set_ylim(0, ymax * 1.38)

    handles, labels = axes[0].get_legend_handles_labels()
    figure.legend(
        handles,
        labels,
        loc="outside upper center",
        ncol=2,
        frameon=False,
        bbox_to_anchor=(0.5, 1.12),
    )
    svg_path = STEM.with_suffix(".svg")
    figure.savefig(svg_path, bbox_inches="tight")
    svg_text = svg_path.read_text(encoding="utf-8")
    svg_path.write_text(
        "\n".join(line.rstrip() for line in svg_text.splitlines()) + "\n",
        encoding="utf-8",
    )
    figure.savefig(STEM.with_suffix(".png"), dpi=300, bbox_inches="tight")
    plt.close(figure)
    print(STEM.with_suffix(".png"))


if __name__ == "__main__":
    main()
