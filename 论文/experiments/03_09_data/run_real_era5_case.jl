using Emerald
using GriddingMachine
using NetcdfIO
using SHA
using TOML

const ROOT = @__DIR__
const RESEARCH = dirname(dirname(dirname(ROOT)))
const ERA5_HOME = joinpath(RESEARCH, "experiment_data", "03_09")
const ERA5_CATALOG = joinpath(ROOT, "Artifacts.era5.local.yaml")
const LAND_HOME = joinpath(RESEARCH, "experiment_data", "03_04")
const LAND_CATALOG = joinpath(dirname(ROOT), "03_04_data", "Artifacts.land.local.yaml")
const OUTPUT = joinpath(ERA5_HOME, "real_era5_result.toml")
const YEAR = 2020
const LAT = 40.0329
const LON = -105.5464
const EXPECTED_STEPS = 366 * 24
const FTP_BASE = "ftp://114.214.212.145/GriddingMachine/public/wd1"

const FIELD_TAGS = Dict(
    "PATM" => "PATM_ERA5_1X_1H_2020_V1",
    "PPT" => "PPT_ERA5_1X_1H_2020_V1",
    "RAD_SW_DIF" => "RAD_SW_DIF_ERA5_1X_1H_2020_V1",
    "RAD_SW_DIR" => "RAD_SW_DIR_ERA5_1X_1H_2020_V1",
    "RAD_LW" => "RAD_LW_ERA5_1X_1H_2020_V1",
    "TAIR" => "TAIR_ERA5_1X_1H_2020_V1",
    "VPD" => "VPD_ERA5_1X_1H_2020_V1",
    "WIND" => "WIND_ERA5_1X_1H_2020_V1",
)
const PPT_TAG = "PPT_ERA5_1X_1H_2020_V1"

source_filename(tag) = tag == PPT_TAG ? "$(PPT_TAG)_R1.nc" : "$(tag).nc"

file_sha256(path) = open(path, "r") do io
    bytes2hex(sha256(io))
end

function finite_summary(values)
    data = Float64.(values)
    finite = filter(isfinite, data)
    return Dict{String,Any}(
        "length" => length(data),
        "finite_count" => length(finite),
        "finite_fraction" => length(finite) / length(data),
        "minimum" => minimum(finite),
        "maximum" => maximum(finite),
        "mean" => sum(finite) / length(finite),
    )
end

function main()
    mkpath(ERA5_HOME)
    isfile(ERA5_CATALOG) || error("Missing ERA5 catalog: $ERA5_CATALOG")
    isfile(LAND_CATALOG) || error("Missing land catalog: $LAND_CATALOG")

    # Build the real land-parameter dictionary first. The dictionary remains in
    # memory while the collector is switched to the ERA5-only local catalog.
    GriddingMachine.Collector.configure!(
        home = LAND_HOME,
        catalog_file = LAND_CATALOG,
        catalog_url = "http://127.0.0.1/unused",
        clear = true,
    )
    GriddingMachine.Collector.load_database!(download_if_missing = false)
    grid = GriddingMachine.Indexer.grid_dict("gm2", YEAR, LAT, LON; verification = true)

    GriddingMachine.Collector.configure!(
        home = ERA5_HOME,
        catalog_file = ERA5_CATALOG,
        catalog_url = "http://127.0.0.1/unused",
        clear = true,
    )
    GriddingMachine.Collector.load_database!(download_if_missing = false)

    missing_files = String[]
    for tag in values(FIELD_TAGS)
        path = GriddingMachine.Collector.dataset_path(tag)
        isfile(path) || push!(missing_files, path)
    end
    isempty(missing_files) || error(
        "Place the eight 2020 ERA5 files in $(joinpath(ERA5_HOME, "public", "wd1")). Missing:\n" *
        join(missing_files, "\n"),
    )

    drivers = GriddingMachine.Indexer.grid_weather("wd1", YEAR, LAT, LON; verification = true)
    expected_keys = Set(["FDOY"; collect(keys(FIELD_TAGS))])
    Set(keys(drivers)) == expected_keys || error("Unexpected weather dictionary fields")
    all(length(series) == EXPECTED_STEPS for series in Base.values(drivers)) ||
        error("ERA5 time dimension is not $EXPECTED_STEPS")
    all(isfinite, drivers["FDOY"]) || error("FDOY contains non-finite values")
    all(diff(drivers["FDOY"]) .> 0) || error("FDOY is not strictly increasing")
    weather_input_field_count = length(drivers)
    fdoy = copy(drivers["FDOY"])
    timezone_offset_hours = LON / 15
    expected_fdoy = (Float64.(collect(1:EXPECTED_STEPS)) .- 0.5 .+ timezone_offset_hours) ./ 24
    fdoy_max_abs_difference = maximum(abs.(fdoy .- expected_fdoy))
    fdoy_max_abs_difference == 0 || error("FDOY timezone conversion mismatch")

    ilat = GriddingMachine.Indexer.lat_ind(LAT, 1)
    ilon = GriddingMachine.Indexer.lon_ind(LON, 1)
    center_lat = (ilat - 0.5) - 90
    center_lon = (ilon - 0.5) - 180

    fields = Dict{String,Any}()
    files = Dict{String,Any}()
    for field in sort(collect(keys(FIELD_TAGS)))
        tag = FIELD_TAGS[field]
        path = GriddingMachine.Collector.dataset_path(tag)
        direct = Float64.(NetcdfIO.read_nc(path, "data", ilon, ilat))
        via_interface = Float64.(drivers[field])
        length(direct) == EXPECTED_STEPS || error("Unexpected direct-read length for $tag")
        deltas = abs.(direct .- via_interface)
        max_abs_difference = maximum(deltas)
        max_abs_difference == 0 || error("Direct-read mismatch for $tag: $max_abs_difference")
        summary = finite_summary(via_interface)
        summary["max_abs_difference"] = max_abs_difference
        attributes = NetcdfIO.read_attributes(path, "data")
        _, variable_shape = NetcdfIO.read_dims(path, "data")
        summary["units"] = string(get(attributes, "units", ""))
        if field == "PPT"
            ppt_units = summary["units"]
            ppt_units == "m" ||
                error("PPT units must be m after the ERA5 metadata correction; found $ppt_units")
            annual_total_m = sum(via_interface)
            summary["annual_total_m"] = annual_total_m
            summary["annual_total_mm"] = annual_total_m * 1000
        end
        summary["dimension_names"] = collect(String.(NetcdfIO.read_dimnames(path)))
        summary["shape"] = collect(variable_shape)
        summary["dimension_names"] == ["lon", "lat", "ind"] ||
            error("Unexpected dimensions for $tag: $(summary["dimension_names"])")
        summary["shape"] == [360, 180, EXPECTED_STEPS] ||
            error("Unexpected shape for $tag: $(summary["shape"])")
        fields[field] = summary
        files[tag] = Dict(
            "path" => path,
            "source_url" => "$(FTP_BASE)/$(source_filename(tag))",
            "bytes" => filesize(path),
            "sha256" => file_sha256(path),
        )
    end

    config = Emerald.Namespace.SPACConfig(Float64)
    config.CONFIG_INFO.MESSAGE_LEVEL = 0
    spac = Emerald.Land.site_spac(config, grid)
    driver = Emerald.Land.site_driver_tuple(grid, drivers)
    model_driver_field_count = length(drivers)
    Emerald.Land.prescribe!(config, spac, driver, 1; initialize_state = true)
    initialization_finite = all(isfinite, spac.airs[1].state.ns) && isfinite(spac.airs[1].state.p_air)
    initialization_finite || error("Emerald initialization produced non-finite atmospheric state")
    Emerald.SPAC.soil_plant_air_continuum!(config, spac, 60.0)
    first_step_finite = all(air -> all(isfinite, air.state.ns) && isfinite(air.state.p_air), spac.airs) &&
                        all(soil -> all(isfinite, soil.state.ns), spac.soils)
    first_step_finite || error("Emerald first step produced non-finite state")

    result = Dict{String,Any}(
        "case" => Dict(
            "year" => YEAR,
            "requested_latitude" => LAT,
            "requested_longitude" => LON,
            "grid_center_latitude" => center_lat,
            "grid_center_longitude" => center_lon,
            "time_steps" => EXPECTED_STEPS,
            "field_count" => length(FIELD_TAGS),
            "total_bytes" => sum(item["bytes"] for item in Base.values(files)),
        ),
        "fields" => fields,
        "files" => files,
        "time_axis" => Dict(
            "length" => length(fdoy),
            "finite_fraction" => count(isfinite, fdoy) / length(fdoy),
            "strictly_increasing" => all(diff(fdoy) .> 0),
            "timezone_offset_hours" => timezone_offset_hours,
            "first_fdoy" => first(fdoy),
            "last_fdoy" => last(fdoy),
            "formula_max_abs_difference" => fdoy_max_abs_difference,
        ),
        "model" => Dict(
            "land_parameter_count" => length(grid),
            "weather_input_field_count" => weather_input_field_count,
            "model_driver_field_count" => model_driver_field_count,
            "initialization_finite" => initialization_finite,
            "first_step_seconds" => 60,
            "first_step_finite" => first_step_finite,
        ),
        "environment" => Dict(
            "julia_version" => string(VERSION),
            "platform" => Sys.MACHINE,
            "network_requests" => 0,
        ),
    )
    open(OUTPUT, "w") do io
        TOML.print(io, result; sorted = true)
    end
    println("ERA5 real-data case PASS")
    println("Result: $OUTPUT")
end

main()
