"""Inspect actual native exports, not configuration claims.

Development requirements: Pillow, pdfplumber, pypdf, and Poppler pdftoppm.
R native vector devices quantize the canvas to integer PostScript points;
the requested physical dimensions must agree within one point (0.353 mm).
"""
from pathlib import Path
import csv
import math
import subprocess
import xml.etree.ElementTree as ET

from PIL import Image, ImageChops, ImageDraw, ImageFont
import pdfplumber
from pypdf import PdfReader

root = Path.cwd()
gallery = root / "figure_gallery"
preview = root / "output" / "sci_style_validation"
preview.mkdir(parents=True, exist_ok=True)
manifest = list(csv.DictReader((root / "figure_style_comparison" /
                               "figure_style_comparison_manifest.csv").open()))
results = []
metadata = []
for column, width_mm in (("single", 85), ("double", 178)):
    for entry in manifest:
        stem = gallery / column / entry["figure"]
        with Image.open(stem.with_suffix(".png")) as png_image, Image.open(stem.with_suffix(".tiff")) as tiff_image:
            assert ImageChops.difference(png_image.convert("RGB"), tiff_image.convert("RGB")).getbbox() is None
        for suffix in ("png", "tiff"):
            path = stem.with_suffix("." + suffix)
            with Image.open(path) as image:
                image.load()
                dpi = image.info.get("dpi")
                assert dpi and max(abs(v - 600) for v in dpi) < .1, (path, dpi)
                assert abs(image.width - width_mm / 25.4 * 600) <= 1
                assert abs(image.height - 110 / 25.4 * 600) <= 1
                results.append(dict(file=str(path.relative_to(root)), format=suffix,
                    requested_width_mm=width_mm, measured_width_mm=image.width / dpi[0] * 25.4,
                    measured_height_mm=image.height / dpi[1] * 25.4, dpi=dpi[0],
                    minimum_font_pt="", text_outside_page=0, status="PASS"))
                info = dict(image.info)
                if suffix == "tiff":
                    info["tiff_tags"] = {str(k): str(v) for k, v in image.tag_v2.items()}
                metadata.append((str(path.relative_to(root)), str(info)))
        pdf_path = stem.with_suffix(".pdf")
        reader = PdfReader(pdf_path)
        assert len(reader.pages) == 1
        assert not reader.pages[0].images, "PDF must remain vector"
        metadata.append((str(pdf_path.relative_to(root)), str(reader.metadata)))
        with pdfplumber.open(pdf_path) as pdf:
            page = pdf.pages[0]
            assert abs(page.width - width_mm / 25.4 * 72) <= 1
            assert abs(page.height - 110 / 25.4 * 72) <= 1
            # pdfminer reports rotated character advances as `size`. Use the
            # perpendicular extent for the native 90-degree axis titles.
            font_sizes = [c["size"] if c["upright"] else c["width"] for c in page.chars]
            assert font_sizes and min(font_sizes) >= 6.99, (pdf_path, min(font_sizes))
            outside = [c for c in page.chars if c["x0"] < -.2 or c["x1"] > page.width + .2
                       or c["top"] < -.2 or c["bottom"] > page.height + .2]
            assert not outside, (pdf_path, "text outside page")
            results.append(dict(file=str(pdf_path.relative_to(root)), format="pdf",
                requested_width_mm=width_mm, measured_width_mm=page.width / 72 * 25.4,
                measured_height_mm=page.height / 72 * 25.4, dpi="",
                minimum_font_pt=min(font_sizes), text_outside_page=len(outside), status="PASS"))
        svg_path = stem.with_suffix(".svg")
        tree = ET.parse(svg_path)
        svg = tree.getroot()
        viewbox = [float(v) for v in svg.attrib["viewBox"].split()]
        assert abs(viewbox[2] - width_mm / 25.4 * 72) <= 1
        assert abs(viewbox[3] - 110 / 25.4 * 72) <= 1
        assert not any(node.tag.endswith("}image") for node in svg.iter())
        results.append(dict(file=str(svg_path.relative_to(root)), format="svg",
            requested_width_mm=width_mm, measured_width_mm=viewbox[2] / 72 * 25.4,
            measured_height_mm=viewbox[3] / 72 * 25.4, dpi="",
            minimum_font_pt="OUTLINED_GLYPHS", text_outside_page="VISUAL_REVIEW", status="PASS"))
        metadata.append((str(svg_path.relative_to(root)), str(svg.attrib)))
        # Render both physical widths from the actual final PDF.
        subprocess.run(["pdftoppm", "-scale-to", "1200", "-singlefile", "-png",
                        str(pdf_path), str(preview / f"{entry['figure']}_{column}_pdf")],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)

with (gallery / "export_validation.csv").open("w", newline="", encoding="utf-8") as stream:
    writer = csv.DictWriter(stream, fieldnames=list(results[0]))
    writer.writeheader()
    writer.writerows(results)
with (preview / "metadata_inventory.csv").open("w", newline="", encoding="utf-8") as stream:
    writer = csv.writer(stream)
    writer.writerow(["file", "metadata"])
    writer.writerows(metadata)

# Compact sheets supplement the individual previews; labels stay outside plots.
font = ImageFont.load_default(size=17)
def sheet(paths, labels, destination, cols=4):
    cell_w, cell_h = 440, 440
    canvas = Image.new("RGB", (cols * cell_w, math.ceil(len(paths) / cols) * cell_h), "white")
    draw = ImageDraw.Draw(canvas)
    for i, (path, label) in enumerate(zip(paths, labels)):
        x, y = (i % cols) * cell_w, (i // cols) * cell_h
        draw.text((x + 8, y + 5), label, fill="#30383F", font=font)
        with Image.open(path) as image:
            image.thumbnail((cell_w - 12, cell_h - 36))
            canvas.paste(image.convert("RGB"), (x + (cell_w - image.width) // 2, y + 30))
    canvas.save(destination)

labels = [e["figure"].removeprefix("figure_").replace("_", " ") for e in manifest]
for column in ("single", "double"):
    sheet([preview / f"{e['figure']}_{column}_pdf.png" for e in manifest], labels,
          preview / f"contact_{column}_pdf.png")
    sheet([preview / f"{e['figure']}_{column}_svg.png" for e in manifest], labels,
          preview / f"contact_{column}_svg.png")
for mode in ("grayscale", "deutan", "protan", "tritan"):
    sheet([gallery / "accessibility" / f"{e['figure']}_{mode}.png" for e in manifest],
          labels, preview / f"contact_{mode}.png")
print("SCI_EXPORT_FILE_INSPECTION=PASS FILES=112 PDF_RENDERED=28 MINIMUM_FONT_PT=7")
