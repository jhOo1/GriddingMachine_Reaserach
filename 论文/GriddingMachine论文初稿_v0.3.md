# 面向地球系统模式的全球网格数据库：GriddingMachine框架更新与应用

**姜皓（Hao Jiang）**^1，**王玉杰（Yujie Wang）**^1*

1. 中国科学技术大学地球和空间科学学院，安徽 合肥 230026

姜皓，E-mail：hao.jiang@mail.ustc.edu.cn；ORCID：https://orcid.org/0009-0009-8295-8661

\* 通讯作者：王玉杰，wyujie@ustc.edu.cn

## 摘要

地球系统模式依赖区域至全球尺度的网格数据进行参数初始化和结果验证。尽管当前数据大多采用NetCDF、HDF或GeoTIFF等标准格式，源数据处理规则、单位换算、数据标识和网络分发方式仍存在差异，使得每个模式不得不单独维护数据库，给模式持续更新和验证带来不必要的困难。本文在2022版GriddingMachine基础上，完善数据预处理、数据分发和数据读取流程：以共享YAML配置描述源数据结构及转换规则，以独立目录管理标准化数据的标签、镜像和完整性信息，并通过统一接口组织陆面参数和气象驱动。除Julia外，我们适配了MATLAB、Octave、Python和R语言对新版数据的自动下载支持，并新增C和Fortran的自动获取入口。这些更新使研究人员能够在 MATLAB、Octave、Python、R、C 和 Fortran 程序中调用统一的数据获取接口，自动下载新版网格数据，并通过 Julia 接口完成标准化数据的读取和模式输入组织，减少不同地球系统模式重复整理和维护数据的工作，为科学研究与应用提供便利。

**关键词：** 地球系统模式；全球网格数据库；数据标准化；NetCDF；数据完整性；模式输入

**A Global Gridded Database for Earth System Models: Advances and Applications of GriddingMachine**

**Hao JIANG^1, Yujie WANG^1\***

1. School of Earth and Space Sciences, University of Science and Technology of China, Hefei 230026, China

Hao Jiang, E-mail: hao.jiang@mail.ustc.edu.cn; ORCID: https://orcid.org/0009-0009-8295-8661

\* Corresponding author: Yujie Wang, wyujie@ustc.edu.cn

## Abstract

Earth system models rely on gridded data at regional to global scales for parameter initialization and evaluation of simulation results. Although most datasets are available in standard formats such as NetCDF, HDF, or GeoTIFF, differences in source-processing rules, unit conversion, data identification, and distribution methods require each model to maintain its own database, creating unnecessary difficulties for continued model development and evaluation. Building on the 2022 release of GriddingMachine, this study improves data preprocessing, distribution, and data reading. Shared YAML configurations describe source data structures and transformation rules; an independent catalog manages dataset tags, mirrors, and integrity metadata; and unified interfaces organize land parameters and meteorological forcing. In addition to Julia, we have adapted automatic downloading of the updated data for MATLAB, Octave, Python, and R, and added automatic data retrieval entry points for C and Fortran. These updates enable researchers to process, retrieve, and access gridded data through a consistent workflow, reducing repeated data preparation and maintenance across Earth system modeling workflows and facilitating scientific research and applications.

**Keywords:** Earth system models; global gridded database; data standardization; NetCDF; data integrity; model input

## 1 引言

地球系统模式以数值方法描述大气、海洋及其相互作用，其参数初始化、边界条件、气象驱动和结果验证均依赖区域至全球尺度的网格数据。此类数据由多个研究团队和业务机构提供，在文件格式、空间投影、维度顺序、经纬度方向、时间组织、单位、缩放方式、缺失值表示和元数据结构等方面存在差异。研究人员需要完成数据发现、下载、重排或重投影、数值转换、质量检查和模式接口适配，才能将可获得的数据用于可重复的模式计算。因此，科学数据管理正在由单纯的数据公开转向强调可发现（**F**indable）、可获取（**A**ccessible）、可互操作（**I**nteroperable）和可复用（**R**eusable）的 FAIR 原则[1]。NetCDF具有自描述、跨系统和适合多维数组等特点，便于保存多维网格及其坐标信息[2]。然而，对于面向固定版本、离线缓存和模式直接调用的工作流，研究人员仍需要把数据转换规则、标准产品标识、网络获取内容和下游模式接口连接起来。建立适用于本地运行的标准化科研数据库，可以将这些环节组织为可追溯、可复用的数据流程，减少重复整理，保证模式输入的一致性，并便于研究人员在不同计算环境中复现实验。

Wang等[4]于2022年发布了基于Julia语言的GriddingMachine数据库和软件，旨在将常用于陆面和地球系统模拟的全球数据处理为具有统一空间和变量约定的NetCDF文件，并通过标签、数据库文件Artifacts.toml和Julia语言的artifact机制实现数据管理与自动下载，同时提供Julia、MATLAB、Octave、Python和R接口。2022版已经建立了统一网格约定、数据标签和多语言访问基础，但仍存在三方面局限：数据生产主要依赖数据集专用脚本，处理规则难以共享；标准化数据以带有标签文件的`tar.gz`归档分发，增加了获取和读取环节；数据目录随软件包维护，数据更新与软件发布耦合。随着数据类型、分发位置和模式应用链条扩展，源数据处理、数据分发和模式输入之间需要进一步统一。

针对上述问题，改进方向应当同时覆盖数据生产和模式使用两个环节：用共享配置显式记录源数据维度、坐标、数值变换和缺失值处理，用独立目录维护数据标签、版本、镜像及可核验的完整性信息，并用统一读取接口把标准化数据组织为模式需要的参数、驱动和时间序列。这样的设计可以使数据处理规则、数据目录和访问软件分别维护，同时通过稳定标签和标准 NetCDF 保持衔接。

本文在 2022 版 GriddingMachine 基础上，更新数据预处理、数据分发和数据读取流程，形成数据生产与标准化、数据目录与获取、模式输入组织三个相互衔接的环节。数据生产与标准化层以共享 YAML 配置规范表达源维度、坐标、数值变换、Gapfill 和质量控制；数据目录与获取层以逻辑标签连接数据副本，并对登记了文件字节数和 SHA-256 的条目执行内容核验；模式输入组织层通过统一读取、陆面参数融合和气象驱动组织形成满足模式接口要求的数据结构。

在上述框架基础上，研究通过受控数据处理实例、真实网格数据标准化、网络镜像获取和模式输入案例，评价新版框架的数据一致性、可执行性和接口适配能力；同时适配 MATLAB、Octave、Python 和 R 对新版数据的自动获取，并新增 C 和 Fortran 的自动获取入口。

## 2 框架设计与关键方法

### 2.1 总体架构与数据生命周期

GriddingMachine新版围绕三个相互衔接的生命周期层次组织（图1）：数据生产与标准化层负责把来源、结构和数值约定不同的地学数据转换为标准NetCDF；数据目录与可信分发层负责维护标签、版本、镜像和完整性元数据，并使数据目录能够独立于`GriddingMachine.jl`软件包版本更新；模式输入组织层负责数据发现、获取、读取以及陆面参数和气象驱动组织。数据生产与标准化层主要由`GriddingMachineDatasets`承担，数据目录与可信分发层及模式输入组织层主要由`GriddingMachine.jl`承担。三层共同形成“生产—质控—发布—发现—下载—读取—模式调用”的数据生命周期，其中各层通过标准NetCDF和稳定标签衔接，同时保留独立演化的维护边界。

![图1 GriddingMachine从2022版基线到新版数据生命周期的架构更新](figures/图1_GriddingMachine总体架构_终稿.svg)

**图1 GriddingMachine从2022版基线到新版数据生命周期的架构更新** （a）2022版以数据集专用脚本、`tar.gz`文件、包内数据目录和`read_LUT`构成数据预处理、分发与读取路径；（b）新版由数据生产与标准化层、数据目录与可信分发层和模式输入组织层构成，依次连接异构源数据、共享YAML契约、标准化与质量控制、标准NetCDF、独立数据目录、完整性获取以及统一读取和模式调用；（c）O1—O5依次表示统一数据契约、简化数据文件、目录独立演化、事务式获取和模式就绪接口。橙色虚线标示各项更新相对于2022版基线及新版核心节点的对应关系。

**Fig. 1 Architectural updates from the 2022 GriddingMachine baseline to the updated data lifecycle.** (a) The 2022 release connected dataset-specific scripts, `tar.gz` artifacts, an in-package catalog, and `read_LUT` across data preprocessing, distribution, and access. (b) The updated lifecycle comprises a data production and standardization layer, a catalog and trusted-distribution layer, and a model-input organization layer, connecting heterogeneous source data, a shared YAML contract, standardization and quality control, standard NetCDF data, an independent catalog, integrity-verified acquisition, and unified reading and model invocation. (c) O1--O5 denote the unified data contract, simplified data artifacts, independent catalog evolution, transactional acquisition, and model-ready interfaces. Orange dashed lines map these updates to the corresponding baseline components and core nodes in the updated workflow.

三层之间以标准NetCDF和数据标签衔接。源数据与YAML配置共同进入预处理流程，经维度、坐标和数值检查后生成标准化文件；数据目录登记文件位置、镜像与完整性信息，数据获取模块据此下载和核验；读取接口再将多个数据集组织为格点参数和气象驱动。本文以“数据生命周期”描述这一从源数据整理到模式调用的连续过程。

这种组织方式将数据处理规则、数据目录和访问软件分开维护。数据源发生变化时可调整配置，分发位置发生变化时可更新目录，模式侧则通过标签保持调用方式一致。各环节的具体方法分别见第2.2—2.4节。

表1概括2022版与新版的主要差异及其在数据生命周期中的作用。

**表1 2022版与新版GriddingMachine的功能和技术路线比较**

| 环节 | 2022版 | 新版 | 对科研流程的作用 |
|---|---|---|---|
| 分发单元 | NetCDF的`tar.gz` artifact | 可直接读取的`.nc` | 简化数据获取并降低端到端读取时间 |
| 数据目录 | 软件内置`Artifacts.toml` | 独立`Artifacts.yaml`；配置规范校验、事务更新和版本备份 | 数据集可独立于软件版本持续扩展 |
| 下载 | artifact哈希寻址、多个URL和解包 | 延迟信号辅助排序；多URL回退、独立临时文件；带`SIZE`/`SHA256`条目可执行严格核验后落盘 | 将镜像选择与内容完整性判定分离，支持历史目录平滑迁移 |
| 读取 | `read_LUT` | `read_dataset`，旧名称保留为别名 | 全球规则经纬网整场、周期和站点读取 |
| 模式组织 | 标准化数据和通用读取 | 陆面参数融合与气象驱动组织 | 标准化数据进入Emerald参数组织与模式初始化 |
| 数据生产 | 数据源专用处理及贡献流程 | 共享YAML配置规范、程序化与交互式配置生成及显式源维度映射 | 形成共享的标准化数据生产工作流 |

**Table 1 Comparison between the 2022 release and the updated GriddingMachine.** The table summarizes the implemented mechanisms, workflow advances, and application value across the data lifecycle.

### 2.2 YAML驱动的数据生产与标准化

#### 2.2.1 数据契约与维度映射

GriddingMachine采用NetCDF格式组织多维数组、坐标和自描述元数据，便于不同地球科学软件读取[5]。2022 年版本已经规定数据采用二维或三维规则经纬网，前两维依次为经度和纬度，可选第三维表示周期；经度自西向东、纬度自南向北，输出保存为实际物理值，缺失值在读取后统一表示为 `NaN`，主变量和不确定性变量分别命名为 `data` 和 `std`[4]。新版延续这些核心约定，并将源维度映射、处理记录、版本化配置和分发完整性纳入相互衔接的机器可读规范（表2）。

**表2 GriddingMachine 标准 NetCDF 数据与元数据规范**

| 类别 | 新版规范 | 实现方式 |
|---|---|---|
| 文件与网格 | 一个标签对应一个可直接读取的`.nc`；规则经纬度网格，默认全球覆盖并声明坐标参考 | NetCDF统一保存数据、坐标与自描述元数据 |
| 维度 | 二维`(lon, lat)`；三维`(lon, lat, ind)`；源维度按名称映射到标准顺序 | 通用维度映射将多种源排列转换为统一结构 |
| 坐标方向 | `lon`自西向东并统一到`[-180, 180)`；`lat`自南向北 | 翻转和循环平移保持数据与坐标同步 |
| 数据变量 | `data`为主变量；`std`保存同形不确定性；输出为实际物理值 | 统一变量命名、类型、单位和数值表达 |
| Gapfill与范围 | 有效范围、填充值和Gapfill策略由YAML显式声明 | 支持数值常数、`MEAN`、`KEEP_AS_IS`、`INT_NAN_TO_1`、`NO_LAND_NAN`和`NO_NAN` |
| 变量元数据 | `data/std`记录可读说明、单位及处理变更条目 | 输出文件保留变量语义与主要转换过程 |
| 处理记录 | YAML声明维度、坐标、数值与Gapfill规则；NetCDF属性写入逐项变更记录 | 配置意图与数据集处理历史相互对应 |
| 处理复现 | `SCHEMA_VERSION`、完整YAML、固定输入和版本化项目环境共同归档 | 配置、输入与代码版本共同重建标准化数据 |
| 标签与版本 | 标签表达类别、空间/时间分辨率、年份、版本和可选修订号 | 标签与文件名共同形成稳定数据集标识 |
| 分发完整性 | 新登记或严格完整性条目记录文件字节数和SHA-256；同一标签的受控镜像指向相同内容 | 对带完整性元数据的条目下载后核验并以事务方式进入正式目录；历史条目由兼容模式承接 |

**Table 2 Standardized NetCDF data and metadata requirements of GriddingMachine.** The specification connects grid structure, gap filling, metadata, provenance, versioning, and distribution integrity within a unified production contract.

缺失值填补（gap filling，以下简称Gapfill）由YAML中的`GAPFILL`字段驱动，并依据数据集物理含义选择相应策略。数值常数和`MEAN`分别以给定值或分层`nanmean`填补陆地区域缺失值；`KEEP_AS_IS`保持原始数组；`INT_NAN_TO_1`将缺失值补为1并对数组整数化；`NO_LAND_NAN`和`NO_NAN`分别检查陆地区域与全域的数据完整性。Gapfill由此统一连接有效范围过滤、陆海掩膜、缺失值处置和输出精度，为不同地球系统数据集提供可配置的数据完善方法。高程数据（ELEV）采用常数0填补策略，为统一读取和模式调用提供连续地形场。

CF约定利用坐标变量和属性表达维度语义[2]。GriddingMachine进一步固定输出维度顺序，以降低下游接口复杂度。新版通过YAML的`DIMENSIONS`显式记录源变量各维度语义，维度标准化过程将`(lat, lon)`、`(ind, lat, lon)`等排列重排为统一输出；经纬度翻转与循环平移同步作用于坐标和数据值。规则经纬网数据进入通用标准化流程，非规则网格、区域投影和复杂坐标数据由数据源专用预处理模块完成适配。

#### 2.2.2 YAML配置与转换示例

YAML将数据源差异与通用处理代码分离。配置以`FILE`、`FOLDER`、`DATA`（及可选`STD`）和`GRIDDINGMACHINE`组织文件组合、输入输出位置、变量语义与转换规则以及稳定标签，并通过`SCHEMA_VERSION`约束字段类型、必需项、默认值、互斥关系和数组长度一致性。`DIMENSIONS`显式记录源变量的维度语义，`GAPFILL`、坐标方向、数值范围和缩放规则在数据读取前完成解析；配置构建器与生产流水线调用同一规范。

受控二维示例采用`(lat, lon)`源维度排列，纬度按北向南排列，经度范围为`0°～360°`。配置文件显式声明源维度语义、纬度方向转换、经度范围转换和线性数值变换，生产流水线据此生成标准`(lon, lat)`数据集。输出坐标和数值与独立构造的参考数组逐点一致，用于验证配置声明能够被正确映射为标准化处理过程。完整YAML配置、字段说明、执行命令和目录结构列于补充材料S3及版本化贡献指南。

框架同时提供程序化和本地交互式配置生成方式。二者输出均经同一配置规范校验后进入`process_dataset!`，使数据贡献入口与生产流水线共享一致的字段语义。

#### 2.2.3 生产流程与质量控制

标准化数据生产引擎首先根据`FILE`和`FOLDER`定位输入与输出文件，再读取`DATA`和可选`STD`指定的源变量。流水线将数据转换为`Float32`，依次执行纬度翻转、经度翻转或从`0°～360°`到`−180°～180°`的循环平移、线性缩放、有效范围过滤和缺失值处理。各项转换追加为NetCDF变量属性中的变更记录；研究材料进一步将完整YAML、固定输入和版本化项目环境与输出数据集共同归档。

生产流程在保存前检查维度、坐标、变量、数值范围和Gapfill结果，空间方向图进一步呈现坐标语义。质量控制完成后生成`data`，存在不确定性时追加同形的`std`，并按`TAG_(PREFIX_)NX_MT_(YYYY_)VV(_REVISION)`生成唯一文件名。文件级变更记录与发布级配置、输入和软件环境共同构成双层复现链，连接数据集内容与其生成上下文。

空间方向检查依据变量维度生成带经纬度坐标轴的审核图，人工确认与自动结构、坐标和逐点数值检查相互补充；`VERIFY_ONCE`用于记录同一配置组合的首次方向确认。输出数据质量检查进一步核对`lon`、`lat`及可选`ind`维度、主变量`data`、数值范围和缺失值状态。对于标准支持分辨率，陆地区域完整性通过重采样`LM_4X_1Y_V1`掩膜检查；其他分辨率由专用规则承接。由此，生产阶段的变换记录、自动判据和必要的空间方向审核共同构成标准化数据质量控制。

### 2.3 独立数据目录与事务式多镜像分发

标准化数据标签由类别、可选前缀、空间分辨率、时间分辨率、可选年份、数据版本和可选修订号构成，基本形式为`TAG_(PREFIX_)NX_MT_(YYYY_)VV(_REVISION)`。数据发布与目录登记相互解耦：维护者可将标准NetCDF发布到机构文件传输协议（File Transfer Protocol，FTP）服务器、HTTP(S)服务或Zenodo科研资源存储平台，目录生成器根据本地权威文件和公开地址生成逻辑路径、去重镜像列表，并对新登记或需要严格完整性管理的条目计算文件字节数和SHA-256。目录通过临时文件写入和替换，使数据集列表、镜像位置和完整性元数据能够独立于访问软件版本更新。

`GriddingMachine.jl`的Collector显式配置数据根目录、目录来源和本地目录文件。远端目录先下载至临时路径，经根节点和字段规范校验后再替换正式目录，并保留上一有效版本。目录条目以标签为键，核心字段包括安全相对路径`PATH`、一个或多个`URL`以及可选的`SIZE`与`SHA256`。严格完整性模式要求后两项同时存在，兼容模式保持历史条目的标签访问；目录规范和获取逻辑对多URL与完整性字段采用统一表达。

数据集获取以标签为入口。系统保留目录中的全部镜像，并在存在可用延迟信号时辅助安排候选顺序；文件内容统一依据目录完整性元数据判定。每次镜像尝试写入进程级唯一临时文件，对带完整性元数据的条目检查文件状态、字节数和SHA-256，通过后移动至正式路径；各镜像尝试相互隔离，正式路径始终对应最近一次通过核验的数据集。全库同步、状态查询和历史数据整理复用相同目录与获取逻辑。

这一设计将镜像选择与内容完整性判定分离：镜像和延迟信息用于组织候选顺序与回退，目录中的标准化数据标识与完整性字段用于内容核验。多镜像实验选取已配置多个镜像和完整性元数据的代表性数据集，综合评价候选遍历、内容核验和事务式落盘机制；相关接口、状态恢复流程和目录条目示例见补充材料。

### 2.4 统一读取与模式输入组织

#### 2.4.1 标准网格数据读取

标准网格数据读取接口支持以本地NetCDF路径或数据标签访问数据，并提供整场数组、指定周期切片、站点全部周期和站点指定周期4种读取方式。标签对应的NetCDF可由目录模块自动获取；默认返回标准变量`data`，也可读取原始数值或同形不确定性变量`std`。模式输入组织层直接继承数据生产与标准化层统一的单位、缺失值和物理范围，使处理规则集中于共享生产契约，并兼容既有读取方式。

站点读取依据全球规则经纬网分辨率把经纬度映射为数组索引，并以标准文件的`(lon,lat[,ind])`顺序及西向东、南向北排列为输入契约。接口面向全球规则网格的原位索引，区域投影、非规则网格和空间插值可在数据生产与标准化层完成转换；周期索引的月份、日期或小时含义由对应数据元数据解释。

#### 2.4.2 模式参数与气象驱动组织

格点尺度陆面参数组织接口从预定义数据集合中提取土壤、冠层、叶片、地形、陆地掩膜和植物功能型数据，依据陆面状态融合相应参数，并对叶面积指数、叶绿素、冠层聚集度和最大羧化速率等季节序列执行Gapfill与逐日重采样。第二套陆面参数集合`gm2`由14类标准化数据组成，其中冠层聚集度采用月尺度数据集，其余字段按各自空间与时间分辨率进入统一格点。

植物功能型比例进一步用于融合C3/C4植被的叶片光学参数和Medlyn气孔参数，并由`VCMAX25`推导`JMAX25`和`B6F`。输出涵盖位置、分辨率、年份、CO₂、土壤水力性质、冠层结构、植物功能型组成、叶片生物物理和光合参数；字段完整性与`NaN`状态同步进入质量控制。多个标准化数据由此形成结构一致的格点级模式输入。

格点尺度气象驱动接口按年份和格点读取气象驱动集合`wd1`中的8类第五代全球再分析数据（ERA5）[6]，分别提取地表气压、降水、漫射与直射短波辐射、长波辐射、气温、水汽压亏缺和风速，并依据格点经度换算时区偏移、构建浮点年积日`FDOY`。接口既可直接按经纬度读取，也可从已经加载的全局气象数组提取格点序列，输出字段完整性与`NaN`状态同步进入质量控制。

标签驱动的数据访问、陆面参数融合与气象驱动组织共同构成模式输入组织层。本文将“模式就绪”界定为：标准化数据经过格点索引、字段组织、时间轴构建和量纲衔接后，形成满足Emerald初始化接口的数据结构。与2022版通过标签组织数据访问的思路一致[4]，新版进一步把目录配置与更新、完整性获取、标准网格读取和模式输入组织连接为连续公共数据流。用户以数据标签发现数据集，经镜像获取，并在目录提供完整性元数据时执行内容核验，再读取整场、周期或格点数据，并形成陆面参数或气象驱动；具体公共接口、调用参数和完整Julia示例列入补充材料与版本化用户指南。

### 2.5 多语言数据下载接口

为衔接不同科研编程环境，新版提供MATLAB、Octave、Python和R的数据下载入口，并增加C和Fortran入口。非Julia入口调用同一Python下载脚本，使用时需要Python 3运行环境。MATLAB/Octave函数、R函数及C和Fortran程序接收文件URL和本地输出路径，调用脚本完成直接NetCDF下载；Python脚本还支持依据本地Artifacts.yaml中的标签查找下载地址，并在目录或调用参数提供相应信息时检查文件大小和SHA-256。

该设计将各语言的调用方式与下载逻辑分开维护，使科研人员可以在已有程序中自动获取文件，再使用相应语言的NetCDF工具读取数据。非Julia接口的源码和调用说明随代码仓库的`clients`目录提供。

## 3 应用案例与评价方法

本节从数据标准化、文件获取和模式输入三个方面评价框架。案例包括最优插值海表温度数据（Optimum Interpolation Sea Surface Temperature，OISST）、高程数据（ELEV）、叶面积指数数据（Leaf Area Index，LAI），以及US-NR1站点附近格点的陆面参数和气象驱动。表3列出各项方法对应的受控实验、真实数据与网络案例及评价指标；跨操作系统测试用于检查相同依赖和判据下的运行一致性。

**表3 GriddingMachine框架核心贡献、证据层级与主要评价指标**

| 核心贡献 | 受控或确定性证据 | 真实数据/网络应用 | 主要评价指标 |
|---|---|---|---|
| 数据生产与标准化层将异构源数据转换为标准NetCDF | 31组受控实例、ELEV重复生产与逐点核对 | OISST V2.1真实异构源数据 | 维度与坐标、有效值掩膜、逐点物理值、重复生成摘要 |
| 数据目录与可信分发层组织高效且内容可核验的数据获取 | ELEV/LAI回环HTTP对照；13类受控状态场景 | Zenodo公共网络记录；校园网FTP—Zenodo同文件获取 | 端到端时间、传输字节、候选遍历、`SIZE`/SHA-256、临时与正式文件状态 |
| 模式输入组织层将标准化数据组织为模式就绪输入 | 确定性读取、字段、时间轴与接口核对 | US-NR1的14类陆面数据集、8类ERA5及Emerald初始化和60 s首步 | 字段与形状、时间轴、量纲、逐点数值、初始化与首步状态 |
| 核心实现具有跨操作系统运行一致性 | Windows、macOS、Linux持续集成 | Windows/macOS独立性能观测及按实际环境记录的真实网络案例 | 数据集结构、逐点数值、文件摘要、缓存状态和接口状态 |

**Table 3 Core contributions, evidence levels, and evaluation metrics for the GriddingMachine framework.** Controlled experiments and real-data or real-network applications are listed separately, and the final column summarizes the principal metrics used for each contribution.


### 3.1 数据生产与标准化及OISST案例

#### 3.1.1 共享生产契约与质量控制

为展示YAML驱动流程对多维地学数据的标准化能力，本文设计具有明确空间语义的位置编码数组：二维数组由经纬度索引共同编码，三维数组进一步加入周期索引。该设计能够清晰呈现维度交换、方向翻转、经度平移和周期组织前后的对应关系，并为标准NetCDF生产提供逐点参照。

代表性处理实例包括`(lon,lat)`与`(lon,lat,ind)`标准输入、`(lat,lon)`与`(ind,lat,lon)`源排列、纬度和经度翻转、`0～360°`经度平移、线性缩放、范围过滤、Gapfill、`data/std`保存和标签生成。配置字段、变量数量、已有数据集和标签状态共同覆盖标准化数据从源数据到目录登记的主要环节。

共享生产契约的受控评价从维度、坐标、数值、Gapfill、YAML配置、输出和空间方向7个方面组织31组代表性处理实例。各组对应生产流程中的一个关键操作，并以结构、逐点数值或数据集状态表征标准化结果；完整分类矩阵见补充材料S4。
数据集质量控制覆盖变量、维度、形状、属性、坐标方向、数值范围和Gapfill结果。输出数组与位置编码参照逐点对应，Float32转换采用统一的绝对和相对容差；配置与数据集状态通过明确的流程信息反馈给维护者。质量报告同步保存最大绝对误差、最大相对误差、处理历史和重复生产一致性。

29组非交互处理实例在Windows、macOS和Linux持续集成环境中采用相同判据运行；V01和V02空间方向图分别设置正向和南北反转预期。自动结构与数值检查和人工空间审核共同评价生产契约在数组变换、配置解析和空间方向控制方面的跨系统一致性。

配置构建器面向二维数据、含不确定性变量的三维数据和经纬度变换数据生成符合共享配置规范的YAML，并将其直接交给标准化数据生产引擎。数据贡献案例进一步贯通配置生成、标准化、自动与人工质量检查、数据集发布、目录登记以及下游更新、下载和读取，形成覆盖主要环节的数据贡献入口。

#### 3.1.2 OISST异构数据集标准化

OISST案例用于检验共享配置对真实异构源数据的适配。采用美国国家海洋和大气管理局国家环境信息中心（NOAA/NCEI）发布的0.25°逐日OISST V2.1数据，选用仅使用甚高分辨率辐射计（AVHRR）数据的版本[7]，选取2022年2月25日文件。原始`sst`变量在NetCDF中声明为`time×zlev×lat×lon`，其中`zlev`和`time`均为单例维度；Julia读取后的数组顺序为`lon×lat×zlev×time`，形状为1440×720×1×1。经度覆盖0.125°～359.875°，存储类型为Int16，并以0.01缩放因子解码为摄氏度。

版本化源适配器提取唯一的垂向层和时间层，共享YAML契约进一步完成维度声明、`0°～360°`至`[−180°, 180°)`的经度重排、有效范围控制和缺失值策略，生成`SST_OISST_4X_1D_20220225_V1`标准化数据。

独立参考流程直接读取未缩放的Int16存储值，根据原始`scale_factor`、`add_offset`和`_FillValue`构造物理值与缺失值掩膜，并独立计算目标经度索引。参考结果记录全场统计量、10个确定性有效格点和10个缺失格点。标准化数据连续生成3次，逐点比较坐标、有效值掩膜和物理值；随后由权威文件生成包含逻辑路径、镜像地址、字节数和SHA-256的目录条目，通过回环HTTP执行事务式下载，并以统一读取接口完成整场核对。

### 3.2 ELEV与LAI的直接NetCDF分发效率评价

直接NetCDF分发效率采用二维静态高程（ELEV）`ELEV_4X_1Y_V1`和三维8日叶面积指数（LAI）`LAI_MODIS_2X_8D_2020_V1`进行分析，代表不同规模和维度的内部压缩数据集。每个标准NetCDF分别以原始`.nc`和包含同一文件的`tar.gz`分发，对照归档采用gzip级别6。两种形式解包后的NetCDF具有相同SHA-256，据此量化省去外层打包与解包带来的时间和临时空间收益。

性能分析在Windows（环境A）和macOS（环境B）中采用回环HTTP服务。每个“数据×分发形式”组合经过缓存预热后按随机顺序测量10次，记录传输字节数、打包与解包时间、从请求开始到首次读取NetCDF值的端到端时间，以及下载文件与解包文件并存时的逻辑临时占用。两个独立环境使用一致的脚本和输入文件，时间指标以中位数、四分位距和95% Bootstrap置信区间表示。

### 3.3 多镜像获取与内容完整性

数据目录生命周期涵盖首次建立、版本更新、目录同步、数据集获取、状态查询和历史数据整理。代表性目录包含不同版本的`Artifacts.yaml`、多个NetCDF数据集和两个镜像端点，并覆盖目录更新、单数据集获取、全库同步、历史整理和状态查询。各状态转换通过重复调用考察幂等行为，确定性小型目录参考数据用于呈现事务缓存、正式数据区、全库同步与镜像遍历逻辑。

多镜像分析在两个独立环境中构建内容一致、访问状态可配置的镜像集合，通过延迟分数组织候选顺序，并设置13类受控状态场景，覆盖候选排序、镜像回退、网络访问异常、缓存命中、内容完整性异常和候选耗尽过程。每类场景在各环境中重复5次，记录候选选择、镜像遍历、正式文件状态及SHA-256，据此刻画事务式获取在镜像切换过程中的文件选择、校验与落盘行为。校园网机构FTP与Zenodo公共存储的访问进一步呈现机构镜像和公共镜像的互补分发特征与内容一致性；完整场景矩阵列于补充材料S6。

镜像访问实验选取4个同时具有FTP和Zenodo地址且已登记`SIZE`与`SHA256`字段的代表性标签，对各文件—镜像组合开展重复下载，记录候选顺序、传输时间、字节数和SHA-256。公共网络观测刻画Zenodo镜像获取特征；中科大校园网实验对FTP与Zenodo执行同文件只读下载，共形成24次完整性记录。实验数据与环境信息随可复现材料归档。

### 3.4 统一读取与模式输入组织

模式输入组织案例连接标准网格读取、陆面参数融合、气象驱动组织与Emerald初始化。确定性参考数据用于核对字段名、形状、类型、时间索引和缺失值处理；陆面案例采用2020年第二套陆面参数集合，在US-NR1研究站点附近植被格点和典型非植被格点呈现不同陆面状态下的模式入口。

真实气象案例使用同一年度的8类ERA5标准化数据[6]：地表气压、降水、漫射与直射短波辐射、长波辐射、气温、水汽压亏缺和风速。八文件从中科大机构FTP只读获取，总大小为12 575 376 138字节，并逐文件记录SHA-256。US-NR1坐标（40.0329°N、105.5464°W）由规则索引映射到40.5°N、105.5°W格点；2020年为闰年，预期每个字段包含8784个逐小时值。实验同时核对8个`data`变量的`lon×lat×ind`维度、360×180×8784形状及单位属性。模式输入组织层输出与底层NetCDF直接读取的同一格点序列逐点比较；`FDOY`另按经度/15计算时区偏移并独立重建。随后把真实陆面参数和真实气象驱动共同传入Emerald，检查初始化和60 s首步后的大气、土壤状态是否均为有限值。

### 3.5 跨操作系统运行一致性设计

跨操作系统运行一致性采用本地运行与持续集成相结合的设计。Windows和macOS本地环境运行生产矩阵、ELEV/LAI分发效率、13类受控状态场景以及核心软件与Emerald接口；Linux与另外两个系统的干净持续集成环境运行29组非交互生产实例、40次确定性分发测量、65次镜像状态核对、核心软件功能和Emerald最小接口。统一项目依赖与参考数据用于比较数据结构、逐点数值、正式文件摘要和接口状态。

真实FTP—Zenodo访问按照实际网络环境单独记录，US-NR1真实陆面和ERA5链路作为应用案例归档。由此形成“多系统确定性核心路径—独立环境性能观测—真实网络与数据应用”三个层次的复现设计；完整系统—模块—证据矩阵见补充材料S5。

## 4 结果

按照表3所列评价设计，以下依次呈现标准化数据生产、直接NetCDF分发效率、多镜像获取、模式输入组织和跨操作系统运行一致性结果。

### 4.1 数据生产与标准化及OISST结果

#### 4.1.1 共享生产契约与质量控制结果

31组处理实例覆盖维度、坐标、数值、Gapfill、配置、输出和空间方向控制，其中29组非交互实例在三系统持续集成环境中获得一致的数据集结构和逐点数值结果；人工空间审核分别接受正向图并识别南北反转图，与预设方向结果一致。数据贡献案例进一步贯通YAML配置、标准化数据生成、目录登记和下游读取，生成数据集与参考数组逐点一致，目录中的文件字节数和SHA-256与数据集相符。

ELEV补充案例使用已通过文件大小和SHA-256校验的`ELEV_4X_1Y_V1.nc`。该文件为1440×720、全域有效，有限值范围为−415.5～5 357.7002 m；GriddingMachine整场读取与NetCDF底层Float32数组逐点一致。使用显式标准维度、`KEEP_AS_IS`和原值保持配置连续处理3次，三次`data/lon/lat`均与输入一致，输出文件SHA-256也彼此相同，表明标准化数据经过统一读取和生产流水线后保持科学数组及坐标。

#### 4.1.2 OISST异构数据集标准化结果

OISST案例展示了共享生产契约对异构地学源数据的组织能力。原始`sst`变量在Julia读取路径中呈现为1440×720×1×1的`lon×lat×zlev×time`数组，经单例层提取、Int16物理值解码和经度重排后形成1440×720标准化数据。输出经度由−179.875°递增至179.875°，纬度由−89.875°递增至89.875°；691 150个有效格点和345 650个缺失格点与独立参考逐点一致，海表温度范围为−1.80～32.39 ℃，全场平均值为14.013 ℃，最大绝对差为0。

标准化数据连续生成3次，科学数组、坐标和文件SHA-256均保持一致。生成文件为997 006字节，目录条目自动登记相同的字节数和SHA-256；经回环HTTP事务式下载后，正式文件摘要与目录完全一致，传输临时文件全部完成回收。统一读取接口获得的整场数组与独立参考逐点一致，验证了从源数据、共享YAML生产、目录登记到标准读取的端到端数据链路。

![图2 OISST数据标准化结果](figures/图2_OISST真实产品标准化结果.png)

**图2 OISST V2.1数据集标准化结果** （a）2022年2月25日全球海表温度标准化数据；（b）从四维源结构、存储值解码和经度重排到二维标准网格的转换路径；（c）坐标、有效值掩膜、物理值及重复生成摘要的独立参考核对。标准化数据为1440×720规则网格，691 150个有效格点及345 650个缺失格点与独立参考掩膜逐点一致，物理值最大绝对差为0，3次生成的文件摘要相同。

**Fig. 2 Standardization results for the OISST V2.1 product.** (a) Global standardized sea-surface temperature on 25 February 2022; (b) the transformation from the four-dimensional source layout through stored-value decoding and longitude reordering to the two-dimensional standard grid; and (c) independent-reference checks of coordinates, the finite-value mask, physical values, and repeated file digests. The 1440 × 720 product contains 691,150 finite and 345,650 missing cells that match the independently decoded reference mask point by point, with a maximum absolute physical-value difference of zero and identical file digests across three runs.

### 4.2 ELEV与LAI的直接NetCDF分发效率

按照第3.2节的相同输入和测量协议，环境A中直接NetCDF相对外层`tar.gz`将ELEV和LAI的端到端中位时间分别降低48.3%和82.9%；环境B中的相应降幅分别为53.6%和69.2%（图3）。两个数据文件的传输字节分别增加6.43%和2.16%，逻辑临时占用分别减少约48%和49%。80次SHA-256摘要核验结果一致。

两文件均已采用NetCDF内部zlib压缩级别4，对照归档采用gzip级别6。在所测文件和缓存预热条件下，直接NetCDF以较小的传输字节增量减少了解包及临时文件共存开销，缩短了从请求到首次读取数据的路径。

![图3 直接NetCDF与外层tar.gz分发的端到端时间比较](figures/图3_直接NetCDF分发效率.svg)

**图3 ELEV和LAI数据集采用直接NetCDF与外层tar.gz分发的端到端时间比较** （a）二维高程数据集ELEV；（b）三维叶面积指数数据集LAI。空心圆表示各组合的10次独立测量，柱高为缓存预热后端到端时间中位数，误差线为95% Bootstrap置信区间；环境A（Windows）和环境B（macOS）采用相同输入文件与测量协议。柱上百分比表示直接NetCDF相对于外层`tar.gz`归档的中位时间降幅。

**Fig. 3 End-to-end distribution time for the ELEV and LAI products using direct NetCDF and external `tar.gz` archives.** (a) The two-dimensional ELEV product; (b) the three-dimensional LAI product. Open circles show the 10 measurements for each combination, bars show median warm-cache end-to-end time, and error bars show 95% bootstrap confidence intervals. Environment A (Windows) and environment B (macOS) used identical input files and measurement protocols. Percentages above the bars indicate the reduction in median time achieved by direct NetCDF relative to external `tar.gz` archives.

### 4.3 目录管理与事务式多镜像分发

目录与数据获取模块将目录初始化、事务更新、数据集同步、镜像获取、状态查询和历史数据整理组织为统一的数据维护接口。独立目录使数据集能够随镜像和版本持续更新，事务缓存区与正式数据区的分层机制则将传输过程与标准化数据分离，使上一有效目录和已发布数据集在目录更新与镜像切换过程中保持稳定。

13类受控状态场景在两个独立操作系统环境中分别重复5次，共形成130次获取记录。在具有可用延迟分数的场景中，目录与数据获取模块按照延迟辅助排序候选，并在首选镜像访问或内容校验状态变化时依次遍历其余地址。每次获取采用独立临时文件，内容经字节数和SHA-256确认后进入正式路径；所有记录均完成临时文件回收，既有正式文件摘要保持一致。

在校外公共网络观测中，两个独立环境分别对4个Zenodo标签重复获取3次，共形成24次下载记录，全部达到登记字节数并通过SHA-256核验。下载时间随文件规模呈梯度变化，重复传输的SHA-256摘要与目录登记值一致，体现了公共镜像、事务式获取和完整性校验的协同作用。

校园网双镜像实验是另一组独立记录：4个数据集分别从FTP和Zenodo重复获取3次，两类镜像各形成12次下载，共24次结果，均达到登记字节数并通过SHA-256核验。在本组校园网观测中，延迟辅助排序与实际传输顺序一致，机构镜像与公共镜像提供了内容一致的分发副本；分数据集传输时间与网络记录列于补充材料。

ERA5降水数据的单位修订进一步呈现逻辑标签与物理文件的解耦：逻辑标签`PPT_ERA5_1X_1H_2020_V1`保持稳定，目录将其物理URL指向`V1_R1.nc`并登记新的`SIZE`与SHA-256，V1和V1_R1文件以不同后缀并行保留。空缓存Collector实例按V1逻辑标签获取R1文件并通过完整性核验，第二次调用直接复用正式缓存。该案例表明，目录更新能够承接数据修订，同时保持下游逻辑标签和调用接口稳定。

### 4.4 统一读取与模式输入组织

陆面案例使用2020年第二套陆面参数集合的14类标准化数据，文件大小、来源摘要和SHA-256均通过核验。US-NR1站点映射至40.5°N、105.5°W的规则格点，参数融合接口组织34个模式字段、366日季节序列、4个土壤层和17个植物功能型，高程、陆地掩膜与叶面积指数得到一致读取。撒哈拉案例被识别为非植被格点并进入相应的陆面状态分流，体现了参数组织前的场景识别能力。该参数集合由此贯通完整性目录、统一读取和陆面参数组织，并覆盖植被与非植被场景。

真实气象案例读取2020年8类ERA5标准化数据，八文件合计12 575 376 138字节；各`data`变量均为`lon×lat×ind`、360×180×8784，并带有单位属性。US-NR1格点的地表气压、降水、漫射与直射短波辐射、长波辐射、气温、水汽压亏缺和风速均得到8784个逐小时值，有限值比例均为100%；模式输入组织层输出与底层NetCDF逐点读取的8个字段最大绝对差均为0。按站点经度计算的时区偏移为−7.0364 h，`FDOY`严格递增且与独立公式逐点一致。气象驱动组织形成`FDOY`和8类气象共9个字段，Emerald适配后扩展为16个模式驱动字段；真实陆面参数与真实气象共同完成模式初始化和60 s首步计算，大气与土壤关键状态均保持有限值。

量纲审计进一步表明，PPT全年累计值为0.496409 m水层，即496.409 mm。该数值尺度与ERA5逐小时累计降水的米制表达[8]及Emerald由水层厚度转换为摩尔通量的适配关系一致。据此，标准NetCDF中的降水单位属性统一为`m`，使数据元信息、数值尺度和模式换算形成一致的量纲链条。真实年度案例由此覆盖格点提取、时间轴构建、量纲衔接和模式首步计算等主要接口环节。

### 4.5 跨操作系统运行一致性结果

Windows、macOS和Linux持续集成环境分别完成29组非交互生产实例、40次确定性分发测量和65次镜像状态核对，数据集结构、逐点数值、SHA-256摘要、正式文件状态和临时文件回收结果一致。GriddingMachine与GriddingMachineDatasets核心功能以及Emerald合成输入最小接口也在三个系统环境中完成，呈现固定依赖下核心数据路径的跨系统一致性。

Windows和macOS本地环境进一步完成ELEV/LAI性能测量及镜像故障场景，独立公共网络记录完成Zenodo内容核验；校园网环境完成FTP—Zenodo同文件对照，US-NR1案例完成真实陆面与气象数据集的模式输入组织。持续集成、独立环境观测和真实数据案例共同构成分层复现证据，具体系统—模块对应关系列于补充材料S5。

## 5 讨论

### 5.1 相对2022版的更新与科研用途

2022版GriddingMachine已建立统一网格、变量约定、标签访问和多语言接口[4]。本轮更新进一步把数据源专用处理规则整理为共享配置，将数据目录与软件包分开维护，并将标准网格读取延伸到陆面参数和气象驱动组织。其科研用途在于减少不同数据集和模式之间重复编写转换、下载与接口程序的工作，使数据修订能够在明确的配置、目录和文件记录下进行。

OISST案例说明，共享流程可以通过源适配器处理单例维度、存储缩放和经度范围差异，并保留与独立参考逐点核对的路径。ERA5降水修订则表明，逻辑标签可以继续供下游调用，实际文件位置和完整性信息在目录中更新。为重现某次模式计算，研究人员需要同时保存当时的目录、文件摘要和代码版本；稳定标签用于简化调用，版本记录用于确定实际使用的数据。

### 5.2 分发效率与科学数据质量

直接NetCDF减少了单文件外层打包和解包的步骤。对于本文测试的两个内部压缩文件，直接分发虽然增加少量传输字节，但减少了临时占用并缩短缓存预热后的端到端访问时间。这一结果适用于所测文件与协议；其他文件规模、压缩程度和网络带宽下的收益取决于传输与解包开销的相对大小。选择分发方式时，应同时考虑传输量、首次读取时间和本地存储需求。

数据质量检查与下载完整性核验分别解决两个问题：前者检查维度、坐标、物理值、单位和缺失值处理是否符合数据约定，后者检查收到的文件是否与目录登记内容一致。OISST的独立解码比较和ERA5降水单位修订分别体现了数值与量纲检查的作用；受控镜像场景和真实网络下载记录则检验了文件获取的一致性。将两类检查串联，才能从源数据处理一直追溯到科研程序实际读取的文件。

### 5.3 从标准网格数据到模式输入

统一NetCDF格式为数据复用提供基础，模式运行还需要格点对应、参数字段组合、时间轴构建和单位换算。US-NR1案例中，多类陆面数据和逐时气象驱动经过这些步骤形成Emerald所需的输入，应用层字段与底层读取逐点一致，并完成初始化与60 s首步计算。这些结果验证了本文数据组织方法与既定模式接口的衔接。

这一流程可作为其他站点、年份和模式的数据接入参考。迁移时应根据目标模式重新确认空间代表性、时间分辨率、变量定义和单位关系；长期模拟与观测比较则用于进一步评价模式运行效果。Julia主流程与非Julia下载入口分别服务输入组织和跨语言文件获取，研究人员可按已有科研程序的需求选择调用方式。

### 5.4 与相关数据基础设施的关系及扩展方向

NetCDF/CF提供多维数据表达与元数据约定[2,5]，地球系统数据立方体强调多变量时空数据的联合组织与分析[9]。GriddingMachine在这些基础上固定规则网格、变量命名和数据标签，使不同来源的数据能够进入一致的本地读取流程。其核心实现使用Julia[10]，通过可组合的数据处理与读取接口连接标准化过程和模式程序。

Google Earth Engine侧重云端遥感数据访问与计算[3]，ESGF侧重分布式气候模式数据发现和访问[11]，Pangeo及Pangeo Forge支持云端数据组织与可复用的处理配方[12,13]。GriddingMachine面向固定版本、离线缓存和本地模式调用，利用共享配置、数据目录和模式输入接口衔接这些环节。与上述平台的关系主要体现为科研工作流中的分工；本文的本地分发实验也不构成与云端平台的性能比较。

国内地球系统科学数据共享研究强调规范分类和目录建设[14]；Pooch提供科研文件获取与管理工具[15]，STAC提供地理空间数据的目录描述规范[16]。GriddingMachine进一步约定标准网格数据和模式输入的组织方式，为模式研究中的多源数据组合提供统一入口。后续可在保留现有读取方式的同时，加强与通用目录和数据获取工具的衔接。

持续维护需要兼顾软件版本、数据出处和可引用性。科研软件引用原则[17]、FAIR4RS[18]和TRUST[19]分别为软件识别、复用和资源库维护提供参考，国内国家科学数据中心的FAIR实践也强调元数据与使用信息的重要性[20]。当前跨系统测试提供了固定依赖下的运行一致性证据；后续重点是完善数据目录与镜像登记、归档配置和实验环境，并扩展非规则网格源适配及更多模式接口，使数据更新和科研复用保持可追溯。

## 6 结论

本文面向地球系统模式对全球网格数据的使用需求，在2022版GriddingMachine基础上完善了数据预处理、分发和读取。共享YAML配置统一描述源数据转换规则，独立目录组织标签、镜像和完整性信息，统一读取接口将标准化数据进一步组织为陆面参数和气象驱动；多语言下载入口扩展了数据获取的调用方式。

受控实例和真实数据案例为上述更新提供了验证。OISST标准化后的有效格点与独立参考逐点一致；ELEV和LAI在两个测试环境中采用直接NetCDF分发，缩短了缓存预热后的端到端访问时间并使逻辑临时占用约减半；校园网FTP与Zenodo的24次获取均通过文件大小和SHA-256核验。US-NR1案例中，14类陆面数据和8类ERA5逐时数据形成模式输入，各气象字段的8784个时间步与底层读取一致，并完成Emerald初始化和60 s首步计算。

更新后的GriddingMachine将数据处理规则、网络获取和模式输入连接为可重复调用的流程，为全球网格数据的持续维护和地球系统模式研究提供基础。后续将围绕数据覆盖、镜像维护和模式适配扩展其科研应用。

## 数据和代码可用性声明

GriddingMachine.jl源代码公开于https://github.com/CliMA/GriddingMachine.jl，数据生产代码公开于https://github.com/jhOo1/GriddingMachineDatasets，Emerald模式接口环境公开于https://github.com/jhOo1/Emerald-paper，论文补充材料、实验协议、脚本和结果公开于https://github.com/jhOo1/GriddingMachine_Reaserach。ERA5案例的逐文件大小与SHA-256、格点统计、时间轴核对和模式状态保存在`experiment_data/03_09/real_era5_result.toml`；PPT修订文件以V1_R1后缀发布，逻辑标签保持V1，目录记录其文件大小、SHA-256和机构FTP地址。既有主体实验使用的核心代码版本分别以`griddingmachine-paper-2026-v1`、`griddingmachine-datasets-paper-2026-v1`和`emerald-paper-2026-v1`标签固定。多语言下载入口位于GriddingMachine.jl的`clients`目录，对应提交`e0ee0051ba1e51826f494d03f4a411187477cc61`；该新增代码与既有实验冻结版本分别记录。研究材料的内容冻结提交、冻结分支及不可变稿件标签由`论文/投稿版本锁定.toml`统一记录；永久归档与DOI信息随最终归档版本同步发布。

## 基金项目

【待作者和通讯作者补充基金项目中文/英文名称及编号；如无资助，按期刊要求声明。】

## 作者贡献

姜皓：概念设计、方法设计、软件、数据整理、可视化、初稿撰写。王玉杰：概念设计、研究指导、项目管理、论文审阅与修改。

## 利益冲突声明

作者声明不存在利益冲突。

## AI 工具使用声明

本文准备过程中使用OpenAI Codex辅助整理研究材料与代码差异、检查论文结构、修订部分文字、审查分析脚本、汇总结果并辅助图件制作。研究目标、分析方法和结论由作者确定；作者核验软件版本、数据、文件摘要、图件数值和正文表述，并对研究设计、数据真实性、结果解释及全文承担责任。


## 参考文献

[1] WILKINSON M D, DUMONTIER M, AALBERSBERG I J, et al. The FAIR Guiding Principles for scientific data management and stewardship[J]. Scientific Data, 2016, 3: 160018. DOI: 10.1038/sdata.2016.18.

[2] CF CONVENTIONS COMMITTEE. CF Metadata Conventions[EB/OL]. [2026-08-07]. https://cfconventions.org/.

[3] GORELICK N, HANCHER M, DIXON M, et al. Google Earth Engine: Planetary-scale geospatial analysis for everyone[J]. Remote Sensing of Environment, 2017, 202: 18-27. DOI: 10.1016/j.rse.2017.06.031.

[4] WANG Y, KÖHLER P, BRAGHIERE R K, et al. GriddingMachine, a database and software for Earth system modeling at global and regional scales[J]. Scientific Data, 2022, 9: 258. DOI: 10.1038/s41597-022-01346-x.

[5] REW R, DAVIS G. NetCDF: An interface for scientific data access[J]. IEEE Computer Graphics and Applications, 1990, 10(4): 76-82. DOI: 10.1109/38.56302.

[6] HERSBACH H, BELL B, BERRISFORD P, et al. The ERA5 global reanalysis[J]. Quarterly Journal of the Royal Meteorological Society, 2020, 146(730): 1999-2049. DOI: 10.1002/qj.3803.

[7] HUANG B, LIU C, BANZON V, et al. Improvements of the Daily Optimum Interpolation Sea Surface Temperature (DOISST) Version 2.1[J]. Journal of Climate, 2021, 34(8): 2923-2939. DOI: 10.1175/JCLI-D-20-0166.1.

[8] COPERNICUS CLIMATE CHANGE SERVICE. Conversion table for accumulated variables (total precipitation/fluxes): ERA5 reanalysis hourly data[EB/OL]. https://confluence.ecmwf.int/pages/viewpage.action?pageId=216478200.

[9] MAHECHA M D, GANS F, BRANDT G, et al. Earth system data cubes unravel global multivariate dynamics[J]. Earth System Dynamics, 2020, 11: 201-234. DOI: 10.5194/esd-11-201-2020.

[10] BEZANSON J, EDELMAN A, KARPINSKI S, et al. Julia: A fresh approach to numerical computing[J]. SIAM Review, 2017, 59(1): 65-98. DOI: 10.1137/141000671.

[11] CINQUINI L, CRICHTON D, MATTMANN C, et al. The Earth System Grid Federation: An open infrastructure for access to distributed geospatial data[J]. Future Generation Computer Systems, 2014, 36: 400-417. DOI: 10.1016/j.future.2013.07.002.

[12] ABERNATHEY R P, AUGSPURGER T, BANIHIRWE A, et al. Cloud-native repositories for big scientific data[J]. Computing in Science & Engineering, 2021, 23(2): 26-35. DOI: 10.1109/MCSE.2021.3059437.

[13] STERN C, ABERNATHEY R, HAMMAN J, et al. Pangeo Forge: Crowdsourcing analysis-ready, cloud optimized data production[J]. Frontiers in Climate, 2022, 3: 782909. DOI: 10.3389/fclim.2021.782909.

[14] 王卷乐, 林海, 冉盈盈, 等. 面向数据共享的地球系统科学数据分类探讨[J]. 地球科学进展, 2014, 29(2): 265-274. [WANG Juanle, LIN Hai, RAN Yingying, et al. A study of Earth System Science data classification for data sharing[J]. Advances in Earth Science, 2014, 29(2): 265-274.]

[15] UIEDA L, SOLER S R, RAMPIN R, et al. Pooch: A friend to fetch your data files[J]. Journal of Open Source Software, 2020, 5(45): 1943. DOI: 10.21105/joss.01943.

[16] OPEN GEOSPATIAL CONSORTIUM. SpatioTemporal Asset Catalog (STAC) Community Standard, Version 1.1.0[S/OL]. OGC 25-004, 2025[2026-08-15]. https://www.ogc.org/standards/stac/.

[17] SMITH A M, KATZ D S, NIEMEYER K E, et al. Software citation principles[J]. PeerJ Computer Science, 2016, 2: e86. DOI: 10.7717/peerj-cs.86.

[18] BARKER M, CHUE HONG N P, KATZ D S, et al. Introducing the FAIR Principles for research software[J]. Scientific Data, 2022, 9: 622. DOI: 10.1038/s41597-022-01710-x.

[19] LIN D, CRABTREE J, DILLO I, et al. The TRUST Principles for digital repositories[J]. Scientific Data, 2020, 7: 144. DOI: 10.1038/s41597-020-0486-7.

[20] 李楠楠, 刘筱敏. 我国国家科学数据中心FAIR原则的实践现状调查与分析[J]. 图书与情报, 2023, 43(2): 137-144. DOI: 10.11968/tsyqb.1003-6938.2023032. [LI Nannan, LIU Xiaomin. Survey and analysis on the practice of FAIR principle in National Science Data Center of China[J]. Library and Information, 2023, 43(2): 137-144.]
