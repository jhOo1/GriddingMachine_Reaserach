# GriddingMachine LaTeX 稿件

## 上传与编译

1. 在 Overleaf 中选择 **New Project → Upload Project**，上传 `GriddingMachine_Overleaf.zip`。
2. 将主文档设为 `main.tex`，编译器设为 **XeLaTeX**。
3. 点击 Recompile。项目采用 TeX Live 自带的 Fandol 中文字体，无需上传系统字体，也不需要开启 shell escape。

项目包含完整中英文摘要、正文、3 张图、3 个可编辑表格和 22 条参考文献。参考文献使用 `thebibliography`，不需要额外运行 BibTeX。图件沿用当前论文版本。

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

目前只生成可上传项目，尚未建立 Overleaf 账号关联或远端项目。若需要长期双向维护，可在创建 Overleaf 项目后，使用其 Git 地址连接专门的 LaTeX 仓库，或通过 Overleaf 从 GitHub 新建项目。不要直接导入包含大量实验数据的整个研究仓库。

官方操作说明：

- 上传项目：https://docs.overleaf.com/managing-projects-and-files/uploading-a-project
- Git / GitHub 同步：https://docs.overleaf.com/integrations-and-add-ons/git-integration-and-github-synchronization
