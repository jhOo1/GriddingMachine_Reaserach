# 面向地球系统模型的全球网格数据生产与可信分发：GriddingMachine框架更新与应用

**姜皓（Hao Jiang）**^1，**王玉杰（Yujie Wang）**^1*

1. 中国科学技术大学地球和空间科学学院，安徽 合肥 230026

姜皓，E-mail：hao.jiang@mail.ustc.edu.cn；ORCID：https://orcid.org/0009-0009-8295-8661

\* 通讯作者：王玉杰，wyujie@ustc.edu.cn

## 摘要

多源全球网格数据在维度结构、坐标方向、数值缩放、缺失值处理和分发位置等方面具有显著差异，对地球系统模型输入的标准化生产与稳定获取提出了统一化需求。本文在2022版GriddingMachine基础上完成框架更新，形成贯通数据生产、质量控制、多镜像分发、统一读取和模型调用的数据生命周期。新版以共享模式（schema）和YAML配置驱动源维度映射、坐标转换、数值变换与Gapfill，采用独立目录管理逻辑路径、镜像地址及完整性元数据，通过直接NetCDF和事务式缓存实现可信获取，并以`read_dataset`、`grid_dict`和`grid_weather`提供模型就绪数据。应用结果表明，二维与三维产品可稳定转换为统一NetCDF；直接NetCDF使两个内部压缩产品的暖缓存端到端中位时间降低48.3%～82.9%和53.6%～69.2%；校园网内4个代表性产品经FTP和Zenodo完成24次内容一致的真实下载；14类真实陆面产品成功生成US-NR1参数字典并进入Emerald模型初始化。新版GriddingMachine由此形成面向全球规则网格数据的可配置生产、可信分发和模型就绪应用框架，为地球系统数据产品的持续维护与复用提供轻量化基础设施。

**关键词：** 地球系统模型；全球网格数据；数据生命周期；NetCDF；可信分发；数据完整性

**English title:** Production and Trustworthy Distribution of Global Gridded Data for Earth System Models: Framework Advances and Applications of GriddingMachine

**Authors:** Hao Jiang^1, Yujie Wang^1*

1. School of Earth and Space Sciences, University of Science and Technology of China, Hefei 230026, China

Hao Jiang, E-mail: hao.jiang@mail.ustc.edu.cn; ORCID: https://orcid.org/0009-0009-8295-8661

\* Corresponding author: Yujie Wang, wyujie@ustc.edu.cn

## Abstract

Multi-source global gridded data differ substantially in dimensional structure, coordinate orientation, numerical scaling, missing-value treatment, and distribution location, creating a demand for standardized production and reliable access to Earth system model inputs. Building on the 2022 release, this study advances GriddingMachine into an integrated lifecycle for data production, quality control, multi-mirror distribution, unified reading, and model use. A shared schema and YAML configuration drive source-dimension mapping, coordinate and numerical transformations, and gap filling; an independent catalog manages logical paths, mirrors, and integrity metadata; direct NetCDF and transactional caching support trustworthy acquisition; and `read_dataset`, `grid_dict`, and `grid_weather` provide model-ready access. Two- and three-dimensional products were consistently transformed into standardized NetCDF files. Direct NetCDF reduced median warm-cache end-to-end time by 48.3%–82.9% and 53.6%–69.2% for two internally compressed products. Four representative products completed 24 content-consistent FTP and Zenodo downloads on the campus network. Fourteen real land products generated a parameter dictionary for US-NR1 and supported Emerald model initialization. The updated GriddingMachine therefore provides a lightweight infrastructure for configurable production, trustworthy distribution, and model-ready use of global regular-grid data.

**Keywords:** Earth system modeling; global gridded data; data lifecycle; NetCDF; trustworthy distribution; data integrity

## 1 引言

地球系统模型正在以更高的空间分辨率和更精细的过程表达描述陆地、大气、海洋及其相互作用。模型复杂度的提升使参数化、初始条件、边界条件、气象驱动和结果评估越来越依赖多源全球网格数据。此类数据通常由多个研究团队和业务机构生产，呈现多样的文件格式、空间投影、维度顺序、经纬度方向、时间组织、单位、缩放方式、缺失值表示和元数据结构。研究人员需要串联数据发现、下载、重投影、重排、缩放、质量检查和模型接口适配，进而把“可获得的数据”转化为可稳定、正确且可重复调用的模型输入。

科学数据管理正在由单纯的数据公开转向强调可发现、可获取、可互操作和可复用的 FAIR 原则[1]。NetCDF 具有自描述、跨平台和适合多维数组等特点，已广泛用于地球科学数据交换；CF 元数据约定进一步通过坐标、物理量、单位和时空属性描述促进不同数据源之间的解释与处理[2]。Google Earth Engine 等云平台显著提升了大尺度遥感数据的访问和分析能力[3]。机构服务器、团队存储和云平台共同构成当前地学数据分发生态，其中离线使用、固定版本和模型直接调用等场景尤其需要统一格式、独立目录、稳定镜像和可复现转换流程。

王玉杰等[4]于2022年提出GriddingMachine，将常用于陆面和地球系统模拟的全球数据处理为具有统一空间和变量约定的NetCDF文件，并通过标签、`Artifacts.toml`和Julia artifact机制实现数据管理和自动下载，同时提供Julia、MATLAB、Octave、Python和R接口。旧版目录已经记录SHA-1、SHA-256和一个或多个下载URL，数据标准也已规定经纬度方向、空间分辨率、变量名称、缺失值、单位、引用信息和处理日志。本文以这些既有设计为基础，将数据源专用处理提升为共享、可复用的生产契约，使数据目录具备独立演化能力，以事务缓存支持直接NetCDF获取，并通过统一接口组织模型输入。旧版`tar.gz`分发单元和随软件发布更新的目录为生命周期升级提供了明确基线。

从相关技术体系看，NetCDF以维度、变量和属性构成机器无关的多维科学数据抽象[5]，地球系统数据立方体则强调对多变量时空数据的共同组织和分析[6]；Julia通过多重派发和专业化兼顾高层抽象与科学计算性能[7]。与此同时，软件引用原则要求科研软件具有可识别、可持续、可访问和可归属的版本记录[8]。这些工作分别支撑文件表达、多变量分析、计算实现和软件引用；本文进一步把相关能力连接为“异构数据生产—多镜像分发—内容完整性保障—模型输入组织”的领域闭环。

针对上述问题，本研究围绕2022版的实际使用需求更新GriddingMachine，并将创新重点置于可执行的数据生命周期契约。在数据生产端，配置模板与`YamlBuilder`辅助贡献者生成YAML，通用流水线依据配置完成源维度映射、坐标和数值处理、质量检查及标准NetCDF输出；在分发端，以可直接读取的NetCDF替代二次压缩制品，通过独立目录登记机构FTP、Zenodo及其他社区镜像，并对已登记`SIZE/SHA256`的条目在cache下载后执行严格完整性核验；在数据使用端，以`read_dataset`统一读取，再通过`grid_dict`和`grid_weather`组织Emerald初始化数据。本文以Julia主路径系统呈现新版目录、下载状态机和模型接口的协同更新。

围绕全球网格数据从生产到模型应用的完整生命周期，本文构建共享YAML生产契约、独立数据目录、直接NetCDF分发、多镜像事务获取和模型就绪接口，并以标准产品生产、真实镜像访问和真实陆面数据应用展示新版框架的完整工作流。该更新将数据维护逻辑由分散脚本提升为可配置基础设施，使研究人员能够通过统一标签获得具有明确来源、处理记录和完整性信息的模型输入。

## 2 新版架构与关键方法

### 2.1 总体架构与数据生命周期

GriddingMachine 新版由数据生产、目录与分发、数据使用三个相互衔接的部分组成（图1）。数据生产端由 `GriddingMachineDatasets` 承担，负责把来源、结构和数值约定不同的地学数据转换为满足 GriddingMachine 规范的 NetCDF 产品；目录与分发部分负责保存标准数据产品、维护标签与镜像地址之间的映射，并使数据目录能够独立于 `GriddingMachine.jl` 软件包版本更新；数据使用端由 `GriddingMachine.jl` 承担，负责数据发现、下载、落盘、读取以及向地球系统模型提供参数和气象驱动。三部分共同形成“生产—质控—发布—发现—下载—读取—模型调用”的数据生命周期。

![图1 GriddingMachine全球网格数据生产、分发与模型调用框架](figures/图1_GriddingMachine总体架构.svg)

**图1 GriddingMachine从2022版到新版的数据工作流与关键优化** （a）2022版以数据集专用脚本、`tar.gz`制品、包内目录和`read_LUT`为主要路径；（b）新版形成“共享YAML契约—标准化与质控—直接NetCDF制品—独立数据目录—安全获取—统一读取与模型调用”的端到端流程；（c）O1—O5分别表示统一数据契约、简化数据制品、目录独立演化、事务式下载和模型就绪接口。蓝色实线、橙色虚线和灰色分别表示新版核心路径、版本间改进映射和2022版基线。

**Fig. 1 Data workflow and key optimizations from the 2022 release to the updated GriddingMachine.** (a) The 2022 baseline used dataset-specific scripts, `tar.gz` artifacts, an in-package catalog, and `read_LUT`. (b) The updated end-to-end workflow links a shared YAML contract, standardization and quality control, direct NetCDF products, an independent catalog, verified acquisition, and unified model-ready access. (c) O1--O5 denote the unified data contract, simplified artifacts, independently evolving catalog, transactional downloads, and model-ready interfaces, respectively. Blue solid lines, orange dashed lines, and gray elements indicate the updated workflow, cross-version changes, and the 2022 baseline.

在生产端，原始数据及其处理规则分别作为数据输入和YAML配置输入。新版使用共享schema描述原始文件组合、源变量、经纬度方向、源维度语义、数值变换、有效范围、Gapfill及输出元数据；配置构建器与处理流水线调用同一schema。`process_dataset!`根据配置枚举输入，依次完成读取、标准化、质量控制和保存，最终生成以统一标签命名的`TAG.nc`。维度、坐标、数值和空间方向检查嵌入生产流程，使标准产品在生成阶段即具有清晰的数据语义。

通过质量控制的数据产品可发布到机构FTP、HTTP(S)服务或Zenodo等公共存储位置。一个标签可以对应多个镜像地址；独立的`Artifacts.yaml`登记相对路径、URL、文件字节数和SHA-256。`GriddingMachineDatasets`的目录生成函数从权威本地文件计算完整性字段并事务式写入YAML，数据发布与目录登记由清晰接口衔接。目录与`GriddingMachine.jl`分开维护，使数据列表能够独立演化。

在数据使用端，Collector的`configure!`显式设置本地根目录与目录来源。目录下载经临时文件完成schema校验和事务式替换，并保留上一有效版本。`download_dataset!`提取各URL的主机名，以可获得的平均往返延迟辅助确定候选顺序，同时完整保留全部镜像并依次回退。每次调用创建独立`.part`文件；文件通过`SIZE`和`SHA256`核验后进入`public`，异常缓存随当前尝试清理。历史目录通过兼容模式继续提供数据获取能力，新目录形成内容完整、来源清晰的分发链。Indexer通过`read_dataset`提供整场、指定周期及站点读取，`grid_dict`和`grid_weather`进一步组织Emerald所需参数和气象驱动。14类真实`gm2`产品已经贯通陆面参数链路并进入Emerald初始化，2020年ERA5序列将继续拓展真实`wd1`气象驱动应用。

该生命周期形成持续演化的闭环。模型使用过程中形成的数据校正、元数据完善和新增数据需求可以反馈至YAML配置、质量控制和版本登记环节，持续提升数据产品及其生产流程。本文从标准产品生产、可信分发、统一读取和模型应用四个方面呈现这一闭环。

表1概括2022版与新版的主要差异及其在数据生命周期中的作用。

**表1 2022版与新版GriddingMachine的功能和技术路线比较**

| 环节 | 2022版 | 新版 | 应用价值 |
|---|---|---|---|
| 分发单元 | NetCDF的`tar.gz` artifact | 可直接读取的`.nc` | 简化数据获取并降低端到端读取时间 |
| 数据目录 | 软件内置`Artifacts.toml` | 外置`Artifacts.yaml`；schema校验、事务更新和版本备份 | 数据产品可独立于软件版本持续扩展 |
| 下载 | artifact哈希寻址、多个URL和解包 | 延迟探测辅助排序；多URL回退、独立缓存及`SIZE/SHA256`校验后落盘 | 兼顾机构镜像速度、公共镜像可达性和内容完整性 |
| 读取 | `read_LUT` | `read_dataset`，旧名称保留为别名 | 全球规则经纬网整场、周期和站点读取 |
| 模型组织 | 标准化数据和通用读取 | `grid_dict`与`grid_weather` | 真实陆面产品与Emerald模型接口顺利贯通 |
| 数据生产 | 数据源专用处理及贡献流程 | 共享YAML schema、配置构建器及显式源维度映射 | 形成可复用、可扩展的标准产品生产工作流 |

**Table 1 Comparison between the 2022 release and the current manuscript version of GriddingMachine.** The table summarizes implemented capabilities, workflow improvements, and validation progress. A field-level comparison is provided in the supplementary manuscript materials.

### 2.2 数据标准与 YAML 驱动的生产流程

#### 2.2.1 标准 NetCDF 数据模型

GriddingMachine 以 NetCDF 作为标准数据格式，原因是该格式能够在同一文件中保存多维数组、坐标和自描述元数据，并被多种地球科学软件读取。2022 年版本已经规定数据采用二维或三维规则经纬网，前两维依次为经度和纬度，可选第三维表示周期；经度自西向东、纬度自南向北，数据不保留未说明的缩放，缺失值在读取后统一表示为 `NaN`，主变量和不确定性变量分别命名为 `data` 和 `std`[4]。新版延续这些核心约定，并将维度映射、溯源信息、处理配置和分发完整性纳入可机器检查的规范（表2）。

**表2 GriddingMachine 标准 NetCDF 数据与元数据规范**

| 类别 | 新版规范 | 实现方式 |
|---|---|---|
| 文件与网格 | 一个标签对应一个可直接读取的`.nc`；规则经纬度网格，默认全球覆盖并声明坐标参考 | NetCDF统一保存数据、坐标与自描述元数据 |
| 维度 | 二维`(lon, lat)`；三维`(lon, lat, ind)`；源维度按名称映射到标准顺序 | 通用维度映射将多种源排列转换为统一结构 |
| 坐标方向 | `lon`自西向东并统一到`[-180, 180)`；`lat`自南向北 | 翻转和循环平移保持数据与坐标同步 |
| 数据变量 | `data`为主变量；`std`保存同形不确定性；输出为实际物理值 | 统一变量命名、类型、单位和数值表达 |
| Gapfill与范围 | 有效范围、填充值和Gapfill策略由YAML显式声明 | 支持数值常数、`MEAN`、`KEEP_AS_IS`、`INT_NAN_TO_1`、`NO_LAND_NAN`和`NO_NAN` |
| 变量元数据 | 包含单位、可读说明；可映射时使用CF `standard_name`[2] | 元数据随产品生成并进入统一目录 |
| 数据溯源 | 记录来源、引用/DOI、许可、处理历史、生成时间和责任主体 | 产品保留完整来源和处理上下文 |
| 处理复现 | 记录生产软件release、YAML schema版本和配置哈希 | 同一配置可重建相应标准产品 |
| 标签与版本 | 标签表达类别、空间/时间分辨率、年份、版本和可选修订号 | 标签与文件名共同形成稳定产品标识 |
| 分发完整性 | 正式发布条目记录文件字节数和SHA-256；同一标签各镜像内容相同 | 下载后核验并以事务方式进入正式目录 |

**Table 2 Standardized NetCDF data and metadata requirements of GriddingMachine.** The specification connects grid structure, gap filling, metadata, provenance, versioning, and distribution integrity within a unified production contract.

缺失值处理由YAML中的`GAPFILL`字段驱动，并依据产品物理含义选择相应策略。数值常数和`MEAN`分别以给定值或分层`nanmean`填补陆地区域缺失值；`KEEP_AS_IS`保持原始数组；`INT_NAN_TO_1`将缺失值补为1并对数组整数化；`NO_LAND_NAN`和`NO_NAN`分别检查陆地区域与全域的数据完整性。Gapfill由此统一连接有效范围过滤、陆海掩膜、缺失值处置和输出精度，为不同地球系统数据产品提供可配置的数据完善方法。ELEV采用常数0填补策略，为统一读取和模型调用提供连续地形场。

CF约定利用坐标变量和属性表达维度语义[2]。GriddingMachine进一步固定输出维度顺序，以降低下游接口复杂度。新版通过YAML的`DIMENSIONS`显式记录源变量各维度语义，并由`standardize_dimension_order`将`(lat, lon)`、`(ind, lat, lon)`等排列重排为统一输出；经纬度翻转与循环平移同步作用于坐标和数据值。规则经纬网数据进入通用标准化流程，非规则网格、区域投影和复杂坐标数据由数据源专用预处理模块完成适配。

#### 2.2.2 YAML 配置结构

YAML 将数据源差异与通用处理代码分离。当前配置由四类顶层字段组成：`FILE` 描述文件命名模式及 `PREFIX`、空间分辨率 `NX`、时间分辨率 `MT`、可选年份 `YYYY` 和数据版本 `VV`；`FOLDER` 指定原始数据与标准化数据目录；`DATA` 及可选的 `STD` 描述源变量名称、单位、缩放、有效范围、经纬度变换、缺失值策略和处理日志；`GRIDDINGMACHINE` 定义标签及可选修订号。一个配置可以包含多组前缀、分辨率、时间尺度、年份和版本，流水线对其笛卡尔组合逐项生成目标文件。

新版加入`SCHEMA_VERSION`并在数据读取前解析配置结构。字段分为必需项、具有明确默认值的可选项和互斥项，数组长度与变量前缀一一对应；`DIMENSIONS`、坐标变换、Gapfill和输出属性由共享schema统一约束。生产配置及配置构建器采用直接NetCDF方案，缺省`GAPFILL`规范化为`KEEP_AS_IS`。版本化schema同时承接历史配置，并持续扩展来源、许可、引用和输出NetCDF溯源属性。

#### 2.2.3 最小YAML配置示例

P01代表性贡献流程使用二维非对称参考数据呈现配置与处理操作的对应关系。源变量采用`(lat,lon)`顺序，纬度由北向南、经度范围为`0～360°`；配置中的关键映射为`DIMENSIONS: source: [lat, lon]`，并声明纬度翻转、经度半球转换和线性变换`2x+1`。处理后得到标准`(lon,lat)`顺序的`CONTRIB_SRC_2X_1Y_V1.nc`，逐点结果与独立金标准一致。完整YAML、字段字典、命令和目录说明保存在贡献指南中，真实数据配置进一步记录来源、许可、引用和复杂时间坐标。

#### 2.2.4 配置构建器与共享schema

`GriddingMachineDatasets`仓库中的`YamlBuilder`接收文件命名、变量标签、分辨率、时间尺度、版本、输入输出目录、单位、数值范围、缩放、坐标方向和GriddingMachine标签等结构化输入，并生成YAML配置。结构化构建方式统一字段名称、缩进和默认值，使贡献者能够将数据源约定稳定转换为可执行配置。

`YamlBuilder`与处理流水线调用同一schema；其输出采用`SCHEMA_VERSION`、`GAPFILL`与`DIMENSIONS`描述处理契约，输出位置由调用者配置。构建器生成的配置可直接交给`process_dataset!`，字段信息在源数据读取前完成解析。框1和版本化指南共同提供面向贡献者的配置范式。

#### 2.2.5 数据处理顺序与可追溯输出

`process_dataset!`首先根据`FILE`和`FOLDER`定位输入与输出文件，再读取`DATA`和可选`STD`指定的源变量。当前流水线将数据转换为`Float32`，依次执行纬度翻转、经度翻转或从`0～360°`到`-180～180°`的循环平移、线性缩放、有效范围过滤和缺失值处理。处理顺序作为复现链的一部分写入`history`，完整YAML、配置SHA-256和生产代码版本与输出文件共同归档。

生产流程在保存前检查维度、坐标、变量、数值范围和Gapfill结果，空间方向图进一步呈现坐标语义。质量控制完成后生成`data`，存在不确定性时追加同形的`std`，并按`TAG_(PREFIX_)NX_MT_(YYYY_)VV(_REVISION)`生成唯一文件名。重复调用可识别已有目标；内容感知机制将进一步结合配置哈希、软件版本和文件摘要管理产品重建。

### 2.3 数据质量检查与目录登记

#### 2.3.1 处理过程中的空间方向控制

当前生产流水线在 `read_input` 完成经纬度翻转、经度范围调整、线性缩放、有效范围过滤和缺失值处理后，调用 `verify_data!` 对待保存数组进行方向检查。该函数把数组写入调用者指定或默认的NetCDF缓存文件，Python脚本依据变量维度名重排为`(lat,lon)`后生成带经纬度坐标轴的图件；二维数据输出PNG，三维数据沿`ind`维输出GIF。操作者查看图件并在终端记录接受或退回状态。YAML中的`VERIFY_ONCE`控制同一配置组合的首次确认，通过状态保存在该次处理使用的配置副本中。

这一过程用于识别南北方向、东西方向和经度平移状态。V01/V02脚本分别提供方向正确与南北反转的非对称位置编码图，正向图与反向图均得到准确识别。人工空间判断与自动坐标、结构和逐点数值检查共同组成直观的方向质量控制体系。

#### 2.3.2 标准文件检查

对于已经生成的NetCDF文件，`verify_processed_data!`提供独立的结构和数值检查。该函数首先确认文件及覆盖类型，支持全球陆地和海洋（`both`）与陆地（`land`）两类产品。随后检查`lon`、`lat`维度、坐标变量和主变量`data`，三维产品进一步检查`ind`，并验证各维长度的一致性。数值检查读取完整`data`数组，计算有效值的最小值和最大值，并评价其与给定范围的符合程度。

缺失值检查根据覆盖类型执行。`both`要求整个数组具有完整有效值；`land`在经度长度为360、720或1 440时读取并重采样`LM_4X_1Y_V1`陆地掩膜，逐层检查陆地区域。其他空间分辨率由专用规则承接。现有函数覆盖主变量、形状、范围和陆地掩膜，后续质量模块将进一步整合坐标单调性、`std`、单位、引用信息和处理日志。

#### 2.3.3 标签生成与数据目录登记

数据文件名由`griddingmachine_tag`生成，基本形式为`TAG_(PREFIX_)NX_MT_(YYYY_)VV(_REVISION)`。其中`NX`表示空间分辨率，`MT`表示时间分辨率，`YYYY`和`REVISION`为可选部分。生成输出路径时，代码读取当前`Artifacts.yaml`并识别标签状态，以保持数据产品标识的唯一性。

数据发布与目录登记采用解耦设计。维护者在Zenodo、机构FTP或其他存储中发布标准产品，再将本地NetCDF路径和公开URL交给`update_yaml_library!`。该函数调用`build_catalog_entry`生成`PATH`、去重后的`URL`、`SIZE`和`SHA256`，按标签排序后通过临时文件更新`Artifacts.yaml`，从而形成职责清晰、内容可校验的目录生成流程。

目录生成器从本地标准文件计算字节数和SHA-256并写入YAML，下载端以相同字段确认实际内容，从而形成“本地标准文件—目录条目—下载文件”的完整性链。历史目录迁移以权威本地文件重新生成`SIZE/SHA256`，`verify_urls!`用于地址巡检，二者共同提升多镜像目录的可维护性。

#### 2.3.4 数据贡献与发布流程

一个新数据集进入GriddingMachine依次经历：准备原始文件；通过模板或配置构建器生成YAML；运行`process_dataset!`；检查维度、坐标、变量、数值范围、缺失值和方向图；将标准NetCDF至少上传至一个外部可访问位置，并按条件增加机构镜像；把标签、逻辑路径、URL、文件大小和SHA-256写入`Artifacts.yaml`；发布目录新版本；最后从`GriddingMachine.jl`执行目录更新、下载和读取。机构FTP可以提高校内访问速度，Zenodo或其他公共存储保证校外可用；其他维护者也可在目录条目中增加内容相同的镜像。

P01贡献流程依据版本化指南贯通代表性数据集的配置生成、标准化、质量检查、发布、目录登记和下游读取。最终NetCDF与目录项保持一致，并形成包含固定输入路径和完整YAML示例的贡献模板。

### 2.4 动态目录与多镜像分发

#### 2.4.1 本地目录初始化与加载

`GriddingMachine.jl`通过Collector管理目录和本地文件。`configure!`可从参数或环境变量设置数据根目录、目录URL和本地目录文件；`cache`保存下载临时文件，`public`按条目中的`PATH`保存正式NetCDF。模块初始化负责配置内存状态，目录加载、更新和数据下载均由显式调用触发，使数据访问过程清晰可控。

目录条目以数据标签为键，核心字段包括安全相对路径`PATH`、一个或多个`URL`以及正整数字节数`SIZE`与64位十六进制`SHA256`。加载时对标签字符、路径、URL协议和完整性字段执行schema校验，并提供路径、URL、信息和本地状态查询。可配置根目录与显式网络访问共同支持独立工作环境、离线复现和正式数据管理。

#### 2.4.2 数据目录更新

`update_database!` 调用 `download_database!` 获取目录，验证后再加载为内存状态。调用者可直接提供 YAML 文件 URL，也可使用 Zenodo 落地页；后者仍通过页面中的 `Artifacts.yaml` 链接解析实际下载地址。目录先写入同目录临时文件，解析根节点并执行 schema 校验；通过后备份当前目录为 `Artifacts.previous.yaml`，再替换正式文件。

该机制实现目录与软件版本分离，并以事务替换和备份恢复保护有效目录。目录入口同时支持直接YAML地址与Zenodo落地页解析；后续版本将接入结构化API和多版本远程归档，进一步增强目录演化能力。

#### 2.4.3 多镜像排序与稳健回退

`download_dataset!`接收数据标签；目录刷新、正式文件复用和远端获取由同一接口组织。下载阶段从每个FTP或HTTP(S) URL提取主机名，以可获得的平均往返延迟生成候选顺序；缺少延迟分数的地址按原有顺序保留，全部URL共同组成完整回退队列。

下载循环按候选顺序逐一尝试镜像，每次尝试均写入进程级唯一`.part`文件。程序核对文件生成状态、字节数和SHA-256；校验通过后以原子移动进入正式路径，异常内容则随本次临时文件清理并转向下一URL。`require_integrity=true`提供严格完整性模式，兼容模式承接历史目录。镜像遍历完成后返回包含数据标签和各候选状态的汇总信息，已有正式文件始终保持稳定。

延迟探测用于优化镜像尝试顺序，完整文件下载与`SIZE/SHA256`核验决定最终可用性。本文进一步在中科大校园网对同一文件分别执行FTP和Zenodo只读下载，以实际下载时间和内容摘要共同评价镜像获取效果。

#### 2.4.4 缓存落盘与批量同步

每次下载使用`cache/.<TAG>.<PID>.part`，通过完整性校验后移动到正式路径。`sync_database!`在更新目录后遍历标签并复用相同下载逻辑。小型目录参考数据呈现初始化、更新、同步、回退和清理行为，完整历史目录沿用同一事务机制开展批量运维。

镜像状态分析覆盖候选顺序、字节数、SHA-256、缓存恢复和镜像遍历等分发环节。多环境运行与校园网FTP—Zenodo实测共同呈现“事务安全—真实获取—内容一致”的分发链路。

#### 2.4.5 Collector公共操作

除单标签下载外，Collector还提供目录更新、全库同步、旧数据或指定标签清理、目录树和数据集信息查询等操作，形成完整的数据维护工具链。`clean_database!("all")`管理所配置根目录下的`public`内容，按标签清理对应缓存和正式文件；`clean_database!("old")`依据当前有效目录识别历史文件，并支持在清理前刷新目录。路径检查将操作范围限定在托管数据目录，更新、同步、查询和清理共享统一的目录状态。

### 2.5 统一读取与模型接口

#### 2.5.1 `read_dataset` 统一读取接口

Indexer模块以`read_dataset`统一本地NetCDF路径和目录标签的读取，支持整场数组、指定周期切片、站点全部周期以及站点指定周期4种调用。目录标签在本地缺失时交由Collector下载；旧名称`read_LUT`保留为兼容别名。默认读取`data`，调用者也可显式请求`raw_data`或`std`。读取层直接保留生产端已经标准化的单位、缺失值和物理范围，使处理规则集中于共享生产契约。

站点读取依据全球规则经纬网分辨率把经纬度映射为数组索引，并以标准文件的`(lon,lat[,ind])`顺序及西向东、南向北排列为输入契约。接口面向全球规则网格的原位索引，区域投影、非规则网格和空间插值可在生产端完成标准化；周期索引的月份、日期或小时含义由对应产品元数据解释。

#### 2.5.2 `grid_dict` 陆地模型参数组织

`grid_dict`把`gm1`或`gm2`标签组中的土壤、冠层、叶片、地形、陆地掩膜和植物功能型产品组织为单个格点的模型参数字典。年份用于选择叶面积指数并组织逐日序列。函数先检查陆地掩膜和叶面积指数；植被格点进入参数读取与季节序列组织，其他格点返回清晰的状态信息。

输出包括位置、分辨率、年份、CO₂、土壤水力参数、冠层结构、植物功能型比例、叶片生物物理和光合参数；启用质量控制时同步检查字段完整性和`NaN`状态。该接口把多个已标准化产品稳定组织为模型入口，内置经验系数、标签组合及陆面类型状态共同构成清晰的模型输入契约。

#### 2.5.3 `grid_weather` 气象驱动组织

`grid_weather`按年份和格点读取`wd1`中的8个ERA5标签，分别组织地表气压、降水、漫射与直射短波辐射、长波辐射、气温、水汽压亏缺和风速。输出统一为含时间索引`FDOY`及8个气象字段的字典，启用质量控制时同步检查字段完整性和`NaN`状态。接口既可直接按经纬度读取，也可从已经加载的全局气象数组提取格点序列。

该接口围绕规则网格、既定单位和`wd1`标签完成模型就绪字段组织。确定性气象参考数据用于组织字段、形状和Emerald最小步进，真实`gm2`文件贯通陆面参数链路。2020年ERA5序列将进一步扩展真实`wd1`气象驱动应用。

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

示例采用只读目录与镜像获取流程。`update_database!`和缺失文件下载访问目录及其镜像；离线复现可将`catalog_file`和数据根目录指向已经归档并完成哈希核验的本地副本。版本化用户指南集中提供完整安装、配置字段字典、目录登记和状态恢复命令，正文突出工作流结构及其应用方式。

## 3 典型应用与分析方法

### 3.1 标准数据生产与质量控制

#### 3.1.1 维度、坐标与数值转换场景

为展示YAML驱动流程对多维地学数据的标准化能力，本文设计具有明确空间语义的位置编码数组：二维数组由经纬度索引共同编码，三维数组进一步加入周期索引。该设计能够清晰呈现维度交换、方向翻转、经度平移和周期组织前后的对应关系，并为标准NetCDF生产提供逐点参照。

生产场景包括`(lon,lat)`与`(lon,lat,ind)`标准输入、`(lat,lon)`与`(ind,lat,lon)`源排列、纬度和经度翻转、`0～360°`经度平移、线性缩放、范围过滤、Gapfill、`data/std`保存和标签生成。配置字段、变量数量、已有产品和标签状态共同覆盖标准产品从源数据到目录登记的主要环节。

#### 3.1.2 标准产品生产场景

表3将标准产品生产分为维度（D）、坐标（C）、数值（N）、Gapfill（G）、YAML配置（Y）、输出（O）和空间方向检查（V）7组，共覆盖31个代表性场景。各组对应共享生产契约中的一个关键环节，并以结构、数值或产品状态描述处理结果。

**表3 GriddingMachineDatasets标准产品生产场景**

| 环节 | 场景数 | 主要内容 | 处理结果 |
|---|---:|---|---|
| D 维度 | 5 | 2D/3D标准顺序、`(lat,lon)`、`(ind,lat,lon)`、非支持维度 | 输出形状、维度名及逐点位置 |
| C 坐标 | 4 | 纬度翻转、经度翻转、`0～360°`平移、组合变换 | 坐标方向及位置编码值 |
| N 数值 | 4 | Float32、线性缩放、有效范围、有/无缩放 | 最大绝对和相对误差、NaN掩膜 |
| G Gapfill | 8 | 常数、`nanmean`、原值保持、陆地完整、全域完整和整数化 | 填补位置、填充值、覆盖范围和处理记录 |
| Y 配置 | 4 | 最小配置、字段完整性、构建器生成配置、数组长度一致性 | 配置解析、字段定位和产品生成 |
| O 输出 | 4 | `data`、`std`、已有文件、标签状态 | 变量、属性、版本策略和标签唯一性 |
| V 方向检查 | 2 | 正向图识别、反向图识别 | 空间方向与坐标语义一致 |

**Table 3 Representative standardized-product production scenarios in GriddingMachineDatasets.** The scenarios cover dimensions, coordinates, numerical transformations, gap filling, YAML configuration, product output, and spatial-orientation inspection.

#### 3.1.3 产品质量控制

产品质量控制覆盖变量、维度、形状、属性、坐标方向、数值范围和Gapfill结果。输出数组与位置编码参照逐点对应，Float32转换采用统一的绝对和相对容差；配置与产品状态通过明确的流程信息反馈给维护者。质量报告同步保存最大绝对误差、最大相对误差、处理历史和重复生产一致性。

标准产品生产流程在多环境中保持一致行为。29个自动场景连续完成，V01正向图和V02南北反转图均得到准确识别，展示了共享生产契约在数组变换、配置解析和空间方向控制方面的稳定性。

#### 3.1.4 YAML配置与数据贡献工作流

`YamlBuilder`面向二维数据、含`std`的三维数据和经纬度变换数据生成符合共享schema的配置，并将配置直接交给`process_dataset!`。字段级信息、直接NetCDF输出和可配置路径共同构成面向数据贡献者的生产入口。

P01代表性贡献案例依次完成配置生成、标准化、自动与人工质量检查、产品发布、`Artifacts.yaml`登记以及下游更新、下载和读取，呈现数据贡献者使用新版工作流的完整路径。

### 3.2 直接NetCDF分发效率评价

直接NetCDF分发效率采用二维静态高程`ELEV_4X_1Y_V1`和三维8日叶面积指数`LAI_MODIS_2X_8D_2020_V1`进行分析，代表不同规模和维度的内部压缩产品。每个标准NetCDF分别以原始`.nc`和包含同一文件的`tar.gz`分发，对照归档采用gzip级别6。两种形式解包后的NetCDF具有相同SHA-256，据此量化省去外层打包与解包带来的时间和临时空间收益。

性能分析在本地HTTP服务中采用随机顺序重复测量，记录传输字节数、打包与解包时间、从请求开始到首次读取NetCDF值的端到端时间，以及下载文件与解包文件并存时的逻辑临时占用。两个独立环境使用一致的脚本和输入文件，时间指标以中位数、四分位距和95% bootstrap置信区间表示。

### 3.3 数据目录与多镜像分发分析

#### 3.3.1 数据目录生命周期

数据目录生命周期涵盖首次建立、版本更新、目录同步、产品获取、状态查询和历史数据整理。代表性目录包含不同版本的`Artifacts.yaml`、多个NetCDF产品和两个镜像端点，并依次调用`update_database!`、`download_dataset!`、`sync_database!`、`clean_database!`及目录信息接口。cache与public目录分别承担事务缓存和正式产品保存，`read_dataset`的整场、周期和站点读取共同连接目录与数据使用环节。

各状态转换通过重复调用考察幂等行为，上一有效版本和事务缓存共同承接目录与下载状态。`sync_database!`使用确定性小型目录参考数据呈现全库遍历逻辑。

#### 3.3.2 多镜像状态与事务安全

多镜像状态分析在两个独立环境中建立内容一致且状态可配置的HTTP端点，并通过延迟分数组织候选顺序，覆盖404、超时、连接重置、延迟探测状态、镜像遍历、缓存恢复、内容类型、哈希差异和传输完整性等场景。各场景重复5次，记录候选顺序、回退次数、最终状态以及cache/public文件的字节数和SHA-256变化。事务机制使目录摘要一致的文件进入正式路径，并在各类镜像状态下保持既有正式文件稳定。校园网FTP与Zenodo访问进一步呈现真实镜像的可达性和内容一致性。

#### 3.3.3 真实镜像访问

真实镜像实验选取4个同时具有FTP和Zenodo地址且已登记`SIZE/SHA256`的代表性标签，对各文件—镜像组合开展重复下载，记录候选顺序、传输时间、字节数和SHA-256。公共网络观测刻画Zenodo镜像获取特征；中科大校园网实验对FTP与Zenodo执行同文件只读下载，共形成24次完整性记录。实验数据与环境信息随可复现材料归档。

### 3.4 统一读取与模型就绪应用

模型就绪应用连接`read_dataset`、`grid_dict`、`grid_weather`与Emerald初始化。确定性参考数据用于组织字段名、形状、类型、时间索引和NaN处理；真实陆面案例采用2020年`gm2`产品，在US-NR1附近植被格点和典型非植被格点展示不同陆面状态下的模型入口。2020年`wd1`的8类ERA5数据将进一步拓展真实气象驱动应用。

`grid_dict`和`grid_weather`输出可直接用于同一格点的Emerald初始化与首个气象时间步计算。字段映射、单位和维度在标准数据与模型接口之间保持一致，使GriddingMachine产品能够进入模型参数组织和时间步计算。

### 3.5 多环境运行与持续集成

本文所称多环境运行覆盖Windows、macOS和Linux，采用本地运行与持续集成相结合的方式，贯通标准产品生产、真实ELEV/LAI分发、多镜像获取、Emerald最小模型流程和核心软件路径。统一的项目依赖和参考数据使数据结构、数值内容、正式文件状态与临时缓存行为保持一致。

持续集成使用确定性NetCDF参考数据维护代码路径、文件状态和内容完整性，本地环境进一步覆盖真实ELEV/LAI效率、真实镜像访问和真实`gm2`陆面案例，共同形成从自动维护到真实数据应用的分层运行体系。

## 4 应用结果与性能表现

新版GriddingMachine实现了从源数据配置到标准产品生成、从多镜像发布到本地可信获取、再到模型参数组织的完整链路。共享生产契约提升异构数据处理的一致性，独立目录和直接NetCDF简化产品维护与访问，事务式缓存增强多镜像获取的稳定性，统一接口进一步将标准数据连接到Emerald模型。主要功能与应用表现汇总于表4。

**表4 新版GriddingMachine的主要改进与应用表现**

| 功能模块 | 主要改进 | 应用表现 | 扩展方向 |
|---|---|---|---|
| 标准产品生产 | 共享YAML schema、显式维度映射和Gapfill | 二维/三维产品稳定生成；ELEV数组与坐标完整保持 | 扩展真实异构原始产品 |
| 数据制品 | 直接NetCDF替代外层`tar.gz` | 暖缓存端到端中位时间降低48.3%～82.9%和53.6%～69.2% | 扩展更多产品规模 |
| 目录与镜像 | 独立目录、延迟辅助排序、多URL回退和事务缓存 | 校园网FTP与Zenodo共24次下载内容一致 | 建立长期镜像运行统计 |
| 模型就绪访问 | `read_dataset`、`grid_dict`和`grid_weather` | 14类`gm2`产品生成US-NR1参数字典并进入Emerald | 接入ERA5气象驱动与长期模拟 |
| 多环境运行 | 版本化依赖与持续集成 | 多环境保持一致的软件路径与数据接口 | 扩展真实案例自动化运行 |

**Table 4 Major advances and application performance of the updated GriddingMachine.** The table summarizes standardized production, direct NetCDF distribution, multi-mirror acquisition, model-ready access, and cross-platform operation.

### 4.1 数据生产、配置契约与目录生成

共享YAML schema成功组织二维和三维数据的源维度重排、坐标变换、线性缩放、有效范围过滤与Gapfill，并将处理结果保存为统一的`data/std`结构。配置构建器、生产流水线和目录生成器使用同一字段约定，使标准产品能够从源数据处理直接进入`Artifacts.yaml`登记；目录条目同步生成准确的`SIZE`与SHA-256，为后续多镜像发布提供完整性信息。

表3所列31个生产场景完整覆盖维度、坐标、数值、Gapfill、配置、输出和空间方向控制。多环境获得一致的产品结构和逐点数值结果，V01正向图与V02南北反转图得到准确区分，说明自动质量控制与人工空间检查能够共同维护标准产品的坐标语义。

P01代表性贡献案例顺利完成从YAML配置到标准产品生成、目录登记和下游读取的完整流程。生成产品与参照数组逐点一致，目录中的`SIZE`和SHA-256准确；完整YAML示例和固定输入路径进一步形成可直接复用的数据贡献模板。

NetcdfIO接口迁移与配置对象复用机制进一步统一了文件访问和批量生产行为。二维/三维输出、坐标变换、数值处理、Gapfill和目录生成由同一工作流连接，形成可持续扩展的标准产品生产基础。

真实产品补充实验使用已通过大小和SHA-256校验的`ELEV_4X_1Y_V1.nc`。该文件为1440×720、全域有效，有限值范围-415.5～5357.7002 m；GriddingMachine整场读取与NetCDF底层Float32数组逐点完全一致。使用显式标准维度、`KEEP_AS_IS`和原值保持配置连续处理3次，三次`data/lon/lat`均与输入完全一致，输出文件SHA-256也彼此相同。这表明真实标准产品经过统一读取和生产流水线后完整保持科学数组及坐标。

ELEV标准文件顺利贯通完整性目录、统一读取和处理流水线。实测数组全域具有有效值，重复生产中的坐标、数据和输出摘要保持一致，展示了新版流程对既有标准数据产品的稳定承接能力。

### 4.2 直接NetCDF分发效率

新版采用直接NetCDF作为分发制品。本研究以通过来源MD5与SHA-256校验的`ELEV_4X_1Y_V1`和`LAI_MODIS_2X_8D_2020_V1`评价分发效率，并在独立运行环境中采用一致协议。两文件的`data`变量均采用NetCDF内部zlib level 4压缩，对照归档采用gzip level 6。本机回环HTTP条件下，各“数据×形式”组合经过预热并按随机顺序重复测量，全部解包后内容均通过SHA-256校验。

直接NetCDF相对外层`tar.gz`的暖缓存端到端中位时间在两个环境中分别降低48.3%～82.9%和53.6%～69.2%；两样本传输字节增加6.43%和2.16%。共80次内容摘要核验全部通过。结果表明，对于已经采用NetCDF内部压缩的数据产品，直接分发能够显著减少额外解包时间和逻辑临时占用。置信区间、绝对时间及完整图件保存在实验材料中。

### 4.3 Collector与可信多镜像分发

Collector将目录初始化、事务更新、产品同步、镜像获取、状态查询和历史数据整理组织为统一的数据维护接口。独立目录使数据产品能够随镜像和版本持续更新，cache与public分层保存机制则将传输过程与正式数据分离，使上一有效目录和已发布产品在目录更新与镜像切换过程中保持稳定。

M01～M13镜像状态场景表明，Collector能够优先选择延迟较低的候选，同时完整保留全部URL并依次回退。每次获取采用独立`.part`文件，内容经字节数和SHA-256确认后进入正式路径；130次状态记录中的临时文件均被完整回收，既有正式文件摘要保持一致。

同一下载接口在多环境中均实现延迟辅助排序、全候选保留和顺序回退，为不同网络条件提供一致的数据获取方式。

公共网络环境下，4个标签经Zenodo完成24次真实下载，全部达到登记字节数并通过SHA-256核验。不同文件规模的中位下载时间呈合理梯度，重复传输的内容摘要与目录登记值一致，展示了公共镜像、事务缓存和完整性校验协同支持稳定数据获取的能力。

中科大校园网环境下，FTP与Zenodo各完成12次同文件下载，24次结果全部达到登记字节数并通过SHA-256核验。4个文件的FTP中位下载时间为0.071～0.356 s，Zenodo为1.091～14.092 s；FTP往返延迟为1.0～13.5 ms，延迟辅助排序与实际传输表现一致。该结果展示了机构镜像与公共镜像的内容一致性，以及多镜像目录对不同访问环境的适应能力。

镜像状态场景呈现事务式文件转换，真实镜像访问展示FTP与Zenodo的可达性、候选顺序和下载表现。公共网络体现Zenodo镜像和全候选保留机制，校园网体现机构FTP与公共Zenodo的互补分发能力。延迟辅助排序、全URL回退和`SIZE/SHA256`核验共同支持不同网络条件下的稳定数据获取。

### 4.4 统一读取与模型就绪应用

`read_dataset`统一支持整场、周期和站点读取以及经纬度索引，`read_LUT`作为兼容别名延续原有调用方式。`grid_dict`和`grid_weather`进一步将标准产品组织为Emerald可直接使用的参数与气象字典，并支持植被、裸土和时间序列等模型输入场景。

GriddingMachine输出顺利进入Emerald参数组织、气象组织、模型初始化和60 s单步计算，建立了从标准数据读取到模型首个时间步的直接连接。

真实陆面案例使用2020年`gm2`的14类标准产品，全部通过文件大小、来源摘要和本地SHA-256核验。US-NR1站点被映射至相应规则格点，`grid_dict`成功组织34个模型字段、366日季节序列、4个土壤层和17个植物功能型，高程、陆地掩膜与叶面积指数均得到正确读取。撒哈拉案例准确返回非植被格点状态，表明接口能够根据陆面特征组织相应模型入口。

真实`gm2`文件顺利贯通完整性目录、统一读取和陆面参数组织接口，并覆盖植被与非植被入口。依赖统一和接口迁移使多环境能够从同一项目声明解析一致的软件组合。2020年ERA5的8类`wd1`序列将进一步拓展从标准气象数据到模型运行的应用链路。

### 4.5 多环境运行表现

多环境均可运行标准产品生产、直接NetCDF分发、多镜像获取和Emerald模型接口，并获得一致的数据结构、内容摘要和模型字段，表明共享数据契约、事务式下载和模型就绪接口具有稳定的环境适应性。

公共网络中的Zenodo下载和校园网中的FTP—Zenodo对照均通过完整性核验。多网络环境结果共同展示了公共镜像与机构镜像的互补价值，以及全URL回退机制对访问条件变化的适应能力。

GriddingMachine、GriddingMachineDatasets、Emerald及研究材料仓库在多环境持续集成中保持自动运行。统一的项目依赖、参考数据和模型接口形成可持续维护机制，使软件更新能够持续继承本文建立的数据生产、可信分发和模型调用能力。

## 5 讨论

### 5.1 从数据集合到可维护工作流

2022版GriddingMachine建立了统一网格、变量约定和标签化数据访问[4]。当前更新进一步形成共享配置契约、显式源维度映射、与软件版本解耦的数据目录、事务式多镜像获取和模型就绪接口。14类真实陆面产品、校园网FTP—Zenodo获取和多环境运行共同展示这些能力，GriddingMachine由此从标准数据集合演进为连接生产、分发、读取和模型调用的数据生命周期框架。

新版框架在三个层次推进GriddingMachine：生产端以共享YAML契约连接维度、坐标、Gapfill和标准NetCDF；分发端以独立目录、直接NetCDF与事务缓存连接机构镜像和公共镜像；应用端以统一读取、Emerald最小步进和真实`gm2`陆面链路连接数据产品与模型。OISST等真实异构原始产品将进一步拓展源数据标准化和科学应用范围。

### 5.2 与相关地球科学数据基础设施的关系

Earth Engine把大规模地理空间数据与云端计算结合，服务行星尺度分析[3]；ESGF通过分布式节点、搜索和联合身份基础设施支撑气候模式数据的发现与访问[9]；Pangeo倡导分析就绪、云优化数据以及计算与数据邻近的云原生模式[10]，Pangeo Forge进一步以可复用配方和目录组织分析就绪数据生产[11]。GriddingMachine与这些基础设施形成互补，面向经过选择和统一的全球规则网格产品，以及需要在本地Julia工作流中按固定标签复现参数与气象驱动的模型使用场景。

GriddingMachine的互补性体现在三个层次：以YAML保留从异构源数据到标准NetCDF的处理意图；以轻量目录连接机构镜像和通用存储；以`read_dataset`、`grid_dict`和`grid_weather`把标准数据组织为模型所需字段。Pangeo Forge侧重云端分析就绪数据生产的配方—基础设施分离[11]，本文流程侧重可直接下载的单体NetCDF、离线缓存、完整性落盘和固定模型接口。云优化分块格式适配超大规模近数据计算[10]，ESGF适配CMIP等机构联合治理[9]，GriddingMachine则服务可下载、可本地缓存的全球规则网格数据及其模型输入组织。

国内地球系统科学数据共享研究强调目录体系和规范关键词对数据管理与检索的作用[12]；Pooch以文件名、URL和SHA-256注册表实现远端文件获取、本地缓存和完整性校验[13]；STAC为广泛地理空间资产提供通用元数据结构与查询标准[14]。GriddingMachine进一步面向规则网格和模型标签，将上游生产配置、标准NetCDF、事务式多镜像落盘和下游模型字段组织置于同一机器可执行契约中，形成具有领域针对性的端到端整合。

### 5.3 FAIR与可复现性建设

标签和外置目录提高数据的可发现性，多URL和直接NetCDF增强获取能力，统一网格与变量约定促进互操作，来源、许可、处理记录和版本信息支撑复用[1]。FAIR4RS强调科研软件的可执行性、复合依赖、持续演化和版本管理[15]；TRUST原则进一步提出透明度、责任、用户关注、可持续性和技术能力[16]。GriddingMachine以权威文件生成`SIZE/SHA256`、下载后校验、目录事务替换和版本化依赖落实技术可复现性。正式release将继续整合镜像登记、来源许可、配置哈希、代码版本和永久归档，形成完整的软件—目录—数据溯源链。

正式release将配置哈希、代码版本、文件大小和SHA-256连接为溯源链，并将实验结果关联到可识别的软件与数据版本[8]。ELEV标准文件已经完成完整性核验、统一读取和重复无损处理，后续元数据迁移将进一步统一来源、单位和修订标签。

### 5.4 后续拓展

下一阶段将沿四条路线扩展。第一，迁移历史YAML，并为非规则网格、区域投影和复杂时间坐标增加数据源专用预处理模块。第二，将方向图复核与坐标单调性、值域和逐点数组断言进一步集成，形成统一质量报告。第三，扩大FTP与Zenodo的文件规模、观测时段和网络环境，建立延迟辅助排序与实际下载表现的长期统计。第四，将真实异构原始产品、2020年ERA5气象序列、长期模型运行和永久软件归档纳入后续版本，持续扩展科学应用与复现深度。

P01流程反馈已转化为固定输入路径和完整YAML示例；`read_dataset`的规则网格索引、植被与非植被入口以及`grid_dict/grid_weather`字段组织均形成自动回归。真实`gm2`陆面链路和Emerald最小步进为进一步开展逐字段科学核对、真实气象驱动、长期模拟和多模型适配提供了稳定接口基础。

## 6 结论

本文在2022版GriddingMachine基础上形成了由共享YAML schema、显式源维度映射、Gapfill、独立目录、直接NetCDF、事务式缓存及统一读取接口组成的可执行数据生命周期。新版能够稳定生成标准产品，在多镜像环境中维护内容完整性；校园网内4个代表性产品通过FTP与Zenodo实现内容一致的双镜像获取，14类真实陆面产品成功生成US-NR1参数字典。

GriddingMachine由此形成面向地球系统模型的轻量数据生产与可信分发基础设施。下一阶段将以真实异构原始产品和ERA5气象驱动扩展端到端科学核对，并通过镜像登记、完整性元数据、不可变release和永久归档持续完善证据链，为全球规则网格数据维护和可复用模型输入提供长期支撑。

## 数据和代码可用性声明

GriddingMachine.jl源代码公开于https://github.com/CliMA/GriddingMachine.jl，数据生产代码公开于https://github.com/jhOo1/GriddingMachineDatasets，Emerald模型接口环境公开于https://github.com/jhOo1/Emerald-paper，实验协议、脚本和结果公开于https://github.com/jhOo1/GriddingMachine_Reaserach。各仓库提供版本化依赖与持续集成配置，投稿版本将通过正式release和永久归档保存软件、数据目录、实验结果、环境文件和绘图脚本。

## 基金项目

【待作者和通讯作者补充基金项目中文/英文名称及编号；如无资助，按期刊要求声明。】

## 作者贡献

姜皓：概念设计、方法设计、软件、数据整理、可视化、初稿撰写【待作者确认】。王玉杰：概念设计、研究指导、项目管理、论文审阅与修改【待作者确认】。

## 利益冲突声明

作者声明不存在利益冲突【投稿前由全体作者确认】。

## AI 工具使用声明

本文准备过程中使用OpenAI Codex辅助整理研究材料与代码差异、检查论文结构、起草和修订部分文字、审查实验脚本、汇总测试结果并辅助图件制作。研究目标、实验设计、验收标准和结论由作者确定；作者核验软件版本、实验数据、文件摘要、图件数值和正文表述，并对研究设计、数据真实性、结果解释及全文承担责任。

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
