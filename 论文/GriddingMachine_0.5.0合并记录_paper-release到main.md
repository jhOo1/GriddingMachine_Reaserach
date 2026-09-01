# GriddingMachine.jl 0.4.0 → 0.5.0 合并记录（paper-release → main）

- 日期：2026-09-01
- 操作者：姜皓（JhOo1）
- 状态：**已在本地完成合并，尚未推送、尚未注册版本**，等待审核
- 合并前 main：`0cd6cbe`（0.4.0，2025-10-28，PR #88）
- 合并后 main：`11631d6`（0.5.0，2026-08-15），随后叠加 1 个文档修订提交 `f77f61e`
- 合并方式：**fast-forward**（`git merge --ff-only paper-release`）

## 1. 为什么可以快进，为什么选快进

`origin/main` 是 `origin/paper-release` 的祖先（paper-release 领先 41 个提交、落后 0 个），因此合并为纯快进，**零冲突、无任何 main 侧改动被丢弃**。

选择快进而非制造 merge commit 的理由：快进后 main 的 HEAD 与以下三者是**同一个提交对象**，可追溯性最强，注册的版本与论文引用的代码完全一致：

```
main                          = 11631d624f4847c5e34d2c4ff3cd762359a80c05
paper-release                 = 11631d624f4847c5e34d2c4ff3cd762359a80c05
tag griddingmachine-paper-2026-v1 = 11631d624f4847c5e34d2c4ff3cd762359a80c05
```

若改用 `--no-ff`，main 的 HEAD 会是一个新 SHA，与论文已归档引用的 `11631d6` 不一致。

### 合并后的文档修订提交

审阅时发现 README 已严重过时（详见第 3.5 节），因此在合并之后叠加了一个**仅改文档**的提交 `f77f61e`。因此：

- main 当前 HEAD = `f77f61e`，领先 origin/main **42** 个提交；
- `f77f61e` 与 `11631d6` 的**代码完全相同**，差异仅限 `README.md`；
- 论文 tag `griddingmachine-paper-2026-v1` 仍指向 `11631d6`不变，论文引用不受影响；实验结论也不受影响（README 不参与任何代码路径）。

## 2. 分支拓扑（说明这 41 个提交的来源）

```
main 0cd6cbe (0.4.0, 2025-10-28)
 └── 30 个共有提交 ──► 2c02ef4 (2025-12-26)   ← jianghao 与 wyujie 的分叉点
                          ├── +9 ──► jianghao (2026-01-14)   ← 本次不合并
                          └── +5 ──► wyujie   (2026-07-29)
                                       └── +6 ──► paper-release 11631d6 (2026-08-15)
```

本次合并的 41 = 共有 30 + wyujie 段 5 + paper 段 6。`wyujie` 已被 paper-release 完整包含，**合并 paper-release 等于同时合入 wyujie**。`jianghao`（Server/Web 表单与 JSON 路由）是 wyujie 的兄弟分支，不在本次范围内，另行处理。

## 3. 改了什么

总体：**79 文件，+2834 / −1467 行**（`git diff 0cd6cbe 11631d6`）。

### 3.1 破坏性变更（决定版本号语义）

**目录结构由单文件模块改为目录模块**：`src/Collector.jl` → `src/Collector/`，`src/Indexer.jl` → `src/Indexer/`，`src/Requestor.jl` → `src/Requestor/`。

**四个模块从 `src/` 移出到仓库根 `deprecated/`，不再编译、不再作为公开 API**：

| 移除的模块 | 原路径 | 现位置 |
|---|---|---|
| Blender | `src/Blender.jl` | 已删除 |
| Fetcher | `src/Fetcher.jl` + `src/fetcher/*`（carbontracker/gedi/general/modis/password/smap/viirs） | `deprecated/fetcher/` |
| Partitioner | `src/Partitioner.jl` + `src/partitioner/*` | `deprecated/partitioner/` |
| Processer | `src/Processer.jl` + `src/processer/process_json/*` | `deprecated/processer/` |
| 内部工具 | `src/borrowed/*`（EmeraldMath/EmeraldUtility/Terminal）、`src/database/*` | 已删除，改用 PkgUtility |
| 旧 Gridding | `src/deprecated/Gridding/*` | `deprecated/Gridding/` |

合并后主模块仅包含四个子模块：

```julia
module GriddingMachine
    include("Collector/Collector.jl");
    include("Indexer/Indexer.jl");
    include("Requestor/Requestor.jl");
    include("Server/Server.jl");
end
```

因此 0.4.0 → **0.5.0** 是正确的：在 0.x 语义化版本下，破坏性变更通过抬升次版本号表达。

### 3.2 数据获取（Collector）

- **新增 `database-schema.jl`**：目录 schema 校验，非法条目（如 `PATH` 越出数据根）抛 `CatalogValidationError`
- **完整性校验**：目录条目登记 `SIZE` 与 `SHA256`；下载后校验，不匹配则不进入正式目录
- **安全缓存**：先落 `cache/`，校验通过后再原子移入 `public/`；失败不残留 `.part`、不污染上一份正式文件
- **事务式目录更新**：目录更新失败时保留上一有效版本，并保存 `Artifacts.previous.yaml`
- **多镜像回退**：一个标签可登记多个 URL，按探测分数排序后逐个回退；探测分数为 `Inf` 的地址仍进入尝试队列（ICMP 无响应不等于不可下载）
- **跨平台 ping 解析**：支持 Windows 与 macOS 的 ping 输出文本
- 公开导出：`CatalogValidationError, clean_database!, configure!, dataset_cache, dataset_dir, ...`（`database-clean/download/initialize/load/sync/tree/update`、`dataset-download/info`）

### 3.3 数据读取与模型接口（Indexer）

- **`read_dataset` 统一读取接口**（`dataset-read.jl` 净减 206 行），覆盖整场 / 周期切片 / 站点 / 站点周期；`read_LUT` 保留为兼容别名
- **Indexer 不再插值**（`reafactor Indexer (do not interpolate data)`）
- **模型接口自 Emerald 迁入**：新增 `grid-dict.jl`(307行)、`grid-weather.jl`、`emerald-land-datasets.jl`(224行)、`emerald-weather-drivers.jl`、`emerald-clm.jl`、`emerald-co2.jl`
- `grid_dict` / `grid_weather` 改用 `OrderedDict`；加入 FDOY、b6f、jmax25；chl/ci/lai/vcmax 重采样到日尺度；SAI 默认 0
- **修复裸土分支 bug**：原先把标量传给 `resample` 会报错
- 公开导出：`grid_dict, grid_weather, lat_ind, lon_ind, read_dataset, read_LUT`

### 3.4 依赖与工程

- NetcdfIO 升到 **0.3.0**，PkgUtility 固定 **0.3.1**，最低 Julia 1.10
- `Manifest.toml` 保持 gitignore（新机器全新解析）
- **新增三平台 CI**（`.github/workflows/JuliaStable.yml`）：ubuntu-latest / macos-latest / windows-latest，固定 Julia 1.12.6，`Pkg.instantiate()` + `julia-runtest`，Linux 侧上报 codecov

### 3.5 审阅中发现并修正的 README 过时问题（提交 `f77f61e`）

审阅时逐项核对了 README 与实际代码，发现 README 会**直接误导用户**：

| README 原内容 | 实际情况 |
|---|---|
| 示例 `Collector.download_artifact!("VCMAX_2X_1Y_V1")` | 该函数**已移除**，用户抄第一行示例就报错 |
| 示例 `Requestor.request_site_data(tag, lat, lon; interpolation=true)` | 签名已变为 `(server, user, tag, lat, lon, cycle=0)`，`interpolation` 参数已删 |
| API 表格列出 Blender / Fetcher / Partitioner（状态 “Testing”） | 三者均已不在包内；且未列出实际存在的 Server |
| 徽章引用 `Julia-1.7` workflow | 该 workflow 已不存在（仅剩 CompatHelper/Documentation/JuliaStable/TagBot），徽章是坏的 |
| “only supports julia 1.7 and above” | compat 已为 `julia = "1.10"` |

修正内容：重写 API 表格为实际四个子模块（Collector / Indexer 标 v0.5；Requestor / Server 标 **Experimental**，因论文明确将其排除在验证范围外）；修正全部示例并新增 `read_dataset` 示例；新增“Migrating from v0.4 to v0.5”迁移对照表；删除坏徽章；更新最低 Julia 版本。

所有写入 README 的示例均对着源码逐个核实过：`read_dataset` 确实接受 tag（`_dataset_file` 会在需要时自动下载）且四个签名 `(tf)`/`(tf,cyc)`/`(tf,lat,lon)`/`(tf,lat,lon,cyc)` 与示例一致；`initialize_database!` 存在；`GriddingMachine.jl` 与 `Collector.jl` 在模块加载期无 `mkpath` / 无联网，因此“import 不再有副作用”的说法成立。

## 4. 测了什么

### 4.1 本机环境（"新电脑"验证）

| 项 | 值 |
|---|---|
| 机器 | Apple M4（arm64） |
| 系统 | macOS 26.3.2（Build 25D2140） |
| Julia | 1.12.6（与 CI 固定版本一致） |
| 依赖解析 | **删除本地旧 Manifest 后全新解析**，模拟新电脑首次安装 |
| 包服务器 | USTC 镜像（内容寻址 + 哈希校验，不改变包内容） |

全新解析得到的关键依赖（git-tree-sha1）：NetcdfIO 0.3.0 (`0a876b43`)、PkgUtility 0.3.1 (`f77541ed`)、Genie 5.35.15 (`3172f630`)、HTTP 1.11.0 (`51059d23`)、JSON 1.7.1 (`c7345ab1`)、OrderedCollections 1.8.2 (`94ba9377`)、Revise 3.17.0 (`ab0f5630`)、YAML 0.4.16 (`a1c0c758`)。

### 4.2 测试结果

同一套 `Pkg.test()` 在**合并前的 paper-release** 与**合并后的 main** 上各跑一次，结果一致：

| 测试组 | 通过 | 说明 |
|---|---|---|
| Catalog initialization and schema | 5/5 | 目录初始化、schema 校验、非法条目拒绝 |
| Transactional catalog update | 6/6 | 目录事务替换、失败保留上一版本 |
| Mirror fallback, cache isolation, and integrity | 10/10 | 镜像回退、缓存隔离、SIZE/SHA256 校验、Windows/macOS ping 文本解析 |
| Sync, information, tree, and cleanup | 8/8 | 同步、信息查询、目录树、安全清理 |
| Indexer read_dataset | 18/18 | 整场/周期/站点读取、经纬度换算、`read_LUT` 兼容别名 |
| Model input dictionaries | 15/15 | `grid_dict`/`grid_weather` 字段、形状、时间组织、裸土分支 |
| **合计** | **63/63** | paper-release 8.7 s；合并后 main 9.0 s |

原始日志与哈希（已归档至 `论文/experiments/03_10_data/`）：

| 文件 | SHA-256 |
|---|---|
| `gm_fresh_instantiate_macos_0901.log` | `9fb60ec3b3f786babfe33495fec9866f8050eff1360bb142cf53d1c5046af6ed` |
| `gm_test_paperrelease_macos_0901.log` | `b80b12ac6b7a2664a25a64e9f96f1212cf47848ca59f66a605c3eccce131acb7` |
| `gm_test_main_macos_0901.log` | `a5c1c8f7bb59a3c0b082ffe5fb811f33c8d0af6291d2d64d2d436bd6d77e47f3` |
| `gm_manifest_main_macos_0901.toml`（完整依赖锁） | `de7936041c3059ccb923ae63e2e6807044f2040b2b1881509a9d900dfce97fab` |

### 4.3 已有的其他平台证据（来自论文实验，非本次新跑）

三平台 CI 已在公开仓库运行通过（Windows / macOS / Ubuntu，Julia 1.12.6，同为 63/63）。此外论文侧在 Windows 与 macOS 完成了生产矩阵、效率、故障注入与真实网络实验，记录见研究仓库 `论文/experiments/`。

### 4.4 本次未测的边界

- 未在本机跑 Linux/Windows（本机无相应环境）；跨平台依赖公开 CI 结果
- 未跑 `docs/` 构建与 doctest
- 未跑涉及真实远端下载的实验（本次只跑单元测试，测试内均为夹具与本地回环）
- 合并未包含 `jianghao` 分支的 Server/Web 功能，其 `test/runtests.jl` 与新版 Collector 测试不兼容，需单独 rebase 后处理

## 5. 待审核确认项

1. 确认以 **fast-forward** 方式合并（main HEAD 与论文 tag 同一提交），或改用 `--no-ff` 保留合并节点
2. 确认版本号 **0.5.0**（0.4.0 起为破坏性变更，抬升次版本号）
3. 确认将 Blender / Fetcher / Partitioner / Processer 移入 `deprecated/` 作为 0.5.0 的公开 API 范围，README/文档是否需同步说明迁移路径
4. 确认 `jianghao` 分支的处理方式（本次不合并；后续 rebase 到新 Collector 后单独发版）
5. 审核通过后再执行：推送 main → 注册新版本

## 6. 尚未执行的动作

- `git push origin main`（本地 main 领先 origin/main 41 个提交，**未推送**）
- 版本注册（无论是 General registry 还是 GitHub release，**均未执行**）

本地 main 未推送，因此如需回退，`git reset --hard 0cd6cbe` 即可完全恢复。
