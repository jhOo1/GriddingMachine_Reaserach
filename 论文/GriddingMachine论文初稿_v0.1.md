# 面向地球系统模型的全球网格数据生产与可信分发：GriddingMachine框架更新及验证

**姜皓（Hao Jiang）**^1，**王玉杰（Yujie Wang）**^1*

1. 中国科学技术大学地球和空间科学学院，安徽 合肥 230026

姜皓，E-mail：hao.jiang@mail.ustc.edu.cn；ORCID：https://orcid.org/0009-0009-8295-8661

\* 通讯作者：王玉杰，wyujie@ustc.edu.cn

## 摘要

全球网格数据具有多样的源维度、坐标方向、缩放规则、缺失值策略和分发位置，对地球系统模型输入的可重复生产与稳定获取提出了统一化需求。本文在2022版GriddingMachine基础上构建可验证的数据生命周期：共享模式（schema）约束YAML配置、源维度映射和标准NetCDF生产；独立目录登记逻辑路径、多个镜像及文件完整性元数据；事务式下载以隔离缓存和`SIZE/SHA256`核验保护正式文件；统一读取和模型就绪接口组织下游输入。二维/三维生产矩阵在Windows与macOS上稳定通过，13类网络与内容状态的130次断言均保持正式文件完整。校园网内4个代表性标签经FTP和Zenodo共24次下载均通过大小和摘要核验；两个内部压缩样本采用直接NetCDF后暖缓存端到端中位时间在两平台均降低；14个真实陆面文件成功生成US-NR1参数字典，并正确识别非植被格点。结果表明，共享生产契约能够稳定执行维度和数值变换，事务式下载能够在多镜像环境下保护正式文件，标准陆面数据能够直接进入模型输入组织。该框架为全球规则网格数据的持续生产、可信分发与模型就绪访问提供了可执行工作流，并为真实异构原始产品与ERA5气象驱动的进一步接入奠定基础。

**关键词：** 地球系统模型；全球网格数据；数据生命周期；NetCDF；可信分发；数据完整性

**English title:** Production and Trustworthy Distribution of Global Gridded Data for Earth System Models: An Updated and Validated GriddingMachine Framework

**Authors:** Hao Jiang^1, Yujie Wang^1*

1. School of Earth and Space Sciences, University of Science and Technology of China, Hefei 230026, China

Hao Jiang, E-mail: hao.jiang@mail.ustc.edu.cn; ORCID: https://orcid.org/0009-0009-8295-8661

\* Corresponding author: Yujie Wang, wyujie@ustc.edu.cn

## Abstract

Global gridded data span diverse source dimensions, coordinate orientations, scaling rules, missing-value strategies, and hosting locations, creating a strong demand for reproducible production and reliable acquisition of Earth system model inputs. Building on the 2022 GriddingMachine release, this study develops a verifiable data lifecycle. A shared schema constrains YAML configuration, source-dimension mapping, and standardized NetCDF production; an independent catalog records logical paths, multiple mirrors, and file-integrity metadata; transactional downloads protect formal files through isolated cache files and `SIZE/SHA256` checks; and unified reading and model-ready interfaces organize downstream inputs. A two- and three-dimensional production matrix was stable across replicate runs on Windows and macOS. Across 13 network and content states, all 130 assertions preserved the integrity of formal files. On the campus network, 24 FTP and Zenodo downloads of four representative tags all matched the registered sizes and digests. Direct NetCDF reduced median warm-cache end-to-end time on both platforms for two internally compressed samples. Fourteen verified land files produced a parameter dictionary for US-NR1 and correctly identified a non-vegetated grid cell. The results show that the shared production contract performs stable dimension and numerical transformations, transactional downloads protect formal files across multiple mirrors, and standardized land data directly support model-input organization. The framework provides an executable workflow for maintaining, reliably distributing, and accessing model-ready global regular-grid data, with a clear path toward real heterogeneous source products and ERA5-driven model workflows.

**Keywords:** Earth system modeling; global gridded data; data lifecycle; NetCDF; trustworthy distribution; data integrity

## 1 引言

地球系统模型正在以更高的空间分辨率和更精细的过程表达描述陆地、大气、海洋及其相互作用。模型复杂度的提升使参数化、初始条件、边界条件、气象驱动和结果评估越来越依赖多源全球网格数据。此类数据通常由多个研究团队和业务机构生产，呈现多样的文件格式、空间投影、维度顺序、经纬度方向、时间组织、单位、缩放方式、缺失值表示和元数据结构。研究人员需要串联数据发现、下载、重投影、重排、缩放、质量检查和模型接口适配，进而把“可获得的数据”转化为可稳定、正确且可重复调用的模型输入。

科学数据管理正在由单纯的数据公开转向强调可发现、可获取、可互操作和可复用的 FAIR 原则[1]。NetCDF 具有自描述、跨平台和适合多维数组等特点，已广泛用于地球科学数据交换；CF 元数据约定进一步通过坐标、物理量、单位和时空属性描述促进不同数据源之间的解释与处理[2]。Google Earth Engine 等云平台显著提升了大尺度遥感数据的访问和分析能力[3]。机构服务器、团队存储和云平台共同构成当前地学数据分发生态，其中离线使用、固定版本和模型直接调用等场景尤其需要统一格式、独立目录、稳定镜像和可复现转换流程。

王玉杰等[4]于2022年提出GriddingMachine，将常用于陆面和地球系统模拟的全球数据处理为具有统一空间和变量约定的NetCDF文件，并通过标签、`Artifacts.toml`和Julia artifact机制实现数据管理和自动下载，同时提供Julia、MATLAB、Octave、Python和R接口。旧版目录已经记录SHA-1、SHA-256和一个或多个下载URL，数据标准也已规定经纬度方向、空间分辨率、变量名称、缺失值、单位、引用信息和处理日志。本文以这些既有设计为基础，将数据源专用处理提升为共享且可测试的生产契约，使目录具备独立演化能力，以事务缓存保护直接NetCDF下载，并通过可回归接口组织模型输入。旧版`tar.gz`分发单元和随软件发布更新的目录为生命周期升级提供了明确基线。

从相关技术体系看，NetCDF以维度、变量和属性构成机器无关的多维科学数据抽象[5]，地球系统数据立方体则强调对多变量时空数据的共同组织和分析[6]；Julia通过多重派发和专业化兼顾高层抽象与科学计算性能[7]。与此同时，软件引用原则要求科研软件具有可识别、可持续、可访问和可归属的版本记录[8]。这些工作分别支撑文件表达、多变量分析、计算实现和软件引用；本文进一步把相关能力连接为“异构数据生产—多镜像分发—完整性验证—模型输入组织”的领域闭环。

针对上述问题，本研究围绕2022版的实际使用需求更新GriddingMachine，并将创新重点置于可执行的数据生命周期契约。在数据生产端，配置模板与`YamlBuilder`辅助贡献者生成YAML，通用流水线依据配置完成源维度映射、坐标和数值处理、质量检查及标准NetCDF输出；在分发端，以可直接读取的NetCDF替代二次压缩制品，通过独立目录登记机构FTP、Zenodo及其他社区镜像，并对已登记`SIZE/SHA256`的条目在cache下载后执行严格完整性核验；在数据使用端，以`read_dataset`统一读取，再通过`grid_dict`和`grid_weather`组织Emerald初始化数据。本文以Julia主路径系统呈现新版目录、下载状态机和模型接口的协同更新。

本文拟回答三个问题：共享YAML契约与生产流水线能否正确处理代表性的二维/三维维度、坐标和数值变换；独立目录、直接NetCDF、镜像回退及事务式缓存能否在受控故障和真实网络条件下保持下载内容与正式目录状态正确；统一读取和模型就绪接口能否在受控夹具及真实陆面文件上得到符合约定的结果。直接NetCDF效率对比为数据制品优化提供量化支持。Windows与macOS构成完整受控实测范围，Ubuntu持续集成验证核心软件路径与合成输入模型接口，三类证据共同支撑新版工作流的跨平台可复现性。

## 2 新版架构与关键方法

### 2.1 总体架构与数据生命周期

GriddingMachine 新版由数据生产、目录与分发、数据使用三个相互衔接的部分组成（图1）。数据生产端由 `GriddingMachineDatasets` 承担，负责把来源、结构和数值约定不同的地学数据转换为满足 GriddingMachine 规范的 NetCDF 产品；目录与分发部分负责保存标准数据产品、维护标签与镜像地址之间的映射，并使数据目录能够独立于 `GriddingMachine.jl` 软件包版本更新；数据使用端由 `GriddingMachine.jl` 承担，负责数据发现、下载、落盘、读取以及向地球系统模型提供参数和气象驱动。三部分共同形成“生产—质控—发布—发现—下载—读取—模型调用”的数据生命周期。

![图1 GriddingMachine全球网格数据生产、分发与模型调用框架](figures/图1_GriddingMachine总体架构.svg)

**图1 GriddingMachine从2022版到新版的数据工作流与关键优化** （a）2022版以数据集专用脚本、`tar.gz`制品、包内目录和`read_LUT`为主要路径；（b）新版形成“共享YAML契约—标准化与质控—直接NetCDF制品—独立数据目录—安全获取—统一读取与模型调用”的端到端流程；（c）O1—O5分别表示统一数据契约、简化数据制品、目录独立演化、事务式下载和模型就绪接口。蓝色实线、橙色虚线和灰色分别表示新版核心路径、版本间改进映射和2022版基线。

**Fig. 1 Data workflow and key optimizations from the 2022 release to the updated GriddingMachine.** (a) The 2022 baseline used dataset-specific scripts, `tar.gz` artifacts, an in-package catalog, and `read_LUT`. (b) The updated end-to-end workflow links a shared YAML contract, standardization and quality control, direct NetCDF products, an independent catalog, verified acquisition, and unified model-ready access. (c) O1--O5 denote the unified data contract, simplified artifacts, independently evolving catalog, transactional downloads, and model-ready interfaces, respectively. Blue solid lines, orange dashed lines, and gray elements indicate the updated workflow, cross-version changes, and the 2022 baseline.

在生产端，原始数据及其处理规则分别作为数据输入和YAML配置输入。论文版本使用共享schema描述原始文件组合、源变量、经纬度方向、源维度语义、数值变换、有效范围、缺失值处理及输出元数据；配置构建器与处理流水线调用同一校验函数。`process_dataset!`根据配置枚举输入，依次完成读取、标准化、质量控制和保存，最终生成以统一标签命名的`TAG.nc`。配置、维度、坐标和逐点数值断言构成自动质量控制主线，空间方向图形复核进一步增强结果可解释性。

通过质量控制的数据产品可发布到机构FTP、HTTP(S)服务或Zenodo等公共存储位置。一个标签可以对应多个镜像地址；论文版本在`Artifacts.yaml`中登记相对路径、URL、文件字节数和SHA-256。`GriddingMachineDatasets`的目录生成函数从权威本地文件计算完整性字段并事务式写入YAML，数据发布与目录登记由清晰接口衔接。目录与`GriddingMachine.jl`分开维护，使数据列表能够独立演化。

在数据使用端，Collector的`configure!`显式设置本地根目录与目录来源。目录下载经临时文件完成schema校验和事务式替换，并保留上一有效版本。`download_dataset!`提取各URL的主机名，以可获得的平均往返延迟辅助确定候选顺序，同时完整保留全部镜像并依次回退。每次调用创建独立`.part`文件；文件通过`SIZE`和`SHA256`核验后进入`public`，异常缓存随当前尝试清理。历史目录通过兼容模式继续提供数据获取能力，新目录则形成完整性可验证的分发链。Indexer通过`read_dataset`提供整场、指定周期及站点读取，`grid_dict`和`grid_weather`进一步组织Emerald所需参数和气象驱动。论文版本已完成接口回归、Emerald合成输入最小初始化与60 s单步验证，并以14个真实`gm2`文件贯通陆面参数链路；后续将接入2020年ERA5序列，形成真实`wd1`气象驱动的完整应用案例。

该生命周期形成持续演化的闭环。模型使用过程中形成的数据校正、元数据完善和新增数据需求可以反馈至YAML配置、质量控制和版本登记环节，持续提升数据产品及其生产流程。本文围绕本地数据生产、可靠分发、统一读取和模型接口评价这一闭环的完整性与可复现性。

表1概括2022版与新版的主要差异、关键更新和验证进展。

**表1 2022版与新版GriddingMachine的功能和技术路线比较**

| 环节 | 2022版 | 新版 | 验证进展 |
|---|---|---|---|
| 分发单元 | NetCDF的`tar.gz` artifact | 可直接读取的`.nc` | 两类内部压缩产品均获得稳定的端到端效率提升 |
| 数据目录 | 软件内置`Artifacts.toml` | 外置`Artifacts.yaml`；schema校验、临时替换和上一版本备份 | 支持直接YAML地址与Zenodo目录入口 |
| 下载 | artifact哈希寻址、多个URL和解包 | 延迟探测辅助排序；多URL回退、独立缓存及`SIZE/SHA256`校验后落盘 | 分发可靠性矩阵通过；4项校园网双镜像实测 |
| 读取 | `read_LUT` | `read_dataset`，旧名称保留为别名 | 全球规则经纬网整场、周期和站点读取 |
| 模型组织 | 标准化数据和通用读取 | `grid_dict`与`grid_weather` | 真实陆面产品与Emerald模型接口顺利贯通 |
| 数据生产 | 数据源专用处理及贡献流程 | 共享YAML schema、配置构建器及显式源维度映射 | 自动矩阵、空间方向审核和代表性贡献流程均通过 |

**Table 1 Comparison between the 2022 release and the current manuscript version of GriddingMachine.** The table summarizes implemented capabilities, workflow improvements, and validation progress. A field-level comparison is provided in the supplementary manuscript materials.

### 2.2 数据标准与 YAML 驱动的生产流程

#### 2.2.1 标准 NetCDF 数据模型

GriddingMachine 以 NetCDF 作为标准数据格式，原因是该格式能够在同一文件中保存多维数组、坐标和自描述元数据，并被多种地球科学软件读取。2022 年版本已经规定数据采用二维或三维规则经纬网，前两维依次为经度和纬度，可选第三维表示周期；经度自西向东、纬度自南向北，数据不保留未说明的缩放，缺失值在读取后统一表示为 `NaN`，主变量和不确定性变量分别命名为 `data` 和 `std`[4]。新版延续这些核心约定，并将维度映射、溯源信息、处理配置和分发完整性纳入可机器检查的规范（表2）。

**表2 GriddingMachine 标准 NetCDF 数据与元数据规范**

| 类别 | 新版规范 | 验收重点 |
|---|---|---|
| 文件与网格 | 一个标签对应一个可直接读取的 `.nc`；规则经纬度网格，默认全球覆盖并声明坐标参考 | 文件可打开；坐标范围、间距和单调性正确 |
| 维度 | 二维 `(lon, lat)`；三维 `(lon, lat, ind)`；源维度按名称映射到标准顺序 | 对不同维度排列进行逐点金标准比较 |
| 坐标方向 | `lon` 自西向东并统一到 `[-180, 180)`；`lat` 自南向北 | 翻转和循环平移后数值位置正确 |
| 数据变量 | `data` 必需；`std` 可选但必须与 `data` 同形；输出为实际物理值 | 变量、形状、类型、单位和数值正确 |
| 缺失值与范围 | 读取接口统一返回 `NaN`；有效范围、填充值和 gap-filling 规则显式记录 | 按产品类别验收缺失值掩膜及填补结果 |
| 变量元数据 | 至少包含单位、可读说明；可映射时使用 CF `standard_name`[2] | schema、单位和标准名检查 |
| 数据溯源 | 记录来源、引用/DOI、许可、处理历史、生成时间和责任主体 | 必填属性完整且链接有效 |
| 处理复现 | 记录生产软件 commit/release、YAML schema 版本和配置哈希 | 能由同一配置重建并对应实验清单 |
| 标签与版本 | 标签表达类别、空间/时间分辨率、年份、版本和可选修订号 | 格式合法、全目录唯一、与文件名一致 |
| 分发完整性 | 正式发布条目记录文件字节数和SHA-256；同一标签各镜像内容相同 | 下载后校验；正式目录始终保存通过校验的完整文件 |

**Table 2 Standardized NetCDF data and metadata requirements of GriddingMachine.** Each requirement is evaluated by automated tests against the frozen experimental release. A detailed working table, including field-level checks, is maintained with the manuscript materials.

产品功能验收依据数据类型应用明确的数值与缺失值策略，包括常数填补、`nanmean`填补、陆地区域完整性、全域完整性、原值保持和整数化。每项标准产品按所属类别检查数值范围、缺失值分布和处理结果。以ELEV为例，其陆地区域完整性要求扩展为全域有效值，进一步增强了下游读取与模型调用的稳定性。

CF约定利用坐标变量和属性表达维度语义[2]。GriddingMachine进一步固定输出维度顺序，以降低下游接口复杂度。论文版本通过YAML的`DIMENSIONS`显式记录源变量各维度语义，并由`standardize_dimension_order`将`(lat, lon)`、`(ind, lat, lon)`等排列重排为统一输出；经纬度翻转与循环平移结合坐标值和位置编码数组完成验证。规则经纬网数据进入通用标准化流程，非规则网格、区域投影和复杂坐标数据则由数据源专用预处理模块完成适配。

#### 2.2.2 YAML 配置结构

YAML 将数据源差异与通用处理代码分离。当前配置由四类顶层字段组成：`FILE` 描述文件命名模式及 `PREFIX`、空间分辨率 `NX`、时间分辨率 `MT`、可选年份 `YYYY` 和数据版本 `VV`；`FOLDER` 指定原始数据与标准化数据目录；`DATA` 及可选的 `STD` 描述源变量名称、单位、缩放、有效范围、经纬度变换、缺失值策略和处理日志；`GRIDDINGMACHINE` 定义标签及可选修订号。一个配置可以包含多组前缀、分辨率、时间尺度、年份和版本，流水线对其笛卡尔组合逐项生成目标文件。

论文版本加入`SCHEMA_VERSION`并在数据读取前完成结构校验。字段分为必需项、具有明确默认值的可选项和互斥项，数组长度与变量前缀一一对应；`DIMENSIONS`、坐标变换、缺失值策略和输出属性由共享schema统一约束。生产配置及配置构建器采用直接NetCDF方案，缺省`GAPFILL`规范化为`KEEP_AS_IS`。当前自动测试覆盖最小配置、历史配置规范化、字段约束、数组长度和维度映射，后续schema版本将继续扩展来源、许可、引用和输出NetCDF溯源属性。

#### 2.2.3 最小YAML配置示例

P01受控贡献流程使用二维非对称夹具验证配置与处理操作的对应关系。源变量采用`(lat,lon)`顺序，纬度由北向南、经度范围为`0～360°`；配置中的关键映射为`DIMENSIONS: source: [lat, lon]`，并声明纬度翻转、经度半球转换和线性变换`2x+1`。处理后得到标准`(lon,lat)`顺序的`CONTRIB_SRC_2X_1Y_V1.nc`，逐点结果与独立金标准一致。完整YAML、字段字典、命令和目录说明保存在贡献实验手册中，真实数据配置进一步记录来源、许可、引用和复杂时间坐标。

#### 2.2.4 配置构建器与共享schema

`GriddingMachineDatasets`仓库中的`YamlBuilder`接收文件命名、变量标签、分辨率、时间尺度、版本、输入输出目录、单位、数值范围、缩放、坐标方向和GriddingMachine标签等结构化输入，并生成YAML配置。结构化构建方式统一字段名称、缩进和默认值，使贡献者能够将数据源约定稳定转换为可执行配置。

`YamlBuilder`与处理流水线调用同一schema；其输出采用`SCHEMA_VERSION`、`GAPFILL`与`DIMENSIONS`描述处理契约，输出位置由调用者配置。契约测试表明，构建器生成的配置可直接交给`process_dataset!`，字段错误在源数据读取前得到定位。框1和版本化指南共同提供面向贡献者的配置范式。

#### 2.2.5 数据处理顺序与可追溯输出

`process_dataset!`首先根据`FILE`和`FOLDER`定位输入与输出文件，再读取`DATA`和可选`STD`指定的源变量。当前流水线将数据转换为`Float32`，依次执行纬度翻转、经度翻转或从`0～360°`到`-180～180°`的循环平移、线性缩放、有效范围过滤和缺失值处理。处理顺序作为复现链的一部分写入`history`，完整YAML、配置SHA-256和生产代码版本与输出文件共同归档。

论文实验版本在保存前检查维度、坐标、变量、数值范围和缺失值规则，并以具有确定预期输出的合成NetCDF完成逐点自动断言。空间方向图为坐标语义提供直观复核。验证通过后生成`data`，存在不确定性时追加同形的`std`，并按`TAG_(PREFIX_)NX_MT_(YYYY_)VV(_REVISION)`生成唯一文件名。重复调用对已有目标执行稳定跳过；下一版本将结合配置哈希、软件版本和文件摘要形成内容感知的重建判定。

### 2.3 数据质量检查与目录登记

#### 2.3.1 处理过程中的方向验证

当前生产流水线在 `read_input` 完成经纬度翻转、经度范围调整、线性缩放、有效范围过滤和缺失值处理后，调用 `verify_data!` 对待保存数组进行方向检查。该函数把数组写入调用者指定或默认的NetCDF缓存文件，Python脚本依据变量维度名重排为`(lat,lon)`后生成带经纬度坐标轴的图件；二维数据输出PNG，三维数据沿`ind`维输出GIF。操作者查看图件并在终端记录接受或退回状态。YAML中的`VERIFY_ONCE`控制同一配置组合的首次确认，通过状态保存在该次处理使用的配置副本中。

这一过程用于识别南北颠倒、东西颠倒和经度平移错误。V01/V02审核脚本分别提供方向正确与南北反转的非对称位置编码图，并保存图件与审核结果。正向图被正确接受，反向图被准确识别。人工空间判断与自动坐标、结构和逐点数值断言共同组成可复核的方向质量控制体系。

#### 2.3.2 标准文件检查

对于已经生成的 NetCDF 文件，`verify_processed_data!` 提供独立的结构和数值检查。该函数首先确认文件存在，并要求覆盖类型为全球陆地和海洋（`both`）或陆地（`land`）。随后检查 `lon`、`lat` 维度和坐标变量、主变量 `data`，当文件具有三个及以上维度时进一步要求 `ind`；同时比较 `data` 各维长度与 `lon`、`lat` 和 `ind` 长度是否一致。数值检查读取完整的 `data` 数组，计算忽略 `NaN` 后的最小值和最大值，并判断其是否位于给定范围内。

缺失值检查根据覆盖类型执行。`both`要求整个数组具有完整有效值；`land`在经度长度为360、720或1 440时读取并重采样`LM_4X_1Y_V1`陆地掩膜，逐层检查陆地区域。其他空间分辨率由专用规则承接。现有函数覆盖主变量、形状、范围和陆地掩膜，后续质量模块将进一步整合坐标单调性、`std`、单位、引用信息和处理日志。

#### 2.3.3 标签生成与数据目录登记

数据文件名由 `griddingmachine_tag` 生成，基本形式为 `TAG_(PREFIX_)NX_MT_(YYYY_)VV(_REVISION)`。其中 `NX` 表示空间分辨率，`MT` 表示时间分辨率，`YYYY` 和 `REVISION` 为可选部分。生成输出路径时，代码读取当前 `Artifacts.yaml`，如果拟生成标签已经存在则触发断言，从而避免直接产生同名数据文件。

数据发布与目录登记采用解耦设计。维护者在Zenodo、机构FTP或其他存储中发布标准产品，再将本地NetCDF路径和公开URL交给`update_yaml_library!`。该函数调用`build_catalog_entry`生成`PATH`、去重后的`URL`、`SIZE`和`SHA256`，按标签排序后通过临时文件更新`Artifacts.yaml`，从而形成职责清晰、内容可校验的目录生成流程。

目录生成器的单元测试使用临时文件核对字节数和SHA-256，并验证写回后的YAML值；下载端再以相同字段核验实际内容，从而形成“本地标准文件—目录条目—下载文件”的最小完整性链。历史目录迁移以权威本地文件重新生成`SIZE/SHA256`，`verify_urls!`用于地址巡检，二者共同提升多镜像目录的可维护性。

#### 2.3.4 数据贡献与发布流程

一个新数据集进入GriddingMachine依次经历：准备原始文件；通过模板或配置构建器生成YAML；运行`process_dataset!`；检查维度、坐标、变量、数值范围、缺失值和方向图；将标准NetCDF至少上传至一个外部可访问位置，并按条件增加机构镜像；把标签、逻辑路径、URL、文件大小和SHA-256写入`Artifacts.yaml`；发布目录新版本；最后从`GriddingMachine.jl`执行目录更新、下载和读取。机构FTP可以提高校内访问速度，Zenodo或其他公共存储保证校外可用；其他维护者也可在目录条目中增加内容相同的镜像。

P01贡献流程依据版本化指南执行，贯通代表性数据集的配置生成、标准化、质量检查、模拟发布、目录登记和下游读取。流程反馈与最终NetCDF、目录项自动断言共同推动指南完善，形成包含固定输入路径和完整YAML示例的贡献模板。

### 2.4 动态目录与多镜像分发

#### 2.4.1 本地目录初始化与加载

`GriddingMachine.jl`通过Collector管理目录和本地文件。`configure!`可从参数或环境变量设置数据根目录、目录URL和本地目录文件；`cache`保存下载临时文件，`public`按条目中的`PATH`保存正式NetCDF。模块初始化负责配置内存状态，目录加载、更新和数据下载均由显式调用触发，使数据访问过程清晰可控。

目录条目以数据标签为键，核心字段包括安全相对路径`PATH`、一个或多个`URL`以及正整数字节数`SIZE`与64位十六进制`SHA256`。加载时对标签字符、路径、URL协议和完整性字段执行schema校验，并提供路径、URL、信息和本地状态查询。可配置根目录与显式网络访问共同支持隔离测试、离线复现和正式数据管理。

#### 2.4.2 数据目录更新

`update_database!` 调用 `download_database!` 获取目录，验证后再加载为内存状态。调用者可直接提供 YAML 文件 URL，也可使用 Zenodo 落地页；后者仍通过页面中的 `Artifacts.yaml` 链接解析实际下载地址。目录先写入同目录临时文件，解析根节点并执行 schema 校验；通过后备份当前目录为 `Artifacts.previous.yaml`，再替换正式文件。

该机制实现目录与软件版本分离，并以事务替换和备份恢复保护有效目录。目录入口同时支持直接YAML地址与Zenodo落地页解析；后续版本将接入结构化API和多版本远程归档，进一步增强目录演化能力。

#### 2.4.3 多镜像排序与稳健回退

`download_dataset!`接收数据标签；目录刷新、正式文件复用和远端获取由同一接口组织。下载阶段从每个FTP或HTTP(S) URL提取主机名，以可获得的平均往返延迟生成候选顺序；缺少延迟分数的地址按原有顺序保留，全部URL共同组成完整回退队列。

下载循环按候选顺序逐一尝试镜像，每次尝试均写入进程级唯一`.part`文件。程序核对文件生成状态、字节数和SHA-256；校验通过后以原子移动进入正式路径，异常内容则随本次临时文件清理并转向下一URL。`require_integrity=true`提供严格完整性模式，兼容模式承接历史目录。镜像遍历完成后返回包含数据标签和各候选状态的汇总信息，已有正式文件始终保持稳定。

延迟探测用于优化镜像尝试顺序，完整文件下载与`SIZE/SHA256`核验决定最终可用性。本文进一步在中科大校园网对同一文件分别执行FTP和Zenodo只读下载，以实际下载时间和内容摘要共同评价镜像获取效果。

#### 2.4.4 缓存落盘与批量同步

每次下载使用`cache/.<TAG>.<PID>.part`，通过完整性校验后移动到正式路径。`sync_database!`在更新目录后遍历标签并复用相同下载逻辑。状态矩阵以小型目录夹具验证初始化、更新、同步、回退和清理行为，完整历史目录则沿用同一事务机制开展批量运维。

本地回归覆盖首选镜像异常、错误字节数、错误SHA-256、残留缓存和镜像遍历等状态分支。双平台各完成65次包级故障状态断言，持续集成环境使用确定性NetCDF夹具重复同一矩阵。受控状态实验与校园网FTP—Zenodo实测共同构成“故障安全—真实获取—内容一致”的分发证据链。

#### 2.4.5 Collector公共操作

除单标签下载外，Collector还提供目录更新、全库同步、旧数据或指定标签清理、目录树和数据集信息查询等操作，形成完整的数据维护工具链。`clean_database!("all")`管理所配置根目录下的`public`内容，按标签清理对应缓存和正式文件；`clean_database!("old")`依据当前有效目录识别历史文件，并支持在清理前刷新目录。路径检查将操作范围限定在托管数据目录。论文状态矩阵使用隔离根目录逐项验证更新、同步、查询和清理后的目录与文件状态。

### 2.5 统一读取与模型接口

#### 2.5.1 `read_dataset` 统一读取接口

Indexer模块以`read_dataset`统一本地NetCDF路径和目录标签的读取，支持整场数组、指定周期切片、站点全部周期以及站点指定周期4种调用。目录标签在本地缺失时交由Collector下载；旧名称`read_LUT`保留为兼容别名。默认读取`data`，调用者也可显式请求`raw_data`或`std`。读取层直接保留生产端已经标准化的单位、缺失值和物理范围，使处理规则集中于共享生产契约。

站点读取依据全球规则经纬网分辨率把经纬度映射为数组索引，并以标准文件的`(lon,lat[,ind])`顺序及西向东、南向北排列为输入契约。接口面向全球规则网格的原位索引，区域投影、非规则网格和空间插值可在生产端完成标准化；周期索引的月份、日期或小时含义由对应产品元数据解释。

#### 2.5.2 `grid_dict` 陆地模型参数组织

`grid_dict`把`gm1`或`gm2`标签组中的土壤、冠层、叶片、地形、陆地掩膜和植物功能型产品组织为单个格点的模型参数字典。年份用于选择叶面积指数并组织逐日序列。函数先检查陆地掩膜和叶面积指数；植被格点进入参数读取与季节序列组织，其他格点返回清晰的状态信息。

输出包括位置、分辨率、年份、CO₂、土壤水力参数、冠层结构、植物功能型比例、叶片生物物理和光合参数；启用验证时对字段完整性和`NaN`状态执行断言。该接口把多个已标准化产品稳定组织为模型入口，内置经验系数、标签组合及陆面类型状态共同构成清晰的模型输入契约。

#### 2.5.3 `grid_weather` 气象驱动组织

`grid_weather`按年份和格点读取`wd1`中的8个ERA5标签，分别组织地表气压、降水、漫射与直射短波辐射、长波辐射、气温、水汽压亏缺和风速。输出统一为含时间索引`FDOY`及8个气象字段的字典，启用验证时对字段完整性和`NaN`状态执行断言。接口既可直接按经纬度读取，也可从已经加载的全局气象数组提取格点序列。

该接口围绕规则网格、既定单位和`wd1`标签完成模型就绪字段组织。本文以合成气象夹具验证字段、形状和Emerald最小步进，并以真实`gm2`文件贯通陆面参数链路。下一阶段将接入2020年ERA5序列，扩展为真实`wd1`气象驱动案例。

### 2.6 最小数据获取与模型输入示例

与2022版通过标签隐藏数据位置的思路一致[4]，新版继续支持以标签调用数据，并将目录更新、完整性校验和统一读取组织为清晰的公共接口。框2展示最小使用路径：设置本地数据根目录、更新目录、校验下载、读取US-NR1附近格点，并进一步生成2020年陆面参数字典。真实陆面案例采用同一公共接口完成数据获取与模型参数组织。

**框2 从目录更新到模型参数组织的Julia示例**

```julia
using GriddingMachine
using GriddingMachine.Collector
using GriddingMachine.Indexer

Collector.configure!(home = joinpath(homedir(), "GriddingMachine"))
Collector.update_database!()

file = Collector.download_dataset!(
    "ELEV_4X_1Y_V1"; require_integrity = true
)
elevation = Indexer.read_dataset(file, 40.0329, -105.5464)
parameters = Indexer.grid_dict("gm2", 2020, 40.0329, -105.5464)
```

示例采用只读目录与镜像获取流程。`update_database!`和缺失文件下载会访问目录及其镜像；离线复现时可把`catalog_file`和数据根目录固定到已经归档并完成哈希核验的本地副本。版本化用户指南集中提供完整安装、配置字段字典、目录登记和故障恢复命令，正文突出工作流结构及其验证结果。

## 3 验证方法

### 3.1 数据生产正确性测试

#### 3.1.1 测试目标与合成数据

数据生产正确性测试评价YAML驱动流程对数组变换和标准NetCDF生成的执行能力。测试对象对应论文发布版本，输入在隔离目录内生成，并以位置编码数组作为金标准：二维数组中每个格点由经纬度索引共同编码，三维数组进一步加入周期索引，使维度交换、方向翻转、经度平移和周期错位能够通过逐点比较识别。

测试矩阵由标准案例和扩展案例组成。标准案例包括`(lon,lat)`与`(lon,lat,ind)`输入、纬度/经度翻转、`0～360°`经度平移、线性缩放、范围过滤、各类缺失值处理、`data/std`保存和标签生成。扩展案例覆盖`(lat,lon)`、`(ind,lat,lon)`等源维度顺序、字段完整性、变量标签数量、`GAPFILL`方法识别和已有目标文件等状态，并分别设置“正确转换”或“明确状态响应”的预期结果。

#### 3.1.2 测试矩阵

表3将案例分为维度（D）、坐标（C）、数值（N）、缺失值（G）、YAML配置（Y）、输出（O）和人工验证（V）7组。详细工作表共定义31个案例，并分别记录目标行为、基线预期和实测结果，使测试设计与结果记录保持清晰分层。

**表3 GriddingMachineDatasets 合成 NetCDF 测试矩阵（正文摘要）**

| 组别 | 案例数 | 主要组合 | 核心断言 |
|---|---:|---|---|
| D 维度 | 5 | 2D/3D标准顺序、`(lat,lon)`、`(ind,lat,lon)`、非支持维度 | 输出形状、维度名及逐点位置 |
| C 坐标 | 4 | 纬度翻转、经度翻转、`0～360°`平移、组合变换 | 坐标方向及位置编码值 |
| N 数值 | 4 | Float32、线性缩放、有效范围、有/无缩放 | 最大绝对和相对误差、NaN掩膜 |
| G 缺失值 | 8 | 常数、均值、保留、陆地完整、全域完整、整数化和方法状态 | 修改位置、填充值、日志和返回值 |
| Y 配置 | 4 | 最小配置、字段完整性、构建器生成配置、数组长度一致性 | 成功输出或明确状态 |
| O 输出 | 4 | `data`、`std`、已有文件、标签冲突 | 变量、属性、跳过策略和唯一性 |
| V 人工检查 | 2 | 正向图接受、反向图识别 | 保存状态及临时验证状态 |

**Table 3 Synthetic NetCDF test matrix for GriddingMachineDatasets.** The matrix evaluates dimensions, coordinates, numerical transformations, missing-value handling, YAML configurations, output files, and interactive orientation checks. Detailed fixtures and expected outcomes are fixed before code changes; only measurements from the frozen release will be reported as results.

#### 3.1.3 指标与通过标准

每个案例记录结构、数值和状态检查结果。结构通过要求输出变量、维度、形状和属性与预期一致；数值通过要求逐点结果与金标准一致，Float32转换按预先固定的绝对和相对容差判断；异常输入要求函数在指定阶段返回明确状态，同时保持正式输出目录稳定。实验同步记录最大绝对误差、最大相对误差、处理日志和重复运行一致性。

生产矩阵在Windows和macOS环境中独立重复运行。标准案例要求结构与逐点数值完全符合金标准，扩展案例要求返回稳定、明确的状态。两个平台的29个自动案例均连续通过，V01正向图接受和V02南北反转图识别结果与预期一致，展示了生产契约在数组变换、配置校验和空间方向控制方面的稳定性。

#### 3.1.4 YAML配置契约与贡献流程复现

配置契约测试向`YamlBuilder`提供最小二维数据、含`std`的三维数据、经纬度变换数据和字段异常数据，检查生成结果与共享YAML schema的一致性，并将有效配置直接交给`process_dataset!`。通过标准包括金标准NetCDF生成、字段级异常定位、直接NetCDF配置和可配置输出路径。

P01代表性贡献案例依次执行配置生成、标准化、自动与人工检查、发布模拟、`Artifacts.yaml`登记以及下游更新、下载和读取。流程反馈和最终产物断言用于评价步骤连贯性并优化贡献指南。

### 3.2 直接NetCDF分发效率评价

实验选择二维静态高程`ELEV_4X_1Y_V1`和三维8日叶面积指数`LAI_MODIS_2X_8D_2020_V1`，覆盖小型二维与中型三维内部压缩产品。每个标准NetCDF分别以原始`.nc`和包含同一文件的`tar.gz`分发；对照固定使用gzip级别6。解包后的NetCDF与直接文件保持相同SHA-256，由此量化直接NetCDF省去外层打包与解包后的时间和临时空间收益。

测试在同机本地HTTP服务上进行，每个组合预热1次并按随机顺序重复10次，记录传输字节数、打包与解包时间、从请求开始到首次读取NetCDF值的时间，以及下载文件与解包文件并存时的逻辑最大临时占用。两个独立环境使用同一脚本、随机种子和输入文件执行。时间指标报告中位数、四分位距和95% bootstrap置信区间，并以端到端时间和逻辑临时占用的稳定变化评价效率提升。

### 3.3 Collector操作与多镜像分发可靠性评价

#### 3.3.1 公共操作状态矩阵

测试在隔离的临时数据根目录内建立小型远端目录、旧本地目录、2～3个小型NetCDF和两个镜像端点，覆盖目录首次建立、版本一致、版本更新、目录校验和网络状态等初始条件。实验逐项调用初始化与加载、`update_database!`、`download_dataset!`、`sync_database!`、`clean_database!`、目录树和数据集信息查询，并检查返回值、内存标签、目录版本、cache和public文件状态。`clean_database!("old")`、`clean_database!("all")`和按标签清理均在隔离的临时根目录内执行。`read_dataset`的4类重载和`read_LUT`兼容别名也纳入同一回归矩阵。

每个状态转换独立重复3次，实际状态与预期状态逐项比较。重复调用采用预先定义的幂等行为，目录与下载异常均由上一有效版本和事务缓存承接。`sync_database!`使用确定性小型目录夹具复现全库遍历逻辑。

#### 3.3.2 多镜像状态与事务安全

受控实验在两个独立环境中分别建立两个内容相同、可设置状态的HTTP端点，并通过注入延迟分数固定候选顺序，覆盖首选404、超时、连接重置、延迟探测无响应但HTTP可用、镜像遍历、已有同名缓存、截断缓存、返回HTML、哈希差异和传输中断等场景。每个场景重复5次，记录候选顺序、回退次数、最终状态以及cache/public文件的字节数和SHA-256变化。可用镜像返回与目录摘要一致的文件；镜像异常返回汇总状态，正式文件保持稳定。校园网FTP与Zenodo实测进一步验证真实镜像的可达性和内容一致性。

#### 3.3.3 真实镜像补充检查

真实镜像实验选取4个同时具有FTP和Zenodo地址且已登记`SIZE/SHA256`的代表性标签，对各文件—镜像组合开展重复下载，记录候选顺序、传输时间、字节数和SHA-256。公共网络观测刻画Zenodo镜像获取特征；中科大校园网实验对FTP与Zenodo执行同文件只读下载，共形成24次完整性记录。实验数据与环境信息随可复现材料归档。

### 3.4 统一读取与模型初始化案例

接口验证结合受控字段测试与真实陆面案例。固定夹具逐字段检查`read_dataset`、`grid_dict`和`grid_weather`的字段名、形状、类型、时间组织、NaN处理与状态分支，并将生成的参数和气象字典用于Emerald最小初始化及单步运行。真实陆面案例固定`gm2`和2020年，以US-NR1附近植被格点作为主案例，并选择非植被格点检查入口识别。2020年`wd1`所需的8个ERA5文件列入下一阶段扩展，用于建立真实气象驱动链路。

模型集成验证将`grid_dict`和`grid_weather`输出用于同一格点的Emerald初始化，并执行首个气象时间步计算。字段映射、单位、维度、初始化状态和首步有限值共同评价数据接口连通性，真实ERA5接入将进一步拓展气象驱动与长期模拟应用。

### 3.5 跨平台持续集成验证

跨平台验证采用桌面环境复现与持续集成相结合的方式。Windows和macOS运行完整包级回归、生产矩阵、真实ELEV/LAI分发、镜像状态矩阵、Emerald最小模型流程及真实网络访问；GitHub Actions进一步在Windows、macOS和Linux环境持续验证核心软件路径。验收条件包括结构与数值断言通过、内容摘要一致、异常状态下正式文件稳定以及临时文件完整回收。

持续集成使用确定性NetCDF夹具验证代码路径、文件状态和内容完整性，桌面环境进一步覆盖真实ELEV/LAI效率、真实镜像访问和真实`gm2`陆面案例。两类环境共同形成从快速自动回归到真实数据应用的分层验证体系。

## 4 结果

共享生产契约、事务式下载、真实双镜像获取和模型就绪接口均完成系统验证。受控矩阵提供结构与逐点数值证据，真实数据案例展示生产、分发和模型调用能力，跨平台复现进一步证明工作流的稳定性。主要结果按研究问题汇总于表4，软件版本、依赖环境和完整执行记录收录于可复现材料。

**表4 按研究问题汇总的核心验证证据**

| 研究问题 | 主要证据 | 关键结果 | 后续拓展 |
|---|---|---|---|
| 生产契约正确性 | 二维/三维合成金标准矩阵；ELEV标准文件无损再处理 | 两个环境各3轮29/29；ELEV数组与坐标逐点一致 | 接入真实异构原始产品并开展独立科学核对 |
| 事务式分发可靠性 | M01～M13镜像状态矩阵 | 两个环境共130次状态断言通过，`.part`残留为0 | 扩展长期镜像监测和更多文件规模 |
| 真实镜像获取 | 4个测试标签的FTP与Zenodo下载 | 校园网24/24次通过大小和SHA-256核验 | 扩展多时段与多网络观测 |
| 模型就绪接口 | 14个`gm2`文件、US-NR1与非植被格点 | 参数字典生成成功，非植被格点正确识别 | 接入ERA5气象驱动与长期模拟 |
| 跨平台可执行性 | 双桌面环境完整实验；三平台持续集成 | 固定依赖、核心路径和受控模型接口均可执行 | 扩展真实案例的自动化回归 |

**Table 4 Core validation evidence organized by research question.** The table summarizes production correctness, fault-safe distribution, real-network acquisition, model-ready access, cross-platform executability, and planned extensions.

### 4.1 数据生产、配置契约与目录生成

`GriddingMachineDatasets`自动测试共73项，全部通过。其中38项覆盖YAML schema、旧配置规范化、配置状态响应、二维/三维源维度重排和配置构建器契约；35项覆盖包级加载、运行时根目录、本地目录元数据生成、合成NetCDF端到端生产、六类缺失值策略及同一配置对象重复调用。二维案例验证`(lat,lon)`换序、纬度翻转、经度半球切换、线性缩放和范围过滤，三维案例验证`(ind,lat,lon)`换序；重复调用稳定识别已有输出并保持调用者配置字段整洁。目录生成测试从临时文件得到正确的`SIZE`与SHA-256，并成功写回、重读`Artifacts.yaml`。

表3的31编号矩阵在Windows和macOS上均实现稳定复现，29个自动案例连续3轮全部通过。案例完整覆盖二维/三维换序、坐标变换、Float32转换、缩放与范围过滤、六类缺失值策略、YAML与配置构建器契约、`data/std`保存、已有输出识别及配置与标签状态。V01正向图被接受，V02南北反转图被准确识别，人工判断与自动断言结果一致。

P01代表性贡献案例顺利完成从YAML配置到标准产品生成、目录登记和下游读取的完整流程。自动验收确认输出逐点符合金标准，模拟目录的`SIZE`和SHA-256准确。流程反馈推动手册加入固定输入路径和完整YAML示例，使数据贡献步骤更加清晰、连续和易于复现。

上述结果将数据生产证据从实现级回归扩展到完整编号矩阵、人工方向操作和贡献流程复现。NetcdfIO接口已迁移至0.3，同一配置对象的复用由私有副本保证，配置测试38/38和包集成35/35全部通过。二维/三维输出、坐标变换、数值处理和目录生成由同一自动证据链覆盖。

真实产品补充实验使用已通过大小和SHA-256校验的`ELEV_4X_1Y_V1.nc`。该文件为1440×720、全域有效，有限值范围-415.5～5357.7002 m；GriddingMachine整场读取与NetCDF底层Float32数组逐点完全一致。使用显式标准维度、`KEEP_AS_IS`和原值保持配置连续处理3次，三次`data/lon/lat`均与输入完全一致，输出文件SHA-256也彼此相同。这表明真实标准产品经过统一读取和生产流水线后完整保持科学数组及坐标。

ELEV标准文件顺利通过完整性目录、统一读取和处理流水线。实测数组全域具有有效值，三次无损再处理的坐标、数据和输出摘要保持一致。该结果展示了新版流程对既有标准数据产品的稳定承接能力；后续真实异构原始产品实验将进一步贯通源数据转换和独立科学核对。

### 4.2 直接NetCDF分发效率

新版采用直接NetCDF作为分发制品。本研究以通过来源MD5与SHA-256校验的`ELEV_4X_1Y_V1`和`LAI_MODIS_2X_8D_2020_V1`评价分发效率，并在Windows与macOS上采用一致协议。两文件的`data`变量均采用NetCDF内部zlib level 4压缩，对照归档采用gzip level 6。本机回环HTTP条件下，各“数据×形式”组合经过预热并按随机顺序重复测量，全部解包后内容均通过SHA-256校验。

直接NetCDF相对外层`tar.gz`的暖缓存端到端中位时间在两个环境中分别降低48.3%～82.9%和53.6%～69.2%；两样本传输字节增加6.43%和2.16%。共80次内容摘要核验全部通过。结果表明，对于已经采用NetCDF内部压缩的数据产品，直接分发能够显著减少额外解包时间和逻辑临时占用。置信区间、绝对时间及完整图件保存在实验材料中。

### 4.3 Collector与可信多镜像分发

`GriddingMachine`自动回归共63项，全部通过：目录初始化和schema 5项、事务式目录更新6项、镜像回退/缓存隔离/完整性校验及延迟解析10项、同步/信息/目录树/安全清理8项、`read_dataset` 18项、模型输入字典15项。受控夹具覆盖错误大小、错误哈希、首选镜像异常、镜像遍历和目录异常恢复，所有状态转换均保持正式数据与上一有效目录稳定。清理测试在隔离数据根目录中完成。

包级M01～M13矩阵使用固定注入延迟分数，在两个独立环境中分别对每个场景重复5次，共130次状态断言全部通过。矩阵验证较低延迟候选优先、有限分数排序、无延迟分数地址保留以及全部URL依次进入尝试队列；其余场景覆盖404、连接重置、镜像遍历、稳定cache、截断cache、同长度错误内容、传输截断、已有完整正式文件和同大小错误SHA-256。全部运行的`.part`残留均为0，各类异常状态下旧正式文件摘要保持一致。

完整软件包在Windows和macOS环境均顺利加载，63项测试全部通过。延迟探测与状态矩阵覆盖主机响应、探测超时、候选排序和镜像转换，验证了同一下载接口能够完整保留候选URL并执行稳健回退。

公共网络环境下，4个标签经Zenodo完成24次真实下载，全部达到登记字节数并通过SHA-256核验。不同文件规模的中位下载时间呈合理梯度，重复传输的内容摘要与目录登记值一致，展示了公共镜像、事务缓存和完整性校验协同支持稳定数据获取的能力。

中科大校园网环境下，FTP与Zenodo各完成12次同文件下载，24次结果全部达到登记字节数并通过SHA-256核验。4个文件的FTP中位下载时间为0.071～0.356 s，Zenodo为1.091～14.092 s；FTP往返延迟为1.0～13.5 ms，延迟辅助排序与实际传输表现一致。该结果展示了机构镜像与公共镜像的内容一致性，以及多镜像目录对不同访问环境的适应能力。

受控故障注入验证文件状态转换，真实镜像实验验证FTP与Zenodo的可达性、候选顺序和下载表现。校外结果展示公共镜像获取和全候选保留机制，校园网结果进一步证明机构FTP和公共Zenodo镜像能够提供内容一致的标准文件。两类实验共同表明，延迟辅助排序、全URL回退和`SIZE/SHA256`核验能够适应不同网络条件。

### 4.4 统一读取与模型初始化接口

合成NetCDF回归中，`read_dataset`的整场、周期和站点读取、经纬度边界换算及`read_LUT`兼容别名共18项全部通过；`grid_dict/grid_weather`的字段、形状、时间组织和裸土分支共15项全部通过。模型接口支持裸土标量参数组织，并以普通`Dict`提供Emerald可直接使用的气象字段。

Emerald模型集成验证覆盖参数组织、气象组织、模型初始化和60 s单步执行，5项接口断言全部通过，表明GriddingMachine输出能够直接进入模型初始化与首个时间步计算。

真实陆面案例使用2020年`gm2`的14类标准产品，全部通过文件大小、来源摘要和本地SHA-256核验。US-NR1站点被映射至相应规则格点，`grid_dict`成功组织34个模型字段、366日季节序列、4个土壤层和17个植物功能型，高程、陆地掩膜与叶面积指数均得到正确读取。撒哈拉案例准确返回非植被格点状态，表明接口能够根据陆面特征组织相应模型入口。

真实`gm2`文件顺利贯通完整性目录、统一读取和陆面参数组织接口，并覆盖植被与非植被入口。依赖统一和接口迁移后，配置测试与包集成测试全部通过，三个操作系统环境能够从同一项目声明解析一致的软件组合。2020年ERA5的8类`wd1`序列将进一步拓展从标准气象数据到模型运行的应用链路。

### 4.5 跨平台复现结果

Windows和macOS完整执行生产、分发与模型接口验证，全部测试组获得一致结果。GriddingMachine核心回归、GriddingMachineDatasets配置与集成测试、生产矩阵、直接NetCDF效率测试、多镜像状态矩阵和Emerald最小模型流程均顺利通过。跨平台结果表明，共享数据契约、事务式下载和模型就绪接口在不同桌面环境中具有稳定行为。

公共网络中的Zenodo下载和校园网中的FTP—Zenodo对照均通过完整性核验。多网络环境结果共同展示了公共镜像与机构镜像的互补价值，以及全URL回退机制对访问条件变化的适应能力。

GriddingMachine、GriddingMachineDatasets、Emerald及研究材料仓库在Windows、macOS和Linux持续集成环境中完成自动验证。统一的项目依赖、测试夹具和模型接口形成可持续复现机制，使软件更新能够持续继承本文建立的数据生产、可信分发和模型调用能力。

## 5 讨论

### 5.1 从数据集合到可维护工作流

2022版GriddingMachine建立了统一网格、变量约定和标签化数据访问[4]。当前更新进一步形成共享配置契约、显式源维度映射、与软件版本解耦的数据目录、事务式多镜像下载状态机和可回归测试的模型就绪接口。跨平台受控实验、14个真实陆面文件以及校园网FTP—Zenodo实测共同验证这些机制，持续集成进一步提供稳定的多系统复现记录。GriddingMachine由此从标准数据集合演进为连接生产、分发、读取和模型调用的数据生命周期框架。

现有结果从三个层次支撑更新：生产端形成合成数据逐点金标准矩阵、方向图复核和ELEV标准文件无损处理证据；分发端形成事务状态故障注入与真实双镜像下载证据；下游端形成统一读取回归、Emerald最小步进和真实`gm2`陆面链路证据。跨平台复现说明核心流程具有稳定的系统适应性。下一阶段将选择OISST等真实异构原始产品，贯通缩放、缺失值、坐标变换、标准NetCDF、目录登记和重新下载后的独立科学核对，进一步提升生产链的外部代表性。

### 5.2 与相关地球科学数据基础设施的关系

Earth Engine把大规模地理空间数据与云端计算结合，服务行星尺度分析[3]；ESGF通过分布式节点、搜索和联合身份基础设施支撑气候模式数据的发现与访问[9]；Pangeo倡导分析就绪、云优化数据以及计算与数据邻近的云原生模式[10]，Pangeo Forge进一步以可复用配方和目录组织分析就绪数据生产[11]。GriddingMachine与这些基础设施形成互补，面向经过选择和统一的全球规则网格产品，以及需要在本地Julia工作流中按固定标签复现参数与气象驱动的模型使用场景。

GriddingMachine的互补性体现在三个层次：以YAML保留从异构源数据到标准NetCDF的处理意图；以轻量目录连接机构镜像和通用存储；以`read_dataset`、`grid_dict`和`grid_weather`把标准数据组织为模型所需字段。Pangeo Forge侧重云端分析就绪数据生产的配方—基础设施分离[11]，本文流程侧重可直接下载的单体NetCDF、离线缓存、完整性落盘和固定模型接口。云优化分块格式适配超大规模近数据计算[10]，ESGF适配CMIP等机构联合治理[9]，GriddingMachine则服务可下载、可本地缓存的全球规则网格数据及其模型输入组织。

国内地球系统科学数据共享研究强调目录体系和规范关键词对数据管理与检索的作用[12]；Pooch以文件名、URL和SHA-256注册表实现远端文件获取、本地缓存和完整性校验[13]；STAC为广泛地理空间资产提供通用元数据结构与查询标准[14]。GriddingMachine进一步面向规则网格和模型标签，将上游生产配置、标准NetCDF、事务式多镜像落盘和下游模型字段组织置于同一可测试契约中，形成具有领域针对性的端到端整合。

### 5.3 FAIR与可复现性建设

标签和外置目录提高数据的可发现性，多URL和直接NetCDF增强获取能力，统一网格与变量约定促进互操作，来源、许可、处理记录和版本信息支撑复用[1]。FAIR4RS强调科研软件的可执行性、复合依赖、持续演化和版本管理[15]；TRUST原则进一步提出透明度、责任、用户关注、可持续性和技术能力[16]。GriddingMachine以权威文件生成`SIZE/SHA256`、下载后校验、目录事务替换和版本化依赖落实技术可复现性。正式release将继续整合镜像登记、来源许可、配置哈希、代码版本和永久归档，形成完整的软件—目录—数据溯源链。

正式release将配置哈希、代码版本、文件大小和SHA-256连接为溯源链，并将实验结果关联到可识别的软件与数据版本[8]。ELEV标准文件已经完成完整性核验、统一读取和重复无损处理，后续元数据迁移将进一步统一来源、单位和修订标签。

### 5.4 后续拓展

下一阶段将沿四条路线扩展。第一，迁移历史YAML，并为非规则网格、区域投影和复杂时间坐标增加数据源专用预处理模块。第二，将方向图复核与坐标单调性、值域和逐点数组断言进一步集成，形成统一质量报告。第三，扩大FTP与Zenodo的文件规模、观测时段和网络环境，建立延迟辅助排序与实际下载表现的长期统计。第四，将真实异构原始产品、2020年ERA5气象序列、长期模型运行和永久软件归档纳入后续版本，持续扩展科学应用与复现深度。

P01流程反馈已转化为固定输入路径和完整YAML示例；`read_dataset`的规则网格索引、植被与非植被入口以及`grid_dict/grid_weather`字段组织均形成自动回归。真实`gm2`陆面链路和Emerald最小步进为进一步开展逐字段科学核对、真实气象驱动、长期模拟和多模型适配提供了稳定接口基础。

## 6 结论

本文在2022版GriddingMachine基础上形成了由共享YAML schema、显式源维度映射、独立目录、直接NetCDF、事务式缓存及统一读取接口组成的可执行数据生命周期。跨平台合成矩阵和故障注入表明，生产变换能够稳定得到预期结果，事务状态机制能够保护正式文件；校园网内4个测试标签的FTP与Zenodo下载均通过大小和SHA-256核验，14个真实陆面文件成功生成US-NR1参数字典。

GriddingMachine由此形成面向地球系统模型的轻量数据生产与可信分发基础设施。下一阶段将以真实异构原始产品和ERA5气象驱动扩展端到端科学核对，并通过镜像登记、完整性元数据、不可变release和永久归档持续完善证据链，为全球规则网格数据维护和可复用模型输入提供长期支撑。

## 数据和代码可用性声明

GriddingMachine.jl源代码公开于https://github.com/CliMA/GriddingMachine.jl，数据生产代码公开于https://github.com/jhOo1/GriddingMachineDatasets，Emerald模型接口环境公开于https://github.com/jhOo1/Emerald-paper，实验协议、脚本和结果公开于https://github.com/jhOo1/GriddingMachine_Reaserach。各仓库提供版本化依赖与持续集成配置，投稿版本将通过正式release和永久归档保存软件、数据目录、实验结果、环境文件和绘图脚本。

## 基金项目

【待作者和通讯作者补充基金项目中文/英文名称及编号；如无资助，按期刊要求声明。】

## 作者贡献

姜皓：概念设计、软件、验证、数据整理、可视化、初稿撰写【待作者确认】。王玉杰：概念设计、研究指导、项目管理、论文审阅与修改【待作者确认】。

## 利益冲突声明

作者声明不存在利益冲突【投稿前由全体作者确认】。

## AI 工具使用声明

本文准备过程中使用OpenAI Codex辅助整理研究材料与代码差异、检查论文结构、起草和修订部分文字、审查实验脚本、汇总测试结果并辅助图件制作。研究问题、实验设计、验收标准和结论由作者确定；作者核验软件版本、实验数据、文件摘要、图件数值和正文表述，并对研究设计、数据真实性、结果解释及全文承担责任。

## 参考文献

[1] WILKINSON M D, DUMONTIER M, AALBERSBERG I J, et al. The FAIR Guiding Principles for scientific data management and stewardship[J]. Scientific Data, 2016, 3: 160018. DOI: 10.1038/sdata.2016.18.

[2] CF CONVENTIONS COMMITTEE. CF Metadata Conventions[EB/OL]. [2026-08-07]. https://cfconventions.org/.

[3] GORELICK N, HANCHER M, DIXON M, et al. Google Earth Engine: Planetary-scale geospatial analysis for everyone[J]. Remote Sensing of Environment, 2017, 202: 18-27. DOI: 10.1016/j.rse.2017.06.031.

[4] WANG Y, KÖHLER P, BRAGHIERE R K, et al. GriddingMachine, a database and software for Earth system modeling at global and regional scales[J]. Scientific Data, 2022, 9: 258. DOI: 10.1038/s41597-022-01346-x.

[5] REW R, DAVIS G. NetCDF: An interface for scientific data access[J]. IEEE Computer Graphics and Applications, 1990, 10(4): 76-82. DOI: 10.1109/38.56302.

[6] MAHECHA M D, GANS F, BRANDT G, et al. Earth system data cubes unravel global multivariate dynamics[J]. Earth System Dynamics, 2020, 11: 201-234. DOI: 10.5194/esd-11-201-2020.

[7] BEZANSON J, EDELMAN A, KARPINSKI S, et al. Julia: A fresh approach to numerical computing[J]. SIAM Review, 2017, 59(1): 65-98. DOI: 10.1137/141000671.

[8] SMITH A M, KATZ D S, NIEMEYER K E, et al. Software citation principles[J]. PeerJ Computer Science, 2016, 2: e86. DOI: 10.7717/peerj-cs.86.

[9] CINQUINI L, CRICHTON D, MATTMANN C, et al. The Earth System Grid Federation: An open infrastructure for access to distributed geospatial data[J]. Future Generation Computer Systems, 2014, 36: 400-417. DOI: 10.1016/j.future.2013.07.002.

[10] ABERNATHEY R P, AUGSPURGER T, BANIHIRWE A, et al. Cloud-native repositories for big scientific data[J]. Computing in Science & Engineering, 2021, 23(2): 26-35. DOI: 10.1109/MCSE.2021.3059437.

[11] STERN C, ABERNATHEY R, HAMMAN J, et al. Pangeo Forge: Crowdsourcing analysis-ready, cloud optimized data production[J]. Frontiers in Climate, 2022, 3: 782909. DOI: 10.3389/fclim.2021.782909.

[12] 王卷乐, 林海, 冉盈盈, 等. 面向数据共享的地球系统科学数据分类探讨[J]. 地球科学进展, 2014, 29(2): 265-274. [WANG J L, LIN H, RAN Y Y, et al. A study of Earth System Science data classification for data sharing[J]. Advances in Earth Science, 2014, 29(2): 265-274.]

[13] UIEDA L, SOLER S R, RAMPIN R, et al. Pooch: A friend to fetch your data files[J]. Journal of Open Source Software, 2020, 5(45): 1943. DOI: 10.21105/joss.01943.

[14] OPEN GEOSPATIAL CONSORTIUM. SpatioTemporal Asset Catalog (STAC) Community Standard, Version 1.1.0[S/OL]. OGC 25-004, 2025[2026-08-15]. https://www.ogc.org/standards/stac/.

[15] BARKER M, CHUE HONG N P, KATZ D S, et al. Introducing the FAIR Principles for research software[J]. Scientific Data, 2022, 9: 622. DOI: 10.1038/s41597-022-01710-x.

[16] LIN D, CRABTREE J, DILLO I, et al. The TRUST Principles for digital repositories[J]. Scientific Data, 2020, 7: 144. DOI: 10.1038/s41597-020-0486-7.
