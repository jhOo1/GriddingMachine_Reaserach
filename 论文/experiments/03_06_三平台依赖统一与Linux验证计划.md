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
| GriddingMachine | 核心代码`0.5.0@53bb0be8b676f88d3d3dbe32f20aefdad883fcc2`；三平台CI提交`11631d6` |
| GriddingMachineDatasets | 候选论文分支`0.1.0@5eac56a`，基于`3926ae3`完成依赖修复 |
| Emerald | 候选论文分支`1.0.0@d79324f`，基于`wyujie@9828b2a`完成依赖修复 |
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

## 4. 三平台CI完成情况与证据边界

公开代码仓库CI固定Julia 1.12.6，并覆盖`ubuntu-latest`、`macos-latest`和`windows-latest`：

- GriddingMachine：三平台均为63/63，运行记录为<https://github.com/CliMA/GriddingMachine.jl/actions/runs/31876825314>；
- GriddingMachineDatasets：三平台均为38/38配置测试和35/35包集成测试，并归档平台Manifest，运行记录为<https://github.com/jhOo1/GriddingMachineDatasets/actions/runs/31876841675>；
- Emerald：接口代码提交`d79324f`已发布到`jhOo1/Emerald-paper`，公开快照`b95d119`在三平台均为5/5，并归档平台Manifest；运行记录为<https://github.com/jhOo1/Emerald-paper/actions/runs/31886671034>。该CI只覆盖固定合成输入下的最小接口烟雾。

研究仓库运行三平台受控CI，记录为<https://github.com/jhOo1/GriddingMachine_Reaserach/actions/runs/31877990092>：

- 31编号生产矩阵中的29个非交互案例均通过；
- 两个小型确定性NetCDF夹具、两种分发形式各10次，共40次分发测量，SHA-256检查均通过；
- M01--M13各5次，共65次故障状态断言均通过。

研究仓库三个平台工件名分别为`paper-controlled-windows`、`paper-controlled-macos`和`paper-controlled-linux`；Emerald仓库另保存`Emerald-manifest-*`。Ubuntu结果可以支持“表4所列核心代码路径和Emerald合成输入接口已通过Linux CI兼容性验证”，但不能外推为真实ELEV/LAI性能、真实FTP/Zenodo、真实`gm2`陆面案例、长期模型模拟或科学正确性均在Linux完成。真实网络结果按网络环境单独报告，不由GitHub runner代替校园网实验。GitHub Actions工件存在保留期限，投稿前必须迁移到永久归档。

## 5. 剩余操作

1. 已完成：GriddingMachine、GriddingMachineDatasets、Emerald和研究仓库公开候选提交及三平台CI；正文、表4、讨论和结论已按证据边界回填Linux结果。
2. 待完成：下载或重新生成最终冻结版本的日志、CSV、TOML和Manifest，并存入带DOI的永久归档；不能只依赖Actions临时工件。
3. 已完成：Emerald候选`d79324f`已公开，修复后的仓库快照`b95d119`已在Windows、macOS和Ubuntu干净runner上通过5/5接口烟雾；仍需创建不可变release和永久归档。
4. 已完成：2026-08-15在中科大校园网实际只读访问同内容FTP和Zenodo，共24/24次通过字节数与SHA-256核验，并保存ping、下载时间和冻结环境。
5. 正式release前创建不可变tag，并推动GriddingMachine 0.5.0注册，以消除Git source覆盖。
