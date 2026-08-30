# 面向地球系统模型的全球网格数据生命周期：GriddingMachine框架更新与应用

**姜皓（Hao Jiang）**^1，**王玉杰（Yujie Wang）**^1*

1. 中国科学技术大学地球和空间科学学院，安徽 合肥 230026

姜皓，E-mail：hao.jiang@mail.ustc.edu.cn；ORCID：https://orcid.org/0009-0009-8295-8661

\* 通讯作者：王玉杰，wyujie@ustc.edu.cn

## 摘要

地球系统模型依赖来自不同机构和产品体系的全球网格数据。即使数据已采用NetCDF等标准格式，源数据处理规则、标准产品身份、网络分发副本与模型实际输入仍可能由不同环节分别维护，给持续更新和可核验调用带来困难。本文在2022版GriddingMachine基础上，将数据生产、产品身份与分发、模型输入组织重构为连续的数据生命周期。生产端以共享YAML配置规范驱动源维度映射、坐标与数值变换、缺失值处理和质量控制；分发端以独立目录维护逻辑标签、镜像及完整性元数据，并通过直接NetCDF和事务式获取对已登记完整性字段的产品进行字节数与SHA-256核验；应用端以统一读取、陆面参数融合和气象驱动组织连接标准产品与模型接口。NOAA OISST V2.1由四维源结构转换为1440×720标准网格，691 150个有效格点与独立参考逐点一致。对于ELEV和LAI两个内部压缩产品，直接NetCDF在环境A中分别降低48.3%和82.9%的缓存预热端到端中位时间，在环境B中分别降低53.6%和69.2%。校园网内4个代表性产品经FTP和Zenodo完成24次同文件下载，文件大小与SHA-256均与目录登记值一致。14类陆面产品和8类ERA5逐时产品在US-NR1形成模型参数和气象驱动，8个字段的8784个时间步与底层NetCDF逐点一致，并完成Emerald初始化和60 s首步。结果表明，在本文测试的全球规则网格产品、网络环境和模型接口范围内，该框架能够把异构源数据生产、内容身份核验和模型输入组织连接为可执行的数据路径，为地球系统数据产品的持续维护提供轻量化基础设施。

**关键词：** 地球系统模型；全球网格数据；数据生命周期；NetCDF；数据完整性；模型输入

**A Lifecycle Framework for Global Gridded Data in Earth System Models: Advances and Applications of GriddingMachine**

**Hao JIANG^1, Yujie WANG^1\***

1. School of Earth and Space Sciences, University of Science and Technology of China, Hefei 230026, China

Hao Jiang, E-mail: hao.jiang@mail.ustc.edu.cn; ORCID: https://orcid.org/0009-0009-8295-8661

\* Corresponding author: Yujie Wang, wyujie@ustc.edu.cn

## Abstract

Earth system models depend on global gridded datasets maintained by different institutions and product systems. Even when standardized formats such as NetCDF are used, source-processing rules, standardized product identities, network replicas, and the data structures actually consumed by models may evolve in separate maintenance layers. Building on the 2022 release, this study reorganizes GriddingMachine into a continuous data lifecycle spanning production, product identity and distribution, and model-input organization. A shared YAML contract drives source-dimension mapping, coordinate and numerical transformations, missing-value treatment, and quality control. An independent catalog manages logical labels, mirrors, and integrity metadata, while direct NetCDF and transactional acquisition verify file size and SHA-256 for entries that carry integrity records. Unified reading, land-parameter assembly, and meteorological forcing organization connect standardized products to model interfaces. NOAA OISST V2.1 was transformed from a four-dimensional source layout to a standardized 1440 × 720 grid, with 691,150 finite cells matching an independently decoded reference point by point. For the internally compressed ELEV and LAI products, direct NetCDF reduced median warm-cache end-to-end time by 48.3% and 82.9%, respectively, in environment A and by 53.6% and 69.2% in environment B. Four representative products were downloaded 24 times from FTP and Zenodo on the campus network, with file sizes and SHA-256 digests matching catalog records. Fourteen land products and eight hourly ERA5 products supplied model parameters and forcing for US-NR1; all 8,784 time steps in eight fields matched direct NetCDF reads, and Emerald initialization and a 60 s first step completed with finite states. Within the tested regular-grid products, network environments, and model interface, the framework connects heterogeneous-source production, verifiable content identity, and model-input organization into an executable data path.

**Keywords:** Earth system modeling; global gridded data; data lifecycle; NetCDF; data integrity; model input

## 1 引言

地球系统模型正在以更高的空间分辨率和更精细的过程表达描述陆地、大气、海洋及其相互作用。模型复杂度的提升使参数化、初始条件、边界条件、气象驱动和结果评估越来越依赖多源全球网格数据。此类数据通常由多个研究团队和业务机构生产，在文件格式、空间投影、维度顺序、经纬度方向、时间组织、单位、缩放方式、缺失值表示和元数据结构等方面存在差异。研究人员需要串联数据发现、下载、重排或重投影、数值转换、质量检查和模型接口适配，才能把“可获得的数据”转化为可重复调用的模型输入。

科学数据管理正在由单纯的数据公开转向强调可发现、可获取、可互操作和可复用的FAIR原则[1]。NetCDF具有自描述、跨系统和适合多维数组等特点，CF元数据约定进一步通过坐标、物理量、单位和时空属性促进不同数据源之间的解释与处理[2]。Google Earth Engine等云平台显著提升了大尺度遥感数据的访问和分析能力[3]。机构服务器、团队存储和公共存储共同构成当前地学数据分发生态。这些标准与平台分别改善了数据表达、发现、计算或访问，但对于面向固定版本、离线缓存和模型直接调用的工作流，仍需要把数据转换规则、标准产品身份、网络获取内容和下游模型接口连接起来。

王玉杰等[4]于2022年提出GriddingMachine，将常用于陆面和地球系统模拟的全球数据处理为具有统一空间和变量约定的NetCDF文件，并通过标签、`Artifacts.toml`和Julia artifact机制实现数据管理和自动下载，同时提供Julia、MATLAB、Octave、Python和R接口。旧版已经规定经纬度方向、空间分辨率、变量名称、缺失值、单位、引用信息和处理日志，目录中也记录SHA-1、SHA-256和一个或多个下载URL。因此，新版工作的重点并不是重新定义标准网格、标签或哈希机制，而是解决产品体系扩展后不同维护环节之间的一致性问题。

随着产品类型、分发位置和模型应用链条扩展，源数据处理规则、标准产品版本、网络分发副本和模型实际读取对象需要在保持统一标签语义的同时分别更新。仅有统一文件格式并不能保证这些环节持续对应：源数据的维度和缩放规则需要能够被显式重建，网络获取的文件需要能够与目录登记的标准产品核对，标准产品还需要经过空间索引、字段组织、时间轴和量纲衔接后才能成为模型输入。本文据此将研究问题界定为：如何在延续2022版统一数据标准与标签访问的基础上，建立从异构源数据到模型输入的连续、可执行并可核验的数据生命周期。

围绕这一问题，新版GriddingMachine形成三个相互衔接的机制。第一，生产端以共享YAML配置规范表达源维度、坐标、数值变换、Gapfill和质量控制，使异构源到标准NetCDF的转换规则成为可执行生产契约。第二，分发端将数据目录与访问软件解耦，以逻辑标签连接发布副本，并通过直接NetCDF与事务式获取组织下载路径；对于登记了文件字节数和SHA-256的条目，下载端进一步执行严格内容核验以维护可验证的产品身份。第三，应用端以稳定标签连接统一读取、陆面参数融合和气象驱动组织，使标准产品形成满足本文所定义模型输入接口要求的数据结构。三者共同构成“异构数据生产—产品登记与完整性核验—模型输入组织”的连续路径。

本文采用受控实例与真实地学数据分层评价上述路径：以31组生产实例和OISST V2.1产品转换[9]检验标准化规则及真实异构源适配；以ELEV和LAI比较直接NetCDF与外层`tar.gz`的分发路径，并结合13类受控状态及FTP—Zenodo同文件获取检验事务式多镜像机制；以14类陆面产品和8类ERA5逐时产品[10]构成的US-NR1案例检验标准产品到模型输入组织的接口链路。跨操作系统持续集成作为横向验证，用于检查固定依赖条件下核心实现的运行一致性。

## 2 框架设计与关键方法

### 2.1 总体架构与数据生命周期

GriddingMachine新版围绕三个相互衔接的生命周期层次组织（图1）：生产契约负责把来源、结构和数值约定不同的地学数据转换为标准NetCDF产品；产品身份与分发层负责维护标签、版本、镜像和完整性元数据，并使数据目录能够独立于`GriddingMachine.jl`软件包版本更新；模型输入层负责数据发现、获取、读取以及陆面参数和气象驱动组织。生产端主要由`GriddingMachineDatasets`承担，分发与使用端主要由`GriddingMachine.jl`承担。三层共同形成“生产—质控—发布—发现—下载—读取—模型调用”的数据生命周期，其中各层通过标准产品和稳定标签衔接，同时保留独立演化的维护边界。

![图1 GriddingMachine从2022版基线到新版端到端工作流的架构更新](figures/图1_GriddingMachine总体架构_终稿.svg)

**图1 GriddingMachine从2022版基线到新版端到端工作流的架构更新** （a）2022版以数据集专用脚本、`tar.gz`制品、包内数据目录和`read_LUT`构成数据预处理、分发与读取路径；（b）新版以共享YAML契约连接异构源数据、标准化与质量控制、标准NetCDF产品、独立数据目录、事务式获取以及统一读取和模型调用，形成贯通数据生产、内容身份可核验分发与模型应用的端到端工作流；（c）O1—O5依次表示统一数据契约、简化数据制品、目录独立演化、事务式获取和模型就绪接口。橙色虚线标示各项更新相对于2022版基线及新版核心节点的对应关系。

**Fig. 1 Architectural updates from the 2022 GriddingMachine baseline to the updated end-to-end workflow.** (a) The 2022 release connected dataset-specific scripts, `tar.gz` artifacts, an in-package catalog, and `read_LUT` across data preprocessing, distribution, and access. (b) The updated workflow uses a shared YAML contract to connect heterogeneous source data, standardization and quality control, standard NetCDF products, an independent catalog, transactional acquisition, and unified reading and model invocation, thereby integrating data production, content-integrity-verifiable distribution, and model application. (c) O1--O5 denote the unified data contract, simplified data artifacts, independent catalog evolution, transactional acquisition, and model-ready interfaces. Orange dashed lines map these updates to the corresponding baseline components and core nodes in the updated workflow.

在生产端，原始数据及其处理规则分别作为数据输入和YAML配置输入。新版使用共享配置规范描述原始文件组合、源变量、经纬度方向、源维度语义、数值变换、有效范围、Gapfill及输出元数据；配置构建器与处理流水线遵循同一规范。生产引擎依据配置枚举输入，依次完成读取、标准化、质量控制和保存，最终生成以统一标签命名的NetCDF产品。维度、坐标、数值和空间方向检查嵌入生产流程，使标准产品在生成阶段即具有清晰的数据语义。

通过质量控制的数据产品可发布到机构FTP、HTTP(S)服务或Zenodo等公共存储位置。同一标签可对应多个内容相同的网络副本，本文将其称为多镜像分发。独立数据目录登记相对路径和镜像地址，并可为新登记或需要严格完整性管理的条目记录文件字节数和SHA-256；目录生成过程从权威标准文件计算相应完整性元数据并以事务方式写入YAML。目录与访问软件分开维护，支持数据产品列表及其分发位置独立更新。

在数据使用端，目录管理模块显式设置数据根目录与目录来源。目录更新经临时文件完成配置规范校验和事务式替换，并保留上一有效版本。产品获取模块提取各镜像地址的主机名，以可获得的平均往返延迟辅助确定候选顺序，同时保留全部镜像并依次回退。每次传输创建独立临时文件。对于目录中已登记`SIZE`和`SHA256`的产品，文件只有在字节数和摘要核验通过后才进入正式数据目录；严格完整性模式要求两项字段同时存在，兼容模式用于承接尚未回填完整性元数据的历史条目。本文将版本化目录、内容一致的镜像、事务式落盘和可选的严格内容核验共同构成的获取机制定义为“可信分发”。该术语在本文中专指下载对象能够依据目录中的完整性元数据与登记的标准产品进行内容身份核对；数据源真实性、产品科学质量和网络服务可用性分别由上游质量控制与具体运行环境承担。

数据读取层提供标签驱动的整场、指定周期及站点读取，并进一步完成格点尺度陆面参数融合与气象驱动组织。由14类产品组成的第二套陆面参数集合（代码标识为`gm2`）贯通参数组织链路并进入Emerald初始化。本文所称“模型就绪”指标准产品经过格点索引、字段组织、时间轴构建和量纲衔接后能够满足Emerald输入接口，并完成初始化及首步运行；本文对该术语的评价范围集中于数据组织与接口层。

共享YAML、独立目录与统一读取接口共同重构了GriddingMachine的维护单元：数据处理规则由配置契约表达，数据产品与镜像由目录版本管理，模型应用继续使用稳定标签。该设计支持数据产品、分发目录和访问软件在保持接口一致的条件下分别更新，形成贯通生产、发布和应用的可维护数据生命周期。

表1概括2022版与新版的主要差异及其在数据生命周期中的作用。

**表1 2022版与新版GriddingMachine的功能和技术路线比较**

| 环节 | 2022版 | 新版 | 应用价值 |
|---|---|---|---|
| 分发单元 | NetCDF的`tar.gz` artifact | 可直接读取的`.nc` | 简化数据获取并降低端到端读取时间 |
| 数据目录 | 软件内置`Artifacts.toml` | 独立`Artifacts.yaml`；配置规范校验、事务更新和版本备份 | 数据产品可独立于软件版本持续扩展 |
| 下载 | artifact哈希寻址、多个URL和解包 | 延迟信号辅助排序；多URL回退、独立临时文件；带`SIZE`/`SHA256`条目可执行严格核验后落盘 | 将镜像选择与内容身份判定分离，并兼容历史目录 |
| 读取 | `read_LUT` | `read_dataset`，旧名称保留为别名 | 全球规则经纬网整场、周期和站点读取 |
| 模型组织 | 标准化数据和通用读取 | 陆面参数融合与气象驱动组织 | 标准产品进入Emerald参数组织与模型初始化 |
| 数据生产 | 数据源专用处理及贡献流程 | 共享YAML配置规范、程序化与交互式配置生成及显式源维度映射 | 形成共享的标准产品生产工作流 |

**Table 1 Comparison between the 2022 release and the updated GriddingMachine.** The table summarizes the implemented mechanisms, workflow advances, and application value across the data lifecycle.

### 2.2 YAML驱动的标准数据生产

#### 2.2.1 数据契约与维度映射

GriddingMachine 以 NetCDF 作为标准数据格式，原因是该格式能够在同一文件中保存多维数组、坐标和自描述元数据，并被多种地球科学软件读取。2022 年版本已经规定数据采用二维或三维规则经纬网，前两维依次为经度和纬度，可选第三维表示周期；经度自西向东、纬度自南向北，输出保存为实际物理值，缺失值在读取后统一表示为 `NaN`，主变量和不确定性变量分别命名为 `data` 和 `std`[4]。新版延续这些核心约定，并将源维度映射、处理记录、版本化配置和分发完整性纳入相互衔接的机器可读规范（表2）。

**表2 GriddingMachine 标准 NetCDF 数据与元数据规范**

| 类别 | 新版规范 | 实现方式 |
|---|---|---|
| 文件与网格 | 一个标签对应一个可直接读取的`.nc`；规则经纬度网格，默认全球覆盖并声明坐标参考 | NetCDF统一保存数据、坐标与自描述元数据 |
| 维度 | 二维`(lon, lat)`；三维`(lon, lat, ind)`；源维度按名称映射到标准顺序 | 通用维度映射将多种源排列转换为统一结构 |
| 坐标方向 | `lon`自西向东并统一到`[-180, 180)`；`lat`自南向北 | 翻转和循环平移保持数据与坐标同步 |
| 数据变量 | `data`为主变量；`std`保存同形不确定性；输出为实际物理值 | 统一变量命名、类型、单位和数值表达 |
| Gapfill与范围 | 有效范围、填充值和Gapfill策略由YAML显式声明 | 支持数值常数、`MEAN`、`KEEP_AS_IS`、`INT_NAN_TO_1`、`NO_LAND_NAN`和`NO_NAN` |
| 变量元数据 | `data/std`记录可读说明、单位及处理变更条目 | 输出文件保留变量语义与主要转换过程 |
| 处理记录 | YAML声明维度、坐标、数值与Gapfill规则；NetCDF属性写入逐项变更记录 | 配置意图与产品处理历史相互对应 |
| 处理复现 | `SCHEMA_VERSION`、完整YAML、固定输入和版本化项目环境共同归档 | 配置、输入与代码版本共同重建标准产品 |
| 标签与版本 | 标签表达类别、空间/时间分辨率、年份、版本和可选修订号 | 标签与文件名共同形成稳定产品标识 |
| 分发完整性 | 新登记或严格完整性条目记录文件字节数和SHA-256；同一标签的受控镜像指向相同内容 | 对带完整性元数据的条目下载后核验并以事务方式进入正式目录；历史条目由兼容模式承接 |

**Table 2 Standardized NetCDF data and metadata requirements of GriddingMachine.** The specification connects grid structure, gap filling, metadata, provenance, versioning, and distribution integrity within a unified production contract.

缺失值处理由YAML中的`GAPFILL`字段驱动，并依据产品物理含义选择相应策略。数值常数和`MEAN`分别以给定值或分层`nanmean`填补陆地区域缺失值；`KEEP_AS_IS`保持原始数组；`INT_NAN_TO_1`将缺失值补为1并对数组整数化；`NO_LAND_NAN`和`NO_NAN`分别检查陆地区域与全域的数据完整性。Gapfill由此统一连接有效范围过滤、陆海掩膜、缺失值处置和输出精度，为不同地球系统数据产品提供可配置的数据完善方法。ELEV采用常数0填补策略，为统一读取和模型调用提供连续地形场。

CF约定利用坐标变量和属性表达维度语义[2]。GriddingMachine进一步固定输出维度顺序，以降低下游接口复杂度。新版通过YAML的`DIMENSIONS`显式记录源变量各维度语义，维度标准化过程将`(lat, lon)`、`(ind, lat, lon)`等排列重排为统一输出；经纬度翻转与循环平移同步作用于坐标和数据值。规则经纬网数据进入通用标准化流程，非规则网格、区域投影和复杂坐标数据由数据源专用预处理模块完成适配。

#### 2.2.2 YAML配置与转换示例

YAML将数据源差异与通用处理代码分离。配置以`FILE`、`FOLDER`、`DATA`（及可选`STD`）和`GRIDDINGMACHINE`组织文件组合、输入输出位置、变量语义与转换规则以及稳定标签，并通过`SCHEMA_VERSION`约束字段类型、必需项、默认值、互斥关系和数组长度一致性。`DIMENSIONS`显式记录源变量的维度语义，`GAPFILL`、坐标方向、数值范围和缩放规则在数据读取前完成解析；配置构建器与生产流水线调用同一规范。

受控二维示例采用`(lat, lon)`源维度排列，纬度按北向南排列，经度范围为`0°～360°`。配置文件显式声明源维度语义、纬度方向转换、经度范围转换和线性数值变换，生产流水线据此生成标准`(lon, lat)`产品。输出坐标和数值与独立构造的参考数组逐点一致，用于验证配置声明能够被正确映射为标准化处理过程。完整YAML配置、字段说明、执行命令和目录结构列于补充材料S3及版本化贡献指南。

框架同时提供程序化和本地交互式配置生成方式。二者输出均经同一schema校验后进入`process_dataset!`，因此贡献入口不再维护一套独立于生产流水线的字段语义。

#### 2.2.3 生产流程与质量控制

标准产品生产引擎首先根据`FILE`和`FOLDER`定位输入与输出文件，再读取`DATA`和可选`STD`指定的源变量。流水线将数据转换为`Float32`，依次执行纬度翻转、经度翻转或从`0°～360°`到`−180°～180°`的循环平移、线性缩放、有效范围过滤和缺失值处理。各项转换追加为NetCDF变量属性中的变更记录；研究材料进一步将完整YAML、固定输入和版本化项目环境与输出产品共同归档。

生产流程在保存前检查维度、坐标、变量、数值范围和Gapfill结果，空间方向图进一步呈现坐标语义。质量控制完成后生成`data`，存在不确定性时追加同形的`std`，并按`TAG_(PREFIX_)NX_MT_(YYYY_)VV(_REVISION)`生成唯一文件名。文件级变更记录与发布级配置、输入和软件环境共同构成双层复现链，连接产品内容与其生成上下文。

空间方向检查依据变量维度生成带经纬度坐标轴的审核图，人工确认与自动结构、坐标和逐点数值检查相互补充；`VERIFY_ONCE`用于记录同一配置组合的首次方向确认。成品质量检查进一步核对`lon`、`lat`及可选`ind`维度、主变量`data`、数值范围和缺失值状态。对于标准支持分辨率，陆地区域完整性通过重采样`LM_4X_1Y_V1`掩膜检查；其他分辨率由专用规则承接。由此，生产阶段的变换记录、自动判据和必要的空间方向审核共同构成标准产品质量控制。

### 2.3 独立数据目录与事务式多镜像分发

标准产品标签由类别、可选前缀、空间分辨率、时间分辨率、可选年份、数据版本和可选修订号构成，基本形式为`TAG_(PREFIX_)NX_MT_(YYYY_)VV(_REVISION)`。数据发布与目录登记相互解耦：维护者可将标准NetCDF发布到机构FTP、HTTP(S)或公共存储，目录生成器根据本地权威文件和公开地址生成逻辑路径、去重镜像列表，并对新登记或需要严格完整性管理的条目计算文件字节数和SHA-256。目录通过临时文件写入和替换，使产品列表、镜像位置和完整性元数据能够独立于访问软件版本更新。

`GriddingMachine.jl`的Collector显式配置数据根目录、目录来源和本地目录文件。远端目录先下载至临时路径，经根节点和字段schema校验后再替换正式目录，并保留上一有效版本。目录条目以标签为键，核心字段包括安全相对路径`PATH`、一个或多个`URL`以及可选的`SIZE`与`SHA256`。严格完整性模式要求后两项同时存在，兼容模式用于承接尚未完成元数据迁移的历史条目。当前目录中的现有产品均已登记机构FTP地址，公共镜像及完整性字段则随数据发布进度逐步补充；目录schema和获取逻辑对多URL与完整性字段保持统一支持。

产品获取以标签为入口。系统保留目录中的全部镜像，并在存在可用延迟信号时辅助安排候选顺序；延迟探测不决定内容是否有效。每次镜像尝试写入进程级唯一临时文件，对带完整性元数据的条目检查文件状态、字节数和SHA-256，通过后才移动至正式路径；失败尝试独立清理，已有正式文件不被失败传输替换。全库同步、状态查询和历史数据整理复用相同目录与获取逻辑。

这一设计将镜像选择与内容身份判定分离：镜像和延迟信息用于组织候选顺序与回退，目录中的产品身份与完整性字段用于内容核验。多镜像实验选取已配置多个镜像和完整性元数据的代表性产品开展，用于评价镜像回退、内容核验和事务式落盘机制。公共镜像仍随数据发布逐步扩展，相关接口、状态恢复流程和目录条目示例见补充材料。

### 2.4 统一读取与模型输入组织

#### 2.4.1 标准网格数据读取

标准网格数据读取接口支持以本地NetCDF路径或数据标签访问产品，并提供整场数组、指定周期切片、站点全部周期和站点指定周期4种读取方式。标签对应的产品可由目录模块自动获取；默认返回标准变量`data`，也可读取原始数值或同形不确定性变量`std`。读取层直接继承生产端统一的单位、缺失值和物理范围，使处理规则集中于共享生产契约，并兼容既有读取方式。

站点读取依据全球规则经纬网分辨率把经纬度映射为数组索引，并以标准文件的`(lon,lat[,ind])`顺序及西向东、南向北排列为输入契约。接口面向全球规则网格的原位索引，区域投影、非规则网格和空间插值可在生产端完成标准化；周期索引的月份、日期或小时含义由对应产品元数据解释。

#### 2.4.2 模型参数与气象驱动组织

格点尺度陆面参数组织接口从预定义产品集合中提取土壤、冠层、叶片、地形、陆地掩膜和植物功能型数据，依据陆面状态融合相应参数，并对叶面积指数、叶绿素、冠层聚集度和最大羧化速率等季节序列执行Gapfill与逐日重采样。第二套陆面参数集合`gm2`由14类标准产品组成，其中冠层聚集度采用月尺度产品，其余字段按各自空间与时间分辨率进入统一格点。

植物功能型比例进一步用于融合C3/C4植被的叶片光学参数和Medlyn气孔参数，并由`VCMAX25`推导`JMAX25`和`B6F`。输出涵盖位置、分辨率、年份、CO₂、土壤水力性质、冠层结构、植物功能型组成、叶片生物物理和光合参数；字段完整性与`NaN`状态同步进入质量控制。多个标准产品由此形成结构一致的格点级模型输入。

格点尺度气象驱动接口按年份和格点读取气象驱动集合`wd1`中的8类ERA5产品，分别提取地表气压、降水、漫射与直射短波辐射、长波辐射、气温、水汽压亏缺和风速，并依据格点经度换算时区偏移、构建浮点年积日`FDOY`。接口既可直接按经纬度读取，也可从已经加载的全局气象数组提取格点序列，输出字段完整性与`NaN`状态同步进入质量控制。

标签驱动的数据访问、陆面参数融合与气象驱动组织共同构成模型输入转换层。本文将“模型就绪”具体界定为：标准产品经过格点索引、字段组织、时间轴构建和量纲衔接后，形成满足Emerald初始化接口的数据结构。与2022版通过标签组织数据访问的思路一致[4]，新版进一步把目录配置与更新、完整性获取、标准网格读取和模型输入组织连接为连续公共数据流。用户以数据标签发现产品，经镜像获取，并在目录提供完整性元数据时执行内容核验，再读取整场、周期或格点数据，并形成陆面参数或气象驱动；具体公共接口、调用参数和完整Julia示例列入补充材料与版本化用户指南。

## 3 应用案例与评价方法

表3按照受控测试、真实数据和真实网络观测组织全文证据，并给出各项主张对应的评价范围。跨操作系统持续集成作为横向验证维度，贯穿生产、分发和模型接口的确定性核心路径。

**表3 GriddingMachine框架核心主张、证据层级与结论边界**

| 核心主张 | 受控或确定性证据 | 真实数据/网络证据 | 主要结论边界 |
|---|---|---|---|
| 异构源数据可按共享生产契约转换为标准产品 | 31组受控实例、ELEV重复生产与逐点核对 | OISST V2.1真实异构源产品 | 评价范围为所测试全球规则经纬网结构及其显式源维度、坐标和数值变换；非规则网格与复杂投影由专用预处理承接 |
| 直接NetCDF与事务式多镜像机制可改善所测分发路径，并对带完整性元数据的产品维护可核验内容身份 | ELEV/LAI回环HTTP对照；13类镜像状态 | Zenodo公共网络记录；校园网FTP—Zenodo同文件获取 | 性能结论限定于所测内部压缩产品和环境；完整性结论限定于已登记`SIZE`/SHA-256条目的目录内容与下载文件一致性 |
| 标准产品可组织为本文定义的模型就绪输入 | 确定性读取、字段、时间轴与接口核对 | US-NR1的14类陆面产品、8类ERA5及Emerald初始化和60 s首步 | 评价范围为输入组织、初始化和首步接口运行；模型科学过程、模拟精度和长期积分属于后续模型研究 |
| 固定依赖下核心实现具有跨操作系统运行一致性 | Windows、macOS、Linux持续集成 | Windows/macOS独立性能观测及按实际环境记录的真实网络案例 | 评价范围为固定依赖下所测试代码路径的平台一致性；真实网络性能按实际环境分别记录 |

**Table 3 Core claims, evidence levels, and scope of inference for the GriddingMachine framework.** Controlled tests and real-data or real-network cases are listed separately, and the final column states the scope supported by each evidence chain.


### 3.1 标准产品生产与OISST案例

#### 3.1.1 共享生产契约与质量控制

为展示YAML驱动流程对多维地学数据的标准化能力，本文设计具有明确空间语义的位置编码数组：二维数组由经纬度索引共同编码，三维数组进一步加入周期索引。该设计能够清晰呈现维度交换、方向翻转、经度平移和周期组织前后的对应关系，并为标准NetCDF生产提供逐点参照。

代表性处理实例包括`(lon,lat)`与`(lon,lat,ind)`标准输入、`(lat,lon)`与`(ind,lat,lon)`源排列、纬度和经度翻转、`0～360°`经度平移、线性缩放、范围过滤、Gapfill、`data/std`保存和标签生成。配置字段、变量数量、已有产品和标签状态共同覆盖标准产品从源数据到目录登记的主要环节。

共享生产契约的受控评价从维度、坐标、数值、Gapfill、YAML配置、输出和空间方向7个方面组织31组代表性处理实例。各组对应生产流程中的一个关键操作，并以结构、逐点数值或产品状态表征标准化结果；完整分类矩阵见补充材料S4。
产品质量控制覆盖变量、维度、形状、属性、坐标方向、数值范围和Gapfill结果。输出数组与位置编码参照逐点对应，Float32转换采用统一的绝对和相对容差；配置与产品状态通过明确的流程信息反馈给维护者。质量报告同步保存最大绝对误差、最大相对误差、处理历史和重复生产一致性。

29组非交互处理实例在Windows、macOS和Linux持续集成环境中均完成，产品结构和逐点数值满足相同判据；人工方向审核分别接受正向图并识别南北反转图，与预设方向结果一致。两类结果共同呈现共享生产契约在数组变换、配置解析和空间方向控制方面的跨系统一致性。

配置构建器面向二维数据、含不确定性变量的三维数据和经纬度变换数据生成符合共享配置规范的YAML，并将其直接交给标准产品生产引擎。数据贡献案例进一步贯通配置生成、标准化、自动与人工质量检查、产品发布、目录登记以及下游更新、下载和读取，形成覆盖主要环节的数据贡献入口。

#### 3.1.2 OISST异构产品标准化

OISST实际产品用于进一步呈现共享生产契约对异构源结构的适配能力。案例采用NOAA/NCEI 0.25°逐日最优插值海表温度OISST V2.1中仅使用AVHRR数据的正式产品[9]，选取2022年2月25日文件。原始`sst`变量在NetCDF中声明为`time×zlev×lat×lon`，其中`zlev`和`time`均为单例维度；Julia读取后的数组顺序为`lon×lat×zlev×time`，形状为1440×720×1×1。经度覆盖0.125°～359.875°，存储类型为Int16，并以0.01缩放因子解码为摄氏度。

版本化源适配器提取唯一的垂向层和时间层，共享YAML契约进一步完成维度声明、`0°～360°`至`[−180°, 180°)`的经度重排、有效范围控制和缺失值策略，生成`SST_OISST_4X_1D_20220225_V1`标准产品。

独立参考流程直接读取未缩放的Int16存储值，根据原始`scale_factor`、`add_offset`和`_FillValue`构造物理值与缺失值掩膜，并独立计算目标经度索引。参考结果记录全场统计量、10个确定性有效格点和10个缺失格点。标准产品连续生成3次，逐点比较坐标、有效值掩膜和物理值；随后由权威文件生成包含逻辑路径、镜像地址、字节数和SHA-256的目录条目，通过回环HTTP执行事务式下载，并以统一读取接口完成整场核对。

### 3.2 ELEV与LAI的直接NetCDF分发效率评价

直接NetCDF分发效率采用二维静态高程`ELEV_4X_1Y_V1`和三维8日叶面积指数`LAI_MODIS_2X_8D_2020_V1`进行分析，代表不同规模和维度的内部压缩产品。每个标准NetCDF分别以原始`.nc`和包含同一文件的`tar.gz`分发，对照归档采用gzip级别6。两种形式解包后的NetCDF具有相同SHA-256，据此量化省去外层打包与解包带来的时间和临时空间收益。

性能分析基于回环HTTP服务，按随机顺序重复测量传输字节数、打包与解包时间、从请求开始到首次读取NetCDF值的端到端时间，以及下载文件与解包文件并存时的逻辑临时占用。两个独立环境使用一致的脚本和输入文件，时间指标以中位数、四分位距和95% Bootstrap置信区间表示。

### 3.3 多镜像获取与内容完整性

数据目录生命周期涵盖首次建立、版本更新、目录同步、产品获取、状态查询和历史数据整理。代表性目录包含不同版本的`Artifacts.yaml`、多个NetCDF产品和两个镜像端点，并覆盖目录更新、单产品获取、全库同步、历史整理和状态查询。各状态转换通过重复调用考察幂等行为，确定性小型目录参考数据用于呈现事务缓存、正式数据区、全库同步与镜像遍历逻辑。

多镜像分析在两个独立环境中构建内容一致、访问状态可配置的镜像集合，通过延迟分数组织候选顺序，并设置13个受控状态场景，覆盖候选排序、镜像回退、网络访问异常、缓存命中、内容完整性异常和候选耗尽过程。每个场景在各环境中重复5次，记录候选选择、镜像遍历、正式文件状态及SHA-256，据此刻画事务式获取在镜像切换过程中的文件选择、校验与落盘行为。校园网FTP与Zenodo访问进一步呈现机构镜像和公共镜像的互补分发特征与内容一致性；完整场景矩阵列于补充材料S6。

镜像访问实验选取4个同时具有FTP和Zenodo地址且已登记`SIZE`与`SHA256`字段的代表性标签，对各文件—镜像组合开展重复下载，记录候选顺序、传输时间、字节数和SHA-256。公共网络观测刻画Zenodo镜像获取特征；中科大校园网实验对FTP与Zenodo执行同文件只读下载，共形成24次完整性记录。实验数据与环境信息随可复现材料归档。

### 3.4 统一读取与模型输入组织

模型输入组织案例连接标准网格读取、陆面参数融合、气象驱动组织与Emerald初始化。确定性参考数据用于核对字段名、形状、类型、时间索引和缺失值处理；陆面案例采用2020年第二套陆面参数集合，在US-NR1附近植被格点和典型非植被格点呈现不同陆面状态下的模型入口。

真实气象案例使用同一年度的8类ERA5标准产品[10]：地表气压、降水、漫射与直射短波辐射、长波辐射、气温、水汽压亏缺和风速。八文件从中科大机构FTP只读获取，总大小为12 575 376 138字节，并逐文件记录SHA-256。US-NR1坐标（40.0329°N、105.5464°W）由规则索引映射到40.5°N、105.5°W格点；2020年为闰年，预期每个字段包含8784个逐小时值。实验同时核对8个`data`变量的`lon×lat×ind`维度、360×180×8784形状及单位属性。应用层输出与底层NetCDF直接读取的同一格点序列逐点比较；`FDOY`另按经度/15计算时区偏移并独立重建。随后把真实陆面参数和真实气象驱动共同传入Emerald，检查初始化和60 s首步后的大气、土壤状态是否均为有限值。

### 3.5 跨操作系统运行一致性设计

跨操作系统运行一致性采用本地运行与持续集成相结合的设计。Windows和macOS本地环境运行生产矩阵、ELEV/LAI分发效率、13类镜像状态以及核心软件与Emerald接口；Linux与另外两个系统的干净持续集成环境运行29组非交互生产实例、40次确定性分发测量、65次镜像状态核对、核心软件功能和Emerald最小接口。统一项目依赖与参考数据用于比较产品结构、逐点数值、正式文件摘要和接口状态。

真实FTP—Zenodo访问按照实际网络环境单独记录，US-NR1真实陆面和ERA5链路作为应用案例归档。由此形成“多系统确定性核心路径—独立环境性能观测—真实网络与数据应用”三个层次的复现设计；完整系统—模块—证据矩阵见补充材料S5。

## 4 结果

按照表3所列评价设计，以下依次呈现标准产品生产、直接NetCDF分发效率、多镜像获取、模型输入组织和跨操作系统运行一致性结果。

### 4.1 标准产品生产与OISST结果

#### 4.1.1 共享生产契约与质量控制结果

31组处理实例覆盖维度、坐标、数值、Gapfill、配置、输出和空间方向控制，其中29组非交互实例在三系统持续集成环境中获得一致的产品结构和逐点数值结果；人工空间审核分别接受正向图并识别南北反转图，与预设方向结果一致。数据贡献案例进一步贯通YAML配置、标准产品生成、目录登记和下游读取，生成产品与参考数组逐点一致，目录中的文件字节数和SHA-256与产品相符。

ELEV补充案例使用已通过文件大小和SHA-256校验的`ELEV_4X_1Y_V1.nc`。该文件为1440×720、全域有效，有限值范围为−415.5～5 357.7002 m；GriddingMachine整场读取与NetCDF底层Float32数组逐点一致。使用显式标准维度、`KEEP_AS_IS`和原值保持配置连续处理3次，三次`data/lon/lat`均与输入一致，输出文件SHA-256也彼此相同，表明标准产品经过统一读取和生产流水线后保持科学数组及坐标。

#### 4.1.2 OISST异构产品标准化结果

OISST案例展示了共享生产契约对异构地学源数据的组织能力。原始`sst`变量在Julia读取路径中呈现为1440×720×1×1的`lon×lat×zlev×time`数组，经单例层提取、Int16物理值解码和经度重排后形成1440×720标准产品。输出经度由−179.875°递增至179.875°，纬度由−89.875°递增至89.875°；691 150个有效格点和345 650个缺失格点与独立参考逐点一致，海表温度范围为−1.80～32.39 ℃，全场平均值为14.013 ℃，最大绝对差为0。

标准产品连续生成3次，科学数组、坐标和文件SHA-256均保持一致。生成文件为997 006字节，目录条目自动登记相同的字节数和SHA-256；经回环HTTP事务式下载后，正式文件摘要与目录完全一致，传输临时文件全部完成回收。统一读取接口获得的整场数组与独立参考逐点一致，验证了从源产品、共享YAML生产、目录登记到标准读取的端到端数据链路。

![图2 OISST产品标准化结果](figures/图2_OISST真实产品标准化结果.png)

**图2 OISST V2.1产品标准化结果** （a）2022年2月25日全球海表温度标准产品；（b）从四维源结构、存储值解码和经度重排到二维标准网格的转换路径；（c）坐标、有效值掩膜、物理值及重复生成摘要的独立参考核对。标准产品为1440×720规则网格，691 150个有效格点及345 650个缺失格点与独立参考掩膜逐点一致，物理值最大绝对差为0，3次生成的文件摘要相同。

**Fig. 2 Standardization results for the OISST V2.1 product.** (a) Global standardized sea-surface temperature on 25 February 2022; (b) the transformation from the four-dimensional source layout through stored-value decoding and longitude reordering to the two-dimensional standard grid; and (c) independent-reference checks of coordinates, the finite-value mask, physical values, and repeated file digests. The 1440 × 720 product contains 691,150 finite and 345,650 missing cells that match the independently decoded reference mask point by point, with a maximum absolute physical-value difference of zero and identical file digests across three runs.

### 4.2 ELEV与LAI的直接NetCDF分发效率

新版采用直接NetCDF作为分发制品。本研究以通过来源MD5与SHA-256校验的`ELEV_4X_1Y_V1`和`LAI_MODIS_2X_8D_2020_V1`评价分发效率，并在环境A（Windows）和环境B（macOS）中采用一致协议。两文件的`data`变量均采用NetCDF内部zlib压缩级别4，对照归档采用gzip压缩级别6。回环HTTP条件下，各“数据×形式”组合经过缓存预热并按随机顺序重复10次，解包后内容均通过SHA-256校验。

环境A中，直接NetCDF相对外层`tar.gz`将ELEV和LAI的端到端中位时间分别降低48.3%和82.9%；环境B中的相应降幅分别为53.6%和69.2%。两个产品的传输字节分别增加6.43%和2.16%，逻辑临时占用分别减少约48%和49%。80次SHA-256摘要核验结果一致。对于所测的两个内部压缩产品，直接分发以少量传输字节增加换取了额外解包步骤和临时文件共存的减少。

![图3 直接NetCDF与外层tar.gz分发的端到端时间比较](figures/图3_直接NetCDF分发效率.svg)

**图3 ELEV和LAI产品采用直接NetCDF与外层tar.gz分发的端到端时间比较** （a）二维高程产品ELEV；（b）三维叶面积指数产品LAI。空心圆表示各组合的10次独立测量，柱高为缓存预热后端到端时间中位数，误差线为95% Bootstrap置信区间；环境A（Windows）和环境B（macOS）采用相同输入文件与测量协议。柱上百分比表示直接NetCDF相对于外层`tar.gz`归档的中位时间降幅。

**Fig. 3 End-to-end distribution time for the ELEV and LAI products using direct NetCDF and external `tar.gz` archives.** (a) The two-dimensional ELEV product; (b) the three-dimensional LAI product. Open circles show the 10 measurements for each combination, bars show median warm-cache end-to-end time, and error bars show 95% bootstrap confidence intervals. Environment A (Windows) and environment B (macOS) used identical input files and measurement protocols. Percentages above the bars indicate the reduction in median time achieved by direct NetCDF relative to external `tar.gz` archives.

### 4.3 目录管理与事务式多镜像分发

目录与数据获取模块将目录初始化、事务更新、产品同步、镜像获取、状态查询和历史数据整理组织为统一的数据维护接口。独立目录使数据产品能够随镜像和版本持续更新，事务缓存区与正式数据区的分层机制则将传输过程与标准产品分离，使上一有效目录和已发布产品在目录更新与镜像切换过程中保持稳定。

13个受控状态场景在两个独立操作系统环境中分别重复5次，共形成130次获取记录。在具有可用延迟分数的场景中，目录与数据获取模块按照延迟辅助排序候选，并在首选镜像访问或内容校验状态变化时依次遍历其余地址。每次获取采用独立临时文件，内容经字节数和SHA-256确认后进入正式路径；所有记录均完成临时文件回收，既有正式文件摘要保持一致。

在校外公共网络观测中，两个独立环境分别对4个Zenodo标签重复获取3次，共形成24次下载记录，全部达到登记字节数并通过SHA-256核验。下载时间随文件规模呈梯度变化，重复传输的SHA-256摘要与目录登记值一致，体现了公共镜像、事务式获取和完整性校验的协同作用。

校园网双镜像实验是另一组独立记录：4个产品分别从FTP和Zenodo重复获取3次，两类镜像各形成12次下载，共24次结果，均达到登记字节数并通过SHA-256核验。在本组校园网观测中，延迟辅助排序与实际传输顺序一致，机构镜像与公共镜像提供了内容一致的分发副本；分产品传输时间与网络记录列于补充材料。

ERA5降水产品的单位修订进一步检验了逻辑标签与物理制品的解耦：逻辑标签`PPT_ERA5_1X_1H_2020_V1`保持不变，目录将其物理URL更新为`V1_R1.nc`并登记新的`SIZE`与SHA-256，原V1物理文件未被覆盖。全新Collector按V1逻辑标签获取R1制品并通过完整性核验，第二次调用直接复用正式缓存。该案例说明产品修订可以通过目录更新完成，而无需改变下游使用的逻辑标签。

### 4.4 统一读取与模型输入组织

陆面案例使用2020年第二套陆面参数集合的14类标准产品，文件大小、来源摘要和SHA-256均通过核验。US-NR1站点映射至40.5°N、105.5°W的规则格点，参数融合接口组织34个模型字段、366日季节序列、4个土壤层和17个植物功能型，高程、陆地掩膜与叶面积指数得到一致读取。撒哈拉案例被识别为非植被格点并进入相应的陆面状态分流，体现了参数组织前的场景识别能力。该参数集合由此贯通完整性目录、统一读取和陆面参数组织，并覆盖植被与非植被场景。

真实气象案例读取2020年8类ERA5标准产品，八文件合计12 575 376 138字节；各`data`变量均为`lon×lat×ind`、360×180×8784，并带有单位属性。US-NR1格点的地表气压、降水、漫射与直射短波辐射、长波辐射、气温、水汽压亏缺和风速均得到8784个逐小时值，有限值比例均为100%；应用层输出与底层NetCDF逐点读取的8个字段最大绝对差均为0。按站点经度计算的时区偏移为−7.0364 h，`FDOY`严格递增且与独立公式逐点一致。气象组织层形成`FDOY`和8类气象共9个字段，Emerald适配后扩展为16个模型驱动字段；真实陆面参数与真实气象共同完成模型初始化和60 s首步计算，大气与土壤关键状态均保持有限值。

量纲审计进一步表明，PPT全年累计值为0.496409 m水层，即496.409 mm。该数值尺度与ERA5逐小时累计降水的米制表达[11]及Emerald由水层厚度转换为摩尔通量的适配关系一致。本轮更新据此将生产端降水单位属性统一为`m`，使标准产品元数据、数值尺度和模型换算形成一致的量纲链条。真实年度案例由此覆盖格点提取、时间轴构建、量纲衔接和模型首步计算等主要接口环节。

### 4.5 跨操作系统运行一致性结果

Windows、macOS和Linux持续集成环境分别完成29组非交互生产实例、40次确定性分发测量和65次镜像状态核对，产品结构、逐点数值、SHA-256摘要、正式文件状态和临时文件回收结果一致。GriddingMachine与GriddingMachineDatasets核心功能以及Emerald合成输入最小接口也在三个系统环境中完成，呈现固定依赖下核心数据路径的跨系统一致性。

Windows和macOS本地环境进一步完成ELEV/LAI性能测量及镜像故障场景，独立公共网络记录完成Zenodo内容核验；校园网环境完成FTP—Zenodo同文件对照，US-NR1案例完成真实陆面与气象产品的模型输入组织。持续集成、独立环境观测和真实数据案例共同构成分层复现证据，具体系统—模块对应关系列于补充材料S5。

## 5 讨论

### 5.1 从统一产品标准到可执行数据生命周期

2022版GriddingMachine已经建立统一网格、变量约定、标签化数据访问以及基于artifact的数据管理[4]。新版的主要变化不在于再次规定NetCDF、标签或哈希，而在于把原先分散在数据源专用处理、软件内置目录和下游调用中的维护责任重新组织为三个可衔接的层次：共享YAML契约显式描述异构源到标准产品的转换规则，独立目录维护标准产品的逻辑身份、镜像和完整性元数据，统一读取与模型输入层继续围绕稳定标签组织下游使用。这样，数据处理规则、产品目录和访问软件可以在共同约定下分别更新，同时通过标准产品和标签保持对应关系。

OISST案例说明了这种重构在生产端的具体作用。源变量的单例维度、存储缩放和经度范围并未被隐藏在一次性脚本中，而是由源适配与共享配置共同表达；输出再通过独立解码参考核对坐标、有效值掩膜和逐点物理值。31组受控实例用于覆盖维度、坐标、数值和Gapfill等基本操作，真实OISST则检验这些机制能否共同作用于实际异构产品。两类证据的角色不同：前者用于定位处理规则是否正确，后者用于验证一条真实源数据到标准产品的组合路径。据此，新版生产改进的核心在于把处理规则显式化为可执行、可核对的生产契约，并通过真实异构产品检验其组合使用。

### 5.2 直接NetCDF分发与完整性保证的重新建立

直接NetCDF取消了标准文件外层`tar.gz`的打包和解包步骤。对于本文所测、已经采用NetCDF内部压缩的ELEV和LAI，外层归档仅减少2.16%～6.43%的传输字节，而直接NetCDF在两个独立环境中均缩短了缓存预热后的端到端时间，并将逻辑临时占用降低约一半。这一结果说明，对于内部已经压缩、下载后需要立即读取的单体NetCDF，分发单元的选择需要同时考虑传输字节、解包开销和首次读取路径。本文的性能结论对应ELEV、LAI及两个独立实验环境中的既定测试条件。

更重要的变化在于，取消旧版artifact封装后，文件完整性不能再依赖原有制品机制隐式维持，而需要在新的直接NetCDF路径中显式重建。新版目录生成器可从权威标准文件计算并记录`SIZE`和SHA-256；对于启用严格完整性核验的条目，每个镜像下载到独立临时文件，只有在字节数和摘要均与目录一致后才进入正式路径，失败镜像的临时内容不替换已有正式文件。13类受控状态主要验证这一状态机在回退、损坏和缓存条件下的行为，真实Zenodo及校园网FTP—Zenodo记录则验证所测试网络副本能够返回与目录登记一致的内容。因此，直接NetCDF带来的效率变化与事务式完整性机制应被视为同一次分发架构重构的两个方面，而不是彼此独立的功能增加。

ERA5降水V1→V1_R1修订展示了独立目录的另一项作用：模型侧继续使用原逻辑标签，而物理制品、URL及完整性摘要在目录层更新。目录记录和原始制品共同保留版本边界，使数据修订与下游接口保持解耦，同时由新的摘要锁定修订后的具体bitstream。

### 5.3 科学质量控制与内容完整性的职责边界

生产质量控制和分发完整性核验承担不同职责。生产阶段通过维度、坐标方向、变量、数值范围、Gapfill、空间方向图和独立参考等检查，判断标准产品是否按照声明的处理规则生成；分发阶段的文件字节数和SHA-256用于判断下载对象是否与目录登记的标准文件保持相同内容。数据源真实性、处理规则的科学合理性以及变量物理意义和量纲则分别由生产与应用层的相应质量控制承担。OISST的逐点独立参考和ERA5降水单位修订分别体现了这两类检查在数据生命周期中的作用。

在本文中，“可信分发”指内容身份和完整性可核验的分发机制。多镜像提供获取路径冗余，候选顺序用于组织尝试过程；对于启用严格完整性核验的条目，文件进入正式目录以前需要通过内容核验。校园网实验验证了所测FTP与Zenodo副本在实验时段内的内容一致性，镜像的长期可达性、吞吐率和服务稳定性则属于具体部署环境的运行属性。

### 5.4 从标准产品到模型输入：接口层面的“模型就绪”

标准化NetCDF并不是模型输入组织的终点。地球系统模型通常还需要把多个产品映射到共同格点，组合参数字段，建立时间轴，并处理变量单位和模型接口所需的数据结构。US-NR1案例中，14类陆面产品形成34个模型字段，8类ERA5产品形成8784步逐时气象序列；应用层字段与底层NetCDF逐点一致，FDOY与独立时间公式一致，降水单位与模型水量换算相衔接。真实陆面参数和气象驱动随后完成Emerald初始化和60 s首步计算。

这些结果构成模型输入链路和接口运行的验证。本文将“模型就绪”定义为：标准产品经过格点索引、字段组织、时间轴构建和量纲衔接后，形成满足Emerald初始化接口的数据结构，并能够完成本文测试的首步运行。当前真实案例集中于2020年US-NR1单一格点，多区域、多年份、不同生态区及长期积分构成后续模型应用的扩展方向。

### 5.5 跨操作系统运行一致性与相关基础设施定位

Windows、macOS和Linux持续集成中的一致结果用于检查固定依赖条件下核心数据逻辑是否受操作系统差异影响。持续集成覆盖确定性的生产、分发和接口路径，本地独立环境用于测量性能和镜像故障状态，真实网络及US-NR1案例则按照实际环境单独记录。这样的分层设计将代码路径的一致性与网络性能的环境依赖区分开来，因此本文将这类证据表述为“跨操作系统运行一致性”；更广义的科学可复现性还涉及数据版本、运行环境、网络条件和科学过程等因素。

从基础设施定位看，NetCDF/CF解决多维科学数据的表示与语义约定[2,5]，Earth Engine强调云端地理空间数据计算[3]，ESGF支撑分布式气候模式数据发现与访问[12]，Pangeo及Pangeo Forge侧重云优化数据和可复用生产配方[13-14]，Pooch与STAC分别提供文件获取注册和广义地理空间资产描述[16-17]。GriddingMachine关注其中一个更窄的模型导向场景：经过选择的全球规则网格产品需要以固定标签进入Julia工作流，并在机构存储、公共镜像、离线缓存和模型输入之间保持一致的数据身份。其特点在于把上游生产契约、标准NetCDF、轻量目录、事务式多镜像获取和下游模型字段组织放在同一生命周期中，而不是替代上述通用数据平台。

### 5.6 适用范围与后续扩展

本研究的适用范围主要由数据结构、分发实验和模型案例三方面界定。当前标准产品与统一读取主要面向全球规则经纬网，非规则网格、区域投影和复杂坐标通过数据源专用预处理进入标准化流程；OISST提供了一条真实异构源数据链路，更多海洋、陆面和大气产品可用于进一步评价不同源结构下的适配范围。直接NetCDF性能实验覆盖ELEV和LAI两个内部压缩产品及两个独立本地环境，真实网络实验覆盖本文登记的代表性镜像，因此相应性能与网络结果对应这些实验条件。

发布层面，现有目录条目均已登记机构FTP地址，Zenodo等公共镜像以及`SIZE`/SHA-256字段随数据发布进度逐步扩展。本文的严格完整性和真实多镜像实验来自已经完成相应配置的代表性产品，用于验证统一目录和获取机制在实际发布对象上的运行方式。模型应用集中于US-NR1的2020年陆面参数与ERA5驱动，并以Emerald初始化和60 s首步作为接口层验证；多区域、多年份、不同生态区和长期积分是后续模型应用的重要扩展方向。持久化DOI归档、历史产品镜像完善及更多模型适配则属于数据基础设施持续维护工作。

## 6 结论

本文在2022版GriddingMachine统一网格、标签访问和artifact数据管理基础上，将数据生产、产品身份与分发、模型输入组织重新连接为可执行的数据生命周期。新版以共享YAML配置规范和显式源维度映射描述异构源到标准产品的生产契约，以独立目录、直接NetCDF、事务式获取和对已登记完整性元数据产品的`SIZE`/SHA-256核验维护可验证的内容身份，并以统一读取、陆面参数融合和气象驱动组织连接标准产品与模型接口。

分层验证为这三个环节提供了对应证据。OISST V2.1产品从四维源结构生成1440×720标准海表温度产品，坐标、有效值掩膜和691 150个物理值与独立参考逐点一致。对于所测内部压缩的ELEV和LAI，直接NetCDF在环境A中将缓存预热后的端到端中位时间分别降低48.3%和82.9%，在环境B中分别降低53.6%和69.2%；校园网内4个代表性产品通过FTP与Zenodo完成24次内容一致的双镜像获取。US-NR1案例中，14类陆面产品与8类ERA5逐时产品形成参数和气象驱动，8个气象字段的8784个时间步与底层NetCDF逐点一致，并完成Emerald初始化和60 s首步计算。

这些结果表明，在本文所测试的全球规则网格产品、具备相应完整性元数据的分发条目、网络环境和模型接口范围内，GriddingMachine能够把异构源数据生产、标准产品登记与内容身份核验以及模型输入组织连接为连续数据路径。该框架为数据产品、目录和访问软件的独立维护提供了统一接口基础；其向非规则网格、更广泛网络环境、多区域多年份应用和长期模型积分的扩展仍需要进一步验证。

## 数据和代码可用性声明

GriddingMachine.jl源代码公开于https://github.com/CliMA/GriddingMachine.jl，数据生产代码公开于https://github.com/jhOo1/GriddingMachineDatasets，Emerald模型接口环境公开于https://github.com/jhOo1/Emerald-paper，论文补充材料、实验协议、脚本和结果公开于https://github.com/jhOo1/GriddingMachine_Reaserach。ERA5案例的逐文件大小与SHA-256、格点统计、时间轴核对和模型状态保存在`experiment_data/03_09/real_era5_result.toml`；PPT修订制品以V1_R1物理文件发布，逻辑标签保持V1，目录记录其文件大小、SHA-256和机构FTP地址。论文所对应的核心代码版本分别以`griddingmachine-paper-2026-v1`、`griddingmachine-datasets-paper-2026-v1`和`emerald-paper-2026-v1`标签固定。研究材料的审稿前修订已合并至主线，其内容冻结提交、冻结分支及后续不可变稿件标签由`论文/投稿版本锁定.toml`统一记录；永久归档与DOI信息将在正式投稿前按最终归档结果补充。

## 基金项目

【待作者和通讯作者补充基金项目中文/英文名称及编号；如无资助，按期刊要求声明。】

## 作者贡献

姜皓：概念设计、方法设计、软件、数据整理、可视化、初稿撰写。王玉杰：概念设计、研究指导、项目管理、论文审阅与修改。

## 利益冲突声明

作者声明不存在利益冲突【投稿前由全体作者确认】。

## AI 工具使用声明

本文准备过程中使用OpenAI Codex辅助整理研究材料与代码差异、检查论文结构、修订部分文字、审查分析脚本、汇总结果并辅助图件制作。研究目标、分析方法和结论由作者确定；作者核验软件版本、数据、文件摘要、图件数值和正文表述，并对研究设计、数据真实性、结果解释及全文承担责任。

## 参考文献

[1] WILKINSON M D, DUMONTIER M, AALBERSBERG I J, et al. The FAIR Guiding Principles for scientific data management and stewardship[J]. Scientific Data, 2016, 3: 160018. DOI: 10.1038/sdata.2016.18.

[2] CF CONVENTIONS COMMITTEE. CF Metadata Conventions[EB/OL]. [2026-08-07]. https://cfconventions.org/.

[3] GORELICK N, HANCHER M, DIXON M, et al. Google Earth Engine: Planetary-scale geospatial analysis for everyone[J]. Remote Sensing of Environment, 2017, 202: 18-27. DOI: 10.1016/j.rse.2017.06.031.

[4] WANG Y, KÖHLER P, BRAGHIERE R K, et al. GriddingMachine, a database and software for Earth system modeling at global and regional scales[J]. Scientific Data, 2022, 9: 258. DOI: 10.1038/s41597-022-01346-x.

[5] REW R, DAVIS G. NetCDF: An interface for scientific data access[J]. IEEE Computer Graphics and Applications, 1990, 10(4): 76-82. DOI: 10.1109/38.56302.

[6] MAHECHA M D, GANS F, BRANDT G, et al. Earth system data cubes unravel global multivariate dynamics[J]. Earth System Dynamics, 2020, 11: 201-234. DOI: 10.5194/esd-11-201-2020.

[7] BEZANSON J, EDELMAN A, KARPINSKI S, et al. Julia: A fresh approach to numerical computing[J]. SIAM Review, 2017, 59(1): 65-98. DOI: 10.1137/141000671.

[8] SMITH A M, KATZ D S, NIEMEYER K E, et al. Software citation principles[J]. PeerJ Computer Science, 2016, 2: e86. DOI: 10.7717/peerj-cs.86.

[9] HUANG B, LIU C, BANZON V, et al. Improvements of the Daily Optimum Interpolation Sea Surface Temperature (DOISST) Version 2.1[J]. Journal of Climate, 2021, 34(8): 2923-2939. DOI: 10.1175/JCLI-D-20-0166.1.

[10] HERSBACH H, BELL B, BERRISFORD P, et al. The ERA5 global reanalysis[J]. Quarterly Journal of the Royal Meteorological Society, 2020, 146(730): 1999-2049. DOI: 10.1002/qj.3803.

[11] COPERNICUS CLIMATE CHANGE SERVICE. Conversion table for accumulated variables (total precipitation/fluxes): ERA5 reanalysis hourly data[EB/OL]. https://confluence.ecmwf.int/pages/viewpage.action?pageId=216478200.

[12] CINQUINI L, CRICHTON D, MATTMANN C, et al. The Earth System Grid Federation: An open infrastructure for access to distributed geospatial data[J]. Future Generation Computer Systems, 2014, 36: 400-417. DOI: 10.1016/j.future.2013.07.002.

[13] ABERNATHEY R P, AUGSPURGER T, BANIHIRWE A, et al. Cloud-native repositories for big scientific data[J]. Computing in Science & Engineering, 2021, 23(2): 26-35. DOI: 10.1109/MCSE.2021.3059437.

[14] STERN C, ABERNATHEY R, HAMMAN J, et al. Pangeo Forge: Crowdsourcing analysis-ready, cloud optimized data production[J]. Frontiers in Climate, 2022, 3: 782909. DOI: 10.3389/fclim.2021.782909.

[15] 王卷乐, 林海, 冉盈盈, 等. 面向数据共享的地球系统科学数据分类探讨[J]. 地球科学进展, 2014, 29(2): 265-274. [WANG Juanle, LIN Hai, RAN Yingying, et al. A study of Earth System Science data classification for data sharing[J]. Advances in Earth Science, 2014, 29(2): 265-274.]

[16] UIEDA L, SOLER S R, RAMPIN R, et al. Pooch: A friend to fetch your data files[J]. Journal of Open Source Software, 2020, 5(45): 1943. DOI: 10.21105/joss.01943.

[17] OPEN GEOSPATIAL CONSORTIUM. SpatioTemporal Asset Catalog (STAC) Community Standard, Version 1.1.0[S/OL]. OGC 25-004, 2025[2026-08-15]. https://www.ogc.org/standards/stac/.

[18] BARKER M, CHUE HONG N P, KATZ D S, et al. Introducing the FAIR Principles for research software[J]. Scientific Data, 2022, 9: 622. DOI: 10.1038/s41597-022-01710-x.

[19] LIN D, CRABTREE J, DILLO I, et al. The TRUST Principles for digital repositories[J]. Scientific Data, 2020, 7: 144. DOI: 10.1038/s41597-020-0486-7.

[20] 李楠楠, 刘筱敏. 我国国家科学数据中心FAIR原则的实践现状调查与分析[J]. 图书与情报, 2023, 43(2): 137-144. DOI: 10.11968/tsyqb.1003-6938.2023032. [LI Nannan, LIU Xiaomin. Survey and analysis on the practice of FAIR principle in National Science Data Center of China[J]. Library and Information, 2023, 43(2): 137-144.]
