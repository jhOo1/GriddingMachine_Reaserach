# Collector多镜像与故障注入实验

本目录保存实验3.3的Windows受控HTTP故障矩阵和真实FTP—Zenodo访问脚本。故障脚本不复制GriddingMachine源码，可通过`GRIDDING_MACHINE_PAPER_REPO`指定当前论文分支；所有正式文件、cache和中间`.part`均位于本目录的`work`临时根内。真实网络脚本从活动Julia项目导入GriddingMachine，输出根目录根据脚本所在研究仓库动态推导。

包级运行时使用`julia --startup-file=no --project=<GriddingMachine.jl路径> fault_matrix_windows.jl`。如需复核最小源码harness，先设置`FAULT_MATRIX_BACKEND=source`再运行；正式论文结果以默认的`package`后端为准。

包级结果使用`fault_matrix_windows_package_*`文件名。目录中无后缀的早期结果来自源码harness，仅作补充审计。

实验只访问`127.0.0.1`临时端口，不访问或修改真实镜像，不使用用户默认的`~/GriddingMachine`，也不执行任何网站写入或删除操作。

真实网络运行结束后，可使用以下命令校验行数和成功数，并从原始CSV重新生成汇总表：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\summarize_real_ftp_zenodo.ps1 `
  -RunDirectory '<real_ftp_zenodo下的运行目录>' -RequireAll
```
