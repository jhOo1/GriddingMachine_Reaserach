# GriddingMachine 更新论文代码基线

本文档记录《地球科学进展》投稿研究所参考的代码基线。本研究仓库不复制或收录两个代码仓库；需要核对实现时，从外部 clone 或对应 GitHub 仓库读取。论文文档、实验记录、结果和图表保存在本仓库。

## 作者与论文定位

- 第一作者：姜皓（Hao Jiang）
- 通讯作者：王玉杰（Yujie Wang）
- 单位：中国科学技术大学
- 论文主题：GriddingMachine 上一版本的功能、数据工作流与可复现性更新
- 范围约束：Server/Requestor 不作为论文核心内容；如需提及，仅作为软件生态或未来扩展

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

1. 明确论文验证方案，并在本仓库保存实验设计、运行记录和结果。
2. 按代码审计结果依次处理下载可靠性、数据校验、跨平台探测、YAML 规范和数据维度问题。
3. 建立基准实验与回归测试，保存原始结果和绘图脚本。
4. 冻结论文实验提交，并将结果写入论文方法、结果与讨论部分。
