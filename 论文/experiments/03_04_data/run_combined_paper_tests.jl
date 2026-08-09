const WORKSPACE = dirname(dirname(dirname(dirname(@__DIR__))))
const GM_REPO = joinpath(WORKSPACE, "GriddingMachine_paper")
const GMD_REPO = joinpath(WORKSPACE, "GriddingMachineDatasets_paper")

@assert Base.active_project() == joinpath(GM_REPO, "Project.toml")
# Load the local paper branch without importing its exported names into Main.
# The GMD unit tests include ConfigSchema directly and use its exports; a plain
# `using GriddingMachine` here would make identically named bindings ambiguous.
import GriddingMachine
pushfirst!(LOAD_PATH, GMD_REPO)
import GriddingMachineDatasets
include(joinpath(GMD_REPO, "test", "runtests.jl"))
