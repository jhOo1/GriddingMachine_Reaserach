# ERA5真实气象链路（已完成）

2020年8个ERA5标准NetCDF文件放到：

`<研究仓库>/experiment_data/03_09/public/wd1`

随后执行：

```powershell
julia --startup-file=no --project=<Emerald-paper仓库> run_real_era5_case.jl
```

脚本只读取这8个文件及实验3.4已归档的陆面文件，并把TOML结果写入研究文件夹。脚本不会访问网络，也不会改写输入NetCDF。

2026-08-29实测PASS：八文件共12 575 376 138字节；8个气象字段各8784步、有限值比例100%，与底层NetCDF最大绝对差均为0；FDOY公式差为0；Emerald初始化和60 s首步状态均有限。单位审计同时发现，PPT文件属性写为`mm`，但历史数值尺度和Emerald换算按米水层处理；因此首步PASS只说明链路可执行，正式发布前仍须统一PPT单位契约。详见`../03_09_ERA5真实气象链路实验结果.md`。
