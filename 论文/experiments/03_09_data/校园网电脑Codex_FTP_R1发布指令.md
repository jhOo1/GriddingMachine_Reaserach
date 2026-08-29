# 校园网电脑Codex执行指令：发布PPT V1_R1并完成正式目录核验

已获得远端新增文件授权。请在校园网电脑上完成ERA5 2020年降水修订制品的FTP发布、回下载核验、正式目录更新和论文记录同步。采用“保留逻辑标签、增加远端修订文件”的方案：

- 现有远端文件`PPT_ERA5_1X_1H_2020_V1.nc`完整保留；
- 新增远端文件`PPT_ERA5_1X_1H_2020_V1_R1.nc`；
- GriddingMachine逻辑标签继续使用`PPT_ERA5_1X_1H_2020_V1`，使`grid_weather("wd1", 2020, ...)`保持兼容；
- 正式目录中该逻辑标签的URL改为R1文件，并登记修订文件的`SIZE/SHA256`；
- 原V1文件不能作为R1条目的备用URL，因为二者SHA-256不同。

## 一、安全要求

1. 本任务授权新增R1文件、读取FTP目录和回下载验证。
2. 禁止删除、覆盖、改名或移动远端原V1文件。
3. 如果远端已经存在同名R1正式文件，停止上传并报告其大小和摘要，禁止覆盖。
4. 上传优先使用临时名称`PPT_ERA5_1X_1H_2020_V1_R1.nc.part`，完整上传后再原子改名为正式R1名称。若服务器或客户端不支持安全改名，停止并说明，等待用户选择方案。
5. FTP凭据只从校园网电脑已有的安全凭据、环境变量或交互式输入获取，禁止写入Git、脚本、日志、命令历史和对话输出。
6. 所有回下载大文件和临时验证文件放在`GriddingMachine_Reaserach/experiment_data/03_09`内部。
7. 禁止对Zenodo执行上传、覆盖或删除操作；本轮只处理已授权的机构FTP新增文件。
8. 保留所有已有工作区修改，禁止使用`git reset --hard`或`git checkout --`清除文件。

## 二、同步并检查仓库

先对以下仓库运行`git status --short`，确认工作区状态：

- `GriddingMachine_Reaserach`
- `GriddingMachineDatasets_paper`
- `GriddingMachine_paper`
- `Emerald_paper`

干净工作区执行：

```powershell
git -C <GriddingMachine_Reaserach路径> pull --ff-only origin main
git -C <GriddingMachineDatasets_paper路径> pull --ff-only origin paper-release
git -C <GriddingMachine_paper路径> pull --ff-only origin paper-release
git -C <Emerald_paper路径> pull --ff-only paper main
```

确认研究仓库包含`11bd1f7`或其后继提交，数据生产仓库包含`c116b6b`或其后继提交。

## 三、确认本地发布候选文件

本地修订文件通常为：

```text
<研究仓库>\experiment_data\03_09\public\wd1\PPT_ERA5_1X_1H_2020_V1.nc
```

发布前必须确认：

- 文件大小：`1102213097`字节；
- SHA-256：`1ae6b80512fac97e6b3e609c02ea126858256cf9153ead1335b5bf8d59fe7725`；
- `data.units = "m"`；
- 维度名为`lon, lat, ind`；
- 形状为`360×180×8784`；
- US-NR1年累计为`0.4964092731862654 m`，即`496.40927318626535 mm`。

任何一项不符时停止发布并报告。

在研究仓库内部创建发布候选副本，文件名增加R1后缀：

```text
<研究仓库>\experiment_data\03_09\ftp_release_candidate\PPT_ERA5_1X_1H_2020_V1_R1.nc
```

复制后再次核对候选副本与本地修订文件的字节数和SHA-256完全一致。不得把该大文件加入Git。

## 四、检查远端并新增R1文件

目标FTP目录：

```text
ftp://114.214.212.145/GriddingMachine/public/wd1/
```

执行只读目录检查，确认原文件存在：

```text
PPT_ERA5_1X_1H_2020_V1.nc
```

并确认以下正式名称当前不存在：

```text
PPT_ERA5_1X_1H_2020_V1_R1.nc
```

使用实验室已经批准的FTP客户端和安全凭据，把候选文件先上传为：

```text
PPT_ERA5_1X_1H_2020_V1_R1.nc.part
```

上传完成后核对远端临时文件大小为`1102213097`字节，再通过FTP服务器端改名将`.part`变为：

```text
PPT_ERA5_1X_1H_2020_V1_R1.nc
```

改名后再次列出目录，确认原V1和新V1_R1同时存在。不得删除原V1。

## 五、回下载并验证远端R1

将远端R1下载到新的验证目录：

```text
<研究仓库>\experiment_data\03_09\ftp_release_validation\PPT_ERA5_1X_1H_2020_V1_R1.nc
```

必须核对：

- 回下载文件大小为`1102213097`字节；
- SHA-256为`1ae6b80512fac97e6b3e609c02ea126858256cf9153ead1335b5bf8d59fe7725`；
- `data.units = "m"`；
- 维度和形状保持`lon×lat×ind`及`360×180×8784`；
- US-NR1的8784个Float32值与本地发布候选逐点完全一致；
- 年累计值保持`0.4964092731862654 m`。

回下载验证通过后，R1才视为正式可登记制品。

## 六、更新正式Artifacts.yaml

修改：

```text
<GriddingMachineDatasets_paper>\Artifacts.yaml
```

保留逻辑标签：

```yaml
PPT_ERA5_1X_1H_2020_V1:
```

将该条目的FTP URL由原V1物理文件改为R1物理文件，并加入完整性字段，最终形式应为：

```yaml
PPT_ERA5_1X_1H_2020_V1:
  PATH: "public/wd1"
  URL:
    - "ftp://114.214.212.145/GriddingMachine/public/wd1/PPT_ERA5_1X_1H_2020_V1_R1.nc"
  SIZE: 1102213097
  SHA256: "1ae6b80512fac97e6b3e609c02ea126858256cf9153ead1335b5bf8d59fe7725"
```

要求：

- 不新增`PPT_ERA5_1X_1H_2020_V1_R1`逻辑标签；
- 不修改`GriddingMachine_paper/src/Indexer/emerald-weather-drivers.jl`；
- 不把旧V1 URL继续列为镜像；
- 不修改其他年份或其他7个ERA5产品条目；
- 保持YAML缩进、排序和schema有效。

逻辑标签继续为V1，物理文件使用V1_R1，这使现有`WeatherDriverLabels("wd1", 2020)`仍能定位修订文件。

## 七、更新论文实验本地目录和脚本记录

修改研究仓库：

```text
论文\experiments\03_09_data\Artifacts.era5.local.yaml
```

保持键`PPT_ERA5_1X_1H_2020_V1`和现有`SIZE/SHA256`，只把URL改为R1物理文件URL。

检查：

```text
论文\experiments\03_09_data\run_real_era5_case.jl
```

实验逻辑标签继续使用V1。将PPT的归档`source_url`记录为R1地址，可采用明确的PPT源文件名映射，避免结果TOML继续记录旧V1物理URL。其余7个字段的URL保持原样。

本地实验数据文件仍可使用逻辑名称`PPT_ERA5_1X_1H_2020_V1.nc`，因为Collector正式落盘路径由逻辑标签决定；不要为了R1物理文件名修改`grid_weather`公共接口。

## 八、使用正式目录执行一次全新下载核验

在研究仓库内部建立空的验证home：

```text
<研究仓库>\experiment_data\03_09\collector_ftp_r1_validation
```

使用`GriddingMachine_paper`的Collector，并把目录文件指向更新后的`GriddingMachineDatasets_paper/Artifacts.yaml`。仅获取逻辑标签：

```text
PPT_ERA5_1X_1H_2020_V1
```

要求Collector从R1 URL下载，并按照逻辑标签落盘。确认：

- 实际访问URL以`V1_R1.nc`结尾；
- 下载文件通过SIZE和SHA-256；
- 正式落盘文件的`data.units = "m"`；
- 临时`.part`文件完成回收；
- 第二次调用复用已校验的正式文件。

验证目录及大文件保持在`experiment_data/03_09`下，并继续由`.gitignore`排除。

## 九、重新运行03_09案例

执行：

```powershell
Set-Location <研究仓库>\论文\experiments\03_09_data
julia --startup-file=no --project=<Emerald_paper路径> run_real_era5_case.jl
```

必须再次输出`ERA5 real-data case PASS`，并确认：

- `fields.PPT.units = "m"`；
- `fields.PPT.annual_total_m = 0.4964092731862654`附近；
- `fields.PPT.annual_total_mm = 496.40927318626535`附近；
- `files.PPT_ERA5_1X_1H_2020_V1.source_url`指向`V1_R1.nc`；
- 8字段各8784步，有限值比例均为1；
- 8字段与底层读取最大绝对差均为0；
- `FDOY`严格递增且公式差为0；
- Emerald初始化和60 s首步均为有限状态。

## 十、同步论文记录

更新：

```text
论文\experiments\03_09_ERA5真实气象链路实验结果.md
论文\experiments\03_09_data\README.md
论文\下一步实验执行顺序.md
论文\待作者补充信息.md
论文\第一版完成检查清单.md
```

将“机构FTP尚未更新”等状态改为正式结果表述，明确：

- 原V1文件保留；
- 修订制品以V1_R1物理文件发布；
- 逻辑标签保持V1以兼容现有模型接口；
- 回下载文件与本地候选的SIZE/SHA-256一致；
- 正式目录已指向R1。

主论文中的PPT累计值和模型结果保持不变，无需增加新实验章节。检查数据和代码可用性声明，按需要补充“修订制品由项目镜像提供”的正式表述。

## 十一、测试、提交与推送

先运行YAML解析、正式目录加载、Collector单文件下载和03_09案例。检查所有工作区差异和大文件忽略状态。

数据生产仓库只提交正式目录的小型文本修改：

```powershell
git -C <GriddingMachineDatasets_paper路径> add Artifacts.yaml
git -C <GriddingMachineDatasets_paper路径> commit -m "登记ERA5降水R1修订制品"
git -C <GriddingMachineDatasets_paper路径> push origin paper-release
```

研究仓库提交脚本、目录、TOML和说明文档，不提交任何NetCDF：

```powershell
git -C <研究仓库> add <本次小型文本与脚本文件>
git -C <研究仓库> commit -m "完成ERA5降水R1远端发布与回下载核验"
git -C <研究仓库> push origin main
```

`GriddingMachine_paper`和`Emerald_paper`无需代码修改。

## 十二、最终报告

向用户报告：

1. FTP上传采用的临时名称和最终R1名称；
2. 原V1文件仍存在的目录证据；
3. R1远端文件大小；
4. R1回下载SHA-256；
5. R1的`data.units`、维度、形状和年累计值；
6. 发布候选与回下载文件逐点比较结果；
7. 正式`Artifacts.yaml`条目内容；
8. Collector实际访问R1 URL并以V1逻辑标签落盘的结果；
9. 临时文件回收和第二次缓存复用结果；
10. 03_09 PASS结果；
11. 两个仓库的新提交号与推送结果；
12. 明确说明原V1未删除、未覆盖，Zenodo未修改。

出现同名R1、摘要不一致、上传中断、服务器无法安全改名、目录下载校验失败或工作区冲突时，立即停止后续发布动作，保留现场文件并向用户报告。
