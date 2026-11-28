#!/usr/bin/env python3
# Builds ~/Documents/System Guide.pdf from guide.md (next to this file).
# Run: ~/.config/mango/scripts/guide build   (or: uv run --with reportlab python build.py)
# guide.md, line by line:
#   # Title            > text (right after the title): the subtitle
#   ## Section         numbered, listed in the contents, and starts a new page
#   > text             a section's grey intro
#   ### Heading        a heading inside a section
#   #### Heading       a smaller one inside that (to break a long part into groups)
#   | key | what       a table row (keys in green); \| for a | inside a cell
#   - text             a bullet
#   other text         a paragraph; **bold** works everywhere
# A blank line ends a paragraph, a table or a list.
import os, re, sys
from reportlab.lib.colors import HexColor
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (BaseDocTemplate, Frame, KeepTogether, ListFlowable, ListItem, PageBreak, PageTemplate,
                                Paragraph, Spacer, Table, TableStyle)
from reportlab.platypus.tableofcontents import TableOfContents

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.environ.get("GUIDE_SRC") or os.path.join(HERE, "guide.md")
OUT = os.environ.get("GUIDE_OUT") or os.path.join(os.path.dirname(HERE), "System Guide.pdf")
FOOT = os.environ.get("GUIDE_FOOT") or "Your system: features and keys"

FONTS = "/usr/share/fonts/TTF"
pdfmetrics.registerFont(TTFont("Sans", os.path.join(FONTS, "DejaVuSans.ttf")))
pdfmetrics.registerFont(TTFont("Sans-Bold", os.path.join(FONTS, "DejaVuSans-Bold.ttf")))
pdfmetrics.registerFont(TTFont("Cond-Bold", os.path.join(FONTS, "DejaVuSansCondensed-Bold.ttf")))
pdfmetrics.registerFontFamily("Sans", normal="Sans", bold="Sans-Bold", italic="Sans", boldItalic="Sans-Bold")
MONO = os.path.join(FONTS, "JetBrainsMonoNerdFontMono-Bold.ttf")   # ttf-jetbrains-mono-nerd
KEYFONT = "Cond-Bold"
if os.path.exists(MONO):
    pdfmetrics.registerFont(TTFont("Mono-Bold", MONO))
    KEYFONT = "Mono-Bold"

INK, GREY, GREEN = HexColor("#1d2329"), HexColor("#5b6670"), HexColor("#2f6f62")
STRIPE, RULE = HexColor("#eef4f2"), HexColor("#d5ddda")
MARGIN = 43
W, H = A4
KEYW = 158

S = {
    "title": ParagraphStyle("title", fontName="Sans-Bold", fontSize=26, leading=30, textColor=INK),
    "subtitle": ParagraphStyle("subtitle", fontName="Sans", fontSize=10.5, leading=14, textColor=GREY, spaceAfter=12),
    "h1": ParagraphStyle("h1", fontName="Sans-Bold", fontSize=15, leading=19, textColor=GREEN, spaceBefore=12, spaceAfter=4),
    "intro": ParagraphStyle("intro", fontName="Sans", fontSize=9, leading=12.5, textColor=GREY, spaceAfter=6),
    "h2": ParagraphStyle("h2", fontName="Sans-Bold", fontSize=10, leading=13, textColor=INK, spaceBefore=8, spaceAfter=4),
    "h3": ParagraphStyle("h3", fontName="Sans-Bold", fontSize=8.6, leading=11, textColor=GREEN, spaceBefore=6, spaceAfter=3),
    "para": ParagraphStyle("para", fontName="Sans", fontSize=8.6, leading=12, textColor=INK, spaceAfter=4),
    "bullet": ParagraphStyle("bullet", fontName="Sans", fontSize=8.6, leading=12, textColor=INK),
    "key": ParagraphStyle("key", fontName=KEYFONT, fontSize=8, leading=11, textColor=GREEN),
    "what": ParagraphStyle("what", fontName="Sans", fontSize=8.6, leading=11, textColor=INK),
    "toc": ParagraphStyle("toc", fontName="Sans-Bold", fontSize=9.5, leading=12, textColor=INK, spaceBefore=4, spaceAfter=1),
    "tocsub": ParagraphStyle("tocsub", fontName="Sans", fontSize=7.8, leading=9.2, textColor=GREY, leftIndent=14),
}


def inline(t):
    t = t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    return re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", t)


class Doc(BaseDocTemplate):
    section = ""
    section_page = 0
    subs = 0

    def beforeDocument(self):
        self.section, self.section_page, self.subs = "", 0, 0

    def afterFlowable(self, f):
        if getattr(f, "toc_text", None):
            key = "s" + f.toc_text.split(".", 1)[0]
            self.canv.bookmarkPage(key)
            self.canv.addOutlineEntry(f.toc_text, key, 0, closed=True)
            self.notify("TOCEntry", (0, f.toc_text, self.page, key))
            self.section, self.section_page = f.toc_text, self.page
        elif getattr(f, "sub_text", None) and self.section:
            self.subs += 1
            key = f"h{self.subs}"
            self.canv.bookmarkPage(key)
            self.canv.addOutlineEntry(f.sub_text, key, 1)
            self.notify("TOCEntry", (1, f.sub_text, self.page, key))


def header(c, d):
    if not d.section or d.section_page == d.page:
        return
    c.saveState()
    c.setFont("Sans", 7.5)
    c.setFillColor(GREY)
    c.drawRightString(W - MARGIN, H - 22, d.section)
    c.restoreState()


def footer(c, d):
    c.saveState()
    c.setStrokeColor(RULE)
    c.setLineWidth(1)
    c.line(MARGIN, 34, W - MARGIN, 34)
    c.setFont("Sans", 7.5)
    c.setFillColor(GREY)
    c.drawString(MARGIN, 24, FOOT)
    c.drawRightString(W - MARGIN, 24, str(d.page))
    c.restoreState()


def table(rows, start=0):
    """Rows as a striped key / what table; START is where these rows sit in the whole table (for the stripes)."""
    data = [[Paragraph(inline(k), S["key"]), Paragraph(inline(v), S["what"])] for k, v in rows]
    t = Table(data, colWidths=[KEYW, W - 2 * MARGIN - KEYW], repeatRows=0)
    st = [("VALIGN", (0, 0), (-1, -1), "TOP"),
          ("LEFTPADDING", (0, 0), (-1, -1), 5), ("RIGHTPADDING", (0, 0), (-1, -1), 5),
          ("TOPPADDING", (0, 0), (-1, -1), 3), ("BOTTOMPADDING", (0, 0), (-1, -1), 3.5),
          ("LINEBELOW", (0, 0), (-1, -1), 0.4, RULE)]
    if start == 0:
        st.append(("LINEABOVE", (0, 0), (-1, 0), 0.4, RULE))
    st += [("BACKGROUND", (0, i), (-1, i), STRIPE) for i in range(len(rows)) if (start + i) % 2 == 0]
    t.setStyle(TableStyle(st))
    return t


def parse(lines):
    story, para, rows, bullets = [], [], [], []
    num = 0
    pending = None

    def push(f):
        nonlocal pending
        if pending:
            story.append(KeepTogether(pending + [f]))
            pending = None
        else:
            story.append(f)

    def flush():
        nonlocal para, rows, bullets
        if para:
            push(Paragraph(inline(" ".join(para)), S["para"]))
            para = []
        if rows:
            push(table(rows[:3]))
            if len(rows) > 3:
                story.append(table(rows[3:], 3))
            story.append(Spacer(1, 6))
            rows = []
        if bullets:
            push(ListFlowable([ListItem(Paragraph(inline(b), S["bullet"]), leftIndent=10, value="•") for b in bullets],
                              bulletType="bullet", start="•", leftIndent=10, bulletFontName="Helvetica", bulletFontSize=10,
                              bulletOffsetY=1, spaceAfter=4))
            bullets = []

    title_seen = False
    for raw in lines:
        line = raw.rstrip("\n")
        s = line.strip()
        if not s:
            flush()
            continue
        if s.startswith("#### "):
            flush()
            pending = (pending or []) + [Paragraph(inline(s[5:]), S["h3"])]
        elif s.startswith("### "):
            flush()
            p = Paragraph(inline(s[4:]), S["h2"])
            p.sub_text = re.sub(r"\*\*", "", s[4:])
            pending = (pending or []) + [p]
        elif s.startswith("## "):
            flush()
            num += 1
            text = f"{num}. {s[3:]}"
            p = Paragraph(inline(text), S["h1"])
            p.toc_text = text
            story.append(PageBreak())
            pending = (pending or []) + [p]
        elif s.startswith("# "):
            flush()
            story.append(Paragraph(inline(s[2:]), S["title"]))
            title_seen = True
        elif s.startswith("> "):
            flush()
            if title_seen and num == 0 and not any(getattr(f, "toc_text", None) for f in story):
                story.append(Paragraph(inline(s[2:]), S["subtitle"]))
                toc = TableOfContents(dotsMinLevel=0)
                toc.levelStyles = [S["toc"], S["tocsub"]]
                story.append(toc)
                title_seen = False
            else:
                push(Paragraph(inline(s[2:]), S["intro"]))
        elif s.startswith("| "):
            if para or bullets:
                flush()
            cells = re.split(r"(?<!\\)\|", s[2:], maxsplit=1)
            k = cells[0].strip().replace("\\|", "|")
            v = cells[1].strip().replace("\\|", "|") if len(cells) > 1 else ""
            rows.append((k, v))
        elif s.startswith("- "):
            if para or rows:
                flush()
            bullets.append(s[2:])
        else:
            if rows or bullets:
                flush()
            para.append(s)
    flush()
    if pending:
        story += pending
    return story


def main():
    with open(SRC, encoding="utf-8") as f:
        story = parse(f.readlines())
    tmp = OUT + ".part"
    d = Doc(tmp, pagesize=A4, leftMargin=MARGIN, rightMargin=MARGIN, topMargin=36, bottomMargin=48,
            title="Your system: features and keys", subject="Guide to the desktop setup")
    frame = Frame(MARGIN, 48, W - 2 * MARGIN, H - 36 - 48, id="body", leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)
    d.addPageTemplates([PageTemplate(id="page", frames=[frame], onPage=footer, onPageEnd=header)])
    d.multiBuild(story)
    os.replace(tmp, OUT)
    print(OUT)


if __name__ == "__main__":
    sys.exit(main())
