using TOML

const WORKSPACE = dirname(dirname(dirname(dirname(@__DIR__))))
const RESEARCH = joinpath(WORKSPACE, "GriddingMachine_Reaserach")
const GM_REPO = joinpath(WORKSPACE, "GriddingMachine_paper")
const GMD_REPO = joinpath(WORKSPACE, "GriddingMachineDatasets_paper")
const PYTHON_PACKAGES = joinpath(dirname(@__DIR__), "03_02_data", "python_env")
const VERIFIED_PYTHON = raw"D:\develop\Python\Python311\python.exe"
const PYTHON_OVERRIDE = get(ENV, "GMD_AUDIT_PYTHON", "")
const PYTHON = !isempty(PYTHON_OVERRIDE) ? PYTHON_OVERRIDE :
    (isfile(VERIFIED_PYTHON) ? VERIFIED_PYTHON : something(Sys.which("python"), ""))
const PLOT_SCRIPT = joinpath(GMD_REPO, "src", "python", "verify-data.py")
const AUDIT_ROOT = joinpath(RESEARCH, "experiment_data", "03_01", "manual_orientation")

@assert Base.active_project() == joinpath(GM_REPO, "Project.toml")
isfile(PYTHON) || error("Python executable not found on PATH")
isdir(PYTHON_PACKAGES) || error("Python packages not found: $PYTHON_PACKAGES")
ENV["GMD_PYTHON_PACKAGES"] = PYTHON_PACKAGES
const PYTHON_CHECK = "import matplotlib,sys,os; " *
    "sys.path.append(os.environ['GMD_PYTHON_PACKAGES']); import netCDF4"
success(pipeline(`$PYTHON -c $PYTHON_CHECK`; stdout=devnull, stderr=devnull)) ||
    error("Python dependencies are incompatible. Set GMD_AUDIT_PYTHON to a working Python executable. Selected: $PYTHON")
import GriddingMachine
pushfirst!(LOAD_PATH, GMD_REPO)
import GriddingMachineDatasets

function fixture()
    data = repeat(reshape(Float32.(range(-80, 80; length=180)), 1, 180), 360, 1)
    data[20:55, 135:170] .= 100   # north-west: brightest
    data[300:330, 140:165] .= 60  # north-east: light
    data[25:65, 15:45] .= -100    # south-west: darkest
    data[285:325, 20:50] .= -60   # south-east: dark
    return data
end

function audit_one(data, folder, expected_accept)
    mkpath(folder)
    section = Dict{String,Any}("ABOUT"=>"orientation audit fixture",
        "CHANGE_LOGS"=>String[], "GAPFILL"=>"KEEP_AS_IS", "LABEL"=>["test"],
        "LIMITS"=>[-100,100], "UNIT"=>"1", "VERIFY_ONCE"=>false)
    cache = joinpath(folder, "fixture.nc")
    image_path = joinpath(folder, "orientation.png")
    println("\nImage will be written to: $image_path")
    println(expected_accept ?
        "Expected: north is at the top; enter y only if the image matches the checklist." :
        "Expected: this image is deliberately north-south reversed; enter n to reject it.")
    observed = GriddingMachineDatasets.verify_data!(data, section;
        cache_data_path=cache, python=PYTHON, script=PLOT_SCRIPT)
    return observed, observed == expected_accept
end

function main()
    print("Reviewer identifier (for example HJ or reviewer02) > ")
    reviewer = strip(readline())
    occursin(r"^[A-Za-z0-9_-]{1,32}$", reviewer) ||
        error("Reviewer identifier may contain only letters, numbers, _ and -")
    folder = joinpath(AUDIT_ROOT, reviewer)
    isdir(folder) && error("Audit folder already exists; choose a new reviewer identifier: $folder")
    correct = fixture()
    v01_observed, v01_passed = audit_one(correct, joinpath(folder,"V01"), true)
    v02_observed, v02_passed = audit_one(correct[:,end:-1:1], joinpath(folder,"V02"), false)
    record = Dict{String,Any}(
        "reviewer"=>reviewer, "timestamp"=>string(Dates.now()),
        "v01_observed_accept"=>v01_observed, "v01_passed"=>v01_passed,
        "v02_observed_accept"=>v02_observed, "v02_passed"=>v02_passed,
        "overall_passed"=>v01_passed&&v02_passed,
        "griddingmachinedatasets_commit"=>readchomp(`git -C $GMD_REPO rev-parse HEAD`),
    )
    open(joinpath(folder,"audit_record.toml"),"w") do io
        TOML.print(io,record;sorted=true)
    end
    audit_label = record["overall_passed"] ? "PASS" : "FAIL"
    record_path = joinpath(folder, "audit_record.toml")
    println("\nAudit result: $audit_label")
    println("Record: $record_path")
end

using Dates
main()
