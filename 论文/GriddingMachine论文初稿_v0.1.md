# 面向地球系统模型的全球网格数据生产与可信分发：GriddingMachine框架更新及验证

**姜皓（Hao Jiang）**^1，**王玉杰（Yujie Wang）**^1*

1. 中国科学技术大学地球和空间科学学院，安徽 合肥 230026

姜皓，E-mail：hao.jiang@mail.ustc.edu.cn；ORCID：https://orcid.org/0009-0009-8295-8661

\* 通讯作者：王玉杰，wyujie@ustc.edu.cn

## 摘要

全球网格数据的源维度、坐标方向、缩放、缺失值和分发位置不一致，制约地球系统模型输入的可重复生产与稳定获取。本文在2022版GriddingMachine基础上构建可验证的数据生命周期：共享模式（schema）约束YAML配置、源维度映射和标准NetCDF生产；独立目录登记逻辑路径、多个镜像及文件完整性元数据；事务式下载以隔离缓存和`SIZE/SHA256`核验保护正式文件；统一读取和模型就绪接口组织下游输入。二维/三维合成矩阵在Windows与macOS各连续3轮通过，13类故障在两平台共130次状态断言中均未污染正式文件。校园网内4个测试标签经FTP和Zenodo共24次下载均通过大小和摘要核验；两个内部压缩样本采用直接NetCDF后暖缓存端到端中位时间在两平台均降低；14个真实陆面文件能够生成US-NR1参数字典，非植被格点按预期拒绝。结果表明，共享生产契约能够正确执行受控维度和数值变换，事务式下载能够在镜像及内容故障下保持正式文件状态，标准陆面数据能够进入模型输入组织。当前证据尚不覆盖真实异构原始产品的完整生产链、真实气象驱动或非Julia接口。该框架为全球规则网格数据的持续生产、可信分发与模型就绪访问提供了可执行工作流。

**关键词：** 地球系统模型；全球网格数据；数据生命周期；NetCDF；可信分发；数据完整性

**English title:** Production and Trustworthy Distribution of Global Gridded Data for Earth System Models: An Updated and Validated GriddingMachine Framework

**Authors:** Hao Jiang^1, Yujie Wang^1*

1. School of Earth and Space Sciences, University of Science and Technology of China, Hefei 230026, China

Hao Jiang, E-mail: hao.jiang@mail.ustc.edu.cn; ORCID: https://orcid.org/0009-0009-8295-8661

\* Corresponding author: Yujie Wang, wyujie@ustc.edu.cn

## Abstract

Differences in source dimensions, coordinate orientation, scaling, missing values, and hosting locations hinder the reproducible production and reliable acquisition of global gridded inputs for Earth system models. Building on the 2022 GriddingMachine release, this study develops a verifiable data lifecycle. A shared schema constrains YAML configuration, source-dimension mapping, and standardized NetCDF production; an independent catalog records logical paths, multiple mirrors, and file-integrity metadata; transactional downloads protect formal files through isolated cache files and `SIZE/SHA256` checks; and unified reading and model-ready interfaces organize downstream inputs. A two- and three-dimensional synthetic matrix passed three consecutive runs on both Windows and macOS. Across 13 injected failure classes, all 130 state assertions confirmed that invalid downloads did not contaminate formal files. On the campus network, 24 FTP and Zenodo downloads of four test tags all matched the registered sizes and digests. Direct NetCDF reduced median warm-cache end-to-end time on both platforms for two internally compressed samples. Fourteen verified land files produced a parameter dictionary for US-NR1, while a non-vegetated grid cell was rejected as expected. The results show that the shared production contract correctly performs controlled dimension and numerical transformations, transactional downloads preserve formal-file state under mirror and content failures, and standardized land data can enter model-input organization. Current evidence does not cover a complete production chain from a real heterogeneous raw product, real-weather forcing, or updated non-Julia interfaces. The framework provides an executable workflow for maintaining, reliably distributing, and accessing model-ready global regular-grid data.

**Keywords:** Earth system modeling; global gridded data; data lifecycle; NetCDF; trustworthy distribution; data integrity

## 1 引言

地球系统模型正在以更高的空间分辨率和更精细的过程表达描述陆地、大气、海洋及其相互作用。模型复杂度的提升使参数化、初始条件、边界条件、气象驱动和结果评估越来越依赖多源全球网格数据。此类数据通常由不同研究团队和业务机构生产，在文件格式、空间投影、维度顺序、经纬度方向、时间组织、单位、缩放方式、缺失值表示和元数据完整性等方面存在差异。研究人员因此不仅需要寻找数据，还需要反复完成下载、重投影、重排、缩放、质量检查和模型接口适配。数据“可以获得”并不等同于能够被模型稳定、正确且可重复地使用。

科学数据管理正在由单纯的数据公开转向强调可发现、可获取、可互操作和可复用的 FAIR 原则[1]。NetCDF 具有自描述、跨平台和适合多维数组等特点，已广泛用于地球科学数据交换；CF 元数据约定进一步通过坐标、物理量、单位和时空属性描述促进不同数据源之间的解释与处理[2]。Google Earth Engine 等云平台显著提升了大尺度遥感数据的访问和分析能力[3]。然而，对于尚未进入统一云平台、保存在不同机构服务器或研究团队本地的数据，特别是需要离线使用、版本固定或直接进入地球系统模型的数据，研究人员仍然面临格式不一致、分发位置分散、目录更新与软件版本耦合以及模型输入转换重复等问题。

王玉杰等[4]于2022年提出GriddingMachine，将常用于陆面和地球系统模拟的全球数据处理为具有统一空间和变量约定的NetCDF文件，并通过标签、`Artifacts.toml`和Julia artifact机制实现数据管理和自动下载，同时提供Julia、MATLAB、Octave、Python和R接口。旧版目录已经记录SHA-1、SHA-256和一个或多个下载URL，数据标准也已规定经纬度方向、空间分辨率、变量名称、缺失值、单位、引用信息和处理日志。因此，哈希、多个URL、标准NetCDF和标签本身不是本文新增贡献。尚待解决的问题是：数据源专用处理如何提升为共享且可测试的生产契约，目录如何脱离软件版本演化，直接NetCDF下载如何在失败时隔离不完整文件，以及标准数据如何以可回归的接口进入模型输入组织。旧版采用`tar.gz`作为分发单元且目录随软件发布更新，正为这些生命周期更新提供了明确基线。

从相关技术体系看，NetCDF以维度、变量和属性构成机器无关的多维科学数据抽象[5]，地球系统数据立方体则强调对多变量时空数据的共同组织和分析[6]；Julia通过多重派发和专业化兼顾高层抽象与科学计算性能[7]。与此同时，软件引用原则要求科研软件具有可识别、可持续、可访问和可归属的版本记录[8]。这些工作分别解决文件表达、多变量分析、计算实现和软件引用问题，但不能自动形成“异构数据生产—多镜像分发—完整性验证—模型输入组织”的领域闭环，这正是本文验证的系统边界。

针对上述问题，本研究围绕2022版的实际使用需求更新GriddingMachine，并将创新重点置于可执行的数据生命周期契约。在数据生产端，配置模板与`YamlBuilder`辅助贡献者生成YAML，通用流水线依据配置完成源维度映射、坐标和数值处理、质量检查及标准NetCDF输出；在分发端，以可直接读取的NetCDF替代二次压缩制品，通过独立目录登记机构FTP、Zenodo及其他社区镜像，并对已登记`SIZE/SHA256`的条目在cache下载后执行严格完整性核验；在数据使用端，以`read_dataset`统一读取，再通过`grid_dict`和`grid_weather`组织Emerald初始化数据。本文以Julia主路径系统呈现新版目录、下载状态机和模型接口的协同更新。

本文拟回答三个问题：共享YAML契约与生产流水线能否正确处理代表性的二维/三维维度、坐标和数值变换；独立目录、直接NetCDF、镜像回退及事务式缓存能否在受控故障和真实网络条件下保持下载内容与正式目录状态正确；统一读取和模型就绪接口能否在受控夹具及真实陆面文件上得到符合约定的结果。直接NetCDF效率对比为数据制品优化提供量化支持。Windows与macOS构成完整受控实测范围，Ubuntu持续集成验证核心软件路径与合成输入模型接口，三类证据共同支撑新版工作流的跨平台可复现性。

## 2 新版架构与关键方法

### 2.1 总体架构与数据生命周期

GriddingMachine 新版由数据生产、目录与分发、数据使用三个相互衔接的部分组成（图1）。数据生产端由 `GriddingMachineDatasets` 承担，负责把来源、结构和数值约定不同的地学数据转换为满足 GriddingMachine 规范的 NetCDF 产品；目录与分发部分负责保存标准数据产品、维护标签与镜像地址之间的映射，并使数据目录能够独立于 `GriddingMachine.jl` 软件包版本更新；数据使用端由 `GriddingMachine.jl` 承担，负责数据发现、下载、落盘、读取以及向地球系统模型提供参数和气象驱动。三部分共同形成“生产—质控—发布—发现—下载—读取—模型调用”的数据生命周期。

![图1 GriddingMachine全球网格数据生产、分发与模型调用框架](figures/图1_GriddingMachine总体架构.svg)

**图1 GriddingMachine从2022版到新版的数据工作流与关键优化** （a）2022版以数据集专用脚本、`tar.gz`制品、包内目录和`read_LUT`为主要路径；（b）新版形成“共享YAML契约—标准化与质控—直接NetCDF制品—独立数据目录—安全获取—统一读取与模型调用”的端到端流程；（c）O1—O5分别表示统一数据契约、简化数据制品、目录独立演化、事务式下载和模型就绪接口。蓝色实线、橙色虚线和灰色分别表示新版核心路径、版本间改进映射和2022版基线。

**Fig. 1 Data workflow and key optimizations from the 2022 release to the updated GriddingMachine.** (a) The 2022 baseline used dataset-specific scripts, `tar.gz` artifacts, an in-package catalog, and `read_LUT`. (b) The updated end-to-end workflow links a shared YAML contract, standardization and quality control, direct NetCDF products, an independent catalog, verified acquisition, and unified model-ready access. (c) O1--O5 denote the unified data contract, simplified artifacts, independently evolving catalog, transactional downloads, and model-ready interfaces, respectively. Blue solid lines, orange dashed lines, and gray elements indicate the updated workflow, cross-version changes, and the 2022 baseline.

在生产端，原始数据及其处理规则分别作为数据输入和 YAML 配置输入。论文版本使用共享 schema 描述原始文件组合、源变量、经纬度方向、源维度语义、数值变换、有效范围、缺失值处理及输出元数据；配置构建器与处理流水线调用同一校验函数。`process_dataset!` 根据配置枚举输入，依次完成读取、验证和保存，最终生成以统一标签命名的 `TAG.nc`。生产过程中的质量控制同时包括可自动断言的配置、维度与数值检查，以及用于补充确认空间方向的图形复核；人工复核不替代程序化验证。

通过质量控制的数据产品可发布到机构 FTP、HTTP(S) 服务或 Zenodo 等公共存储位置。一个标签可以对应多个镜像地址；论文版本在 `Artifacts.yaml` 中登记相对路径、URL、文件字节数和 SHA-256。`GriddingMachineDatasets` 的目录生成函数仅从本地文件计算这些字段并事务式写入本地 YAML，不承担网站上传或远程记录管理。目录与 `GriddingMachine.jl` 分开维护，使数据列表能够独立更新。

在数据使用端，Collector的`configure!`显式设置本地根目录与目录来源，包加载不再自动访问网络。目录下载先进入临时文件，经schema校验后替换正式目录，并保留上一有效目录；`download_dataset!`提取各URL的主机名，在Windows上用`ping`平均往返延迟辅助排序，而在macOS和Linux上无法取得该分数时仍保留并依次尝试全部URL。每次调用创建独立`.part`文件；目录同时登记`SIZE`和`SHA256`时，文件只有通过两项核验才进入`public`，否则清理本次缓存并尝试下一镜像。为兼容历史目录，缺少完整性字段的条目在默认非严格模式下仍可下载，这类文件不属于本文的“完整性已验证”集合。Indexer通过`read_dataset`提供整场、指定周期及站点读取，`grid_dict`和`grid_weather`则组织Emerald所需参数和气象驱动。论文版本已完成固定夹具下的接口回归、Emerald合成输入最小初始化及60 s单步烟雾验证，并完成`gm2`真实陆面链路预实验；真实`wd1`气象链路未执行，因此模型接口仅作为下游应用证据。

该生命周期形成持续演化的闭环。模型使用过程中形成的数据校正、元数据完善和新增数据需求可以反馈至YAML配置、质量控制和版本登记环节，持续提升数据产品及其生产流程。本文围绕本地数据生产、可靠分发、统一读取和模型接口评价这一闭环的完整性与可复现性。

表1概括2022版与当前论文版本的主要差异，并明确已实现机制与仍需外部实验验证的边界。

**表1 2022版与当前论文版本的功能和技术路线比较**

| 环节 | 2022版 | 当前论文版本 | 当前边界 |
|---|---|---|---|
| 分发单元 | NetCDF的`tar.gz` artifact | 可直接读取的`.nc` | 两类内部压缩文件的Windows与macOS支持实验已完成 |
| 数据目录 | 软件内置`Artifacts.toml` | 外置`Artifacts.yaml`；schema校验、临时替换和上一版本备份 | 默认入口仍需解析Zenodo落地页 |
| 下载 | artifact哈希寻址、多个URL和解包 | Windows `ping`辅助排序；全平台多URL回退、独立缓存及`SIZE/SHA256`校验后落盘 | 受控故障矩阵通过；4项校园网双镜像实测 |
| 读取 | `read_LUT` | `read_dataset`，旧名称保留为别名 | 假设全球规则经纬网，不插值 |
| 模型组织 | 标准化数据和通用读取 | `grid_dict`与`grid_weather` | 仅支持固定标签组合 |
| 数据生产 | 数据源专用处理及贡献流程 | 共享YAML schema、配置构建器及显式源维度映射 | 自动矩阵、单人方向审核和1例受控贡献流程已完成 |
| 语言接口 | Julia、MATLAB、Octave、Python和R | 新版目录与接口实现集中于Julia | 非Julia接口未在本文重新验证 |

**Table 1 Comparison between the 2022 release and the current manuscript version of GriddingMachine.** The table distinguishes implemented behavior from enhancements that still require implementation and validation. A field-level comparison is provided in the supplementary manuscript materials.

### 2.2 数据标准与 YAML 驱动的生产流程

#### 2.2.1 标准 NetCDF 数据模型

GriddingMachine 以 NetCDF 作为标准数据格式，原因是该格式能够在同一文件中保存多维数组、坐标和自描述元数据，并被多种地球科学软件读取。2022 年版本已经规定数据采用二维或三维规则经纬网，前两维依次为经度和纬度，可选第三维表示周期；经度自西向东、纬度自南向北，数据不保留未说明的缩放，缺失值在读取后统一表示为 `NaN`，主变量和不确定性变量分别命名为 `data` 和 `std`[4]。新版延续这些核心约定，并将维度映射、溯源信息、处理配置和分发完整性纳入可机器检查的规范（表2）。

**表2 GriddingMachine 标准 NetCDF 数据与元数据规范**

| 类别 | 论文实验版本要求 | 验收重点 |
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
| 分发完整性 | 正式发布条目记录文件字节数和SHA-256；同一标签各镜像内容相同 | 下载后校验；失败文件不能进入正式目录 |

**Table 2 Standardized NetCDF data and metadata requirements of GriddingMachine.** Each requirement is evaluated by automated tests against the frozen experimental release. A detailed working table, including field-level checks, is maintained with the manuscript materials.

本文将仓库文件`test/preparation/griddingmachine-v04/catergory.txt`（原文件名拼写）作为产品数值与缺失值处理的功能验收依据。该文件把产品类别映射为常数填补、`nanmean`、陆地不得为`NaN`、全域不得为`NaN`、保持原值或整数化等策略；验收针对当前标准产品是否满足所属类别规则，不要求证明该文件与2022年某次生产使用了完全相同的原始输入。以ELEV为例，其规则为“陆地不得为`NaN`”；本次文件全域无`NaN`，因而满足更强条件。

CF 约定不强制固定维度顺序，而是利用坐标变量和属性表达数据含义[2]。GriddingMachine 固定输出维度顺序以降低下游接口复杂度，但生产端不能假设源数据已经采用该顺序。论文版本通过 YAML 的 `DIMENSIONS` 显式记录源变量各维度语义，并由 `standardize_dimension_order` 将 `(lat, lon)`、`(ind, lat, lon)` 等排列重排为统一输出；经纬度翻转与循环平移则结合坐标值和位置编码数组验证。非规则网格、区域投影或不能无损映射到规则经纬网的数据必须明确拒绝或进入数据源专用预处理，不能静默生成看似合规的文件。

#### 2.2.2 YAML 配置结构

YAML 将数据源差异与通用处理代码分离。当前配置由四类顶层字段组成：`FILE` 描述文件命名模式及 `PREFIX`、空间分辨率 `NX`、时间分辨率 `MT`、可选年份 `YYYY` 和数据版本 `VV`；`FOLDER` 指定原始数据与标准化数据目录；`DATA` 及可选的 `STD` 描述源变量名称、单位、缩放、有效范围、经纬度变换、缺失值策略和处理日志；`GRIDDINGMACHINE` 定义标签及可选修订号。一个配置可以包含多组前缀、分辨率、时间尺度、年份和版本，流水线对其笛卡尔组合逐项生成目标文件。

为避免配置错误在长流程末端才暴露，论文版本加入 `SCHEMA_VERSION` 并在读取数据前进行结构校验。字段分为必需项、具有明确默认值的可选项和互斥项，数组长度必须与变量前缀一一对应；`DIMENSIONS`、坐标变换、缺失值策略和输出属性由共享 schema 约束。旧版 `TARBALL` 已从生产配置及配置构建器输出移除，缺省 `GAPFILL` 被规范化为 `KEEP_AS_IS`。当前自动测试覆盖合法最小配置、旧配置规范化、非法字段、数组长度和维度映射，但来源、许可、引用和输出 NetCDF 的完整溯源属性仍需继续约束。

#### 2.2.3 最小YAML配置示例

P01受控贡献流程使用一个二维非对称夹具验证配置与处理操作的对应关系。源变量采用`(lat,lon)`顺序，纬度由北向南、经度范围为`0～360°`；配置中的关键映射为`DIMENSIONS: source: [lat, lon]`，并声明纬度翻转、经度半球转换和线性变换`2x+1`。处理后得到标准`(lon,lat)`顺序的`CONTRIB_SRC_2X_1Y_V1.nc`，逐点结果与独立金标准一致。完整YAML、字段字典、命令和目录说明保存在贡献实验手册中，正文不再重复软件使用指南。来源、许可、引用和复杂时间坐标仍须由真实数据配置完整记录。

#### 2.2.4 配置构建器与共享schema

`GriddingMachineDatasets`仓库中的`YamlBuilder`接收文件命名、变量标签、分辨率、时间尺度、版本、输入输出目录、单位、数值范围、缩放、坐标方向和GriddingMachine标签等结构化输入，并生成YAML配置。其目的在于减少手工编辑时的拼写、缩进和字段遗漏。当前论文版本没有可供评价的独立客户端，因此本文只验证配置构建逻辑，不讨论图形界面或浏览器交互可用性。

`YamlBuilder`与处理流水线调用同一schema；其输出不再包含`TARBALL`，并补入`SCHEMA_VERSION`、`GAPFILL`与`DIMENSIONS`，输出位置由调用者提供而非固定服务器路径。契约测试证明构建器生成的合法配置可直接交给`process_dataset!`，非法字段则在读取源数据前被拒绝。框1和版本化指南承担面向贡献者的示例作用；未来若开发独立客户端，应另行开展端到端交互和可用性验证。

#### 2.2.5 数据处理顺序与可追溯输出

`process_dataset!` 首先根据 `FILE` 和 `FOLDER` 定位输入与输出文件，再读取 `DATA` 和可选 `STD` 指定的源变量。当前流水线将数据转换为 `Float32`，依次执行纬度翻转、经度翻转或从 `0～360°` 到 `-180～180°` 的循环平移、线性缩放、有效范围过滤和缺失值处理。处理顺序本身是结果可复现的一部分，因而不能只保存最终数组；每项实际执行的转换都应写入 `history`，并将完整 YAML、配置 SHA-256 和生产代码版本与输出关联。

论文实验版本的自动质量控制在保存前检查维度、坐标、变量、数值范围和缺失值规则。当前已有的空间方向图可用于人工发现异常，但只作为补充审核；流水线的正确性主要由具有已知预期输出的合成NetCDF自动断言。验证通过后生成`data`，存在不确定性时追加同形的`std`，并按`TAG_(PREFIX_)NX_MT_(YYYY_)VV(_REVISION)`生成唯一文件名。当前实现发现同名目标文件时仅依据文件存在性跳过，本研究把该行为纳入重复调用测试，但不把它解释为内容级断点续跑；需要强制重建时应先移走或删除受控输出，未来版本应增加配置哈希、软件版本和文件校验结果比较。

### 2.3 数据质量检查与目录登记

#### 2.3.1 处理过程中的方向验证

当前生产流水线在 `read_input` 完成经纬度翻转、经度范围调整、线性缩放、有效范围过滤和缺失值处理后，调用 `verify_data!` 对待保存数组进行方向检查。该函数把数组写入调用者指定或默认的NetCDF缓存文件，Python脚本依据变量维度名重排为`(lat,lon)`后生成带经纬度坐标轴的图件；二维数据输出PNG，三维数据沿`ind`维输出GIF。操作者查看图件后在终端输入`Y/y`表示通过，其他输入表示拒绝。YAML中的`VERIFY_ONCE`用于控制同一配置组合是否只在第一次处理时确认，通过状态只存在于该次处理使用的配置副本中。

这一过程主要用于识别南北颠倒、东西颠倒或经度平移错误，属于交互式补充检查。为形成可复核证据，本文另提供V01/V02审核脚本：V01给出方向正确的非对称位置编码图，检查者应接受；V02把同一数组南北反转，检查者应拒绝。脚本将图件、检查者标识、时间、两次选择、总体结果和代码提交写入独立目录。一名操作者已完成该流程并得到PASS；本文只据此说明审核步骤可以执行，不称其为独立用户研究，人工判断也不替代自动坐标、结构与逐点数值断言。

#### 2.3.2 标准文件检查

对于已经生成的 NetCDF 文件，`verify_processed_data!` 提供独立的结构和数值检查。该函数首先确认文件存在，并要求覆盖类型为全球陆地和海洋（`both`）或陆地（`land`）。随后检查 `lon`、`lat` 维度和坐标变量、主变量 `data`，当文件具有三个及以上维度时进一步要求 `ind`；同时比较 `data` 各维长度与 `lon`、`lat` 和 `ind` 长度是否一致。数值检查读取完整的 `data` 数组，计算忽略 `NaN` 后的最小值和最大值，并判断其是否位于给定范围内。

缺失值检查取决于覆盖类型。`both` 要求整个数组不存在 `NaN`；`land` 在经度长度为360、720或1 440时读取并重采样 `LM_4X_1Y_V1` 陆地掩膜，逐层检查陆地区域是否含 `NaN`。其他空间分辨率下，代码给出警告并跳过陆地缺失值检查。当前函数尚未检查经纬度坐标的实际取值和单调方向，也未检查 `std`、单位、引用信息和处理日志；这些边界将在验证实验中明确报告。

#### 2.3.3 标签生成与数据目录登记

数据文件名由 `griddingmachine_tag` 生成，基本形式为 `TAG_(PREFIX_)NX_MT_(YYYY_)VV(_REVISION)`。其中 `NX` 表示空间分辨率，`MT` 表示时间分辨率，`YYYY` 和 `REVISION` 为可选部分。生成输出路径时，代码读取当前 `Artifacts.yaml`，如果拟生成标签已经存在则触发断言，从而避免直接产生同名数据文件。

数据发布与目录登记被有意分开。维护者先在 Zenodo、机构 FTP 或其他存储中完成显式发布，再把本地标准 NetCDF 路径和公开 URL 交给 `update_yaml_library!`。该函数调用 `build_catalog_entry` 读取本地文件，生成 `PATH`、去重后的 `URL`、`SIZE` 和 `SHA256`，按标签排序后通过临时文件替换本地 `Artifacts.yaml`。它不抓取网页、不内置服务器地址，也不执行上传、删除或远程记录修改，因此本文称其为“可校验目录生成器”，而不是自动发布系统。

目录生成器的单元测试使用临时文件核对字节数和 SHA-256，并验证写回后的 YAML 值；下载端再以相同字段验证实际内容，从而形成“本地标准文件—目录条目—下载文件”的最小完整性链。现存 `verify_urls!` 仍只能作为旧目录地址抽查工具，不能证明全部历史标签可访问或既有多个 URL 内容一致；因此，历史目录迁移必须重新从权威本地文件生成 `SIZE/SHA256`，不能仅凭 URL 可访问性补写哈希。

#### 2.3.4 数据贡献与发布流程

一个新数据集进入GriddingMachine依次经历：准备原始文件；通过模板或配置构建器生成YAML；运行`process_dataset!`；检查维度、坐标、变量、数值范围、缺失值和方向图；将标准NetCDF至少上传至一个外部可访问位置，并按条件增加机构镜像；把标签、逻辑路径、URL、文件大小和SHA-256写入`Artifacts.yaml`；发布目录新版本；最后从`GriddingMachine.jl`执行目录更新、下载和读取。机构FTP可以提高校内访问速度，Zenodo或其他公共存储保证校外可用；其他维护者也可在目录条目中增加内容相同的镜像。

这一流程既是维护文档，也是需要验证的软件接口。本文使用1名未参与相关代码开发的参与者，依据冻结说明处理一个受控数据集并完成模拟登记。实验只判断该案例能否完成、在哪些环节需要口头干预以及最终NetCDF和目录项是否正确，不把单案例结果外推为一般可用性结论。发现的问题用于修订补充材料或项目网站中的逐步指南。

### 2.4 动态目录与多镜像分发

#### 2.4.1 本地目录初始化与加载

`GriddingMachine.jl` 通过 Collector 管理目录和本地文件。`configure!` 可从参数或环境变量设置数据根目录、目录 URL 和本地目录文件；`cache` 保存下载临时文件，`public` 按条目中的 `PATH` 保存正式 NetCDF。模块初始化只设置配置并清空内存状态，不创建目录、不读取目录且不访问网络；只有显式调用初始化、加载、更新或下载时才发生对应 I/O。

目录条目以数据标签为键，必需字段为安全相对路径 `PATH` 和至少一个 `URL`，可选完整性字段为正整数字节数 `SIZE` 与64位十六进制 `SHA256`。加载时对标签字符、路径穿越、URL 协议和完整性字段执行 schema 校验，并提供路径、URL、信息和本地状态查询。可配置根目录与无网络导入使测试和离线使用能够与开发者真实数据目录隔离。

#### 2.4.2 数据目录更新

`update_database!` 调用 `download_database!` 获取目录，验证后再加载为内存状态。调用者可直接提供 YAML 文件 URL，也可使用 Zenodo 落地页；后者仍通过页面中的 `Artifacts.yaml` 链接解析实际下载地址。目录先写入同目录临时文件，解析根节点并执行 schema 校验；通过后备份当前目录为 `Artifacts.previous.yaml`，再替换正式文件。

该机制实现了目录与软件版本分离，并避免损坏 YAML 直接覆盖上一有效目录；替换失败时使用备份恢复。当前局限是默认 Zenodo 入口仍依赖落地页链接结构，而非结构化 API；备份也只有一个上一版本，不能替代远程版本归档。

#### 2.4.3 多镜像排序与失败回退

`download_dataset!`接收数据标签；标签不存在时可显式选择刷新目录，正式文件已存在且通过已登记完整性检查时直接返回。需要下载时，函数从每个FTP或HTTP(S) URL提取主机名，在Windows调用两次限时`ping`并按平均往返延迟从小到大排序；没有得到有效响应的地址以`Inf`排在末尾，但仍保留在下载尝试队列中。

下载循环按排序结果逐一尝试镜像，每次尝试均写入进程级唯一`.part`文件。对于同时登记`SIZE`和`SHA256`的条目，程序检查文件是否生成、字节数及摘要是否一致；任一条件失败即删除本次临时文件并尝试下一URL。`require_integrity=true`还会拒绝缺失完整性字段的目录项。当前默认值为`false`以兼容历史目录，因此未登记两字段的文件只能称为“已下载”，不能称为“已通过内容完整性核验”。全部镜像失败时抛出汇总错误，不触碰已有正式文件。

`ping`只测量主机ICMP往返延迟，不等于FTP或HTTPS的连接时间、吞吐率和完整文件下载时间；服务器也可能允许文件访问但禁用ICMP。因此本文只称其为“基于ping延迟的候选顺序”，不声称选择吞吐率最优镜像。机构FTP只在中科大校园网可访问，真实FTP—Zenodo实验必须在校园网对同一文件分别进行只读下载，并以`SIZE/SHA256`确认内容一致。

#### 2.4.4 缓存落盘与批量同步

每次下载使用`cache/.<TAG>.<PID>.part`；具备完整性字段的条目在校验成功后移动到正式路径，历史兼容条目则遵循非严格模式。`sync_database!`在更新目录后遍历标签并复用相同下载逻辑。论文测试仅同步临时fixture，不运行超过100 GB的完整历史目录。

本地回归已覆盖首选镜像失败、错误字节数、错误SHA-256、残留缓存及全部失败等受控分支，并断言失败内容不进入正式目录。Windows与macOS分别完成65次包级故障状态断言；Ubuntu CI使用小型确定性NetCDF夹具完成相同的65次状态断言。真实FTP与Zenodo可达性仍按网络环境单独报告，不由受控HTTP端点替代。

#### 2.4.5 Collector公共操作

除单标签下载外，Collector还提供目录更新、全库同步、旧数据或指定标签清理、目录树和数据集信息查询等操作。师生讨论将这些操作视为新版维护逻辑的一部分，因此不能只测试`download_dataset!`。当前`clean_database!("all")`清空所配置根目录下的`public`内容，按标签清理删除相应缓存和正式文件；`clean_database!("old")`默认加载当前有效目录，也可由`update=true`先刷新目录，然后删除本地`public`中已不再登记的数据集。清理函数仅允许作用于经过配置和路径检查的托管数据目录。`sync_database!`会顺序遍历整个目录，完整运行可能涉及超过100 GB数据。论文测试使用隔离的临时数据根目录和小型目录夹具，逐项断言目录与文件状态，不在开发者真实数据目录上执行破坏性测试。全库实际迁移只作为运维功能说明，不作为论文实验的必要条件。

### 2.5 统一读取与模型接口

#### 2.5.1 `read_dataset` 统一读取接口

Indexer模块以`read_dataset`统一本地NetCDF路径和目录标签的读取，支持整场数组、指定周期切片、站点全部周期以及站点指定周期4种调用。目录标签在本地缺失时交由Collector下载；旧名称`read_LUT`保留为兼容别名。默认读取`data`，调用者也可显式请求`raw_data`或`std`。读取层不再次修改单位、缺失值或物理范围，从而避免把生产规则隐式重复到使用端。

站点读取依据全球规则经纬网分辨率把经纬度映射为数组索引，因此依赖标准文件采用`(lon,lat[,ind])`顺序及西向东、南向北排列。当前接口不插值，也不适用于区域投影和非规则网格；周期索引的月份、日期或小时含义由对应产品元数据解释。这些约束说明统一读取建立在第2.2节数据契约之上，而不是任意NetCDF的通用读取器。

#### 2.5.2 `grid_dict` 陆地模型参数组织

`grid_dict`把`gm1`或`gm2`标签组中的土壤、冠层、叶片、地形、陆地掩膜和植物功能型产品组织为单个格点的模型参数字典。年份用于选择叶面积指数并组织逐日序列。函数先检查陆地掩膜和叶面积指数；对植被格点读取各类参数、处理季节序列并依据内置参数表形成Emerald所需字段，对不满足入口条件的格点给出明确错误。

输出包括位置、分辨率、年份、CO₂、土壤水力参数、冠层结构、植物功能型比例、叶片生物物理和光合参数；启用验证时拒绝含未处理`NaN`的结果。该接口的贡献是把多个已标准化产品稳定组织为模型入口，而不是提出新的参数化方案。内置经验系数、标签组合及不同入口的非植被处理差异因此作为适用边界，在第5.4节讨论。

#### 2.5.3 `grid_weather` 气象驱动组织

`grid_weather`按年份和格点读取`wd1`中的8个ERA5标签，分别组织地表气压、降水、漫射与直射短波辐射、长波辐射、气温、水汽压亏缺和风速。输出统一为含时间索引`FDOY`及8个气象字段的字典，并在启用验证时拒绝未处理的`NaN`。接口既可直接按经纬度读取，也可从已经加载的全局气象数组提取格点序列。

该接口完成固定标签组合的读取与字段组织，不是通用模型耦合层；它依赖规则网格、既定单位和`wd1`标签。本文以合成气象夹具验证字段、形状和Emerald最小步进，以真实`gm2`文件补充陆面链路，不把尚未运行的真实ERA5链路表述为已经验证。

### 2.6 最小数据获取与模型输入示例

与2022版通过标签隐藏数据位置的思路一致[4]，新版仍让使用者以标签而不是远端URL调用数据，但目录更新、下载完整性和读取被拆分为可单独检查的步骤。框2展示跨平台的最小使用路径：显式设置本地数据根目录，更新目录，下载并强制要求完整性字段，再读取US-NR1附近格点；当`gm2`所需文件已经存在或可下载时，可进一步生成2020年陆面参数字典。本文真实陆面实验使用的就是相同公共接口，但实验脚本额外记录代码版本、文件哈希和网络请求数。

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

数据生产正确性测试用于回答 YAML 驱动流程能否按照配置完成数组变换并生成结构一致的 NetCDF。测试对象固定为正式实验所使用的 `GriddingMachineDatasets` commit，不使用当前工作目录状态代替版本号。全部输入在临时目录内生成，以位置编码数组作为金标准：二维数组中每个格点由经纬度索引共同编码，三维数组再加入周期索引，使维度交换、方向翻转、经度平移和周期错位能够通过逐点比较识别。

测试分为当前支持行为和边界行为两类。支持行为包括标准 `(lon,lat)` 与 `(lon,lat,ind)` 输入、纬度/经度翻转、`0～360°`经度平移、线性缩放、范围过滤、各类缺失值处理、`data/std`保存和标签生成。边界行为包括 `(lat,lon)`、`(ind,lat,lon)`等非标准维度顺序、缺少必需字段、变量标签数量不一致、未知`GAPFILL`以及目标文件已存在等情况。边界案例不预设当前代码能够处理；评价重点是其产生正确结果、明确拒绝，还是静默生成错误文件。

#### 3.1.2 测试矩阵

表3将案例分为维度（D）、坐标（C）、数值（N）、缺失值（G）、YAML配置（Y）、输出（O）和人工验证（V）7组。详细工作表共定义31个案例，并分别记录正确行为和基于`wyujie@51cf0fe`静态代码得到的基线预期。正式论文只填写冻结版本的实测结果，基线预期不作为结果。

**表3 GriddingMachineDatasets 合成 NetCDF 测试矩阵（正文摘要）**

| 组别 | 案例数 | 主要组合 | 核心断言 |
|---|---:|---|---|
| D 维度 | 5 | 2D/3D标准顺序、`(lat,lon)`、`(ind,lat,lon)`、非支持维度 | 输出形状、维度名及逐点位置 |
| C 坐标 | 4 | 纬度翻转、经度翻转、`0～360°`平移、组合变换 | 坐标方向及位置编码值 |
| N 数值 | 4 | Float32、线性缩放、有效范围、有/无缩放 | 最大绝对和相对误差、NaN掩膜 |
| G 缺失值 | 8 | 常数、均值、保留、无陆地NaN、无NaN、整数化和错误方法 | 修改位置、填充值、日志和返回值 |
| Y 配置 | 4 | 最小配置、缺`GAPFILL`、构建器生成配置、数组长度不一致 | 成功输出或明确异常 |
| O 输出 | 4 | `data`、`std`、已有文件、标签冲突 | 变量、属性、跳过策略和唯一性 |
| V 人工检查 | 2 | 接受或拒绝方向图 | 是否保存及临时验证状态 |

**Table 3 Synthetic NetCDF test matrix for GriddingMachineDatasets.** The matrix evaluates dimensions, coordinates, numerical transformations, missing-value handling, YAML configurations, output files, and interactive orientation checks. Detailed fixtures and expected outcomes are fixed before code changes; only measurements from the frozen release will be reported as results.

#### 3.1.3 指标与通过标准

每个案例记录结构检查、数值检查和异常检查结果。结构通过要求输出变量、维度、形状和属性与预期一致；数值通过要求逐点结果与金标准一致，Float32转换按预先固定的绝对和相对容差判断；预期失败通过要求函数产生指定类型和阶段的错误，且不留下可被当作正式数据使用的输出。另记录最大绝对误差、最大相对误差、处理日志和重复运行一致性。

正式实验在Windows与macOS两个环境分别执行，全部非交互测试在每个环境独立运行至少3次。论文声称支持的案例必须达到100%的结构和数值通过率；暂不支持的案例必须稳定拒绝，不能静默产生错误结果。人工方向图由实际操作者判断并保存审核记录，但不计入自动正确率。Windows和Julia 1.12.6环境的31编号矩阵已完成3次独立冻结运行，每次29个非交互案例全部通过；同一矩阵脚本（仅输出文件名随平台区分）在macOS/Julia 1.12.6上也完成3次独立运行，每次29个非交互案例全部通过，网络请求数均为0；HJ操作者完成V01接受和V02拒绝，总体结果为PASS。本文准确报告一名操作者，不据此声称一般用户可用性。

#### 3.1.4 YAML配置契约与贡献流程复现

配置契约测试向`YamlBuilder`提供最小二维数据、含`std`的三维数据、纬度/经度需变换的数据及字段非法数据，检查生成结果是否满足同一YAML schema，并把合法配置直接交给`process_dataset!`。通过要求是合法输入无需人工补字段即可得到金标准NetCDF，非法输入在启动处理前给出字段级错误；构建器不得生成遗留`TARBALL`，也不得依赖固定服务器路径。

贡献流程复现至少使用1名未参与相关代码开发的组内成员和1个受控数据集。参与者只获得冻结的逐步指南和测试数据，依次完成配置生成、标准化、自动与人工检查、上传模拟、`Artifacts.yaml`登记以及下游更新、下载和读取。记录是否完成、错误步骤、口头干预次数和最终产物断言。该单案例只用于发现流程中断点，不进行一般用户群体的统计推断，也不把完成时间作为主要结果。

### 3.2 直接NetCDF分发的支持性效率测试

实验选择二维静态高程`ELEV_4X_1Y_V1`和三维8日叶面积指数`LAI_MODIS_2X_8D_2020_V1`，覆盖小型二维与中型三维内部压缩产品。每个标准NetCDF分别以原始`.nc`和包含同一文件的`tar.gz`分发；对照固定使用gzip级别6并明确记录。解包后的NetCDF必须与直接文件具有相同SHA-256，确保比较对象的科学内容完全一致。该实验只为“省去额外打包与解包”提供量化支持，不把压缩算法比较作为论文贡献，也不要求额外下载ERA5大文件。

测试在同机本地HTTP服务上进行以隔离公网波动，每个组合预热1次并随机顺序重复至少10次，记录传输字节数、打包与解包时间、从请求开始到首次读取一个NetCDF值的时间，以及按下载文件和解包文件同时存在关系计算的逻辑最大临时占用。该协议在Windows与macOS上各执行一轮，两轮使用同一脚本（仅输出文件名随平台区分）、同一随机种子与同一对输入文件；跨平台只比较方向与量级，不把两轮的绝对耗时直接合并。真实镜像不重复进行压缩对比，以免把网络波动误当成格式效应。时间指标报告中位数、四分位距和95% bootstrap置信区间。只有直接NetCDF在端到端时间或逻辑临时占用上表现出稳定定量优势时，才写“提高效率”；否则只写“删除了额外打包与解包步骤”。

### 3.3 Collector操作、多镜像与故障注入测试

#### 3.3.1 公共操作状态矩阵

测试在隔离的临时数据根目录内建立小型远端目录、旧本地目录、2～3个小型NetCDF和两个镜像端点，覆盖本地目录不存在、与远端相同、落后于远端、远端目录损坏及网络不可用等初始状态。逐项调用初始化与加载、`update_database!`、`download_dataset!`、`sync_database!`、`clean_database!`、目录树和数据集信息查询，并检查返回值、内存标签、目录版本、cache和public文件状态。`clean_database!("old")`、`clean_database!("all")`和按标签清理分别测试，但所有删除目标必须位于临时根目录。`read_dataset`的4类重载和`read_LUT`兼容别名也纳入同一回归矩阵。

每个状态转换至少独立重复3次。通过要求不是“函数未抛异常”，而是实际状态与预期完全一致；重复调用应具有预先定义的幂等行为，目录或下载失败不得破坏上一有效版本。`sync_database!`只同步fixture中的小文件，不把超过100 GB的全库下载作为论文必要实验。

#### 3.3.2 多镜像与故障注入

受控实验在Windows与macOS上分别建立两个内容相同、可独立设置故障的HTTP端点，并通过可注入的ping分数固定候选顺序，覆盖首选404、超时、连接重置、ping无响应但HTTP可用、全部镜像失败、已有同名缓存、截断缓存、返回HTML、哈希不符和中途截断等场景。每个场景在每个平台至少独立运行5次，记录ping分数、首选URL、回退次数、最终结果、错误类型以及cache/public文件的字节数和SHA-256变化。核心通过标准是：任一正确镜像可用时得到与目录哈希一致的文件；所有镜像失败或内容错误时返回明确错误，并保持原正式文件不变。受控端点用于故障状态验证，不能替代真实FTP与Zenodo访问实验。

#### 3.3.3 真实镜像补充检查

真实镜像实验分为校外可达性观察和校园网正式比较。固定具有同内容FTP和Zenodo地址且已登记`SIZE/SHA256`的4个小中型标签，对每个地址分别记录本机`ping`结果、单文件下载是否成功、下载时间、字节数和SHA-256。校外观察在Windows与macOS上各执行一轮；每个文件—镜像组合重复3次，所有下载缓存只写入论文研究目录。校外观察允许FTP失败并如实保留；若执行环境出现异常域名解析，须先用公共解析器交叉核实地址并在结果中如实记录解析方式，不把解析故障直接归因于镜像服务。校园网实验要求两个镜像均实际下载。实验只读访问FTP和Zenodo，不执行上传、覆盖或删除远端对象，结果分别限定于对应网络环境。

### 3.4 统一读取与模型初始化案例

接口验证分为受控接口测试与真实陆面补充案例。受控测试以固定夹具逐字段检查`read_dataset`、`grid_dict`和`grid_weather`的字段名、形状、类型、时间组织、NaN处理及异常分支，并将生成的参数和气象字典用于Emerald最小初始化与单步烟雾测试。真实陆面案例固定`gm2`和2020年，以US-NR1附近植被格点作为主案例，并选择一个非植被格点检查拒绝行为；运行前依据陆地掩膜和LAI确认格点类别。真实`wd1`需要8个ERA5文件，但它只用于扩展真实气象外部有效性，不是本文的软件接口验收条件。

固定Emerald版本和依赖环境后，将受控夹具生成的`grid_dict`和`grid_weather`输出用于同一格点的模型初始化，并执行能够读取首个气象时间步的最小步进烟雾测试。记录初始化是否成功、字段映射错误、单位或维度错误以及首步是否产生有限状态。本文不比较长期模拟结果、科学性能或计算速度；真实ERA5未运行时，仅将结论限定为受控输入下的接口连通性，不声称真实气象科学正确性。

### 3.5 平台与持续集成验证边界

Windows与macOS承担本文完整实验：运行包级回归、3轮生产矩阵、真实ELEV/LAI分发实验、5轮故障矩阵、Emerald烟雾及校外真实网络观察。公开候选版本另在GitHub Actions的`windows-latest`、`macos-latest`和`ubuntu-latest`上固定Julia 1.12.6运行。GriddingMachine执行63项回归；GriddingMachineDatasets执行38项配置测试和35项包集成测试；研究仓库执行29个非交互生产案例、M01～M13共65次故障状态断言，以及两个小型确定性NetCDF夹具、两种分发形式各10次的40次测量；Emerald公开候选执行5项最小接口烟雾断言。通过条件为所有预期测试成功、内容SHA-256一致、预期失败不改变正式文件且无`.part`残留。研究仓库保存各平台实验输出，GriddingMachineDatasets和Emerald工作流另保存解析后的平台Manifest。

CI中的小型分发夹具只用于验证代码路径、文件状态和内容完整性，不替代Windows/macOS真实ELEV/LAI的性能结果。Ubuntu任务不访问真实FTP/Zenodo或真实`gm2`文件；Emerald只运行固定合成输入下的5项最小接口烟雾断言。因此，Linux结果支持核心代码路径和受控模型接口能够在固定依赖下执行，但不能作为真实网络、真实陆面数据、长期模型模拟或科学正确性的三平台证据。

## 4 结果

本节只报告固定提交和可追溯日志支持的结果。Windows与macOS原始实验固定于`GriddingMachine@53bb0be`和`GriddingMachineDatasets@3926ae3`；依赖统一后的公开候选提交为`GriddingMachine@11631d6`（核心代码仍为`53bb0be`）、`GriddingMachineDatasets@5eac56a`、`Emerald@d79324f`和研究仓库实验冻结提交`8a23b5a`，Julia均为1.12.6。完整受控实验在Windows与macOS分别执行，校园网FTP—Zenodo比较在Windows实验电脑完成；Ubuntu CI检查固定依赖下的核心代码路径和Emerald最小接口烟雾，不作为额外科学样本。表4按研究问题汇总主要证据和外推边界，逐平台测试计数及环境信息见补充材料。

**表4 按研究问题汇总的核心验证证据**

| 研究问题 | 主要证据 | 关键结果 | 证据边界 |
|---|---|---|---|
| 生产契约正确性 | 二维/三维合成金标准矩阵；ELEV标准文件无损再处理 | Windows与macOS各3轮29/29；ELEV数组与坐标逐点一致 | 尚无真实异构原始产品端到端核对 |
| 下载失败安全性 | M01～M13受控故障注入 | 两平台共130次状态断言通过，`.part`残留为0 | 受控HTTP与注入排序分数 |
| 真实镜像获取 | 4个测试标签的FTP与Zenodo下载 | 校园网24/24次通过大小和SHA-256核验 | 单台Windows电脑、单个时段，不代表长期吞吐率 |
| 模型就绪接口 | 14个`gm2`文件、US-NR1与非植被格点 | 参数字典生成成功，非植被格点按预期拒绝 | 未作逐字段科学金标准、真实气象或长期模拟 |
| 跨平台可执行性 | Windows、macOS完整受控实验；Ubuntu CI核心路径与Emerald烟雾 | 所列固定依赖、核心路径和受控模型接口均可执行 | Linux不覆盖真实网络与真实陆面；非Julia接口未验证 |

**Table 4 Core validation evidence organized by research question.** Platform repetitions assess executability rather than provide independent scientific samples. The table separates production correctness, failure safety, real-network observations, downstream evidence, and cross-platform executability.

### 4.1 数据生产、配置契约与目录生成

`GriddingMachineDatasets`自动测试共73项，全部通过。其中38项覆盖YAML schema、旧配置规范化、非法配置拒绝、二维/三维源维度重排和配置构建器契约；35项覆盖包级加载、运行时根目录、本地目录元数据生成、合成NetCDF端到端生产、六类缺失值策略及同一配置对象重复调用。二维案例验证`(lat,lon)`换序、纬度翻转、经度半球切换、线性缩放和范围过滤，三维案例验证`(ind,lat,lon)`换序；重复调用安全跳过已有输出且不向调用者配置写入内部日志字段。目录生成测试从临时文件得到正确的`SIZE`与SHA-256，并成功写回、重读`Artifacts.yaml`。

在此基础上执行表3的31编号矩阵并独立重复3次，每次29个非交互案例全部通过；同一脚本在macOS上另完成3次独立运行，结果相同，两个平台的网络请求数均为0。自动案例逐项覆盖二维/三维标准与换序、坐标变换、Float32与缩放/范围、六类缺失值策略、YAML与配置构建器契约、主变量和同形`std`保存、已有输出跳过及非法配置/标签冲突拒绝。所有NetCDF位于纯ASCII隔离临时根目录。HJ操作者实际完成V01/V02审核：接受正确方向图、拒绝南北翻转图，总体为PASS；图件、记录和夹具均已计算SHA-256。该结果只验证一次操作流程，不构成多参与者研究。

一名未参与相关代码开发的参与者执行P01受控贡献流程。参与者最初不确定应使用哪个NetCDF以及YAML如何填写，获得1次说明后完成配置和流水线；没有失败的流水线尝试。自动验收确认输出逐点符合金标准，模拟目录的`SIZE`和SHA-256正确，且网络操作数为0。该结果证明流程在一次干预后可以完成，同时暴露出夹具选择和配置填写说明不够醒目；手册随后增加固定输入路径和完整YAML示例。由于修订发生在P01之后，本结果不证明修订版指南可无帮助完成，也不外推为一般用户可用性。

上述结果将数据生产证据从实现级回归扩展到完整编号矩阵、人工方向操作和单案例流程复现，但仍有边界：Windows含中文路径的NetCDF创建未通过；NetcdfIO旧导入名称已迁移至0.3接口；同一可变Dict被内部日志字段污染的问题已通过私有配置副本和重复调用测试修复。完整配置测试38/38和包集成35/35通过，二维/三维输出验证通过；GriddingMachine预编译缓存警告仍存在。本文不要求原始ELEV重建。

真实产品补充实验使用已通过大小和SHA-256校验的`ELEV_4X_1Y_V1.nc`。该文件为1440×720、无NaN，有限值范围-415.5～5357.7002 m；GriddingMachine整场读取与NetCDF底层Float32数组逐点完全一致。使用显式标准维度、`KEEP_AS_IS`且无缩放/裁剪的配置无损再处理3次，三次`data/lon/lat`均与输入完全一致，输出文件SHA-256也彼此相同。这支持真实标准产品能够通过统一读取和生产流水线而不改变科学数组及坐标。

本实验评价的是当前标准文件能否被完整性目录、统一读取和处理流水线稳定使用，而不是重建2022年的原始生产过程。按`catergory.txt`，ELEV的功能要求是陆地区域不得含`NaN`；实测文件全域无`NaN`，满足该要求。仓库历史YAML的范围、单位和修订标签与当前文件不一致，说明旧元数据仍需后续清理，但该遗留迁移问题不影响本文关于当前软件流程改进和标准文件无损处理的结论。

### 4.2 直接NetCDF分发效率

取消外层`tar.gz`已在代码路径中实现。本研究对通过来源MD5与SHA-256校验的`ELEV_4X_1Y_V1`和`LAI_MODIS_2X_8D_2020_V1`进行暖缓存实验，同一协议同一输入文件在Windows 10与macOS上各执行一轮。两文件的`data`变量均已采用NetCDF内部zlib level 4压缩；对照归档采用gzip level 6。本机回环HTTP条件下，每个“数据×形式”组合预热1次并按固定随机种子重复10次，两个平台共80次解包后SHA-256校验均通过。

直接NetCDF相对外层`tar.gz`的暖缓存端到端中位时间在Windows上降低48.3%（ELEV）和82.9%（LAI），在macOS上降低53.6%和69.2%；取消外层归档的代价是两样本传输字节分别增加6.43%和2.16%。两个平台共80次解包后摘要核验均通过。由于操作系统缓存未被特权清理，逻辑临时占用也不是系统级峰值采样，本结果只支持对这两个已内部压缩样本取消二次打包，不构成普遍性能结论。置信区间、绝对时间和原图移至实验材料，不作为正文核心图。

### 4.3 Collector、完整性校验与故障分支

`GriddingMachine`自动回归共63项，全部通过：目录初始化和schema 5项、事务式目录更新6项、镜像回退/缓存隔离/完整性校验及Windows ping解析10项、同步/信息/目录树/安全清理8项、`read_dataset` 18项、模型输入字典15项。受控fixture已验证错误大小、错误哈希、首选镜像失败和全部镜像失败时不会把错误缓存作为正式数据，并验证目录损坏不覆盖上一有效目录。所有清理测试均限定在临时数据根目录。

当前包级M01～M13矩阵使用固定注入ping分数，在Windows与macOS上分别每场景重复5次，两个平台各65次状态断言全部通过。M01验证较低ping镜像优先；M03验证有限值排在`Inf`之前；M05验证唯一URL即使ping为`Inf`仍会下载；M07验证所有ping为`Inf`时URL仍全部进入尝试队列。其余场景覆盖404、连接重置、全部下载失败、稳定cache、截断cache、同长度错误内容、传输截断、已有完整正式文件和同大小错误SHA-256。两个平台130次运行的`.part`残留均为0，预期失败场景保持旧正式文件不变。

Windows ping解析恢复后，提交`53bb0be`中的完整包在两个平台均正常加载，63项测试全部通过，其中两项新增测试覆盖正常响应与超时文本的ping延迟解析。包测试与注入ping矩阵分别验证真实Windows文本解析和确定性排序/状态逻辑；macOS上该解析函数按实现返回`Inf`，相应排序行为由注入分数矩阵覆盖。

在两个非校园网环境中进一步实际访问4个标签的FTP和Zenodo地址，每个文件—镜像组合重复3次。Windows轮：ping对两个主机均返回`Inf`，FTP的12次尝试全部在10 s连接超时，Zenodo的12次下载全部达到登记字节数并通过SHA-256，中位下载时间随文件大小由6.639 s增至271.507 s；20 s预实验仅使最小文件通过，说明下载超时必须与文件规模和网络条件共同解释。macOS轮：该环境默认解析器把`zenodo.org`异常解析为`0.0.0.0`，默认配置下12次Zenodo连接全部失败；经8.8.8.8与1.1.1.1交叉核实地址后以显式IP解析重测，正式记录的12次下载全部通过SIZE与SHA-256核验，中位下载时间由3.8 s（91 KB）增至70.8 s（4.2 MB）。正式记录前的一次手动大文件探测发生中途截断，完整重传后哈希与登记值一致；该单次现象只说明当时网络路径存在传输中断，不足以估计发生率或归因于Zenodo。FTP的12次尝试同样全部超时。两轮均无远端写操作，临时下载文件在记录后清除。

校园网Windows实验电脑于2026年8月15日使用Julia 1.12.6和`GriddingMachine@11631d6`执行同一协议。FTP与Zenodo各12次下载全部达到登记字节数并通过SHA-256；4个文件的FTP中位下载时间依次为0.076、0.356、0.071和0.244 s，Zenodo依次为1.091、2.720、3.386和14.092 s。12次排序记录中FTP `ping`为1.0～13.5 ms，Zenodo均为`Inf`，当前实现每次均把FTP排在首位；在本次校园网、4个文件和执行时段内，该顺序与实际下载表现一致。完整依赖Manifest及其SHA-256已随原始CSV/TOML保存。

受控故障注入与真实镜像访问回答不同问题：前者验证失败时的文件状态，后者验证特定网络内FTP与Zenodo的真实可达性、ping顺序和下载表现。两轮校外结果证明ICMP无响应不等于HTTPS不可下载、域名解析故障不等于镜像故障，也支持保留`Inf`地址并实施失败回退；校园网结果则表明校外FTP超时主要是对应网络边界现象，而不是文件缺失或完整性校验失败。单次校园网结果不能证明FTP长期更快，也不能把ping候选顺序等同于一般意义上的吞吐率最优。

### 4.4 统一读取与模型初始化接口

合成 NetCDF 回归中，`read_dataset` 的整场、周期和站点读取、经纬度边界换算及 `read_LUT` 兼容别名均通过，共18项；`grid_dict/grid_weather` 的字段、形状、时间组织和裸土分支共15项通过。测试发现并修复裸土分支把标量传给 `resample` 的错误，并使气象接口返回 Emerald 可接受的普通 `Dict`。

在隔离依赖环境中，Emerald最小烟雾测试5项全部通过，覆盖参数组织、气象组织、模型初始化和60 s单步执行。这证明接口在固定合成输入下能够连接，但不证明US-NR1全部参数的独立科学数值、真实气象、长期模拟或模型性能。

真实陆面预实验固定使用2020年`gm2`的14个唯一文件，共184,404,953 B。文件均通过登记字节数、Zenodo来源MD5和本地SHA-256三重核验，目录中的相应`SIZE/SHA256`已补齐。US-NR1请求坐标40.0329°N、105.5464°W映射到中心40.5°N、105.5°W的规则格点，陆地掩膜为0.991592，最大LAI为1.579117；`grid_dict`成功返回34个键、366日序列、4个土壤层和17个PFT，高程为1773.2001 m。撒哈拉请求坐标23°N、13°E映射到23.5°N、13.5°E，LAI为NaN，接口按预期报告目标格点非植被而未生成字典。全过程使用已校验本地文件且网络请求数为0。

这项结果证明真实`gm2`文件能够通过完整性目录、统一读取和陆面参数组织接口，并覆盖植被与非植被边界；它不是逐字段科学正确性证明。当前2020年`wd1`的8个ERA5条目仅登记机构FTP地址，未给出`SIZE/SHA256`，且本实验环境无法访问该FTP，因此未执行真实`grid_weather`；这不影响受控夹具对接口字段、时间组织和Emerald连通性的验证，但本文不作真实气象科学正确性声明。两个论文分支可在同一进程装载；迁移NetcdfIO接口并修复配置复用后，GriddingMachineDatasets配置测试38/38和包集成35/35通过。公开候选`Project.toml`已把GriddingMachine来源固定到完整提交号，三平台CI均从该声明解析依赖并保存Manifest；永久归档仍需保存这些环境文件，避免只依赖远端Git对象。

### 4.5 Windows与macOS完整验证及Ubuntu CI兼容性检查

为检查前述机制是否依赖单一操作系统，本研究在macOS 26.3.2（Apple Silicon）上以同一Julia 1.12.6和同一提交`GriddingMachine@53bb0be`、`GriddingMachineDatasets@3926ae3`复现全部受控实验：核心自动回归GriddingMachine 63项、GriddingMachineDatasets配置38项与包集成35项、Emerald最小烟雾5项全部通过，分组通过数与Windows逐项一致；31编号生产矩阵独立运行3次，每次29个非交互案例全部通过，网络请求数为0；直接NetCDF效率实验40次测量SHA-256全部一致，方向与Windows轮相同（4.2节）；M01～M13故障注入矩阵65次状态断言全部通过、`.part`残留为0。macOS环境的Emerald固定为`silicormosia/Emerald.jl`分支`wyujie`提交`9828b2a`，完整依赖锁已随原始日志归档。其中镜像测试组包含对Windows格式`ping`输出文本的解析断言，在macOS上同样通过，说明该解析为纯文本处理而不依赖本机`ping`实现；两轮效率实验使用SHA-256相同的输入文件，保证比较对象一致。

真实网络观察在两个平台的校外环境各完成一轮（4.3节）：Zenodo在可达条件下均能完成下载并通过完整性核验，机构FTP在校外均不可达；macOS轮额外记录到DNS异常解析，以及正式记录前的一次大文件传输截断。校园网Windows轮的FTP与Zenodo共24次下载全部通过完整性核验，补齐了机构镜像在校内网络的正式观察；该网络特定结果不作为macOS或Linux真实网络证据。

四个公开仓库随后在固定Julia 1.12.6环境完成`ubuntu-latest`、`macos-latest`和`windows-latest`持续集成。Ubuntu任务中，GriddingMachine 63项、GriddingMachineDatasets配置38项与包集成35项全部通过；研究仓库的29个非交互生产案例、65次故障状态断言和40次分发测量也全部完成；Emerald统一候选的5项最小接口烟雾断言通过。研究仓库保存三平台实验输出，GriddingMachineDatasets和Emerald工作流分别保存三平台Manifest。CI分发实验为控制运行时间而使用小型确定性NetCDF夹具，因此只用于检查流程、哈希和文件状态，性能数值不与Windows和macOS真实ELEV/LAI样本合并。Ubuntu没有执行校外FTP—Zenodo访问、真实`gm2`案例或长期模型模拟，故Linux结论限定为表4所列核心代码路径与合成输入模型接口的兼容性验证。

候选论文分支已消除Emerald与GriddingMachine之间的NetcdfIO约束冲突：GriddingMachineDatasets和Emerald候选均固定到同一GriddingMachine提交，NetcdfIO与PkgUtility分别统一为0.3.0和0.3.1，历史移动分支及冲突Manifest不再参与解析。Windows统一环境中GriddingMachine 63/63、GriddingMachineDatasets 38/38和35/35、Emerald 5/5全部通过。Emerald候选核心提交`d79324f`现已发布至独立论文仓库，仓库快照`b95d119`在Windows、macOS和Ubuntu干净runner上均通过5/5接口烟雾断言并归档平台Manifest。该证据使统一依赖和受控接口具备公开三平台复现记录，但不扩展为真实气象、长期模拟或全部Emerald科学过程的验证。

## 5 讨论

### 5.1 从数据集合到可维护工作流

2022版GriddingMachine的主要贡献是建立统一的网格和变量约定，并通过标签、哈希、多个下载URL及跨语言接口降低多源全球数据的发现和调用成本[4]。当前更新的增量不是TOML换成YAML、首次使用哈希或首次允许多个URL，而是共享配置契约、显式源维度映射、与软件版本解耦的目录、失败不污染正式文件的下载状态机，以及可回归测试的模型就绪接口。Windows与macOS受控实验支持这些机制，14个真实陆面文件和校园网FTP—Zenodo访问提供了外部案例；Ubuntu CI进一步验证核心路径的Linux兼容性。服务器文件复制、镜像URL补充以及由权威文件批量生成`SIZE/SHA256`属于正式发布准备，不构成本文的方法创新或科学验证指标。

现有结果从三个层次支撑更新：生产端有合成数据逐点金标准矩阵、人工方向走查和ELEV标准文件无损核对；分发端有事务状态故障注入和特定网络中的真实双镜像下载；下游端有统一读取回归、合成输入最小步进及真实`gm2`陆面链路。跨平台结果说明核心流程不是单一操作系统特例，但相同测试在多个平台通过不等同于多份独立科学验证。更重要的是，ELEV来自已标准化文件，P01使用合成夹具，现有生产实验尚未证明一个真实异构原始产品经缩放、缺失值和坐标变换后仍保持科学信息；这一端到端案例是正式投稿前最有价值的补充，而继续增加同类平台测试轮次的边际价值较低。

### 5.2 与相关地球科学数据基础设施的关系

Earth Engine把大规模地理空间数据与云端计算结合，适合服务器侧的行星尺度分析[3]；ESGF通过分布式节点、搜索和联合身份基础设施支撑气候模式数据的发现与访问[9]；Pangeo倡导分析就绪、云优化数据以及计算与数据邻近的云原生模式[10]，Pangeo Forge进一步以可复用配方和目录组织分析就绪、云优化数据的生产[11]。GriddingMachine不试图替代这些通用或大规模平台。它面向的是一组经过选择和统一的全球规则网格产品，以及需要在本地Julia工作流中按固定标签复现参数与气象驱动的模型使用场景。

因此，GriddingMachine的互补性体现在三个层次：以YAML保留从异构源数据到标准NetCDF的处理意图；以轻量目录连接机构镜像和通用存储；以`read_dataset`、`grid_dict`和`grid_weather`把标准数据组织为模型所需字段。与Pangeo Forge面向云端分析就绪数据生产的配方—基础设施分离不同[11]，本文流程强调可直接下载的单体NetCDF、离线缓存、完整性落盘和固定模型接口。对于接近云端的超大数据分析，云优化分块格式和数据邻近计算更合适[10]；对于CMIP等机构联合数据，ESGF的联合治理更成熟[9]。GriddingMachine的适用范围应限定为可下载、可本地缓存的规则网格数据，不能由本研究推及任意规模或任意网格的地球科学数据。

目录与哈希本身也不是本文单独主张的新技术。国内地球系统科学数据共享研究已经强调目录体系和规范关键词对数据管理与检索的作用[12]；Pooch以文件名、URL和SHA-256注册表实现远端文件获取、本地缓存和完整性校验[13]；STAC则为广泛地理空间资产的元数据结构与查询提供通用标准[14]。相比之下，GriddingMachine的外置YAML目录更窄且面向固定规则网格和模型标签，其新增价值在于把上游生产配置、标准NetCDF、事务式多镜像落盘和下游模型字段组织置于同一可测试契约中，而不是声称提出了通用目录标准或首次使用哈希下载。

### 5.3 FAIR与可复现性的实际边界

标签和外置目录提高数据的可发现性，多URL和直接NetCDF有助于获取，统一网格与变量约定支持互操作，来源、许可、处理记录和版本信息则关系到复用[1]。FAIR4RS进一步指出，科研软件的可执行性、复合依赖、持续演化和版本管理使其不能被简单视为静态数据对象[15]；TRUST原则则把透明度、责任、用户关注、可持续性和技术能力作为可信存储的共同框架[16]。GriddingMachine当前验证主要覆盖技术能力，不等同于已经证明长期治理和可持续保存。采用YAML、NetCDF或Zenodo本身也不自动满足FAIR。论文版本支持从权威文件生成`SIZE/SHA256`、下载后校验和目录事务替换；正式发布时仍需完成服务器文件复制、镜像登记和完整性元数据批量生成，并把来源、许可、配置哈希和代码版本写入最终NetCDF及归档记录。这些属于发布与溯源工作的完成度，不改变本文对生产和下载机制的验证结论。

正式release仍需把配置哈希、代码版本、文件大小和SHA-256连成最小溯源链，并将每项结果关联到不可变标签、归档地址和原始日志；软件本身也应按可识别版本作为研究产物引用[8]。ELEV历史YAML与当前文件范围、单位和标签的不一致说明，旧配置不能自动视为当前产品的完整生产溯源；本文因此只评价当前标准文件是否满足`catergory.txt`规定的功能规则以及能否被新版流程无损使用，不把历史产品的原始可重建性纳入结论。

### 5.4 局限与后续工作

第一，共享schema和显式维度映射已经实现，但部分历史YAML尚未迁移；非规则网格、区域投影和复杂时间坐标仍需数据源专用预处理。第二，空间方向仍需要人工查看图片；本文审核脚本可独立记录判断，但自动坐标和值域断言仍是主检查，人工判断只作补充。第三，`ping`延迟不是FTP或Zenodo下载吞吐率，且ICMP策略与域名解析异常都可能造成可下载地址被排后或暂时不可达；本文虽同时报告校园网ping和实际下载，但单个时段、4个文件和一台Windows电脑的结果不能证明当前排序长期或普遍最优。本文的完整受控实验和校外观察覆盖Windows与macOS；校园网真实网络结果仅来自Windows实验电脑；Ubuntu CI覆盖核心包、生产、故障、小型分发路径及Emerald合成输入接口烟雾，但不覆盖真实网络、真实陆面文件、长期模型模拟或科学过程验证。Emerald统一依赖候选已经公开并在三平台干净runner上通过5/5烟雾断言，但仍需不可变release和永久归档。

第四，配置构建器输出已与共享schema对齐，P01在一次说明后完成本地受控流程，为继续优化夹具入口和YAML指南提供了直接反馈。第五，`read_dataset`依据规则网格公式换算索引，真实陆面预实验验证了植被与非植被两个代表性格点，为后续建立逐字段科学金标准提供了基础。第六，`grid_dict`和`grid_weather`围绕固定的`gm1/gm2`、`wd1`标签与内置系数组织数据；当前真实证据覆盖`gm2`陆面链路，合成气象夹具完成接口验证，Emerald最小步进进一步证明模型接入路径连通。后续工作可沿真实气象驱动、长期模拟和多模型适配持续拓展。

## 6 结论

本文在2022版GriddingMachine基础上形成了由共享YAML schema、显式源维度映射、独立目录、直接NetCDF、事务式缓存及统一读取接口组成的可执行数据生命周期。跨平台合成矩阵和故障注入表明，受控生产变换可得到预期结果，错误或截断下载不会污染已有正式文件；校园网内4个测试标签的FTP与Zenodo下载均通过大小和SHA-256核验，14个真实陆面文件能够生成US-NR1参数字典。

合成生产矩阵、已标准化ELEV文件和单案例贡献走查不能替代真实异构原始产品的端到端科学核对；真实气象、长期模拟及MATLAB、Octave、Python和R接口也未在本文重新验证。GriddingMachine可定位为面向地球系统模型的轻量数据生产与可信分发基础设施。正式投稿前应优先补充一个真实原始产品的独立数值验证，并完成服务器文件复制、镜像登记、完整性元数据生成和不可变归档，为全球规则网格数据的持续维护和可复用模型输入形成完整证据链。

## 数据和代码可用性声明

GriddingMachine.jl源代码公开于https://github.com/CliMA/GriddingMachine.jl，论文候选分支提交为`11631d624f4847c5e34d2c4ff3cd762359a80c05`，其中被验证的核心代码提交为`53bb0be8b676f88d3d3dbe32f20aefdad883fcc2`。数据生产代码公开于https://github.com/jhOo1/GriddingMachineDatasets，论文候选提交为`5eac56af311fe511237ac2b1d7ef68b018fd7626`。Emerald统一依赖候选公开于https://github.com/jhOo1/Emerald-paper，接口代码提交为`d79324f5dbbfc560ccf1d796e10533ee3a7cd4f1`，可复现仓库快照为`b95d119204b2d1d6f82fd51ed5cffd4c5345af75`。实验协议、脚本和阶段性结果公开于https://github.com/jhOo1/GriddingMachine_Reaserach；提交`8a23b5af8481cf575d45a0b7587ad7b6ea76edd3`冻结了此前的三平台受控实验，后续校园网实验、目录盘点和修订稿记录在研究仓库的更新提交中。三平台持续集成记录分别为https://github.com/CliMA/GriddingMachine.jl/actions/runs/31876825314、https://github.com/jhOo1/GriddingMachineDatasets/actions/runs/31876841675、https://github.com/jhOo1/GriddingMachine_Reaserach/actions/runs/31877990092和https://github.com/jhOo1/Emerald-paper/actions/runs/31886671034。GitHub Actions工件具有保留期限，投稿前仍应为软件、数据目录、原始结果、环境文件和绘图脚本创建不可变release及带DOI的永久归档。

## 基金项目

【待作者和通讯作者补充基金项目中文/英文名称及编号；如无资助，按期刊要求声明。】

## 作者贡献

姜皓：概念设计、软件、验证、数据整理、可视化、初稿撰写【待作者确认】。王玉杰：概念设计、研究指导、项目管理、论文审阅与修改【待作者确认】。

## 利益冲突声明

作者声明不存在利益冲突【投稿前由全体作者确认】。

## AI 工具使用声明

本文准备过程中使用OpenAI Codex辅助整理研究材料与代码差异、检查论文结构、起草和修订部分文字、审查Julia/Python实验脚本、执行本地受控测试并汇总机器生成日志；同时辅助修订图1、生成分发效率实验图并编写发布目录盘点脚本。研究问题、实验范围、通过标准和结论边界由作者确定；工具输出未经人工核对不作为论文证据。作者逐项核验代码提交、原始CSV/TOML、文件哈希、终端结果、图件数值和正文表述，并对研究设计、数据真实性、结果解释及全文承担责任。OpenAI Codex不列为作者或参考文献作者。

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
