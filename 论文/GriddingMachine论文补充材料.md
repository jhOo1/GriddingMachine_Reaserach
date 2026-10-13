# GriddingMachine论文补充材料（仓库复审同步）

## S1 从目录更新到模式参数组织的Julia示例

以下示例对应正文2.4节，依次完成数据目录配置与更新、ELEV数据集完整性下载、US-NR1附近格点读取和2020年第二套陆面参数集合（`gm2`）的参数组织。`gm2`由14类土壤、冠层、叶片、地形、陆地掩膜和植物功能型标准化数据集组成。

| 数据操作 | 公共接口 | 主要输出 |
|---|---|---|
| 配置数据环境 | `configure!` | 数据根目录与目录来源 |
| 更新数据集目录 | `update_database!` | 通过schema校验的版本化目录 |
| 获取标准化数据集 | `download_dataset!` | 事务式获取；对带`SIZE`/SHA-256条目可执行严格完整性核验 |
| 读取规则网格 | `read_dataset` | 全域网格、周期或站点数据 |
| 融合陆面参数 | `grid_dict` | 格点级模式参数字典 |
| 组织气象驱动 | `grid_weather` | 格点级气象时间序列 |

真实气象案例在US-NR1读取2020年8类ERA5标准化数据集。八文件共12 575 376 138字节，各字段包含8784个逐小时值；`grid_weather`与`NetcdfIO.read_nc`底层读取的最大绝对差均为0，FDOY与按输入站点经度计算时间偏移的独立公式逐点一致。真实陆面参数和气象驱动共同通过Emerald初始化及60 s首步。单位审计确认PPT按米水层解释；修订文件以V1_R1物理文件发布到机构FTP，原V1保留，正式目录的V1逻辑标签指向R1。FTP回下载和全新Collector获取均通过SIZE/SHA-256与结构核验。逐文件SHA-256、值域和环境见`experiment_data/03_09/real_era5_result.toml`及`论文/experiments/03_09_ERA5真实气象链路实验结果.md`。投稿代码与研究材料通过带注释Git标签冻结，标签、精确提交号及PPT R1制品摘要统一记录于`论文/投稿版本锁定.toml`。

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

目录和标准化数据集也可来自完成归档与完整性核验的研究材料。此时通过`catalog_file`和数据根目录指定相应副本，后续读取及模式参数组织保持相同接口。

### S1.1 气象时间轴与降水量纲

气象接口按年度逐小时序列构建模式时间轴。第k个小时的索引从1开始，按接口的小时中点约定和经度λ（东经为正，单位为度）计算`FDOY = (k − 0.5 + λ/15) / 24`。零点对应所选年度UTC的起始时刻，λ/15为地方平太阳时相对UTC的小时偏移；该约定用于构建模式时间轴，不改变源文件的气象变量值。经纬度调用采用请求位置的经度，数组索引调用采用规则格点中心经度。Emerald以FDOY计算太阳天顶角，使气象序列与模式的日内辐射计算对应。US-NR1请求经度为−105.5464°，偏移为−7.0364267 h，2020年的8784个小时依次保持连续编号。实现分别见GriddingMachine.jl的`src/Indexer/grid-weather.jl`和Emerald的`src/Land/simulation/5-prescribe.jl`。

ERA5逐小时总降水按每小时累计的米制水层解释，依据为正文文献[11]所列ERA5 reanalysis hourly data定义。标准NetCDF降水的原始数值保持不变，单位属性由`mm`修订为`m`；年度累计0.496409 m等于496.409 mm，作为数值尺度和量纲的核对结果。Emerald采用`q = P × ρ / (M × Δt)`将其转为摩尔通量，其中P为小时累计水层厚度（m），ρ为水密度（kg m⁻³），M为水的摩尔质量（kg mol⁻¹），Δt为3600 s，q的单位为mol m⁻² s⁻¹。

### S1.2 光合参数换算与单位

叶片羧化与电子传递能力的关联参见正文文献[8]。具体参数组织采用所用GriddingMachine模式输入实现的固定比例：`JMAX25 = 1.73 × VCMAX25`，`B6F = 0.0089 × VCMAX25`。其中VCMAX25和JMAX25分别表示25 ℃下最大羧化速率和最大电子传递速率，单位为μmol m⁻² s⁻¹；B6F表示细胞色素b6f复合体含量，单位为μmol m⁻²。0.0089为该速率到含量换算所采用的比例系数，其时间量纲为s。固定比例来源于GriddingMachine.jl的`src/Indexer/grid-dict.jl`，参数单位对应Emerald的`src/Namespace/plant/leaf/photosynthesis.jl`定义。这些关系用于本文的模式参数组织，文献[8]提供生理关联背景，具体比例由上述实现规定。

### S1.3 ERA5文件与输入字段记录

本文2020年ERA5案例采用8类文件，合计12 575 376 138字节，各主变量的形状均为360×180×8784。站点序列由FDOY和地表气压、降水、漫射与直射短波辐射、长波辐射、气温、水汽压亏缺及风速组成，共9个输入字段；Emerald适配后形成16个模式驱动字段。逐文件大小、SHA-256、变量单位和值域，以及模式字段记录保存在`experiment_data/03_09/real_era5_result.toml`和`论文/experiments/03_09_ERA5真实气象链路实验结果.md`。

## S2 Collector目录维护接口

Collector在单标签获取之外提供目录更新、全库同步、历史数据整理、目录树和数据集信息查询。`sync_database!`在更新目录后遍历有效标签并复用事务式下载逻辑；历史数据整理依据当前有效目录识别版本状态；路径、URL、完整性元数据和本地文件状态通过统一查询接口呈现。目录更新、同步和数据获取共享schema校验和临时文件落盘逻辑；当目录条目提供`SIZE`与`SHA256`时，可启用严格完整性核验。历史兼容条目若缺少这些字段，不计入本文严格完整性结论。

### S2.1 标签、目录字段与更新过程

标签基本形式为`TAG_(PREFIX_)NX_MT_(YYYY_)VV(_REVISION)`，表达类别、可选前缀、空间与时间分辨率、可选年份、数据版本及可选修订号。目录条目以标签为键，字段包括安全相对路径`PATH`、一个或多个下载地址`URL`，以及可选文件字节数`SIZE`和摘要`SHA256`。目录生成器根据待发布NetCDF及公开地址生成相对路径和去重地址列表；对新登记或严格管理的条目计算字节数与SHA-256。

远端目录先下载到临时路径，经根节点和字段规范校验后替换本地正式目录，并保留上一有效版本。各镜像尝试使用进程级唯一临时文件；内容核验通过后才进入正式路径，失败尝试与既有有效文件相互隔离。全库同步、状态查询和历史数据整理复用相同目录与获取逻辑。

### S2.2 目录管理评价操作

目录管理评价采用不同版本的Artifacts.yaml、多个NetCDF文件与两个镜像端点，覆盖目录首次建立与更新、单数据集获取、全库同步、历史整理和状态查询。重复调用的获取结果、文件摘要及缓存状态与小型参考目录的预设结果比较；对应的镜像与缓存状态矩阵见S6，完整操作和原始文件记录随研究材料归档。

## S3 配置与贡献材料

YAML以`SCHEMA_VERSION`标明配置规范版本，`FILE`描述文件命名及批量组合，`FOLDER`指定原始数据和输出目录，`DATA`及可选`STD`描述源变量与处理规则，`GRIDDINGMACHINE`记录数据标签和可选修订号。`DIMENSIONS`明确每个源变量的维度顺序；坐标方向、缩放、有效范围和`GAPFILL`缺失值策略均由相应字段表达。配置校验在执行前检查字段类型、必需项、数值范围、互斥关系及批量参数长度。字段说明和贡献步骤见GriddingMachineDatasets的配置规范及贡献指南。

以下为本文OISST案例实际使用的完整配置，对应`experiment_data/03_08/oisst_20220225.yaml`。源适配器已提取单例时间与垂向维度并解码存储值，配置进一步声明源维度、经度变换、有效范围和原值保持策略。

```yaml
SCHEMA_VERSION: 1
GRIDDINGMACHINE:
  TAG: "SST_OISST"
DATA:
  LABEL:
    - "sst_source"
  UNIT: "degree_Celsius"
  CHANGE_LOGS:
    - "The only time and zlev layers were extracted by the versioned OISST source adapter."
    - "Packed source values were decoded using the source scale_factor and add_offset."
    - "Source fill values were represented as NaN."
    - "Source identity: oisst-avhrr-v02r01.20220225.nc; SHA-256: b5e91dacb3ed85819b47b516dd4edb7dab7fb6ae7bf67062cef03cd0333c9b73."
  VERIFY_ONCE: false
  LIMITS:
    - -3.0
    - 45.0
  ABOUT: "NOAA/NCEI OISST v2.1 daily sea surface temperature for 2022-02-25."
  GAPFILL: "KEEP_AS_IS"
  DIMENSIONS:
    sst_source:
      - "lon"
      - "lat"
  FLIP_LON: true
FILE:
  PATTERN: "PREFIX_NX_X_MT_YYYY_VV.nc"
  PREFIX:
    - "OISST"
  YYYY:
    - 20220225
  VV:
    - "V1"
  NX:
    - 4
  MT:
    - "1D"
FOLDER:
  ORIGINAL: "oisst"
  REPROCESSED: "oisst"
```

本地交互式配置生成器提供表单化输入、YAML预览与保存功能。界面提交的结构化参数由`YamlBuilder`转换为配置对象，并使用与`process_dataset!`相同的schema完成字段解析。交互界面与程序化构建方式由此生成结构一致、可直接进入标准化数据生产流水线的YAML配置。

### S3.1 缺失值策略及生产检查

`GAPFILL`支持数值常数、`MEAN`、`KEEP_AS_IS`、`INT_NAN_TO_1`、`NO_LAND_NAN`和`NO_NAN`。数值常数和`MEAN`分别以给定值或分层`nanmean`填补陆地区域缺失值；`KEEP_AS_IS`保持数组中的缺失状态；`INT_NAN_TO_1`将缺失值补为1并对数组整数化；后两项分别检查陆地区域和全域是否仍有缺失值。策略应与变量的物理含义及区域适用性相符。高程填补配置采用常数0，ELEV重复处理实验则采用`KEEP_AS_IS`，且不执行缩放和范围裁剪，二者用于不同处理目的。

生产流程读取主变量与可选不确定性变量后转换为`Float32`，再按配置重排维度、调整坐标、缩放、过滤有效范围并处理缺失值。标准支持分辨率的陆地完整性检查使用重采样的`LM_4X_1Y_V1`掩膜，其他分辨率采用对应专用规则。`VERIFY_ONCE`记录同一配置组合的首次空间方向确认；方向图与自动结构检查共同核对数据和坐标的对应关系。

## S4 标准化数据生产操作矩阵

标准化数据生产评价由31个编号实例组成，其中29个为自动实例，空间方向测试 V01（方向正确）和 V02（南北反转）用于人工检查。自动实例在Windows、macOS和Linux持续集成环境中运行，人工实例分别呈现方向正确和南北反转的非对称位置编码图。

**表S1 标准化数据生产操作矩阵**

| 环节 | 实例数 | 主要内容 | 核对内容 |
|---|---:|---|---|
| D 维度 | 5 | 2D/3D标准顺序、`(lat,lon)`、`(ind,lat,lon)`和维度约束 | 输出形状、维度名及逐点位置 |
| C 坐标 | 4 | 纬度翻转、经度翻转、`0～360°`平移和组合变换 | 坐标方向及位置编码值 |
| N 数值 | 4 | Float32、线性缩放、有效范围和原值处理 | 绝对与相对误差、NaN掩膜 |
| G 缺失值填补 | 8 | 常数、分层`nanmean`、原值保持、陆地与全域完整性和整数化 | 填补位置、填充值、覆盖范围和处理记录 |
| Y 配置 | 4 | 最小配置、缺失字段、构建器输出和数组长度一致性 | schema解析、字段定位和数据集生成状态 |
| O 输出 | 4 | `data`、`std`、已有文件和标签状态 | 变量、属性、重复运行和标签唯一性 |
| V 方向检查 | 2 | 正向图和南北反转图 | 空间方向与坐标语义 |

自动实例使用确定性位置编码数组，使维度交换、坐标变换和数值处理后的目标值均可直接计算。完整原始记录位于`论文/experiments/03_01_data`，实验设计和结果说明分别位于`论文/experiments/03_01_数据生产正确性测试协议.md`和`论文/experiments/03_01_Windows合成矩阵结果.md`。

### S4.1 OISST登记与下载记录

连续3次生成的OISST标准文件均为997 006字节，数据值、坐标和SHA-256保持一致。目录登记与回环HTTP获取通过字节数和SHA-256核验，下载后未遗留临时文件；统一读取结果与独立参考逐点一致。完整记录见`论文/experiments/03_08_真实异构OISST端到端结果.md`及`experiment_data/03_08`。

## S5 跨操作系统运行一致性与应用证据矩阵

证据由固定依赖下的持续集成、本地独立环境观测以及真实网络与数据应用三个层次组成。持续集成用于检查确定性核心代码路径在Windows、macOS和Linux上的运行一致性；性能、真实网络和真实数据案例按各自环境单独记录，不将环境依赖结果等同于广义科学可复现性。

**表S2 跨操作系统运行一致性证据矩阵**

| 证据层次 | 运行环境 | 模块或案例 | 主要记录 |
|---|---|---|---|
| 核心软件持续集成 | Windows、macOS、Linux | GriddingMachine核心测试 | 各系统63项测试完成 |
| 数据生产持续集成 | Windows、macOS、Linux | 配置测试与包集成 | 各系统38项配置测试和35项包集成测试完成 |
| 研究材料持续集成 | Windows、macOS、Linux | 生产矩阵、确定性分发、镜像状态 | 各系统29组非交互实例、40次分发测量和65次状态断言完成 |
| 模式接口持续集成 | Windows、macOS、Linux | Emerald合成输入最小接口 | 各系统5项状态断言完成 |
| 本地独立环境 | Windows、macOS | ELEV/LAI效率与13类镜像状态 | 端到端时间、SHA-256、正式文件和临时文件状态 |
| 公共网络观测 | 两个独立网络环境 | 4个Zenodo标签 | 24次字节数与SHA-256记录 |
| 校内网双镜像 | 中科大校内网 | 4个FTP—Zenodo同文件数据集 | 24次传输、字节数、SHA-256和延迟记录 |
| 真实数据应用 | US-NR1案例环境 | 14类陆面数据集、8类ERA5和Emerald | 参数字段、8784步时间轴、量纲、逐点值、初始化和60 s首步 |

持续集成记录、平台Manifest及原始输出随冻结研究材料归档。真实网络观测按照网络环境记录，真实数据应用按照数据和模式链路记录，使运行一致性、网络访问和科学数据应用分别具有对应证据。

### S5.1 多语言数据自动下载

Matlab、Octave、Python、R、C和Fortran接口均支持文件URL和数据标签下载。各接口通过同一Python程序解析本地Artifacts.yaml、尝试目录中的候选镜像，并在提供文件大小或SHA-256信息时核验内容。以下为调用方式示例，其中URL、TAG、FILE、BYTE_COUNT和DIGEST分别表示文件地址、数据标签、本地输出路径、文件字节数和SHA-256摘要。

| 语言 | URL下载 | 标签下载 |
|---|---|---|
| Matlab / Octave | `gm_download(url, output, 'Size', byte_count, 'SHA256', digest)` | `gm_download('', output, 'Tag', tag, 'Catalog', catalog_path)` |
| Python | `python3 clients/download.py --url URL --output FILE --size BYTE_COUNT --sha256 DIGEST` | `python3 clients/download.py --tag TAG --catalog Artifacts.yaml --output FILE` |
| R | `gm_download(url, output, size = byte_count, sha256 = digest)` | `gm_download(output = output, tag = tag, catalog = catalog_path)` |
| C | `gm_c --url URL --output FILE --size BYTE_COUNT --sha256 DIGEST` | `gm_c --tag TAG --catalog Artifacts.yaml --output FILE` |
| Fortran | `gm_fortran --url URL --output FILE --size BYTE_COUNT --sha256 DIGEST` | `gm_fortran --tag TAG --catalog Artifacts.yaml --output FILE` |

文件URL调用中的大小和摘要参数可按所需核验信息提供；标签调用使用目录登记的完整性信息。C和Fortran入口先编译为可执行程序，各语言均可指定Python运行路径及下载脚本位置。Windows的Python命令使用`python`；完整安装与调用说明见GriddingMachine.jl的`clients/README.md`。

独立运行记录覆盖原有URL调用、文件大小与摘要核验、标签下载及首镜像不可用时的回退、错误SHA-256、错误目录文件大小和指定下载脚本六类情形。成功下载的二进制内容、字节数和摘要与参考文件一致；错误完整性信息得到明确返回，原文件保持不变且无临时文件残留。运行采用与源码不同的工作目录，路径包含空格和特殊字符；Linux案例还包含中文文件名。

Python的13项回归用例在Linux和Windows完成；C、Fortran和R在两类环境分别完成六项接口用例，Octave在Linux完成六项。Matlab使用R2025b Update 7的真实会话独立完成六项调用。详细版本、逐项结果及云端日志见`clients/VALIDATION.md`、跨语言运行记录https://github.com/CliMA/GriddingMachine.jl/actions/runs/38398605480与Matlab运行记录https://github.com/CliMA/GriddingMachine.jl/actions/runs/38398605598。

## S6 多镜像受控状态场景

多镜像获取评价由13个受控状态场景组成，覆盖候选排序、地址遍历、缓存复用、内容完整性和正式文件状态。每个场景在Windows和macOS独立环境中重复5次，候选顺序、获取结果、SHA-256、临时文件回收和正式文件状态构成统一记录。

**表S3 多镜像获取与内容完整性场景矩阵**

| 编号 | 镜像或缓存状态 | 主要核对内容 |
|---|---|---|
| M01 | 两个镜像均可用且具有不同延迟分数 | 较低延迟候选优先 |
| M02 | 首选地址返回404，第二地址提供完整文件 | 镜像回退与完整文件落盘 |
| M03 | 第一地址延迟分数为`Inf`，第二地址具有有限分数 | 有限分数候选优先 |
| M04 | 首选地址连接重置，第二地址提供完整文件 | 镜像回退与临时文件回收 |
| M05 | 唯一镜像延迟分数为`Inf`且可下载 | 全部URL保留在尝试队列 |
| M06 | 两个镜像均处于下载异常状态 | 正式文件保持及完整错误汇总 |
| M07 | 所有延迟分数为`Inf`且镜像访问异常 | 按目录顺序遍历全部URL |
| M08 | 缓存区已有同名完整文件且镜像访问异常 | 既有缓存保持 |
| M09 | 缓存区已有截断文件 | 缓存隔离与正式目录状态 |
| M10 | 地址返回HTML内容 | 文件类型内容的摘要判定 |
| M11 | 传输过程产生截断文件 | 临时文件回收与正式目录状态 |
| M12 | 正式文件已存在且完整 | 完整性复核与缓存复用 |
| M13 | 返回内容字节数正确而SHA-256不同 | 摘要核验与正式目录状态 |

M01—M13的原始记录、候选访问顺序和逐次状态位于`论文/experiments/03_03_data`，汇总结果分别对应65次独立运行和两个操作系统环境中的130次获取记录。


## S7 术语、目录覆盖与PPT修订案例

### S7.1 操作性定义

- **可信分发（trustworthy distribution）**：版本化目录、镜像回退和独立临时文件共同组织获取；对于登记了`SIZE`和SHA-256的条目，可在严格模式下核验内容身份后再进入正式目录。该术语关注目录登记对象与下载内容的一致性，数据源真实性、科学质量和长期服务可用性分别由上游质控和运行环境记录。
- **模式就绪（model-ready）**：标准化数据集经格点索引、字段组织、时间轴构建和量纲衔接后形成满足本文所测试Emerald初始化接口的数据结构，并可完成60 s首步。本文的评价范围集中于数据组织、初始化和首步接口运行。
- **跨操作系统运行一致性**：固定依赖和既定测试路径在Windows、macOS和Linux中的结构、数值、摘要和状态结果满足相同判据，用于描述核心实现的跨平台运行一致性。

### S7.2 目录覆盖边界

研究所用目录的统计日期为2026年8月15日，原始记录保存于`experiment_data/03_07/catalog_audit/catalog_coverage_summary.toml`。目录覆盖率反映该版本的数据发布和镜像迁移情况。统计时1179个条目均已登记机构FTP地址，其中部分数据集进一步完成Zenodo等公共镜像登记；`SIZE`/SHA-256可由权威文件批量计算并随发布过程回填。目录schema统一支持多个URL和完整性字段，Collector按照已登记镜像执行获取与核验。正文中的严格完整性和真实多镜像实验采用已经完成相应配置的代表性数据集。

### S7.3 逻辑标签与物理制品修订

ERA5降水数据集提供真实修订案例。逻辑标签保持`PPT_ERA5_1X_1H_2020_V1`，修订后的物理文件为`PPT_ERA5_1X_1H_2020_V1_R1.nc`。原V1物理文件保留，目录将V1逻辑标签的URL指向R1并登记：

- 字节数：`1102213097`；
- SHA-256：`1ae6b80512fac97e6b3e609c02ea126858256cf9153ead1335b5bf8d59fe7725`；
- 全新Collector按V1逻辑标签首次获取R1并通过严格完整性核验；
- 第二次调用复用正式缓存，没有再次访问网络；
- 获取过程未遗留`.part`临时文件。

该案例说明稳定逻辑身份可以与可修订物理制品解耦；原始V1、修订R1及其独立摘要共同保留版本边界。原始记录见`experiment_data/03_09/ftp_r1_release_result.toml`和`experiment_data/03_09/collector_ftp_r1_result.toml`。

## S8 代码版本、数据修订与实验记录

ERA5案例的逐文件大小与SHA-256、格点统计、时间轴核对和模式状态保存在`experiment_data/03_09/real_era5_result.toml`；PPT修订文件以V1_R1后缀发布，逻辑标签保持V1，目录记录其文件大小、SHA-256和机构FTP地址。既有主体实验使用的核心代码版本分别以`griddingmachine-paper-2026-v1`、`griddingmachine-datasets-paper-2026-v1`和`emerald-paper-2026-v1`标签固定。多语言下载入口位于GriddingMachine.jl的`clients`目录，对应发布分支提交`a2baba10e5bb3498d8a2a4114f19c58b8937ddbc`；该提交包含六种语言的下载接口、调用说明及实际运行验证记录。研究材料的内容冻结提交、冻结分支及不可变稿件标签由`论文/投稿版本锁定.toml`统一记录；永久归档与DOI信息随最终归档版本同步发布。
