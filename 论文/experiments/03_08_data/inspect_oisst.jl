using Dates
using NetcdfIO
using SHA
using TOML

const ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const RAW_FILE = joinpath(
    ROOT,
    "experiment_data",
    "03_08",
    "raw",
    "oisst-avhrr-v02r01.20220225.nc",
)
const OUTPUT_FILE = joinpath(ROOT, "experiment_data", "03_08", "source_inventory.toml")

function serializable(value)
    if value isa Union{AbstractArray,Tuple}
        return [serializable(item) for item in value]
    elseif value isa Union{AbstractString,Real,Bool,Date,DateTime}
        return value
    end
    return string(value)
end

function main()
    isfile(RAW_FILE) || error("OISST source file is missing: $RAW_FILE")
    mkpath(dirname(OUTPUT_FILE))

    inventory = Dict{String,Any}(
        "source" => Dict(
            "filename" => basename(RAW_FILE),
            "url" => "https://www.ncei.noaa.gov/thredds/fileServer/OisstBase/NetCDF/V2.1/AVHRR/202202/oisst-avhrr-v02r01.20220225.nc",
            "bytes" => filesize(RAW_FILE),
            "sha256" => bytes2hex(open(SHA.sha256, RAW_FILE)),
        ),
    )

    dataset = NetcdfIO.Dataset(RAW_FILE, "r")
    try
        inventory["dimensions"] = Dict(
            String(name) => length(NetcdfIO.read_nc(dataset, name)) for name in keys(dataset.dim)
        )
        inventory["global_attributes"] = Dict(
            String(name) => serializable(value) for (name, value) in NetcdfIO.read_attributes(dataset)
        )
        variables = Dict{String,Any}()
        for name in NetcdfIO.read_varnames(dataset)
            variable = NetcdfIO.find_variable(dataset, name)
            raw_variable = variable.var
            variable_dimensions = [
                NetcdfIO.nc_inq_dimname(NetcdfIO.parent_ncid(raw_variable), dimension_id) for
                dimension_id in raw_variable.dimids
            ]
            variables[String(name)] = Dict(
                "julia_dimensions" => String.(variable_dimensions),
                "netcdf_declared_dimensions" => reverse(String.(variable_dimensions)),
                "size" => collect(size(variable)),
                "element_type" => string(eltype(variable)),
                "attributes" => Dict(
                    String(key) => serializable(value) for
                    (key, value) in NetcdfIO.read_attributes(dataset, name)
                ),
            )
        end
        inventory["variables"] = variables
    finally
        close(dataset)
    end

    open(OUTPUT_FILE, "w") do io
        TOML.print(io, inventory; sorted = true)
    end
    println("OISST inventory written to: $OUTPUT_FILE")
end

main()
