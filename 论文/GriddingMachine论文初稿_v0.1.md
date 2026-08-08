# GriddingMachine：全球网格数据生产、分发与模型调用框架的更新与验证

**姜皓（Hao Jiang）**^1，[其他作者待定]^1，**王玉杰（Yujie Wang）**^1*

1. 中国科学技术大学[二级单位待确认]，安徽 合肥 [邮政编码待确认]

\* 通讯作者：王玉杰，[邮箱待确认]

## 摘要

地球系统模型的参数化、初始化和驱动依赖来源广泛、格式各异的全球网格数据，但数据制作、发布、稳定获取和模型适配仍需要大量重复劳动。本文在2022年发布的GriddingMachine基础上，针对新数据进入系统、标准数据可靠到达本地以及本地数据进入模型三个环节进行更新。数据生产部分以网页辅助生成YAML配置，并由通用流水线完成二维或三维NetCDF的标准化、检查和目录登记；数据分发部分取消外层`tar.gz`，采用可独立更新的YAML目录登记多个镜像，并通过cache、文件大小和SHA-256校验控制正式落盘；数据使用部分以`read_dataset`统一读取，并通过`grid_dict`和`grid_weather`组织Emerald初始化所需的陆地参数和气象驱动。本文采用合成NetCDF、贡献流程复现、Collector接口回归、三操作系统故障注入以及固定格点金标准和模型初始化实验进行验证。【定量结果待论文release完成并运行实验后填写。】本研究旨在以可重复测试验证GriddingMachine相对2022版的具体改进，为全球规则网格数据从贡献到模型调用提供一条可维护路径。

**关键词：** 地球系统模型；全球网格数据；数据标准化；NetCDF；数据分发；模型初始化

**English title:** GriddingMachine: Updating and Validating a Framework for Global Gridded Data Production, Distribution, and Model Use

## Abstract

Earth system model parameterization, initialization, and forcing depend on global gridded datasets from heterogeneous sources, yet producing, publishing, reliably obtaining, and adapting these datasets still requires repeated manual work. Building on the GriddingMachine release published in 2022, this study updates three connected stages: introducing new datasets, delivering standardized files to local storage, and organizing local data for model use. A browser-based form assists in generating YAML configurations, and a common pipeline standardizes, checks, and registers two- or three-dimensional NetCDF data. Distribution uses directly readable NetCDF files, an independently updated catalog with multiple mirrors, and cache-based download followed by file-size and SHA-256 verification. `read_dataset` provides unified access, while `grid_dict` and `grid_weather` organize land parameters and meteorological forcing for Emerald initialization. Validation combines synthetic NetCDF files, independent reproduction of the contribution workflow, regression tests of catalog operations, fault injection on three operating systems, and fixed-site numerical reference and model-initialization tests. **[Quantitative results and the result-supported conclusion will be inserted after the manuscript release is frozen and tested.]** The study evaluates concrete improvements over the 2022 release and provides a maintainable path from contributing global regular-grid data to using them in an Earth system model.

**Keywords:** Earth system modeling; global gridded data; data standardization; NetCDF; data distribution; model initialization

## 1 引言

地球系统模型正在以更高的空间分辨率和更精细的过程表达描述陆地、大气、海洋及其相互作用。模型复杂度的提升使参数化、初始条件、边界条件、气象驱动和结果评估越来越依赖多源全球网格数据。此类数据通常由不同研究团队和业务机构生产，在文件格式、空间投影、维度顺序、经纬度方向、时间组织、单位、缩放方式、缺失值表示和元数据完整性等方面存在差异。研究人员因此不仅需要寻找数据，还需要反复完成下载、重投影、重排、缩放、质量检查和模型接口适配。数据“可以获得”并不等同于能够被模型稳定、正确且可重复地使用。

科学数据管理正在由单纯的数据公开转向强调可发现、可获取、可互操作和可复用的 FAIR 原则[1]。NetCDF 具有自描述、跨平台和适合多维数组等特点，已广泛用于地球科学数据交换；CF 元数据约定进一步通过坐标、物理量、单位和时空属性描述促进不同数据源之间的解释与处理[2]。Google Earth Engine 等云平台显著提升了大尺度遥感数据的访问和分析能力[3]。然而，对于尚未进入统一云平台、保存在不同机构服务器或研究团队本地的数据，特别是需要离线使用、版本固定或直接进入地球系统模型的数据，研究人员仍然面临格式不一致、分发位置分散、目录更新与软件版本耦合以及模型输入转换重复等问题。

王玉杰等[4]于 2022 年提出 GriddingMachine，将常用于陆面和地球系统模拟的全球数据处理为具有统一空间和变量约定的 NetCDF 文件，并通过标签、`Artifacts.toml` 和 Julia artifact 机制实现数据管理和自动下载，同时提供 Julia、Matlab、Octave、Python 和 R 接口。该版本降低了全球网格数据发现和调用的门槛，并明确了经纬度方向、空间分辨率、变量名称、缺失值、单位、引用信息和处理日志等数据规范。但是，旧版采用 `tar.gz` 作为分发单元，数据目录随软件发布更新，数据镜像和贡献流程的扩展能力有限；当数据存储位置、网络环境和软件接口持续变化时，数据生产、发布、更新和模型使用之间仍缺少统一且可验证的闭环。

针对上述问题，本研究围绕2022版的实际使用障碍更新GriddingMachine，而不把TOML改为YAML这一格式变化本身作为创新。在数据生产端，网页表单辅助贡献者生成YAML，通用流水线依据配置完成源维度映射、坐标和数值处理、质量检查及标准NetCDF输出；在分发端，以可直接读取的NetCDF替代二次压缩制品，通过独立目录登记机构FTP、Zenodo及其他社区镜像，并在cache下载后校验文件大小和SHA-256；在数据使用端，系统化测试目录更新、单文件下载、全库同步、旧文件清理、目录与信息查询等操作，以`read_dataset`替代含义不准确的`read_LUT`名称，再通过`grid_dict`和`grid_weather`组织Emerald初始化数据。远程子集服务Server/Requestor涉及端口开放与服务安全，不属于本文范围。

本文拟回答四个问题：网页配置与生产流水线能否正确处理代表性的二维/三维异构NetCDF，并使未参与开发的贡献者按文档完成数据登记；直接NetCDF、独立目录、多镜像、cache和SHA校验能否在跨平台故障条件下保持下载内容及正式目录状态正确；Collector公共操作和`read_dataset`重载能否在不同本地/远端状态下得到确定结果并保留必要兼容性；`grid_dict`和`grid_weather`能否生成与独立金标准一致且可用于Emerald固定格点初始化的数据。取消二次压缩的效率对比作为分发更新的支持实验，而不是独立贡献；完整长期模型模拟和Server/Requestor均不进入本文验证范围。

## 2 系统设计与方法

### 2.1 总体架构与数据生命周期

GriddingMachine 新版由数据生产、目录与分发、数据使用三个相互衔接的部分组成（图1）。数据生产端由 `GriddingMachineDatasets` 承担，负责把来源、结构和数值约定不同的地学数据转换为满足 GriddingMachine 规范的 NetCDF 产品；目录与分发部分负责保存标准数据产品、维护标签与镜像地址之间的映射，并使数据目录能够独立于 `GriddingMachine.jl` 软件包版本更新；数据使用端由 `GriddingMachine.jl` 承担，负责数据发现、下载、落盘、读取以及向地球系统模型提供参数和气象驱动。三部分共同形成“生产—质控—发布—发现—下载—读取—模型调用”的数据生命周期。

![图1 GriddingMachine全球网格数据生产、分发与模型调用框架](figures/图1_GriddingMachine总体架构.svg)

**图1 GriddingMachine全球网格数据生产、分发与模型调用框架** 生产端利用网页或模板生成YAML并驱动数据标准化和质量控制，目录与分发层维护标准NetCDF、文件哈希及其镜像，数据使用端完成目录操作、校验落盘、统一读取和Emerald模型初始化。虚线表示独立更新、社区反馈或需要在论文release中完成验证的机制；Server/Requestor远程子集服务不属于本文范围。

**Fig. 1 Framework for global gridded data production, distribution, and model use in GriddingMachine.** A browser form or template generates YAML configurations for standardization and quality control. The catalog and distribution component maintains NetCDF files, content checksums, and mirrors. The data-use component manages the catalog, verifies cache-based downloads, provides unified access, and supplies parameters and forcing for Emerald initialization. Dashed lines indicate independent updates, community feedback, or mechanisms to be validated in the manuscript release. Server/Requestor is outside the scope of this study.

在生产端，原始数据及其处理规则分别作为数据输入和 YAML 配置输入。当前 YAML 描述原始文件组合、源变量、经纬度方向、数值变换、有效范围、缺失值处理及输出元数据；论文实验版本将进一步加入显式维度映射。`process_dataset!` 根据配置枚举需要处理的数据文件，依次调用读取、验证和保存过程，最终生成以统一标签命名的 `TAG.nc`。生产过程中的质量控制包括可自动断言的结构与数值检查，以及用于补充确认空间方向的图形复核。自动检查必须成为合成数据测试矩阵的一部分，人工复核不能替代维度、坐标、数值范围和缺失值处理的程序化验证。

通过质量控制的数据产品被发布到机构 FTP、HTTP(S) 服务或 Zenodo 等公共存储位置。一个数据标签可以对应多个镜像地址，并在 `Artifacts.yaml` 中登记标签、相对路径和 URL。目录文件与 `GriddingMachine.jl` 软件包分开维护，使数据列表可以在不发布新软件版本的情况下更新。当前目录尚未记录文件大小和 SHA-256，下载过程也未执行内容哈希校验，因此本文不把现有实现表述为已经保证镜像内容一致或文件完整性。

在数据使用端，Collector负责初始化、更新和加载目录，并由`download_dataset!`完成镜像排序、失败回退和文件下载。当前代码先把文件下载到`cache`目录，在某个下载调用未抛出异常后退出镜像循环，再把缓存文件移动到`public`数据目录；这一过程尚未比较文件大小或内容哈希。Indexer随后通过`read_dataset`提供整场、指定周期及站点数据读取，并通过`grid_dict`和`grid_weather`将多个标签组织为模型参数集合和气象驱动。论文release在完成校验与接口测试后，将这些数据用于Emerald固定格点初始化和最小步进。

该生命周期不是单向发布链。模型使用过程中发现的数据错误、元数据不足和新增数据需求可以反馈至 YAML 配置、质量控制和版本登记环节，形成持续维护机制。本文评价的重点是上述本地数据生产、可靠分发、统一读取和模型接口闭环；考虑到网络服务部署与端口安全涉及不同的技术问题，Server/Requestor 不纳入本文核心架构与实验评价。

表1概括2022版与当前论文版本的主要差异。这里将“当前已有行为”与“拟在实验release中实现的增强”分开列示，防止把设计目标误写为已经完成的软件功能。

**表1 2022版与当前论文版本的功能和技术路线比较**

| 环节 | 2022版 | 当前论文版本 | 当前边界 |
|---|---|---|---|
| 分发单元 | NetCDF的`tar.gz` artifact | 可直接读取的`.nc` | 效率优势待3.2节验证 |
| 数据目录 | 软件内置`Artifacts.toml` | 外置并可独立更新的`Artifacts.yaml` | 更新依赖网页文本结构，无schema与回滚 |
| 下载 | artifact下载、哈希寻址和解包 | ping排序、多URL回退、cache至public | 当前无大小或哈希校验 |
| 读取 | `read_LUT` | `read_dataset`，旧名称保留为别名 | 假设全球规则经纬网，不插值 |
| 模型组织 | 标准化数据和通用读取 | `grid_dict`与`grid_weather` | 仅支持固定标签组合 |
| 数据生产 | 数据源专用处理及贡献流程 | YAML驱动的通用处理骨架 | 配置schema与任意维度重排尚未完成 |

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
| 缺失值与范围 | 读取接口统一返回 `NaN`；有效范围、填充值和 gap-filling 规则显式记录 | 缺失值掩膜及各种填补策略符合预期 |
| 变量元数据 | 至少包含单位、可读说明；可映射时使用 CF `standard_name`[2] | schema、单位和标准名检查 |
| 数据溯源 | 记录来源、引用/DOI、许可、处理历史、生成时间和责任主体 | 必填属性完整且链接有效 |
| 处理复现 | 记录生产软件 commit/release、YAML schema 版本和配置哈希 | 能由同一配置重建并对应实验清单 |
| 标签与版本 | 标签表达类别、空间/时间分辨率、年份、版本和可选修订号 | 格式合法、全目录唯一、与文件名一致 |
| 分发完整性 | 目录记录文件字节数和 SHA-256；同一标签各镜像内容相同 | 下载后校验；失败文件不能进入正式目录 |

**Table 2 Standardized NetCDF data and metadata requirements of GriddingMachine.** Each requirement is evaluated by automated tests against the frozen experimental release. A detailed working table, including field-level checks, is maintained with the manuscript materials.

CF 约定不强制固定维度顺序，而是利用坐标变量和属性表达数据含义[2]。GriddingMachine 进一步固定输出维度顺序，是为了降低下游模型接口的复杂度；但生产端不能假设所有源数据已经采用这一顺序。因此，论文实验版本的 YAML schema 需要显式记录源变量各维度的语义，将 `(lat, lon)`、`(ind, lat, lon)` 等排列重排为统一输出，并通过坐标值而非仅凭数组位置判断翻转和循环平移操作。对于非规则网格、区域投影或无法无损映射到规则经纬网的数据，流水线应给出明确错误或进入数据源专用的预处理步骤，而不能静默生成看似合规的文件。

#### 2.2.2 YAML 配置结构

YAML 将数据源差异与通用处理代码分离。当前配置由四类顶层字段组成：`FILE` 描述文件命名模式及 `PREFIX`、空间分辨率 `NX`、时间分辨率 `MT`、可选年份 `YYYY` 和数据版本 `VV`；`FOLDER` 指定原始数据与标准化数据目录；`DATA` 及可选的 `STD` 描述源变量名称、单位、缩放、有效范围、经纬度变换、缺失值策略和处理日志；`GRIDDINGMACHINE` 定义标签及可选修订号。一个配置可以包含多组前缀、分辨率、时间尺度、年份和版本，流水线对其笛卡尔组合逐项生成目标文件。

为避免配置错误在长流程末端才暴露，论文实验版本将为 YAML 增加 `schema_version` 并在读取数据前完成结构校验。字段分为必需字段、具有明确默认值的可选字段和互斥字段；数组长度必须与变量前缀一一对应。维度映射、坐标变量、缺失值、单位、引用、许可和输出属性均由 schema 约束。旧版遗留的 `TARBALL` 字段从生产配置中删除，YAML 网页生成器与处理流水线必须由同一 schema 驱动，确保网页生成的最小配置能够直接运行。以 `wyujie@51cf0fe` 为基线的21份 YAML 尚未完全满足这一要求，例如 `GAPFILL` 并非全部配置均具备，而当前读取函数将其作为必需字段；这些差异将在正式实验前通过 schema 迁移和配置测试消除。

#### 2.2.3 网页配置生成器

`GriddingMachineDatasets`仓库包含一个面向数据贡献者的本地网页工具。其前端表单收集文件命名模式、变量标签、分辨率、时间尺度、版本、输入输出目录、单位、数值范围、缩放、纬度方向及GriddingMachine标签，后端`YamlBuilder`将表单内容转换为YAML，并提供预览和保存接口。该工具的目的不是提供远程数据服务，而是减少手工编辑配置时的拼写、缩进和字段遗漏，使贡献者能够从原始NetCDF开始执行标准化流程。因此，它与本文排除的Server/Requestor具有不同用途。

当前网页工具尚不能作为已经完成的贡献入口：保存目录被固定为一条Linux服务器路径，生成内容仍包含已经取消的`TARBALL`，没有覆盖`GAPFILL`、经度变换、源维度映射和完整溯源字段，相关依赖也未完全纳入根项目环境。论文release须让网页生成器和`process_dataset!`共用同一YAML schema，允许用户选择输出目录，并对表单输入进行字段级校验。契约测试将把网页生成的YAML直接交给流水线；只有能够解析并完成受控数据处理的配置才算通过，单纯生成格式合法的文本不算通过。

#### 2.2.4 数据处理顺序与可追溯输出

`process_dataset!` 首先根据 `FILE` 和 `FOLDER` 定位输入与输出文件，再读取 `DATA` 和可选 `STD` 指定的源变量。当前流水线将数据转换为 `Float32`，依次执行纬度翻转、经度翻转或从 `0～360°` 到 `-180～180°` 的循环平移、线性缩放、有效范围过滤和缺失值处理。处理顺序本身是结果可复现的一部分，因而不能只保存最终数组；每项实际执行的转换都应写入 `history`，并将完整 YAML、配置 SHA-256 和生产代码版本与输出关联。

论文实验版本的自动质量控制将在保存前检查维度、坐标、变量、数值范围和缺失值规则。当前已有的空间方向图可用于人工发现异常，但只作为补充审核；流水线的正确性应由具有已知预期输出的合成 NetCDF 自动断言。验证通过后生成 `data`，存在不确定性时追加同形的 `std`，并按 `TAG_(PREFIX_)NX_MT_(YYYY_)VV(_REVISION)` 生成唯一文件名。若目标文件已存在，流水线不能仅凭文件名跳过，而应比较配置哈希、软件版本和文件校验结果，以区分可安全复用的输出与需要重建的过期或不完整文件。

### 2.3 数据质量检查与目录登记

#### 2.3.1 处理过程中的方向验证

当前生产流水线在 `read_input` 完成经纬度翻转、经度范围调整、线性缩放、有效范围过滤和缺失值处理后，调用 `verify_data!` 对待保存数组进行方向检查。该函数先将数组写入固定的 NetCDF 缓存文件，再调用 Python 脚本生成全球分布图；操作者查看图件后在终端输入 `Y/y` 表示通过，其他输入则终止当前数据的保存。YAML 中的 `VERIFY_ONCE` 用于控制同一配置组合是否只在第一次处理时进行人工确认，通过状态临时写入配置字典的 `VERIFIED` 字段。

这一过程主要用于识别南北颠倒、东西颠倒或经度平移错误，属于交互式人工检查。当前代码使用固定缓存文件名、默认调用 `python3`，审核结论也没有写入最终 NetCDF 或独立记录，因此不适合直接作为无人值守的批处理证据。本文对当前功能的表述限定为“提供空间方向人工验证步骤”，不称其为完整的自动质量控制系统。

#### 2.3.2 标准文件检查

对于已经生成的 NetCDF 文件，`verify_processed_data!` 提供独立的结构和数值检查。该函数首先确认文件存在，并要求覆盖类型为全球陆地和海洋（`both`）或陆地（`land`）。随后检查 `lon`、`lat` 维度和坐标变量、主变量 `data`，当文件具有三个及以上维度时进一步要求 `ind`；同时比较 `data` 各维长度与 `lon`、`lat` 和 `ind` 长度是否一致。数值检查读取完整的 `data` 数组，计算忽略 `NaN` 后的最小值和最大值，并判断其是否位于给定范围内。

缺失值检查取决于覆盖类型。`both` 要求整个数组不存在 `NaN`；`land` 在经度长度为360、720或1 440时读取并重采样 `LM_4X_1Y_V1` 陆地掩膜，逐层检查陆地区域是否含 `NaN`。其他空间分辨率下，代码给出警告并跳过陆地缺失值检查。当前函数尚未检查经纬度坐标的实际取值和单调方向，也未检查 `std`、单位、引用信息和处理日志；这些边界将在验证实验中明确报告。

#### 2.3.3 标签生成与数据目录登记

数据文件名由 `griddingmachine_tag` 生成，基本形式为 `TAG_(PREFIX_)NX_MT_(YYYY_)VV(_REVISION)`。其中 `NX` 表示空间分辨率，`MT` 表示时间分辨率，`YYYY` 和 `REVISION` 为可选部分。生成输出路径时，代码读取当前 `Artifacts.yaml`，如果拟生成标签已经存在则触发断言，从而避免直接产生同名数据文件。

当前的数据发布与登记尚未组成全自动流程。标准 NetCDF 需要先上传至 Zenodo，机构 FTP 副本也需要单独准备；现有 `update_yaml_library!` 脚本尝试从 Zenodo 记录网页提取 `.nc` 文件链接，根据文件名生成标签，并向 `Artifacts.yaml` 条目写入 `PATH` 以及 Zenodo、FTP URL。已有标签会追加新的 URL，新标签则创建目录项，最后对目录排序并写回文件。FTP 上传在代码中仍为 TODO，服务器地址、目录路径和 Zenodo 记录号也采用固定值；脚本还存在变量名不一致和模块加载时直接执行的问题。因此，本文将其描述为“辅助生成目录条目的开发脚本”，不称为已经实现的自动发布系统。

仓库中的 `verify_urls!` 用于初步检查目录地址。它先对各服务器执行 ping，再通过 FTP 目录查询或 HTTP GET 判断文件是否存在，并将异常地址写入日志。但当前全库函数在检查前10个标签后即停止，HTTP 请求关闭了 TLS 证书校验，而且禁止 ICMP 的可用服务器会被直接视为不可访问。由此，现有代码可以辅助抽查部分 URL，不能证明全部1 179个标签均可访问，也不能证明多个 URL 指向内容相同的文件。当前 `Artifacts.yaml` 仅保存 `PATH` 和 `URL`，尚无文件大小或内容哈希字段。

#### 2.3.4 数据贡献与发布流程

一个新数据集进入GriddingMachine依次经历：准备原始文件；通过网页或模板生成YAML；运行`process_dataset!`；检查维度、坐标、变量、数值范围、缺失值和方向图；将标准NetCDF至少上传至一个外部可访问位置，并按条件增加机构镜像；把标签、逻辑路径、URL、文件大小和SHA-256写入`Artifacts.yaml`；发布目录新版本；最后从`GriddingMachine.jl`执行目录更新、下载和读取。机构FTP可以提高校内访问速度，Zenodo或其他公共存储保证校外可用；其他维护者也可在目录条目中增加内容相同的镜像。

这一流程既是维护文档，也是需要验证的软件接口。本文将邀请2～3名未参与相关代码开发的组内成员，分别依据冻结说明处理一个受控数据集并完成模拟登记。实验只判断步骤是否可以独立完成、在哪些环节需要口头干预以及最终NetCDF和目录项是否正确，不把小样本完成时间外推为一般可用性结论。发现的问题用于修订补充材料或项目网站中的逐步指南。

### 2.4 动态目录与多镜像分发

#### 2.4.1 本地目录初始化与加载

`GriddingMachine.jl` 通过 Collector 模块管理数据目录和本地文件。当前代码将工作目录固定为用户主目录下的 `GriddingMachine`，其中 `Artifacts.yaml` 保存数据目录，`cache` 保存下载过程中的缓存文件，`public` 按目录条目中的 `PATH` 保存正式 NetCDF。Collector 模块加载时创建这些目录，并立即调用 `load_database!` 读取 `Artifacts.yaml`，将目录内容和标签分别保存在全局变量 `YAML_DATABASE` 和 `YAML_TAGS` 中。如果本地目录文件不存在，软件包会先访问 Zenodo 下载目录，再完成解析。

目录条目以数据标签为键，当前包含 `PATH` 和 `URL` 两类信息。`dataset_found` 判断标签是否存在；`dataset_path`、`dataset_dir`、`dataset_cache` 和 `dataset_url` 分别返回正式文件路径、目标目录、缓存路径和下载地址数组。该结构使目录内容可以独立于 `GriddingMachine.jl` 的发布版本更新，但也意味着首次加载软件包时可能发生目录创建和网络访问。当前实现没有离线模式或可配置的数据根目录，本文将这一行为作为现有软件边界，而不表述为无副作用的初始化过程。

#### 2.4.2 数据目录更新

`update_database!` 调用 `download_database!` 获取远端目录，随后重新执行 `load_database!` 并更新内存中的标签列表。远端入口目前固定为一个 Zenodo 记录页面。`download_database!` 首先下载该页面的 HTML 文本，查找包含 `Artifacts.yaml?download=1` 的行，从中截取实际文件记录号和下载地址。软件包同时在本地 `Zenodo` 文本文件中保存上次记录号；当远端记录号、本地记录号和目录文件均存在且一致时跳过下载，否则最多重试3次下载 `Artifacts.yaml`，并写入新的记录号。

该机制已经实现“目录更新与软件包版本分离”，但更新过程依赖 Zenodo 网页的具体文本结构，而不是结构化 API。目录文件直接写入正式路径，记录号也在同一下载过程内更新；当前代码没有在替换前执行 YAML 结构检查，也没有保留上一目录版本。因此，本研究可以验证软件包是否发现并加载新目录记录，但不能据现有代码声称目录更新具有原子性或自动回滚能力。

#### 2.4.3 多镜像排序与失败回退

`download_dataset!` 接收一个数据标签。如果标签不在当前内存目录中，函数先调用 `update_database!` 刷新目录；刷新后仍不存在则报错。若对应 NetCDF 已位于正式路径，函数直接返回本地文件，不再访问网络。需要下载时，函数取得该标签的全部 URL，提取各 URL 的服务器地址，调用 `ip_address_ping` 测量往返时间，并按测得时间由小到大排列镜像。

当前 `ip_address_ping` 执行 `ping -c 2 -W 2`，分别解析 macOS 的汇总行或 Linux 的 `time=` 输出；命令失败、输出格式不匹配或无法解析时返回 `Inf`。下载循环按排序结果依次尝试镜像：遇到 `Inf` 时报告服务器不可达；`Downloads.download` 抛出异常时记录警告并继续下一个 URL；某次调用未抛出异常时退出循环。这一实现体现了“优先尝试网络往返时间较短的镜像，并在下载异常时回退”的基本逻辑。

镜像排序目前存在两项明确边界。第一，Windows 的 ping 参数和输出格式与当前实现不同，因此 Windows 上可能把所有镜像判断为不可达；服务器禁用 ICMP 时，即使 HTTP 或 FTP 文件可访问也会得到 `Inf`。第二，ping 反映的是 ICMP 往返时间，不等同于文件协议连接时间、首字节时间或实际传输吞吐率。因而本文在完成跨平台实验前，只称该方法为“基于 ping 的镜像排序”，不称为跨平台最优镜像选择。

#### 2.4.4 缓存落盘与批量同步

每个标签使用 `cache/<TAG>.nc` 作为缓存文件。下载循环结束后，代码创建 `Artifacts.yaml` 中指定的目标目录，并通过 `mv` 将缓存文件移动到正式路径。该设计使正在下载的文件与 `public` 中供读取的数据分离，降低未完成下载直接以正式路径出现的可能性。`sync_database!` 在更新目录后遍历全部标签并调用 `download_dataset!`，每个标签之间暂停1秒，可用于顺序同步整个目录。

当前缓存流程不检查响应内容、文件大小或哈希，也没有独立的下载成功状态。如果所有具有有限 ping 的镜像均在下载时抛出异常，循环结束后仍会执行 `mv`；此时可能因缓存不存在而报错，也可能移动之前残留的同名缓存。现有 `Artifacts.yaml` 不含哈希字段，因此无法判断下载内容是否完整或多个镜像是否一致。本文将通过下载中断、截断文件、错误响应和全部镜像失败等案例验证这些边界；在当前代码未修改前，不使用“完整性保证”或“安全原子下载”等表述。

论文release将恢复2022版artifact流程中已有但在直接NetCDF迁移时丢失的内容校验：目录条目同时登记文件字节数和SHA-256；每次下载使用干净的临时cache；仅当下载成功、字节数和SHA-256均一致时才以原子重命名方式进入`public`；失败时删除本次临时文件并保持已有正式文件不变。该行为必须通过故障注入复测后才能写入结果。

#### 2.4.5 Collector公共操作

除单标签下载外，Collector还提供目录更新、全库同步、旧数据或指定标签清理、目录树和数据集信息查询等操作。师生讨论将这些操作视为新版维护逻辑的一部分，因此不能只测试`download_dataset!`。当前`clean_database!("all")`会递归删除本地public内容，按标签清理会删除cache和正式文件，而`clean_database!("old")`目前仅显示待删除路径，实际删除语句被注释；`sync_database!`会顺序遍历整个目录，完整运行可能涉及超过100 GB数据。论文测试使用隔离的临时数据根目录和小型目录fixture，逐项断言目录与文件状态，禁止在开发者真实数据目录上执行破坏性测试。全库实际迁移只作为运维功能说明，不作为论文实验的必要条件。

### 2.5 统一读取与模型接口

#### 2.5.1 `read_dataset` 统一读取接口

Indexer 模块使用 `read_dataset` 读取本地 NetCDF 或目录标签。当前接口包含4类重载：读取完整数组；按1起始的周期索引读取二维切片；按纬度和经度读取站点的全部周期；按纬度、经度和周期读取单个值。整场和指定周期重载将以 `.nc` 结尾的字符串直接视为本地路径，站点重载则只有在 `isfile` 返回真时才视为本地文件；其他输入被视为 GriddingMachine 标签并传给 `download_dataset!`。这种判断规则目前并不完全一致。旧名称 `read_LUT` 作为 `read_dataset` 的别名保留，因此已有 Julia 代码仍可调用旧接口。

默认读取变量 `data`。当 `raw_data=true` 且文件包含 `raw_data` 时读取原始变量，否则退回 `data`；当 `read_std=true` 时优先读取 `std`，文件不含 `std` 则返回 `nothing`。接口由 NetcdfIO 完成实际数组读取，没有在这一层进行单位转换、缺失值填补或数据质量修正。周期索引也不解释具体月份、日期或小时，调用者需要预先知道第三维的含义和长度。

站点读取根据纬度维长度计算空间分辨率 `res=180/nlat`，再由 `floor((lat+90)/res)+1` 和 `floor((lon+180)/res)+1` 得到数组索引。大于180°的经度先减去360°，随后经纬度被限制在 `[-180°,180°]` 和 `[-90°,90°]`。这一实现依赖数据已经采用全球规则经纬网、`(lon,lat[,ind])` 顺序以及西向东、南向北排列；函数没有读取实际坐标值，也没有进行双线性插值。位于90°纬线或180°经线的端点可能得到超出格点数的索引，区域数据和非规则网格同样不满足当前索引假设。

#### 2.5.2 `grid_dict` 陆地模型参数组织

`grid_dict` 将多个 GriddingMachine 标签组织为单个格点的陆地模型参数字典。当前 `LandDatasetLabels` 支持 `gm1` 和 `gm2` 两组标签，两者使用相同的土壤颜色、van Genuchten 土壤水力参数、冠层高度、叶绿素、叶面积指数、比叶面积、最大羧化速率、地形高程、陆地掩膜和植物功能型数据，主要区别是聚集指数产品。年份用于选择对应的 MODIS 叶面积指数，并用于取得逐月大气 CO₂ 浓度。

按经纬度调用时，函数首先读取陆地掩膜和叶面积指数；目标格点不是陆地或没有正的叶面积指数时直接报错。对于植被格点，函数读取土壤、冠层和叶片变量，对叶绿素、聚集指数、叶面积指数和最大羧化速率的季节序列执行缺失值填补，并重采样为逐日序列。随后根据植物功能型比例和代码内置的 CLM5 参数表计算 C3/C4 Medlyn 模型参数及叶片在可见光和近红外波段的反射率与透射率；叶片质量面积由比叶面积换算，`JMAX25` 和 `B6F` 分别由 `VCMAX25` 乘以固定系数1.73和0.0089得到。

输出字典包括格点位置、分辨率、年份、陆地掩膜、植物功能型比例、CO₂、土壤参数、冠层结构、叶片生物物理参数和光合参数。`verification=true` 时，函数通过 `NaN_test` 断言输出不含未处理的 `NaN`。另一重载可以先构建覆盖全局的 `LandDatasets`，重网格并填补数据，再按数组索引生成植被或裸土格点字典；因此两个入口对非植被陆地格点的处理并不完全一致。代码中还保留 `gm3` 的条件分支，但 `LandDatasetLabels` 构造器只允许 `gm1` 和 `gm2`，该分支从公开构造入口不可达。

#### 2.5.3 `grid_weather` 气象驱动组织

`grid_weather` 用于组织单个格点的逐小时气象驱动。当前 `WeatherDriverLabels` 只支持 `wd1`，并按年份构造8个 ERA5 数据标签，分别对应地表气压、降水、漫射短波辐射、直射短波辐射、长波辐射、气温、水汽压亏缺和风速。按经纬度调用时，函数通过 `read_dataset` 分别读取8个站点时间序列，并转换为调用者指定的浮点类型。

输出为包含 `FDOY`、`PATM`、`PPT`、`RAD_SW_DIF`、`RAD_SW_DIR`、`RAD_LW`、`TAIR`、`VPD` 和 `WIND` 的有序字典。`FDOY` 以逐小时序号为基础，并使用 `lon/15` 形成经度对应的时区偏移；`verification=true` 时同样通过 `NaN_test` 检查输出。另一重载接收已加载的 `WeatherDrivers` 全局数组并按格点索引提取相同字段。

当前模型接口完成的是“按固定标签组合读取并整理数据”，而不是通用模型耦合层。它依赖预定义的 `gm1/gm2` 和 `wd1` 标签、规则网格、既定单位及内置 CLM5 系数，没有在接口层检查单位一致性或记录各字段来源版本；现有测试也尚未给出站点金标准结果。因此，本文现阶段只表述为“提供模型参数字典和气象驱动组织接口”，其数值正确性、年份覆盖、格点边界以及能否完成Emerald初始化和最小步进需要在第3章验证。

## 3 验证设计

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
| Y 配置 | 4 | 最小配置、缺`GAPFILL`、网页生成配置、数组长度不一致 | 成功输出或明确异常 |
| O 输出 | 4 | `data`、`std`、已有文件、标签冲突 | 变量、属性、跳过策略和唯一性 |
| V 人工检查 | 2 | 接受或拒绝方向图 | 是否保存及临时验证状态 |

**Table 3 Synthetic NetCDF test matrix for GriddingMachineDatasets.** The matrix evaluates dimensions, coordinates, numerical transformations, missing-value handling, YAML configurations, output files, and interactive orientation checks. Detailed fixtures and expected outcomes are fixed before code changes; only measurements from the frozen release will be reported as results.

#### 3.1.3 指标与通过标准

每个案例记录结构检查、数值检查和异常检查结果。结构通过要求输出变量、维度、形状和属性与预期一致；数值通过要求逐点结果与金标准一致，Float32转换按预先固定的绝对和相对容差判断；预期失败通过要求函数产生指定类型和阶段的错误，且不留下可被当作正式数据使用的输出。另记录最大绝对误差、最大相对误差、处理日志和重复运行一致性。

全部非交互测试在Linux、macOS和Windows上运行至少3次。论文声称支持的案例必须达到100%的结构和数值通过率；暂不支持的案例必须稳定拒绝，不能静默产生错误结果。人工方向图由至少2名检查者独立判断并保存审核记录，但不计入自动正确率。当前目标分支没有`test/runtests.jl`，本机也没有可用Julia环境，因此本节目前是预先冻结的实验方案，不包含运行结果。

#### 3.1.4 网页配置契约与贡献流程复现

网页契约测试对最小二维数据、含`std`的三维数据、纬度/经度需变换的数据及字段非法数据分别提交表单，检查预览与保存结果是否满足同一YAML schema，并把生成文件直接交给`process_dataset!`。通过要求是合法输入生成的配置无需人工补字段即可得到金标准NetCDF，非法输入在启动处理前给出字段级错误；网页不得生成遗留`TARBALL`，也不得依赖固定服务器路径。

贡献流程复现使用2～3名未参与相关代码开发的组内成员和互不相同的受控数据集。参与者只获得冻结的逐步指南和测试数据，依次完成网页配置、标准化、自动与人工检查、上传模拟、`Artifacts.yaml`登记以及下游更新、下载和读取。记录是否完成、错误步骤、口头干预次数和最终产物断言；发现文档缺陷后修订指南，再由尚未执行该任务的参与者验证。该小样本只用于发现流程中断点，不进行一般用户群体的统计推断，也不把完成时间作为主要结果。

### 3.2 直接NetCDF分发的支持性效率测试

实验选择二维静态高程`ELEV_4X_1Y_V1`、三维8日叶面积指数`LAI_MODIS_2X_8D_2020_V1`和逐小时气温`TAIR_ERA5_1X_1H_2020_V1`作为小、中、大及不同维度的候选产品。每个标准NetCDF分别以原始`.nc`和包含同一文件的`tar.gz`分发，优先复现2022版的压缩参数；无法确认时使用固定的gzip级别6并明确记录。解包后的NetCDF必须与直接文件具有相同SHA-256，确保比较对象的科学内容完全一致。该实验只为“省去额外打包与解包”提供量化支持，不把压缩算法比较作为论文贡献。

测试在同机本地HTTP服务上进行以隔离公网波动，每个组合预热1次并随机顺序重复至少10次，记录传输字节数、打包与解包时间、从请求开始到首次读取一个NetCDF值的时间以及峰值临时磁盘占用。真实镜像不重复进行压缩对比，以免把网络波动误当成格式效应。时间指标报告中位数、四分位距和95% bootstrap置信区间。只有直接NetCDF在端到端时间或临时磁盘占用上表现出稳定定量优势时，才写“提高效率”；否则只写“删除了额外打包与解包步骤”。

### 3.3 Collector操作、多镜像与故障注入测试

#### 3.3.1 公共操作状态矩阵

测试在隔离的临时数据根目录内建立小型远端目录、旧本地目录、2～3个小型NetCDF和两个镜像端点，覆盖本地目录不存在、与远端相同、落后于远端、远端目录损坏及网络不可用等初始状态。逐项调用初始化与加载、`update_database!`、`download_dataset!`、`sync_database!`、`clean_database!`、目录树和数据集信息查询，并检查返回值、内存标签、目录版本、cache和public文件状态。`clean_database!("old")`、`clean_database!("all")`和按标签清理分别测试，但所有删除目标必须位于临时根目录。`read_dataset`的4类重载和`read_LUT`兼容别名也纳入同一回归矩阵。

每个状态转换至少独立重复3次。通过要求不是“函数未抛异常”，而是实际状态与预期完全一致；重复调用应具有预先定义的幂等行为，目录或下载失败不得破坏上一有效版本。`sync_database!`只同步fixture中的小文件，不把超过100 GB的全库下载作为论文必要实验。

#### 3.3.2 多镜像与故障注入

受控实验建立两个内容相同、可独立设置延迟和故障的HTTP端点，覆盖两镜像均可用、首选404、超时、连接重置、禁止ICMP但HTTP可用、全部镜像失败、已有同名缓存、截断缓存、返回HTML、哈希不符和中途截断等场景。每个场景在Linux、macOS和Windows至少独立运行5次，记录协议可达性、首选URL、回退次数、最终结果、错误类型以及cache/public文件的字节数和SHA-256变化。核心通过标准是：任一正确镜像可用时得到与目录哈希一致的文件；所有镜像失败或内容错误时返回明确错误，并保持原正式文件不变。

#### 3.3.3 真实镜像补充检查

真实镜像实验从当前具有多个URL的标签中固定3～5个小中型文件，在中科大校内网络和至少一种校外网络各重复3～5次，记录协议可达性、选择的镜像、回退、吞吐率和内容校验结果。该实验仅确认受控结论在有限真实环境中没有明显矛盾，不比较两个存储服务的长期性能，也不外推到整个目录。当前代码的Windows ping、ICMP误判、无哈希以及全部下载失败后仍可能执行`mv`是基线缺陷；论文结果应报告修复后的release是否通过，而不是把已知缺陷重新包装成未知假设。

### 3.4 统一读取与模型初始化案例

接口验证固定`gm2`陆地参数、`wd1`气象驱动和数据齐全的年份，以2022年论文使用的US-NR1附近植被格点作为主案例，并选择一个裸土格点检查边界行为。运行前依据陆地掩膜和LAI确认格点类别。`read_dataset`与NetCDF底层读取逐项比较；`grid_dict`由各标签的独立读取结果复现缺失值填补、重采样、PFT加权和派生参数；`grid_weather`由8个ERA5序列独立复现`FDOY`。所有字段比较形状、类型、单位、数值和NaN位置，而不是仅调用函数后检查无异常。

数值金标准通过后，固定Emerald版本和依赖环境，将`grid_dict`和`grid_weather`输出用于同一植被格点的模型初始化，并执行能够读取首个气象时间步的最小步进烟雾测试。记录初始化是否成功、字段映射错误、单位或维度错误以及首步是否产生有限状态。本文不比较长期模拟结果、科学性能或计算速度；若投稿前不能完成该最小验证，则`grid_dict/grid_weather`只能作为未完成的软件功能，不能列入摘要的已验证贡献。

## 4 结果

本章结构在实验前冻结，用于避免根据结果改变指标或选择性报告。所有数值均从固定release的原始CSV和日志生成；当前第一版不包含尚未运行的实验结果，方括号内容为回填位置，不代表推断性结果。

### 4.1 数据生产与贡献流程复现

31个合成案例在Linux、macOS和Windows上的总执行次数分别为[待填写]、[待填写]和[待填写]。其中，当前声称支持的[待填写]个案例有[待填写]个达到结构与数值断言，符合预期率为[待填写]%；边界案例中[待填写]个被明确拒绝，[待填写]个产生非预期失败，[待填写]个出现静默错误。各组结果及最大数值误差见表4a。

[实验后从下列两类表述中选择并给出案例编号：①结果支持时，说明维度、坐标、缩放和缺失值处理中哪些组合已通过；②发现缺陷时，说明缺陷触发条件、输出影响以及其是否在论文release中修复。] 重复运行的输出哈希一致率为[待填写]%，人工方向检查的检查者一致性为[待填写]。真实数据案例[数据标签待填写]与其独立参考结果的最大绝对误差为[待填写]。

网页配置生成器的[待填写]个合法表单案例中，[待填写]个生成的YAML无需手工修改即可由流水线处理；[待填写]个非法输入均在处理前得到字段级提示。贡献流程复现共有[待填写]名参与者，其中[待填写]名仅依据文档完成全部步骤；口头干预集中在[步骤待填写]。修订指南后，后续验证者的完成情况为[待填写]。最终NetCDF和目录项的自动断言通过率为[待填写]。

### 4.2 直接NetCDF分发效率

三个候选数据产品的直接NetCDF与`tar.gz`在解包后具有相同SHA-256。受控本地HTTP冷缓存实验中，直接NetCDF相对`tar.gz`的传输字节变化为[待填写]%，端到端首次读取时间变化为[待填写]%，峰值临时磁盘占用变化为[待填写]%；分数据类型的结果见表4b。

[仅在置信区间和重复实验支持时写入方向性结论。若外层压缩节省传输量但增加解包时间，则分别报告带宽受限和本地处理受限条件，不给出“直接NetCDF始终更快”的总体结论。]

### 4.3 Collector操作、多镜像与故障注入

Collector状态矩阵覆盖[待填写]个初始状态和[待填写]项公共操作。初始化/加载、目录更新、单标签下载、小型目录同步、三类清理、目录树、信息查询及`read_dataset`重载分别有[待填写]项符合预期；重复调用的状态一致率为[待填写]%。目录损坏或网络失败时，上一有效目录和正式文件保持不变的案例数为[待填写]/[待填写]。`read_LUT`兼容别名与`read_dataset`的结果一致率为[待填写]%。

受控双镜像实验共执行[待填写]个“平台—场景”组合和[待填写]次下载。Linux、macOS和Windows的成功率分别为[待填写]%、[待填写]%和[待填写]%，在首选镜像返回404、超时或连接重置时的正确回退率分别为[待填写]。禁止ICMP但HTTP可用、全部镜像失败、残留缓存、HTML响应和中途截断等场景的正式目录状态正确率见表4c。

真实网络实验覆盖[待填写]个具有多个URL的标签。校内和校外网络的有效下载数/总尝试数分别为[待填写]和[待填写]，镜像选择、吞吐率、回退次数和内容校验结果为[待填写]。这些结果只代表选定标签和测量时段，不外推至整个目录。基线代码中的Windows ping、ICMP误判、缺少哈希和失败后移动缓存问题对应的修复commit为[待填写]，修复后复测通过数为[待填写]/[待填写]。

### 4.4 统一读取与模型初始化接口

在[最终格点和年份待填写]上，`read_dataset`各重载与NetCDF底层读取的比较次数为[待填写]，一致率为[待填写]%，最大绝对误差为[待填写]。`grid_dict`的[待填写]个输出字段和`grid_weather`的9类输出中，分别有[待填写]和[待填写]项与独立金标准在既定容差内一致；缺失值、端点和裸土边界行为见表4d。

在Emerald[版本待填写]中，`grid_dict`输出完成固定植被格点初始化的结果为[成功/失败，待填写]，`grid_weather`首个时间步完成最小步进的结果为[成功/失败，待填写]。发现的字段、单位或维度映射问题及修复commit为[待填写]。裸土格点产生的预期边界行为为[待填写]。本节不报告长期模型结果，也不据此评价Emerald的科学性能。

## 5 讨论

### 5.1 从数据集合到可维护工作流

2022版GriddingMachine的主要贡献是建立统一的网格和变量约定，并通过标签及Julia artifact降低多源全球数据的发现和调用成本[4]。当前更新进一步把新数据贡献、目录与镜像维护、统一读取和模型初始化数据组织连接起来。其关键变化不是TOML换成YAML，也不是单纯增加数据数量，而是让贡献者能够按同一契约制作数据，让目录独立于软件更新，让同一标签可从多个位置取得并校验内容，并让固定的数据组合直接形成模型初始化输入。表1同时表明，这一演进尚未完成：基线代码已有YAML处理骨架、网页原型、外置目录、多URL、缓存落盘和模型字典，但schema、完整性校验、安全发布、完整回归测试及部分跨平台行为仍需在论文release中补齐。

第4章实验完成后，本节将据RQ1—RQ4回答这些变化是否形成可重复的工作流。生产正确性依据逐点金标准和网页—流水线契约，而非流程成功退出；贡献流程依据未参与开发者能否按文档独立完成；分发可靠性以故障后的正式目录状态和内容哈希为核心；公共接口依据状态转换断言；模型接口则同时满足数值金标准和Emerald最小初始化。这样的评价方式避免用功能列表或主观代码量替代验证。

### 5.2 与相关地球科学数据基础设施的关系

Earth Engine把大规模地理空间数据与云端计算结合，适合服务器侧的行星尺度分析[3]；ESGF通过分布式节点、搜索和联合身份基础设施支撑气候模式数据的发现与访问[5]；Pangeo倡导分析就绪、云优化数据以及计算与数据邻近的云原生模式[6]。GriddingMachine不试图替代这些通用或大规模平台。它面向的是一组经过选择和统一的全球规则网格产品，以及需要在本地Julia工作流中按固定标签复现参数与气象驱动的模型使用场景。

因此，GriddingMachine的互补性体现在三个层次：以YAML保留从异构源数据到标准NetCDF的处理意图；以轻量目录连接机构镜像和通用存储；以`read_dataset`、`grid_dict`和`grid_weather`把标准数据组织为模型所需字段。对于接近云端的超大数据分析，云优化分块格式和数据邻近计算更合适[6]；对于CMIP等机构联合数据，ESGF的联合治理更成熟[5]。GriddingMachine的适用范围应限定为可下载、可本地缓存的规则网格数据，不能由本研究推及任意规模或任意网格的地球科学数据。

### 5.3 FAIR与可复现性的实际边界

标签和外置目录提高数据的可发现性，多URL和直接NetCDF有助于获取，统一网格与变量约定支持互操作，来源、许可、处理记录和版本信息则关系到复用[1]。但是，采用YAML、NetCDF或Zenodo本身并不自动满足FAIR。当前目录缺少文件大小和内容哈希，部分标准文件元数据尚未由schema统一约束，目录更新也没有事务式替换与回滚；这意味着用户可能能够找到并下载文件，却仍不足以证明镜像一致、文件完整或处理可重建。

论文实验release应把配置哈希、代码版本、文件大小和SHA-256连成最小溯源链，并将每项结果关联到不可变release和原始日志。只有当目录校验、下载后校验、失败清理和重复构建测试全部通过，才可将“可复现”和“可靠”从设计目标提升为结果支持的结论。

### 5.4 局限与后续工作

第一，生产流程当前对源维度顺序作较强假设，21份YAML也没有完全服从统一schema；非规则网格、区域投影和复杂时间坐标仍需要数据源专用预处理。第二，空间方向依赖人工查看图片，审核记录未写入数据溯源；自动坐标和值域断言应成为主检查，人工判断只作补充。第三，基于ping的镜像排序受操作系统、ICMP策略和网络瞬时状态影响，且往返时间不等于实际吞吐率。更稳健的实现应直接探测文件协议，以小范围请求或历史传输统计排序，并在全部失败时保持正式目录不变。

第四，网页配置生成器当前仍有固定路径、遗留字段和依赖未声明等问题；小样本组内复现只能发现明显流程中断点，不能证明面向所有用户的可用性。第五，`read_dataset`按规则网格公式换算索引，没有读取实际坐标，也没有插值，极区和日期变更线端点存在越界风险；当前接口还不检查单位。第六，`grid_dict`和`grid_weather`依赖固定的`gm1/gm2`、`wd1`标签与内置系数，本文的Emerald最小步进只能证明接口可接入，不能证明长期模拟结果或推广到其他模型。后续可增加显式数据清单、单位和来源版本检查，再通过模型适配层支持不同模型。Server/Requestor远程子集服务可作为独立研究方向评估，但不纳入本文核心贡献。

## 6 结论

本文在2022版GriddingMachine基础上提出连接数据贡献、标准化生产、目录与镜像维护、统一读取和模型初始化的更新方案。当前`wyujie`基线已经具有YAML驱动的生产骨架和网页原型、可独立更新的YAML目录、直接NetCDF分发、多URL尝试、缓存落盘以及`read_dataset`、`grid_dict`和`grid_weather`接口；代码复核同时表明，YAML格式变化本身不是核心贡献，schema与维度映射、SHA校验、安全落盘、Collector回归和模型初始化验证才是投稿前必须完成的内容。

本文据此设计合成数据与网页契约、贡献流程复现、直接NetCDF支持性效率对比、Collector状态回归、三平台故障注入、固定格点金标准和Emerald最小初始化实验，使软件更新由工作流正确性和状态证据评价，而不是由功能描述评价。**[实验完成后在此用3—5句填入由结果直接支持的定量结论，并同步更新中英文摘要。]** 在缺少相应实测证据时，本研究不声称直接NetCDF必然更快、镜像选择跨平台最优、下载已经具备完整性保证，或接口已经验证长期模型模拟。

GriddingMachine的定位是面向地球系统模拟的轻量、可维护的数据基础设施：它通过固定数据约定减少重复适配，并以目录和模型数据接口连接数据发布者与使用者。完成实验release、溯源字段和自动测试后，该框架有望为全球规则网格数据的持续维护和可复用模型输入提供更可验证的路径。

## 数据和代码可用性声明

GriddingMachine.jl源代码公开于https://github.com/CliMA/GriddingMachine.jl，本文当前代码基线为`wyujie@715268067645b0b68ba76ffb7c1be945de048705`。数据生产代码公开于https://github.com/jhOo1/GriddingMachineDatasets，当前基线为`wyujie@51cf0fee842c6c731b8c1836841682afec52df48`。论文材料与实验协议位于https://github.com/jhOo1/GriddingMachine_Reaserach。【投稿前以正式release tag和归档DOI替代分支描述，并补充数据目录、原始结果、环境文件与绘图脚本的永久地址。】

## 作者贡献

姜皓：概念设计、软件、验证、数据整理、可视化、初稿撰写【待作者确认】。王玉杰：概念设计、研究指导、项目管理、论文审阅与修改【待作者确认】。其他作者贡献待实际参与情况确定。

## 利益冲突声明

作者声明不存在利益冲突【投稿前由全体作者确认】。

## AI 工具使用声明

本文准备过程中使用 OpenAI Codex 辅助梳理研究材料、检查论文结构、形成文字初稿和协助代码审查。所有研究问题、方法选择、代码修改、实验设计、数据、结果解释和最终文字均由作者核验并承担责任。投稿前将依据实际使用情况补充工具版本、使用环节和人工核验过程。

## 参考文献

[1] WILKINSON M D, DUMONTIER M, AALBERSBERG I J, et al. The FAIR Guiding Principles for scientific data management and stewardship[J]. Scientific Data, 2016, 3: 160018. DOI: 10.1038/sdata.2016.18.

[2] CF CONVENTIONS COMMITTEE. CF Metadata Conventions[EB/OL]. [2026-08-07]. https://cfconventions.org/.

[3] GORELICK N, HANCHER M, DIXON M, et al. Google Earth Engine: Planetary-scale geospatial analysis for everyone[J]. Remote Sensing of Environment, 2017, 202: 18-27. DOI: 10.1016/j.rse.2017.06.031.

[4] WANG Y, KÖHLER P, BRAGHIERE R K, et al. GriddingMachine, a database and software for Earth system modeling at global and regional scales[J]. Scientific Data, 2022, 9: 258. DOI: 10.1038/s41597-022-01346-x.

[5] CINQUINI L, CRICHTON D, MATTMANN C, et al. The Earth System Grid Federation: An open infrastructure for access to distributed geospatial data[J]. Future Generation Computer Systems, 2014, 36: 400-417. DOI: 10.1016/j.future.2013.07.002.

[6] ABERNATHEY R P, AUGSPURGER T, BANIHIRWE A, et al. Cloud-native repositories for big scientific data[J]. Computing in Science & Engineering, 2021, 23(2): 26-35. DOI: 10.1109/MCSE.2021.3059437.
