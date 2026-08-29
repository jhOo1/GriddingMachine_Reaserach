# ERA5真实气象链路

把2020年8个ERA5标准NetCDF文件放到：

`D:\Emerald\GriddingMachine_Reaserach\experiment_data\03_09\public\wd1`

随后执行：

```powershell
julia --startup-file=no --project=D:\Emerald\Emerald_paper run_real_era5_case.jl
```

脚本只读取这8个文件及实验3.4已归档的陆面文件，并把TOML结果写入研究文件夹。脚本不会访问网络，也不会改写输入NetCDF。
