# GriddingMachine `wyujie` 分支投稿前代码审计

> 审计日期：2026-08-07  
> 审计范围：论文核心涉及的数据生产、质量控制、发布、目录、下载、读取及模型接口  
> 明确排除：`Server/Requestor` 不作为论文核心内容  
> 方法：源码与仓库结构静态审计；当前机器只有 WindowsApps 的 Julia 占位程序，无法执行 Julia，因此所有运行时问题仍需在可用 Julia 环境复核

## 1. 审计基线

| 仓库 | 目标分支 | 本轮固定 commit | 版本/状态 |
|---|---|---|---|
| `GriddingMachine.jl` | `wyujie` | `715268067645b0b68ba76ffb7c1be945de048705` | `Project.toml` 为 0.5.0，距 `v0.4.0` 35 个提交，尚无 `v0.5.0` tag |
| `GriddingMachineDatasets` | `wyujie` | `51cf0fee842c6c731b8c1836841682afec52df48` | `Project.toml` 为 0.1.0，无标准测试入口和 CI |

`GriddingMachineDatasets` 当前工作区在 `jianghao` 分支且存在未提交修改。本轮没有切换分支或修改这些文件，只通过 `git show wyujie:<path>` 审计目标分支。

### `Artifacts.yaml` 的可量化现状

在 `GriddingMachineDatasets/wyujie@51cf0fe`：

- 标签数：1 179；
- URL 数：1 251；
- FTP URL：1 179；
- HTTPS/Zenodo URL：72；
- 具有多个 URL 的标签：72，占 6.1%；
- 哈希/校验和字段：0。

论文中必须称其为“1 179 个数据标签”，不能未经归并就称为“1 179 个独立科学数据集”。当前也不能宣称数据库已经全面实现多镜像冗余，因为 93.9% 的标签仍只有一个 FTP 地址。

## 2. 总体结论

目前代码已经具备论文所需的主要架构雏形，但尚不满足可发表实验的最低条件。推荐判定为：

- **架构主线成立**：直接 NetCDF、动态 YAML、缓存下载、统一读取、`grid_dict`、`grid_weather` 和 YAML 数据生产流程都能在源码中找到清晰实现。
- **稳定性证据不足**：下载完整性、Windows 支持、发布闭环、配置校验和自动测试尚未完成。
- **生产端目标分支当前存在包加载阻断风险**：应作为第一优先级修复。
- **不能立即跑正式论文实验**：应先完成 P0 项并建立测试基线，否则产生的性能和正确性结果不可作为稳定版本证据。

## 3. P0：正式实验前必须解决

### P0-1 `GriddingMachineDatasets` 主模块加载会触发部署操作，并存在确定的未定义引用

证据：

- `src/GriddingMachineDatasets.jl:39-43` 直接 include 部署验证、上传和 URL 检查脚本。
- `src/deployment/2-upload.jl:77` 在文件顶层直接执行 `update_yaml_library!()`，因此 `using GriddingMachineDatasets` 会产生网络访问和写文件副作用。
- `src/deployment/2-upload.jl:25` 调用未定义变量 `zenodo_record_url`，函数参数实际名为 `doi_url`。
- `src/deployment/0-get_zenodo_nc_files.jl` 没有被主模块 include，因此 `get_zenodo_nc_urls` 在主模块中不可用。
- `save_library!` 没有在主模块导入。
- YAML 文件路径硬编码为 `/mnt/net/ormosia/group/jianghao/...`。

影响：生产端包很可能无法在新机器正常加载，更不能作为论文所称的通用工具。

修复要求：

1. 删除所有模块顶层的网络、上传和写文件调用。
2. 将部署功能改成显式调用，例如 `publish_dataset!(config; ...)`。
3. 完整声明依赖和导入；使用参数传递 YAML 路径、Zenodo 记录和 FTP 配置。
4. 部署功能与纯数据处理核心分层，保证离线 `using GriddingMachineDatasets` 成功。
5. 增加“干净临时目录加载包”的自动测试。

验收：在无 FTP 权限、无既有 `~/GriddingMachine`、无网络时，包可以完成加载；只有用户显式调用发布函数时才访问外部系统。

### P0-2 下载数据没有内容哈希，取消 artifact 后丢失了旧版完整性保障

证据：

- 1 179 个 YAML 标签均无 SHA/哈希字段。
- `GriddingMachine.jl/src/Collector/dataset-download.jl:37-46` 下载后直接移动缓存文件，没有计算或比较哈希。
- 2022 年旧版 `Artifacts.toml` 为每个制品保存 `git-tree-sha1` 和 `sha256`；新版取消 tarball 后没有替代机制。

影响：截断文件、代理错误页、服务器端静默替换或位翻转均可能进入正式数据目录，论文不能据此声称“可靠分发”。

修复要求：为每个标签增加 `SHA256` 和建议的 `SIZE_BYTES`；每个镜像必须指向相同内容。下载完成后先校验大小与 SHA-256，通过后再原子移动。

验收：截断、单字节修改、错误 HTML 和旧缓存均被拒绝，且不会覆盖已有正确文件。

### P0-3 下载循环可能在所有镜像失败后仍执行移动

证据：`dataset-download.jl:33-46` 没有 `download_succeeded` 状态。若所有具有有限 ping 的 URL 均抛出下载异常，循环结束后仍执行 `mv(cache_file, dataset_file)`。

影响：可能移动上次残留缓存，或用与真实原因无关的“缓存文件不存在”错误结束。

修复要求：每个镜像使用独立临时文件；只有下载和校验都成功才返回；全部失败后汇总每个 URL 的错误并抛出异常；使用 `try/finally` 清理残留。

验收：构造两个均失败的 URL，正式目录保持不变，错误中包含两个镜像及失败阶段。

### P0-4 镜像选择仍不支持 Windows，并会把禁止 ICMP 的可用服务器判死

证据：`dataset-download.jl:54` 固定执行 `ping -c 2 -W 2`；当前只解析 macOS 和 Linux 输出。Windows 参数和输出格式不同。代码将 `Inf` 直接等同为服务器不可达。

影响：与论文“跨平台、自适应镜像”主张直接冲突。2026-07-29 的修复增加了异常捕获，但没有实现 Windows 支持，也没有解决 ICMP 与 HTTP/FTP 可达性不等价的问题。

修复要求：

- HTTP(S)：超时受控的 `HEAD`，不支持时退回小范围 `GET`；
- FTP：连接并查询目标文件元数据；
- 将“可达性”和“性能排序”分开；
- ping 只能作为可选参考，不能作为下载前置条件；
- Windows、macOS、Linux 使用同一协议级逻辑。

验收：服务器禁止 ping 但允许 HTTPS 时仍能下载；三平台自动测试通过。

### P0-5 自动测试尚不能支撑论文中的正确性与跨平台结论

证据：

- `GriddingMachine.jl/test/runtests.jl:26-31` 当前唯一活动测试只是调用 `clean_database!("old")` 后执行 `@test true`。
- `clean_database!("old")` 中实际删除语句被注释，因此测试也没有验证清理结果。
- 大量旧测试整体被块注释，并调用已废弃的 `download_artifact!`。
- CI 矩阵虽包含 Linux/macOS/Windows，但 push 仅监听 `main/staging/trying`，不监听持续开发的 `wyujie`。
- `GriddingMachineDatasets/wyujie` 没有 `test/runtests.jl`，也没有 `.github/workflows`。

修复要求：建立不依赖真实服务器和用户主目录的分层测试：

1. 纯单元测试；
2. 本地临时 HTTP 服务器集成测试；
3. 合成 NetCDF 流水线测试；
4. 少量、可手动或定时执行的真实 Zenodo/FTP 冒烟测试；
5. 三操作系统 CI，并明确在 `wyujie` 或其 PR 上触发。

验收：核心测试不删除用户数据、不依赖公网、可重复执行，并覆盖下载失败、哈希、读取和流水线转换。

### P0-6 YAML 网页生成器缺少流水线必需字段

证据：

- `src/preparation/1-read.jl:80` 无条件读取 `dict["GAPFILL"]`。
- `src/build-yaml/YamlBuilder.jl:51-73` 生成 `DATA` 部分时没有写入 `GAPFILL`。
- 网页仍生成 `TARBALL` 字段，与“取消 tarball”主线相冲突。

影响：用网页生成的 YAML 不能直接运行当前通用 pipeline，因此不能在论文中写成已打通的数据贡献入口。

修复要求：以同一个 schema 同时驱动网页表单、YAML 校验、默认值和 pipeline；删除或明确弃用 `TARBALL`。

验收：网页生成的最小 YAML 可在临时目录端到端生成标准 NetCDF。

### P0-7 当前通用流水线不能处理任意维度顺序

证据：`src/preparation/1-read.jl` 只按数组位置反转第1/第2维和移动第1维经度，没有读取源变量的维度名并将 `(lat, lon)` 或 `(ind, lat, lon)` 重排成 `(lon, lat[, ind])`。

影响：手绘图提出的“生成不同 NetCDF 测试 pipeline”会暴露这一限制；如果论文声称处理异构维度顺序，当前实现不支持。

两种可接受选择：

1. 实现基于维度名的自动重排，并用合成 NetCDF 验证；或
2. 收窄论文表述，明确通用 pipeline 的输入前置条件已经是 `(lon, lat[, ind])`，其他格式由数据源专用预处理器完成。

建议选择第1种，因为它更符合“降低贡献门槛”的论文主线。

### P0-8 缺失值填充存在高风险索引写法，必须用测试确认并修正

证据：`src/preparation/0-gapfill.jl:43-45`、`62-64`、`109-111` 先取得二维 `slice` 和二维布尔掩膜，却使用 `data_in[site_to_refill, i]` 回写原数组，而不是对 `slice[site_to_refill]` 或显式第3维视图赋值。

影响：二维/三维数组上可能出现维度不匹配、错误位置赋值或运行异常。由于本轮无法运行 Julia，列为“静态高风险问题”，必须通过最小数组测试确认。

验收：2D 和 3D 的每种 gapfill 策略都有精确预期数组断言，且原数组只修改目标像元。

## 4. P1：P0 完成后、论文冻结前解决

### P1-1 动态 YAML 更新依赖 HTML 文本解析且不是原子更新

`database-download.jl` 先下载 Zenodo HTML，再搜索固定文本提取记录号，并直接覆盖本地 `Artifacts.yaml`。网页结构变化或中断可能损坏现有目录。

建议：使用 Zenodo REST API 或稳定概念 DOI；下载到临时文件，完成 YAML schema 校验后原子替换；保留上一版可回滚目录，并记录目录版本/记录号/哈希。

### P1-2 导入消费端包会创建目录并可能访问网络

`Collector.jl:7-18,34-35` 在模块加载时创建用户目录并调用 `load_database!`；首次使用且本地无 YAML 时会访问 Zenodo。

建议：惰性初始化。`using GriddingMachine` 不产生网络和持久化写入；第一次调用数据目录或下载 API 时再初始化。允许 `root`、目录 URL 和离线模式通过参数或环境变量配置。

### P1-3 已确定不作为论文核心的 Server/Requestor 仍增加核心包依赖和加载面

`src/GriddingMachine.jl:9-10` 默认 include `Requestor` 与 `Server`，`Project.toml` 因此保留 Genie、HTTP、JSON 等依赖。

建议：将它们移为可选扩展、独立包或至少默认不加载的实验模块。论文稳定 API 只列 Collector、Indexer 和模型接口。

### P1-4 发布实现仍未形成闭环

`deployment/2-upload.jl` 的 FTP 上传为 TODO；使用 `joinpath` 拼 URL，在 Windows 可能产生反斜杠；关闭 TLS 校验；更新现有条目时可能重复加入 FTP URL。

建议：建立“验证 → 上传镜像 → 远端校验 → 计算/确认哈希 → 原子更新目录 → 下游冒烟下载”的单一事务式命令。失败时不能发布半成品索引。

### P1-5 URL 验证器只检查前10个标签且下载完整 HTTP 文件

`library/1-verify-urls.jl:36-38` 在第10项后退出；HTTP 使用完整 `GET` 且关闭 TLS 校验。它不能验证全部 1 179 个标签，也不适合大文件。

建议：默认检查全库，支持抽样参数；采用 HEAD/Range；并发受控；保留状态、耗时和时间戳；TLS 校验默认开启。

### P1-6 YAML 没有正式 schema 和版本

当前客户端直接假定每个标签有 `PATH`、`URL`；生产配置直接读取 `FILE/FOLDER/DATA/GRIDDINGMACHINE` 及多项子字段。拼写或类型错误往往在长流程中途才暴露。

建议分别定义：

- 数据目录 schema：`schema_version`、标签、路径、URL、SHA-256、字节数、媒体类型；
- 生产配置 schema：字段类型、默认值、互斥关系、数组长度一致性、维度映射、许可与引用元数据。

### P1-7 输出元数据少于仓库自己声明的标准

`save_input!` 当前仅写 `about`、`unit` 和 `change_n`；而 `GriddingMachine.jl/README.md:101-121` 要求 authors、year、title、journal、doi 等引用信息。

建议：将来源 DOI、作者、标题、许可、原始文件、处理软件版本、配置哈希和生成时间写入 NetCDF 全局或变量属性。论文数据可追溯性需要这些字段。

### P1-8 已存在输出会被无条件跳过

`pipeline.jl:40-45` 只要目标文件存在就返回，不检查文件是否完整、是否由当前配置生成或是否通过验证。

建议：增加 `overwrite`/`resume` 策略；读取 provenance/config hash；只有完全匹配且通过验证的输出才跳过。

### P1-9 人工方向验证不可自动化且有并发冲突

`verify_data!` 固定使用 `python3`、固定缓存名 `cache/test.nc`、固定输出图名并调用 `readline()`。Windows、CI、批处理和并发任务均不稳健。

建议：把自动数值/结构验证作为必选，把人工方向图作为可选审核步骤；使用唯一临时目录；Python 可执行文件和输出路径配置化；审核结果写入独立 provenance，而不是只修改内存字典。

### P1-10 镜像覆盖率不足以支撑“全面冗余”结论

只有72/1 179个标签有双地址。正式实验前至少应为用于论文实验和核心模型接口的数据集配置 FTP+Zenodo，并明确论文只评价这一受控子集；若要宣称全库冗余，则需提高全库镜像覆盖率。

## 5. P2：建议清理，但不阻塞首轮功能实验

- 两个包都把 `Revise` 作为运行时依赖；它更适合开发环境。
- `GriddingMachine.jl` README 仍写 Julia 1.7、v0.2 模块和 `download_artifact!`，与 0.5.0 代码不一致。
- API 文档仍以 `read_LUT` 和 Requestor 为主，未突出 `read_dataset`、`grid_dict` 和 `grid_weather`。
- `GriddingMachineDatasets` README 过于简略，没有可执行的最小示例、输入约束和失败说明。
- `LandDatasetLabels` 只允许 `gm1/gm2`，但 `grid_dict` 内保留不可达的 `gm3` 分支，应统一版本设计。
- 生产端存在旧 tarball 部署代码、历史脚本和大量硬编码数据集脚本；应明确哪些属于正式 API、示例、迁移工具或归档。
- 错误消息、拼写和 docstring 需要统一；避免用 `@test true` 作为功能通过证据。

## 6. 推荐执行顺序

### 第1批：恢复可安装、可加载、可测试（先做）

1. 移除生产端顶层部署执行和硬编码路径。
2. 建立 `GriddingMachineDatasets/test/runtests.jl` 与三平台 CI。
3. 改造 `GriddingMachine.jl` 测试，使其使用临时目录和本地模拟服务器。
4. 让两个包在离线干净环境完成安装与加载。

完成标准：CI 绿；不会访问真实 FTP/Zenodo；不会写用户真实数据目录。

### 第2批：完成可靠下载闭环

1. 设计并迁移新 YAML schema。
2. 加入 SHA-256、字节数和目录版本。
3. 实现跨平台协议级镜像探测。
4. 实现临时文件、校验、原子移动、错误汇总和回退。
5. 用本地服务器做中断、损坏和镜像失败测试。

完成标准：故障注入测试全部通过，才可开始论文下载性能实验。

### 第3批：证明数据生产通用性

1. 增加维度名识别和重排，或正式收窄输入契约。
2. 修复并测试 gapfill。
3. 建立 YAML schema 与网页生成器的一致实现。
4. 补齐 provenance、引用、许可和配置哈希。
5. 建立合成 NetCDF 测试矩阵。

完成标准：所有合成案例均有确定输出或确定的预期错误。

### 第4批：验证模型接口并同步文档

1. 为 `read_dataset` 的全部重载增加测试。
2. 为 `grid_dict`、`grid_weather` 固定少量站点金标准结果。
3. 完成 Emerald 端到端案例。
4. 更新 README/API，明确 Server/Requestor 非核心。

完成标准：从新环境安装到模型输入生成有一条可复现命令链。

### 第5批：冻结论文版本并运行正式实验

1. 将 `wyujie` 的候选提交冻结为 release candidate。
2. 运行三平台、校内/校外、多镜像、压缩对比和故障注入实验。
3. 保存原始 CSV、日志、环境和绘图脚本。
4. 修复后只允许重新跑全部实验，不手工改论文数字。
5. 最终发布 tag 和 Zenodo DOI。

## 7. 建议的首个实现任务包

为了降低返工，第一批代码修改应严格限定为“可加载与测试基础设施”，暂不同时重写下载算法：

1. `GriddingMachineDatasets` 移除顶层 `update_yaml_library!()`。
2. 暂时不在主模块 include 未完成的发布脚本，或将其整理为无副作用的显式 API。
3. 参数化所有根目录和发布地址。
4. 新建最小 `test/runtests.jl`：包加载、YAML 构建、2D 数据读取/保存。
5. 新建 Linux/macOS/Windows CI。
6. 为后续测试建立合成 NetCDF fixture 生成器。

这批完成后，再进入“哈希 + 原子下载 + 协议级镜像选择”。

## 8. 对论文表述的即时约束

在以上问题解决并完成实验前，初稿只能使用以下措辞：

- “设计并正在实现多镜像分发机制”，不能写“已实现跨平台最优镜像选择”。
- “缓存后移动降低了未完成文件进入正式目录的风险”，不能写“保证文件完整性”。
- “YAML 驱动流程支持若干已配置转换”，不能写“可自动处理任意异构 NetCDF”。
- “提供 `grid_dict` 与 `grid_weather` 接口”，不能写“已证明显著提升模型初始化效率”。
- “目录包含1 179个标签”，不能直接写“包含1 179个独立数据集”。

完成 P0/P1 并获得定量结果后，才能把这些设计目标改写成论文结果和结论。

