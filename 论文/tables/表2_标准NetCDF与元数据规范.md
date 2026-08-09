# 表2 GriddingMachine 标准 NetCDF 数据与元数据规范

| 类别 | 字段或对象 | 论文实验版本要求 | 自动验收方法 |
|---|---|---|---|
| 文件 | 格式与扩展名 | 一个标签对应一个可直接读取的 `.nc` 文件，不再进行外层 `tar.gz` 打包 | NetCDF 文件头和扩展名检查；独立打开测试 |
| 空间覆盖 | 网格与坐标参考 | 规则经纬度网格；默认覆盖全球，采用 WGS84；区域数据必须明确覆盖范围 | 检查坐标属性、范围、间距和单调性 |
| 维度 | 维度名称与顺序 | 二维为 `(lon, lat)`；三维为 `(lon, lat, ind)`；源数据顺序由维度名映射后统一 | 对合成的不同维度排列检查输出形状和逐点值 |
| 经度 | `lon` | 自西向东单调递增，目标范围为 `[-180, 180)`；间距均匀 | 检查端点、差分、长度及循环平移后的数值位置 |
| 纬度 | `lat` | 自南向北单调递增，目标范围覆盖 `[-90, 90]` 对应的网格中心或边界 | 检查端点、差分、长度及翻转后的数值位置 |
| 周期 | `ind` | 三维数据的第三维，表示时间或其他有序周期；含义、长度和时间分辨率必须记录 | 检查维度长度、索引单调性和时间元数据 |
| 主变量 | `data` | 必需；保存经单位恢复、缩放和有效范围处理后的物理量 | 检查变量存在、类型、形状、单位和金标准数组 |
| 不确定性 | `std` | 可选；存在时必须与 `data` 具有相同维度和形状，并说明不确定性的定义 | 检查变量形状、非负约束及说明属性 |
| 缺失值 | `NaN` / `_FillValue` | 计算接口统一返回 `NaN`；文件层缺失值表示及转换规则必须显式记录 | 注入填充值、NaN、陆地/海洋空值并检查输出掩膜 |
| 数值处理 | 缩放、偏移和有效范围 | 输出保存实际物理值，不依赖未记录的缩放；越界值处理规则和 gap-filling 方法可追溯 | 对已知输入计算预期缩放、过滤和填补结果 |
| 变量元数据 | `units`、`long_name`、`standard_name` | `units` 必需；能够映射 CF 标准名时写入 `standard_name`；同时给出可读名称和说明 | schema 校验；单位可解析性与 CF 标准名检查 |
| 全局溯源 | `title`、`source`、`references`、`license`、`history` | 记录来源数据、DOI/引用、许可、处理步骤、生成时间和责任主体 | 必填字段检查；DOI/URL 格式检查；处理日志非空 |
| 处理复现 | 软件与配置版本 | 写入 GriddingMachineDatasets commit/release、YAML schema 版本和配置 SHA-256 | 与实验清单及配置文件重新计算结果比对 |
| 标签 | `TAG_(PREFIX_)NX_MT_(YYYY_)VV(_REVISION)` | 标签唯一且能表达数据类别、空间/时间分辨率、年份、版本及可选修订号 | 正则表达式、目录唯一性和文件名一致性检查 |
| 分发完整性 | `SIZE_BYTES`、`SHA256` | 记录在数据目录中；同一标签的所有镜像必须具有相同字节数和 SHA-256 | 下载后重新计算并比较，失败文件不得进入正式目录 |

注：本表定义论文版本的目标验收规范。冻结版本已验证标准文件结构、显式维度映射、主要坐标和数值处理以及目录`SIZE/SHA256`链；来源、许可、配置哈希和代码版本尚未在全部历史产品的最终NetCDF中完整迁移，因此不能据此声称所有历史数据均可从原始来源重建。

**Table 2 Standardized NetCDF data and metadata requirements of GriddingMachine.** The table defines the acceptance criteria for the experimental release. Compliance must be demonstrated using automated tests against the frozen release rather than inferred from the design.
