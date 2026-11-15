"""Optional Word-only output, independent of the statistical runtime."""
from __future__ import annotations

import hashlib
import json
import shutil
import tempfile
import zipfile
from pathlib import Path

from .inputs import prepare_report, read_config, sha256


def validate_docx(path, report):
    from docx import Document
    from lxml import etree
    document = Document(path)
    headings = [p.text for p in document.paragraphs if p.style.name == "Heading 1"]
    if headings != [section["title"] for section in report["sections"]]:
        raise ValueError("Word section headings do not match the report contract")
    blocks = [block for section in report["sections"] for block in section["blocks"]]
    tables = [block for block in blocks if block["type"] == "table"]
    figures = [block for block in blocks if block["type"] == "figure"]
    if len(document.tables) != len(tables) or len(document.inline_shapes) != len(figures):
        raise ValueError("Word asset counts do not match the supplied assets")
    for table, expected in zip(document.tables, tables):
        if [[cell.text for cell in row.cells] for row in table.rows] != [expected["headers"], *expected["rows"]]:
            raise ValueError("Word table cells differ from the input aggregate cells")
        if not table.rows[0]._tr.xpath(".//w:tblHeader"):
            raise ValueError("Word table has no repeating header")
    with zipfile.ZipFile(path) as package:
        xml = package.read("word/document.xml")
        root = etree.fromstring(xml)
        ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
        if root.xpath("//w:ins|//w:del|//w:moveFrom|//w:moveTo|//w:commentReference", namespaces=ns):
            raise ValueError("Generated report contains revisions or comments")
        if any("comments" in name.lower() for name in package.namelist()):
            raise ValueError("Generated report contains a comments part")
        if b'TargetMode="External"' in package.read("word/_rels/document.xml.rels"):
            raise ValueError("Word report contains an external relationship")
        media = {hashlib.sha256(package.read(name)).hexdigest() for name in package.namelist()
                 if name.startswith("word/media/")}
        if media != {sha256(figure["path"]) for figure in figures}:
            raise ValueError("Embedded figure bytes differ from the supplied images")
    return {"document_xml_sha256": hashlib.sha256(xml).hexdigest(),
            "tables": len(tables), "figures": len(figures), "sections": headings}


def run(config_path, output=None, internal_dir=None, enable=False):
    config_path = Path(config_path).resolve(strict=True)
    config = read_config(config_path)
    if not (config.get("report_enabled", False) or enable):
        return {"status": "REPORT_DISABLED"}
    if output is None or internal_dir is None:
        raise ValueError("Enabled reporting needs --output and a separate --internal-dir")
    output = Path(output).resolve()
    internal_dir = Path(internal_dir).resolve()
    if output.suffix.lower() != ".docx":
        raise ValueError("The user deliverable must be a DOCX file")
    if internal_dir == output.parent or internal_dir in output.parents:
        raise ValueError("Keep the deliverable outside the internal validation directory")
    report, bindings = prepare_report(config_path)
    if any(output == Path(binding["path"]) for binding in bindings):
        raise ValueError("Output cannot replace an input")
    code_files = sorted(Path(__file__).parent.glob("*.py"))
    code_bindings = {path.name: sha256(path) for path in code_files}
    fingerprint = hashlib.sha256(json.dumps({"inputs": bindings, "code": code_bindings},
                                             sort_keys=True).encode()).hexdigest()
    state_path = internal_dir / (hashlib.sha256(str(output).encode()).hexdigest()[:16] + ".json")
    if output.exists():
        if not state_path.exists():
            raise ValueError("Existing Word is protected; choose a new output filename")
        state = json.loads(state_path.read_text(encoding="utf-8"))
        if state["output_sha256"] != sha256(output):
            raise ValueError("Word contains subsequent edits; preserve them and review before creating a new version")
        if state["input_fingerprint"] != fingerprint:
            raise ValueError("Inputs or reporting code changed; review and select a new Word version")
        validate_docx(output, report)
        return {"status": "REPORT_UNCHANGED", "output": str(output)}

    from .assemble_docx import build_word
    internal_dir.mkdir(parents=True, exist_ok=True)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="word-assembly-", dir=internal_dir) as temporary:
        candidate = Path(temporary) / "report.docx"
        build_word(report, candidate)
        checks = validate_docx(candidate, report)
        for binding in bindings:
            if sha256(binding["path"]) != binding["sha256"]:
                raise ValueError("Source changed during report generation; no report adopted")
        # Exclusive creation protects the author's original and any concurrent edit.
        with output.open("xb") as target, candidate.open("rb") as source:
            shutil.copyfileobj(source, target)
    state = {"output_sha256": sha256(output), "input_fingerprint": fingerprint,
             "inputs": bindings, "reporting_code_sha256": code_bindings, "checks": checks,
             "statistical_execution": "NOT_CALLED", "render_and_visual_review": "NOT_EXECUTED_BY_ASSEMBLER"}
    state_path.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return {"status": "REPORT_CREATED", "output": str(output)}
