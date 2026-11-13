"""Reporting-only contracts using aggregate synthetic fixtures; no model fits."""
from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

from docx import Document
from lxml import etree
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from reporting.inputs import prepare_report
from reporting.workflow import run
from reporting.author_word import clean_word, inspect_word


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def document_text(path):
    document = Document(path)
    return "\n".join(
        [p.text for p in document.paragraphs]
        + [c.text for t in document.tables for row in t.rows for c in row.cells]
    )


class WordReportingContracts(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.config_path = self.directory / "report.json"
        self.output = self.directory / "delivery" / "analysis.docx"
        self.internal = self.directory / "checks"
        self.config = {
            "report_enabled": True,
            "report_format": "docx",
            "report_template": "methods_results_next_steps",
            "data_classification": "SYNTHETIC_CONFIRMED",
            "title": "Synthetic analysis report",
            "language": "en",
            "study": {
                "design": "Synthetic continuous outcome comparison.",
                "population": "Synthetic units from a saved aggregate fixture.",
                "models": "The existing pooled model is read without refitting.",
                "adjustment": "The prespecified covariates x and z.",
            },
            "methods": [{"type": "paragraph", "text": "Use the original outcome units."}],
            "results": [{"type": "paragraph", "text": "The supplied synthetic description has no additional estimates."}],
            "next_steps": [{"type": "paragraph", "text": "Review the supplied aggregate."}],
        }

    def save(self):
        self.config_path.write_text(json.dumps(self.config), encoding="utf-8")

    def csv_file(self, name, header, rows):
        path = self.directory / name
        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(header)
            writer.writerows(rows)
        return path

    def create(self, **kwargs):
        self.save()
        return run(self.config_path, self.output, self.internal, **kwargs)

    def effect_block(self, path, **kwargs):
        return {
            "type": "effects", "path": str(path),
            "caption": "Table 1. Supplied estimates", "decimals": 4,
            "interval_label": "95% interval", **kwargs,
        }

    def test_disabled_cli_needs_no_optional_packages_or_assets(self):
        self.config = {"report_enabled": False}
        self.save()
        completed = subprocess.run(
            [sys.executable, "-S", str(ROOT / "runtime/render_report.py"),
             "--config", str(self.config_path)],
            cwd=self.directory, capture_output=True, text=True,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertIn("REPORT_DISABLED", completed.stdout)
        self.assertEqual(list(self.directory.iterdir()), [self.config_path])

    def test_default_is_disabled(self):
        self.config = {}
        result = self.create()
        self.assertEqual(result["status"], "REPORT_DISABLED")
        self.assertFalse(self.output.exists())
        self.assertFalse(self.internal.exists())

    def test_explicit_enable_reads_existing_continuous_fixture(self):
        self.config["report_enabled"] = False
        source = ROOT / "validation/fixtures/mi_effects.csv"
        before = digest(source)
        self.config["results"] = [self.effect_block(source)]
        result = self.create(enable=True)
        self.assertEqual(result["status"], "REPORT_CREATED")
        text = document_text(self.output)
        for expected in ["mean_difference", "0.5437", "0.0967", "0.3535", "0.7339"]:
            self.assertIn(expected, text)
        self.assertEqual(digest(source), before)
        self.assertEqual(len(Document(self.output).inline_shapes), 0)
        self.assertEqual(list(self.output.parent.iterdir()), [self.output])

    def test_actual_primary_effects_schema_is_supported(self):
        source = ROOT / "examples/quick_start/expected/tables_primary_effects.csv"
        self.config["results"] = [self.effect_block(source)]
        self.create()
        text = document_text(self.output)
        for expected in ["RD", "RR", "0.1493", "1.7849", "0.0730", "2.4332"]:
            self.assertIn(expected, text)

    def test_multiple_analyses_keep_their_labels(self):
        source = self.csv_file("analyses.csv", ["analysis", "effect", "estimate"],
                               [["primary", "RD", "0.1"], ["prespecified_sensitivity", "RD", "0.09"]])
        self.config["results"] = [self.effect_block(source)]
        self.create()
        text = document_text(self.output)
        self.assertIn("primary", text)
        self.assertIn("prespecified_sensitivity", text)

    def test_missing_uncertainty_is_not_calculated(self):
        source = self.csv_file("point.csv", ["effect", "estimate", "se"],
                               [["mean_difference", "1.5", "0.2"]])
        self.config["results"] = [self.effect_block(source)]
        self.config["results"][0].pop("interval_label")
        self.create()
        text = document_text(self.output)
        self.assertIn("1.5000", text)
        self.assertNotIn("1.108", text)
        self.assertNotIn("1.892", text)
        self.assertNotIn("95%", text)
        self.assertEqual(len(Document(self.output).inline_shapes), 0)

    def test_half_interval_is_rejected(self):
        source = self.csv_file("partial.csv", ["effect", "estimate", "conf_low"],
                               [["mean_difference", "1.5", "1.1"]])
        self.config["results"] = [self.effect_block(source)]
        with self.assertRaises(ValueError):
            self.create()
        self.assertFalse(self.output.exists())

    def test_supplied_interval_needs_explicit_description(self):
        self.config["results"] = [self.effect_block(ROOT / "validation/fixtures/mi_effects.csv")]
        self.config["results"][0].pop("interval_label")
        with self.assertRaises(ValueError):
            self.create()

    def test_inverted_and_nonfinite_results_are_rejected(self):
        for name, estimate, lower, upper in [
            ("inverted", "1.5", "2", "1"),
            ("nonfinite", "Inf", "1", "2"),
        ]:
            with self.subTest(case=name):
                source = self.csv_file(name + ".csv", ["effect", "estimate", "conf_low", "conf_high"],
                                       [["mean_difference", estimate, lower, upper]])
                self.config["results"] = [self.effect_block(source)]
                with self.assertRaises(ValueError):
                    self.create()

    def test_supplied_percentile_interval_need_not_enclose_point(self):
        source = self.csv_file("percentile.csv", ["effect", "estimate", "conf_low", "conf_high"],
                               [["difference", "1.5", "1.6", "2.0"]])
        self.config["results"] = [self.effect_block(source, interval_label="95% percentile interval")]
        self.create()
        self.assertIn("1.6000", document_text(self.output))

    def test_real_image_and_editable_table_are_embedded(self):
        source = self.csv_file("summary.csv", ["Group", "N", "Missing"],
                               [["A", "24", "2"], ["B", "31", "3"]])
        picture = self.directory / "figure.png"
        Image.new("RGB", (360, 180), color="white").save(picture)
        self.config["results"] = [
            {"type": "table", "path": source.name, "caption": "Table 1. Synthetic counts",
             "columns": [{"key": c, "label": c} for c in ["Group", "N", "Missing"]],
             "note": "Missing values remain missing."},
            {"type": "figure", "path": picture.name,
             "caption": "Figure 1. Supplied synthetic image", "width_inches": 4.0},
        ]
        self.create()
        document = Document(self.output)
        self.assertEqual(len(document.tables), 1)
        self.assertEqual(len(document.inline_shapes), 1)
        self.assertEqual([[c.text for c in r.cells] for r in document.tables[0].rows],
                         [["Group", "N", "Missing"], ["A", "24", "2"], ["B", "31", "3"]])
        self.assertTrue(document.tables[0].rows[0]._tr.xpath(".//w:tblHeader"))
        with zipfile.ZipFile(self.output) as archive:
            media = [archive.read(n) for n in archive.namelist() if n.startswith("word/media/")]
            self.assertEqual(media, [picture.read_bytes()])
            self.assertNotIn(b'TargetMode="External"', archive.read("word/_rels/document.xml.rels"))

    def test_missing_declared_figure_does_not_make_placeholder(self):
        self.config["results"] = [{"type": "figure", "path": "absent.png", "caption": "Figure 1"}]
        with self.assertRaises((ValueError, FileNotFoundError)):
            self.create()
        self.assertFalse(self.output.exists())

    def test_patient_identifiers_rejected_even_if_not_selected(self):
        source = self.csv_file("unsafe.csv", ["subject_id", "N"], [["SYN001", "10"]])
        self.config["results"] = [{"type": "table", "path": source.name, "caption": "Table 1",
                                   "columns": [{"key": "N", "label": "Count"}]}]
        with self.assertRaises(ValueError):
            self.create()

    def test_classification_required_and_local_paths_not_printed(self):
        self.config.pop("data_classification")
        with self.assertRaises(ValueError):
            self.create()
        self.config["data_classification"] = "AGGREGATE_ONLY_CONFIRMED"
        self.config["methods"] = [{"type": "paragraph", "text": "Source " + "Q" + ":/private/input.csv"}]
        with self.assertRaises(ValueError):
            self.create()

    def test_frozen_asset_hash_mismatch_stops_without_output(self):
        self.config["results"] = [self.effect_block(ROOT / "validation/fixtures/mi_effects.csv", sha256="0" * 64)]
        with self.assertRaises(ValueError):
            self.create()
        self.assertFalse(self.output.exists())

    def test_exact_three_sections_without_optional_science_fields(self):
        self.config["study"] = {"design": "Synthetic description.", "population": "Synthetic units."}
        self.create()
        document = Document(self.output)
        headings = [p.text for p in document.paragraphs if p.style.name == "Heading 1"]
        self.assertEqual(len(headings), 3)
        self.assertTrue(headings[0].endswith("Methods"))
        self.assertTrue(headings[1].endswith("Results"))
        self.assertTrue(headings[2].endswith("Next Steps"))
        text = document_text(self.output)
        self.assertNotIn("Conclusion", text)
        self.assertNotIn("Discussion", text)
        self.assertNotIn(str(self.directory), text)

    def test_repeat_is_unchanged_and_author_edits_not_overwritten(self):
        self.create()
        before = self.output.read_bytes()
        repeated = run(self.config_path, self.output, self.internal)
        self.assertEqual(repeated["status"], "REPORT_UNCHANGED")
        self.assertEqual(before, self.output.read_bytes())
        document = Document(self.output)
        document.paragraphs[1].text = "Author retained wording."
        document.save(self.output)
        authored = self.output.read_bytes()
        with self.assertRaises(ValueError):
            run(self.config_path, self.output, self.internal)
        self.assertEqual(authored, self.output.read_bytes())

    def test_existing_untracked_output_is_not_overwritten(self):
        self.output.parent.mkdir()
        self.output.write_bytes(b"author-owned file")
        with self.assertRaises(ValueError):
            self.create()
        self.assertEqual(self.output.read_bytes(), b"author-owned file")

    def test_changed_source_does_not_overwrite_previous_report(self):
        source = self.csv_file("point.csv", ["effect", "estimate"], [["difference", "1.5"]])
        self.config["results"] = [self.effect_block(source)]
        self.create()
        before = self.output.read_bytes()
        self.csv_file("point.csv", ["effect", "estimate"], [["difference", "2.5"]])
        with self.assertRaises(ValueError):
            run(self.config_path, self.output, self.internal)
        self.assertEqual(before, self.output.read_bytes())

    def test_author_reference_bound_to_actual_bytes(self):
        reference = self.directory / "author.docx"
        document = Document()
        document.add_paragraph("Retained author wording.")
        document.save(reference)
        self.config["author_reference"] = {
            "path": reference.name, "sha256": "0" * 64, "wording_reviewed": True,
        }
        with self.assertRaises(ValueError):
            self.create()
        self.config["author_reference"]["sha256"] = digest(reference)
        result = self.create()
        self.assertEqual(result["status"], "REPORT_CREATED")

    def test_author_identity_alone_does_not_declare_wording_alignment(self):
        reference = self.directory / "author.docx"
        document = Document()
        document.add_paragraph("Retained author wording.")
        document.save(reference)
        self.config["author_reference"] = {"path": reference.name, "sha256": digest(reference)}
        for supplied_value in [None, False, "true", 1]:
            with self.subTest(wording_reviewed=supplied_value):
                if supplied_value is not None:
                    self.config["author_reference"]["wording_reviewed"] = supplied_value
                with self.assertRaisesRegex(ValueError, "wording_reviewed"):
                    self.create()
                self.assertFalse(self.output.exists())

    def test_author_insertions_and_deletions_read_without_changing_source(self):
        original = self.directory / "base.docx"
        document = Document()
        document.add_paragraph("Retained sentence.")
        document.save(original)
        reference = self.directory / "revised.docx"
        namespace = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
        with zipfile.ZipFile(original) as source:
            root = etree.fromstring(source.read("word/document.xml"))
            paragraph = root.find(".//{%s}p" % namespace)
            for name, text_tag, text in [
                ("del", "delText", "Delete this old wording."),
                ("ins", "t", "Use this author wording."),
            ]:
                revision = etree.SubElement(paragraph, "{%s}%s" % (namespace, name))
                run_node = etree.SubElement(revision, "{%s}r" % namespace)
                etree.SubElement(run_node, "{%s}%s" % (namespace, text_tag)).text = text
            with zipfile.ZipFile(reference, "w") as target:
                for member in source.infolist():
                    target.writestr(member, etree.tostring(root) if member.filename == "word/document.xml"
                                    else source.read(member.filename))
        before = digest(reference)
        info = inspect_word(reference)
        self.assertEqual(info["revision_counts"]["del"], 1)
        self.assertEqual(info["revision_counts"]["ins"], 1)
        self.assertIn("Use this author wording.", info["accepted_text"])
        self.assertNotIn("Delete this old wording.", info["accepted_text"])
        cleaned = self.directory / "clean.docx"
        clean_word(reference, cleaned)
        self.assertEqual(digest(reference), before)
        self.assertIn("Use this author wording.", document_text(cleaned))
        self.assertNotIn("Delete this old wording.", document_text(cleaned))
        self.assertEqual(inspect_word(cleaned)["revision_counts"], {})

    def test_orphan_author_comment_markup_requires_review(self):
        original = self.directory / "base.docx"
        document = Document()
        document.add_paragraph("Author text.")
        document.save(original)
        reference = self.directory / "commented.docx"
        namespace = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
        with zipfile.ZipFile(original) as source, zipfile.ZipFile(reference, "w") as target:
            root = etree.fromstring(source.read("word/document.xml"))
            paragraph = root.find(".//{%s}p" % namespace)
            marker = etree.SubElement(paragraph, "{%s}commentRangeStart" % namespace)
            marker.set("{%s}id" % namespace, "1")
            for member in source.infolist():
                target.writestr(member, etree.tostring(root) if member.filename == "word/document.xml"
                                else source.read(member.filename))
        before = digest(reference)
        self.config["author_reference"] = {
            "path": reference.name, "sha256": before, "wording_reviewed": True,
        }
        with self.assertRaises(ValueError):
            self.create()
        self.assertEqual(digest(reference), before)
        self.assertFalse(self.output.exists())

    def test_source_bindings_include_config_and_actual_assets(self):
        source = ROOT / "validation/fixtures/mi_effects.csv"
        self.config["results"] = [self.effect_block(source)]
        self.save()
        _, bindings = prepare_report(self.config_path)
        self.assertIn(digest(source), [b["sha256"] for b in bindings])
        self.assertIn(digest(self.config_path), [b["sha256"] for b in bindings])


if __name__ == "__main__":
    unittest.main()
