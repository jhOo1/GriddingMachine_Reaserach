# GriddingMachine 更新论文代码基线

本文档记录《地球科学进展》投稿研究所参考的代码基线。本研究仓库不复制或收录两个代码仓库；需要核对实现时，从外部 clone 或对应 GitHub 仓库读取。论文文档、实验记录、结果和图表保存在本仓库。

## 作者与论文定位

- 第一作者：姜皓（Hao Jiang）
- 通讯作者：王玉杰（Yujie Wang）
- 单位：中国科学技术大学
- 论文主题：GriddingMachine全球网格数据生产、分发与模型调用框架的更新与验证
- 范围约束：Server/Requestor 不作为论文核心内容；如需提及，仅作为软件生态或未来扩展
- 核心闭环：网页/YAML辅助贡献与标准化生产；独立目录、多镜像、cache与SHA可靠分发；统一读取与Emerald初始化接口
- 非核心内容：TOML与YAML格式本身的比较、完整长期模型模拟、Server/Requestor

## 冻结的初始快照

### GriddingMachine.jl

- 外部只读 clone：`D:\Emerald\GriddingMachine.jl`
- GitHub：`https://github.com/CliMA/GriddingMachine.jl`
- 来源分支：`wyujie`
- 提交：`715268067645b0b68ba76ffb7c1be945de048705`
- Git tree：`4cb9918272fea9d4da9736ba1b4c7039ab75b38c`
- 项目版本：`0.5.0`

### GriddingMachineDatasets

- 外部只读 clone：`D:\Emerald\GriddingMachineDatasets`
- GitHub：`https://github.com/jhOo1/GriddingMachineDatasets`
- 来源分支：`wyujie`
- 提交：`51cf0fee842c6c731b8c1836841682afec52df48`
- Git tree：`cd100e93477f724ba780b8b0969f5f57eb8e14c6`
- 项目版本：`0.1.0`

## 代码读取规则

本研究仓库遵循以下规则：

- 不在本仓库中导入、复制或镜像两个代码仓库；
- 优先从 GitHub 的指定分支或精确提交读取代码；
- 网络不可用时，可从仓库外已有的两个 clone 只读核对；
- 不把外部 clone 中的未提交修改视为论文基线；
- 论文实验开始后，应另行记录最终实验提交、Julia 版本、依赖环境和数据清单。

## 下一阶段

## 当前本地论文实现（尚未推送）

- GriddingMachine工作树：`D:\Emerald\GriddingMachine_paper`，分支`paper-release`，提交`fe46788`。
- GriddingMachineDatasets工作树：`D:\Emerald\GriddingMachineDatasets_paper`，分支`paper-release`，提交`049867d`。
- 验证环境：Julia 1.12.6；GriddingMachine 61/61，GriddingMachineDatasets 47/47，Emerald最小烟雾5/5。
- 本地提交不是正式release，未获得作者确认前不得push、建远程release或修改Zenodo记录。

## 下一阶段

1. 完成生产流水线端到端合成NetCDF矩阵。
2. 运行直接NetCDF效率、三平台故障注入和真实镜像实验。
3. 完成真实固定格点金标准与贡献者流程复现。
4. 迁移历史目录完整性字段，补齐溯源元数据。
5. 作者确认后冻结论文release，保存原始结果和绘图脚本，再完成投稿稿。
