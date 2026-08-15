using Dates
using Downloads
using SHA
using TOML

import GriddingMachine

const ROOT = dirname(dirname(dirname(@__DIR__)))
const OUTPUT_ROOT = joinpath(ROOT, "experiment_data", "03_03", "real_ftp_zenodo")
const RUN_LABEL = get(ENV, "MIRROR_RUN_LABEL", "offcampus")
occursin(r"^[A-Za-z0-9_-]{1,48}$", RUN_LABEL) || error("Invalid MIRROR_RUN_LABEL")
const OUTPUT = joinpath(OUTPUT_ROOT, RUN_LABEL)
const WORK = joinpath(OUTPUT, "work")
const REPETITIONS = parse(Int, get(ENV, "MIRROR_REPETITIONS", "3"))
const FTP_TIMEOUT_SECONDS = parse(Float64, get(ENV, "MIRROR_FTP_TIMEOUT_SECONDS",
    get(ENV, "MIRROR_TIMEOUT_SECONDS", "60")))
const ZENODO_TIMEOUT_SECONDS = parse(Float64, get(ENV, "MIRROR_ZENODO_TIMEOUT_SECONDS",
    get(ENV, "MIRROR_TIMEOUT_SECONDS", "60")))
const REQUIRE_ALL = lowercase(get(ENV, "MIRROR_REQUIRE_ALL", "true")) in ("true", "1", "yes")

const CANDIDATES = [
    (tag="SC_2X_1Y_V1", size=90987,
        sha="a752c43b9c383890bb221f428554eec4bba3ae1b1ba3b7165340f8acc61f8d42"),
    (tag="SLA_2X_1Y_V1", size=505273,
        sha="352c864477922925057605b70fc20810b6e738989b5a96e70e4fb8701a0f6179"),
    (tag="ELEV_4X_1Y_V1", size=810299,
        sha="642a485fda9517d267a71a63f8cbbb79b924bb19b2ff18a6471c0305b5be6f0f"),
    (tag="CH_20X_1Y_V1", size=4207244,
        sha="77492a5d621103e895ca940208299bdd5b8bc4f93702f6fb4bdbe4476b2745c4"),
]

ftp_url(tag) = "ftp://114.214.212.145/GriddingMachine/public/old-gm1-gm2/$tag.nc"
zenodo_url(tag) = "https://zenodo.org/records/17732092/files/$tag.nc"
sha256_file(path) = open(path) do io
    bytes2hex(SHA.sha256(io))
end

function csv_field(value)
    text = replace(string(value), '"' => "\"\"")
    return "\"" * text * "\""
end

function main()
    Sys.isapple() || error("This experiment variant is fixed to macOS")
    REPETITIONS >= 3 || error("MIRROR_REPETITIONS must be at least 3")
    FTP_TIMEOUT_SECONDS > 0 || error("MIRROR_FTP_TIMEOUT_SECONDS must be positive")
    ZENODO_TIMEOUT_SECONDS > 0 || error("MIRROR_ZENODO_TIMEOUT_SECONDS must be positive")
    mkpath(WORK)
    rows = NamedTuple[]
    orders = NamedTuple[]

    for candidate in CANDIDATES, repetition in 1:REPETITIONS
        urls = [ftp_url(candidate.tag), zenodo_url(candidate.tag)]
        scores = [GriddingMachine.Collector.probe_url(url) for url in urls]
        ordered = GriddingMachine.Collector._ordered_urls(urls,
            url -> scores[findfirst(==(url), urls)])
        push!(orders, (tag=candidate.tag, repetition,
            ftp_ping_ms=scores[1], zenodo_ping_ms=scores[2],
            selected_first=ordered[1]))

        for (mirror, url, ping_ms) in zip(("ftp", "zenodo"), urls, scores)
            timeout_seconds = mirror == "ftp" ? FTP_TIMEOUT_SECONDS : ZENODO_TIMEOUT_SECONDS
            target = joinpath(WORK, "$(candidate.tag)-$(mirror)-$(repetition).nc")
            rm(target; force=true)
            started = time_ns()
            success = false
            error_text = ""
            actual_size = 0
            actual_sha = ""
            try
                println("Downloading $(candidate.tag) from $mirror, repetition $repetition/$REPETITIONS...")
                Downloads.download(url, target; timeout=timeout_seconds)
                actual_size = filesize(target)
                actual_sha = sha256_file(target)
                success = actual_size == candidate.size && actual_sha == candidate.sha
                success || error("SIZE/SHA256 mismatch")
            catch exception
                error_text = sprint(showerror, exception)
            finally
                elapsed_s = (time_ns() - started) / 1.0e9
                push!(rows, (tag=candidate.tag, repetition, mirror, url, ping_ms,
                    timeout_seconds, elapsed_s, success, expected_size=candidate.size, actual_size,
                    expected_sha256=candidate.sha, actual_sha256=actual_sha, error=error_text))
                rm(target; force=true)
            end
        end
    end

    raw_path = joinpath(OUTPUT, "real_ftp_zenodo_raw.csv")
    open(raw_path, "w") do io
        names = propertynames(first(rows))
        println(io, join(string.(names), ','))
        for row in rows
            println(io, join((csv_field(getproperty(row, name)) for name in names), ','))
        end
    end
    order_path = joinpath(OUTPUT, "real_ftp_zenodo_order.csv")
    open(order_path, "w") do io
        names = propertynames(first(orders))
        println(io, join(string.(names), ','))
        for row in orders
            println(io, join((csv_field(getproperty(row, name)) for name in names), ','))
        end
    end
    metadata = Dict(
        "timestamp"=>string(Dates.now()), "operating_system"=>string(Sys.KERNEL),
        "run_label"=>RUN_LABEL, "ftp_timeout_seconds"=>FTP_TIMEOUT_SECONDS,
        "zenodo_timeout_seconds"=>ZENODO_TIMEOUT_SECONDS,
        "require_all_downloads"=>REQUIRE_ALL,
        "julia_version"=>string(VERSION), "repetitions"=>REPETITIONS,
        "griddingmachine_commit"=>readchomp(`git -C $(dirname(Base.active_project())) rev-parse HEAD`),
        "all_downloads_verified"=>all(row.success for row in rows),
        "remote_writes_or_deletes"=>false,
    )
    open(joinpath(OUTPUT, "real_ftp_zenodo_metadata.toml"), "w") do io
        TOML.print(io, metadata; sorted=true)
    end
    rm(WORK; recursive=true, force=true)
    success_count = count(row.success for row in rows)
    if REQUIRE_ALL && !metadata["all_downloads_verified"]
        error("At least one real FTP/Zenodo download failed; inspect $raw_path")
    end
    println("Real FTP/Zenodo observation completed: $success_count/$(length(rows)) downloads verified")
    !REQUIRE_ALL && println("Partial failures were retained because MIRROR_REQUIRE_ALL=false")
end

main()
