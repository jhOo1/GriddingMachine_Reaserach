using GriddingMachine
using GriddingMachineDatasets
using NetcdfIO
using SHA
using Sockets
using TOML
using YAML

const ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const CASE_ROOT = joinpath(ROOT, "experiment_data", "03_08")
const TAG = "SST_OISST_4X_1D_20220225_V1"
const PRODUCT_FILE = joinpath(
    CASE_ROOT,
    "gm_home",
    "reprocessed",
    "oisst",
    "$TAG.nc",
)
const REFERENCE_FILE = joinpath(CASE_ROOT, "reference", "oisst_reference_20220225.nc")
const DISTRIBUTION_HOME = joinpath(CASE_ROOT, "distribution_home")
const CATALOG_FILE = joinpath(CASE_ROOT, "oisst_catalog.yaml")
const RESULT_FILE = joinpath(CASE_ROOT, "distribution_result.toml")
const PORT = 18765
const URL = "http://127.0.0.1:$PORT/$TAG.nc"

sha256_file(path) = bytes2hex(open(SHA.sha256, path))

function maximum_finite_difference(left, right)
    all(isfinite.(left) .== isfinite.(right)) || error("Finite-value masks differ")
    valid = isfinite.(left)
    return maximum(abs.(Float64.(left[valid]) .- Float64.(right[valid])))
end

function start_file_server()
    listener = Sockets.listen(ip"127.0.0.1", PORT)
    task = @async begin
        while isopen(listener)
            socket = try
                accept(listener)
            catch error_value
                isopen(listener) && rethrow(error_value)
                break
            end
            try
                request_line = readline(socket)
                while !eof(socket)
                    isempty(strip(readline(socket))) && break
                end
                requested_path = split(request_line)[2]
                if requested_path == "/$TAG.nc"
                    payload = read(PRODUCT_FILE)
                    write(socket, "HTTP/1.1 200 OK\r\n")
                    write(socket, "Content-Type: application/x-netcdf\r\n")
                    write(socket, "Content-Length: $(length(payload))\r\n")
                    write(socket, "Connection: close\r\n\r\n")
                    write(socket, payload)
                else
                    payload = Vector{UInt8}(codeunits("not found"))
                    write(socket, "HTTP/1.1 404 Not Found\r\n")
                    write(socket, "Content-Length: $(length(payload))\r\n")
                    write(socket, "Connection: close\r\n\r\n")
                    write(socket, payload)
                end
            finally
                close(socket)
            end
        end
    end
    return listener, task
end

function main()
    isfile(PRODUCT_FILE) || error("OISST product is missing: $PRODUCT_FILE")
    isfile(REFERENCE_FILE) || error("OISST reference is missing: $REFERENCE_FILE")

    server, server_task = start_file_server()

    try
        isdir(DISTRIBUTION_HOME) && rm(DISTRIBUTION_HOME; recursive = true, force = true)
        mkpath(DISTRIBUTION_HOME)
        artifact = Dict(
            TAG => Dict(
                "FILE" => PRODUCT_FILE,
                "URL" => [URL],
                "PATH" => "public/oisst",
            ),
        )
        catalog = GriddingMachineDatasets.update_yaml_library!(CATALOG_FILE, artifact)
        entry = catalog[TAG]

        GriddingMachine.Collector.configure!(;
            home = DISTRIBUTION_HOME,
            catalog_file = CATALOG_FILE,
            catalog_url = "http://127.0.0.1/unused",
            clear = true,
        )
        GriddingMachine.Collector.load_database!(; download_if_missing = false)
        downloaded = GriddingMachine.Collector.download_dataset!(
            TAG;
            probe = _ -> 0.0,
            require_integrity = true,
            refresh_missing = false,
        )
        output = GriddingMachine.Indexer.read_dataset(TAG)
        reference = NetcdfIO.read_nc(Float32, REFERENCE_FILE, "reference")
        maximum_difference = maximum_finite_difference(output, reference)
        part_files = filter(
            name -> endswith(name, ".part"),
            readdir(joinpath(DISTRIBUTION_HOME, "cache")),
        )

        result = Dict{String,Any}(
            "catalog" => Dict(
                "tag" => TAG,
                "path" => entry["PATH"],
                "urls" => entry["URL"],
                "size" => entry["SIZE"],
                "sha256" => entry["SHA256"],
            ),
            "download" => Dict(
                "url" => URL,
                "path" => relpath(downloaded, ROOT),
                "bytes" => filesize(downloaded),
                "sha256" => sha256_file(downloaded),
                "integrity_verified" => GriddingMachine.Collector.verify_dataset_file(
                    downloaded,
                    TAG;
                    require_integrity = true,
                ),
                "remaining_part_files" => length(part_files),
            ),
            "read_dataset" => Dict(
                "shape" => collect(size(output)),
                "finite_mask_equal" => all(isfinite.(output) .== isfinite.(reference)),
                "maximum_absolute_difference" => maximum_difference,
            ),
            "environment" => Dict(
                "julia_version" => string(VERSION),
                "platform" => Sys.MACHINE,
                "controlled_http_port" => PORT,
            ),
        )
        all((
            result["download"]["integrity_verified"],
            result["download"]["remaining_part_files"] == 0,
            result["read_dataset"]["finite_mask_equal"],
            result["read_dataset"]["maximum_absolute_difference"] <= 1.0e-6,
            result["catalog"]["size"] == result["download"]["bytes"],
            result["catalog"]["sha256"] == result["download"]["sha256"],
        )) || error("OISST distribution closure failed")

        open(RESULT_FILE, "w") do io
            TOML.print(io, result; sorted = true)
        end
        println("OISST distribution PASS: $RESULT_FILE")
        println("Downloaded SHA-256: $(result["download"]["sha256"])")
    finally
        close(server)
        wait(server_task)
    end
end

main()
