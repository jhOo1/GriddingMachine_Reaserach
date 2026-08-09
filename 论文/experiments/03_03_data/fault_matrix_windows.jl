using Dates
using Downloads
using Random
using SHA
using Sockets
using Statistics
using TOML

const ROOT = @__DIR__
const WORK_ROOT = joinpath(ROOT, "work")
const WORKSPACE = dirname(dirname(dirname(dirname(ROOT))))
const GM_REPO = get(ENV, "GRIDDING_MACHINE_PAPER_REPO", joinpath(WORKSPACE, "GriddingMachine_paper"))
const DOWNLOAD_SOURCE = joinpath(GM_REPO, "src", "Collector", "dataset-download.jl")
const SOURCE_DATA = joinpath(dirname(ROOT), "03_02_data", "ELEV_4X_1Y_V1.nc")
const TAG = "FAULT_4X_1Y_V1"
const REPETITIONS = 5
const SEED = 20260809
const BOOTSTRAP_SAMPLES = 5000

isfile(DOWNLOAD_SOURCE) || error("Missing Collector source: $DOWNLOAD_SOURCE")
isfile(SOURCE_DATA) || error("Missing integrity-checked fixture: $SOURCE_DATA")
mkpath(WORK_ROOT)

sha256_hex(data::Vector{UInt8}) = bytes2hex(SHA.sha256(data))
sha256_file(path::AbstractString) = open(path, "r") do io
    bytes2hex(SHA.sha256(io))
end

module CollectorHarness
using Downloads
using SHA

module HTTP
using Downloads
function request(method, url; status_exception = false, connect_timeout = 5, readtimeout = 5)
    return Downloads.request(url; method, timeout = max(connect_timeout, readtimeout))
end
end

struct CatalogValidationError <: Exception
    errors::Vector{String}
end
Base.showerror(io::IO, error::CatalogValidationError) = print(io, join(error.errors, "; "))

GRIDDINGMACHINE_HOME = ""
const DATABASE = Dict{String,Dict{String,Any}}()

dataset_found(tag::String) = haskey(DATABASE, tag)
update_database!() = nothing
dataset_url(tag::String) = String.(DATABASE[tag]["URL"])
dataset_path(tag::String) = joinpath(GRIDDINGMACHINE_HOME, DATABASE[tag]["PATH"], "$tag.nc")
function _expected_integrity(tag::String)
    entry = DATABASE[tag]
    return get(entry, "SIZE", nothing), get(entry, "SHA256", nothing)
end
function initialize_database!()
    mkpath(joinpath(GRIDDINGMACHINE_HOME, "cache"))
    mkpath(joinpath(GRIDDINGMACHINE_HOME, "public"))
    return nothing
end

include(Main.DOWNLOAD_SOURCE)

function configure!(home::String, urls::Vector{String}, data::Vector{UInt8})
    global GRIDDINGMACHINE_HOME = abspath(home)
    empty!(DATABASE)
    DATABASE[Main.TAG] = Dict{String,Any}(
        "PATH" => "public/v0",
        "URL" => urls,
        "SIZE" => length(data),
        "SHA256" => Main.sha256_hex(data),
    )
    initialize_database!()
    return nothing
end
end

Base.@kwdef mutable struct Behavior
    body::Vector{UInt8}
    head_status::Int = 200
    get_status::Int = 200
    head_delay::Float64 = 0.0
    get_delay::Float64 = 0.0
    head_action::Symbol = :normal
    get_action::Symbol = :normal
    announced_length::Int = length(body)
end

mutable struct FaultServer
    listener::Sockets.TCPServer
    port::Int
    behavior::Behavior
    requests::Vector{String}
    lock::ReentrantLock
    task::Task
end

function response_reason(status::Int)
    return get(Dict(200 => "OK", 404 => "Not Found", 500 => "Internal Server Error"), status, "Status")
end

function handle_connection(server::FaultServer, socket)
    try
        request_line = readline(socket)
        isempty(strip(request_line)) && return
        parts = split(strip(request_line))
        length(parts) >= 2 || return
        method, target = parts[1], split(parts[2], '?')[1]
        while !eof(socket)
            isempty(strip(readline(socket))) && break
        end
        lock(server.lock) do
            push!(server.requests, "$method $target")
        end
        behavior = server.behavior
        action = method == "HEAD" ? behavior.head_action : behavior.get_action
        delay = method == "HEAD" ? behavior.head_delay : behavior.get_delay
        status = method == "HEAD" ? behavior.head_status : behavior.get_status
        sleep(delay)
        action == :reset && return
        announced = behavior.announced_length
        header = "HTTP/1.1 $status $(response_reason(status))\r\n" *
                 "Content-Type: application/x-netcdf\r\n" *
                 "Content-Length: $announced\r\n" *
                 "Connection: close\r\n\r\n"
        write(socket, header)
        if method != "HEAD"
            if action == :truncate
                write(socket, behavior.body[1:max(1, length(behavior.body) ÷ 2)])
            else
                write(socket, behavior.body)
            end
        end
        flush(socket)
    catch
        # Connection-level faults are expected inputs to this experiment.
    finally
        close(socket)
    end
end

function start_server(behavior::Behavior)
    listener = listen(ip"127.0.0.1", 0)
    port = getsockname(listener)[2]
    server = FaultServer(listener, port, behavior, String[], ReentrantLock(), Task(() -> nothing))
    server.task = errormonitor(@async begin
        while isopen(listener)
            try
                socket = accept(listener)
                errormonitor(@async handle_connection(server, socket))
            catch
                isopen(listener) || break
            end
        end
    end)
    return server
end

function stop_server(server::FaultServer)
    isopen(server.listener) && close(server.listener)
    wait(server.task)
    return nothing
end

url(server::FaultServer) = "http://127.0.0.1:$(server.port)/data.nc"
get_count(server::FaultServer) = count(startswith("GET "), server.requests)
head_count(server::FaultServer) = count(startswith("HEAD "), server.requests)

function percentile(values::Vector{Float64}, probability::Float64)
    ordered = sort(values)
    position = (length(ordered) - 1) * probability + 1
    lower, upper = floor(Int, position), ceil(Int, position)
    lower == upper && return ordered[lower]
    fraction = position - lower
    return ordered[lower] * (1 - fraction) + ordered[upper] * fraction
end

function bootstrap_ci(values::Vector{Float64}, seed::Int)
    rng = MersenneTwister(seed)
    medians = Float64[]
    for _ in 1:BOOTSTRAP_SAMPLES
        sample = [rand(rng, values) for _ in eachindex(values)]
        push!(medians, median(sample))
    end
    return percentile(medians, 0.025), percentile(medians, 0.975)
end

function csv_field(value)
    text = string(value)
    if occursin(',', text) || occursin('"', text) || occursin('\n', text)
        return "\"$(replace(text, '"' => "\"\""))\""
    end
    return text
end

function write_csv(path::String, rows)
    names = propertynames(first(rows))
    open(path, "w") do io
        println(io, join(string.(names), ','))
        for row in rows
            println(io, join((csv_field(getproperty(row, name)) for name in names), ','))
        end
    end
end

function wrong_same_length(data::Vector{UInt8}, prefix::String)
    output = fill(UInt8('X'), length(data))
    encoded = collect(codeunits(prefix))
    output[1:min(end, length(encoded))] = encoded[1:min(end, length(output))]
    return output
end

function scenario_definition(id::String, data::Vector{UInt8})
    good() = Behavior(body = data)
    bad500() = Behavior(body = collect(codeunits("server-error")), get_status = 500)
    if id == "M01"
        return (good = true, b1 = Behavior(body = data, head_delay = 0.05), b2 = good(), probe = :real, before = :none, cache = false)
    elseif id == "M02"
        return (good = true, b1 = Behavior(body = collect(codeunits("missing")), head_status = 404, get_status = 404), b2 = Behavior(body = data, head_delay = 0.02), probe = :real, before = :none, cache = false)
    elseif id == "M03"
        return (good = true, b1 = Behavior(body = data, head_delay = 0.20), b2 = good(), probe = :short, before = :none, cache = false)
    elseif id == "M04"
        return (good = true, b1 = Behavior(body = data, head_action = :reset, get_action = :reset), b2 = good(), probe = :ordered, before = :none, cache = false)
    elseif id == "M05"
        return (good = true, b1 = good(), b2 = nothing, probe = :real, before = :none, cache = false)
    elseif id == "M06"
        return (good = false, b1 = bad500(), b2 = bad500(), probe = :real, before = :previous, cache = false)
    elseif id == "M07"
        return (good = false, b1 = Behavior(body = UInt8[], head_status = 500, get_status = 500), b2 = Behavior(body = UInt8[], head_status = 500, get_status = 500), probe = :real, before = :previous, cache = false)
    elseif id == "M08"
        return (good = false, b1 = bad500(), b2 = bad500(), probe = :ordered, before = :previous, cache = true)
    elseif id == "M09"
        return (good = true, b1 = good(), b2 = nothing, probe = :ordered, before = :previous, cache = true)
    elseif id == "M10"
        return (good = false, b1 = Behavior(body = wrong_same_length(data, "<html>error</html>")), b2 = nothing, probe = :ordered, before = :previous, cache = false)
    elseif id == "M11"
        return (good = false, b1 = Behavior(body = data, get_action = :truncate, announced_length = length(data)), b2 = nothing, probe = :ordered, before = :previous, cache = false)
    elseif id == "M12"
        return (good = true, b1 = good(), b2 = nothing, probe = :real, before = :valid, cache = false)
    elseif id == "M13"
        return (good = false, b1 = Behavior(body = wrong_same_length(data, "WRONG-SHA")), b2 = nothing, probe = :ordered, before = :previous, cache = false)
    end
    error("Unknown scenario $id")
end

function run_once(id::String, repetition::Int, data::Vector{UInt8})
    definition = scenario_definition(id, data)
    server1 = start_server(definition.b1)
    server2 = isnothing(definition.b2) ? nothing : start_server(definition.b2)
    servers = isnothing(server2) ? [server1] : [server1, server2]
    urls = url.(servers)
    try
        return mktempdir(WORK_ROOT; prefix = "$(id)-$(repetition)-") do home
            CollectorHarness.configure!(home, urls, data)
            destination = CollectorHarness.dataset_path(TAG)
            mkpath(dirname(destination))
            if definition.before == :previous
                write(destination, "previous-formal-file")
            elseif definition.before == :valid
                write(destination, data)
            end
            stable_cache = joinpath(home, "cache", "$TAG.nc")
            definition.cache && write(stable_cache, "stale-cache")
            before_exists = isfile(destination)
            before_hash = before_exists ? sha256_file(destination) : ""
            stable_before = isfile(stable_cache) ? sha256_file(stable_cache) : ""
            probe = if definition.probe == :real
                CollectorHarness.probe_url
            elseif definition.probe == :short
                address -> CollectorHarness.probe_url(address; timeout = 0.05)
            else
                _ -> 0.0
            end

            started = time_ns()
            result_path = ""
            error_text = ""
            try
                result_path = CollectorHarness.download_dataset!(TAG; probe, require_integrity = true)
            catch exception
                error_text = sprint(showerror, exception)
            end
            elapsed_ms = (time_ns() - started) / 1.0e6
            actual_success = isempty(error_text)
            actual_success == definition.good || error("$id repetition $repetition success mismatch: $error_text")
            after_exists = isfile(destination)
            after_hash = after_exists ? sha256_file(destination) : ""
            part_count = count(endswith(".part"), readdir(joinpath(home, "cache")))
            stable_after = isfile(stable_cache) ? sha256_file(stable_cache) : ""
            get_attempts = String[]
            for (index, server) in enumerate(servers)
                append!(get_attempts, fill("m$index", get_count(server)))
            end
            heads = sum(head_count, servers)

            part_count == 0 || error("$id left $part_count part files")
            if definition.good
                after_hash == sha256_hex(data) || error("$id promoted wrong content")
            else
                before_exists && after_hash == before_hash || error("$id changed previous formal file")
                occursin(TAG, error_text) || error("$id error omitted tag")
                all(address -> occursin(address, error_text), urls) || error("$id error omitted URL")
            end
            definition.cache && stable_after == stable_before || !definition.cache || error("$id changed stable cache")
            id == "M01" && get_attempts == ["m2"] || id != "M01" || error("M01 did not select faster mirror")
            id == "M02" && get_attempts == ["m1", "m2"] || id != "M02" || error("M02 did not fall back after 404")
            id == "M03" && get_attempts == ["m2"] || id != "M03" || error("M03 did not avoid timed-out mirror")
            id == "M04" && get_attempts == ["m1", "m2"] || id != "M04" || error("M04 did not fall back after reset")
            id == "M05" && get_attempts == ["m1"] || id != "M05" || error("M05 HTTP endpoint was misclassified")
            id == "M07" && get_attempts == ["m1", "m2"] || id != "M07" || error("M07 did not try all URLs after failed probes")
            id == "M12" && isempty(get_attempts) && heads == 0 || id != "M12" || error("M12 performed network I/O for valid formal file")

            return (
                scenario = id,
                repetition,
                expected_success = definition.good,
                actual_success,
                elapsed_ms,
                head_requests = heads,
                get_attempts = join(get_attempts, '>'),
                fallback_count = max(0, length(get_attempts) - 1),
                before_exists,
                after_exists,
                formal_unchanged = before_exists ? before_hash == after_hash : false,
                output_sha256_ok = after_hash == sha256_hex(data),
                stable_cache_preserved = definition.cache ? stable_after == stable_before : true,
                part_files_after = part_count,
                error_has_tag = isempty(error_text) ? true : occursin(TAG, error_text),
                error_has_all_urls = isempty(error_text) ? true : all(address -> occursin(address, error_text), urls),
                result_path,
                error = replace(error_text, '\n' => " | "),
            )
        end
    finally
        foreach(stop_server, reverse(servers))
    end
end

function main()
    data = read(SOURCE_DATA)
    rows = NamedTuple[]
    for id in ["M$(lpad(index, 2, '0'))" for index in 1:13]
        for repetition in 1:REPETITIONS
            push!(rows, run_once(id, repetition, data))
        end
        println("$id passed $REPETITIONS/$REPETITIONS")
    end
    write_csv(joinpath(ROOT, "fault_matrix_windows_raw.csv"), rows)

    summaries = NamedTuple[]
    for (index, id) in enumerate(["M$(lpad(value, 2, '0'))" for value in 1:13])
        selected = filter(row -> row.scenario == id, rows)
        values = Float64[row.elapsed_ms for row in selected]
        ci_low, ci_high = bootstrap_ci(values, SEED + index)
        push!(summaries, (
            scenario = id,
            repetitions = length(selected),
            passed = count(row -> row.actual_success == row.expected_success && row.part_files_after == 0, selected),
            median_ms = median(values),
            q1_ms = percentile(values, 0.25),
            q3_ms = percentile(values, 0.75),
            ci95_low_ms = ci_low,
            ci95_high_ms = ci_high,
        ))
    end
    write_csv(joinpath(ROOT, "fault_matrix_windows_summary.csv"), summaries)
    metadata = Dict(
        "created_utc" => string(now(UTC)),
        "status" => "Windows source-level controlled HTTP experiment",
        "platform" => Sys.MACHINE,
        "julia_version" => string(VERSION),
        "collector_source" => DOWNLOAD_SOURCE,
        "collector_source_sha256" => sha256_file(DOWNLOAD_SOURCE),
        "fixture" => SOURCE_DATA,
        "fixture_bytes" => length(data),
        "fixture_sha256" => sha256_hex(data),
        "repetitions_per_scenario" => REPETITIONS,
        "bootstrap_samples" => BOOTSTRAP_SAMPLES,
        "network_scope" => "127.0.0.1 only",
        "limitation" => "dataset-download.jl loaded through a minimal harness; after missing dependency sources were restored, full package precompilation still did not finish within a five-minute verification window",
    )
    open(joinpath(ROOT, "fault_matrix_windows_metadata.toml"), "w") do io
        TOML.print(io, metadata; sorted = true)
    end
    println("All $(length(rows)) measured runs passed state assertions")
end

main()
