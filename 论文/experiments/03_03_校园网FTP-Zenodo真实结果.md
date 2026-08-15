# FTP—Zenodo校园网真实访问结果

执行时间：2026-08-15 22:36—22:38（Asia/Shanghai）

执行环境为作者确认的中科大校园网Windows实验电脑。正式运行前，`114.214.212.145:21`与`zenodo.org:443`均通过TCP连通性预检；使用Julia 1.12.6和`GriddingMachine@11631d624f4847c5e34d2c4ff3cd762359a80c05`执行冻结脚本。官方Julia压缩包、项目文件和本次解析Manifest的SHA-256均随环境记录保存。

正式实验对4个标签的机构FTP和Zenodo镜像分别重复下载3次，共24次只读下载。24/24次均达到登记字节数并通过SHA-256核验，没有远端写入或删除，临时下载文件在核验后清除。

| 标签 | 文件大小/B | FTP中位时间/s（范围） | Zenodo中位时间/s（范围） |
|---|---:|---:|---:|
| `SC_2X_1Y_V1` | 90,987 | 0.076（0.031～0.239） | 1.091（1.052～1.745） |
| `SLA_2X_1Y_V1` | 505,273 | 0.356（0.050～0.387） | 2.720（2.051～2.726） |
| `ELEV_4X_1Y_V1` | 810,299 | 0.071（0.062～0.074） | 3.386（3.376～6.449） |
| `CH_20X_1Y_V1` | 4,207,244 | 0.244（0.188～0.262） | 14.092（13.687～14.730） |

12次排序记录中，FTP主机的Windows `ping`均得到有限值（1.0～13.5 ms），Zenodo均为`Inf`，因此当前实现每次都把FTP排在首位。在本次校园网、这4个文件和该执行时段内，FTP的实测下载时间也均低于Zenodo。该结果说明本次候选顺序与实际表现一致，但不能外推为长期、其他网络、其他文件或全球范围的吞吐率最优选择。

原始证据位于`experiment_data/03_03/real_ftp_zenodo/campus-20260815/`：

- `real_ftp_zenodo_raw.csv`：24次下载、耗时、字节数、SHA-256和错误字段；
- `real_ftp_zenodo_summary.csv`：由PowerShell汇总脚本从原始CSV生成的分组中位数与范围；
- `real_ftp_zenodo_order.csv`：12次ping分数和首选URL；
- `real_ftp_zenodo_metadata.toml`：运行参数、时间、Julia版本和代码提交；
- `campus_environment_windows.toml`、`griddingmachine_Project.toml`和`griddingmachine_Manifest.toml`：平台、环境文件及哈希。
- `SHA256SUMS.txt`：上述环境和结果文件的整体校验清单。

本次结果与两轮校外观察回答不同环境下的可达性问题：校外FTP均超时，校园网FTP与Zenodo均完整可达。因此，校外FTP失败应解释为对应网络边界现象，而不是文件缺失或软件完整性校验失败。
