"""Sentinel Cartography — a one-page chart of the MDC CWPP workshop.

Refined pass: single primary subject anchored in the optical centre with
deliberate margins; the rest is sparse, ceremonial cartouche work.
Output: ONE-PAGER.pdf — A4 portrait.
"""
import math
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.colors import Color

import os
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "ONE-PAGER.pdf")
FONT_DIR = os.path.join(HERE, "fonts")

def _reg(name, path):
    try:
        pdfmetrics.registerFont(TTFont(name, path)); return True
    except Exception:
        return False

_reg("Serif",       f"{FONT_DIR}/InstrumentSerif-Regular.ttf")
_reg("SerifItalic", f"{FONT_DIR}/InstrumentSerif-Italic.ttf")
_reg("Mono",        f"{FONT_DIR}/IBMPlexMono-Regular.ttf")
_reg("MonoBold",    f"{FONT_DIR}/IBMPlexMono-Bold.ttf")

# ----- Palette (Sentinel Cartography) -----
NIGHT   = Color(0x0A/255, 0x0F/255, 0x28/255)
NIGHT_2 = Color(0x10/255, 0x16/255, 0x32/255)
INK     = Color(0xE9/255, 0xEE/255, 0xF7/255)
ICE     = Color(0xC2/255, 0xCF/255, 0xEB/255)
DIM     = Color(0x5F/255, 0x6E/255, 0x9A/255)
GRID    = Color(0x1B/255, 0x23/255, 0x4A/255)
GRID_2  = Color(0x12/255, 0x18/255, 0x38/255)
CORAL   = Color(0xF9/255, 0x61/255, 0x67/255)
GOLD    = Color(0xF0/255, 0xBF/255, 0x5C/255)

W, H = A4
M = 42
c = canvas.Canvas(OUT, pagesize=A4)


def text(x, y, s, font="Serif", size=10, color=INK, align="left", tracking=0):
    c.setFillColor(color); c.setFont(font, size)
    if tracking:
        # manual letter-spacing
        cur = x
        if align in ("center", "right"):
            total = sum(pdfmetrics.stringWidth(ch, font, size) for ch in s) + tracking*(len(s)-1)
            cur = x - total/2 if align == "center" else x - total
        for ch in s:
            c.drawString(cur, y, ch)
            cur += pdfmetrics.stringWidth(ch, font, size) + tracking
        return
    if align == "center":
        c.drawString(x - pdfmetrics.stringWidth(s, font, size)/2, y, s)
    elif align == "right":
        c.drawString(x - pdfmetrics.stringWidth(s, font, size), y, s)
    else:
        c.drawString(x, y, s)


# ----------------------------------------------------------------------
# 1.  Background field + coordinate grid
# ----------------------------------------------------------------------
c.setFillColor(NIGHT); c.rect(0, 0, W, H, fill=1, stroke=0)

# Soft inner lift (subtle vignette band where the chart sits)
c.setFillColor(NIGHT_2)
c.rect(M*1.6, H*0.18, W - M*3.2, H*0.62, fill=1, stroke=0)

# Minor grid
c.setStrokeColor(GRID_2); c.setLineWidth(0.22)
step = 18
x = 0
while x <= W: c.line(x, 0, x, H); x += step
y = 0
while y <= H: c.line(0, y, W, y); y += step

# Major grid (every 5 cells)
c.setStrokeColor(GRID); c.setLineWidth(0.35)
x = 0
while x <= W: c.line(x, 0, x, H); x += step * 5
y = 0
while y <= H: c.line(0, y, W, y); y += step * 5

# Neat-line frame (double)
c.setStrokeColor(ICE); c.setLineWidth(0.6); c.rect(M, M, W - 2*M, H - 2*M, fill=0, stroke=1)
c.setLineWidth(0.3);                       c.rect(M + 5, M + 5, W - 2*M - 10, H - 2*M - 10, fill=0, stroke=1)

# Frame ticks (every 0.5cm)
c.setStrokeColor(ICE); c.setLineWidth(0.35)
for i in range(0, int(W - 2*M), 14):
    c.line(M + i, M, M + i, M + 4)
    c.line(M + i, H - M, M + i, H - M - 4)
for i in range(0, int(H - 2*M), 14):
    c.line(M, M + i, M + 4, M + i)
    c.line(W - M, M + i, W - M - 4, M + i)


# ----------------------------------------------------------------------
# 2.  Title cartouche (top)
# ----------------------------------------------------------------------
top = H - M - 22

text(M + 14, top, "PLATE  N°  01      SENTINEL CARTOGRAPHY      EDITION  2026.05.20",
     font="Mono", size=7.5, color=DIM, tracking=1)

# Coral pip + title
c.setFillColor(CORAL); c.rect(M + 14, top - 36, 26, 1.6, fill=1, stroke=0)
text(M + 14, top - 64, "Microsoft Defender for Cloud",
     font="Serif", size=36, color=INK)
text(M + 14, top - 88, "Cloud Workload Protection Platform — a hands-on workshop",
     font="SerifItalic", size=15, color=ICE)

# Two-line caption in mono, like a museum plate
text(M + 14, top - 112,
     "An observation table of eleven protective plans, one hundred",
     font="Mono", size=8, color=DIM, tracking=0.4)
text(M + 14, top - 124,
     "and ten simulated events, plotted against the MITRE ATT&CK matrix.",
     font="Mono", size=8, color=DIM, tracking=0.4)

# Right cartouche (legend)
lx = W - M - 14
text(lx, top, "LEGEND", font="Mono", size=7.5, color=DIM, align="right", tracking=1)
# items
lg_y = top - 22
c.setStrokeColor(ICE); c.setLineWidth(0.45)
c.circle(lx - 132, lg_y + 2, 3.0, fill=0, stroke=1)
c.setFillColor(INK); c.circle(lx - 132, lg_y + 2, 0.9, fill=1, stroke=0)
text(lx - 122, lg_y, "plan  ·  ten scenarios", font="Mono", size=7.5, color=DIM)
lg_y -= 14
c.setStrokeColor(GOLD); c.setLineWidth(0.6)
c.line(lx - 138, lg_y + 2.5, lx - 122, lg_y + 2.5)
text(lx - 116, lg_y, "kill-chain  ·  ten steps", font="Mono", size=7.5, color=DIM)
lg_y -= 14
c.setStrokeColor(CORAL); c.setLineWidth(0.5)
c.circle(lx - 132, lg_y + 2, 3.0, fill=0, stroke=1)
c.setFillColor(CORAL); c.circle(lx - 132, lg_y + 2, 1.2, fill=1, stroke=0)
text(lx - 122, lg_y, "alert observed",        font="Mono", size=7.5, color=DIM)


# ----------------------------------------------------------------------
# 3.  Central subject — Constellation of plans
# ----------------------------------------------------------------------
cx, cy, R = W/2, H*0.52, 138

# Orbital rings (very thin, like astronomical plate)
c.setStrokeColor(GRID); c.setLineWidth(0.35); c.circle(cx, cy, R, fill=0, stroke=1)
c.setLineWidth(0.18); c.setStrokeColor(GRID_2)
c.circle(cx, cy, R - 14, fill=0, stroke=1)
c.circle(cx, cy, R + 14, fill=0, stroke=1)
c.circle(cx, cy, R + 36, fill=0, stroke=1)

# Cross-hair through centre (recedes towards edges)
c.setStrokeColor(GRID); c.setLineWidth(0.3)
c.line(cx - R - 50, cy, cx - 14, cy); c.line(cx + 14, cy, cx + R + 50, cy)
c.line(cx, cy - R - 50, cx, cy - 14); c.line(cx, cy + 14, cx, cy + R + 50)

# Centre mark
c.setStrokeColor(ICE); c.setLineWidth(0.5)
c.circle(cx, cy, 4.5, fill=0, stroke=1)
c.setFillColor(ICE); c.circle(cx, cy, 0.9, fill=1, stroke=0)
text(cx, cy - 16, "POINT  Ø", font="Mono", size=6.5, color=DIM, align="center", tracking=0.6)
text(cx, cy - 26, "one PoC subscription", font="Mono", size=6.5, color=DIM, align="center")

# 11 plan nodes
plans = [
    ("Servers",      "P-01"),
    ("Containers",   "P-02"),
    ("Storage",      "P-03"),
    ("SQL",          "P-04"),
    ("App Service",  "P-05"),
    ("Key Vault",    "P-06"),
    ("Resource Mgr.","P-07"),
    ("DNS",          "P-08"),
    ("OSS DBs",      "P-09"),
    ("APIs",         "P-10"),
    ("AI Services",  "P-11"),
]

def node_pos(i):
    # P-01 sits at the top, then clockwise
    a = -math.pi/2 + i * (2*math.pi/len(plans))
    return cx + R*math.cos(a), cy + R*math.sin(a), a

# Kill-chain trace (10 steps demonstrating the demo flow)
# Mapping to plan indices: APIs→Servers→Servers→ARM→ARM→Containers→Containers→Storage→ARM→KV
chain = [9, 0, 0, 6, 6, 1, 1, 2, 6, 5]

# Draw the chain underneath nodes
c.setStrokeColor(GOLD); c.setLineWidth(0.6); c.setLineCap(1)
prev = None
for idx in chain:
    if prev is None or prev == idx:
        prev = idx; continue
    x1, y1, _ = node_pos(prev); x2, y2, _ = node_pos(idx)
    # gentle inward Bezier
    midx = (x1 + x2)/2 + (cx - (x1+x2)/2)*0.32
    midy = (y1 + y2)/2 + (cy - (y1+y2)/2)*0.32
    p = c.beginPath(); p.moveTo(x1, y1); p.curveTo(midx, midy, midx, midy, x2, y2)
    c.drawPath(p, stroke=1, fill=0)
    prev = idx

# Draw nodes + radial labels
for i, (name, code) in enumerate(plans):
    x, y, a = node_pos(i)
    # halo
    c.setStrokeColor(ICE); c.setLineWidth(0.4); c.circle(x, y, 9, fill=0, stroke=1)
    c.setFillColor(NIGHT); c.circle(x, y, 5.6, fill=1, stroke=0)
    c.setStrokeColor(ICE); c.setLineWidth(0.55); c.circle(x, y, 5.6, fill=0, stroke=1)
    c.setFillColor(INK); c.circle(x, y, 1.6, fill=1, stroke=0)

    # Radial label
    rx = x + math.cos(a)*30
    ry = y + math.sin(a)*30
    horiz = math.cos(a)
    if horiz > 0.15:   align = "left"
    elif horiz < -0.15:align = "right"
    else:              align = "center"
    text(rx, ry + 4, name, font="Serif", size=12, color=INK, align=align)
    text(rx, ry - 7, code, font="Mono", size=6.5, color=DIM, align=align, tracking=0.6)

# Coral alert mark beside Servers (kill-chain reaches LSASS dump)
sx, sy, sa = node_pos(0)
ax = sx + 16; ay = sy - 14
c.setStrokeColor(CORAL); c.setLineWidth(0.55)
c.circle(ax, ay, 4, fill=0, stroke=1)
c.setFillColor(CORAL); c.circle(ax, ay, 1.4, fill=1, stroke=0)
# tick line
c.line(ax, ay - 4, ax, ay - 10)
text(ax, ay - 18, "T1003.001", font="Mono", size=6.5, color=CORAL, align="center", tracking=0.4)


# ----------------------------------------------------------------------
# 4.  Bottom cartouches : matrix on the left, deliverables on the right
# ----------------------------------------------------------------------
band_y = M + 70
band_h = 120
band_x1 = M + 14
band_x2 = W/2 - 12
band_x3 = W/2 + 12
band_x4 = W - M - 14

# Thin baseline rule above the bands
c.setStrokeColor(ICE); c.setLineWidth(0.4)
c.line(band_x1, band_y + band_h + 16, band_x4, band_y + band_h + 16)

# ----- 4a.  Scenario matrix -----
text(band_x1, band_y + band_h + 8, "ONE HUNDRED AND TEN SIMULATIONS",
     font="Mono", size=8, color=ICE, tracking=0.6)
text(band_x1, band_y + band_h - 4, "eleven plans  ·  ten scenarios each",
     font="Mono", size=7, color=DIM)

cell = 11
cols = 10; rows = 11
mx = band_x1
my = band_y - 4

# severity pattern repeated from prior (filled = simulator-confirmed; ring = walk-through)
severity_pattern = [
    [1,1,1,1,1,1,1,1,1,1],
    [1,1,1,1,1,1,1,1,1,1],
    [1,1,1,1,0,1,1,1,1,1],
    [1,1,0,1,0,1,1,1,1,1],
    [1,1,1,0,0,0,1,0,1,1],
    [1,1,1,1,1,1,1,1,1,1],
    [0,0,0,1,1,1,1,1,1,1],
    [1,1,1,1,1,1,1,1,1,1],
    [1,0,0,0,1,1,1,1,1,1],
    [1,1,1,0,0,1,1,1,1,1],
    [1,1,1,1,1,1,0,1,1,1],
]

# column numerals
for ci in range(cols):
    text(mx + ci*cell + cell/2, my + rows*cell + 4,
         f"{ci+1:02d}", font="Mono", size=5.5, color=DIM, align="center")
# row labels and cells
for ri in range(rows):
    text(mx - 8, my + (rows - ri - 1)*cell + 3.5,
         plans[ri][1], font="Mono", size=5.5, color=DIM, align="right", tracking=0.4)
    for ci in range(cols):
        gx = mx + ci*cell; gy = my + (rows - ri - 1)*cell
        c.setStrokeColor(GRID); c.setLineWidth(0.22)
        c.rect(gx, gy, cell, cell, fill=0, stroke=1)
        cxx, cyy = gx + cell/2, gy + cell/2
        if severity_pattern[ri][ci]:
            c.setFillColor(INK); c.circle(cxx, cyy, 1.5, fill=1, stroke=0)
        else:
            c.setStrokeColor(ICE); c.setLineWidth(0.35)
            c.circle(cxx, cyy, 1.4, fill=0, stroke=1)


# ----- 4b.  Deliverables (right) -----
dx = band_x3 + 20
dy_top = band_y + band_h + 8
text(dx, dy_top, "DELIVERED IN THE KIT", font="Mono", size=8, color=ICE, tracking=0.6)
text(dx, dy_top - 12, "what attendees leave with",
     font="Mono", size=7, color=DIM)

deliv = [
    ("01", "Runbook"),
    ("02", "Scenario matrix · 18 sheets"),
    ("03", "Bicep + Terraform lab"),
    ("04", "13 Sentinel analytics rules"),
    ("05", "Playbooks + workbook"),
    ("06", "5 KQL hunting notebooks"),
    ("07", "Attack-simulator scripts"),
    ("08", "33-slide deck · DOCX manual"),
]
yy = dy_top - 30
for n, label in deliv:
    text(dx, yy, n, font="Mono", size=7, color=GOLD, tracking=0.6)
    text(dx + 22, yy, label, font="Serif", size=11.5, color=INK)
    yy -= 13


# ----------------------------------------------------------------------
# 5.  Tactic strip + bottom signature
# ----------------------------------------------------------------------
strip_y = M + 30
tactics = ["INITIAL ACCESS","EXECUTION","PERSISTENCE","PRIV ESC","DEF EVASION",
           "CREDENTIAL","DISCOVERY","COLLECTION","EXFIL","C2","IMPACT"]
c.setStrokeColor(ICE); c.setLineWidth(0.4)
c.line(M + 14, strip_y + 16, W - M - 14, strip_y + 16)
c.line(M + 14, strip_y - 4,  W - M - 14, strip_y - 4)

aw = W - 2*M - 28
sx = aw / len(tactics)
for i, t in enumerate(tactics):
    x = M + 14 + sx*(i + 0.5)
    text(x, strip_y + 3, t, font="Mono", size=6.5, color=DIM, align="center", tracking=0.5)
    c.setStrokeColor(ICE); c.setLineWidth(0.4)
    c.line(x, strip_y + 16, x, strip_y + 14)
    c.line(x, strip_y - 4,  x, strip_y - 2)

# Signature corners
text(M + 14, M + 14,
     "github.com/your-org/mdc-cwpp-workshop", font="Mono", size=6.5, color=DIM)
text(W - M - 14, M + 14,
     "MDC  ·  CWPP  ·  EDITION  2026 . 05 . 20",
     font="Mono", size=6.5, color=DIM, align="right", tracking=1)

# Wax-seal-style mark at bottom centre
sc_x, sc_y = W/2, M + 16
c.setStrokeColor(CORAL); c.setLineWidth(0.55)
c.circle(sc_x, sc_y, 8, fill=0, stroke=1)
c.circle(sc_x, sc_y, 5, fill=0, stroke=1)
c.setFillColor(CORAL); c.circle(sc_x, sc_y, 1.4, fill=1, stroke=0)

c.showPage()
c.save()
print(f"wrote {OUT}")
