# GriddingMachine 更新论文代码基线

本文档记录《地球科学进展》投稿研究所参考的代码基线。本研究仓库不复制或收录两个代码仓库；需要核对实现时，从外部 clone 或对应 GitHub 仓库读取。论文文档、实验记录、结果和图表保存在本仓库。

## 作者与论文定位

- 第一作者：姜皓（Hao Jiang）
- 通讯作者：王玉杰（Yujie Wang）
- 单位：中国科学技术大学
- 论文主题：GriddingMachine全球网格数据生产、分发与模型调用框架的更新与验证
- 范围约束：Server/Requestor 不作为论文核心内容；如需提及，仅作为软件生态或未来扩展
- 核心闭环：YAML配置构建与标准化生产；独立目录、多镜像、缓存与SHA可靠分发；统一读取与Emerald初始化接口
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

## 当前论文候选基线

- GriddingMachine公开候选：`paper-release@11631d624f4847c5e34d2c4ff3cd762359a80c05`，被验证的核心代码为`53bb0be8b676f88d3d3dbe32f20aefdad883fcc2`。
- GriddingMachineDatasets公开候选：`paper-release@5eac56af311fe511237ac2b1d7ef68b018fd7626`。
- 研究仓库实验冻结提交：`main@8a23b5af8481cf575d45a0b7587ad7b6ea76edd3`。
- Emerald统一依赖候选：接口代码`d79324f5dbbfc560ccf1d796e10533ee3a7cd4f1`，公开仓库快照`b95d119204b2d1d6f82fd51ed5cffd4c5345af75`；三平台5/5接口烟雾CI记录为<https://github.com/jhOo1/Emerald-paper/actions/runs/31886671034>。
- 固定环境：Julia 1.12.6；NetcdfIO 0.3.0；PkgUtility 0.3.1。
- 公开三平台CI：GriddingMachine 63/63；GriddingMachineDatasets 38/38配置与35/35包集成；研究仓库29/29生产案例、65/65故障断言和40次小型确定性分发测量完成。
- 完整实验范围：Windows与macOS；Ubuntu CI只验证核心代码路径，不包含Emerald、真实网络和真实陆面文件。

上述提交仍是论文候选而不是正式release。研究仓库不导入外部代码，也不对Zenodo或其他网站执行删除或远程修改。

## 剩余门槛

1. 在中科大校园网实际只读访问FTP与Zenodo，记录ping、下载时间、字节数和SHA-256。
2. 作者确认基金、CRediT、利益冲突和P01匿名记录使用；Emerald公开策略已落实，仍需创建不可变release和永久归档。
3. 为代码、数据目录、实验结果、Manifest和绘图脚本创建不可变release及带DOI永久归档。
4. 迁移历史目录完整性与溯源字段属于后续维护，不作为本文软件流程结论的前置条件。
