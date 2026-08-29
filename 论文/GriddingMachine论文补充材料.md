# GriddingMachine论文补充材料

## S1 从目录更新到模型参数组织的Julia示例

以下示例对应正文2.6节，依次完成数据目录配置与更新、ELEV产品完整性下载、US-NR1附近格点读取和2020年第二套陆面参数集合（`gm2`）的参数组织。`gm2`由14类土壤、冠层、叶片、地形、陆地掩膜和植物功能型标准产品组成。

| 数据操作 | 公共接口 | 主要输出 |
|---|---|---|
| 配置数据环境 | `configure!` | 数据根目录与目录来源 |
| 更新产品目录 | `update_database!` | 通过schema校验的版本化目录 |
| 获取标准产品 | `download_dataset!` | 通过字节数与SHA-256校验的NetCDF文件 |
| 读取规则网格 | `read_dataset` | 整场、周期或站点数据 |
| 融合陆面参数 | `grid_dict` | 格点级模型参数字典 |
| 组织气象驱动 | `grid_weather` | 格点级气象时间序列 |

2026-08-29真实气象案例在US-NR1读取2020年8类ERA5标准产品。八文件共12 575 376 138字节，各字段包含8784个逐小时值；`grid_weather`与`NetcdfIO.read_nc`底层读取的最大绝对差均为0，FDOY与经度时区公式逐点一致。真实陆面参数和气象驱动共同通过Emerald初始化及60 s首步。单位审计确认PPT按米水层解释；2026-08-30修订制品以V1_R1物理文件发布到机构FTP，原V1保留，正式目录的V1逻辑标签指向R1。FTP回下载和全新Collector获取均通过SIZE/SHA-256与结构核验。逐文件SHA-256、值域和环境见`experiment_data/03_09/real_era5_result.toml`及`论文/experiments/03_09_ERA5真实气象链路实验结果.md`。

```julia
using GriddingMachine
using GriddingMachine.Collector
using GriddingMachine.Indexer

Collector.configure!(home = joinpath(homedir(), "GriddingMachine"))
Collector.update_database!()

file = Collector.download_dataset!(
    "ELEV_4X_1Y_V1"; require_integrity = true
)
elevation = Indexer.read_dataset(file, 40.0329, -105.5464)
parameters = Indexer.grid_dict("gm2", 2020, 40.0329, -105.5464)
```

目录和标准产品也可来自完成归档与完整性核验的研究材料。此时通过`catalog_file`和数据根目录指定相应副本，后续读取及模型参数组织保持相同接口。

## S2 Collector目录维护接口

Collector在单标签获取之外提供目录更新、全库同步、历史数据整理、目录树和数据集信息查询。`sync_database!`在更新目录后遍历有效标签并复用事务式下载逻辑；历史数据整理依据当前有效目录识别版本状态；路径、URL、完整性元数据和本地文件状态通过统一查询接口呈现。目录更新、同步和数据获取共享schema校验、临时文件落盘及`SIZE/SHA256`核验机制。

## S3 配置与贡献材料

完整YAML字段字典、数据贡献目录结构、产品登记步骤及状态恢复命令随论文对应的软件release归档。正文框1给出维度映射、坐标变换、数值处理与Gapfill所需的核心配置；版本化指南进一步覆盖二维和三维产品、`data/std`组合及批量产品配置。

本地交互式配置生成器提供表单化输入、YAML预览与保存功能。界面提交的结构化参数由`YamlBuilder`转换为配置对象，并使用与`process_dataset!`相同的schema完成字段解析。交互界面与程序化构建方式由此生成结构一致、可直接进入标准产品生产流水线的YAML配置。
