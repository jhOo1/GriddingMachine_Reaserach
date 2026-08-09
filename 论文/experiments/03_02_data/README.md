# 直接NetCDF效率实验数据

本目录用于保存可删除的实验大文件，不把`.nc`、`.tar.gz`、下载副本或临时工作目录提交到Git。

公开来源：Zenodo记录`17732092`，DOI `10.5281/zenodo.17732092`。

| 文件 | 字节数 | Zenodo MD5 | 用途 |
|---|---:|---|---|
| `ELEV_4X_1Y_V1.nc` | 810299 | `749e160f809f56c32cd3fa007e1e005f` | 小型二维静态数据 |
| `LAI_MODIS_2X_8D_2020_V1.nc` | 13936426 | `163b76c13a923ec70e7bf8968f6bd1db` | 中型多周期数据 |
| `SOIL_SWCS_12X_1Y_V1.nc` | 46065259 | `f4ed22033bb1822cb196413593ca43d1` | 下载文件校验失败，禁止用于实验 |

原计划第三个候选为`TAIR_ERA5_1X_1H_2020_V1.nc`，但2026-08-09机构FTP连接失败，Zenodo公开检索未找到备份。下载得到的`SOIL_SWCS_12X_1Y_V1.nc`虽然字节数符合记录，但MD5为`97da6750431db101780f84aabb0c850e`，不符合记录值，因此本轮没有使用该文件。正式稿应在TAIR可获取后补跑，或由作者确认其他通过完整性校验的大文件样本。

本目录中的`benchmark_distribution_pilot.py`只执行分发格式预实验，不调用GriddingMachine API。运行前把Python依赖安装到本目录的`python_env`，并把安装缓存指定为本目录的`pip_cache`（或使用`--no-cache-dir`），然后在本目录执行脚本。脚本仅启动`127.0.0.1`回环HTTP服务，输出原始数据、统计摘要和运行元数据；大文件、外层归档、依赖、安装缓存和工作目录均由`.gitignore`排除。

PowerShell安装示例：`python -m pip install --cache-dir .\pip_cache --target .\python_env netCDF4`。

本目录不包含任何网站写操作。删除本地大文件时只删除本目录内被`.gitignore`排除的实验产物。
