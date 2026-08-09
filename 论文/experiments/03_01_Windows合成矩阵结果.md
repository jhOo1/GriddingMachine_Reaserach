# 实验3.1阶段结果：Windows合成NetCDF矩阵

更新日期：2026-08-09

## 1. 结果

在Windows 10、Julia 1.12.6、GriddingMachine `fe46788`和GriddingMachineDatasets `064ce1d`条件下，表3共31个编号案例连续独立运行3次，每次29个非交互案例全部通过；三次自动结构/数值通过率均为100%，网络请求数均为0。随后HJ一名操作者在GriddingMachineDatasets `3926ae3`上完成V01接受和V02拒绝，总体结果为PASS。

自动案例覆盖4项维度、4项坐标、4项数值、7项缺失值、5项预期拒绝、2项YAML契约和3项输出行为。二维与三维标准/换序、纬度和经度反转、经度半球平移、组合变换、Float32容差、线性缩放、有效范围、六类缺失值策略、未知方法拒绝、最小YAML、配置构建器输出、标签数量校验、主变量属性、同形`std`追加、已有输出安全跳过和目录标签冲突均满足预设断言。

## 2. 运行边界

所有NetCDF均生成在研究仓库的纯ASCII临时目录`experiment_data/03_01/work`。早期诊断轮次使用含中文的`论文/.../work`时，NetCDF底层库无法创建文件；改用ASCII路径后问题消失。因此本结果不能证明Windows下含非ASCII路径的兼容性。

首轮冻结曾报告`NetcdfIO.dimname_nc/size_nc/varname_nc`未声明导入。数据生产代码迁移至NetcdfIO 0.3的`read_dimnames/read_varnames/read_dims`后，又修复方向绘图和同一配置对象复用，本地完整测试配置38/38、包集成35/35通过，二维和三维输出均通过`verify_processed_data!`。GriddingMachine预编译缓存警告仍重复出现，正式环境仍需清理复现。

`process_dataset!(yaml_path)`重复运行会重新读取配置并安全跳过已有输出；直接复用同一可变`Dict`则会因首次运行追加内部`CHANGE_LOGS_TO_WRITE`而在第二次schema校验失败。论文结果只支持正常YAML入口的幂等性，不将可变Dict复用写成已支持行为。

## 3. 未完成项

V01/V02的实际单人操作记录、图件与夹具均已保存并计算哈希。本文准确报告一名操作者，不声称多参与者可用性研究，也不要求Linux和macOS复跑。构建器案例验证的是结构化输入、配置输出和流水线契约；当前没有独立客户端。ELEV真实标准产品核对已完成；P01未参与开发者在获得1次说明后完成贡献流程，自动验收为PASS。该单案例不外推为一般可用性研究。
