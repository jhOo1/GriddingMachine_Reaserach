using Pkg

length(ARGS) == 6 || error(
    "usage: validate_unified_environment.jl ENV_DIR GRID_MACHINE GRID_DATASETS EMERALD NETCDF_IO PKG_UTILITY",
)

environment, gridding_machine, datasets, emerald, netcdf_io, pkg_utility = abspath.(ARGS)
for repository in (gridding_machine, datasets, emerald, netcdf_io, pkg_utility)
    isfile(joinpath(repository, "Project.toml")) || error("missing Project.toml: $repository")
end

mkpath(environment)
Pkg.activate(environment)
Pkg.develop([
    PackageSpec(path = gridding_machine),
    PackageSpec(path = datasets),
    PackageSpec(path = emerald),
    PackageSpec(path = netcdf_io),
    PackageSpec(path = pkg_utility),
])
# The package test entry points import YAML directly.  Add it explicitly to
# this integration environment because Julia does not expose transitive
# dependencies to test scripts executed outside Pkg.test.
Pkg.add("YAML")
Pkg.resolve()
Pkg.instantiate()

println("Unified integration environment: $environment")
Pkg.status()
