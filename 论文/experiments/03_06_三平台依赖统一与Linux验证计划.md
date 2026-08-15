# 三平台依赖统一与Linux验证计划

执行日期：2026-08-15

## 1. 问题定位

论文代码的版本冲突来自移动Git分支和历史Manifest共同作用，而不是Windows或macOS代码路径本身：

- `GriddingMachine@53bb0be`要求`NetcdfIO = 0.3.0`和`PkgUtility = 0.3.1`；
- `GriddingMachineDatasets`的`[sources]`原来指向三个`wyujie`移动分支，历史Manifest因此解析到`GriddingMachine`旧提交和`NetcdfIO 0.2.12`；
- Emerald `wyujie@9828b2a`原来声明`NetcdfIO = 0.2.11`，与论文版GriddingMachine不可同时解析；
- macOS实验通过临时放宽compat运行，证明接口可以兼容，但这种临时修改不能作为正式release方案。

## 2. 统一版本组合

| 工程或依赖 | 冻结版本 |
|---|---|
| GriddingMachine | `0.5.0@53bb0be8b676f88d3d3dbe32f20aefdad883fcc2` |
| GriddingMachineDatasets | `0.1.0@3926ae384690dac6a8ce57af87edc5ff210a40c0`基础上的依赖修复 |
| Emerald | `1.0.0@9828b2acd594145dff2de5714a2793945ec734a5`基础上的独立`paper-release`工作树 |
| NetcdfIO | 注册表`0.3.0`，tree `0a876b43a8e35c8471bdcacc320e9697422722fd` |
| PkgUtility | 注册表`0.3.1`，tree `f77541ed81df69f9b4c08a94b4fe2f7ef86b964a` |
| Julia | `1.12.6` |

GriddingMachineDatasets和Emerald的`Project.toml`均将GriddingMachine固定到完整提交号，删除NetcdfIO/PkgUtility移动分支源，并将compat统一为NetcdfIO 0.3.0、PkgUtility 0.3.1。GriddingMachineDatasets中与新约束冲突的历史Manifest已从论文分支移除，由各平台按固定Project重新解析；CI保存每个平台生成的Manifest作为证据。正式发布时应优先把GriddingMachine 0.5.0注册到General，再删除论文工程中的Git source覆盖。

## 3. Windows统一环境验证

在不修改原始脏`Emerald.jl`工作区的前提下，新建`D:\Emerald\Emerald_paper`工作树。使用本地论文源码及已安装的注册表源码构建统一环境，实际解析得到GriddingMachine 0.5.0、GriddingMachineDatasets 0.1.0、Emerald 1.0.0、NetcdfIO 0.3.0和PkgUtility 0.3.1。

| 测试 | 结果 |
|---|---:|
| GriddingMachine完整回归 | 63/63通过 |
| GriddingMachineDatasets配置 | 38/38通过 |
| GriddingMachineDatasets包集成 | 35/35通过 |
| Emerald合成输入最小接入状态断言 | 5/5通过 |

结果证明三个工程在统一依赖组合下可以同时装载和运行。远程无Manifest实例化在当前Windows网络中停滞于GitHub提交获取，因此没有把该网络现象写成代码失败；远程可重复性由GitHub Actions三平台干净runner继续验证。

## 4. 三平台CI与Linux通过标准

代码仓库CI均固定Julia 1.12.6，并覆盖`ubuntu-latest`、`macos-latest`和`windows-latest`：

- GriddingMachine：63项完整回归；
- GriddingMachineDatasets：38项配置测试和35项包集成测试，并归档平台Manifest；
- Emerald：使用固定GriddingMachine提交运行5项最小接入状态断言，并归档平台Manifest。

研究仓库另运行三个平台相同的受控实验：

- 31编号生产矩阵中的29个非交互案例；
- 两个数据样本、两种分发形式各10次，共40次效率测量；
- M01--M13各5次，共65次故障状态断言。

只有Ubuntu对应任务实际完成并保存日志后，正文才能把“Linux支持”写成实证结论。在此之前，论文继续保留“Linux尚未验证”的边界。真实FTP/Zenodo结果按网络环境单独报告，不由GitHub runner代替校园网实验。

## 5. 后续操作

1. 分别提交三个代码工作树和研究仓库的CI改动；
2. 经作者允许后推送`paper-release`与研究仓库`main`，触发三平台CI；
3. 下载并核验三个系统的日志、CSV、TOML和Manifest工件；
4. 若Ubuntu全部通过，把Linux结果加入表4、结果章、讨论和结论；若失败，先修复后重跑，不写支持性结论；
5. 正式release前创建不可变tag，并推动GriddingMachine 0.5.0注册，以消除Git source覆盖。
