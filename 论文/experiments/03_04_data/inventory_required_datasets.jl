using GriddingMachine
using TOML
using YAML

const ROOT = @__DIR__
const WORKSPACE = dirname(dirname(dirname(dirname(ROOT))))
const CATALOG = get(
    ENV,
    "GRIDDING_MACHINE_DATASET_CATALOG",
    joinpath(WORKSPACE, "GriddingMachineDatasets_paper", "Artifacts.yaml"),
)
const YEAR = 2020

function csv_field(value)
    text = string(value)
    if occursin(',', text) || occursin('"', text) || occursin('\n', text)
        return "\"$(replace(text, '"' => "\"\""))\""
    end
    return text
end

function labels(object, group)
    rows = NamedTuple[]
    for name in propertynames(object)
        startswith(string(name), "tag_") || continue
        push!(rows, (group = group, field = string(name), tag = string(getproperty(object, name))))
    end
    return rows
end

function main()
    isfile(CATALOG) || error("Catalog does not exist: $CATALOG")
    catalog = YAML.load_file(CATALOG)
    requested = vcat(
        labels(GriddingMachine.Indexer.LandDatasetLabels("gm2", YEAR), "gm2"),
        labels(GriddingMachine.Indexer.WeatherDriverLabels("wd1", YEAR), "wd1"),
    )

    rows = NamedTuple[]
    for item in requested
        entry = get(catalog, item.tag, nothing)
        present = !isnothing(entry)
        urls = present ? String.(get(entry, "URL", String[])) : String[]
        size = present ? get(entry, "SIZE", nothing) : nothing
        sha = present ? get(entry, "SHA256", get(entry, "SHA", nothing)) : nothing
        path = present ? get(entry, "PATH", nothing) : nothing
        push!(rows, (
            group = item.group,
            field = item.field,
            tag = item.tag,
            catalog_present = present,
            size_bytes = isnothing(size) ? "" : string(size),
            sha256 = isnothing(sha) ? "" : lowercase(string(sha)),
            path = isnothing(path) ? "" : string(path),
            url_count = length(urls),
            urls = join(urls, " | "),
        ))
    end

    output = joinpath(ROOT, "required_datasets_2020.csv")
    names = propertynames(first(rows))
    open(output, "w") do io
        println(io, join(string.(names), ','))
        for row in rows
            println(io, join((csv_field(getproperty(row, name)) for name in names), ','))
        end
    end

    unique_tags = unique(row.tag for row in rows)
    unique_entries = [get(catalog, tag, nothing) for tag in unique_tags]
    known_sizes = Int[
        Int(entry["SIZE"])
        for entry in unique_entries
        if !isnothing(entry) && haskey(entry, "SIZE") && entry["SIZE"] isa Integer
    ]
    metadata = Dict(
        "catalog" => abspath(CATALOG),
        "catalog_entries" => length(catalog),
        "year" => YEAR,
        "requested_fields" => length(rows),
        "unique_tags" => length(unique_tags),
        "missing_catalog_tags" => count(isnothing, unique_entries),
        "tags_with_size" => length(known_sizes),
        "known_total_bytes" => sum(known_sizes),
        "tags_without_size" => count(entry -> isnothing(entry) || !haskey(entry, "SIZE"), unique_entries),
        "tags_without_sha256" => count(
            entry -> isnothing(entry) || (!haskey(entry, "SHA256") && !haskey(entry, "SHA")),
            unique_entries,
        ),
        "tags_without_url" => count(
            entry -> isnothing(entry) || isempty(get(entry, "URL", String[])),
            unique_entries,
        ),
        "network_requests" => 0,
    )
    open(joinpath(ROOT, "required_datasets_2020_metadata.toml"), "w") do io
        TOML.print(io, metadata; sorted = true)
    end
    println("Wrote $(length(rows)) fields covering $(length(unique_tags)) unique tags")
    println("Known total bytes: $(sum(known_sizes))")
end

main()
