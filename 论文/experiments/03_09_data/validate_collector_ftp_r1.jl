using Downloads
using GriddingMachine
using NetcdfIO
using SHA
using TOML
using YAML

const TAG = "PPT_ERA5_1X_1H_2020_V1"
const EXPECTED_URL = "ftp://114.214.212.145/GriddingMachine/public/wd1/PPT_ERA5_1X_1H_2020_V1_R1.nc"
const EXPECTED_BYTES = 1_102_213_097
const EXPECTED_SHA256 = "1ae6b80512fac97e6b3e609c02ea126858256cf9153ead1335b5bf8d59fe7725"

file_sha256(path) = open(path, "r") do io
    bytes2hex(sha256(io))
end

function part_files(root)
    found = String[]
    isdir(root) || return found
    for (directory, _, files) in walkdir(root)
        for file in files
            endswith(file, ".part") && push!(found, joinpath(directory, file))
        end
    end
    return found
end

function main()
    length(ARGS) == 3 ||
        error("Usage: validate_collector_ftp_r1.jl CATALOG_YAML EMPTY_HOME RESULT_TOML")
    catalog = abspath(ARGS[1])
    home = abspath(ARGS[2])
    output = abspath(ARGS[3])
    isfile(catalog) || error("Missing formal catalog: $catalog")
    if isdir(home) && !isempty(readdir(home))
        error("Collector validation home must be empty: $home")
    end
    mkpath(home)

    parsed = YAML.load_file(catalog)
    haskey(parsed, TAG) || error("Formal catalog is missing logical tag $TAG")
    entry = parsed[TAG]
    entry["URL"] == [EXPECTED_URL] || error("Unexpected formal URL: $(entry["URL"])")
    entry["SIZE"] == EXPECTED_BYTES || error("Unexpected formal SIZE")
    lowercase(entry["SHA256"]) == EXPECTED_SHA256 || error("Unexpected formal SHA256")

    GriddingMachine.Collector.configure!(
        home = home,
        catalog_file = catalog,
        catalog_url = "http://127.0.0.1/unused",
        clear = true,
    )
    GriddingMachine.Collector.load_database!(download_if_missing = false)
    urls = GriddingMachine.Collector.dataset_url(TAG)
    urls == [EXPECTED_URL] || error("Collector URL differs from the formal catalog")

    accessed_urls = String[]
    recording_downloader = function (url, destination)
        push!(accessed_urls, String(url))
        return Downloads.download(url, destination)
    end
    destination = GriddingMachine.Collector.download_dataset!(
        TAG;
        downloader = recording_downloader,
        probe = _ -> 0.0,
        require_integrity = true,
        refresh_missing = false,
    )
    accessed_urls == [EXPECTED_URL] || error("Collector accessed unexpected URLs: $accessed_urls")
    isfile(destination) || error("Collector did not produce the logical-tag destination")
    basename(destination) == "$TAG.nc" || error("Unexpected destination name: $destination")
    filesize(destination) == EXPECTED_BYTES || error("Collector destination size mismatch")
    digest = file_sha256(destination)
    digest == EXPECTED_SHA256 || error("Collector destination SHA-256 mismatch")
    GriddingMachine.Collector.verify_dataset_file(destination, TAG; require_integrity = true) ||
        error("Collector integrity verification failed")
    isempty(part_files(home)) || error("Collector left temporary .part files after first call")
    attributes = NetcdfIO.read_attributes(destination, "data")
    string(get(attributes, "units", "")) == "m" || error("Collector file data.units is not m")

    modified_before = stat(destination).mtime
    second_network_calls = Ref(0)
    refusing_downloader = function (_url, _destination)
        second_network_calls[] += 1
        error("Second Collector call attempted network access")
    end
    second_destination = GriddingMachine.Collector.download_dataset!(
        TAG;
        downloader = refusing_downloader,
        probe = _ -> error("Second Collector call attempted URL probing"),
        require_integrity = true,
        refresh_missing = false,
    )
    second_destination == destination || error("Second call returned a different destination")
    second_network_calls[] == 0 || error("Second call did not reuse the verified cache")
    stat(destination).mtime == modified_before || error("Second call rewrote the cached file")
    isempty(part_files(home)) || error("Collector left temporary .part files after second call")

    result = Dict{String,Any}(
        "logical_tag" => TAG,
        "physical_url" => EXPECTED_URL,
        "destination" => destination,
        "bytes" => filesize(destination),
        "sha256" => digest,
        "units" => "m",
        "first_call_download_count" => length(accessed_urls),
        "first_call_accessed_url" => only(accessed_urls),
        "part_files_after_first_call" => 0,
        "second_call_network_count" => second_network_calls[],
        "second_call_reused_cache" => true,
        "part_files_after_second_call" => 0,
    )
    mkpath(dirname(output))
    open(output, "w") do io
        TOML.print(io, result; sorted = true)
    end
    println("Collector FTP R1 validation PASS")
    println("logical_tag=", TAG)
    println("physical_url=", EXPECTED_URL)
    println("destination=", destination)
    println("second_call_reused_cache=true")
    println("result=", output)
end

main()
