# 老师模板备份与接入记录

- 来源：Overleaf 项目 `2026_GriddingMachine`，https://www.overleaf.com/project/6ad187c7099334b21a9823a4。
- 备份日期：2026-10-16。
- `main_20261016.tex` 是接入全文前下载的主文件，保留原始署名占位与摘要，仅作恢复备份，不参与编译。
- 原始 `chinese.cls` 已原样保存到 `../overleaf/chinese.cls`，接入过程中未修改其字节内容。
- 当前完整稿位于 `../overleaf/main.tex`，包含中英文摘要、正文、3 幅图、3 个可编辑表格及 22 条参考文献。
- 已通过浏览器复制线上主文件并计算 SHA-256，与本地主文件逐字节一致：`40e779347db14ce4952ee6fb82beb08c20a4855cdb3ad2617dadf0a6c3a3a3d6`。
- 本地 pdfLaTeX 两轮源码检查通过，无文字越界、缺字或未解析引用；检查采用 draft mode，不另生成 PDF。
- 线上最终稿已成功编译为 32 页 PDF，日志显示 Errors 0、Warnings 0、Info 0。中途出现的 Overleaf `Server Error` 已恢复；已复核修正后的表1、表2、表3、参考文献标题及首页。
- Codex 内置单文件编译器不能加载项目的 `chinese.cls`，因此其预览报缺少类文件，不代表模板文件缺失。
- 当前为浏览器同步，尚未建立 Overleaf Git 自动同步。正文与 Markdown、Word 保持相同，本次只调整 LaTeX 接入与排版。
