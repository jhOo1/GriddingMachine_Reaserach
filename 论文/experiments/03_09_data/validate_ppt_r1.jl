using NetcdfIO
using SHA

const EXPECTED_BYTES = 1_102_213_097
const EXPECTED_SHA256 = "1ae6b80512fac97e6b3e609c02ea126858256cf9153ead1335b5bf8d59fe7725"
const EXPECTED_DIMENSIONS = ["lon", "lat", "ind"]
const EXPECTED_SHAPE = (360, 180, 8_784)
const SITE_LATITUDE = 40.0329
const SITE_LONGITUDE = -105.5464
const EXPECTED_GRID_LATITUDE = 40.5
const EXPECTED_GRID_LONGITUDE = -105.5

file_sha256(path) = open(path, "r") do io
    bytes2hex(sha256(io))
end

function inspect_r1(path)
    isfile(path) || error("Missing R1 file: $path")
    filesize(path) == EXPECTED_BYTES || error("Unexpected file size: $(filesize(path))")
    digest = file_sha256(path)
    digest == EXPECTED_SHA256 || error("Unexpected SHA-256: $digest")
    attributes = NetcdfIO.read_attributes(path, "data")
    units = string(get(attributes, "units", ""))
    units == "m" || error("Expected data.units=m, found $units")
    dimensions = collect(String.(NetcdfIO.read_dimnames(path)))
    dimensions == EXPECTED_DIMENSIONS || error("Unexpected dimensions: $dimensions")
    _, shape = NetcdfIO.read_dims(path, "data")
    shape == EXPECTED_SHAPE || error("Unexpected shape: $shape")
    lons = Float64.(NetcdfIO.read_nc(path, "lon"))
    lats = Float64.(NetcdfIO.read_nc(path, "lat"))
    ilon = argmin(abs.(lons .- SITE_LONGITUDE))
    ilat = argmin(abs.(lats .- SITE_LATITUDE))
    lons[ilon] == EXPECTED_GRID_LONGITUDE || error("Unexpected mapped longitude")
    lats[ilat] == EXPECTED_GRID_LATITUDE || error("Unexpected mapped latitude")
    values = vec(NetcdfIO.read_nc(Float32, path, "data", ilon, ilat))
    length(values) == EXPECTED_SHAPE[3] || error("Unexpected site-series length")
    all(isfinite, values) || error("PPT site series contains non-finite values")
    return (; digest, units, dimensions, shape, lons, lats, values)
end

function main()
    length(ARGS) == 2 || error("Usage: validate_ppt_r1.jl REFERENCE_R1 CANDIDATE_R1")
    reference = inspect_r1(abspath(ARGS[1]))
    candidate = inspect_r1(abspath(ARGS[2]))
    reference.lons == candidate.lons || error("Longitude coordinates differ")
    reference.lats == candidate.lats || error("Latitude coordinates differ")
    reinterpret(UInt32, reference.values) == reinterpret(UInt32, candidate.values) ||
        error("US-NR1 Float32 values differ bit for bit")
    annual_total_m = sum(Float64.(candidate.values))
    annual_total_mm = annual_total_m * 1_000
    println("bytes=", EXPECTED_BYTES)
    println("sha256=", candidate.digest)
    println("units=", candidate.units)
    println("dimensions=", join(candidate.dimensions, ","))
    println("shape=", join(candidate.shape, "x"))
    println("site_value_count=", length(candidate.values))
    println("float32_values_bitwise_equal=true")
    println("annual_total_m=", annual_total_m)
    println("annual_total_mm=", annual_total_mm)
    println("PPT R1 validation PASS")
end

main()
