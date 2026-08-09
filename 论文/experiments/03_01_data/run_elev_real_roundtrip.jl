using Dates
using SHA
using TOML
using YAML
using NetcdfIO

const WORKSPACE = dirname(dirname(dirname(dirname(@__DIR__))))
const RESEARCH = joinpath(WORKSPACE, "GriddingMachine_Reaserach")
const GM_REPO = joinpath(WORKSPACE, "GriddingMachine_paper")
const GMD_REPO = joinpath(WORKSPACE, "GriddingMachineDatasets_paper")
const DATA_ROOT = joinpath(RESEARCH, "experiment_data", "03_04")
const WORK = joinpath(RESEARCH, "experiment_data", "03_01", "work")
const CATALOG = joinpath(RESEARCH, "论文", "experiments", "03_04_data", "Artifacts.land.local.yaml")
const SOURCE = joinpath(DATA_ROOT, "downloads", "ELEV_4X_1Y_V1.nc")
const HISTORICAL_YAML = joinpath(GMD_REPO, "yaml", "community", "ELEV_4X_1Y_V1.yaml")
const OUTPUT = joinpath(@__DIR__, "elev_real_roundtrip.toml")

@assert Base.active_project() == joinpath(GM_REPO, "Project.toml")
import GriddingMachine
pushfirst!(LOAD_PATH, GMD_REPO)
import GriddingMachineDatasets

function config()
    Dict{String,Any}(
        "SCHEMA_VERSION" => 1,
        "FILE" => Dict("PATTERN"=>"PREFIX_NX_MT_VV.nc", "PREFIX"=>["ELEV"],
            "NX"=>[4], "MT"=>["1Y"], "VV"=>["V1"]),
        "FOLDER" => Dict("ORIGINAL"=>"elev-input", "REPROCESSED"=>"elev-output"),
        "DATA" => Dict("ABOUT"=>"ELEV_4X_1Y_V1 verified real-product roundtrip",
            "CHANGE_LOGS"=>["No-op roundtrip from the verified standard product"],
            "DIMENSIONS"=>Dict("data"=>["lon","lat"]), "GAPFILL"=>"KEEP_AS_IS",
            "LABEL"=>["data"], "UNIT"=>"m", "VERIFY_ONCE"=>false),
        "GRIDDINGMACHINE" => Dict("TAG"=>"ROUNDTRIP"),
    )
end

function main()
    isfile(SOURCE) || error("Missing verified source file: $SOURCE")
    isfile(CATALOG) || error("Missing local catalog: $CATALOG")
    isdir(WORK) && rm(WORK; recursive=true)
    mkpath(WORK)

    GriddingMachine.Collector.configure!(home=DATA_ROOT, catalog_file=CATALOG,
        catalog_url="http://127.0.0.1/unused", clear=true)
    GriddingMachine.Collector.load_database!(download_if_missing=false)
    integrity = GriddingMachine.Collector.verify_dataset_file(SOURCE,
        "ELEV_4X_1Y_V1"; require_integrity=true)

    raw = NetcdfIO.read_nc(Float32, SOURCE, "data")
    lon = NetcdfIO.read_nc(Float32, SOURCE, "lon")
    lat = NetcdfIO.read_nc(Float32, SOURCE, "lat")
    attrs = NetcdfIO.read_attributes(SOURCE, "data")
    finite = filter(isfinite, Float64.(vec(raw)))
    raw_min, raw_max = minimum(finite), maximum(finite)
    gm = GriddingMachine.Indexer.read_dataset("ELEV_4X_1Y_V1")
    gm_exact = isequal(raw, gm)

    historical = YAML.load_file(HISTORICAL_YAML)
    historical_schema_valid = try
        GriddingMachineDatasets.validate_config(historical)
        true
    catch
        false
    end
    old_limits = Float64.(historical["DATA"]["LIMITS"])
    old_unit = string(historical["DATA"]["UNIT"])
    old_tag = GriddingMachineDatasets.griddingmachine_tag(historical,
        "ELEV", 4, "1Y", "V1", nothing)

    old_home = GriddingMachineDatasets.GRIDDING_MACHINE_HOME
    repetitions = Dict{String,Any}[]
    try
        for run in 1:3
            run_home = joinpath(WORK, "run$(run)")
            input_dir = joinpath(run_home, "original", "elev-input")
            mkpath(input_dir)
            cp(SOURCE, joinpath(input_dir, "ELEV_4X_1Y_V1.nc"); force=true)
            GriddingMachineDatasets.GRIDDING_MACHINE_HOME = run_home
            reviews = Ref(0)
            verifier = (data, section) -> begin
                reviews[] += 1
                isequal(data, raw)
            end
            GriddingMachineDatasets.process_dataset!(config(); verifier)
            produced = joinpath(run_home, "reprocessed", "elev-output",
                "ROUNDTRIP_ELEV_4X_1Y_V1.nc")
            observed = NetcdfIO.read_nc(Float32, produced, "data")
            out_lon = NetcdfIO.read_nc(Float32, produced, "lon")
            out_lat = NetcdfIO.read_nc(Float32, produced, "lat")
            push!(repetitions, Dict(
                "run"=>run, "passed"=>isequal(observed,raw) && out_lon==lon && out_lat==lat,
                "data_exact"=>isequal(observed,raw), "longitude_exact"=>out_lon==lon,
                "latitude_exact"=>out_lat==lat, "verifier_calls"=>reviews[],
                "output_bytes"=>filesize(produced),
                "output_sha256"=>bytes2hex(sha256(read(produced))),
            ))
        end
    finally
        GriddingMachineDatasets.GRIDDING_MACHINE_HOME = old_home
    end

    result = Dict{String,Any}(
        "date"=>string(Dates.today()), "julia_version"=>string(VERSION),
        "platform"=>Sys.MACHINE, "network_requests"=>0,
        "griddingmachine_commit"=>readchomp(`git -C $GM_REPO rev-parse HEAD`),
        "griddingmachinedatasets_commit"=>readchomp(`git -C $GMD_REPO rev-parse HEAD`),
        "source"=>Dict("path"=>SOURCE, "bytes"=>filesize(SOURCE),
            "sha256"=>bytes2hex(sha256(read(SOURCE))), "integrity_verified"=>integrity,
            "shape"=>collect(size(raw)), "finite_min"=>raw_min, "finite_max"=>raw_max,
            "nan_count"=>count(isnan,raw), "unit"=>string(get(attrs,"unit","")),
            "array_sha256"=>bytes2hex(sha256(reinterpret(UInt8,vec(raw))))),
        "independent_read"=>Dict("griddingmachine_exact"=>gm_exact,
            "longitude_first"=>Float64(first(lon)), "longitude_last"=>Float64(last(lon)),
            "latitude_first"=>Float64(first(lat)), "latitude_last"=>Float64(last(lat))),
        "historical_yaml"=>Dict("path"=>HISTORICAL_YAML,"limits"=>old_limits,
            "schema_valid"=>historical_schema_valid,
            "limits_cover_real_range"=>old_limits[1]<=raw_min<=raw_max<=old_limits[2],
            "configured_unit"=>old_unit,"real_unit"=>string(get(attrs,"unit","")),
            "generated_tag"=>old_tag,"matches_current_tag"=>old_tag=="ELEV_4X_1Y_V1"),
        "roundtrip"=>Dict("repetitions"=>repetitions,
            "all_passed"=>all(r->r["passed"],repetitions)),
    )
    open(OUTPUT,"w") do io TOML.print(io,result;sorted=true) end
    rm(WORK; recursive=true)
    passed_repetitions = count(r -> r["passed"], repetitions)
    println("ELEV real roundtrip: GM exact=$gm_exact, repetitions=$passed_repetitions/3")
    result["roundtrip"]["all_passed"] || error("ELEV roundtrip failed")
    gm_exact || error("GriddingMachine full-array read differs from NetCDF")
end

main()
