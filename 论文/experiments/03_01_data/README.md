# 合成NetCDF 31案例矩阵

`run_matrix_windows.jl`读取外部两个论文代码仓库。由于Windows NetCDF底层库不能可靠处理含中文的绝对路径，临时NetCDF统一生成在同一研究仓库的纯ASCII目录`experiment_data/03_01/work`。脚本不会访问网站或用户默认GriddingMachine数据目录。

V01/V02是人工方向审核，自动运行时记录为`MANUAL`。其余29项逐项执行并写入`matrix_windows_raw.csv`和`matrix_windows_summary.toml`。
