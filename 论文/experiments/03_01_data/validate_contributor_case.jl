using Dates
using NetcdfIO
using SHA
using TOML

const RESEARCH = dirname(dirname(dirname(@__DIR__)))
const GMD_REPO = joinpath(dirname(RESEARCH), "GriddingMachineDatasets_paper")
const ROOT = joinpath(RESEARCH, "experiment_data", "03_01", "contributor_flow")
length(ARGS) == 1 || error("Usage: validate_contributor_case.jl REVIEWER_ID")
const IDENTIFIER = ARGS[1]
const CASE_ROOT = joinpath(ROOT, IDENTIFIER)
isdir(CASE_ROOT) || error("Case not found: $CASE_ROOT")
ENV["GRIDDING_MACHINE_HOME"] = joinpath(CASE_ROOT, "gm_home")
import GriddingMachine
pushfirst!(LOAD_PATH, GMD_REPO)
println("Loading GriddingMachineDatasets...")
import GriddingMachineDatasets
println("Validating contributor YAML and running the controlled pipeline...")

function sha256_file(path)
    open(path) do io
        bytes2hex(SHA.sha256(io))
    end
end

function main()
    identifier = IDENTIFIER
    case_root = CASE_ROOT
    yaml_file = joinpath(case_root, "contributor.yaml")

    started = Dates.now()
    source = Float32[11 12 13 14; 21 22 23 24]
    expected = permutedims(source, (2,1))[:,end:-1:1]
    expected = vcat(expected[3:4,:], expected[1:2,:]) .* 2 .+ 1
    expected[expected .< 23 .|| expected .> 49] .= NaN
    reviews = Ref(0)
    verifier = (data, section) -> begin
        reviews[] += 1
        isequal(data, expected)
    end
    GriddingMachineDatasets.process_dataset!(yaml_file; verifier)
    println("Pipeline output created; checking data and simulated catalog...")
    output = joinpath(case_root, "gm_home", "reprocessed", "case-output",
        "CONTRIB_SRC_2X_1Y_V1.nc")
    data = NetcdfIO.read_nc(Float32, output, "data")
    isequal(data, expected) || error("Output data do not match the fixed gold standard")
    reviews[] == 1 || error("Unexpected verifier call count: $(reviews[])")

    catalog_file = joinpath(case_root, "Artifacts.simulated.yaml")
    artifacts = Dict("CONTRIB_SRC_2X_1Y_V1"=>Dict(
        "FILE"=>output,
        "URL"=>["https://example.invalid/CONTRIB_SRC_2X_1Y_V1.nc"],
        "PATH"=>"public/simulated",
    ))
    catalog = GriddingMachineDatasets.update_yaml_library!(catalog_file, artifacts)
    entry = catalog["CONTRIB_SRC_2X_1Y_V1"]
    entry["SIZE"] == filesize(output) || error("Catalog SIZE mismatch")
    entry["SHA256"] == sha256_file(output) || error("Catalog SHA256 mismatch")

    result = Dict(
        "participant"=>identifier,
        "started_validation"=>string(started),
        "finished_validation"=>string(Dates.now()),
        "automatic_result"=>"PASS",
        "verifier_calls"=>reviews[],
        "output_file"=>output,
        "output_size"=>filesize(output),
        "output_sha256"=>sha256_file(output),
        "catalog_file"=>catalog_file,
        "catalog_size_correct"=>true,
        "catalog_sha256_correct"=>true,
        "remote_operations"=>false,
        "griddingmachinedatasets_commit"=>readchomp(`git -C $GMD_REPO rev-parse HEAD`),
    )
    open(joinpath(case_root, "automatic_result.toml"), "w") do io
        TOML.print(io, result; sorted=true)
    end
    println("Contributor case PASS: $case_root")
    println("Complete participant_record.toml according to the guide.")
end

main()
