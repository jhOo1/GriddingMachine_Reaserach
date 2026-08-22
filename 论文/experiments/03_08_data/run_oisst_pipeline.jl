using GriddingMachine
using GriddingMachineDatasets
using NetcdfIO
using SHA
using Statistics
using TOML
using YAML

const ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const CASE_ROOT = joinpath(ROOT, "experiment_data", "03_08")
const GM_HOME = joinpath(CASE_ROOT, "gm_home")
const YAML_FILE = joinpath(CASE_ROOT, "oisst_20220225.yaml")
const REFERENCE_FILE = joinpath(CASE_ROOT, "reference", "oisst_reference_20220225.nc")
const OUTPUT_FILE = joinpath(
    GM_HOME,
    "reprocessed",
    "oisst",
    "SST_OISST_4X_1D_20220225_V1.nc",
)
const LAND_MASK_SOURCE = joinpath(ROOT, "experiment_data", "03_04", "downloads", "LM_4X_1Y_V1.nc")
const LAND_MASK_TAG = "LM_4X_1Y_V1"
const CATALOG_FILE = joinpath(CASE_ROOT, "pipeline_catalog.yaml")
const RESULT_FILE = joinpath(CASE_ROOT, "pipeline_result.toml")

sha256_file(path) = bytes2hex(open(SHA.sha256, path))

function maximum_finite_difference(left, right)
    same_mask = isfinite.(left) .== isfinite.(right)
    all(same_mask) || error("Finite-value masks differ")
    valid = isfinite.(left)
    return maximum(abs.(Float64.(left[valid]) .- Float64.(right[valid])))
end

function prepare_land_mask()
    isfile(LAND_MASK_SOURCE) || error("Land mask is missing: $LAND_MASK_SOURCE")
    target_directory = joinpath(GM_HOME, "support")
    mkpath(target_directory)
    target = joinpath(target_directory, "$LAND_MASK_TAG.nc")
    cp(LAND_MASK_SOURCE, target; force = true)
    catalog = Dict(
        LAND_MASK_TAG => Dict(
            "PATH" => "support",
            "URL" => ["https://example.invalid/$LAND_MASK_TAG.nc"],
            "SIZE" => filesize(target),
            "SHA256" => sha256_file(target),
        ),
    )
    YAML.write_file(CATALOG_FILE, catalog)
    return target
end

function main()
    isfile(YAML_FILE) || error("Production YAML is missing: $YAML_FILE")
    isfile(REFERENCE_FILE) || error("Independent reference is missing: $REFERENCE_FILE")
    reference = NetcdfIO.read_nc(Float32, REFERENCE_FILE, "reference")
    reference_lon = NetcdfIO.read_nc(Float32, REFERENCE_FILE, "lon")
    reference_lat = NetcdfIO.read_nc(Float32, REFERENCE_FILE, "lat")
    land_mask = prepare_land_mask()

    GriddingMachine.Collector.configure!(;
        home = GM_HOME,
        catalog_file = CATALOG_FILE,
        catalog_url = "http://127.0.0.1/unused",
        clear = true,
    )
    GriddingMachine.Collector.load_database!(; download_if_missing = false)
    GriddingMachineDatasets.GRIDDING_MACHINE_HOME = GM_HOME

    run_hashes = String[]
    maximum_differences = Float64[]
    for run in 1:3
        isfile(OUTPUT_FILE) && rm(OUTPUT_FILE; force = true)
        verifier = (data, section) -> begin
            maximum_finite_difference(data, reference) <= 1.0e-6
        end
        GriddingMachineDatasets.process_dataset!(YAML_FILE; verifier)
        isfile(OUTPUT_FILE) || error("Pipeline did not create output on run $run")
        output = NetcdfIO.read_nc(Float32, OUTPUT_FILE, "data")
        push!(maximum_differences, maximum_finite_difference(output, reference))
        push!(run_hashes, sha256_file(OUTPUT_FILE))
    end

    output = NetcdfIO.read_nc(Float32, OUTPUT_FILE, "data")
    output_lon = NetcdfIO.read_nc(Float32, OUTPUT_FILE, "lon")
    output_lat = NetcdfIO.read_nc(Float32, OUTPUT_FILE, "lat")
    finite_values = Float64[value for value in output if isfinite(value)]
    result = Dict{String,Any}(
        "case" => Dict(
            "tag" => "SST_OISST_4X_1D_20220225_V1",
            "output" => relpath(OUTPUT_FILE, ROOT),
            "bytes" => filesize(OUTPUT_FILE),
            "sha256" => sha256_file(OUTPUT_FILE),
            "runs" => 3,
            "scientific_array_reproducible" => length(unique(maximum_differences)) == 1 && only(unique(maximum_differences)) == 0,
            "file_hash_reproducible" => length(unique(run_hashes)) == 1,
        ),
        "comparison" => Dict(
            "shape" => collect(size(output)),
            "finite_count" => length(finite_values),
            "missing_count" => length(output) - length(finite_values),
            "minimum" => minimum(finite_values),
            "maximum" => maximum(finite_values),
            "mean" => mean(finite_values),
            "maximum_absolute_difference" => maximum(maximum_differences),
            "finite_mask_equal" => all(isfinite.(output) .== isfinite.(reference)),
            "longitude_equal" => output_lon == reference_lon,
            "latitude_equal" => output_lat == reference_lat,
            "lon_first" => Float64(first(output_lon)),
            "lon_last" => Float64(last(output_lon)),
            "lat_first" => Float64(first(output_lat)),
            "lat_last" => Float64(last(output_lat)),
        ),
        "provenance" => Dict(
            "yaml" => relpath(YAML_FILE, ROOT),
            "yaml_sha256" => sha256_file(YAML_FILE),
            "reference" => relpath(REFERENCE_FILE, ROOT),
            "reference_sha256" => sha256_file(REFERENCE_FILE),
            "land_mask" => relpath(land_mask, ROOT),
            "land_mask_sha256" => sha256_file(land_mask),
            "julia_version" => string(VERSION),
            "platform" => Sys.MACHINE,
        ),
        "run_sha256" => run_hashes,
    )
    all((
        result["comparison"]["finite_mask_equal"],
        result["comparison"]["longitude_equal"],
        result["comparison"]["latitude_equal"],
        result["comparison"]["maximum_absolute_difference"] <= 1.0e-6,
        result["case"]["scientific_array_reproducible"],
    )) || error("OISST pipeline comparison failed")

    open(RESULT_FILE, "w") do io
        TOML.print(io, result; sorted = true)
    end
    println("OISST pipeline PASS: $RESULT_FILE")
    println("Maximum absolute difference: $(result["comparison"]["maximum_absolute_difference"])")
end

main()
