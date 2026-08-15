# FTP—Zenodo校园网真实访问流程

本实验必须在能够访问`114.214.212.145`机构FTP的中科大校园网Windows机器上执行。它会对4个已登记`SIZE/SHA256`的小型标签分别访问真实FTP和真实Zenodo，每个文件—镜像组合重复3次。实验只读远端文件，不执行上传、覆盖或删除。

## 执行前确认

1. 电脑已连接中科大校园网或能够访问机构FTP的合规校内网络。
2. `GriddingMachine.jl`位于论文工作区且固定为提交`11631d624f4847c5e34d2c4ff3cd762359a80c05`，工作区干净。
3. 研究目录至少有100 MB临时空间。
4. 不同时运行其他大文件下载任务。

## 执行命令

```powershell
$workspace = 'D:\jh\code\paper' # 若仓库位于其他位置，只修改这一行
$julia = Join-Path $workspace '.tools\julia-1.12.6\bin\julia.exe'
$env:JULIA_DEPOT_PATH = Join-Path $workspace '.julia-paper-depot'
$env:MIRROR_RUN_LABEL = 'campus-YYYYMMDD'
$env:MIRROR_REQUIRE_ALL = 'true'
$env:MIRROR_FTP_TIMEOUT_SECONDS = '120'
$env:MIRROR_ZENODO_TIMEOUT_SECONDS = '120'
Set-Location (Join-Path $workspace 'GriddingMachine_Reaserach\论文\experiments\03_03_data')
& $julia --startup-file=no --project=(Join-Path $workspace 'GriddingMachine.jl') run_real_ftp_zenodo_windows.jl
```

脚本依次对`SC_2X_1Y_V1`、`SLA_2X_1Y_V1`、`ELEV_4X_1Y_V1`和`CH_20X_1Y_V1`执行：

1. 对FTP主机和Zenodo主机各运行Windows ping并记录平均延迟。
2. 按软件当前逻辑记录首选URL。
3. 从真实FTP下载完整文件，核对字节数和SHA-256后删除本地临时文件。
4. 从真实Zenodo下载同一文件，完成相同核对后删除临时文件。
5. 重复3次。

结果保存在工作区内的`GriddingMachine_Reaserach\experiment_data\03_03\real_ftp_zenodo\<RUN_LABEL>`。正式通过要求是24次真实下载全部成功且哈希一致。若FTP失败，先确认校园网条件，不得把校外失败写成软件失败；若Zenodo ping为`Inf`但下载成功，应如实记录为“ICMP无响应但HTTPS可下载”，不能删除该案例。

若当前不在校园网，可执行一次独立的校外可达性观察。该观察真实连接FTP并保留超时，也真实下载Zenodo，但写入独立子目录且不作为校园网正式结果：

```powershell
$env:MIRROR_RUN_LABEL='offcampus-20260809'
$env:MIRROR_FTP_TIMEOUT_SECONDS='20'
$env:MIRROR_ZENODO_TIMEOUT_SECONDS='120'
$env:MIRROR_REQUIRE_ALL='false'
& $julia --startup-file=no --project=(Join-Path $workspace 'GriddingMachine.jl') run_real_ftp_zenodo_windows.jl
```

校外观察结束后可移除这3个仅对当前PowerShell会话生效的环境变量。校园网正式实验必须使用新的运行标签并保持`MIRROR_REQUIRE_ALL=true`，不能覆盖或改写校外原始CSV。

该实验的ping延迟和下载时间只代表执行时段及校园网环境。论文可以比较ping排序是否与本次实际下载表现一致，但不能据此声称长期或全球最优镜像。

## 2026-08-15正式运行状态

已在作者确认的中科大校园网Windows实验电脑完成正式运行，运行标签为`campus-20260815`，24/24次FTP与Zenodo下载均通过`SIZE/SHA256`。结果与环境证据见`experiment_data/03_03/real_ftp_zenodo/campus-20260815/`，汇总见`03_03_校园网FTP-Zenodo真实结果.md`。
