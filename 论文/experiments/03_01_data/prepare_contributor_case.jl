using NetcdfIO

const RESEARCH = dirname(dirname(dirname(@__DIR__)))
const ROOT = joinpath(RESEARCH, "experiment_data", "03_01", "contributor_flow")

function main()
    length(ARGS) == 1 || error("Usage: prepare_contributor_case.jl REVIEWER_ID")
    identifier = ARGS[1]
    occursin(r"^[A-Za-z0-9_-]{1,32}$", identifier) || error("Invalid identifier")
    case_root = joinpath(ROOT, identifier)
    isdir(case_root) && error("Case already exists: $case_root")
    original = joinpath(case_root, "gm_home", "original", "case-input")
    mkpath(original)
    source = Float32[11 12 13 14; 21 22 23 24]
    source_file = joinpath(original, "SRC_2X_1Y_V1.nc")
    NetcdfIO.save_nc!(source_file, "source", source,
        Dict{String,Any}("about"=>"controlled contributor fixture; source order is lat,lon"))
    template = """SCHEMA_VERSION: null
FILE:
  PATTERN: null
  PREFIX: []
  NX: []
  MT: []
  VV: []
FOLDER:
  ORIGINAL: null
  REPROCESSED: null
DATA:
  ABOUT: null
  CHANGE_LOGS: []
  DIMENSIONS:
    source: []
  FLIP_LON: null
  GAPFILL: null
  LABEL: []
  LIMITS: []
  REV_LAT: null
  SCALING: null
  SCALING_FACTOR: []
  UNIT: null
  VERIFY_ONCE: null
GRIDDINGMACHINE:
  TAG: null
"""
    write(joinpath(case_root, "contributor.yaml"), template)
    record = """participant = \"$identifier\"
completed_without_help = false
verbal_help_count = 0
failed_attempt_count = 0
failed_step = \"\"
error_summary = \"\"
guide_was_clear = false
notes = \"Not completed\"
"""
    write(joinpath(case_root, "participant_record.toml"), record)
    println("Contributor case created: $case_root")
    println("Edit contributor.yaml by following the frozen guide; do not rename source files.")
    println("After validation, complete participant_record.toml without deleting failed attempts.")
end

main()
