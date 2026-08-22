# 03_08 真实异构OISST端到端结果

## 数据来源

- 产品：NOAA/NCEI 0.25° Daily OISST V2.1 AVHRR-only Final；
- 日期：2022-02-25；
- 原始文件：`oisst-avhrr-v02r01.20220225.nc`；
- 原始文件大小：1 523 789字节；
- 原始SHA-256：`b5e91dacb3ed85819b47b516dd4edb7dab7fb6ae7bf67062cef03cd0333c9b73`；
- 官方入口：`https://www.ncei.noaa.gov/thredds/fileServer/OisstBase/NetCDF/V2.1/AVHRR/202202/oisst-avhrr-v02r01.20220225.nc`。

## 原始结构与处理契约

原始`sst`变量的Julia维度顺序为`lon×lat×zlev×time`，形状为1440×720×1×1。经度由0.125°递增至359.875°，纬度由−89.875°递增至89.875°；存储类型为Int16，`scale_factor=0.01`，`add_offset=0`，`_FillValue=-999`，单位为Celsius。

版本化源适配器提取唯一的`zlev`和`time`层，并保留解码后的物理值、原始经度顺序、来源URL和原始文件SHA-256。共享YAML契约声明`lon×lat`维度，执行经度半球转换、−3～45 ℃有效范围控制及`KEEP_AS_IS`缺失值策略，输出标签为`SST_OISST_4X_1D_20220225_V1`。

## 独立参考与生产结果

独立参考脚本直接读取未缩放Int16存储值，依据原始属性构造物理值和缺失值掩膜，并独立完成经度索引转换。生产输出与独立参考结果如下：

| 指标 | 结果 |
|---|---:|
| 输出形状 | 1440×720 |
| 经度范围 | −179.875°～179.875° |
| 纬度范围 | −89.875°～89.875° |
| 有效格点 | 691 150 |
| 缺失格点 | 345 650 |
| 最小海表温度 | −1.80 ℃ |
| 最大海表温度 | 32.39 ℃ |
| 全场有效值平均温度 | 14.013 ℃ |
| 最大绝对差 | 0 |
| 有效值掩膜 | 逐点一致 |
| 经度与纬度 | 逐点一致 |

标准产品连续生成3次，科学数组、坐标和文件SHA-256均一致。最终产品大小为997 006字节，SHA-256为`9acfa0d196d8ccbd9ed863d8a6e241a018e0c9278ae8b3d37304bbf656d44fe4`。

## 目录、下载与统一读取

`build_catalog_entry`从标准产品生成`PATH/URL/SIZE/SHA256`目录字段。回环HTTP事务式下载得到997 006字节文件，SHA-256与目录登记值一致，下载结束后缓存目录中`.part`文件数量为0。`read_dataset`读取的1440×720数组与独立参考有效值掩膜逐点一致，最大绝对差为0。

## 结果文件

- 来源结构：`experiment_data/03_08/source_inventory.toml`；
- 独立参考摘要：`experiment_data/03_08/reference_summary.toml`；
- 生产YAML：`experiment_data/03_08/oisst_20220225.yaml`；
- 生产核对：`experiment_data/03_08/pipeline_result.toml`；
- 实验目录：`experiment_data/03_08/oisst_catalog.yaml`；
- 分发与读取结果：`experiment_data/03_08/distribution_result.toml`；
- 可执行脚本：`论文/experiments/03_08_data/`。

## 结论

OISST真实案例完整贯通了四维打包源数据、版本化源适配、共享YAML标准化、Gapfill策略、直接NetCDF制品、完整性目录、事务式HTTP下载和统一读取，形成新版GriddingMachine面向真实全球网格产品的数据生命周期实例。
