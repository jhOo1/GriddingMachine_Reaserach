# 03_07 发布目录准备状态盘点

本脚本只读取`GriddingMachineDatasets/Artifacts.yaml`，不访问网络，也不下载数据。它用于服务器复制与目录回填过程中的发布检查：

- 统计当前已回填`SIZE/SHA256`和多URL的条目；
- 在服务器文件复制完成后重复运行，核对发布准备状态。

统计数字不评价软件能力，也不作为论文核心实验结果。

在工作区根目录使用论文固定的 Julia 环境运行：

```powershell
$env:JULIA_DEPOT_PATH='D:\jh\code\paper\.julia-paper-depot'
& 'D:\jh\code\paper\.tools\julia-1.12.6\bin\julia.exe' --startup-file=no --project='D:\jh\code\paper\GriddingMachine.jl' 'D:\jh\code\paper\GriddingMachine_Reaserach\论文\experiments\03_07_data\audit_catalog_coverage.jl'
```

默认输出到 `experiment_data/03_07/catalog_audit/`。脚本也接受目录文件和输出目录两个可选位置参数。
