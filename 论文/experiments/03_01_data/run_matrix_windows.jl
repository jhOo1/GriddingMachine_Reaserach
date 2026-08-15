using Dates
using SHA
using YAML
using NetcdfIO

const WORKSPACE = dirname(dirname(dirname(dirname(@__DIR__))))
const GM_REPO = joinpath(WORKSPACE, "GriddingMachine_paper")
const GMD_REPO = joinpath(WORKSPACE, "GriddingMachineDatasets_paper")
@assert Base.active_project() == joinpath(GM_REPO, "Project.toml")
import GriddingMachine
pushfirst!(LOAD_PATH, GMD_REPO)
import GriddingMachineDatasets
include(joinpath(GMD_REPO, "src", "build-yaml", "YamlBuilder.jl"))
import .YamlBuilder

const ROOT = @__DIR__
const RESEARCH_ROOT = dirname(dirname(dirname(ROOT)))
const WORK = joinpath(RESEARCH_ROOT, "experiment_data", "03_01", "work")
isdir(WORK) && rm(WORK; recursive = true)
mkpath(WORK)
const RESULTS = NamedTuple[]

check(value, message) = value ? nothing : error(message)

function run_case(f, id, category, expectation)
    started = time_ns()
    status, detail = "PASS", ""
    try
        f()
    catch error_value
        status = "FAIL"
        detail = sprint(showerror, error_value)
    end
    push!(RESULTS, (id=id, category=category, status=status,
        elapsed_ms=(time_ns()-started)/1e6, expectation=expectation,
        detail=replace(detail, '\n' => ' ')))
end

function manual_case(id, expectation)
    push!(RESULTS, (id=id, category="manual", status="MANUAL", elapsed_ms=0.0,
        expectation=expectation, detail="requires two recorded human reviewers"))
end

function section(varname, dims; gapfill="KEEP_AS_IS", options...)
    result = Dict{String,Any}(
        "ABOUT"=>"matrix fixture", "CHANGE_LOGS"=>String[],
        "DIMENSIONS"=>Dict(varname=>collect(dims)), "GAPFILL"=>gapfill,
        "LABEL"=>[varname], "UNIT"=>"1", "VERIFY_ONCE"=>false,
    )
    for (key, value) in options
        result[uppercase(String(key))] = value
    end
    result
end

function read_fixture(name, source, dims; options...)
    path = joinpath(WORK, name * ".nc")
    NetcdfIO.save_nc!(path, "v", source, Dict{String,Any}("about"=>"fixture"))
    GriddingMachineDatasets.read_input(path, "v", section("v", dims; options...))
end

function expect_error(f, pattern)
    caught = nothing
    try f() catch error_value; caught = error_value end
    check(!isnothing(caught), "expected an exception")
    check(occursin(lowercase(pattern), lowercase(sprint(showerror, caught))),
        "exception did not contain '$pattern': $(sprint(showerror, caught))")
end

function base_config(; prefix="SRC", label="v", tag="MATRIX", with_std=false)
    data = section(label, ["lat", "lon"])
    config = Dict{String,Any}(
        "SCHEMA_VERSION"=>1,
        "FILE"=>Dict("PATTERN"=>"PREFIX_NX_MT_VV.nc", "PREFIX"=>[prefix],
            "NX"=>[2], "MT"=>["1Y"], "VV"=>["V1"]),
        "FOLDER"=>Dict("ORIGINAL"=>"input", "REPROCESSED"=>"output"),
        "DATA"=>data, "GRIDDINGMACHINE"=>Dict("TAG"=>tag),
    )
    with_std && (config["STD"] = section("s", ["lat", "lon"]))
    config
end

source2 = reshape(Float32.(1:12), 3, 4)
source3 = reshape(Float32.(1:24), 2, 3, 4)

run_case("D01", "dimension", "2D canonical unchanged") do
    out=read_fixture("D01", source2, ["lon","lat"]); check(out==source2,"value mismatch")
end
run_case("D02", "dimension", "3D canonical unchanged") do
    out=read_fixture("D02", source3, ["lon","lat","ind"]); check(out==source3,"value mismatch")
end
run_case("D03", "dimension", "2D reordered") do
    out=read_fixture("D03", source2, ["lat","lon"]); check(out==permutedims(source2,(2,1)),"reorder mismatch")
end
run_case("D04", "dimension", "3D reordered") do
    out=read_fixture("D04", source3, ["ind","lat","lon"]); check(out==permutedims(source3,(3,2,1)),"reorder mismatch")
end
run_case("D05", "rejection", "unsupported dimensions rejected") do
    expect_error(() -> GriddingMachineDatasets.standardize_dimension_order(zeros(2,2,2,2),"v",Dict()), "only two- and three")
    expect_error(() -> GriddingMachineDatasets.validate_config(base_config() |> c -> (c["DATA"]["DIMENSIONS"]["v"]=["x","y"]; c)), "permutation")
end

run_case("C01", "coordinate", "latitude reversal") do
    out=read_fixture("C01",source2,["lon","lat"];rev_lat=true); check(out==source2[:,end:-1:1],"REV_LAT mismatch")
end
run_case("C02", "coordinate", "longitude reversal") do
    out=read_fixture("C02",source2,["lon","lat"];rev_lon=true); check(out==source2[end:-1:1,:],"REV_LON mismatch")
end
run_case("C03", "coordinate", "0-360 longitude shift") do
    out=read_fixture("C03",source2,["lon","lat"];flip_lon=true); check(out==vcat(source2[2:3,:],source2[1:1,:]),"FLIP_LON mismatch")
end
run_case("C04", "coordinate", "combined transform order") do
    x=reshape(Float32.(1:16),4,4); out=read_fixture("C04",x,["lon","lat"];rev_lat=true,flip_lon=true)
    check(out==vcat(x[3:4,end:-1:1],x[1:2,end:-1:1]),"combined mismatch")
end

run_case("N01", "numeric", "Float32 output") do
    x=Float64[0.1 1/3; pi 1e-7]; out=read_fixture("N01",x,["lon","lat"])
    check(eltype(out)==Float32,"not Float32"); check(maximum(abs.(Float64.(out).-x))<2e-7,"tolerance exceeded")
end
run_case("N02", "numeric", "linear scaling") do
    out=read_fixture("N02",source2,["lon","lat"];scaling="linear",scaling_factor=[2,1]); check(out==source2.*2 .+1,"scaling mismatch")
end
run_case("N03", "numeric", "limits retain boundaries") do
    x=Float32[0 1;2 3]; out=read_fixture("N03",x,["lon","lat"];limits=[1,2]); check(isequal(out,Float32[NaN 1;2 NaN]),"limits mismatch")
end
run_case("N04", "numeric", "no scaling unchanged") do
    out=read_fixture("N04",source2,["lon","lat"]); check(out==source2,"unexpected change")
end

land=Float32[1 0;1 1]
gapdict()=Dict{String,Any}("CHANGE_LOGS_TO_WRITE"=>String[])
run_case("G01","gapfill","constant 2D land only") do
    x=Float32[NaN NaN;3 4]; n=GriddingMachineDatasets.fill_missing_values!(x,land,GriddingMachineDatasets.FillMethodConstant(7),gapdict())
    check(n==1 && x[1,1]==7 && isnan(x[1,2]),"land/ocean mismatch")
end
run_case("G02","gapfill","constant 3D per layer") do
    x=cat(Float32[NaN 2;3 4],Float32[5 NaN;7 NaN];dims=3); n=GriddingMachineDatasets.fill_missing_values!(x,land,GriddingMachineDatasets.FillMethodConstant(9),gapdict())
    check(n==2 && x[1,1,1]==9 && isnan(x[1,2,2]) && x[2,2,2]==9,"3D mismatch")
end
run_case("G03","gapfill","layer nanmean") do
    x=cat(Float32[NaN 2;4 6],Float32[10 NaN;20 30];dims=3); GriddingMachineDatasets.fill_missing_values!(x,land,GriddingMachineDatasets.FillMethodMean(),gapdict())
    check(x[1,1,1]==4 && isnan(x[1,2,2]),"mean mismatch")
end
run_case("G04","gapfill","keep as is") do
    x=Float32[NaN 2;3 4]; y=copy(x); n=GriddingMachineDatasets.fill_missing_values!(x,land,GriddingMachineDatasets.FillMethodKeepAsIs(),gapdict()); check(n==0&&isequal(x,y),"changed")
end
run_case("G05","gapfill","land NaN diagnostic") do
    d=gapdict(); x=Float32[NaN 2;3 4]; n=GriddingMachineDatasets.fill_missing_values!(x,land,GriddingMachineDatasets.FillMethodNoLandNaN(),d); check(n==-1&&length(d["CHANGE_LOGS_TO_WRITE"])==1,"diagnostic missing")
end
run_case("G06","gapfill","global NaN diagnostic") do
    d=gapdict(); x=Float32[1 NaN;3 4]; n=GriddingMachineDatasets.fill_missing_values!(x,land,GriddingMachineDatasets.FillMethodNoNaN(),d); check(n==-2&&length(d["CHANGE_LOGS_TO_WRITE"])==1,"diagnostic missing")
end
run_case("G07","gapfill","integer conversion") do
    x=Float32[NaN 2.2;3.8 NaN]; n=GriddingMachineDatasets.fill_missing_values!(x,land,GriddingMachineDatasets.FillMethodIntNaNTo1(),gapdict()); check(n==-3&&x==Float32[1 2;4 1],"integer mismatch")
end
run_case("G08","rejection","unknown method named") do
    path=joinpath(WORK,"G08.nc"); NetcdfIO.save_nc!(path,"v",source2,Dict{String,Any}()); expect_error(() -> GriddingMachineDatasets.read_input(path,"v",section("v",["lon","lat"];gapfill="UNKNOWN")),"unsupported gapfill method")
end

function with_pipeline(f; with_std=false, tag="MATRIX")
    directory=mktempdir(WORK); old=GriddingMachineDatasets.GRIDDING_MACHINE_HOME
    try
        GriddingMachineDatasets.GRIDDING_MACHINE_HOME=directory; config=base_config(;with_std,tag)
        input=joinpath(directory,"original","input"); mkpath(input)
        NetcdfIO.save_nc!(joinpath(input,"SRC_2X_1Y_V1.nc"),"v",source2,Dict{String,Any}())
        with_std && NetcdfIO.append_nc!(joinpath(input,"SRC_2X_1Y_V1.nc"),"s",source2.+1,Dict{String,Any}(),["lon","lat"])
        f(config,directory)
    finally
        GriddingMachineDatasets.GRIDDING_MACHINE_HOME=old
    end
end

run_case("Y01","yaml","minimal YAML drives pipeline") do
    with_pipeline() do c,d; y=joinpath(d,"c.yaml"); YAML.write_file(y,c); GriddingMachineDatasets.process_dataset!(y;verifier=(x,s)->true); check(length(filter(endswith(".nc"),readdir(joinpath(d,"reprocessed","output"))))==1,"output missing") end
end
run_case("Y02","rejection","missing GAPFILL rejected before IO") do
    c=base_config(); delete!(c["DATA"],"GAPFILL"); expect_error(() -> GriddingMachineDatasets.validate_config(c),"GAPFILL is required")
end
run_case("Y03","yaml","builder output validates") do
    p=Dict(:PATTERN=>"PREFIX_NX_MT_VV.nc",:PREFIX=>["SRC"],:NX=>[2],:MT=>["1Y"],:VV=>["V1"],:YYYY=>Int[],:ORIGINAL=>"input",:REPROCESSED=>"output",:ABOUT=>"fixture",:CHANGE_LOGS=>String[],:LABEL=>["v"],:LIMITS=>[-1,99],:DIMENSIONS=>["lat","lon"],:GAPFILL=>"KEEP_AS_IS",:REV_LAT=>false,:REV_LON=>false,:FLIP_LON=>false,:SCALING=>"",:SCALING_FACTOR=>Float64[],:UNIT=>"1",:VERIFY_ONCE=>false,:TAG=>"MATRIX",:REVISION=>"")
    c=YamlBuilder.build_config(p); check(!haskey(c["FOLDER"],"TARBALL"),"legacy field"); check(GriddingMachineDatasets.validate_config(c)===c,"invalid")
end
run_case("Y04","rejection","LABEL cardinality rejected") do
    c=base_config(); c["FILE"]["PREFIX"]=["A","B"]; expect_error(() -> GriddingMachineDatasets.validate_config(c),"one entry for every")
end
run_case("O01","output","main data structure and values") do
    with_pipeline() do c,d
        GriddingMachineDatasets.process_dataset!(c;verifier=(x,s)->true)
        p=joinpath(d,"reprocessed","output","MATRIX_SRC_2X_1Y_V1.nc")
        check("data" in String.(NetcdfIO.read_varnames(p)),"2D variable missing")
        attrs=NetcdfIO.read_attributes(p,"data")
        check(attrs["about"]=="matrix fixture"&&attrs["unit"]=="1"&&haskey(attrs,"change_1"),"2D attributes mismatch")
        check(NetcdfIO.read_nc(Float32,p,"data")==permutedims(source2,(2,1)),"2D output mismatch")
        c3=base_config(); c3["DATA"]=section("v",["lon","lat","ind"]); c3["DATA"]["CHANGE_LOGS_TO_WRITE"]=String[]
        p3=joinpath(d,"cube.nc"); GriddingMachineDatasets.save_input!(c3,source3,p3)
        check(Set(String.(NetcdfIO.read_dimnames(p3)))==Set(["lon","lat","ind"]),"3D dimensions mismatch")
        check(NetcdfIO.read_nc(Float32,p3,"data")==source3,"3D output mismatch")
    end
end
run_case("O02","output","same-shape std appended") do
    with_pipeline(;with_std=true) do c,d
        GriddingMachineDatasets.process_dataset!(c;verifier=(x,s)->true)
        p=joinpath(d,"reprocessed","output","MATRIX_SRC_2X_1Y_V1.nc")
        vars=Set(String.(NetcdfIO.read_varnames(p))); check("data" in vars&&"std" in vars,"2D std missing")
        check(size(NetcdfIO.read_nc(Float32,p,"data"))==size(NetcdfIO.read_nc(Float32,p,"std")),"2D shape mismatch")
        c3=base_config(;with_std=true); c3["DATA"]=section("v",["lon","lat","ind"]); c3["STD"]=section("s",["lon","lat","ind"])
        c3["DATA"]["CHANGE_LOGS_TO_WRITE"]=String[]; c3["STD"]["CHANGE_LOGS_TO_WRITE"]=String[]
        p3=joinpath(d,"cube-std.nc"); GriddingMachineDatasets.save_input!(c3,source3,p3); GriddingMachineDatasets.save_input!(c3,source3.+1,p3;data_or_std="std")
        check(size(NetcdfIO.read_nc(Float32,p3,"data"))==size(NetcdfIO.read_nc(Float32,p3,"std")),"3D shape mismatch")
    end
end
run_case("O03","output","existing output is safely skipped") do
    with_pipeline() do c,d; calls=Ref(0); v=(x,s)->(calls[]+=1;true); y=joinpath(d,"c.yaml"); YAML.write_file(y,c); GriddingMachineDatasets.process_dataset!(y;verifier=v); p=joinpath(d,"reprocessed","output","MATRIX_SRC_2X_1Y_V1.nc"); h1=bytes2hex(sha256(read(p))); GriddingMachineDatasets.process_dataset!(y;verifier=v); check(calls[]==1&&bytes2hex(sha256(read(p)))==h1,"not safely skipped") end
end
run_case("O04","rejection","catalog tag conflict rejected") do
    c=base_config(;prefix="ELEV",tag="ELEV"); c["FILE"]["NX"]=[4]; expect_error(() -> GriddingMachineDatasets.reprocessed_file(c,"ELEV",4,"1Y","V1",nothing),"already exists")
end
manual_case("V01","two reviewers accept direction plot")
manual_case("V02","two reviewers reject deliberately reversed plot")

run_id=get(ENV,"MATRIX_RUN_ID","")
suffix=isempty(run_id) ? "" : "_run$(run_id)"
platform_slug=lowercase(get(ENV,"MATRIX_PLATFORM",Sys.iswindows() ? "windows" : Sys.isapple() ? "macos" : "linux"))
platform_slug in ("windows","macos","linux") || error("Unsupported MATRIX_PLATFORM=$platform_slug")
csv_path=joinpath(ROOT,"matrix_$(platform_slug)$(suffix)_raw.csv")
open(csv_path,"w") do io
    println(io,"id,category,status,elapsed_ms,expectation,detail")
    esc(x)="\""*replace(string(x),'"'=>"\"\"")*"\""
    for r in RESULTS println(io,join((esc(r.id),esc(r.category),esc(r.status),string(round(r.elapsed_ms;digits=4)),esc(r.expectation),esc(r.detail)),',')) end
end
passed=count(r->r.status=="PASS",RESULTS); failed=count(r->r.status=="FAIL",RESULTS); manual=count(r->r.status=="MANUAL",RESULTS)
summary=Dict("date"=>string(Dates.today()),"run_id"=>run_id,"julia_version"=>string(VERSION),"platform"=>Sys.MACHINE,
    "griddingmachine_commit"=>readchomp(`git -C $GM_REPO rev-parse HEAD`),"griddingmachinedatasets_commit"=>readchomp(`git -C $GMD_REPO rev-parse HEAD`),
    "total_cases"=>length(RESULTS),"automatic_cases"=>passed+failed,"passed"=>passed,"failed"=>failed,"manual_pending"=>manual,"work_root"=>WORK,"network_requests"=>0)
open(joinpath(ROOT,"matrix_$(platform_slug)$(suffix)_summary.toml"),"w") do io
    for key in sort(collect(keys(summary))) println(io,key," = ",repr(summary[key])) end
end
println("Matrix: $passed passed, $failed failed, $manual manual of $(length(RESULTS)) cases")
failed==0 || error("$failed automatic matrix cases failed; see $csv_path")
