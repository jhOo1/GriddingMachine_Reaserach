# GriddingMachine LaTeX 稿件

## 上传与编译

1. 在 Overleaf 中选择 **New Project → Upload Project**，上传 `GriddingMachine_Overleaf.zip`。
2. 将主文档设为 `main.tex`，编译器设为 **pdfLaTeX**。
3. 点击 Recompile。项目沿用老师线上项目的 `chinese.cls` 和 CJK 中文字体，正文保留双倍行距，表格和图注采用紧凑行距；无需上传系统字体，也不需要开启 shell escape。

项目包含完整中英文摘要、正文、3 张图、3 个可编辑表格和 22 条参考文献。参考文献使用 `thebibliography`，不需要额外运行 BibTeX。图件沿用当前论文版本。

对应线上项目：[2026_GriddingMachine](https://www.overleaf.com/project/6ad187c7099334b21a9823a4)。`chinese.cls` 与老师的原文件逐字节一致；接入全文前的主文件保存在研究仓库的 `论文/overleaf_template_backup/main_20261016.tex`，不参与编译。

中文署名为姜皓和王玉杰，两位作者均标注单位 1、2，王玉杰标注通讯作者，邮箱为 wyujie@ustc.edu.cn。不保留截图中的问号占位。

第一单位采用“中国科学技术大学风云卫星遥感联合实验室”；英文采用已有论文署名中的“Joint Laboratory of Fengyun Remote Sensing, University of Science and Technology of China”。第二单位为“崂山实验室 / Laoshan Laboratory”。

名称依据：

- 实验室官网：https://fengyun.ustc.edu.cn/main.htm
- 已有英文署名：https://egusphere.copernicus.org/preprints/2026/egusphere-2026-2012/egusphere-2026-2012.pdf

## 后续修改

当前内容由论文 Markdown 源稿生成。直接在 Overleaf 中编辑 `main.tex` 即可修改论文；本地重新导出前，应先把 Overleaf 中的文字修改合回 Markdown，避免覆盖。

本地重新生成项目和上传包：

```sh
python3 论文/tools/export_latex.py
```

## 可选的仓库关联

Overleaf 官方提供 Git 和 GitHub 同步，两者属于高级功能；具备相应权限后，可在 Overleaf 项目的 Integrations 中授权并操作。GitHub 同步由用户主动推送或拉取，并非持续自动同步。

当前使用浏览器维护上述已有项目。Git 入口可用，但本机尚未配置该服务的认证，因此不能把浏览器更新称为 Git 自动同步。若之后需要 Git 关联，请在本机为 `git.overleaf.com` 完成认证，再将其连接到专门的 LaTeX 工作目录，避免把整个研究仓库推入老师的项目。

官方操作说明：

- 上传项目：https://docs.overleaf.com/managing-projects-and-files/uploading-a-project
- Git / GitHub 同步：https://docs.overleaf.com/integrations-and-add-ons/git-integration-and-github-synchronization
