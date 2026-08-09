using GriddingMachine
using TOML

const ROOT = @__DIR__
const DATA_ROOT = joinpath(dirname(dirname(dirname(ROOT))), "experiment_data", "03_04")
const CATALOG = joinpath(ROOT, "Artifacts.land.local.yaml")
const YEAR = 2020

function finite_max(values)
    finite = filter(isfinite, Float64.(vec(values)))
    return isempty(finite) ? NaN : maximum(finite)
end

function classify_point(name, lat, lon)
    land = GriddingMachine.Indexer.read_dataset("LM_4X_1Y_V1", lat, lon)
    lai = GriddingMachine.Indexer.read_dataset("LAI_MODIS_2X_8D_2020_V1", lat, lon)
    lai_max = finite_max(lai)
    class = !(land > 0) ? "nonland" : lai_max > 0 ? "vegetated" : "bare"
    ilat = GriddingMachine.Indexer.lat_ind(lat, 1)
    ilon = GriddingMachine.Indexer.lon_ind(lon, 1)
    center_lat = (ilat - 0.5) - 90
    center_lon = (ilon - 0.5) - 180
    result = Dict{String,Any}(
        "name" => name,
        "requested_lat" => Float64(lat),
        "requested_lon" => Float64(lon),
        "lat_index" => ilat,
        "lon_index" => ilon,
        "center_lat" => center_lat,
        "center_lon" => center_lon,
        "land_mask" => Float64(land),
        "lai_max" => lai_max,
        "classification" => class,
    )
    try
        dictionary = GriddingMachine.Indexer.grid_dict("gm2", YEAR, lat, lon; verification = true)
        result["grid_dict_success"] = true
        result["grid_dict_key_count"] = length(dictionary)
        result["daily_length"] = length(dictionary["LAI"])
        result["elevation"] = Float64(dictionary["ELEVATION"])
        result["soil_layers"] = length(dictionary["SOIL_N"])
        result["pft_count"] = length(dictionary["PFT_FRACTIONS"])
        result["error"] = ""
    catch exception
        result["grid_dict_success"] = false
        result["grid_dict_key_count"] = 0
        result["daily_length"] = 0
        result["elevation"] = 0.0
        result["soil_layers"] = 0
        result["pft_count"] = 0
        result["error"] = sprint(showerror, exception)
    end
    return result
end

function main()
    isfile(CATALOG) || error("Missing local integrity catalog: $CATALOG")
    GriddingMachine.Collector.configure!(;
        home = DATA_ROOT,
        catalog_file = CATALOG,
        catalog_url = "http://127.0.0.1/unused",
        clear = true,
    )
    GriddingMachine.Collector.load_database!(; download_if_missing = false)
    integrity = Dict{String,Any}()
    for tag in GriddingMachine.Collector.YAML_TAGS
        path = GriddingMachine.Collector.dataset_path(tag)
        integrity[tag] = GriddingMachine.Collector.verify_dataset_file(
            path,
            tag;
            require_integrity = true,
        )
    end
    all(values(integrity)) || error("At least one land file failed SIZE/SHA-256")

    points = Dict(
        "US_NR1" => classify_point("US_NR1", 40.0329, -105.5464),
        "SAHARA" => classify_point("SAHARA", 23.0, 13.0),
    )
    output = Dict(
        "environment" => Dict(
            "julia_version" => string(VERSION),
            "platform" => Sys.MACHINE,
            "year" => YEAR,
            "catalog" => CATALOG,
            "verified_files" => count(identity, values(integrity)),
            "required_files" => length(integrity),
            "network_requests" => 0,
        ),
        "points" => points,
    )
    open(joinpath(ROOT, "land_grid_candidate_pilot.toml"), "w") do io
        TOML.print(io, output; sorted = true)
    end
    for name in sort(collect(keys(points)))
        point = points[name]
        class = point["classification"]
        success = point["grid_dict_success"]
        println("$name: $class, grid_dict=$success")
    end
end

main()
