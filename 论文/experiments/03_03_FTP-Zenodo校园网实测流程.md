# FTP—Zenodo校园网真实访问流程

本实验必须在能够访问`114.214.212.145`机构FTP的中科大校园网Windows机器上执行。它会对4个已登记`SIZE/SHA256`的小型标签分别访问真实FTP和真实Zenodo，每个文件—镜像组合重复3次。实验只读远端文件，不执行上传、覆盖或删除。

## 执行前确认

1. 电脑已连接中科大校园网或能够访问机构FTP的合规校内网络。
2. `D:\Emerald\GriddingMachine_paper`当前为论文提交，工作区干净。
3. 研究目录至少有100 MB临时空间。
4. 不同时运行其他大文件下载任务。

## 执行命令

```powershell
Set-Location 'D:\Emerald\GriddingMachine_Reaserach\论文\experiments\03_03_data'
julia --startup-file=no --project=D:\Emerald\GriddingMachine_paper run_real_ftp_zenodo_windows.jl
```

脚本依次对`SC_2X_1Y_V1`、`SLA_2X_1Y_V1`、`ELEV_4X_1Y_V1`和`CH_20X_1Y_V1`执行：

1. 对FTP主机和Zenodo主机各运行Windows ping并记录平均延迟。
2. 按软件当前逻辑记录首选URL。
3. 从真实FTP下载完整文件，核对字节数和SHA-256后删除本地临时文件。
4. 从真实Zenodo下载同一文件，完成相同核对后删除临时文件。
5. 重复3次。

结果保存在`D:\Emerald\GriddingMachine_Reaserach\experiment_data\03_03\real_ftp_zenodo`。正式通过要求是24次真实下载全部成功且哈希一致。若FTP失败，先确认校园网条件，不得把校外失败写成软件失败；若Zenodo ping为`Inf`但下载成功，应如实记录为“ICMP无响应但HTTPS可下载”，不能删除该案例。

该实验的ping延迟和下载时间只代表执行时段及校园网环境。论文可以比较ping排序是否与本次实际下载表现一致，但不能据此声称长期或全球最优镜像。
