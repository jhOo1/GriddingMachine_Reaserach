# GriddingMachine论文补充材料

## S1 从目录更新到模型参数组织的Julia示例

以下示例对应正文2.6节，依次完成数据目录配置与更新、ELEV产品完整性下载、US-NR1附近格点读取和2020年`gm2`陆面参数组织。

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
