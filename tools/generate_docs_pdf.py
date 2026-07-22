from __future__ import annotations

import html
import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    Image,
    CondPageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "说明文档.md"
OUTPUT = ROOT / "output" / "pdf" / "番茄钟项目说明文档.pdf"
FONT_REGULAR = Path(r"C:\Windows\Fonts\msyh.ttc")
FONT_BOLD = Path(r"C:\Windows\Fonts\msyhbd.ttc")


def register_fonts() -> None:
    pdfmetrics.registerFont(TTFont("YaHei", str(FONT_REGULAR), subfontIndex=0))
    pdfmetrics.registerFont(TTFont("YaHeiBold", str(FONT_BOLD), subfontIndex=0))


def inline_markup(value: str) -> str:
    escaped = html.escape(value.strip())
    escaped = re.sub(r"\[([^\]]+)\]\([^\)]+\)", r"\1", escaped)
    escaped = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", escaped)
    escaped = re.sub(r"`([^`]+)`", r'<font color="#D92863">\1</font>', escaped)
    return escaped


def paragraph(value: str, style: ParagraphStyle) -> Paragraph:
    return Paragraph(inline_markup(value), style)


def parse_table(lines: list[str], styles: dict[str, ParagraphStyle]) -> Table:
    rows: list[list[str]] = []
    for line in lines:
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells):
            continue
        rows.append(cells)
    data = [
        [paragraph(cell, styles["table_header"] if index == 0 else styles["table_cell"]) for cell in row]
        for index, row in enumerate(rows)
    ]
    count = max(1, len(data[0]))
    available = A4[0] - 34 * mm
    if count == 2:
        widths = [available * 0.3, available * 0.7]
    else:
        widths = [available / count] * count
    table = Table(data, colWidths=widths, repeatRows=1, hAlign="LEFT")
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#F2F3F6")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.HexColor("#17181C")),
        ("GRID", (0, 0), (-1, -1), 0.45, colors.HexColor("#D8DAE0")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 7),
        ("RIGHTPADDING", (0, 0), (-1, -1), 7),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]))
    return table


def parse_markdown() -> list[object]:
    base = getSampleStyleSheet()
    styles: dict[str, ParagraphStyle] = {
        "title": ParagraphStyle(
            "TitleCN", parent=base["Title"], fontName="YaHeiBold", fontSize=25,
            leading=34, textColor=colors.HexColor("#17181C"), alignment=TA_CENTER,
            spaceAfter=18,
        ),
        "h2": ParagraphStyle(
            "H2CN", parent=base["Heading2"], fontName="YaHeiBold", fontSize=18,
            leading=25, textColor=colors.HexColor("#17181C"), spaceBefore=13, spaceAfter=9,
            keepWithNext=1,
        ),
        "h3": ParagraphStyle(
            "H3CN", parent=base["Heading3"], fontName="YaHeiBold", fontSize=13,
            leading=20, textColor=colors.HexColor("#D92863"), spaceBefore=9, spaceAfter=6,
            keepWithNext=1,
        ),
        "body": ParagraphStyle(
            "BodyCN", parent=base["BodyText"], fontName="YaHei", fontSize=9.3,
            leading=16, textColor=colors.HexColor("#30323A"), alignment=TA_LEFT,
            wordWrap="CJK", spaceAfter=5,
        ),
        "quote": ParagraphStyle(
            "QuoteCN", parent=base["BodyText"], fontName="YaHei", fontSize=9.2,
            leading=16, textColor=colors.HexColor("#5C606B"), backColor=colors.HexColor("#F3F4F7"),
            borderColor=colors.HexColor("#31C85A"), borderWidth=0, borderPadding=9,
            leftIndent=8, rightIndent=8, wordWrap="CJK", spaceAfter=8,
        ),
        "bullet": ParagraphStyle(
            "BulletCN", parent=base["BodyText"], fontName="YaHei", fontSize=9.2,
            leading=15, leftIndent=14, firstLineIndent=-8, bulletIndent=4,
            textColor=colors.HexColor("#30323A"), wordWrap="CJK", spaceAfter=3,
        ),
        "code": ParagraphStyle(
            "CodeCN", parent=base["Code"], fontName="YaHei", fontSize=8.2,
            leading=13, leftIndent=8, rightIndent=8, borderPadding=8,
            backColor=colors.HexColor("#F3F4F7"), textColor=colors.HexColor("#30323A"),
            wordWrap="CJK", spaceAfter=7,
        ),
        "table_header": ParagraphStyle(
            "TableHeaderCN", parent=base["BodyText"], fontName="YaHeiBold", fontSize=8.3,
            leading=13, textColor=colors.HexColor("#17181C"), wordWrap="CJK",
        ),
        "table_cell": ParagraphStyle(
            "TableCellCN", parent=base["BodyText"], fontName="YaHei", fontSize=8.0,
            leading=13, textColor=colors.HexColor("#30323A"), wordWrap="CJK",
        ),
    }

    lines = SOURCE.read_text(encoding="utf-8").splitlines()
    story: list[object] = []
    index = 0
    in_code = False
    code_lines: list[str] = []
    paragraph_lines: list[str] = []

    def flush_paragraph() -> None:
        if paragraph_lines:
            story.append(paragraph(" ".join(paragraph_lines), styles["body"]))
            paragraph_lines.clear()

    while index < len(lines):
        line = lines[index].rstrip()
        stripped = line.strip()
        if stripped.startswith("```"):
            flush_paragraph()
            if in_code:
                code_text = "<br/>".join(html.escape(item) if item else "&#160;" for item in code_lines)
                story.append(Paragraph(code_text, styles["code"]))
                code_lines.clear()
                in_code = False
            else:
                in_code = True
            index += 1
            continue
        if in_code:
            code_lines.append(line)
            index += 1
            continue
        if stripped == "<!-- pagebreak -->":
            flush_paragraph()
            story.append(CondPageBreak(235 * mm))
            index += 1
            continue
        if not stripped:
            flush_paragraph()
            story.append(Spacer(1, 2.5 * mm))
            index += 1
            continue
        if stripped.startswith("|") and stripped.endswith("|"):
            flush_paragraph()
            table_lines: list[str] = []
            while index < len(lines) and lines[index].strip().startswith("|"):
                table_lines.append(lines[index].strip())
                index += 1
            story.append(parse_table(table_lines, styles))
            story.append(Spacer(1, 3 * mm))
            continue
        image_match = re.fullmatch(r"!\[([^\]]*)\]\(([^\)]+)\)", stripped)
        if image_match:
            flush_paragraph()
            image_path = ROOT / image_match.group(2)
            picture = Image(str(image_path))
            scale = min(78 * mm / picture.imageWidth, 165 * mm / picture.imageHeight)
            picture.drawWidth = picture.imageWidth * scale
            picture.drawHeight = picture.imageHeight * scale
            picture.hAlign = "CENTER"
            story.append(picture)
            story.append(Spacer(1, 3 * mm))
            index += 1
            continue
        if stripped.startswith("# "):
            flush_paragraph()
            story.append(paragraph(stripped[2:], styles["title"]))
        elif stripped.startswith("## "):
            flush_paragraph()
            story.append(paragraph(stripped[3:], styles["h2"]))
        elif stripped.startswith("### "):
            flush_paragraph()
            story.append(paragraph(stripped[4:], styles["h3"]))
        elif stripped.startswith("> "):
            flush_paragraph()
            story.append(paragraph(stripped[2:], styles["quote"]))
        elif re.match(r"^[-*] ", stripped):
            flush_paragraph()
            story.append(Paragraph(inline_markup(stripped[2:]), styles["bullet"], bulletText="-"))
        elif re.match(r"^\d+\. ", stripped):
            flush_paragraph()
            match = re.match(r"^(\d+)\. (.+)$", stripped)
            assert match is not None
            story.append(Paragraph(inline_markup(match.group(2)), styles["bullet"], bulletText=f"{match.group(1)}."))
        else:
            paragraph_lines.append(stripped)
        index += 1
    flush_paragraph()
    return story


def draw_page(canvas, document) -> None:
    canvas.saveState()
    page = canvas.getPageNumber()
    canvas.setStrokeColor(colors.HexColor("#E1E2E7"))
    canvas.line(17 * mm, 14 * mm, A4[0] - 17 * mm, 14 * mm)
    canvas.setFont("YaHei", 7.5)
    canvas.setFillColor(colors.HexColor("#7B7F89"))
    canvas.drawString(17 * mm, 9 * mm, "番茄钟智能专注助手 - 项目说明文档")
    canvas.drawRightString(A4[0] - 17 * mm, 9 * mm, f"第 {page} 页")
    canvas.restoreState()


def main() -> None:
    register_fonts()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    document = SimpleDocTemplate(
        str(OUTPUT), pagesize=A4,
        rightMargin=17 * mm, leftMargin=17 * mm,
        topMargin=15 * mm, bottomMargin=19 * mm,
        title="番茄钟智能专注助手 - 项目说明文档",
        author="n0body-byte",
        subject="HarmonyOS ArkTS 课程项目说明",
    )
    document.build(parse_markdown(), onFirstPage=draw_page, onLaterPages=draw_page)
    print(OUTPUT)


if __name__ == "__main__":
    main()
