# 03_03 macOS 校外 FTP—Zenodo 真实观察记录

执行日期：2026-08-15　环境：Apple M4（arm64）、macOS 26.3.2、Julia 1.12.6、非中科大校园网

## 结论摘要

- 默认 DNS 下 Julia 脚本对 24 次下载全部失败：机构 FTP 12 次连接超时（校外本就无法访问，符合预期），Zenodo 12 次在连接阶段即失败——根因是**本网络对 `zenodo.org` 的 DNS 污染**（本地解析返回 `0.0.0.0`）。
- 用公共 DNS 交叉核实并经显式 IP 解析后，Zenodo 12/12 下载全部达到登记字节数并通过 SHA-256 核验。
- 机构 FTP 在校外不可达由网络边界造成，与 Windows 校外观察一致；校园网内的 FTP—Zenodo 正式比较仍需在 Windows 校园网侧完成，本记录不替代。

## 1. 默认 DNS 运行（原始观察，保留）

脚本 `论文/experiments/03_03_data/run_real_ftp_zenodo_macos.jl`（Windows 版的 macOS 变体，仅把平台断言由 `Sys.iswindows()` 改为 `Sys.isapple()`，协议、候选标签、超时、重复次数与 Windows 一致），`MIRROR_RUN_LABEL=macos_offcampus`。

结果（`real_ftp_zenodo_raw.csv`，SHA-256 `c4d45d07365d5bffd46ccc68c2c887ec459a18238338e38463510283a7df5afd`）：

- FTP：12/12 连接超时（约 30 s），校外不可达，符合预期。
- Zenodo：12/12 失败，错误为 `Failed to connect to zenodo.org port 443 after 0~128 ms: Could not connect to server`。

### DNS 污染诊断

- `nslookup zenodo.org`（本地默认解析）→ `0.0.0.0`（污染）。
- `nslookup zenodo.org 8.8.8.8` 与 `1.1.1.1` → 均为 `188.185.48.75`（真实地址）。
- 对照组：同一网络下 `https://github.com` 返回 200，连接 0.34 s，说明并非整体断网，而是针对 `zenodo.org` 的解析污染。
- `curl --resolve zenodo.org:443:188.185.48.75` 请求同一 Zenodo 文件 → HTTP 200，文件完整。

ICMP 参考：本机 `ping -c 3` 对 `114.214.212.145` 与 `zenodo.org` 均 100% 丢包，再次印证 ICMP 无响应不等于 HTTPS 不可下载。

## 2. 显式 IP 解析的 Zenodo 核验运行（可比数据）

脚本 `run_zenodo_verified.py`：对 4 个标签各 3 次、用 `curl --resolve zenodo.org:443:188.185.48.75` 单次尝试下载，记录耗时、字节数、SHA-256；截断传输如实记为失败，不静默重试。

结果（`zenodo_verified_raw.csv`，SHA-256 `3958923b45aa6175e5127c2c5114943a9001362f66f68c6da02063d55b467f85`）：**12/12 通过 SIZE+SHA256 核验**。

| 标签 | 大小 (B) | 中位耗时 (s) | 范围 (s) |
|---|---|---|---|
| SC_2X_1Y_V1 | 90,987 | 4.26 | 1.59–4.98 |
| SLA_2X_1Y_V1 | 505,273 | 3.77 | 2.37–5.69 |
| ELEV_4X_1Y_V1 | 810,299 | 9.90 | 5.62–13.12 |
| CH_20X_1Y_V1 | 4,207,244 | 70.80 | 69.78–89.10 |

### 大文件传输不稳定的附带观察

在正式记录前的手动探测中，`CH_20X_1Y_V1`（4.2 MB）曾出现 `curl` exit 18（部分传输）截断，例如 4,074,536 / 3,943,664 / 3,502,556 B 均小于登记的 4,207,244 B；而一旦传输完成，SHA-256 与登记值精确一致。这说明该网络路径对较大传输偶发中断，而非内容损坏——正是多镜像回退与下载后哈希校验设计要拦截的情形。正式记录的 3 次 CH 重复均完整完成。

## 3. 边界与对论文的使用

- 本记录是**校外**观察，且 Zenodo 数据依赖显式 IP 解析绕过 DNS 污染，方法与 Windows 校外运行（默认 DNS 即可下载）不同，二者不可直接合并为同一组"校外 Zenodo 吞吐"数字；论文引用时须分别注明网络环境与解析方式。
- 机构 FTP 的校园网内表现仍未测，保留为 Windows 校园网侧的正式实验。
- 可写入讨论的新证据点：真实网络中存在 DNS 污染与大文件传输中断两类故障，GriddingMachine 的"多镜像 + cache 隔离 + 下载后 SIZE/SHA-256 校验"在这两类故障下都能阻止损坏或不完整文件进入正式目录（对应 03_03 故障注入矩阵的 M 场景）。
