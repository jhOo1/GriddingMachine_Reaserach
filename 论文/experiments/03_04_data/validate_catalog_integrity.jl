using YAML

const ROOT = @__DIR__
const WORKSPACE = dirname(dirname(dirname(dirname(ROOT))))
const CATALOG = joinpath(WORKSPACE, "GriddingMachineDatasets_paper", "Artifacts.yaml")
const METADATA = joinpath(ROOT, "land_files_2020_metadata.csv")

function main()
    catalog = YAML.load_file(CATALOG)
    lines = readlines(METADATA)
    count = 0
    for line in lines[2:end]
        columns = split(line, ',')
        tag = replace(columns[1], '\ufeff' => "")
        expected_size = parse(Int, columns[6])
        expected_sha256 = lowercase(columns[8])
        entry = catalog[tag]
        @assert entry["SIZE"] == expected_size "$tag SIZE mismatch"
        @assert lowercase(entry["SHA256"]) == expected_sha256 "$tag SHA256 mismatch"
        @assert occursin(r"^[0-9a-f]{64}$", expected_sha256) "$tag invalid SHA256"
        count += 1
    end
    @assert count == 14 "Expected 14 land entries, got $count"
    println("Validated $count catalog entries against downloaded content")
end

main()
