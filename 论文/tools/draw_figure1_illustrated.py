"""Restyle the approved Figure 1 flow with rounded panels and original vector icons."""

from __future__ import annotations

import math

from reportlab.lib.colors import toColor

import draw_figure1_systems as base


# Preserve the previous comparison figure and the active manuscript by using a new stem.
STEM = "图1_GriddingMachine框架_彩色组件版_2026-11-08"
WIDTH, HEIGHT = 1800, 1300
BLUE = "#326CB2"
GREEN = "#688E3D"
PURPLE = "#7956AD"
AMBER = "#B7893A"
INK = "#24374D"
MUTED = "#5B6B7D"
PALE_BLUE = "#E9F1FF"
PALE_GREEN = "#EFF6E5"
PALE_PURPLE = "#F2EBFC"
PALE_AMBER = "#FFF7E7"
GRAY = "#8090A1"


# Extend the existing vector renderer, keeping SVG and PDF coordinates identical.
class Drawing(base.Drawing):
    def __init__(self):
        super().__init__()
        self.rect(0, 0, WIDTH, HEIGHT, "white", "white", radius=0, line=0)

    def circle(self, x, y, r, fill="white", stroke=INK, width=2.5):
        self.svg.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>')
        self.pdf.setLineWidth(width)
        self.pdf.setStrokeColor(toColor(stroke))
        if fill != "none":
            self.pdf.setFillColor(toColor(fill))
        self.pdf.circle(x, HEIGHT-y, r, stroke=1, fill=int(fill != "none"))

    def shape(self, commands, fill="none", stroke=INK, width=2.6):
        parts = []
        p = self.pdf.beginPath()
        for command in commands:
            op, values = command[0], command[1:]
            parts.append(op + " ".join(str(v) for v in values))
            if op == "M":
                p.moveTo(values[0], HEIGHT-values[1])
            elif op == "L":
                p.lineTo(values[0], HEIGHT-values[1])
            elif op == "C":
                p.curveTo(values[0], HEIGHT-values[1], values[2], HEIGHT-values[3], values[4], HEIGHT-values[5])
            elif op == "Z":
                p.close()
            else:
                raise ValueError(f"Unsupported vector command: {op}")
        self.svg.append(f'<path d="{" ".join(parts)}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>')
        self.pdf.setStrokeColor(toColor(stroke))
        self.pdf.setLineWidth(width)
        if fill != "none":
            self.pdf.setFillColor(toColor(fill))
        self.pdf.drawPath(p, stroke=1, fill=int(fill != "none"))


# Draw all icons from local geometry rather than copying the supplied reference artwork.
def icon(d, name, cx, cy, size, color, pale):
    k = size / 64

    def point(x, y):
        return cx + (x-32)*k, cy + (y-32)*k

    def line(points, width=2.8, arrow=False, col=None):
        d.path([point(x, y) for x, y in points], col or color, width*k, arrow=arrow)

    def shape(commands, fill="none", col=None, width=2.8):
        values = []
        for cmd in commands:
            coords = []
            for j in range(1, len(cmd), 2):
                coords.extend(point(cmd[j], cmd[j+1]))
            values.append((cmd[0], *coords))
        d.shape(values, fill, col or color, width*k)

    def circ(x, y, r, fill="none", col=None, width=2.8):
        px, py = point(x, y)
        d.circle(px, py, r*k, fill, col or color, width*k)

    # Use a graticule for source grids and a folded document for configurations/files.
    if name == "globe":
        circ(32, 32, 26, pale)
        line([(6, 32), (58, 32)])
        line([(11, 18), (53, 18)])
        line([(11, 46), (53, 46)])
        shape([("M", 32, 6), ("C", 13, 18, 13, 46, 32, 58), ("C", 51, 46, 51, 18, 32, 6)])
        line([(32, 6), (32, 58)])
    elif name in {"config", "file"}:
        shape([("M", 12, 5), ("L", 41, 5), ("L", 53, 17), ("L", 53, 59), ("L", 12, 59), ("Z",)], "white")
        shape([("M", 41, 5), ("L", 41, 17), ("L", 53, 17)], pale)
        if name == "config":
            for y, x in [(28, 27), (39, 39), (50, 29)]:
                line([(20, y), (45, y)], 2.4)
                circ(x, y, 3.5, pale)
        else:
            for x in [21, 31, 41]:
                for y in [29, 39, 49]:
                    px, py = point(x-3, y-3)
                    d.rect(px, py, 6*k, 6*k, pale, color, radius=k, line=1.4*k)
    elif name == "gear":
        for angle in range(0, 360, 45):
            a = math.radians(angle)
            line([(32+21*math.cos(a), 32+21*math.sin(a)), (32+28*math.cos(a), 32+28*math.sin(a))], 5)
        circ(32, 32, 21, pale)
        circ(32, 32, 13, "white", width=2)
        line([(23, 32), (29, 38), (42, 25)], 3.8, col=GREEN)
    elif name == "catalog":
        shape([("M", 5, 17), ("L", 25, 17), ("L", 31, 24), ("L", 59, 24), ("L", 54, 57), ("L", 5, 57), ("Z",)], pale)
        for y in [33, 42, 51]:
            circ(16, y, 1.5, color, width=1)
            line([(23, y), (46, y)], 2.2)
        line([(8, 17), (8, 10), (43, 10), (43, 23)], 2)
    elif name == "download":
        shape([("M", 14, 39), ("C", 1, 39, 0, 20, 15, 20), ("C", 21, 2, 45, 3, 49, 23), ("C", 65, 23, 65, 43, 50, 44)], pale)
        line([(32, 25), (32, 55)], 3.5)
        line([(22, 45), (32, 55), (42, 45)], 3.5)
        line([(15, 59), (49, 59)], 2.5)
    elif name == "read":
        px, py = point(6, 8)
        d.rect(px, py, 36*k, 39*k, "white", color, radius=4*k, line=2.6*k)
        for x in [18, 30]:
            line([(x, 9), (x, 46)], 1.5)
        for y in [21, 33]:
            line([(7, y), (41, y)], 1.5)
        circ(42, 40, 13, pale)
        line([(51, 50), (61, 60)], 5)
    elif name == "leaf":
        shape([("M", 13, 49), ("C", 9, 20, 33, 8, 55, 8), ("C", 57, 34, 37, 56, 13, 49), ("Z",)], pale)
        line([(8, 58), (44, 22)], 3)
        line([(23, 42), (21, 28)], 2)
        line([(33, 32), (46, 34)], 2)
    elif name == "server":
        for y in [8, 27, 46]:
            px, py = point(6, y)
            d.rect(px, py, 52*k, 13*k, pale, color, radius=3*k, line=2.6*k)
            circ(14, y+6.5, 1.7, color, width=1)
            line([(23, y+6.5), (49, y+6.5)], 1.8)
    elif name == "laptop":
        px, py = point(11, 8)
        d.rect(px, py, 42*k, 34*k, pale, color, radius=4*k, line=2.6*k)
        shape([("M", 10, 43), ("L", 54, 43), ("L", 62, 55), ("L", 2, 55), ("Z",)], "white")
        line([(25, 49), (39, 49)], 2)
    else:
        raise ValueError(f"Unknown diagram icon: {name}")


# Use rounded colored headers with dashed lower boundaries as a stylistic reference only.
def panel(d, x, number, title, subtitle, color, pale):
    d.rect(x, 255, 554, 660, "#FDFEFE", color, radius=24, line=2.1, dash=True)
    d.rect(x, 255, 554, 99, pale, color, radius=24, line=2.4)
    d.rect(x+2, 337, 550, 25, pale, pale, radius=0, line=0)
    d.path([(x, 355), (x+554, 355)], color, 2, dashed=True, arrow=False)
    d.circle(x+41, 296, 25, pale, color, 2)
    d.circle(x+41, 296, 20.5, color, "white", 1.4)
    d.text(x+41, 307, str(number), 30, "white", bold=True, anchor="middle")
    d.text(x+83, 301, title, 34, color, bold=True)
    d.text(x+83, 337, subtitle, 25, color)


# Give individual components a restrained offset edge and a consistent icon-friendly layout.
def card(d, x, y, w, h, color, pale="white", radius=16):
    d.rect(x+3, y+4, w, h, "#EEF1F5", "#EEF1F5", radius=radius, line=0)
    d.rect(x, y, w, h, pale, color, radius=radius, line=2.4)


# Keep the baseline quieter than the new framework, without changing its functional comparison.
def baseline(d):
    d.text(36, 37, "(a) 2022版GriddingMachine（v0.2）", 31, bold=True)
    values = [
        (36, "数据源专用脚本", "按数据源分别编写转换方法"),
        (622, "FTP文件与包内数据目录", "tar.gz + Artifacts.toml"),
        (1208, "单数据读取与在线请求", "read_LUT · Requestor"),
    ]
    for x, title, subtitle in values:
        d.rect(x, 60, 554, 103, "#F6F8FB", "#CBD4DF", radius=14)
        d.text(x+24, 102, title, 29, MUTED, bold=True, max_width=506)
        d.text(x+24, 142, subtitle, 26, MUTED, max_width=506)


# Keep source values and YAML rules as separate inputs to the processing component.
def preprocessing(d):
    card(d, 60, 392, 210, 145, BLUE, "#F7FAFF")
    icon(d, "globe", 165, 431, 53, BLUE, PALE_BLUE)
    d.text(165, 485, "源网格数据", 28, BLUE, bold=True, anchor="middle")
    d.text(165, 519, "多维变量与坐标", 25, MUTED, anchor="middle", max_width=192)
    card(d, 60, 639, 210, 145, AMBER, "#FFFCF5")
    icon(d, "config", 165, 680, 51, AMBER, PALE_AMBER)
    d.text(165, 733, "YAML配置", 28, AMBER, bold=True, anchor="middle")
    d.text(165, 767, "转换与填补规则", 25, MUTED, anchor="middle", max_width=192)
    card(d, 312, 390, 250, 394, BLUE, "#F5F9FF")
    icon(d, "gear", 437, 433, 67, BLUE, PALE_BLUE)
    d.text(437, 497, "Cartographer", 30, BLUE, bold=True, anchor="middle", max_width=226)
    d.text(437, 535, "2.1  标准化与验证", 25, BLUE, anchor="middle", max_width=226)
    d.path([(332, 554), (542, 554)], "#B9CFEA", 1.6, arrow=False)
    for y, value in [(601, "维度与坐标"), (655, "数值与缺失值"), (709, "空间核查与保存")]:
        d.rect(332, y-20, 22, 22, "white", "#85AD70", radius=5, line=1.6)
        d.path([(336, y-10), (341, y-5), (350, y-16)], GREEN, 2.3, arrow=False)
        d.text(365, y, value, 25, INK, max_width=181)
    d.path([(270, 464), (312, 464)], BLUE, 3)
    d.path([(270, 712), (291, 712), (291, 676), (312, 676)], AMBER, 2.8, dashed=True)
    d.rect(60, 839, 506, 48, PALE_BLUE, "#B6CFEF", radius=12, line=1.7)
    d.text(313, 871, "实现：GriddingMachineDatasets", 25, BLUE, anchor="middle", max_width=478)


# Keep shared files distinct from the catalog and show metadata registration explicitly.
def distribution(d):
    card(d, 660, 390, 480, 198, GREEN, "#FBFDF7")
    icon(d, "file", 705, 432, 52, GREEN, PALE_GREEN)
    d.text(750, 440, "2.2  标准NetCDF文件", 28, GREEN, bold=True, max_width=365)
    d.text(900, 492, "TAG.nc", 32, INK, anchor="middle")
    for x, w, title in [(689, 111, "Zenodo"), (811, 168, "ScienceDB"), (990, 122, "FTP")]:
        d.rect(x, 528, w, 42, PALE_GREEN, "#ADC992", radius=10, line=1.5)
        d.text(x+w/2, 557, title, 24, GREEN, anchor="middle", max_width=w-14)
    card(d, 660, 685, 480, 128, AMBER, "#FFFCF5")
    icon(d, "catalog", 707, 728, 52, AMBER, PALE_AMBER)
    d.text(752, 736, "2.3  数据库文件", 29, AMBER, bold=True, max_width=358)
    d.text(900, 783, "Artifacts.yaml", 30, INK, anchor="middle")
    d.path([(562, 464), (660, 464)], BLUE, 3)
    d.path([(900, 588), (900, 685)], AMBER, 2.8, dashed=True)
    d.text(921, 644, "登记文件信息", 25, AMBER, max_width=200)
    d.rect(660, 839, 480, 48, PALE_GREEN, "#B4CD9A", radius=12, line=1.7)
    d.text(900, 871, "文件与目录独立发布、留存版本", 25, GREEN, anchor="middle", max_width=454)


# Keep metadata lookup separate from downloaded files, followed by local reading and application.
def local_access(d):
    card(d, 1248, 390, 474, 154, PURPLE, "#FCF9FF")
    icon(d, "download", 1301, 445, 64, PURPLE, PALE_PURPLE)
    d.text(1358, 435, "Collector", 33, PURPLE, bold=True)
    d.text(1358, 476, "2.4  数据自动下载", 27, PURPLE, max_width=343)
    d.text(1358, 516, "镜像获取与文件核验", 26, MUTED, max_width=343)
    card(d, 1248, 633, 474, 146, PURPLE, "#FCF9FF")
    icon(d, "read", 1301, 690, 62, PURPLE, PALE_PURPLE)
    d.text(1358, 677, "Indexer", 33, PURPLE, bold=True)
    d.text(1358, 719, "2.5  单文件与集合读取", 27, PURPLE, max_width=343)
    d.text(1358, 759, "全域 · 周期 · 格点", 26, MUTED, max_width=343)
    d.path([(1140, 464), (1248, 464)], GREEN, 3)
    d.text(1194, 441, "下载", 24, GREEN, anchor="middle")
    d.path([(1485, 544), (1485, 633)], PURPLE, 3)
    d.text(1505, 596, "本地文件", 25, PURPLE)
    d.path([(1140, 749), (1188, 749), (1188, 584), (1430, 584), (1430, 544)], AMBER, 2.8, dashed=True)
    d.text(1259, 571, "目录查找", 24, AMBER)
    card(d, 1248, 816, 474, 80, PURPLE, PALE_PURPLE, radius=13)
    icon(d, "leaf", 1291, 857, 49, GREEN, PALE_GREEN)
    d.text(1326, 850, "科研程序与模式应用", 28, PURPLE, bold=True, max_width=370)
    d.text(1326, 883, "变量 · 参数 · 气象序列", 24, MUTED, max_width=370)
    d.path([(1485, 779), (1485, 816)], PURPLE, 3)


# Preserve server-side reuse and the two opposite request/response directions.
def remote_access(d):
    d.text(36, 973, "(c) 在线格点访问：复用相同的获取与读取模块", 31, bold=True)
    d.rect(36, 1002, 1728, 235, "#FCFAFF", "#BBA8D5", radius=20, line=2.1)
    card(d, 70, 1044, 350, 144, BLUE, "#F7FAFF")
    icon(d, "file", 111, 1084, 44, BLUE, PALE_BLUE)
    d.text(151, 1092, "同一文件与目录", 28, BLUE, bold=True, max_width=250)
    d.text(245, 1150, "NetCDF + Artifacts.yaml", 25, MUTED, anchor="middle", max_width=326)
    card(d, 560, 1022, 660, 184, PURPLE, PALE_PURPLE)
    icon(d, "server", 596, 1053, 39, PURPLE, "white")
    d.text(629, 1063, "2.6  GMServer", 30, PURPLE, bold=True)
    d.text(1194, 1063, "独立服务器组件", 25, PURPLE, anchor="end")
    for x, name, symbol in [(600, "Collector", "download"), (925, "Indexer", "read")]:
        d.rect(x, 1091, 230, 64, "white", "#AF95CE", radius=11, line=1.9)
        icon(d, symbol, x+31, 1123, 37, PURPLE, PALE_PURPLE)
        d.text(x+64, 1133, name, 29, PURPLE, bold=True, max_width=160)
    d.path([(830, 1123), (925, 1123)], PURPLE, 3)
    d.text(890, 1193, "服务端获取、缓存与读取", 26, MUTED, anchor="middle")
    card(d, 1440, 1044, 296, 144, BLUE, "#F7FAFF")
    d.text(1588, 1087, "2.7  Requestor", 30, BLUE, bold=True, anchor="middle", max_width=272)
    icon(d, "laptop", 1480, 1144, 43, BLUE, PALE_BLUE)
    d.text(1515, 1136, "科研程序请求", 25, MUTED, max_width=204)
    d.text(1515, 1172, "接收格点数据", 25, MUTED, max_width=204)
    d.path([(420, 1123), (560, 1123)], BLUE, 2.8)
    d.text(490, 1100, "按需获取", 25, BLUE, anchor="middle")
    d.path([(1440, 1093), (1220, 1093)], BLUE, 2.8, dashed=True)
    d.text(1330, 1070, "标签 / 位置 / 周期", 24, BLUE, anchor="middle", max_width=220)
    d.path([(1220, 1164), (1440, 1164)], PURPLE, 3)
    d.text(1330, 1200, "格点数据", 26, PURPLE, anchor="middle")


# Keep one line-style legend so the new visual decoration does not create new scientific semantics.
def legend(d):
    d.path([(40, 1274), (100, 1274)], BLUE, 3)
    d.text(115, 1283, "数据传递", 25, MUTED)
    d.path([(302, 1274), (362, 1274)], AMBER, 2.8, dashed=True)
    d.text(377, 1283, "配置、目录或请求信息", 25, MUTED)
    d.text(1764, 1283, "文件与目录可独立于访问软件更新", 25, INK, anchor="end")


# Reuse the existing PDF export with a separate filename and a slightly taller illustration canvas.
def main():
    base.WIDTH, base.HEIGHT, base.STEM = WIDTH, HEIGHT, STEM
    base.register_fonts()
    d = Drawing()
    baseline(d)
    d.text(36, 221, "(b) 新版GriddingMachine（v0.5）", 31, bold=True)
    panel(d, 36, 1, "数据预处理", "复用处理规则", BLUE, PALE_BLUE)
    panel(d, 622, 2, "数据分发", "数据与目录独立维护", GREEN, PALE_GREEN)
    panel(d, 1208, 3, "数据读取", "单文件访问与多源集合", PURPLE, PALE_PURPLE)
    preprocessing(d)
    distribution(d)
    local_access(d)
    remote_access(d)
    legend(d)
    d.finish()
    print(f"Exported illustrated Figure 1 SVG/PDF with {len(d.labels)} width-checked labels.")


if __name__ == "__main__":
    main()
