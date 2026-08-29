# ERA5真实气象链路（已完成）

2020年8个ERA5标准NetCDF文件放到：

`<研究仓库>/experiment_data/03_09/public/wd1`

随后执行：

```powershell
julia --startup-file=no --project=<Emerald-paper仓库> run_real_era5_case.jl
```

脚本只读取这8个文件及实验3.4已归档的陆面文件，并把TOML结果写入研究文件夹。脚本不会访问网络，也不会改写输入NetCDF。

真实数据实验已通过：八文件共12 575 376 138字节；8个气象字段各8784步、有限值比例100%，与底层NetCDF最大绝对差均为0；FDOY公式差为0；Emerald初始化和60 s首步状态均有限。量纲审计确认PPT数值为ERA5逐小时米水层，数据生产代码已将单位属性统一为`m`。

2026-08-29完成本地PPT单位修订，2026-08-30以新增物理文件`PPT_ERA5_1X_1H_2020_V1_R1.nc`发布至机构FTP；原V1物理文件保留。正式目录和本地目录继续使用V1逻辑标签，但URL均指向R1，现有`grid_weather`接口无需改变。FTP回下载、SIZE/SHA256、NetCDF结构、8784个格点值、全新Collector首次下载与第二次缓存复用以及03_09模型首步均已通过。ERA5大文件当前未同步Zenodo是上传耗时安排，不是软件能力限制，后续可补充镜像。详见`../03_09_ERA5真实气象链路实验结果.md`。
