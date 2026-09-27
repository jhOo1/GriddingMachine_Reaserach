"""Export the manuscript Markdown to a review-oriented DOCX.

The Markdown file remains the source of truth.  This exporter intentionally
implements only the structures used by the manuscript: headings, paragraphs,
pipe tables, the architecture figure, and simple inline emphasis/code.
"""

from __future__ import annotations

import re
from pathlib import Path

from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "GriddingMachine论文初稿_v0.3.md"
OUTPUT = ROOT / "GriddingMachine论文初稿_v0.3_语言优化版.docx"
FIGURE_FALLBACKS = {
    "图1_GriddingMachine总体架构.svg": ROOT / "figures" / "figure1-preview.png",
    "图1_GriddingMachine总体架构_v2.svg": ROOT / "figures" / "figure1-preview-v2.png",
    "图1_GriddingMachine数据生命周期_v3.svg": ROOT / "figures" / "figure1-preview-v3.png",
    "图1_GriddingMachine总体架构_终稿.svg": ROOT / "figures" / "图1_GriddingMachine总体架构_终稿.png",
    "图3_直接NetCDF分发效率.svg": ROOT / "figures" / "图3_直接NetCDF分发效率.png",
}


def set_run_font(run, east_asia: str = "Songti SC", latin: str = "Times New Roman") -> None:
    run.font.name = latin
    run._element.rPr.rFonts.set(qn("w:eastAsia"), east_asia)


def add_text_segments(paragraph, text: str, bold: bool = False) -> None:
    """Add ordinary text while rendering author markers as Word superscripts."""
    for part in re.split(r"(\^\d+|\\?\*)", text):
        if not part:
            continue
        marker = part.startswith("^") or part in {"*", r"\*"}
        if part.startswith("^"):
            display = part[1:]
        elif part == r"\*":
            display = "*"
        else:
            display = part
        run = paragraph.add_run(display)
        run.bold = bold
        run.font.superscript = marker
        set_run_font(run)


def add_inline(paragraph, text: str) -> None:
    parts = re.split(r"(\*\*.*?\*\*|`.*?`)", text)
    for part in parts:
        if not part:
            continue
        if part.startswith("**") and part.endswith("**"):
            content = part[2:-2]
            if content.endswith("\\"):
                content = content[:-1]
            add_text_segments(paragraph, content, bold=True)
        elif part.startswith("`") and part.endswith("`"):
            run = paragraph.add_run(part[1:-1])
            run.font.name = "Consolas"
            run._element.rPr.rFonts.set(qn("w:eastAsia"), "Songti SC")
        else:
            add_text_segments(paragraph, part)


def table_cells(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def is_separator(line: str) -> bool:
    cells = table_cells(line)
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", c) for c in cells)


def set_cell_margins(cell, top: int = 70, start: int = 90, bottom: int = 70, end: int = 90) -> None:
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for side, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tc_mar.find(qn(f"w:{side}"))
        if node is None:
            node = OxmlElement(f"w:{side}")
            tc_mar.append(node)
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")


def set_table_borders(table) -> None:
    """Use the journal-style three-line table: top, header, and bottom rules."""
    tbl_pr = table._tbl.tblPr
    borders = tbl_pr.first_child_found_in("w:tblBorders")
    if borders is None:
        borders = OxmlElement("w:tblBorders")
        tbl_pr.append(borders)
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        node = borders.find(qn(f"w:{edge}"))
        if node is None:
            node = OxmlElement(f"w:{edge}")
            borders.append(node)
        if edge in {"top", "bottom"}:
            node.set(qn("w:val"), "single")
            node.set(qn("w:sz"), "8")
            node.set(qn("w:color"), "6B7280")
        elif edge in {"left", "right", "insideH", "insideV"}:
            node.set(qn("w:val"), "nil")
        else:
            node.set(qn("w:val"), "nil")


def set_cell_bottom_border(cell, size: int = 6, color: str = "6B7280") -> None:
    """Draw the single horizontal rule beneath the table header."""
    tc_pr = cell._tc.get_or_add_tcPr()
    borders = tc_pr.first_child_found_in("w:tcBorders")
    if borders is None:
        borders = OxmlElement("w:tcBorders")
        tc_pr.append(borders)
    bottom = borders.find(qn("w:bottom"))
    if bottom is None:
        bottom = OxmlElement("w:bottom")
        borders.append(bottom)
    bottom.set(qn("w:val"), "single")
    bottom.set(qn("w:sz"), str(size))
    bottom.set(qn("w:color"), color)


def table_widths(column_count: int, table_index: int) -> list[float]:
    if column_count == 3:
        return [3.4, 7.0, 5.2]
    if table_index == 3:
        return [4.0, 4.2, 4.3, 3.1]
    return [2.5, 4.1, 4.7, 4.3]


def shade_cell(cell, fill: str) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), fill)
    tc_pr.append(shd)


def add_code_block(document: Document, lines: list[str]) -> None:
    paragraph = document.add_paragraph()
    paragraph.paragraph_format.first_line_indent = Cm(0)
    paragraph.paragraph_format.left_indent = Cm(0.55)
    paragraph.paragraph_format.right_indent = Cm(0.55)
    paragraph.paragraph_format.space_before = Pt(4)
    paragraph.paragraph_format.space_after = Pt(6)
    paragraph.paragraph_format.line_spacing = 1.0
    p_pr = paragraph._p.get_or_add_pPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), "F2F5F7")
    p_pr.append(shd)
    run = paragraph.add_run("\n".join(lines))
    run.font.name = "Consolas"
    run.font.size = Pt(8.5)
    run._element.rPr.rFonts.set(qn("w:eastAsia"), "Songti SC")


def add_table(document: Document, lines: list[str], table_index: int) -> None:
    rows = [table_cells(line) for line in lines if not is_separator(line)]
    if not rows:
        return
    width = max(len(row) for row in rows)
    table = document.add_table(rows=len(rows), cols=width)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    widths = table_widths(width, table_index)
    tbl_pr = table._tbl.tblPr
    tbl_layout = tbl_pr.first_child_found_in("w:tblLayout")
    if tbl_layout is None:
        tbl_layout = OxmlElement("w:tblLayout")
        tbl_pr.append(tbl_layout)
    tbl_layout.set(qn("w:type"), "fixed")
    # python-docx sets equal grid columns by default. Update the table grid as
    # well as each cell width so Word and LibreOffice use the intended layout.
    for grid_col, width_cm in zip(table._tbl.tblGrid.gridCol_lst, widths):
        grid_col.set(qn("w:w"), str(int(Cm(width_cm).twips)))
    set_table_borders(table)
    for i, row in enumerate(rows):
        for j in range(width):
            text = row[j] if j < len(row) else ""
            cell = table.cell(i, j)
            cell.text = ""
            cell.width = Cm(widths[j])
            cell.vertical_alignment = (
                WD_CELL_VERTICAL_ALIGNMENT.CENTER
                if i == 0 or j == 0
                else WD_CELL_VERTICAL_ALIGNMENT.TOP
            )
            set_cell_margins(cell)
            add_inline(cell.paragraphs[0], text)
            paragraph = cell.paragraphs[0]
            paragraph.paragraph_format.first_line_indent = Cm(0)
            paragraph.paragraph_format.left_indent = Cm(0)
            paragraph.paragraph_format.right_indent = Cm(0)
            paragraph.paragraph_format.space_before = Pt(0)
            paragraph.paragraph_format.space_after = Pt(0)
            paragraph.paragraph_format.line_spacing = 1.0
            paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER if i == 0 or j == 0 else WD_ALIGN_PARAGRAPH.LEFT
            for run in cell.paragraphs[0].runs:
                run.font.size = Pt(9.2 if i == 0 else 9)
                run.bold = i == 0 or run.bold
            if i == 0:
                set_cell_bottom_border(cell)


def add_table_caption(document: Document, line: str) -> None:
    paragraph = document.add_paragraph()
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    paragraph.paragraph_format.first_line_indent = Cm(0)
    paragraph.paragraph_format.space_before = Pt(4)
    paragraph.paragraph_format.space_after = Pt(4)
    paragraph.paragraph_format.line_spacing = 1.0
    add_inline(paragraph, line)


def configure(document: Document) -> None:
    section = document.sections[0]
    section.page_width = Cm(21.0)
    section.page_height = Cm(29.7)
    section.top_margin = Cm(2.54)
    section.bottom_margin = Cm(2.54)
    section.left_margin = Cm(2.8)
    section.right_margin = Cm(2.6)

    normal = document.styles["Normal"]
    normal.font.name = "Times New Roman"
    normal.font.size = Pt(10.5)
    normal._element.rPr.rFonts.set(qn("w:eastAsia"), "Songti SC")
    normal.paragraph_format.line_spacing = 1.5
    normal.paragraph_format.first_line_indent = Cm(0.74)
    normal.paragraph_format.space_after = Pt(0)

    for name, size in (("Title", 18), ("Heading 1", 15), ("Heading 2", 13), ("Heading 3", 11)):
        style = document.styles[name]
        style.font.name = "Times New Roman"
        style.font.size = Pt(size)
        style._element.rPr.rFonts.set(qn("w:eastAsia"), "Heiti SC")
        style.paragraph_format.first_line_indent = Cm(0)


def export() -> None:
    document = Document()
    configure(document)
    lines = SOURCE.read_text(encoding="utf-8").splitlines()
    i = 0
    table_index = 0
    while i < len(lines):
        line = lines[i].strip()
        if not line:
            i += 1
            continue

        if line.startswith("!["):
            image_match = re.match(r"^!\[.*?\]\((.*?)\)$", line)
            image_path = None
            if image_match:
                source_path = (SOURCE.parent / image_match.group(1)).resolve()
                image_path = FIGURE_FALLBACKS.get(source_path.name, source_path)
                if source_path.suffix.lower() == ".svg" and source_path.name not in FIGURE_FALLBACKS:
                    image_path = source_path.with_suffix(".png")
            if image_path is not None and image_path.exists():
                paragraph = document.add_paragraph()
                paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
                paragraph.add_run().add_picture(str(image_path), width=Cm(15.0))
            i += 1
            continue

        if line.startswith("```"):
            code_lines: list[str] = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                code_lines.append(lines[i])
                i += 1
            i += 1 if i < len(lines) else 0
            add_code_block(document, code_lines)
            continue

        if line.startswith("|") and i + 1 < len(lines) and is_separator(lines[i + 1].strip()):
            block = [line, lines[i + 1].strip()]
            i += 2
            while i < len(lines) and lines[i].strip().startswith("|"):
                block.append(lines[i].strip())
                i += 1
            table_index += 1
            add_table(document, block, table_index)
            continue

        match = re.match(r"^(#{1,4})\s+(.*)$", line)
        if match:
            level = len(match.group(1))
            title = match.group(2)
            if level == 1:
                paragraph = document.add_paragraph(style="Title")
                paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
                add_inline(paragraph, title)
            else:
                paragraph = document.add_heading(level=min(level - 1, 3))
                add_inline(paragraph, title)
            i += 1
            continue

        paragraph = document.add_paragraph()
        if line.startswith("- "):
            paragraph.style = "List Bullet"
            line = line[2:]
        add_inline(paragraph, line)
        if line.startswith("**表"):
            paragraph._element.getparent().remove(paragraph._element)
            add_table_caption(document, line)
        elif line.startswith("**Table"):
            paragraph._element.getparent().remove(paragraph._element)
            add_table_caption(document, line)
        elif line.startswith("**图") or line.startswith("**Fig."):
            paragraph.paragraph_format.first_line_indent = Cm(0)
        i += 1

    core = document.core_properties
    core.title = lines[0].removeprefix("# ").strip()
    core.author = "Hao Jiang; Yujie Wang"
    core.subject = "导师审阅版，由Markdown源稿自动生成"
    document.save(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    export()
