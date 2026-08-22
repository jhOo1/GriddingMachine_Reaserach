# OISST v2.1真实异构产品案例

本目录保存论文中OISST v2.1单日海表温度案例的可执行脚本。下载和生成的数据统一写入研究仓库内的`experiment_data/03_08/`。

执行顺序：

```powershell
julia --startup-file=no --project=D:\Emerald\GriddingMachine_paper inspect_oisst.jl
julia --startup-file=no --project=D:\Emerald\GriddingMachine_paper prepare_oisst_case.jl
julia --startup-file=no --project=D:\Emerald\tools\griddingmachine-combined-env run_oisst_pipeline.jl
julia --startup-file=no --project=D:\Emerald\tools\griddingmachine-combined-env run_oisst_distribution.jl
```

- `inspect_oisst.jl`记录官方文件的维度、变量、属性、字节数和SHA-256；
- `prepare_oisst_case.jl`独立解码原始`sst`存储值，生成科学参考数组、二维源适配文件和生产YAML；
- `run_oisst_pipeline.jl`运行共享生产流水线3次，并核对坐标、有效值掩膜、全场数值和重复性。
- `run_oisst_distribution.jl`生成带`SIZE/SHA256`的独立目录条目，通过回环HTTP完成事务式下载，并使用`read_dataset`核对全场数组。

固定来源：NOAA/NCEI OISST v2.1 AVHRR-only final，日期2022-02-25，原始文件名`oisst-avhrr-v02r01.20220225.nc`。
