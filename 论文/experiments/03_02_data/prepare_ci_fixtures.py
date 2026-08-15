#!/usr/bin/env python3
"""Create small deterministic NetCDF inputs used only by cross-platform CI.

The paper's archived timing results continue to use the integrity-checked ELEV
and LAI products.  These compact files exist only to exercise the same direct
NetCDF versus tar.gz workflow on clean GitHub runners without publishing the
large research inputs in the source repository.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from netCDF4 import Dataset


def write_fixture(path: Path, periods: int | None) -> None:
    if path.exists():
        raise FileExistsError(f"Refusing to replace existing fixture: {path}")

    nlon, nlat = 64, 32
    lon = np.linspace(-180.0 + 180.0 / nlon, 180.0 - 180.0 / nlon, nlon, dtype="f4")
    lat = np.linspace(-90.0 + 90.0 / nlat, 90.0 - 90.0 / nlat, nlat, dtype="f4")
    base = lon[:, None] * np.float32(0.25) + lat[None, :] * np.float32(0.5)

    with Dataset(path, "w", format="NETCDF4") as dataset:
        dataset.createDimension("lon", nlon)
        dataset.createDimension("lat", nlat)
        dataset.createVariable("lon", "f4", ("lon",))[:] = lon
        dataset.createVariable("lat", "f4", ("lat",))[:] = lat
        if periods is None:
            variable = dataset.createVariable(
                "data", "f4", ("lon", "lat"), zlib=True, complevel=4
            )
            variable[:] = base
        else:
            dataset.createDimension("ind", periods)
            variable = dataset.createVariable(
                "data", "f4", ("lon", "lat", "ind"), zlib=True, complevel=4
            )
            variable[:] = np.stack(
                [base + np.float32(index) / np.float32(periods) for index in range(periods)],
                axis=2,
            )
        variable.setncattr("ci_fixture", "true")
        dataset.setncattr("purpose", "cross-platform workflow validation only")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    write_fixture(args.output_dir / "ELEV_4X_1Y_V1.nc", periods=None)
    write_fixture(args.output_dir / "LAI_MODIS_2X_8D_2020_V1.nc", periods=46)
    print(f"CI fixtures created in {args.output_dir.resolve()}")


if __name__ == "__main__":
    main()
