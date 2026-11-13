"""Assemble supplied report content and aggregate assets; never estimate results.

The compact document styles and editable-table layout are adapted from the
project-validated report assembler. Project content and asset counts are inputs.
"""
from __future__ import annotations

from datetime import datetime, timezone
import math
from pathlib import Path
import re

from docx import Document
from docx.enum.style import WD_STYLE_TYPE
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Mm, Pt, RGBColor


CONTENT_WIDTH = 210 / 25.4 - 1.5


def _font(font, size=None, bold=None):
    font.name = "Arial"
    font.color.rgb = RGBColor(0, 0, 0)
    if size is not None:
        font.size = Pt(size)
    if bold is not None:
        font.bold = bold


def _east_asian(element):
    rpr = element.get_or_add_rPr()
    rfonts = rpr.find(qn("w:rFonts"))
    if rfonts is None:
        rfonts = OxmlElement("w:rFonts")
        rpr.insert(0, rfonts)
    for attr, value in (("ascii", "Arial"), ("hAnsi", "Arial"),
                        ("eastAsia", "SimSun"), ("cs", "Arial")):
        rfonts.set(qn("w:" + attr), value)
    for attr in ("asciiTheme", "hAnsiTheme", "eastAsiaTheme", "cstheme"):
        rfonts.attrib.pop(qn("w:" + attr), None)


def _style(doc, name, size, bold=False, after=5, before=0):
    style = (doc.styles[name] if name in doc.styles
             else doc.styles.add_style(name, WD_STYLE_TYPE.PARAGRAPH))
    _font(style.font, size, bold)
    _east_asian(style.element)
    fmt = style.paragraph_format
    fmt.space_before, fmt.space_after = Pt(before), Pt(after)
    fmt.line_spacing = 1.25
    fmt.widow_control = True
    return style


def _inline(paragraph, text, size=None):
    """Support optional bold/code emphasis without altering other supplied text."""
    for piece in re.split(r"(\*\*[^*]+\*\*|`[^`]+`)", text):
        if not piece:
            continue
        bold = piece.startswith("**") and piece.endswith("**")
        if bold:
            piece = piece[2:-2]
        elif piece.startswith("`") and piece.endswith("`"):
            piece = piece[1:-1]
        run = paragraph.add_run(piece)
        _font(run.font, size, True if bold else None)
        _east_asian(run._element)


def _page_field(paragraph):
    run = paragraph.add_run()
    for tag, attributes, text in (
        ("w:fldChar", {"w:fldCharType": "begin"}, None),
        ("w:instrText", {"xml:space": "preserve"}, " PAGE "),
        ("w:fldChar", {"w:fldCharType": "separate"}, None),
        ("w:t", {}, "1"),
        ("w:fldChar", {"w:fldCharType": "end"}, None),
    ):
        node = OxmlElement(tag)
        for key, value in attributes.items():
            node.set(qn(key), value)
        node.text = text
        run._r.append(node)
    _font(run.font, 9)
    _east_asian(run._element)


def _configure(doc, title, language):
    section = doc.sections[0]
    section.page_width, section.page_height = Mm(210), Mm(297)
    section.top_margin = section.bottom_margin = Inches(.72)
    section.left_margin = section.right_margin = Inches(.75)
    section.header_distance = section.footer_distance = Inches(.30)
    _style(doc, "Normal", 11, after=6)
    _style(doc, "Title", 19, True, after=8)
    for name, size, before in (("Heading 1", 14, 13), ("Heading 2", 12, 10)):
        style = _style(doc, name, size, True, after=6, before=before)
        style.paragraph_format.keep_with_next = True
        style.paragraph_format.keep_together = True
    _style(doc, "Caption", 9.5, after=7).paragraph_format.line_spacing = 1.15
    _style(doc, "Table Note", 9, after=8).paragraph_format.line_spacing = 1.15
    _style(doc, "Report Table", 9.3, after=0).paragraph_format.line_spacing = 1.05
    _style(doc, "Footer", 9, after=0)
    footer = section.footer.paragraphs[0]
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    if language == "zh-CN":
        _inline(footer, "第 ", 9)
    _page_field(footer)
    if language == "zh-CN":
        _inline(footer, " 页", 9)
    update = OxmlElement("w:updateFields")
    update.set(qn("w:val"), "true")
    doc.settings.element.append(update)
    props = doc.core_properties
    props.title, props.subject = title, "Methods Results Next Steps"
    props.author = props.last_modified_by = props.keywords = props.comments = ""
    props.created = props.modified = datetime.now(timezone.utc)
    # Remove the base template's decorative title border without changing text.
    for border in doc.styles.element.xpath(".//w:pBdr"):
        border.getparent().remove(border)


def _column_widths(block):
    count = len(block["headers"])
    if "column_widths" in block:
        widths = block["column_widths"]
        if (len(widths) != count or any(isinstance(w, bool) or
                not isinstance(w, (int, float)) or not math.isfinite(w) or w <= 0
                for w in widths) or sum(widths) > CONTENT_WIDTH + .001):
            raise ValueError("Table widths must be positive, match columns and fit the page")
        return widths
    if count == 1:
        return [CONTENT_WIDTH]
    # A wide first label column and equal data columns; callers may override.
    first = min(2.7, CONTENT_WIDTH * .40)
    return [first] + [(CONTENT_WIDTH - first) / (count - 1)] * (count - 1)


def _table_style(table, widths):
    table.autofit = False
    properties = table._tbl.tblPr
    borders = OxmlElement("w:tblBorders")
    for side in ("top", "left", "bottom", "right", "insideH", "insideV"):
        edge = OxmlElement("w:" + side)
        for key, value in (("val", "single"), ("sz", "4"), ("color", "D9D9D9")):
            edge.set(qn("w:" + key), value)
        borders.append(edge)
    properties.append(borders)
    margins = OxmlElement("w:tblCellMar")
    for side, value in (("top", "55"), ("bottom", "55"), ("left", "75"), ("right", "75")):
        margin = OxmlElement("w:" + side)
        margin.set(qn("w:w"), value)
        margin.set(qn("w:type"), "dxa")
        margins.append(margin)
    properties.append(margins)
    for column, width in zip(table.columns, widths, strict=True):
        column.width = Inches(width)
    for i, row in enumerate(table.rows):
        row._tr.get_or_add_trPr().append(OxmlElement("w:cantSplit"))
        if i == 0:
            row._tr.get_or_add_trPr().append(OxmlElement("w:tblHeader"))
        for j, cell in enumerate(row.cells):
            cell.width = Inches(widths[j])
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            shade = OxmlElement("w:shd")
            shade.set(qn("w:fill"), "E6EEF7" if i == 0 else "FFFFFF")
            cell._tc.get_or_add_tcPr().append(shade)
            for paragraph in cell.paragraphs:
                paragraph.style = "Report Table"
                paragraph.alignment = (WD_ALIGN_PARAGRAPH.LEFT if j == 0
                                       else WD_ALIGN_PARAGRAPH.CENTER)
                paragraph.paragraph_format.keep_with_next = i == 0
                for run in paragraph.runs:
                    _font(run.font, 9.3, i == 0)
                    _east_asian(run._element)


def _add_table(doc, block):
    caption = doc.add_paragraph(style="Caption")
    caption.paragraph_format.keep_with_next = True
    _inline(caption, block["caption"], 10)
    rows = [block["headers"], *block["rows"]]
    table = doc.add_table(rows=len(rows), cols=len(rows[0]))
    for i, row in enumerate(rows):
        for j, value in enumerate(row):
            table.cell(i, j).text = value
    _table_style(table, _column_widths(block))
    # Keep the last row with a note; allow natural breaks between earlier rows.
    if block.get("note"):
        for cell in table.rows[-1].cells:
            for paragraph in cell.paragraphs:
                paragraph.paragraph_format.keep_with_next = True
        note = doc.add_paragraph(style="Table Note")
        note.paragraph_format.keep_together = True
        _inline(note, block["note"], 9)


def _add_figure(doc, block):
    paragraph = doc.add_paragraph()
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    paragraph.paragraph_format.space_after = Pt(4)
    paragraph.paragraph_format.keep_with_next = True
    paragraph.paragraph_format.keep_together = True
    shape = paragraph.add_run().add_picture(
        str(block["path"]), width=Inches(block.get("width_inches", 6.72)))
    shape._inline.docPr.set("descr", block["caption"])
    caption = doc.add_paragraph(style="Caption")
    caption.paragraph_format.keep_together = True
    _inline(caption, block["caption"], 9.5)


def _validate(report):
    if not isinstance(report.get("title"), str) or not report["title"].strip():
        raise ValueError("A nonempty report title is required")
    if report.get("language", "en") not in {"en", "zh-CN"}:
        raise ValueError("Supported report languages are en and zh-CN")
    if not isinstance(report.get("sections"), list) or len(report["sections"]) != 3:
        raise ValueError("Provide exactly three report sections")
    counts = {"table": 0, "figure": 0}
    for section in report["sections"]:
        if not isinstance(section.get("title"), str) or not section["title"].strip():
            raise ValueError("Each section needs a title")
        if not isinstance(section.get("blocks"), list):
            raise ValueError("Each section needs an explicit block list")
        for block in section["blocks"]:
            kind = block.get("type")
            if kind in {"paragraph", "heading"}:
                if not isinstance(block.get("text"), str) or not block["text"].strip():
                    raise ValueError("Text blocks must contain nonempty text")
            elif kind == "table":
                headers, rows = block.get("headers"), block.get("rows")
                if (not isinstance(headers, list) or not headers
                        or not all(isinstance(h, str) and h for h in headers)
                        or not isinstance(rows, list)
                        or any(not isinstance(r, list) or len(r) != len(headers)
                               or not all(isinstance(c, str) for c in r) for r in rows)):
                    raise ValueError("Tables require string headers and rectangular string rows")
                _column_widths(block)
                counts[kind] += 1
            elif kind == "figure":
                if not Path(block["path"]).is_file():
                    raise FileNotFoundError(block["path"])
                width = block.get("width_inches", 6.72)
                if (isinstance(width, bool) or not isinstance(width, (int, float))
                        or not math.isfinite(width) or not 0 < width <= CONTENT_WIDTH):
                    raise ValueError("Figure width must be positive and fit the page")
                counts[kind] += 1
            else:
                raise ValueError(f"Unknown report block type: {kind}")
            if kind in counts:
                if not isinstance(block.get("caption"), str) or not block["caption"].strip():
                    raise ValueError("Tables and figures require a supplied caption")
                if not isinstance(block.get("note", ""), str):
                    raise ValueError("A table note must be text")
    return counts


def build_word(report: dict, output: Path) -> Path:
    """Create a new DOCX with exactly the supplied content; refuse overwrites.

    Structural verification is performed here. Actual rendered-page review remains
    necessary; text or XML checks cannot prove that a document fits its pages.
    """
    output = Path(output)
    if output.suffix.lower() != ".docx":
        raise ValueError("Word output must use the .docx suffix")
    if output.exists():
        raise FileExistsError(f"Refusing to overwrite an existing report: {output}")
    counts = _validate(report)
    doc = Document()
    _configure(doc, report["title"], report.get("language", "en"))
    _inline(doc.add_paragraph(style="Title"), report["title"])
    for section in report["sections"]:
        _inline(doc.add_paragraph(style="Heading 1"), section["title"])
        for block in section["blocks"]:
            kind = block["type"]
            if kind in {"paragraph", "heading"}:
                style = "Normal" if kind == "paragraph" else "Heading 2"
                _inline(doc.add_paragraph(style=style), block["text"])
            elif kind == "table":
                _add_table(doc, block)
            else:
                _add_figure(doc, block)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("xb") as stream:
        doc.save(stream)
    check = Document(output)
    if len(check.tables) != counts["table"] or len(check.inline_shapes) != counts["figure"]:
        raise AssertionError("Embedded figure or editable table count differs from the input")
    return output
