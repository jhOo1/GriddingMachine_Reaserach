"""Build an editable Overleaf project from the canonical manuscript Markdown."""

from __future__ import annotations

import hashlib
import json
import re
import shutil
import zipfile
from pathlib import Path


# Use portable ASCII asset names and include only the three current manuscript figures.
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "GriddingMachine论文初稿_v0.3.md"
OUTPUT = ROOT / "overleaf"
ARCHIVE = ROOT / "GriddingMachine_Overleaf.zip"
FIGURES = {
    "图1_GriddingMachine总体架构_终稿.svg": ("图1_GriddingMachine总体架构_终稿.png", "figure1.png"),
    "图2_OISST真实产品标准化结果.png": ("图2_OISST真实产品标准化结果.png", "figure2.png"),
    "图3_直接NetCDF分发效率.svg": ("图3_直接NetCDF分发效率.png", "figure3.png"),
}


def escape_text(text: str) -> str:
    """Escape prose while preserving scientific symbols with portable TeX commands."""
    # Keep literal symbols separate from the LaTeX commands introduced by the exporter.
    substitutions = {
        "\\": r"\textbackslash{}", "&": r"\&", "%": r"\%", "$": r"\$",
        "#": r"\#", "_": r"\_", "{": r"\{", "}": r"\}",
        "~": r"\textasciitilde{}", "^": r"\textasciicircum{}",
        "×": r"\ensuremath{\times}", "−": r"\ensuremath{-}",
        "℃": r"\ensuremath{{}^{\circ}\mathrm{C}}", "₂": r"\textsubscript{2}",
        "～": r"\ensuremath{\sim}",
    }
    return "".join(substitutions.get(char, char) for char in text)


def inline(text: str, citations: bool = True) -> str:
    """Translate the limited inline syntax used by this manuscript without rewriting prose."""
    # Tokenize before escaping so code, URLs, superscripts and citations retain their meaning.
    pattern = re.compile(
        r"(\*\*.+?\*\*|`[^`]+`|https?://[A-Za-z0-9./?=&_#%+:;~@!()\-]+"
        r"|\^\d+(?:,\d+)*(?:,?\\?\*)?|\\\*|\[\d+(?:[-,]\d+)*\])"
    )
    parts = []
    cursor = 0
    for match in pattern.finditer(text):
        parts.append(escape_text(text[cursor:match.start()]))
        value = match.group()
        if value.startswith("**"):
            parts.append(r"\textbf{" + inline(value[2:-2], citations) + "}")
        elif value.startswith("`"):
            # URL verbatim suppresses CJK font switching, so render Chinese paths as ordinary code.
            code = value[1:-1]
            if re.search(r"[\u3400-\u9fff～]", code):
                parts.append(r"\texttt{" + escape_text(code) + "}")
            else:
                parts.append(r"\nolinkurl{" + code + "}")
        elif value.startswith("http"):
            url = value.rstrip(".;")
            parts.append(r"\url{" + url + "}" + value[len(url):])
        elif value.startswith("^"):
            parts.append(r"\textsuperscript{" + value[1:].replace(r"\*", "*") + "}")
        elif value == r"\*":
            parts.append(r"\textsuperscript{*}")
        elif citations:
            # Expand citation ranges to retain the manuscript's existing reference numbers.
            numbers = []
            for item in value[1:-1].split(","):
                if "-" in item:
                    start, end = map(int, item.split("-"))
                    numbers.extend(range(start, end + 1))
                else:
                    numbers.append(int(item))
            parts.append(r"\cite{" + ",".join(f"ref{n}" for n in numbers) + "}")
        else:
            parts.append(escape_text(value))
        cursor = match.end()
    parts.append(escape_text(text[cursor:]))
    return "".join(parts)


def table_cells(line: str) -> list[str]:
    """Read manuscript pipe tables, whose cells do not contain escaped pipe delimiters."""
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def render_table(rows: list[str], index: int, captions: list[str]) -> str:
    """Use a three-rule longtable with deliberate widths and repeated column headings."""
    # Preserve all text while allowing descriptive cells and long tables to wrap naturally.
    cells = [table_cells(row) for row in rows if not re.fullmatch(r"[| :\-]+", row)]
    columns = len(cells[0])
    weights = {1: [0.13, 0.24, 0.34, 0.29], 2: [0.20, 0.44, 0.36], 3: [0.25, 0.26, 0.27, 0.22]}[index]
    assert columns == len(weights) and all(len(row) == columns for row in cells)
    available = rf"\setlength{{\gmTableWidth}}{{\dimexpr\linewidth-{2 * (columns - 1)}\tabcolsep\relax}}"
    spec = "@{}" + "".join(r">{\raggedright\arraybackslash}p{" + f"{weight:.2f}" + r"\gmTableWidth}" for weight in weights) + "@{}"
    header = " & ".join(r"\textbf{" + inline(value) + "}" for value in cells[0]) + r" \\"
    body = ["% Keep bilingual captions with the first header and repeat columns on continuation pages.",
            r"\begingroup\small\setlength{\tabcolsep}{5pt}\renewcommand{\arraystretch}{1.25}",
            available, r"\begin{longtable}{" + spec + "}"]
    for caption in captions:
        body.append(r"\multicolumn{" + str(columns) + r"}{@{}p{\linewidth}@{}}{\centering " + inline(caption) + r"\par} \\[4pt]")
    body.extend([r"\toprule", header, r"\midrule\endfirsthead", r"\toprule", header,
                 r"\midrule\endhead", r"\bottomrule\endfoot", r"\bottomrule\endlastfoot"])
    for row in cells[1:]:
        body.append(" & ".join(inline(value) for value in row) + r" \\[4pt]")
    body.extend([r"\end{longtable}", r"\endgroup"])
    return "\n".join(body)


def preamble() -> str:
    """Use fonts shipped with TeX Live so Overleaf does not depend on local macOS fonts."""
    return r"""% !TeX program = xelatex
% This editable project is generated from the canonical Markdown manuscript.
\documentclass[UTF8,a4paper,zihao=-4,fontset=fandol]{ctexart}
% Keep the layout suitable for a Chinese research manuscript rather than a slide or report.
\usepackage[top=2.5cm,bottom=2.5cm,left=2.6cm,right=2.6cm]{geometry}
\usepackage{graphicx,booktabs,longtable,array,caption,setspace}
\usepackage{xurl}
\usepackage[unicode,hidelinks]{hyperref}
% Resolve bundled font files through TeX rather than platform font registries.
\setmainfont{lmroman10-regular.otf}[BoldFont=lmroman10-bold.otf,ItalicFont=lmroman10-italic.otf,BoldItalicFont=lmroman10-bolditalic.otf]
\setsansfont{lmsans10-regular.otf}[BoldFont=lmsans10-bold.otf,ItalicFont=lmsans10-oblique.otf]
\setmonofont{lmmono10-regular.otf}
\urlstyle{same}
\setstretch{1.3}
% Use unobtrusive page numbers without running section headers.
\pagestyle{plain}
\setlength{\parskip}{3pt}
\setlength{\emergencystretch}{2em}
% Retain the existing section hierarchy and omit punctuation after section numbers.
\ctexset{
  section={format=\Large\bfseries,aftername=\quad},
  subsection={format=\large\bfseries,aftername=\quad},
  subsubsection={format=\normalsize\bfseries,aftername=\quad}}
\captionsetup{font=small,justification=justified,singlelinecheck=false,skip=5pt}
\newlength{\gmTableWidth}
\setcounter{topnumber}{3}
\renewcommand{\topfraction}{0.95}
\renewcommand{\textfraction}{0.03}
\renewcommand{\floatpagefraction}{0.75}
\hypersetup{pdftitle={面向地球系统模式的全球网格数据库：GriddingMachine框架更新与应用},pdfauthor={Hao Jiang; Yujie Wang}}
\begin{document}
"""


def export() -> None:
    """Generate the full editable manuscript, portable assets, and a clean upload archive."""
    OUTPUT.mkdir(exist_ok=True)
    (OUTPUT / "figures").mkdir(exist_ok=True)
    lines = SOURCE.read_text().splitlines()
    body = [preamble()]
    i, table_index, figure_count, reference_count = 0, 0, 0, 0
    in_references = False
    table_captions = []
    while i < len(lines):
        line = lines[i].strip()
        if not line:
            i += 1
            continue
        # Keep the screenshot's compact Chinese title and author block together.
        if i == 0:
            # Break at the subtitle boundary rather than splitting a Chinese word.
            title = line.removeprefix("# ")
            main_title, subtitle = title.split("：", 1)
            body.extend(["% Chinese title and verified dual affiliations.", r"\begin{center}",
                         r"{\zihao{3}\bfseries " + inline(main_title + "：") + r"\\[0.2em]" + inline(subtitle) + r"\par}", r"\vspace{0.6em}"])
            i += 1
            while i < len(lines) and lines[i].strip() != "## 摘要":
                if lines[i].strip():
                    body.append(inline(lines[i].strip()) + r"\par\vspace{0.35em}")
                i += 1
            body.append(r"\end{center}")
            continue
        # Keep complete bilingual captions with each figure and use stable ASCII paths.
        if line.startswith("!["):
            match = re.fullmatch(r"!\[.*\]\((.+)\)", line)
            source_name, destination = FIGURES[Path(match.group(1)).name]
            shutil.copy2(ROOT / "figures" / source_name, OUTPUT / "figures" / destination)
            captions = []
            i += 1
            while i < len(lines):
                following = lines[i].strip()
                if not following:
                    i += 1
                elif following.startswith(("**图", "**Fig.")):
                    captions.append(inline(following))
                    i += 1
                else:
                    break
            assert len(captions) == 2
            figure_count += 1
            body.extend([r"\begin{figure}[!htbp]", r"\centering",
                         rf"\includegraphics[width=\linewidth,height=0.46\textheight,keepaspectratio]{{figures/{destination}}}"])
            body.extend(r"\caption*{" + caption + "}" for caption in captions)
            body.extend([rf"\label{{fig:{figure_count}}}", r"\end{figure}"])
            continue
        # Longtables handle page breaks without rasterizing editable table content.
        if line.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(lines[i].strip())
                i += 1
            table_index += 1
            body.append(render_table(rows, table_index, table_captions))
            table_captions = []
            continue
        # Preserve manually curated reference entries rather than inventing BibTeX metadata.
        if line == "## 参考文献":
            in_references = True
            body.append(r"\begin{thebibliography}{99}\small\setlength{\itemsep}{5pt}")
            i += 1
            continue
        if in_references:
            match = re.fullmatch(r"\[(\d+)\]\s+(.+)", line)
            assert match, line
            reference_count += 1
            body.append(r"\bibitem{ref" + match[1] + "}" + inline(match[2], citations=False))
            i += 1
            continue
        # Map the existing numbered hierarchy without duplicating section numbers.
        heading = re.fullmatch(r"(#{2,4})\s+(.+)", line)
        if heading:
            level, title = len(heading[1]), heading[2]
            numbered = re.match(r"^\d+(?:\.\d+)*\s+(.+)$", title)
            command = {2: "section", 3: "subsection", 4: "subsubsection"}[level]
            if numbered:
                body.append("\\" + command + "{" + inline(numbered[1]) + "}")
            else:
                body.append("\\" + command + "*{" + inline(title) + "}")
        elif line.startswith(("**表", "**Table")):
            # Defer captions until the longtable so they cannot be orphaned on a previous page.
            table_captions.append(line)
        elif line.startswith("**A Global"):
            body.append(r"\begin{center}\large " + inline(line) + r"\end{center}")
        elif line.startswith(("**Hao JIANG**", "^1 ", "^2 ", r"\* Corresponding author")):
            body.append(r"\begin{center}\small " + inline(line) + r"\end{center}")
        else:
            body.append(inline(line) + "\n")
        i += 1
    assert (table_index, figure_count, reference_count) == (3, 3, 22)
    body.extend([r"\end{thebibliography}", r"\end{document}"])
    (OUTPUT / "main.tex").write_text("\n".join(body) + "\n")
    # Configure XeLaTeX for both Overleaf and local latexmk without shell-escape requirements.
    (OUTPUT / ".latexmkrc").write_text("# Compile the UTF-8 Chinese manuscript with XeLaTeX.\n$pdf_mode = 5;\n")
    (OUTPUT / "source_manifest.json").write_text(json.dumps({
        "source": SOURCE.name, "sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "tables": table_index, "figures": figure_count, "references": reference_count,
    }, ensure_ascii=False, indent=2) + "\n")
    # Build a minimal archive with the main document at its root and no machine-specific files.
    members = [OUTPUT / "main.tex", OUTPUT / ".latexmkrc", OUTPUT / "README.md", OUTPUT / "source_manifest.json"]
    members.extend(sorted((OUTPUT / "figures").glob("*.png")))
    with zipfile.ZipFile(ARCHIVE, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for member in members:
            archive.write(member, member.relative_to(OUTPUT))
    print(ARCHIVE)


if __name__ == "__main__":
    export()
