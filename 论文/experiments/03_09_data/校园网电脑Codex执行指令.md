# 校园网电脑Codex执行指令：ERA5降水制品元数据收尾

请在校园网电脑上完成GriddingMachine论文ERA5降水制品的本地修订、完整性更新和03_09复核。严格限制操作范围：只处理`PPT_ERA5_1X_1H_2020_V1.nc`的`data`变量`units`属性，其余7个ERA5文件保持原样；降水科学数组保持原值，禁止乘以1000或执行其他数值变换；禁止删除、上传、覆盖或重命名机构FTP及Zenodo上的任何文件。涉及远端发布时先停止并向用户报告，等待明确授权。

## 一、同步仓库并确认工作区

1. 定位校园网电脑上的4个仓库。研究仓库通常为`GriddingMachine_Reaserach`，数据生产仓库为`GriddingMachineDatasets_paper`，模型环境为`Emerald_paper`，读取代码为`GriddingMachine_paper`。路径以当前电脑实际目录为准。
2. 对每个仓库先运行`git status --short`。保留所有已有修改；任何仓库存在来源不明的修改时，先报告并停止该仓库的拉取，禁止使用`git reset --hard`、`git checkout --`或删除文件。
3. 在干净工作区执行：

```powershell
git -C <GriddingMachine_Reaserach路径> pull --ff-only origin main
git -C <GriddingMachineDatasets_paper路径> pull --ff-only origin paper-release
git -C <GriddingMachine_paper路径> pull --ff-only origin paper-release
git -C <Emerald_paper路径> pull --ff-only paper main
```

4. 确认研究仓库包含提交`1d6c297`或其后继提交，数据生产仓库包含提交`c116b6b`或其后继提交。确认`GriddingMachineDatasets_paper/pipelines/ERA5/3-preprocess.jl`已把逐小时降水的`units`写为`m`。

## 二、确定目标文件并记录修订前状态

1. 目标文件应位于：

```text
<研究仓库>\experiment_data\03_09\public\wd1\PPT_ERA5_1X_1H_2020_V1.nc
```

2. 确认文件名、绝对路径和大小。修订前实验记录中的大小为`1102213097`字节、SHA-256为`3a4f28ca035fabff26a424979c2e12ebfaea0bde7062f7c9fa4c949c6a757195`。实际文件与该记录不一致时，先报告差异并停止修改。
3. 使用Julia和NetcdfIO只读检查`data`变量：维度名应为`lon, lat, ind`，形状应为`360×180×8784`，单位属性应为`mm`或已经修订后的`m`。
4. 检查研究仓库所在磁盘至少具有约1.5 GB可用空间。在研究仓库内部建立：

```text
<研究仓库>\experiment_data\03_09\metadata_backup
```

将目标文件复制到该目录作为修订前备份。备份完成后核对备份与目标文件SHA-256一致。保留该备份，等待用户在全部核验完成后决定清理。

## 三、只修订NetCDF单位属性

1. 在`论文/experiments/03_09_data`中用`apply_patch`创建一次性Julia脚本，例如`repair_ppt_units.jl`。使用`Emerald_paper`项目环境中的NetcdfIO打开目标NetCDF的追加模式。
2. 脚本必须具备以下行为：

- 修改前读取并打印`data.units`。
- 当单位为`mm`时，仅把`data`变量的`units`属性改为`m`。
- 当单位已经为`m`时按幂等操作处理，不重复改写科学数组。
- 遇到其他单位字符串立即报错并停止。
- 不修改`data`数组、`lon`、`lat`、`ind`、维度顺序、压缩设置及其他变量。
- 关闭并重新打开文件，确认`data.units == "m"`。
- 从备份和修订后文件分别读取US-NR1对应格点（40.0329°N、105.5464°W映射到40.5°N、105.5°W）的8784个PPT值，要求长度、有限值掩膜和所有Float32数值逐点完全一致。
- 核对`lon`、`lat`坐标和`360×180×8784`形状保持一致。
- 计算该格点全年累计值，预期约为`0.496409 m`，同时输出约`496.409 mm`的换算值。

3. 使用以下形式执行脚本，实际路径用绝对路径替换：

```powershell
Set-Location <研究仓库>\论文\experiments\03_09_data
julia --startup-file=no --project=<Emerald_paper路径> repair_ppt_units.jl <目标PPT文件绝对路径> <备份文件绝对路径>
```

## 四、更新本地实验目录

1. 重新计算修订后PPT文件的字节数和SHA-256：

```powershell
(Get-Item -LiteralPath <目标PPT文件>).Length
(Get-FileHash -LiteralPath <目标PPT文件> -Algorithm SHA256).Hash.ToLower()
```

2. 只更新研究仓库下列文件中`PPT_ERA5_1X_1H_2020_V1`条目的`SIZE`和`SHA256`，URL与PATH保持不变，其余7个条目保持原样：

```text
论文\experiments\03_09_data\Artifacts.era5.local.yaml
```

3. 正式目录`GriddingMachineDatasets_paper/Artifacts.yaml`指向机构FTP。当前任务不得直接把本地新摘要写入正式目录，因为FTP仍可能保存修订前文件。先把新文件大小和SHA-256记录在执行报告中；机构FTP上的PPT文件经授权更新并通过只读回下载确认后，再同步正式目录。

## 五、重新运行03_09实验

在03_09脚本目录执行：

```powershell
Set-Location <研究仓库>\论文\experiments\03_09_data
julia --startup-file=no --project=<Emerald_paper路径> run_real_era5_case.jl
```

脚本应输出`ERA5 real-data case PASS`，并更新：

```text
<研究仓库>\experiment_data\03_09\real_era5_result.toml
```

逐项确认：

- `case.field_count = 8`
- `case.time_steps = 8784`
- 8个字段有限值比例均为1.0
- 8个字段与底层NetCDF读取的最大绝对差均为0
- `fields.PPT.units = "m"`
- `fields.PPT.annual_total_m`约为0.496409
- `fields.PPT.annual_total_mm`约为496.409
- `time_axis.strictly_increasing = true`
- `time_axis.formula_max_abs_difference = 0`
- `model.initialization_finite = true`
- `model.first_step_finite = true`
- `environment.network_requests = 0`

同时确认PPT之外7个输入文件的SHA-256与原实验记录完全一致。

## 六、同步研究记录并提交

1. 更新`论文/experiments/03_09_ERA5真实气象链路实验结果.md`中的PPT文件大小、SHA-256、单位和年累计值，使其与新TOML一致。
2. 保留正文已经采用的`0.496409 m（496.409 mm）`表述。主论文无需增加新的实验章节。
3. 用`git diff`检查差异。研究仓库允许出现的修改仅包括：修订脚本、本地ERA5目录、结果TOML、ERA5结果说明及必要的执行记录。1.1 GB NetCDF和备份继续由`.gitignore`排除，禁止加入Git。
4. 提交并推送研究仓库的小型文本结果：

```powershell
git add <上述小型文本文件>
git commit -m "完成ERA5降水制品单位修订与复核"
git push origin main
```

## 七、向用户回报

最终报告以下信息：

- 实际仓库路径及拉取后的提交号
- PPT修订前后的单位、字节数和SHA-256
- 备份文件绝对路径
- 8784个格点值与备份逐点比较结果
- 年累计m和mm
- 03_09 PASS结果及TOML路径
- 其余7个ERA5文件摘要一致性
- 本地实验目录更新情况
- Git提交号和推送结果
- 正式FTP文件及正式目录尚未执行的远端发布动作

完成以上本地步骤后停止。任何FTP、Zenodo或网站文件的上传、覆盖、删除和正式目录切换均需用户另行明确授权。
