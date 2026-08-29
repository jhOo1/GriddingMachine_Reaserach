# ERA5真实气象链路（已完成）

2020年8个ERA5标准NetCDF文件放到：

`<研究仓库>/experiment_data/03_09/public/wd1`

随后执行：

```powershell
julia --startup-file=no --project=<Emerald-paper仓库> run_real_era5_case.jl
```

脚本只读取这8个文件及实验3.4已归档的陆面文件，并把TOML结果写入研究文件夹。脚本不会访问网络，也不会改写输入NetCDF。

真实数据实验已通过：八文件共12 575 376 138字节；8个气象字段各8784步、有限值比例100%，与底层NetCDF最大绝对差均为0；FDOY公式差为0；Emerald初始化和60 s首步状态均有限。量纲审计确认PPT数值为ERA5逐小时米水层，数据生产代码已将单位属性统一为`m`。

正式发布前需在PPT标准产品中同步该属性，并更新本目录`Artifacts.era5.local.yaml`中的`SIZE`和`SHA256`。脚本会要求PPT单位为`m`，在结果TOML中记录`annual_total_m`和`annual_total_mm`，并继续执行8字段逐点比较、时间轴检查及Emerald首步计算。详见`../03_09_ERA5真实气象链路实验结果.md`。
