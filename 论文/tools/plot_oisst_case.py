from __future__ import annotations

from pathlib import Path
import tomllib

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np


ROOT = Path(__file__).resolve().parents[2]
CASE_ROOT = ROOT / "experiment_data" / "03_08"
SUMMARY_FILE = CASE_ROOT / "reference_summary.toml"
BINARY_FILE = CASE_ROOT / "reference" / "oisst_reference_20220225_f32.bin"
OUTPUT_PNG = ROOT / "论文" / "figures" / "图2_OISST真实产品标准化结果.png"
OUTPUT_SVG = ROOT / "论文" / "figures" / "图2_OISST真实产品标准化结果.svg"


def main() -> None:
    with SUMMARY_FILE.open("rb") as stream:
        summary = tomllib.load(stream)

    shape = tuple(summary["target"]["shape"])
    data = np.fromfile(BINARY_FILE, dtype="<f4").reshape(shape, order="F")
    lons = np.linspace(
        summary["target"]["lon_first"], summary["target"]["lon_last"], shape[0]
    )
    lats = np.linspace(
        summary["target"]["lat_first"], summary["target"]["lat_last"], shape[1]
    )
    finite = np.isfinite(data)
    zonal_count = finite.sum(axis=0)
    zonal_mean = np.divide(
        np.nansum(data, axis=0),
        zonal_count,
        out=np.full(shape[1], np.nan, dtype=float),
        where=zonal_count > 0,
    )
    valid_fraction = finite.mean(axis=0) * 100

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

    mean_axis = figure.add_subplot(grid[1, 0])
    mean_axis.plot(lats, zonal_mean, color="#165D9C", linewidth=1.5)
    mean_axis.fill_between(lats, zonal_mean, -2, color="#5FA8D3", alpha=0.18)
    mean_axis.set_title("(b) Zonal mean of finite grid cells", loc="left")
    mean_axis.set_xlabel("Latitude (°)")
    mean_axis.set_ylabel("SST (°C)")
    mean_axis.set_xlim(-90, 90)
    mean_axis.set_xticks(np.arange(-90, 91, 30))
    mean_axis.grid(color="#cfd6df", linewidth=0.45, alpha=0.7)
    mean_axis.spines[["top", "right"]].set_visible(False)

    coverage_axis = figure.add_subplot(grid[1, 1])
    coverage_axis.plot(lats, valid_fraction, color="#B44A3A", linewidth=1.5)
    coverage_axis.fill_between(lats, valid_fraction, 0, color="#E5987D", alpha=0.2)
    coverage_axis.set_title("(c) Valid-grid coverage by latitude", loc="left")
    coverage_axis.set_xlabel("Latitude (°)")
    coverage_axis.set_ylabel("Valid cells (%)")
    coverage_axis.set_xlim(-90, 90)
    coverage_axis.set_ylim(0, 100)
    coverage_axis.set_xticks(np.arange(-90, 91, 30))
    coverage_axis.grid(color="#cfd6df", linewidth=0.45, alpha=0.7)
    coverage_axis.spines[["top", "right"]].set_visible(False)

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
