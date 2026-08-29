using NetcdfIO
using SHA

const EXPECTED_ORIGINAL_BYTES = 1_102_213_097
const EXPECTED_ORIGINAL_SHA256 = "3a4f28ca035fabff26a424979c2e12ebfaea0bde7062f7c9fa4c949c6a757195"
const EXPECTED_SHAPE = (360, 180, 8_784)
const EXPECTED_DIMENSIONS = ["lon", "lat", "ind"]
const SITE_LATITUDE = 40.0329
const SITE_LONGITUDE = -105.5464
const EXPECTED_GRID_LATITUDE = 40.5
const EXPECTED_GRID_LONGITUDE = -105.5

file_sha256(path) = open(path, "r") do io
    bytes2hex(sha256(io))
end

function inspect_file(path)
    isfile(path) || error("NetCDF file does not exist: $path")
    attributes = NetcdfIO.read_attributes(path, "data")
    units = string(get(attributes, "units", ""))
    _, shape = NetcdfIO.read_dims(path, "data")
    dimensions = collect(String.(NetcdfIO.read_dimnames(path)))
    lons = Float64.(NetcdfIO.read_nc(path, "lon"))
    lats = Float64.(NetcdfIO.read_nc(path, "lat"))
    dimensions == EXPECTED_DIMENSIONS ||
        error("Unexpected dimensions in $path: $dimensions")
    shape == EXPECTED_SHAPE || error("Unexpected data shape in $path: $shape")
    return (; units, shape, dimensions, lons, lats)
end

function site_values(path, ilon, ilat)
    values = vec(NetcdfIO.read_nc(Float32, path, "data", ilon, ilat))
    length(values) == EXPECTED_SHAPE[3] ||
        error("Unexpected site-series length in $path: $(length(values))")
    return values
end

function set_ppt_units_to_m!(path, current_units)
    if current_units == "m"
        println("PPT units already equal m; metadata update is idempotent")
        return
    end
    current_units == "mm" ||
        error("Refusing to modify unexpected PPT units: $current_units")

    dataset = NetcdfIO.NCDataset(path, "a")
    try
        data_variable = NetcdfIO.variable(dataset, "data")
        string(NetcdfIO.attrib(data_variable, "units")) == "mm" ||
            error("PPT units changed between inspection and update")
        data_variable.attrib["units"] = "m"
    finally
        close(dataset)
    end
    println("Changed only data.units from mm to m")
end

function main()
    length(ARGS) == 2 || error("Usage: repair_ppt_units.jl TARGET_NC BACKUP_NC")
    target = abspath(ARGS[1])
    backup = abspath(ARGS[2])
    target == backup && error("Target and backup paths must differ")

    filesize(backup) == EXPECTED_ORIGINAL_BYTES ||
        error("Unexpected backup size: $(filesize(backup))")
    backup_sha256 = file_sha256(backup)
    backup_sha256 == EXPECTED_ORIGINAL_SHA256 ||
        error("Unexpected backup SHA-256: $backup_sha256")

    backup_info = inspect_file(backup)
    target_info_before = inspect_file(target)
    println("units_before=", target_info_before.units)
    backup_info.units == "mm" || error("Backup units must be mm")
    target_info_before.units in ("mm", "m") ||
        error("Target units must be mm or m")
    if target_info_before.units == "mm"
        filesize(target) == EXPECTED_ORIGINAL_BYTES ||
            error("Unexpected original target size: $(filesize(target))")
        file_sha256(target) == EXPECTED_ORIGINAL_SHA256 ||
            error("Original target SHA-256 does not match the frozen record")
    end
    backup_info.lons == target_info_before.lons ||
        error("Longitude coordinates differ before metadata update")
    backup_info.lats == target_info_before.lats ||
        error("Latitude coordinates differ before metadata update")

    ilon = argmin(abs.(backup_info.lons .- SITE_LONGITUDE))
    ilat = argmin(abs.(backup_info.lats .- SITE_LATITUDE))
    backup_info.lons[ilon] == EXPECTED_GRID_LONGITUDE ||
        error("Unexpected mapped longitude: $(backup_info.lons[ilon])")
    backup_info.lats[ilat] == EXPECTED_GRID_LATITUDE ||
        error("Unexpected mapped latitude: $(backup_info.lats[ilat])")
    backup_values = site_values(backup, ilon, ilat)

    set_ppt_units_to_m!(target, target_info_before.units)

    target_info_after = inspect_file(target)
    println("units_after=", target_info_after.units)
    target_info_after.units == "m" || error("PPT units update did not persist")
    target_info_after.shape == backup_info.shape || error("Data shape changed")
    target_info_after.dimensions == backup_info.dimensions ||
        error("Dimension order changed")
    target_info_after.lons == backup_info.lons || error("Longitude coordinates changed")
    target_info_after.lats == backup_info.lats || error("Latitude coordinates changed")

    target_values = site_values(target, ilon, ilat)
    isfinite.(target_values) == isfinite.(backup_values) ||
        error("Finite-value masks differ")
    reinterpret(UInt32, target_values) == reinterpret(UInt32, backup_values) ||
        error("Float32 site values differ bit for bit")

    annual_total_m = sum(Float64.(target_values))
    annual_total_mm = annual_total_m * 1_000
    println("site_grid=", target_info_after.lats[ilat], ",", target_info_after.lons[ilon])
    println("site_value_count=", length(target_values))
    println("finite_mask_equal=true")
    println("float32_values_bitwise_equal=true")
    println("annual_total_m=", annual_total_m)
    println("annual_total_mm=", annual_total_mm)
    println("bytes_after=", filesize(target))
    println("sha256_after=", file_sha256(target))
    println("PPT metadata repair PASS")
end

main()
