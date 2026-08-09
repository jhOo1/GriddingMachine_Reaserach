# 模型接口真实格点实验数据

本目录用于实验3.4的标签清单和可复现脚本。由于NetCDF底层库不能可靠打开含中文的绝对路径，大文件统一存放在同一研究仓库内的纯ASCII目录`D:\Emerald\GriddingMachine_Reaserach\experiment_data\03_04\downloads`，不得写入用户默认GriddingMachine数据根目录，也不得提交到Git。

`inventory_required_datasets.jl`只读论文版`Artifacts.yaml`，不会发起网络请求。
