# Collector多镜像与故障注入实验

本目录保存实验3.3的Windows受控HTTP故障矩阵。脚本不复制GriddingMachine源码，而是从同级工作区的`GriddingMachine_paper/src/Collector/dataset-download.jl`直接载入当前论文分支实现；所有正式文件、cache和中间`.part`均位于本目录的`work`临时根内。

运行命令：`julia --startup-file=no fault_matrix_windows.jl`。

实验只访问`127.0.0.1`临时端口，不访问或修改真实镜像，不使用用户默认的`~/GriddingMachine`，也不执行任何网站写入或删除操作。
