using Dates
using SHA
using TOML
using YAML

const RESEARCH_ROOT = dirname(dirname(dirname(@__DIR__)))
const WORKSPACE_ROOT = dirname(RESEARCH_ROOT)
const DEFAULT_CATALOG = joinpath(WORKSPACE_ROOT, "GriddingMachineDatasets", "Artifacts.yaml")
const DEFAULT_OUTPUT = joinpath(RESEARCH_ROOT, "experiment_data", "03_07", "catalog_audit")

catalog_path = length(ARGS) >= 1 ? abspath(ARGS[1]) : DEFAULT_CATALOG
output_dir = length(ARGS) >= 2 ? abspath(ARGS[2]) : DEFAULT_OUTPUT
mkpath(output_dir)

catalog = YAML.load_file(catalog_path)
entries = sort!(collect(catalog); by = pair -> string(first(pair)))

present(entry, key) = haskey(entry, key) && entry[key] !== nothing && !isempty(string(entry[key]))
urls(entry) = get(entry, "URL", Any[])

function url_host(url)
    matched = match(r"^[A-Za-z][A-Za-z0-9+.-]*://([^/]+)", string(url))
    return matched === nothing ? "unparsed" : lowercase(matched.captures[1])
end

function csv_field(value)
    value_string = replace(string(value), '"' => "\"\"")
    return "\"$(value_string)\""
end

total = length(entries)
with_path = count(pair -> present(last(pair), "PATH"), entries)
with_url = count(pair -> !isempty(urls(last(pair))), entries)
with_size = count(pair -> present(last(pair), "SIZE"), entries)
with_sha256 = count(pair -> present(last(pair), "SHA256"), entries)
with_integrity = count(pair -> present(last(pair), "SIZE") && present(last(pair), "SHA256"), entries)
with_multiple_urls = count(pair -> length(urls(last(pair))) > 1, entries)

host_counts = Dict{String, Int}()
path_counts = Dict{String, Int}()
for (_, entry) in entries
    for url in urls(entry)
        host = url_host(url)
        host_counts[host] = get(host_counts, host, 0) + 1
    end
    path = string(get(entry, "PATH", "<missing>"))
    path_counts[path] = get(path_counts, path, 0) + 1
end

catalog_sha256 = bytes2hex(open(SHA.sha256, catalog_path))
summary = Dict(
    "audit" => Dict(
        "catalog_path" => replace(relpath(catalog_path, WORKSPACE_ROOT), '\\' => '/'),
        "catalog_sha256" => catalog_sha256,
        "audit_script" => replace(relpath(@__FILE__, WORKSPACE_ROOT), '\\' => '/'),
        "audit_date" => string(Dates.today()),
        "network_access" => false,
    ),
    "coverage" => Dict(
        "entries_total" => total,
        "entries_with_path" => with_path,
        "entries_with_url" => with_url,
        "entries_with_size" => with_size,
        "entries_with_sha256" => with_sha256,
        "entries_with_size_and_sha256" => with_integrity,
        "entries_with_multiple_urls" => with_multiple_urls,
        "integrity_coverage_percent" => round(100 * with_integrity / total; digits = 3),
        "multiple_url_coverage_percent" => round(100 * with_multiple_urls / total; digits = 3),
    ),
    "url_hosts" => Dict(sort!(collect(host_counts); by = first)),
    "catalog_paths" => Dict(sort!(collect(path_counts); by = first)),
)

open(joinpath(output_dir, "catalog_coverage_summary.toml"), "w") do io
    TOML.print(io, summary; sorted = true)
end

open(joinpath(output_dir, "catalog_entries.csv"), "w") do io
    println(io, "tag,path,url_count,has_size,has_sha256,integrity_ready")
    for (tag, entry) in entries
        has_size = present(entry, "SIZE")
        has_sha = present(entry, "SHA256")
        row = (
            tag,
            get(entry, "PATH", ""),
            length(urls(entry)),
            has_size,
            has_sha,
            has_size && has_sha,
        )
        println(io, join(csv_field.(row), ','))
    end
end

open(joinpath(output_dir, "integrity_ready_tags.txt"), "w") do io
    for (tag, entry) in entries
        present(entry, "SIZE") && present(entry, "SHA256") || continue
        println(io, tag)
    end
end

println("catalog=", catalog_path)
println("entries_total=", total)
println("entries_with_size_and_sha256=", with_integrity)
println("entries_with_multiple_urls=", with_multiple_urls)
println("integrity_coverage_percent=", summary["coverage"]["integrity_coverage_percent"])
println("multiple_url_coverage_percent=", summary["coverage"]["multiple_url_coverage_percent"])
println("output_dir=", output_dir)
