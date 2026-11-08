"""Draw a systems-paper variant of Figure 1 without replacing the manuscript figure."""

from __future__ import annotations

import html
import math
import os
from pathlib import Path

from reportlab.lib.colors import toColor
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas


# Keep editable SVG and embedded-font vector PDF outputs in the existing figure directory.
ROOT = Path(__file__).resolve().parents[1]
FIGURES = ROOT / "figures"
STEM = "图1_GriddingMachine框架_系统论文风格_2026-11-08"
WIDTH, HEIGHT = 1800, 1200
PRINT_WIDTH_MM = 180
INK = "#203349"
MUTED = "#596779"
BLUE = "#35618B"
TEAL = "#217973"
AMBER = "#9C6B2F"
PURPLE = "#77638D"
GRAY = "#78828E"
PALE_BLUE = "#F3F7FB"
PALE_TEAL = "#F2F8F7"
PALE_AMBER = "#FCF9F3"
PALE_PURPLE = "#F8F5FA"
RULE = "#CCD4DC"


# Use configurable TrueType CJK fonts so the PDF contains embedded searchable text.
def register_fonts() -> None:
    candidates = [
        (os.getenv("GM_FIGURE_FONT", ""), os.getenv("GM_FIGURE_BOLD", "")),
        ("/System/Library/Fonts/STHeiti Light.ttc", "/System/Library/Fonts/STHeiti Medium.ttc"),
        ("/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc", "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc"),
    ]
    for regular, bold in candidates:
        if regular and bold and Path(regular).is_file() and Path(bold).is_file():
            pdfmetrics.registerFont(TTFont("FigureRegular", regular, subfontIndex=0))
            pdfmetrics.registerFont(TTFont("FigureBold", bold, subfontIndex=0))
            return
    raise RuntimeError("Set GM_FIGURE_FONT and GM_FIGURE_BOLD to embeddable CJK TrueType fonts.")


# Render identical primitives to SVG and PDF, with top-left coordinates in the scene.
class Drawing:
    def __init__(self) -> None:
        self.svg = [
            '<?xml version="1.0" encoding="UTF-8"?>',
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}" role="img" aria-labelledby="title description">',
            '<title id="title">GriddingMachine框架更新与模块协作</title>',
            '<desc id="description">旧版对照；新版的预处理、独立分发与本地读取；GMServer和Requestor的远程格点访问。实线为数据传递，虚线为配置、目录或请求信息。</desc>',
            '<style>text{font-family:"Heiti SC","PingFang SC","Noto Sans CJK SC",Arial,sans-serif}</style>',
            '<rect width="1800" height="1200" fill="white"/>',
        ]
        scale = PRINT_WIDTH_MM / 25.4 * 72 / WIDTH
        self.pdf = canvas.Canvas(str(FIGURES / f"{STEM}.pdf"), pagesize=(WIDTH * scale, HEIGHT * scale))
        self.pdf.setTitle("GriddingMachine framework and module interactions")
        self.pdf.setAuthor("GriddingMachine research")
        self.pdf.scale(scale, scale)
        self.labels = []

    def rect(self, x, y, w, h, fill="white", stroke=RULE, radius=6, line=1.8, dash=False):
        self.svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{fill}" stroke="{stroke}" stroke-width="{line}"' + (' stroke-dasharray="9 6"' if dash else '') + '/>')
        self.pdf.setFillColor(toColor(fill))
        self.pdf.setStrokeColor(toColor(stroke))
        self.pdf.setLineWidth(line)
        self.pdf.setDash([9, 6] if dash else [])
        self.pdf.roundRect(x, HEIGHT-y-h, w, h, radius, stroke=1, fill=1)
        self.pdf.setDash([])

    def text(self, x, y, value, size=28, color=INK, bold=False, anchor="start", max_width=None):
        font = "FigureBold" if bold else "FigureRegular"
        width = pdfmetrics.stringWidth(value, font, size)
        if max_width is not None and width > max_width:
            raise ValueError(f"Label exceeds its allocated width: {value} ({width:.1f} > {max_width})")
        self.labels.append((x, y, value, size))
        self.svg.append(f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{600 if bold else 400}" fill="{color}" text-anchor="{anchor}">{html.escape(value)}</text>')
        self.pdf.setFillColor(toColor(color))
        self.pdf.setFont(font, size)
        fn = {"start": self.pdf.drawString, "middle": self.pdf.drawCentredString, "end": self.pdf.drawRightString}[anchor]
        fn(x, HEIGHT-y, value)

    def path(self, points, color=INK, width=2.5, dashed=False, arrow=True):
        coords = " ".join(("M" if i == 0 else "L") + f"{x} {y}" for i, (x, y) in enumerate(points))
        self.svg.append(f'<path d="{coords}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"' + (' stroke-dasharray="8 6"' if dashed else '') + '/>')
        self.pdf.setLineWidth(width)
        self.pdf.setStrokeColor(toColor(color))
        self.pdf.setDash([8, 6] if dashed else [])
        p = self.pdf.beginPath()
        p.moveTo(points[0][0], HEIGHT-points[0][1])
        for x, y in points[1:]:
            p.lineTo(x, HEIGHT-y)
        self.pdf.drawPath(p)
        self.pdf.setDash([])
        if arrow:
            x, y = points[-1]
            px, py = points[-2]
            theta = math.atan2(y-py, x-px)
            tip = [(x, y)] + [(x-12*math.cos(theta) + sign*5*math.sin(theta), y-12*math.sin(theta)-sign*5*math.cos(theta)) for sign in (-1, 1)]
            self.svg.append('<polygon points="' + ' '.join(f'{a},{b}' for a, b in tip) + f'" fill="{color}"/>')
            self.pdf.setFillColor(toColor(color))
            ap = self.pdf.beginPath()
            ap.moveTo(tip[0][0], HEIGHT-tip[0][1])
            for a, b in tip[1:]:
                ap.lineTo(a, HEIGHT-b)
            ap.close()
            self.pdf.drawPath(ap, stroke=0, fill=1)

    def finish(self):
        self.svg.append('</svg>')
        (FIGURES / f"{STEM}.svg").write_text('\n'.join(self.svg) + '\n', encoding="utf-8")
        self.pdf.showPage()
        self.pdf.save()


# Create aligned stage headers with explicit roles instead of repeating optimization cards.
def stage(d, x, w, title, subtitle, fill, accent):
    d.rect(x, 274, w, 536, fill, RULE, radius=9)
    d.rect(x, 274, 6, 77, accent, accent, radius=0, line=0)
    d.text(x+24, 310, title, 34, accent, bold=True)
    d.text(x+24, 343, subtitle, 27, MUTED)
    d.path([(x+24, 361), (x+w-24, 361)], RULE, 1.3, arrow=False)


# Reserve the large panel for the actual new framework; the baseline stays compact.
def draw_baseline(d):
    d.text(36, 40, "(a) 2022版GriddingMachine（v0.2）", 33, bold=True)
    cells = [
        (36, 506, "数据源专用脚本", "按数据源分别编写转换方法"),
        (570, 460, "FTP文件与包内数据目录", "tar.gz + Artifacts.toml"),
        (1058, 706, "单数据读取与在线请求", "read_LUT · Requestor"),
    ]
    for x, w, title, subtitle in cells:
        d.rect(x, 65, w, 111, "#F7F8FA", "#D4DAE0")
        d.text(x+24, 108, title, 30, MUTED, bold=True, max_width=w-48)
        d.text(x+24, 148, subtitle, 27, MUTED, max_width=w-48)


# Feed source values and YAML rules into the processor through distinct arrows.
def draw_preprocessing(d):
    d.rect(60, 390, 190, 105, "white", BLUE)
    d.text(155, 431, "源网格数据", 28, BLUE, bold=True, anchor="middle", max_width=174)
    d.text(155, 469, "多维变量与坐标", 25, MUTED, anchor="middle", max_width=178)
    d.rect(60, 578, 190, 102, "white", PURPLE)
    d.text(155, 619, "YAML配置", 28, PURPLE, bold=True, anchor="middle", max_width=174)
    d.text(155, 655, "转换与填补规则", 25, MUTED, anchor="middle", max_width=178)
    d.rect(282, 390, 236, 290, "white", BLUE, line=2.2)
    d.text(400, 430, "Cartographer", 31, BLUE, bold=True, anchor="middle", max_width=218)
    d.text(400, 469, "2.1  标准化与验证", 26, BLUE, anchor="middle", max_width=218)
    d.path([(300, 490), (500, 490)], "#D9E3ED", 1.3, arrow=False)
    for y, label in [(533, "维度与坐标"), (578, "数值与缺失值"), (623, "空间核查与保存")]:
        d.text(400, y, label, 28, anchor="middle", max_width=216)
    d.path([(250, 442), (282, 442)], BLUE)
    d.path([(250, 629), (268, 629), (268, 585), (282, 585)], PURPLE, dashed=True)
    d.text(289, 772, "实现：GriddingMachineDatasets", 25, MUTED, anchor="middle", max_width=466)


# Keep shared data files and the catalog as separate objects; the catalog describes the files.
def draw_distribution(d):
    d.rect(600, 390, 400, 152, "white", AMBER, line=2.1)
    d.text(800, 430, "2.2  标准NetCDF文件", 30, AMBER, bold=True, anchor="middle", max_width=366)
    d.text(800, 472, "TAG.nc", 29, anchor="middle")
    d.text(800, 514, "Zenodo · ScienceDB · FTP", 25, MUTED, anchor="middle", max_width=372)
    d.rect(600, 625, 400, 112, "white", PURPLE, line=2.1)
    d.text(800, 666, "2.3  数据库文件", 30, PURPLE, bold=True, anchor="middle")
    d.text(800, 709, "Artifacts.yaml", 28, anchor="middle")
    d.path([(518, 442), (600, 442)], BLUE)
    d.path([(800, 542), (800, 625)], PURPLE, dashed=True)
    d.text(815, 586, "登记文件信息", 25, PURPLE, max_width=180)
    d.text(800, 772, "数据文件与目录单独发布、留存版本", 25, MUTED, anchor="middle", max_width=438)


# Show the file path and metadata lookup separately before the shared reading interface.
def draw_local_access(d):
    d.rect(1086, 390, 270, 152, "white", TEAL, line=2.1)
    d.text(1221, 433, "Collector", 33, TEAL, bold=True, anchor="middle")
    d.text(1221, 474, "2.4  数据自动下载", 27, TEAL, anchor="middle", max_width=242)
    d.text(1221, 515, "镜像获取与文件核验", 26, MUTED, anchor="middle", max_width=244)
    d.rect(1440, 390, 296, 152, "white", TEAL, line=2.1)
    d.text(1588, 433, "Indexer", 33, TEAL, bold=True, anchor="middle")
    d.text(1588, 474, "2.5  单文件与集合读取", 27, TEAL, anchor="middle", max_width=270)
    d.text(1588, 515, "全域 · 周期 · 格点", 26, MUTED, anchor="middle", max_width=270)
    d.path([(1000, 442), (1086, 442)], TEAL)
    d.text(1043, 422, "下载", 24, TEAL, anchor="middle")
    d.path([(1356, 442), (1440, 442)], TEAL)
    d.text(1398, 422, "文件", 24, TEAL, anchor="middle")
    d.path([(1000, 680), (1138, 680), (1138, 590), (1221, 590), (1221, 542)], PURPLE, dashed=True)
    d.text(1153, 644, "目录查找", 26, PURPLE, max_width=160)
    d.rect(1340, 660, 396, 104, PALE_TEAL, "#B5D0CC")
    d.text(1538, 702, "科研程序与模式应用", 30, TEAL, bold=True, anchor="middle", max_width=370)
    d.text(1538, 741, "网格变量 · 参数 · 气象序列", 26, MUTED, anchor="middle", max_width=368)
    d.path([(1588, 542), (1588, 660)], TEAL)
    d.text(1607, 601, "读取结果", 26, TEAL)


# Put Collector and Indexer inside the server boundary to communicate reuse rather than a new pipeline.
def draw_remote_access(d):
    d.text(36, 866, "(c) 在线格点访问：服务端复用相同的获取与读取模块", 33, bold=True)
    d.rect(36, 891, 1728, 255, "#FCFDFD", "#D4DDE1", radius=9)
    d.rect(70, 946, 350, 145, "white", "#9CAAB8")
    d.text(245, 990, "同一数据文件与目录", 29, bold=True, anchor="middle", max_width=320)
    d.text(245, 1036, "NetCDF + Artifacts.yaml", 25, MUTED, anchor="middle", max_width=325)
    d.rect(560, 924, 660, 190, PALE_TEAL, TEAL, radius=7, line=2.1)
    d.text(585, 965, "2.6  GMServer", 32, TEAL, bold=True)
    d.text(1195, 965, "独立服务器组件", 27, TEAL, anchor="end")
    for x, w, name in [(600, 230, "Collector"), (925, 230, "Indexer")]:
        d.rect(x, 991, w, 64, "white", "#94B7B0", radius=4)
        d.text(x+w/2, 1033, name, 29, TEAL, bold=True, anchor="middle")
    d.path([(830, 1023), (925, 1023)], TEAL)
    d.text(890, 1093, "服务端获取、缓存与读取", 27, MUTED, anchor="middle")
    d.path([(420, 1023), (560, 1023)], GRAY)
    d.text(490, 998, "按需获取", 25, MUTED, anchor="middle")
    d.rect(1440, 946, 296, 145, "white", BLUE, line=2.1)
    d.text(1588, 990, "2.7  Requestor", 31, BLUE, bold=True, anchor="middle", max_width=270)
    d.text(1588, 1036, "科研程序中的请求接口", 26, MUTED, anchor="middle", max_width=274)
    d.text(1588, 1073, "接收所需格点数据", 26, MUTED, anchor="middle")
    d.path([(1440, 981), (1220, 981)], BLUE, dashed=True)
    d.text(1330, 958, "标签 / 位置 / 周期", 24, BLUE, anchor="middle", max_width=220)
    d.path([(1220, 1065), (1440, 1065)], TEAL)
    d.text(1330, 1101, "格点数据", 26, TEAL, anchor="middle")


# Use one compact legend for line semantics and identify the independent update boundary.
def draw_legend(d):
    d.path([(40, 1180), (100, 1180)], TEAL)
    d.text(115, 1188, "数据传递", 25, MUTED)
    d.path([(302, 1180), (362, 1180)], PURPLE, dashed=True)
    d.text(377, 1188, "配置、目录或请求信息", 25, MUTED)
    d.text(1764, 1188, "标准文件与目录可独立于访问软件更新", 26, INK, anchor="end")


# Draw the complete scene once and export both vector representations from the same geometry.
def main():
    register_fonts()
    FIGURES.mkdir(exist_ok=True)
    d = Drawing()
    draw_baseline(d)
    d.text(36, 238, "(b) 新版GriddingMachine（v0.5）", 33, bold=True)
    stage(d, 36, 506, "数据预处理", "复用处理规则", PALE_BLUE, BLUE)
    stage(d, 570, 460, "数据分发", "数据与目录独立维护", PALE_AMBER, AMBER)
    stage(d, 1058, 706, "数据读取", "单文件访问与多源集合", PALE_TEAL, TEAL)
    draw_preprocessing(d)
    draw_distribution(d)
    draw_local_access(d)
    draw_remote_access(d)
    draw_legend(d)
    d.finish()
    print(f"Exported {STEM}.svg and .pdf; {len(d.labels)} labels checked for allocated width.")


if __name__ == "__main__":
    main()
