# GriddingMachine.jl v0.5.0 — Release Notes 草稿

> 用途：GitHub Release `v0.5.0` 的正文草稿，等作者审核后发布。
> 目标提交：main（`11631d6` 合并 + 1 个 README 修订提交）。
> 状态：**草稿，未发布**。

---

## v0.5.0

This release reorganizes GriddingMachine around three things: maintaining a catalog of gridded
datasets, getting those datasets onto a local machine reliably, and turning them into inputs for
land and Earth system models. It also removes several sub-modules that were either unused or whose
role now belongs to a separate upstream repository.

The package code in this release is identical to the snapshot used for the accompanying manuscript
(tag `griddingmachine-paper-2026-v1`); the only addition on top of it is a documentation update.

### Breaking changes

- `Collector.download_artifact!` is replaced by `Collector.download_dataset!`.
- `Collector.query_collection` is replaced by `Collector.dataset_path` and `Collector.dataset_info`.
- `Requestor.request_site_data` now takes the server URL and user name as its first two arguments:
  `request_site_data(server, user, tag, lat, lon, cycle = 0)`. The `interpolation` keyword is gone.
- `Blender` is removed. Its `regrid` function now lives in `PkgUtility.MathTools`, and
  `GriddingMachine` itself consumes it from there.
- `Fetcher` is removed. Downloading raw, ungridded source data is now the job of
  [GriddingMachineDatasets](https://github.com/jhOo1/GriddingMachineDatasets).
- `Partitioner` and `Processer` are removed. Both were already commented out and were never loaded
  by the package in v0.4, so no working code can depend on them.
- `Indexer` no longer interpolates between grid cells; site reads return the containing grid cell.
- `using GriddingMachine` no longer creates directories under `~/GriddingMachine` and no longer
  downloads the catalog as an import side effect. Call `Collector.initialize_database!()` or
  `Collector.update_database!()` explicitly.
- Minimum supported Julia is now 1.10.

`Indexer.read_LUT` is kept as an alias of `read_dataset` and is covered by tests.

The sources of the removed sub-modules are kept under `deprecated/` for reference; they are not
compiled and are not part of the public API.

### Data distribution and integrity

- Catalog entries carry `SIZE` and `SHA256`. A download is written to a cache file first and is only
  promoted into the public data directory after both the size and the hash match. An interrupted,
  truncated, or corrupted download therefore never replaces a valid file, and no `.part` files are
  left behind.
- Catalog updates are transactional: if the new catalog fails validation, the previous working
  catalog is kept, and the prior version is retained as `Artifacts.previous.yaml`.
- A new catalog schema check (`Collector.validate_catalog`) rejects malformed entries, including
  entries whose `PATH` would escape the data directory, and reports them as `CatalogValidationError`.
- A single dataset tag may list several mirror URLs. Candidates are ordered by a reachability probe
  and tried in turn; a mirror that does not answer the probe is still attempted, because an
  unanswered ICMP probe does not mean the file cannot be downloaded over HTTP(S) or FTP.
- The probe parses both Windows and macOS `ping` output.
- Datasets are distributed as plain `.nc` files, so no outer archive has to be unpacked before use.

### Reading data and preparing model inputs

- `Indexer.read_dataset` is the single entry point for reading. It accepts either a local NetCDF file
  or a catalog tag (downloading it if needed), and supports whole-file, single-cycle, single-grid-cell,
  and grid-cell-plus-cycle reads, with `raw_data` and `read_std` options.
- `Indexer.grid_dict` and `Indexer.grid_weather` assemble the soil, canopy, leaf, topography, land
  mask, plant-functional-type, and meteorological fields that a land model needs for one grid cell,
  returning ordered dictionaries. Non-vegetated grid cells are reported explicitly instead of
  silently producing a dictionary.
- Fixed a bug in the bare-soil branch of `grid_dict` that passed a scalar to `resample`.

### Dependencies and CI

- NetcdfIO 0.3.0 and PkgUtility 0.3.1.
- Continuous integration runs on Ubuntu, macOS, and Windows with a pinned Julia 1.12.6.

### Testing

63 tests, all passing, grouped as: catalog initialization and schema (5), transactional catalog
update (6), mirror fallback, cache isolation and integrity (10), sync/info/tree/cleanup (8),
`read_dataset` (18), and model input dictionaries (15).

---

## 发布前需要作者确认的点

1. Release 标题与 tag 名：建议 tag `v0.5.0`，标题 `v0.5.0`（与既有 23 个 release 的命名一致）。
2. 是否在 release 正文里链接论文（论文尚未投稿/无 DOI，当前草稿只提到了内部 tag 名，未给外部链接）。
3. `Requestor` / `Server` 在 README 中标为 `Experimental`：论文明确把 Server/Requestor 排除在验证范围外，所以这里没有声称它们已验证。若你认为应标注为可用，需要补相应测试。
4. 仓库里有 `TagBot.yml`。TagBot 通常在 Julia General registry 注册成功后自动建 GitHub release。若本包仍在 General registry 中，手工建 release 与 TagBot 可能重复；发布前需确认走哪条路径（见下）。

## 关于 release 与 registry 的关系（需要你决定）

既有 23 个 release + `v0.1.0`～`v0.4.0` 的 tag 序列，符合"在 General registry 注册 → TagBot 自动打 tag 并建 release"的标准流程。你指的"注册新版本"是 GitHub Releases，那么有两种做法：

- **A. 只手工建 GitHub Release**：直接在 `v0.5.0` tag 上建 release。用户 `Pkg.add("GriddingMachine")` 装到的仍是 registry 里的 0.4.0，拿不到 0.5.0。
- **B. 走 registry 注册**：在 main 的目标提交上评论 `@JuliaRegistrator register`，合并 registry PR 后 TagBot 会自动创建 tag 与 release。用户可以 `Pkg.add` 到 0.5.0。**此路径公开且不可撤销。**

需要你明确选 A 还是 B。若选 B，还需先确认破坏性变更清单已经定稿，因为注册后无法回退。
