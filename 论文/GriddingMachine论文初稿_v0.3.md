# 面向地球系统模式的全球网格数据库：GriddingMachine框架更新与应用

**姜皓（Hao Jiang）**^1，**王玉杰（Yujie Wang）**^1*

1. 中国科学技术大学地球和空间科学学院，安徽 合肥 230026

姜皓，E-mail：hao.jiang@mail.ustc.edu.cn；ORCID：https://orcid.org/0009-0009-8295-8661

\* 通讯作者：王玉杰，wyujie@ustc.edu.cn

## 摘要

地球系统模式依赖区域至全球尺度的网格数据进行参数初始化及结果验证。尽管当前数据大多已采用NetCDF、HDF、GeoTIFF等标准格式，源数据处理规则、单位换算、标准数据标识和网络分发方式不同等问题，使得各模式仍需分别整理和维护数据库，给模式持续更新和验证带来不必要的困难。本文在2022版GriddingMachine基础上，优化数据预处理、数据分发及数据读取：以共享配置组织数据处理规则，建立统一的标准化流程；采用直接NetCDF分发和独立数据目录，简化文件获取与数据更新；在统一读取基础上组织陆面参数和气象驱动，衔接多源数据与模式输入。应用案例表明，标准化后的坐标与物理值均与独立参考一致，直接NetCDF分发降低了访问开销，多源网格数据能够形成满足模式接口要求的输入。除Julia语言外，还完善了Matlab、Octave、Python和R语言对新版数据的自动下载支持，并添加了C语言和Fortran语言的自动下载支持，以更好地服务科学研究与应用。

**关键词：** 地球系统模式；全球网格数据库；数据标准化；NetCDF；数据完整性；模式输入

**A Global Gridded Database for Earth System Models: Advances and Applications of GriddingMachine**

**Hao JIANG^1, Yujie WANG^1\***

1. School of Earth and Space Sciences, University of Science and Technology of China, Hefei 230026, China

Hao Jiang, E-mail: hao.jiang@mail.ustc.edu.cn; ORCID: https://orcid.org/0009-0009-8295-8661

\* Corresponding author: Yujie Wang, wyujie@ustc.edu.cn

## Abstract

Earth system models rely on gridded data at regional to global scales for parameter initialization and evaluation of simulation results. Although most datasets are available in standard formats such as NetCDF, HDF, and GeoTIFF, differences in source-processing rules, unit conversion, standardized data identifiers, and distribution methods require researchers to organize and maintain databases for individual models, complicating continued model development and evaluation. Building on the 2022 release of GriddingMachine, this study improves data preprocessing, distribution, and reading. A shared configuration organizes processing rules within a standardized workflow; direct NetCDF distribution and an independent catalog simplify file acquisition and data updates; and land parameters and meteorological forcing from multiple sources are assembled into model inputs on the basis of unified reading. Application cases show that standardized coordinates and physical values agree with independent references, direct NetCDF distribution reduces access overhead, and gridded data from multiple sources can be assembled into inputs that meet model-interface requirements. In addition to Julia, automatic downloading of the updated data is supported in MATLAB, Octave, Python, and R, with new automatic-download entry points for C and Fortran, to better serve scientific research and applications.

**Keywords:** Earth system models; global gridded database; data standardization; NetCDF; data integrity; model input

## 1 引言

地球系统模式的参数初始化、边界条件、气象驱动和结果验证均依赖区域至全球尺度的网格数据。这些数据由不同研究团队和业务机构提供，即使采用相同的文件格式，其坐标排列、空间与时间分辨率、变量含义、单位和缺失值表示仍可能存在差异。研究人员因此需要在数据获取后继续完成转换和整理。此类工作往往随各模式的需求分别开展，源数据或模式接口更新后，相应程序和输入文件还需持续维护。减少同类数据的重复整理，并在更新中保持输入一致，是全球网格数据应用中的实际问题。

为促进科学数据的发现、访问和复用，FAIR原则强调可发现（**F**indable）、可获取（**A**ccessible）、可互操作（**I**nteroperable）和可复用（**R**eusable）[1]。NetCDF适合组织多维科学数据及其坐标信息[2]，CF元数据约定进一步规范变量、坐标和时空属性[3]。Google Earth Engine等云平台通过改善数据表达、发现、访问及计算，提升了大尺度地学数据的访问和分析能力[4]。这些原则、格式与平台为数据复用提供了基础；本地模式试验还需要保存可反复调用的处理结果，并记录所用数据版本和转换规则。对于面向固定版本、离线缓存和模式直接调用的工作流，研究人员仍需要把数据转换规则、标准数据标识、网络获取内容和下游模式接口连接起来。因此，建立适用于本地运行的标准化科研数据库，可以集中维护多源数据及其处理结果，为不同模式试验提供一致的数据输入。

Wang等[5]于2022年发布了基于Julia语言的GriddingMachine数据库和软件，将常用于陆面和地球系统模拟的全球数据整理为具有统一空间和变量约定的NetCDF文件，并通过数据标签和软件包内的Artifacts.toml目录实现管理与自动下载，同时提供Julia、Matlab、Octave、Python和R接口。该版本为多源数据的统一访问奠定了基础。随着数据类型和应用需求扩展，原有流程在数据维护和模式接入方面面临新的需求：处理规则主要保存在数据源专用脚本中，新增数据需分别适配；标准NetCDF经外层tar.gz归档后分发，使用时仍需解包，数据目录随软件包维护也使数据更新与软件发布相互关联；在获得标准网格数据后，具体模式所需的参数和气象序列仍由应用程序进一步组合，并完成时间与单位衔接。

针对这些需求，框架改进需要提高处理规则的复用程度，使数据目录更新与软件发布分开维护，并加强标准网格数据与模式接口的衔接。数据源特有的转换规则与通用程序分开后，新增数据可沿用已有流程；文件分发减少外层归档，并将数据目录与访问软件分开维护，有助于简化获取和更新；在一致的网格读取基础上组织参数、时间轴和单位换算，则可减少各模式重复编写数据接入程序。这些环节通过标准NetCDF和数据标签连接，保持从源数据处理到模式使用的连续性。

本文从数据预处理、分发与读取三个方面更新2022版GriddingMachine，建立配置驱动的标准化、直接NetCDF分发和模式输入组织相衔接的数据流程，并完善Matlab、Octave、Python和R对新版数据的自动下载支持，新增C和Fortran下载入口。研究通过受控处理实例和真实海表温度数据检验标准化结果，通过高程与叶面积指数数据的分发比较和网络镜像获取评价访问效率与内容一致性，并以Emerald陆面过程模式为应用载体，展示陆面参数与逐时气象数据向模式输入的衔接。

## 2 框架设计与关键方法

### 2.1 总体架构与数据流程

新版GriddingMachine按数据处理、文件获取和模式使用的顺序组织为三个环节（图1）。数据生产与标准化层依据源数据和以文本配置格式YAML保存的处理规则，完成维度、坐标、数值转换和质量检查，输出标准NetCDF文件；数据目录与可信分发层登记数据标签、版本、镜像和完整性信息，负责目录更新、文件下载与内容核验；模式输入组织层读取已获取的标准化数据，完成格点提取、陆面参数融合和气象驱动组织。数据生产主要由GriddingMachineDatasets承担，目录管理、文件获取和模式输入组织主要由GriddingMachine.jl承担。

![图1 GriddingMachine从2022版基线到新版数据流程的架构更新](figures/图1_GriddingMachine总体架构_终稿.svg)

**图1 GriddingMachine从2022版基线到新版数据流程的架构更新** （a）2022版以数据集专用脚本、`tar.gz`文件、包内数据目录和读取函数`read_LUT`构成数据预处理、分发与读取路径；（b）新版由数据生产与标准化层、数据目录与可信分发层和模式输入组织层构成，依次连接异构源数据、共享YAML配置、标准化与质量控制、标准NetCDF、独立数据目录、完整性获取以及统一读取和模式调用；（c）O1—O5依次表示统一数据规范、简化数据文件、目录独立演化、事务式获取和模式就绪接口。橙色虚线标示各项更新相对于2022版基线及新版核心节点的对应关系。

**Fig. 1 Architectural updates from the 2022 GriddingMachine baseline to the updated data workflow.** (a) The 2022 release linked dataset-specific preprocessing, `tar.gz` distribution, an in-package catalog, and `read_LUT`. (b) The updated framework connects configuration-driven standardization, direct NetCDF distribution, an independent catalog with integrity-verified acquisition, and model-input organization. (c) O1--O5 summarize updates to data specifications, file distribution, catalog maintenance, transactional acquisition, and model-ready interfaces. Orange dashed lines link these updates to the corresponding baseline components and updated workflow nodes.

标准NetCDF和数据标签连接上述环节：生产流程输出以标签命名的文件，目录建立标签与文件地址的对应关系，科研程序再依据标签获取和读取数据。数据源变化时可调整处理配置，分发位置变化时可更新目录，模式侧则沿用统一读取方式，并根据自身接口组织输入。各环节的具体方法见第2.2—2.4节。

表1概括2022版与新版的主要差异及其在数据流程中的作用。

**表1 2022版与新版GriddingMachine的功能和技术路线比较**

**Table 1 Comparison between the 2022 release and the updated GriddingMachine.** The table summarizes the implemented mechanisms, workflow changes, and their implications for scientific data use across the data workflow.

| 环节 | 2022版 | 新版 | 对科研流程的作用 |
|---|---|---|---|
| 分发单元 | NetCDF的`tar.gz`归档文件 | 可直接读取的`.nc` | 简化数据获取并降低端到端读取时间 |
| 数据目录 | 软件内置`Artifacts.toml` | 独立`Artifacts.yaml`，支持目录校验和独立更新 | 数据目录可独立于软件版本维护 |
| 数据获取 | 基于哈希标识管理数据，支持多个URL、摘要核验和解包 | 直接NetCDF获取、多镜像回退、临时文件核验后更新正式文件 | 简化获取步骤，并保持镜像切换时的文件内容一致 |
| 数据读取接口 | 以`read_LUT`提供全域网格、周期切片和指定格点读取 | 以`read_dataset`统一读取入口，保留`read_LUT`兼容名称，并衔接参数与气象输入组织 | 沿用已有读取方式，为模式输入组织提供基础，并降低旧接口迁移成本 |
| 多语言访问 | 提供Julia、Matlab、Octave、Python和R接口 | 在保留原有接口的基础上完善Matlab、Octave、Python和R自动下载，并新增C和Fortran自动下载入口 | 扩展科研人员获取新版网格数据的编程环境 |
| 模式组织 | 标准化数据和通用读取 | 陆面参数融合与气象驱动组织 | 标准化数据进入Emerald参数组织与模式初始化 |
| 数据生产 | 数据源专用处理及贡献流程 | 共享YAML配置规范、程序化与交互式配置生成及显式源维度映射 | 形成共享的标准化数据生产工作流 |

数据库包含高程与陆地掩膜、土壤水力性质、植被结构与叶片属性，以及气象驱动等数据，按类别、空间与时间分辨率、年份和版本组织标签。2026年8月15日的目录审计共记录1179个数据条目，均登记机构文件传输协议（File Transfer Protocol，FTP）地址，部分同时配置Zenodo镜像。面向模式使用，预定义陆面参数集合将土壤、冠层和叶片等数据按字段组合，气象驱动集合则按变量和年份组织逐时数据，使科研程序能够依据格点与年份调用相应输入。

### 2.2 YAML驱动的数据生产与标准化

#### 2.2.1 数据规范与维度映射

GriddingMachine采用NetCDF格式组织多维数组、坐标和自描述元数据，便于不同地球科学软件读取[2]。2022 年版本已经规定数据采用二维或三维规则经纬网，前两维依次为经度和纬度，可选第三维表示周期；经度自西向东、纬度自南向北，输出保存为实际物理值，缺失值在读取后统一表示为 `NaN`，主变量和不确定性变量分别命名为 `data` 和 `std`[5]。新版延续这些核心约定，并将源维度映射、处理记录、版本化配置和分发完整性纳入相互衔接的机器可读规范（表2）。

**表2 GriddingMachine 标准 NetCDF 数据与元数据规范**

**Table 2 Standardized NetCDF data and metadata requirements of GriddingMachine.** The specification connects grid structure, gap filling, metadata, provenance, versioning, and distribution integrity within a unified standardization workflow.

| 类别 | 新版规范 | 实现方式 |
|---|---|---|
| 文件与网格 | 一个标签对应一个可直接读取的`.nc`；规则经纬度网格，默认全球覆盖并声明坐标参考 | NetCDF统一保存数据、坐标与自描述元数据 |
| 维度 | 二维`(lon, lat)`；三维`(lon, lat, ind)`；源维度按名称映射到标准顺序 | 通用维度映射将多种源排列转换为统一结构 |
| 坐标方向 | `lon`自西向东并统一到`[-180, 180)`；`lat`自南向北 | 翻转和循环平移保持数据与坐标同步 |
| 数据变量 | `data`为主变量；`std`保存同形不确定性；输出为实际物理值 | 统一变量命名、类型、单位和数值表达 |
| 缺失值填补与范围 | 有效范围、填充值和缺失值填补策略由YAML显式声明 | 支持数值常数、`MEAN`、`KEEP_AS_IS`、`INT_NAN_TO_1`、`NO_LAND_NAN`和`NO_NAN` |
| 变量元数据 | `data/std`记录可读说明、单位及处理变更条目 | 输出文件保留变量语义与主要转换过程 |
| 处理记录 | YAML文件明确记录维度、坐标、数值转换和缺失值填补规则；处理完成后，输出NetCDF文件的属性中同步保存实际执行的变更记录 | 配置意图与数据集处理历史相互对应 |
| 处理复现 | `SCHEMA_VERSION`、完整YAML、固定输入和版本化项目环境共同归档 | 配置、输入与代码版本共同重建标准化数据 |
| 标签与版本 | 标签表达类别、空间/时间分辨率、年份、版本和可选修订号 | 标签与文件名共同形成稳定数据集标识 |
| 分发完整性 | 新登记的条目或纳入严格完整性管理的条目记录文件字节数和SHA-256摘要（用于核验文件内容一致性）；同一标签的受控镜像指向相同内容 | 对带完整性元数据的条目下载后核验并以事务方式进入正式目录；历史条目由兼容模式承接 |

缺失值填补由YAML中的`GAPFILL`字段驱动，并依据数据集物理含义选择相应策略。数值常数和`MEAN`分别以给定值或分层`nanmean`填补陆地区域缺失值；`KEEP_AS_IS`保持原始数组；`INT_NAN_TO_1`将缺失值补为1并对数组整数化；`NO_LAND_NAN`和`NO_NAN`分别检查陆地区域与全域的数据完整性。缺失值填补由此统一连接有效范围过滤、陆海掩膜、缺失值处置和输出精度，为不同地球系统数据集提供可配置的数据完善方法。高程数据（ELEV）采用常数0填补策略，为统一读取和模式调用提供连续地形场。

GriddingMachine固定输出维度顺序，以降低下游接口复杂度。新版通过YAML的`DIMENSIONS`显式记录源变量各维度语义，维度标准化过程将`(lat, lon)`、`(ind, lat, lon)`等排列重排为统一输出；经纬度翻转与循环平移同步作用于坐标和数据值。目录中的全球网格数据均可通过统一标准化流程进入发布和读取环节；对于非规则网格、区域投影和复杂坐标源数据，先由数据源专用预处理模块完成坐标适配，再按同一标准输出。

#### 2.2.2 YAML配置与转换示例

数据预处理采用YAML配置，将数据源差异与通用处理程序分开。配置描述输入文件、源变量、维度语义、坐标方向、数值转换、缺失值填补（gap filling）及质量检查要求，处理程序据此完成转换，再按照统一的空间和变量约定输出NetCDF文件。配置规范在执行前检查必需信息、字段类型及相互关系，使程序化与交互式生成的配置遵循相同约定。配置及实际执行的处理记录共同保留源数据到标准化数据的转换过程。

以二维源数据为例，源维度按纬度、经度排列，纬度由北向南，经度范围为0°～360°。配置声明维度语义和坐标转换规则，处理程序据此重排数据、翻转纬度并调整经度范围，输出经度在前、纬度在后且坐标递增的标准网格；需要数值转换时，按配置执行相应变换。该示例说明不同源排列如何进入同一输出结构，结果核对见第4.1节。完整配置与字段说明见补充材料S3。

框架同时提供程序化和本地交互式配置生成方式。二者输出均通过同一配置规范校验，再由标准化处理函数`process_dataset!`执行，使数据贡献者可以复用通用流程，集中描述各数据源的转换规则。

#### 2.2.3 生产流程与质量控制

标准化数据生产引擎根据配置定位输入与输出文件，读取主变量及可选不确定性变量，将数值转换为`Float32`后，执行配置指定的维度重排、坐标翻转或经度循环平移、线性缩放、有效范围过滤和缺失值处理。生产流程在保存前检查输出维度、坐标、变量、数值范围和缺失值状态。对于标准支持分辨率，陆地区域完整性通过重采样`LM_4X_1Y_V1`陆地掩膜检查；其他分辨率采用对应的专用规则。带经纬度坐标轴的空间方向图用于人工确认，补充自动结构与坐标检查；`VERIFY_ONCE`记录同一配置组合的首次方向确认。

质量检查完成后，主变量保存为`data`，存在不确定性时追加同形的`std`，文件按表2所列标签规则命名。各项转换写入NetCDF变量属性中的变更记录，完整YAML、固定输入和版本化项目环境与输出共同归档，使数据文件能够对应其处理规则、来源和生成环境。

### 2.3 独立数据目录与事务式多镜像分发

标准化数据标签由类别、可选前缀、空间分辨率、时间分辨率、可选年份、数据版本和可选修订号构成，基本形式为`TAG_(PREFIX_)NX_MT_(YYYY_)VV(_REVISION)`。数据发布与目录登记相互解耦：维护者可将标准NetCDF发布到机构FTP服务器、超文本传输协议（HTTP/HTTPS）服务或Zenodo科研资源存储平台，目录生成器根据本地用于发布的标准NetCDF文件和公开地址生成逻辑路径、去重镜像列表，并对新登记或需要严格完整性管理的条目计算文件字节数和SHA-256。目录通过临时文件写入和替换，使数据集列表、镜像位置和完整性元数据能够独立于访问软件版本更新。

`GriddingMachine.jl`的数据目录与获取模块Collector配置数据根目录、目录来源和本地目录文件。目录条目以标签为键，核心字段包括安全相对路径`PATH`、一个或多个`URL`以及可选的`SIZE`与`SHA256`。远端目录先下载至临时路径，经根节点和字段规范校验后再替换正式目录，并保留上一有效版本，使本地程序在更新前后均可读取结构有效的目录。已有条目按其登记字段保留兼容访问方式。

数据集获取以标签为入口。系统保留目录中的全部镜像，并在存在可用延迟信号时辅助安排候选顺序；文件内容统一依据目录完整性元数据判定。每次镜像尝试写入进程级唯一临时文件，对带完整性元数据的条目检查文件状态、字节数和SHA-256，通过后移动至正式路径；各镜像尝试相互隔离，正式路径始终对应最近一次通过核验的数据集。全库同步、状态查询和历史数据整理复用相同目录与获取逻辑。

这一设计将镜像选择与内容完整性判定分离：镜像和延迟信息用于组织候选顺序与回退，目录中的标准化数据标识与完整性字段用于内容核验。分发地址变化时，可以通过目录调整候选镜像，科研程序继续按标签获取相同内容的数据文件；接口、状态恢复流程和目录条目示例见补充材料。

### 2.4 统一读取与模式输入组织

#### 2.4.1 标准网格数据读取

标准网格数据读取接口支持以本地NetCDF路径或数据标签访问数据，并提供全域网格数组、指定周期切片、站点全部周期和站点指定周期4种读取方式。标签对应的NetCDF可由目录模块自动获取；默认返回标准变量`data`，也可读取原始数值或同形不确定性变量`std`。模式输入组织层直接继承数据生产与标准化层统一的单位、缺失值和物理范围，使处理规则集中于共享处理规范，并兼容既有读取方式。

站点读取依据全球规则经纬网分辨率把经纬度映射为数组索引，并以标准文件的`(lon,lat[,ind])`顺序及西向东、南向北排列为输入约定。接口面向全球规则网格的原位索引，区域投影、非规则网格和空间插值可在数据生产与标准化层完成转换；周期索引的月份、日期或小时含义由对应数据元数据解释。

#### 2.4.2 模式参数与气象驱动组织

格点尺度陆面参数组织接口从预定义数据集合中提取土壤、冠层、叶片、地形、陆地掩膜和植物功能型数据，依据陆面状态融合相应参数，并将叶面积指数、叶绿素、冠层聚集度和最大羧化速率等季节序列组织到同一年度的逐日时间轴。缺失值填补后，月尺度数据按各月实际天数展开，8日尺度数据按相应覆盖日期展开，并依据年份保留365或366日。不同时间分辨率的参数由此形成可按日期调用的序列。第二套陆面参数集合`gm2`由14类标准化数据组成，其中冠层聚集度采用月尺度数据集，其余字段按各自空间与时间分辨率进入统一格点。

叶片光学参数与Medlyn气孔导度模型参数按采用C3与C4光合途径的两类植物分别组织[6,7]：C3参数按格点内对应植物功能型比例归一化加权，C4参数从相应类型的参数表提取，以保留两类植物的参数差异。光合参数组织参考叶片羧化能力与电子传递能力的协调关系[8]，并按当前模式参数化关系由 25 ℃下最大羧化速率 `VCMAX25` 计算最大电子传递速率 `JMAX25` 和细胞色素 b6f 复合体参数 `B6F`。输出涵盖位置、分辨率、年份、二氧化碳（CO₂）、土壤水力性质、冠层结构、植物功能型组成、叶片生物物理和光合参数；字段完整性与缺失值标记 `NaN` 状态同步进入质量控制。多个标准化数据由此形成结构一致的格点级模式输入。

格点尺度气象驱动接口按年份和格点读取气象驱动集合`wd1`中的8类第五代全球再分析数据（ERA5）[9]，分别提取地表气压、降水、漫射与直射短波辐射、长波辐射、气温、水汽压亏缺和风速。接口可按输入经纬度读取对应格点，或从已加载的全域气象数组提取格点序列。时间轴按逐小时序列构建浮点年积日（fractional day of year，`FDOY`），并以经度除以15换算时间偏移：经纬度调用方式使用输入位置的经度，数组索引方式使用格点中心经度。输出字段完整性与`NaN`状态同步进入质量控制。

标签驱动的数据访问、陆面参数融合与气象驱动组织共同构成模式输入组织层。本文将“模式就绪”界定为：标准化数据经过格点索引、字段组织、时间轴构建和量纲衔接后，形成满足Emerald初始化接口的数据结构。与2022版通过标签组织数据访问的思路一致[5]，新版将基础读取与模式输入组织衔接：读取接口提供网格或格点数值，参数与气象接口进一步组合变量并构建相应时间序列。研究人员可由此复用标准化数据，再按模式接口要求形成输入；完整调用示例见补充材料。

### 2.5 多语言数据下载接口

为衔接不同科研编程环境，新版提供Matlab、Octave、Python和R的数据下载入口，并增加C和Fortran入口。非Julia入口调用同一Python下载脚本，使用时需要Python 3运行环境。Matlab/Octave函数、R函数及C和Fortran程序接收文件URL和本地输出路径，调用脚本完成直接NetCDF下载；Python脚本还支持依据本地Artifacts.yaml中的标签查找下载地址，并在目录或调用参数提供相应信息时检查文件大小和SHA-256。

该设计将各语言的调用方式与下载逻辑分开维护，使科研人员可以在已有程序中自动获取文件，再使用相应语言的NetCDF工具读取数据。非Julia接口的源码和调用说明随代码仓库的`clients`目录提供。

## 3 应用案例与评价方法

本节围绕预处理、分发和读取中的改进需求安排评价。受控处理实例和真实最优插值海表温度数据（Optimum Interpolation Sea Surface Temperature，OISST）用于检查统一流程能否正确处理源维度、坐标和数值差异；高程数据（ELEV）与叶面积指数数据（Leaf Area Index，LAI）的分发对照用于量化省去外层归档后的访问开销，网络镜像获取用于检查不同地址提供的文件内容是否一致；北美通量观测站US-NR1附近格点的陆面参数和气象驱动用于考察多源数据能否组成模式所需输入。表3概括案例与评价指标，跨操作系统测试补充检查核心流程的运行一致性。

**表3 GriddingMachine框架更新的应用案例与评价指标**

**Table 3 Application cases and evaluation metrics for the GriddingMachine framework updates.** Controlled experiments and real-data or real-network applications evaluate data standardization, distribution, model-input organization, and cross-platform consistency.

| 框架更新与评价内容 | 受控实例与对照 | 真实数据与网络案例 | 主要评价指标 |
|---|---|---|---|
| 数据生产与标准化层将异构源数据转换为标准NetCDF | 31组受控实例、ELEV重复生产与逐点核对 | OISST V2.1真实异构源数据 | 维度与坐标、有效值掩膜、逐点物理值、重复生成摘要 |
| 数据目录与可信分发层组织高效且内容可核验的数据获取 | ELEV/LAI回环HTTP对照；13类受控状态场景 | Zenodo公共网络记录；中国科学技术大学（以下简称中科大）校内网 FTP—Zenodo同文件获取 | 端到端时间、传输字节、候选遍历、`SIZE`/SHA-256、临时与正式文件状态 |
| 模式输入组织层将标准化数据组织为模式就绪输入 | 确定性读取、字段、时间轴与接口核对 | US-NR1的14类陆面数据集、8类ERA5及Emerald初始化和60 s首步 | 字段与形状、时间轴、量纲、逐点数值、初始化与首步状态 |
| 跨操作系统运行一致性与多语言下载 | Windows、macOS、Linux持续集成；C与Fortran编译及下载测试 | Windows/macOS独立性能观测及按实际环境记录的真实网络案例 | 数据集结构、逐点数值、文件摘要、缓存状态和接口状态 |


### 3.1 数据生产与标准化及OISST案例

#### 3.1.1 共享处理规范与质量控制

为展示YAML驱动流程对多维地学数据的标准化能力，本文设计具有明确空间语义的位置编码数组：二维数组由经纬度索引共同编码，三维数组进一步加入周期索引。该设计能够清晰呈现维度交换、方向翻转、经度平移和周期组织前后的对应关系，并为标准NetCDF生产提供逐点参照。

处理实例按评价目标分为结构转换、数值处理和配置复用三类。结构转换比较`(lon,lat)`与`(lon,lat,ind)`标准输入、`(lat,lon)`与`(ind,lat,lon)`源排列，以及坐标翻转和`0～360°`经度平移后的逐点对应关系；数值处理依据设定规则核对线性缩放、范围过滤和缺失值填补结果；配置复用检查字段与变量数量、`data/std`保存、已有数据集和标签状态，使配置生成、重复执行与目录登记遵循一致约定。

围绕上述评价目标设计31组处理实例，其中29组非交互实例在Windows、macOS和Linux持续集成环境中采用相同判据运行；空间方向测试V01和V02分别呈现正确方向和南北反转，用于核对方向控制。完整分类矩阵见补充材料S4。

配置构建器分别以二维数据、含不确定性变量的三维数据和经纬度变换数据为输入，生成YAML后直接执行标准化，核对输出与参考数组是否一致。数据贡献案例连接配置生成、自动与人工质量检查、发布、目录登记及下游更新、下载和读取，检查各环节形成的数据能否继续被下一环节调用。

ELEV重复处理案例以已有标准NetCDF为输入，先比较统一读取与底层NetCDF读取的数组和坐标，再采用显式标准维度、`KEEP_AS_IS`及不执行缩放和范围裁剪的配置连续处理3次。评价比较每次输出的`data/lon/lat`与输入是否一致，以及各次输出文件的SHA-256是否相同，用于检查标准化数据在重复处理中的保持情况。

#### 3.1.2 OISST异构数据集标准化

OISST案例用于检验共享配置对真实异构源数据的适配。采用美国国家海洋和大气管理局国家环境信息中心（NOAA/NCEI）发布的0.25°逐日OISST V2.1数据，选用仅使用甚高分辨率辐射计（AVHRR）数据的版本[10]，选取2022年2月25日文件。原始`sst`变量在NetCDF中声明为`time×zlev×lat×lon`，其中`zlev`和`time`均为单例维度；Julia读取后的数组顺序为`lon×lat×zlev×time`，形状为1440×720×1×1。经度覆盖0.125°～359.875°，存储类型为Int16，并以0.01缩放因子解码为摄氏度。

版本化源适配器提取唯一的垂向层和时间层，共享YAML配置进一步完成维度声明、`0°～360°`至`[−180°, 180°)`的经度重排、有效范围控制和缺失值策略，生成`SST_OISST_4X_1D_20220225_V1`标准化数据。

独立参考流程直接读取未缩放的Int16存储值，根据原始 NetCDF 变量属性 `scale_factor`、`add_offset` 和 `_FillValue` 构造物理值与缺失值掩膜，并独立计算目标经度索引。参考结果记录全域统计量、10个确定性有效格点和10个缺失格点。标准化数据连续生成3次，逐点比较坐标、有效值掩膜和物理值；随后由生成的标准NetCDF文件建立包含逻辑路径、镜像地址、字节数和SHA-256的目录条目，通过回环HTTP执行事务式下载，并以统一读取接口完成全域网格逐点核对。

### 3.2 ELEV与LAI的直接NetCDF分发效率评价

直接NetCDF分发效率采用二维静态高程（ELEV）`ELEV_4X_1Y_V1`和三维8日叶面积指数（LAI）`LAI_MODIS_2X_8D_2020_V1`进行分析，代表不同规模和维度的内部压缩数据集。每个标准NetCDF分别以原始`.nc`和包含同一文件的`tar.gz`分发，对照归档采用gzip级别6。两种形式解包后的NetCDF具有相同SHA-256，据此量化省去外层打包与解包带来的时间和临时空间收益。

性能分析在Windows（环境A）和macOS（环境B）中采用回环HTTP服务。每个“数据×分发形式”组合经过缓存预热后按随机顺序测量10次，记录传输字节数、打包与解包时间、从请求开始到首次读取NetCDF值的端到端时间，以及下载文件与解包文件并存时的总大小。两个独立环境使用一致的脚本和输入文件，时间指标以中位数、四分位距和95% Bootstrap置信区间表示。

### 3.3 多镜像获取与内容完整性

数据目录管理评价使用不同版本的Artifacts.yaml、多个NetCDF数据集和两个镜像端点，覆盖目录首次建立与更新、单数据集获取、全库同步、历史整理和状态查询。各操作通过重复调用检查能否保持相同的有效结果，并记录临时文件、正式文件所在目录和候选镜像的变化。确定性小型目录使这些变化能够与预设结果直接比较。

多镜像分析在两个独立环境中构建内容一致、访问状态可配置的镜像集合，通过延迟分数组织候选顺序，并以13类受控状态场景检验镜像回退、缓存复用、内容核验和正式文件状态。每类场景在各环境中重复5次，记录候选选择、获取结果和文件状态；中科大校内网机构FTP与Zenodo公共存储的访问进一步呈现两类镜像的互补分发特征与内容一致性。完整场景矩阵列于补充材料S6。

镜像访问实验选取4个同时具有FTP和Zenodo地址且已登记`SIZE`与`SHA256`字段的代表性标签，对各文件—镜像组合开展重复下载，记录候选顺序、传输时间、字节数和SHA-256。公共网络场景刻画Zenodo镜像获取特征；中科大校内网实验对FTP与Zenodo执行同文件只读下载，共形成24次完整性记录。实验数据与环境信息随可复现材料归档。

### 3.4 统一读取与模式输入组织

模式输入组织案例连接标准网格读取、陆面参数融合、气象驱动组织与Emerald初始化。确定性参考数据用于核对字段名、形状、类型、时间索引和缺失值处理；陆面案例采用2020年第二套陆面参数集合，在US-NR1研究站点附近植被格点和典型非植被格点呈现不同陆面状态下的模式入口。

真实气象案例使用同一年度的8类ERA5标准化数据[9]：地表气压、降水、漫射与直射短波辐射、长波辐射、气温、水汽压亏缺和风速。八文件从中科大机构FTP只读获取，并逐文件记录SHA-256。US-NR1坐标（40.0329°N、105.5464°W）由规则索引映射到40.5°N、105.5°W格点；2020年为闰年，预期每个字段包含8784个逐小时值。实验同时核对8个`data`变量的`lon×lat×ind`维度、360×180×8784形状及单位属性。模式输入组织层输出与底层NetCDF直接读取的同一格点序列逐点比较；`FDOY`另按输入站点经度−105.5464°除以15计算时间偏移并独立重建，数据取样位置与时间计算位置分别记录。随后把真实陆面参数和真实气象驱动共同传入Emerald，检查初始化和60 s首步后的大气、土壤状态是否均为有限值。

### 3.5 跨操作系统运行一致性与多语言下载评价

跨操作系统测试采用一致的项目依赖、参考数据和判据，比较核心流程的数据结构、逐点数值、文件摘要及接口状态。Windows和macOS本地环境开展生产、分发效率、镜像状态和模式接口测试，Windows、macOS和Linux持续集成环境运行非交互处理与确定性核心流程。真实网络获取和US-NR1应用案例按实际运行环境分别记录；完整的系统与测试项目对应关系见补充材料S5。

C和Fortran下载入口分别编译后，通过回环HTTP获取同一确定性参考文件，核对程序退出状态、文件字节数、SHA-256和临时文件残留；同时采用含空格的源URL与本地输出路径，检查路径参数能否正确传递给共享下载脚本。评价以实际下载文件与参考文件的内容一致性为判据。

## 4 结果

按照表3所列评价设计，以下依次呈现标准化数据生产、直接NetCDF分发效率、多镜像获取、模式输入组织和跨操作系统运行一致性结果。

### 4.1 数据生产与标准化及OISST结果

#### 4.1.1 共享处理规范与质量控制结果

31组受控处理实例中，29组非交互实例在三系统持续集成中获得一致的数据结构和逐点数值，V01和V02的人工方向检查结果与预设一致。这些实例覆盖维度重排、坐标翻转、经度平移、数值转换及缺失值处理，说明不同源排列和数值约定能够按配置进入统一结构。数据贡献案例完成配置生成、标准化、目录登记和下游读取后，最终读取数组与参考数组逐点一致，说明共享配置形成的标准网格能够继续用于下游数据访问。

ELEV补充案例使用已通过文件大小和SHA-256校验的`ELEV_4X_1Y_V1.nc`。该文件为1440×720、全域有效，有限值范围为−415.5～5 357.7002 m；GriddingMachine全域网格读取与NetCDF底层Float32数组逐点一致。使用显式标准维度、`KEEP_AS_IS`和原值保持配置连续处理3次，三次`data/lon/lat`均与输入一致，输出文件SHA-256也彼此相同，表明标准化数据经过统一读取和生产流水线后保持科学数组及坐标。

#### 4.1.2 OISST异构数据集标准化结果

OISST案例展示了共享处理规范对异构地学源数据的组织能力。原始`sst`变量在Julia读取路径中呈现为1440×720×1×1的`lon×lat×zlev×time`数组，经单例层提取、Int16物理值解码和经度重排后形成1440×720标准化数据。输出经度由−179.875°递增至179.875°，纬度由−89.875°递增至89.875°；691 150个有效格点和345 650个缺失格点与独立参考逐点一致，海表温度范围为−1.80～32.39 ℃，全场平均值为14.013 ℃，最大绝对差为0。

标准化数据连续生成3次，科学数组、坐标和文件SHA-256均保持一致，统一读取获得的全域网格数组也与独立参考逐点一致。生成文件为997 006字节，目录登记的字节数和SHA-256与文件相符；经回环HTTP下载后，正式文件摘要保持一致，临时文件完成回收。这些结果说明源数据转换形成的标准网格能够经目录登记、文件获取和统一读取传递到下游程序，保持坐标与物理值的一致性。

![图2 OISST数据标准化结果](figures/图2_OISST真实产品标准化结果.png)

**图2 OISST V2.1数据集标准化结果** （a）2022年2月25日全球海表温度标准化数据；（b）从四维源结构、存储值解码和经度重排到二维标准网格的转换路径；（c）坐标、有效值掩膜、物理值及重复生成摘要的独立参考核对。标准化数据为1440×720规则网格，691 150个有效格点及345 650个缺失格点与独立参考掩膜逐点一致，物理值最大绝对差为0，3次生成的文件摘要相同。

**Fig. 2 Standardization results for the OISST V2.1 dataset.** (a) Global standardized sea-surface temperature on 25 February 2022; (b) the transformation from the four-dimensional source layout through stored-value decoding and longitude reordering to the two-dimensional standard grid; and (c) independent-reference checks of coordinates, the finite-value mask, physical values, and repeated file digests. The 1440 × 720 dataset contains 691,150 finite and 345,650 missing cells that match the independently decoded reference mask point by point, with a maximum absolute physical-value difference of zero and identical file digests across three runs.

### 4.2 ELEV与LAI的直接NetCDF分发效率

按照第3.2节的相同输入和测量协议，环境A中直接NetCDF相对外层`tar.gz`将ELEV和LAI的端到端中位时间分别由40.503和222.297 ms降至20.929和38.100 ms，降幅为48.3%和82.9%；环境B中的相应降幅分别为53.6%和69.2%（图3）。两个数据文件的传输字节分别增加6.43%和2.16%，临时文件总大小分别减少约48%和49%。80次SHA-256摘要核验结果一致。

两文件均已采用NetCDF内部zlib压缩级别4，对照归档采用gzip级别6。在所测文件和缓存预热条件下，直接NetCDF以较小的传输字节增量减少了解包及临时文件共存开销，缩短了从请求到首次读取数据的路径。

![图3 直接NetCDF与外层tar.gz分发的端到端时间比较](figures/图3_直接NetCDF分发效率.svg)

**图3 ELEV和LAI数据集采用直接NetCDF与外层tar.gz分发的端到端时间比较** （a）二维高程数据集ELEV；（b）三维叶面积指数数据集LAI。空心圆表示各组合的10次独立测量，柱高为缓存预热后端到端时间中位数，误差线为95% Bootstrap置信区间；环境A（Windows）和环境B（macOS）采用相同输入文件与测量协议。柱上百分比表示直接NetCDF相对于外层`tar.gz`归档的中位时间降幅。

**Fig. 3 End-to-end distribution time for the ELEV and LAI datasets using direct NetCDF and external `tar.gz` archives.** (a) The two-dimensional ELEV dataset; (b) the three-dimensional LAI dataset. Open circles show the 10 measurements for each combination, bars show median warm-cache end-to-end time, and error bars show 95% bootstrap confidence intervals. Environment A (Windows) and environment B (macOS) used identical input files and measurement protocols. Percentages above the bars indicate the reduction in median time achieved by direct NetCDF relative to external `tar.gz` archives.

### 4.3 目录管理与事务式多镜像分发

13类受控状态场景在两个独立操作系统环境中各重复5次，镜像获取、缓存复用和内容核验结果均符合预设。候选地址按延迟辅助排序，访问或内容核验未通过时继续尝试其余镜像；下载内容经临时文件核验后进入正式路径，已有正式文件在失败尝试中保持原有摘要。结果说明镜像回退可以与内容核验配合，在调整获取地址的同时保持本地文件一致。

在公共网络场景中，两个独立环境分别对4个Zenodo标签重复获取3次，共形成24次下载记录，全部达到登记字节数并通过SHA-256核验。下载时间随文件规模呈梯度变化，重复传输的SHA-256摘要与目录登记值一致，说明公共镜像能够向本地程序提供与目录登记一致的数据文件。

中科大校内网双镜像实验是另一组独立记录：4个数据集分别从FTP和Zenodo重复获取3次，两类镜像各形成12次下载，共24次结果，均达到登记字节数并通过SHA-256核验。在本组中科大校内网观测中，延迟辅助排序与实际传输顺序一致，机构镜像与公共镜像提供了内容一致的分发副本；分数据集传输时间与网络记录列于补充材料。

ERA5降水数据的单位修订进一步呈现逻辑标签与物理文件的解耦：逻辑标签`PPT_ERA5_1X_1H_2020_V1`保持稳定，目录将其物理URL指向`V1_R1.nc`并登记新的`SIZE`与`SHA256`字段，V1和V1_R1文件以不同后缀并行保留。空缓存Collector实例按V1逻辑标签获取R1文件并通过完整性核验，第二次调用直接复用正式缓存。该案例表明，目录更新能够承接数据修订，同时保持下游逻辑标签和调用接口稳定。

### 4.4 统一读取与模式输入组织

陆面案例使用2020年第二套陆面参数集合的14类标准化数据，文件大小、来源摘要和SHA-256均通过核验。US-NR1站点映射至40.5°N、105.5°W的规则格点，参数融合接口组织34个模式字段、366日季节序列、4个土壤层和17个植物功能型，高程、陆地掩膜与叶面积指数得到一致读取。撒哈拉案例被识别为非植被格点，并按相应陆面状态组织参数。同一参数集合由此能够依据格点的植被状态形成对应输入，支持植被与非植被格点的模式接入。

真实气象案例读取2020年8类ERA5标准化数据，八文件合计12 575 376 138字节；各`data`变量均为`lon×lat×ind`、360×180×8784，并带有单位属性。US-NR1对应格点的8类气象变量均得到8784个逐小时值，有限值比例均为100%；模式输入组织层输出与底层NetCDF逐点读取的8个字段最大绝对差均为0。按输入站点经度计算的时间偏移为−7.0364 h，`FDOY`严格递增且与独立公式逐点一致。气象驱动组织形成`FDOY`和8类气象共9个字段，Emerald适配后扩展为16个模式驱动字段；真实陆面参数与真实气象共同完成模式初始化和60 s首步计算，大气与土壤关键状态均保持有限值。

降水数值与单位核对表明，PPT全年累计值为0.496409 m水层，即496.409 mm。该数值尺度与ERA5逐小时累计降水的米制表达[11]及Emerald由水层厚度转换为摩尔通量的适配关系一致。据此，标准NetCDF中的降水单位属性统一为`m`，使数据元信息、数值尺度和模式换算形成一致的量纲链条。真实年度案例由此覆盖格点提取、时间轴构建、量纲衔接和模式首步计算等主要接口环节。

### 4.5 跨操作系统运行一致性与多语言下载结果

跨系统测试中，核心流程的数据结构、逐点数值、文件摘要和接口状态保持一致，GriddingMachine、GriddingMachineDatasets及Emerald合成输入接口通过相应检查。上述标准化、镜像获取和模式输入结果共同说明，数据约定能够在不同操作系统的相应运行路径中保持一致；各系统测试项目与结果见补充材料S5。

C和Fortran入口已完成编译与下载测试，下载文件通过字节数和SHA-256完整性校验。多语言入口由此能够在已有科研程序中获取与登记内容一致的数据文件。

## 5 讨论

### 5.1 相对2022版的更新与科研用途

2022版GriddingMachine建立了统一网格、变量约定、标签访问和多语言接口[5]，使研究人员能够使用共同的数据基础。新版进一步将不同环节的更新与维护分开：同类源数据更新时，可调整处理配置并复用通用程序；分发地址变化时，可更新目录中的镜像与文件信息，模式侧继续通过已有标签读取；不同来源的数据接入同一模式时，则可复用参数与气象组织方法。数据维护因此能够围绕变化所在的环节开展，减少处理程序、文件获取与模式调用之间的联动修改。

统一约定还需要同时支持数据更新和既有试验的复现。ERA5降水修订中，下游逻辑标签保持不变，实际文件位置及完整性信息在目录中更新，使调用程序能够继续使用已有入口。对某次模式试验，保存当时的目录、文件摘要、处理配置和代码版本则能够明确实际使用的数据与转换过程。标签用于简化调用，归档记录用于还原试验，两者共同支持数据库的持续维护与科研复用。

### 5.2 分发效率与科学数据质量

直接NetCDF减少了单文件外层打包和解包的步骤。对于本文测试的两个内部压缩文件，直接分发虽增加少量传输字节，却减少临时占用，并缩短缓存预热后的端到端访问时间。分发方式的选择应结合传输量、首次读取时间和本地存储需求。

数据质量检查与下载完整性核验分别解决两个问题：前者检查维度、坐标、物理值、单位和缺失值处理是否符合数据约定，后者检查收到的文件是否与目录登记内容一致。OISST的独立解码比较和ERA5降水单位修订分别体现了数值与量纲检查的作用；受控镜像场景和真实网络下载记录则检验了文件获取的一致性。将两类检查串联，才能从源数据处理一直追溯到科研程序实际读取的文件。

### 5.3 从标准网格数据到模式输入

标准网格数据进入模式之前，还需要建立变量之间的空间、时间和物理联系。US-NR1案例中，陆面参数提供土壤、冠层和叶片属性及其季节变化，ERA5逐时序列提供同一年度的气象条件；参数与气象接口在基础读取之后，分别完成字段组合、时间轴构建和模式所需的量纲转换。降水单位修订说明了这种衔接的必要性：文件中的数值必须结合单位解释，才能正确进入模式通量换算。因此，基于统一读取的输入组织使来自多个数据源的变量形成具有明确物理含义、能够由模式直接调用的参数和气象驱动，减少了各模式分别整理输入的工作。

这一流程也可用于其他站点、年份和模式的数据接入；根据目标模式的空间、时间和变量约定调整配置与接口适配，即可复用标准网格读取和数据组织方法。Julia主流程与非Julia下载入口分别服务输入组织和跨语言文件获取，研究人员可按已有科研程序的需求选择调用方式。

### 5.4 与相关数据基础设施的关系及扩展方向

已有数据基础设施从数据表达、发现和计算等方面支持科学数据复用。NetCDF/CF规范多维数组及元数据表达[2,3]，地球系统数据立方体促进多变量时空数据的联合组织与分析[12]；Google Earth Engine提供云端遥感数据访问与计算[4]，ESGF组织分布式气候模式数据发现和访问[14]，Pangeo及Pangeo Forge支持云端数据组织与可复用处理配方[15,16]。对本地模式试验，这些能力需要进一步落实为可反复调用的数据输入。GriddingMachine将标准化结果与处理规则保存在本地科研流程中，并按模式所需的格点、时间和变量关系组织数据，使共享数据便于进入已有模式程序。其Julia实现[13]支持数据处理与模式接口的组合调用，便于在既有计算环境中复用。

国内地球系统科学数据共享研究强调规范分类和目录建设[17]，Pooch和STAC分别提供科研文件获取与地理空间数据目录描述工具[18,19]。GriddingMachine可在保留现有标签与读取方式的基础上，加强与这些目录和获取工具的衔接，使本地科研程序更便于使用共享数据。持续维护还需要保留数据出处、处理配置与软件版本：软件引用原则、科研软件FAIR原则（FAIR4RS）和数字资源库TRUST原则为相应的记录、引用和资源维护提供参考[20-22]。后续扩展因而可以围绕新增数据源的配置接入、公共镜像登记和更多模式接口适配展开，使数据覆盖与科研复用同步推进。

## 6 结论

针对多源网格数据需要分别整理、分发更新与模式调用难以衔接的问题，本文在2022版GriddingMachine基础上完善了数据预处理、分发和读取流程。共享YAML配置组织源数据转换规则，直接NetCDF分发减少外层归档步骤，独立目录维护数据标签、镜像及完整性信息，在统一读取基础上进一步组织陆面参数和气象驱动；同时完善Matlab、Octave、Python和R对新版数据的自动下载支持，并新增C和Fortran下载入口。

受控实例和真实数据案例表明，新版流程能够保持标准化数据与独立参考的一致性。分发对照显示，直接NetCDF省去外层归档的解包步骤，减少了临时文件占用，缩短了端到端读取时间；FTP—Zenodo镜像获取保持文件内容一致；陆面参数与ERA5逐时数据能够组织为US-NR1模式输入，完成Emerald初始化和60 s首步计算。这些结果验证了新版GriddingMachine在数据转换、文件获取和模式输入组织之间的衔接能力。

更新后的GriddingMachine使研究人员能够复用已整理的数据及其处理规则，减少不同地球系统模式重复整理和维护数据的工作，为全球网格数据库的持续更新和模式试验提供一致的数据基础。后续将继续扩展数据覆盖范围、完善公共镜像登记，并适配更多模式接口。

## 数据和代码可用性声明

GriddingMachine.jl源代码公开于https://github.com/CliMA/GriddingMachine.jl，数据生产代码公开于https://github.com/jhOo1/GriddingMachineDatasets，Emerald模式接口环境公开于https://github.com/jhOo1/Emerald-paper，论文补充材料、实验协议、脚本和结果公开于https://github.com/jhOo1/GriddingMachine_Reaserach。ERA5案例的逐文件大小与SHA-256、格点统计、时间轴核对和模式状态保存在`experiment_data/03_09/real_era5_result.toml`；PPT修订文件以V1_R1后缀发布，逻辑标签保持V1，目录记录其文件大小、SHA-256和机构FTP地址。既有主体实验使用的核心代码版本分别以`griddingmachine-paper-2026-v1`、`griddingmachine-datasets-paper-2026-v1`和`emerald-paper-2026-v1`标签固定。多语言下载入口位于GriddingMachine.jl的`clients`目录，对应发布分支提交`8b3ff703e14f1a387281f4c814f2620438e8f9aa`；该提交包含跨语言下载入口及其完整性验证记录。研究材料的内容冻结提交、冻结分支及不可变稿件标签由`论文/投稿版本锁定.toml`统一记录；永久归档与DOI信息随最终归档版本同步发布。

## 基金项目

【待作者和通讯作者补充基金项目中文/英文名称及编号；如无资助，按期刊要求声明。】

## 作者贡献

姜皓：概念设计、方法设计、软件、数据整理、可视化、初稿撰写。王玉杰：概念设计、研究指导、项目管理、论文审阅与修改。

## 参考文献

[1] WILKINSON M D, DUMONTIER M, AALBERSBERG I J, et al. The FAIR Guiding Principles for scientific data management and stewardship[J]. Scientific Data, 2016, 3: 160018. DOI: 10.1038/sdata.2016.18.

[2] REW R, DAVIS G. NetCDF: An interface for scientific data access[J]. IEEE Computer Graphics and Applications, 1990, 10(4): 76-82. DOI: 10.1109/38.56302.

[3] CF CONVENTIONS COMMITTEE. CF Metadata Conventions[EB/OL]. [2026-09-26]. https://cfconventions.org/.

[4] GORELICK N, HANCHER M, DIXON M, et al. Google Earth Engine: Planetary-scale geospatial analysis for everyone[J]. Remote Sensing of Environment, 2017, 202: 18-27. DOI: 10.1016/j.rse.2017.06.031.

[5] WANG Y, KÖHLER P, BRAGHIERE R K, et al. GriddingMachine, a database and software for Earth system modeling at global and regional scales[J]. Scientific Data, 2022, 9: 258. DOI: 10.1038/s41597-022-01346-x.

[6] MEDLYN B E, DUURSMA R A, EAMUS D, et al. Reconciling the optimal and empirical approaches to modelling stomatal conductance[J]. Global Change Biology, 2011, 17(6): 2134-2144. DOI: 10.1111/j.1365-2486.2010.02375.x.

[7] LIN Y S, MEDLYN B E, DUURSMA R A, et al. Optimal stomatal behaviour around the world[J]. Nature Climate Change, 2015, 5: 459-464. DOI: 10.1038/nclimate2550.

[8] WALKER A P, BECKERMAN A P, GU L, et al. The relationship of leaf photosynthetic traits—Vcmax and Jmax—to leaf nitrogen, leaf phosphorus, and specific leaf area: A meta-analysis and modeling study[J]. Ecology and Evolution, 2014, 4(16): 3218-3235. DOI: 10.1002/ece3.1173.

[9] HERSBACH H, BELL B, BERRISFORD P, et al. The ERA5 global reanalysis[J]. Quarterly Journal of the Royal Meteorological Society, 2020, 146(730): 1999-2049. DOI: 10.1002/qj.3803.

[10] HUANG B, LIU C, BANZON V, et al. Improvements of the Daily Optimum Interpolation Sea Surface Temperature (DOISST) Version 2.1[J]. Journal of Climate, 2021, 34(8): 2923-2939. DOI: 10.1175/JCLI-D-20-0166.1.

[11] COPERNICUS CLIMATE CHANGE SERVICE. Conversion table for accumulated variables (total precipitation/fluxes)[EB/OL]. [2026-09-26]. https://confluence.ecmwf.int/pages/viewpage.action?pageId=197702790.

[12] MAHECHA M D, GANS F, BRANDT G, et al. Earth system data cubes unravel global multivariate dynamics[J]. Earth System Dynamics, 2020, 11: 201-234. DOI: 10.5194/esd-11-201-2020.

[13] BEZANSON J, EDELMAN A, KARPINSKI S, et al. Julia: A fresh approach to numerical computing[J]. SIAM Review, 2017, 59(1): 65-98. DOI: 10.1137/141000671.

[14] CINQUINI L, CRICHTON D, MATTMANN C, et al. The Earth System Grid Federation: An open infrastructure for access to distributed geospatial data[J]. Future Generation Computer Systems, 2014, 36: 400-417. DOI: 10.1016/j.future.2013.07.002.

[15] ABERNATHEY R P, AUGSPURGER T, BANIHIRWE A, et al. Cloud-native repositories for big scientific data[J]. Computing in Science & Engineering, 2021, 23(2): 26-35. DOI: 10.1109/MCSE.2021.3059437.

[16] STERN C, ABERNATHEY R, HAMMAN J, et al. Pangeo Forge: Crowdsourcing analysis-ready, cloud optimized data production[J]. Frontiers in Climate, 2022, 3: 782909. DOI: 10.3389/fclim.2021.782909.

[17] 王卷乐, 林海, 冉盈盈, 等. 面向数据共享的地球系统科学数据分类探讨[J]. 地球科学进展, 2014, 29(2): 265-274. DOI: 10.11867/j.issn.1001-8166.2014.02.0265. [WANG Juanle, LIN Hai, RAN Yingying, et al. A study of Earth System Science data classification for data sharing[J]. Advances in Earth Science, 2014, 29(2): 265-274.]

[18] UIEDA L, SOLER S R, RAMPIN R, et al. Pooch: A friend to fetch your data files[J]. Journal of Open Source Software, 2020, 5(45): 1943. DOI: 10.21105/joss.01943.

[19] OPEN GEOSPATIAL CONSORTIUM. SpatioTemporal Asset Catalog (STAC) Community Standard, Version 1.1.0[S/OL]. OGC 25-004, 2025 [2026-09-26]. https://www.ogc.org/standards/stac/.

[20] SMITH A M, KATZ D S, NIEMEYER K E, et al. Software citation principles[J]. PeerJ Computer Science, 2016, 2: e86. DOI: 10.7717/peerj-cs.86.

[21] BARKER M, CHUE HONG N P, KATZ D S, et al. Introducing the FAIR Principles for research software[J]. Scientific Data, 2022, 9: 622. DOI: 10.1038/s41597-022-01710-x.

[22] LIN D, CRABTREE J, DILLO I, et al. The TRUST Principles for digital repositories[J]. Scientific Data, 2020, 7: 144. DOI: 10.1038/s41597-020-0486-7.
