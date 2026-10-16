# 老师模板备份与接入记录

- 来源：Overleaf 项目 `2026_GriddingMachine`，https://www.overleaf.com/project/6ad187c7099334b21a9823a4。
- 备份日期：2026-10-16。
- `main_20261016.tex` 是接入全文前下载的主文件，保留原始署名占位与摘要，仅作恢复备份，不参与编译。
- 原始 `chinese.cls` 已原样保存到 `../overleaf/chinese.cls`，接入过程中未修改其字节内容。
- 当前完整稿位于 `../overleaf/main.tex`，包含中英文摘要、正文、3 幅图、3 个可编辑表格及 22 条参考文献。
- 已通过浏览器复制线上主文件并计算 SHA-256，与本地主文件逐字节一致：`2f251fbac8ccf9ef036a072f1c59adb9fe145dc2dad9a1d40c1ec16aaf905ef8`。
- 本地 pdfLaTeX 两轮源码检查通过，无文字越界、缺字或未解析引用；检查采用 draft mode，不另生成 PDF。
- 删除基金占位段并更新作者贡献后，线上稿已成功编译为 31 页 PDF，日志显示 Errors 0、Warnings 0、Info 0，已复核作者贡献段的实际排版。之前已复核表1、表2、表3、参考文献标题及首页。
- Codex 内置单文件编译器不能加载项目的 `chinese.cls`，因此其预览报缺少类文件，不代表模板文件缺失。
- 当前为浏览器同步，尚未建立 Overleaf Git 自动同步。Markdown、Word 和 LaTeX 中的基金占位段已同步删除，姜皓的“可视化”已删除，王玉杰增加“软件、数据整理”；其余论文内容保持一致。
