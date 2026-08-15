# 03_07 数据目录覆盖率审计

本实验只读取 `GriddingMachineDatasets/Artifacts.yaml`，不访问网络，也不下载数据。它区分两类容易混淆的结论：

- 软件是否实现 `SIZE/SHA256` 校验和多 URL 回退；
- 当前目录中有多少真实条目已经具备相应元数据。

在工作区根目录使用论文固定的 Julia 环境运行：

```powershell
$env:JULIA_DEPOT_PATH='D:\jh\code\paper\.julia-paper-depot'
& 'D:\jh\code\paper\.tools\julia-1.12.6\bin\julia.exe' --startup-file=no --project='D:\jh\code\paper\GriddingMachine.jl' 'D:\jh\code\paper\GriddingMachine_Reaserach\论文\experiments\03_07_data\audit_catalog_coverage.jl'
```

默认输出到 `experiment_data/03_07/catalog_audit/`。脚本也接受目录文件和输出目录两个可选位置参数。
