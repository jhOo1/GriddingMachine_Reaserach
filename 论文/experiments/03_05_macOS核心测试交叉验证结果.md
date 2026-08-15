# 03_05 macOS 跨平台验证结果（核心回归与全部受控实验）

执行日期：2026-08-15

## 目的

论文实证最初限定为 Windows。本记录在 macOS 上复现两个论文分支的核心自动回归及全部受控实验（生产矩阵、效率、故障注入），并补一轮校外真实网络观察，使论文的跨平台表述均有归档数据支撑；不改变"Linux 无实证、校园网比较待做"的边界。

## 环境

- 机器：Apple M4（arm64），macOS 26.3.2（Build 25D2140）
- Julia：1.12.6（与 Windows 验证基线同版本，juliaup 安装）
- 代码提交：`GriddingMachine.jl paper-release@53bb0be`、`GriddingMachineDatasets paper-release@3926ae3`
- Emerald：`https://github.com/silicormosia/Emerald.jl.git`，分支 `wyujie`，提交 `9828b2acd594145dff2de5714a2793945ec734a5`（2025-12-12），`Project.toml` 版本 1.0.0；仓库无 tag
- 三个仓库工作区在实验前后均为干净状态（临时依赖改动已还原）
- 包下载使用 USTC 镜像 `JULIA_PKG_SERVER=https://mirrors.ustc.edu.cn/julia`（默认 pkg 服务器在本网络下连接停滞）；Pkg 协议为内容寻址并校验哈希，镜像不改变包内容

## 执行方式

1. **GriddingMachine.jl**：`julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'`。依赖从 General 注册表解析，其中 NetcdfIO 0.3.0、PkgUtility 0.3.1。
2. **GriddingMachineDatasets**：与 Windows `run_combined_paper_tests.jl` 等价的直跑方式 `GMD_RUN_INTEGRATION_TESTS=true julia --project=. test/runtests.jl`（`Pkg.test` 沙箱因 Project 未声明 `Test` 依赖而不可用，与 Windows 执行方式一致）。依赖偏离说明见下。
3. **Emerald 最小烟雾**：以 Emerald.jl 自身工程为环境（其 `[deps]` 已含 GriddingMachine 与 Test），`julia --project=Emerald.jl <GriddingMachine.jl>/test/emerald-smoke.jl`。`land_model_spectrum_V8` artifact 由 GitHub ResearchArtifacts 正常下载。

### 与提交状态的依赖偏离（运行后已还原）

GriddingMachineDatasets：

- `[sources]` 中 GriddingMachine 由远端 `wyujie` 临时改为本地路径 `../GriddingMachine.jl`（论文组合为两个本地 paper-release 分支）。
- NetcdfIO 与 PkgUtility 的 `[sources]` 远端 `wyujie` 条目临时移除，改由注册表解析：实测远端 `NetcdfIO#wyujie` 当前为 0.2.12，与 GriddingMachine 0.5.0 的 `NetcdfIO = "0.3.0"` compat 冲突，导致按提交状态无法完成解析；注册表 PkgUtility 0.3.1 的 git-tree-sha1（`f77541ed`）与提交 Manifest 所钉版本完全一致，NetcdfIO 采用注册表 0.3.0（tree `0a876b43`）。

Emerald：

- `[sources]` 中 GriddingMachine 由远端 `wyujie` 改为本地 `../GriddingMachine.jl`；NetcdfIO 的远端 `wyujie` 条目移除。
- compat 由 `NetcdfIO = "0.2.11"` 临时放宽为 `"0.2.11, 0.3"`。**这是运行 Emerald 烟雾测试的必要条件**：Emerald `wyujie` 声明的 NetcdfIO 上界（`<0.3`）与 paper-release GriddingMachine 要求的 `0.3.0` 直接冲突，按提交状态两者无法装进同一环境。放宽的安全性已核查：Emerald 全仓库仅在 `src/Land/Land.jl` 使用 `NetcdfIO: read_nc, save_nc!`，两者在 0.3.0 中均存在。
- 上述冲突再次证实初稿 4.4 节的预警：远端 `wyujie` 分支已相对论文环境漂移，正式归档必须锁定论文分支依赖来源，并需在 Emerald 侧同步 NetcdfIO compat。

## 结果

| 测试套件 | macOS 结果 | Windows 基线 |
|---|---|---|
| GriddingMachine 全套 | **63/63 通过**（8.8 s） | 63/63 |
| — Catalog initialization and schema | 5/5 | 5 |
| — Transactional catalog update | 6/6 | 6 |
| — Mirror fallback, cache isolation, and integrity | 10/10 | 10 |
| — Sync, information, tree, and cleanup | 8/8 | 8 |
| — Indexer read_dataset | 18/18 | 18 |
| — Model input dictionaries | 15/15 | 15 |
| GriddingMachineDatasets configuration | **38/38 通过**（2.9 s） | 38/38 |
| GriddingMachineDatasets package integration | **35/35 通过**（10.4 s） | 35/35 |
| Emerald 最小初始化烟雾 | **5/5 通过**（19.9 s） | 5/5 |
| 生产编号矩阵（31 编号，29 非交互）×3 轮 | **29/29 ×3 通过**，网络请求数 0 | 29/29 ×3 |
| 直接 NetCDF 效率实验（40 次测量） | **SHA-256 40/40 一致**；ELEV 中位降幅 53.6%、LAI 69.2% | 40/40；降幅 48.3%/82.9% |
| 故障注入 M01–M13 ×5 | **65/65 断言通过**，`.part` 残留 0 | 65/65 |
| 校外真实 Zenodo 下载（4 标签 ×3） | **12/12 SIZE+SHA256 通过**（显式 IP 解析；默认 DNS 被污染） | 12/12（默认 DNS） |
| 校外真实 FTP（4 标签 ×3） | 12/12 超时（校外网络边界，符合预期） | 12/12 超时 |

macOS 效率实验数字：ELEV 直接 `.nc`/`.tar.gz` 端到端中位 3.8 ms（CI 3.1–4.3）/8.2 ms（7.0–8.4）；LAI 26.6 ms（17.6–28.1）/86.4 ms（80.7–91.8）；逻辑临时占用 1568512→810299 B、27571221→13936426 B。两轮使用 SHA-256 相同的输入文件（ELEV `642a485f…`、LAI `fda32f69…`，后者即目录登记值）。macOS 校外 Zenodo 中位下载时间 3.8 s（91 KB）～70.8 s（4.2 MB），细节与 DNS 污染诊断见 `experiment_data/03_03/real_ftp_zenodo/macos_offcampus/README_观察记录.md`。

macOS 受控实验脚本为 Windows 版的平台变体，仅输出文件名与平台断言不同：`03_01_data/run_matrix_macos.jl`、`03_02_data/benchmark_distribution_pilot_macos.py`、`03_03_data/fault_matrix_macos.jl`、`03_03_data/run_real_ftp_zenodo_macos.jl`。仓库路径软链 `Emerald/GriddingMachine_paper`、`Emerald/GriddingMachineDatasets_paper` 指向两个论文分支工作树。

Emerald 烟雾测试覆盖：`grid_weather` 返回 `Dict{String,Vector{Float64}}`、`site_spac` 构建、`prescribe!` 后 `airs[1].state.ns` 与 `p_air` 有限、`soil_plant_air_continuum!` 60 s 单步后全部 airs 与 soils 状态量有限。

原始日志与环境：

- `03_05_data/gm_test_macos_raw.log`，SHA-256 `a5c968a88527d4f193c27f899e0ba7ae3bd364e16f8b9adbce481a1df0a64bcf`
- `03_05_data/gmd_test_macos_raw.log`，SHA-256 `28b3049dcb3cd0a91312531a8edd799d13ac57e21080d8f9e4f5b74369271359`
- `03_05_data/emerald_smoke_macos_raw.log`，SHA-256 `c4ecfd4dfcee026d52d22f64994992b9c30d08f787700eac7ab4d6a785d70831`
- `03_05_data/emerald_instantiate_macos.log`，SHA-256 `3a3429a389ecc1e83bcc592eae80b8f09313f057044a2cdc01b00442711bca8a`
- `03_05_data/emerald_manifest_macos.toml`（Emerald 环境完整依赖锁，可用于归档），SHA-256 `d488e25405a8bb015e350180fbfc1c77df6bf9b3b77a2cd9d9741281da3ca08e`

Emerald 环境关键依赖版本（含 git-tree-sha1）：NetcdfIO 0.3.0（`0a876b43`）、PkgUtility 0.3.1（`f77541ed`）、DataFrames 1.8.2（`5fab31e2`）、QuadGK 2.11.3（`5e8e8b0a`）、SpecialFunctions 2.8.3（`c3ac026e`）、GriddingMachine 0.5.0（本地 paper-release 路径）。

## 未执行项与边界

- 校园网内的 FTP—Zenodo 正式比较未在 macOS 执行，仍按协议保留为 Windows 校园网侧实验；macOS 校外轮不替代。
- Linux 未执行任何实验，论文不外推。
- GriddingMachine 的 Mirror 测试组含 Windows 格式 ping 文本的解析断言，在 macOS 上同样通过（解析为纯字符串处理，不依赖系统 ping）；macOS 上 `probe_url` 按实现返回 `Inf`，排序行为由注入分数矩阵覆盖。
- Emerald 烟雾测试使用合成 `grid_dict`/`grid_weather` 输入，与 Windows 一致；不构成真实气象、长期模拟或模型科学性能验证。
- Emerald 采用 `wyujie` 分支而非 `main`：`wyujie` 含提交 `c1d6a37 make sure it is competible with GriddingMachine`，把 `site_spac`/`site_driver_tuple` 签名放宽为 `Union{Dict,OrderedDict}`；`main` 仍限定 `Dict{String,Any}`，而 paper-release 的 `grid_dict` 存在返回 `OrderedDict{String,Any}` 的方法路径，故 `main` 不能覆盖全部接口路径。
- Windows 那轮的 Emerald 提交号未归档，因此本次不是"同版本复跑"，而是首次为 Emerald 依赖钉定可追溯提交。若 Windows 使用的是其他提交，两处结果不可直接互证，需由作者确认统一到 `9828b2a` 后重跑或如实分别报告。

## 对论文的建议用法

- 已按本记录把论文初稿（v0.1）修订为双平台表述：全部受控实验（核心回归、生产矩阵×3、效率、故障注入×65）Windows+macOS 通过；校外真实观察两平台各一轮；结论适用两个已测平台，不外推 Linux；校园网比较与真实气象/长期模拟仍排除在外。涉及章节：摘要/Abstract、3.1.3、3.2、3.3.2、3.3.3、4 章开头、4.1、4.2、4.3、4.5、5.1、5.4、6。
- 《待作者补充信息》中"Emerald 准确版本、仓库/论文引用"一项可由本记录填充：仓库 `silicormosia/Emerald.jl`、分支 `wyujie`、提交 `9828b2a`；但需作者确认该仓库是否为拟引用的正式来源（当前无 tag、无 DOI，且非 CliMA 组织下仓库）。
- 归档前必须解决 Emerald 与 GriddingMachine 之间的 NetcdfIO compat 冲突，否则第三方无法按声明版本复现任何含 Emerald 的结果。
