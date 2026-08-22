using NetcdfIO
using SHA
using Statistics
using TOML
using YAML

const ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const CASE_ROOT = joinpath(ROOT, "experiment_data", "03_08")
const RAW_FILE = joinpath(CASE_ROOT, "raw", "oisst-avhrr-v02r01.20220225.nc")
const GM_HOME = joinpath(CASE_ROOT, "gm_home")
const ADAPTED_FILE = joinpath(
    GM_HOME,
    "original",
    "oisst",
    "OISST_4X_1D_20220225_V1.nc",
)
const REFERENCE_FILE = joinpath(CASE_ROOT, "reference", "oisst_reference_20220225.nc")
const REFERENCE_BINARY = joinpath(CASE_ROOT, "reference", "oisst_reference_20220225_f32.bin")
const SUMMARY_FILE = joinpath(CASE_ROOT, "reference_summary.toml")
const YAML_FILE = joinpath(CASE_ROOT, "oisst_20220225.yaml")
const SOURCE_URL = "https://www.ncei.noaa.gov/thredds/fileServer/OisstBase/NetCDF/V2.1/AVHRR/202202/oisst-avhrr-v02r01.20220225.nc"

sha256_file(path) = bytes2hex(open(SHA.sha256, path))

function finite_statistics(data)
    values = Float64[value for value in data if isfinite(value)]
    return Dict{String,Any}(
        "finite_count" => length(values),
        "missing_count" => length(data) - length(values),
        "minimum" => minimum(values),
        "maximum" => maximum(values),
        "mean" => mean(values),
    )
end

function sample_indices(mask::AbstractArray{Bool}, count::Int)
    available = findall(mask)
    isempty(available) && return CartesianIndex[]
    positions = unique(round.(Int, range(1, length(available); length = min(count, length(available)))))
    return available[positions]
end

function sample_table(data, lons, lats, indexes)
    return Dict{String,Any}(
        "lon" => Float64[lons[index[1]] for index in indexes],
        "lat" => Float64[lats[index[2]] for index in indexes],
        "lon_index" => Int[index[1] for index in indexes],
        "lat_index" => Int[index[2] for index in indexes],
        "value" => Float64[data[index] for index in indexes],
    )
end

function write_2d_netcdf(path, variable_name, data, lons, lats, variable_attributes, global_attributes)
    mkpath(dirname(path))
    isfile(path) && rm(path; force = true)
    dataset = NetcdfIO.Dataset(path, "c")
    try
        for (name, value) in global_attributes
            dataset.attrib[name] = value
        end
        NetcdfIO.add_nc_dim!(dataset, "lon", length(lons))
        NetcdfIO.add_nc_dim!(dataset, "lat", length(lats))
        NetcdfIO.append_nc!(
            dataset,
            "lon",
            Float32.(lons),
            Dict{String,Any}("units" => "degrees_east", "long_name" => "Longitude"),
            ["lon"],
        )
        NetcdfIO.append_nc!(
            dataset,
            "lat",
            Float32.(lats),
            Dict{String,Any}("units" => "degrees_north", "long_name" => "Latitude"),
            ["lat"],
        )
        NetcdfIO.append_nc!(
            dataset,
            variable_name,
            Float32.(data),
            variable_attributes,
            ["lon", "lat"];
            deflatelevel = 4,
        )
    finally
        close(dataset)
    end
end

function main()
    isfile(RAW_FILE) || error("OISST source file is missing: $RAW_FILE")
    raw_sha256 = sha256_file(RAW_FILE)
    raw_storage = NetcdfIO.read_nc(RAW_FILE, "sst"; transform = false)
    size(raw_storage) == (1440, 720, 1, 1) || error("Unexpected SST shape: $(size(raw_storage))")

    attributes = NetcdfIO.read_attributes(RAW_FILE, "sst")
    scale_factor = Float64(attributes["scale_factor"])
    add_offset = Float64(attributes["add_offset"])
    fill_value = attributes["_FillValue"]
    raw_2d = raw_storage[:, :, 1, 1]
    decoded = Float32.(Float64.(raw_2d) .* scale_factor .+ add_offset)
    decoded[raw_2d .== fill_value] .= NaN32

    source_lons = Float32.(NetcdfIO.read_nc(RAW_FILE, "lon"))
    source_lats = Float32.(NetcdfIO.read_nc(RAW_FILE, "lat"))
    issorted(source_lons) || error("Source longitude is not ascending")
    issorted(source_lats) || error("Source latitude is not ascending")

    split_index = findfirst(>=(180), source_lons)
    isnothing(split_index) && error("Could not locate the 180-degree longitude split")
    target_lons = vcat(source_lons[split_index:end] .- 360, source_lons[1:split_index-1])
    target_lats = copy(source_lats)
    reference = vcat(decoded[split_index:end, :], decoded[1:split_index-1, :])
    issorted(target_lons) || error("Target longitude is not ascending")

    source_attributes = Dict{String,Any}(
        "about" => "NOAA/NCEI OISST v2.1 daily sea surface temperature; singleton time and zlev dimensions extracted by a versioned source adapter.",
        "unit" => "degree_Celsius",
        "source_file" => basename(RAW_FILE),
        "source_sha256" => raw_sha256,
        "source_url" => SOURCE_URL,
        "source_variable" => "sst",
        "source_dimensions" => "lon,lat,zlev,time",
        "selected_time_index" => 1,
        "selected_zlev_index" => 1,
    )
    global_attributes = Dict{String,Any}(
        "title" => "OISST v2.1 source-adapted input for the GriddingMachine paper",
        "source" => SOURCE_URL,
        "source_sha256" => raw_sha256,
        "product_version" => "v02r01",
        "time_coverage_start" => "2022-02-25T00:00:00Z",
        "time_coverage_end" => "2022-02-25T23:59:59Z",
        "processing" => "Extracted the only time and zlev layers; retained decoded values and original 0-360 longitude order.",
    )
    write_2d_netcdf(
        ADAPTED_FILE,
        "sst_source",
        decoded,
        source_lons,
        source_lats,
        source_attributes,
        global_attributes,
    )

    reference_attributes = copy(source_attributes)
    reference_attributes["about"] = "Independent OISST v2.1 physical-value reference on the GriddingMachine longitude-latitude grid."
    reference_attributes["processing"] = "Raw Int16 values decoded with scale_factor/add_offset, fill values mapped to NaN, and longitudes shifted to [-180,180)."
    write_2d_netcdf(
        REFERENCE_FILE,
        "reference",
        reference,
        target_lons,
        target_lats,
        reference_attributes,
        Dict{String,Any}(
            "title" => "Independent OISST v2.1 reference for GriddingMachine",
            "source" => SOURCE_URL,
            "source_sha256" => raw_sha256,
        ),
    )
    open(REFERENCE_BINARY, "w") do io
        write(io, reference)
    end

    valid_indexes = sample_indices(isfinite.(reference), 10)
    missing_indexes = sample_indices(.!isfinite.(reference), 10)
    summary = Dict{String,Any}(
        "source" => Dict(
            "url" => SOURCE_URL,
            "filename" => basename(RAW_FILE),
            "bytes" => filesize(RAW_FILE),
            "sha256" => raw_sha256,
            "variable" => "sst",
            "netcdf_declared_dimensions" => ["time", "zlev", "lat", "lon"],
            "julia_dimensions" => ["lon", "lat", "zlev", "time"],
            "shape" => collect(size(raw_storage)),
            "storage_type" => string(eltype(raw_storage)),
            "scale_factor" => scale_factor,
            "add_offset" => add_offset,
            "fill_value" => Int(fill_value),
        ),
        "target" => merge(
            finite_statistics(reference),
            Dict{String,Any}(
                "shape" => collect(size(reference)),
                "lon_first" => Float64(first(target_lons)),
                "lon_last" => Float64(last(target_lons)),
                "lat_first" => Float64(first(target_lats)),
                "lat_last" => Float64(last(target_lats)),
            ),
        ),
        "valid_samples" => sample_table(reference, target_lons, target_lats, valid_indexes),
        "missing_samples" => Dict{String,Any}(
            "lon" => Float64[target_lons[index[1]] for index in missing_indexes],
            "lat" => Float64[target_lats[index[2]] for index in missing_indexes],
            "lon_index" => Int[index[1] for index in missing_indexes],
            "lat_index" => Int[index[2] for index in missing_indexes],
        ),
        "files" => Dict(
            "adapted_input" => relpath(ADAPTED_FILE, ROOT),
            "adapted_sha256" => sha256_file(ADAPTED_FILE),
            "reference" => relpath(REFERENCE_FILE, ROOT),
            "reference_sha256" => sha256_file(REFERENCE_FILE),
            "reference_binary" => relpath(REFERENCE_BINARY, ROOT),
            "reference_binary_sha256" => sha256_file(REFERENCE_BINARY),
        ),
    )
    open(SUMMARY_FILE, "w") do io
        TOML.print(io, summary; sorted = true)
    end

    config = Dict{String,Any}(
        "SCHEMA_VERSION" => 1,
        "FILE" => Dict(
            "PATTERN" => "PREFIX_NX_X_MT_YYYY_VV.nc",
            "PREFIX" => ["OISST"],
            "NX" => [4],
            "MT" => ["1D"],
            "YYYY" => [20220225],
            "VV" => ["V1"],
        ),
        "FOLDER" => Dict("ORIGINAL" => "oisst", "REPROCESSED" => "oisst"),
        "DATA" => Dict(
            "ABOUT" => "NOAA/NCEI OISST v2.1 daily sea surface temperature for 2022-02-25.",
            "CHANGE_LOGS" => [
                "The only time and zlev layers were extracted by the versioned OISST source adapter.",
                "Packed source values were decoded using the source scale_factor and add_offset.",
                "Source fill values were represented as NaN.",
                "Source identity: $(basename(RAW_FILE)); SHA-256: $raw_sha256.",
            ],
            "DIMENSIONS" => Dict("sst_source" => ["lon", "lat"]),
            "FLIP_LON" => true,
            "GAPFILL" => "KEEP_AS_IS",
            "LABEL" => ["sst_source"],
            "LIMITS" => [-3.0, 45.0],
            "UNIT" => "degree_Celsius",
            "VERIFY_ONCE" => false,
        ),
        "GRIDDINGMACHINE" => Dict("TAG" => "SST_OISST"),
    )
    YAML.write_file(YAML_FILE, config)

    println("Adapted OISST input: $ADAPTED_FILE")
    println("Independent reference: $REFERENCE_FILE")
    println("Production YAML: $YAML_FILE")
    println("Reference finite/missing: $(summary["target"]["finite_count"])/$(summary["target"]["missing_count"])")
end

main()
