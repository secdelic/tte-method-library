"""Synthetic project isolation, lifecycle and optional Word integration tests.

Set TTE_RUN_WORKSPACE_INTEGRATION=1 for real R executions. Point
TTE_REPORTING_LIBRARY at the pinned optional reporting checkout for Word tests.
No clinical files, new estimates from invented data, or network data are used.
"""
from __future__ import annotations

import csv
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from runtime.project_workspace import Workspace, WorkspaceError, digest, inside, safe_id, write_json


def repository_copy(destination, full=False):
    names = ["runtime", "config_templates", ".gitignore", ".Rprofile"]
    if full:
        names += ["R", "examples/quick_start", "examples/mi_ps"]
    for name in names:
        source, target = ROOT / name, destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.is_dir():
            shutil.copytree(source, target, ignore=shutil.ignore_patterns("output", "__pycache__"))
        else:
            shutil.copyfile(source, target)
    subprocess.run(["git", "init", "--quiet", str(destination)], check=True, capture_output=True)
    subprocess.run(["git", "-C", str(destination), "add", "."], check=True, capture_output=True)
    subprocess.run(["git", "-C", str(destination), "-c", "user.name=Synthetic test",
                    "-c", "user.email=synthetic@example.invalid", "commit", "--quiet", "-m", "Synthetic workspace test"],
                   check=True, capture_output=True)


def prepare(workspace, project_id, fixture):
    workspace.initialize(project_id)
    project = workspace.project(project_id)
    for name in ("analysis_spec.yml", "variable_dictionary.csv", "input_data_contract.csv", "figure_config.yml"):
        shutil.copyfile(workspace.root / "examples" / fixture / "config" / name, project / "config" / name)
    shutil.copyfile(workspace.root / "examples" / fixture / "input/private/analysis_data.csv",
                    project / "input/private/analysis_data.csv")
    # Synthetic source contracts predate checkout-independent byte bindings.
    # Keep the source fixture intact and bind the new project's actual copy.
    contract = project / "config/input_data_contract.csv"
    with contract.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        fields, rows = reader.fieldnames, list(reader)
    for row in rows:
        if row["relative_path"] == "input/private/analysis_data.csv":
            row["sha256"] = digest(project / "input/private/analysis_data.csv")
    with contract.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    return project


class PathContracts(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="tte-workspace-contracts-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        repository_copy(self.root)
        self.workspace = Workspace(self.root)
        self.workspace.initialize("STUDY_A")
        self.project = self.workspace.project("STUDY_A")

    def test_invalid_project_and_run_identifiers(self):
        invalid = ["", ".", "..", "../other", "A/B", "A\\B", "/root", "A ", "A.",
                   "A:B", "A*B", "A?B", 'A"B', "A<B", "A>B", "A|B", "A\x00B", "a" * 65,
                   "CON", "prn", "aux", "NUL", "COM1", "lpt9", "CON.txt", "CONIN$", "COM0"]
        for value in invalid:
            with self.subTest(value=repr(value)), self.assertRaises(WorkspaceError):
                safe_id(value)
        for value in ("JM1021", "T08", "SEPSIS_AKI", "RUN-01"):
            self.assertEqual(safe_id(value), value)

    def test_case_conflict_preserves_project(self):
        sentinel = self.project / "input/private/retained.txt"
        sentinel.write_text("SYNTHETIC sentinel")
        with self.assertRaises(WorkspaceError):
            self.workspace.initialize("study_a")
        self.assertEqual(sentinel.read_text(), "SYNTHETIC sentinel")

    def test_init_reuses_without_replacing_user_files_or_populating_input(self):
        config = self.project / "config/analysis_spec.yml"
        config.write_text("Researcher retained candidate configuration")
        self.workspace.initialize("STUDY_A")
        self.assertEqual(config.read_text(), "Researcher retained candidate configuration")
        self.assertEqual(list((self.project / "input/private").iterdir()), [])
        self.assertFalse(json.loads((self.project / "config/report_config.json").read_text())["report_enabled"])

    def test_separators_traversal_absolute_and_cross_project_references(self):
        path = self.workspace.path(self.project, "input\\private\\prepared.csv", "input")
        self.assertEqual(path, self.project / "input/private/prepared.csv")
        for value in ("../STUDY_B/input/data.csv", "input/../../STUDY_B/data.csv", "input\\..\\data.csv",
                      "input//data.csv", "input/./data.csv", "input/private./data.csv", "/input/data.csv",
                      "Q" + ":/input/data.csv", "Q" + ":input.csv", "\\\\server\\share\\data.csv",
                      "config/analysis.csv"):
            with self.subTest(path=value), self.assertRaises(WorkspaceError):
                self.workspace.path(self.project, value, "input")

    def test_root_and_nested_links_cannot_escape(self):
        outside = self.root / "outside"
        outside.mkdir()
        link = self.project / "input/private/linked"
        if os.name == "nt":
            result = subprocess.run(["cmd", "/c", "mklink", "/J", str(link), str(outside)], capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.addCleanup(lambda: os.rmdir(link))
        else:
            link.symlink_to(outside, target_is_directory=True)
        with self.assertRaises(WorkspaceError):
            self.workspace.path(self.project, "input/private/linked/file.csv")
        with self.assertRaises(WorkspaceError):
            inside(self.root, self.root.parent / "outside.csv")

    def test_project_root_link_is_rejected(self):
        temporary = Path(tempfile.mkdtemp(prefix="tte-external-"))
        self.addCleanup(lambda: shutil.rmtree(temporary))
        link = self.root / "project/ESCAPE"
        if os.name == "nt":
            subprocess.run(["cmd", "/c", "mklink", "/J", str(link), str(temporary)],
                           check=True, capture_output=True)
            self.addCleanup(lambda: os.rmdir(link))
        else:
            link.symlink_to(temporary, target_is_directory=True)
        with self.assertRaises(WorkspaceError):
            self.workspace.initialize("ESCAPE")

    def test_unapproved_profile_rejected_before_run_or_local_registry(self):
        (self.project / "runtime").mkdir()
        (self.project / "runtime/production_registry.csv").write_text("profile,production_allowed\nCCW,TRUE\n")
        with self.assertRaises(WorkspaceError):
            self.workspace.run("STUDY_A", "CCW", "SYNTHETIC_TEST")
        self.assertEqual(list((self.project / "runs").iterdir()), [])

    def test_gitignore_blocks_staging_all_project_assets(self):
        sentinel = self.project / "input/private/synthetic_sentinel.csv"
        sentinel.write_text("synthetic,value\nSYN1,1\n")
        ignored = subprocess.run(["git", "-C", str(self.root), "check-ignore", "project/STUDY_A/input/private/synthetic_sentinel.csv"],
                                 capture_output=True, text=True)
        self.assertEqual(ignored.returncode, 0)
        staged = subprocess.run(["git", "-C", str(self.root), "add", "project"], capture_output=True)
        self.assertNotEqual(staged.returncode, 0)
        tracked = subprocess.run(["git", "-C", str(self.root), "ls-files", "project"], capture_output=True, text=True)
        self.assertEqual(tracked.stdout, "")

    def test_reporting_is_disabled_without_loading_optional_module(self):
        self.assertEqual(self.workspace.report("STUDY_A", "absent")["status"], "REPORT_DISABLED")

    def test_busy_project_lock_is_not_stolen(self):
        with self.workspace.lock(self.project):
            with self.assertRaises(WorkspaceError):
                with self.workspace.lock(self.project):
                    self.fail("Should not acquire the same project twice")


@unittest.skipUnless(os.environ.get("TTE_RUN_WORKSPACE_INTEGRATION") == "1", "Real R integration is opt-in")
class SyntheticExecutions(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="tte-workspace-integration-")
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.root = Path(cls.temporary.name)
        repository_copy(cls.root, full=True)
        # Exercise Linux checkout bytes even when these tests run on Windows.
        # Only temporary copies of the existing synthetic CSVs are normalized.
        for fixture in ("quick_start", "mi_ps"):
            copied = cls.root / "examples" / fixture / "input/private/analysis_data.csv"
            copied.write_bytes(copied.read_bytes().replace(b"\r\n", b"\n"))
        # The isolated test checkout contains code and fixtures, not a second
        # installed renv library. Reuse the actual caller's restored R libraries.
        libraries = cls.root / "r_libraries.txt"
        subprocess.run(["Rscript", "-e", "writeLines(.libPaths(), commandArgs(TRUE)[1])", str(libraries)],
                       cwd=ROOT, check=True, capture_output=True)
        previous = os.environ.get("R_LIBS")
        def restore_libraries():
            if previous is None:
                os.environ.pop("R_LIBS", None)
            else:
                os.environ["R_LIBS"] = previous
        cls.addClassCleanup(restore_libraries)
        os.environ["R_LIBS"] = os.pathsep.join(libraries.read_text().splitlines())
        cls.workspace = Workspace(cls.root)
        cls.binary = prepare(cls.workspace, "SYNTHETIC_BINARY", "quick_start")
        cls.continuous = prepare(cls.workspace, "SYNTHETIC_CONTINUOUS", "mi_ps")
        # A project-local registry must never control the execution gate.
        (cls.binary / "runtime").mkdir()
        (cls.binary / "runtime/production_registry.csv").write_text("profile,production_allowed\nBASELINE_BINARY_RISK,FALSE\n")
        cls.workspace.run("SYNTHETIC_BINARY", "BASELINE_BINARY_RISK", "SYNTHETIC_TEST", "run_001")
        cls.first = cls.binary / "runs/run_001"
        cls.first_hashes = {p.relative_to(cls.first).as_posix(): digest(p)
                            for p in cls.first.rglob("*") if p.is_file()}
        # A harmless configuration comment verifies separate frozen snapshots.
        with (cls.binary / "config/analysis_spec.yml").open("a") as handle:
            handle.write("\n# Synthetic second-run configuration snapshot\n")
        command = [sys.executable, str(cls.root / "runtime/project_workspace.py"), "run", "SYNTHETIC_BINARY",
                   "--profile", "BASELINE_BINARY_RISK", "--execution-mode", "SYNTHETIC_TEST"]
        cls.second_result = json.loads(subprocess.run(command, cwd=cls.root.parent, check=True,
                                                     capture_output=True, text=True).stdout)
        cls.workspace.run("SYNTHETIC_CONTINUOUS", "MI_PS_CONTINUOUS_ATE", "SYNTHETIC_TEST", "run_001")

    def test_two_profiles_same_filenames_separate_inputs_outputs_and_config(self):
        for project in (self.binary, self.continuous):
            run = project / "runs/run_001"
            metadata = json.loads((run / "internal/run.json").read_text())
            self.assertEqual(metadata["status"], "COMPLETED")
            self.assertTrue(metadata["diagnostic_gate_pass"])
            self.assertEqual(metadata["inputs_sha256"]["input/private/analysis_data.csv"],
                             digest(project / "input/private/analysis_data.csv"))
            self.assertTrue((run / "output/tables/primary_effects.csv").is_file())
            self.assertTrue((run / "output/figures/covariate_balance.png").is_file())
            self.assertEqual(list((run / "report").iterdir()), [])
        self.assertNotEqual(digest(self.binary / "runs/run_001/output/tables/primary_effects.csv"),
                            digest(self.continuous / "runs/run_001/output/tables/primary_effects.csv"))
        self.assertFalse((self.root / "output").exists())

    def test_repeat_keeps_first_run_bytes_snapshots_and_index(self):
        for name, before in self.first_hashes.items():
            self.assertEqual(digest(self.first / name), before)
        self.assertNotEqual(self.second_result["run_id"], "run_001")
        index = json.loads((self.binary / "runs/index.json").read_text())
        self.assertEqual(len(index), 2)
        for run_id, entry in index.items():
            self.assertEqual(entry["status"], "COMPLETED")
            self.assertTrue((self.binary / "runs" / entry["output"]).is_dir())
        second = self.binary / "runs" / self.second_result["run_id"]
        self.assertNotEqual(digest(self.first / "internal/config/analysis_spec.yml"),
                            digest(second / "internal/config/analysis_spec.yml"))
        with self.assertRaises(WorkspaceError):
            self.workspace.run("SYNTHETIC_BINARY", "BASELINE_BINARY_RISK", "SYNTHETIC_TEST", "RUN_001")

    def test_numerical_values_match_existing_frozen_fixture(self):
        with (self.first / "output/tables/primary_effects.csv").open(encoding="utf-8-sig") as handle:
            actual = list(csv.DictReader(handle))
        with (ROOT / "examples/quick_start/expected/tables_primary_effects.csv").open(encoding="utf-8-sig") as handle:
            expected = list(csv.DictReader(handle))
        self.assertEqual(len(actual), len(expected))
        for left, right in zip(actual, expected):
            for key in ("estimate", "standard_error", "ci_lower", "ci_upper"):
                self.assertAlmostEqual(float(left[key]), float(right[key]), delta=1e-8)

    def test_failed_input_hash_is_indexed_and_never_reportable(self):
        project = prepare(self.workspace, "SYNTHETIC_FAILED", "quick_start")
        with (project / "input/private/analysis_data.csv").open("a") as handle:
            handle.write("\n")
        with self.assertRaisesRegex(WorkspaceError, "hash mismatch"):
            self.workspace.run("SYNTHETIC_FAILED", "BASELINE_BINARY_RISK", "SYNTHETIC_TEST", "run_failed")
        self.assertEqual(json.loads((project / "runs/index.json").read_text())["run_failed"]["status"], "FAILED")
        with self.assertRaises(WorkspaceError):
            self.workspace.report("SYNTHETIC_FAILED", "run_failed", enable=True)

    @unittest.skipUnless(os.environ.get("TTE_REPORTING_LIBRARY"), "Optional Word checkout required")
    def test_word_uses_this_run_aggregates_and_existing_figure_without_refitting(self):
        from docx import Document
        library = os.environ["TTE_REPORTING_LIBRARY"]
        config = {"report_enabled": False, "data_classification": "SYNTHETIC_CONFIRMED",
                  "title": "Synthetic project analysis report", "language": "en",
                  "study": {"design": "Existing synthetic baseline comparison.",
                            "population": "Synthetic units from the fixed-seed Quick Start."},
                  "results": [{"type": "effects", "path": "output/tables/primary_effects.csv",
                               "caption": "Table 1. Saved synthetic effects", "interval_label": "95% interval"},
                              {"type": "figure", "path": "output/figures/covariate_balance.png",
                               "caption": "Figure 1. Saved synthetic balance diagnostics"}],
                  "next_steps": [{"type": "paragraph", "text": "Review synthetic assembly; no clinical validation is implied."}]}
        source = self.binary / "config/report_config.json"
        write_json(source, config)
        before = {p: digest(p) for p in (self.first / "output").rglob("*") if p.is_file()}
        result = self.workspace.report("SYNTHETIC_BINARY", "run_001", True, reporting_library=library)
        output = self.first / "report/analysis_report.docx"
        self.assertEqual(Path(result["output"]), output)
        document = Document(output)
        self.assertEqual(len(document.tables), 1)
        self.assertEqual(len(document.inline_shapes), 1)
        self.assertIn("SYNTHETIC_BINARY / run_001", document.paragraphs[0].text)
        self.assertEqual(before, {p: digest(p) for p in before})
        self.assertEqual(self.workspace.report("SYNTHETIC_BINARY", "run_001", True,
                         reporting_library=library)["status"], "REPORT_UNCHANGED")
        # Changed prose requires an explicitly named new report version.
        config["title"] = "Revised synthetic project analysis report"
        write_json(source, config)
        with self.assertRaisesRegex(WorkspaceError, "new --report-version"):
            self.workspace.report("SYNTHETIC_BINARY", "run_001", True, reporting_library=library)
        config["results"] = config["results"][:1]
        write_json(source, config)
        self.workspace.report("SYNTHETIC_BINARY", "run_001", True, version="analysis_report_v2", reporting_library=library)
        self.assertEqual(len(Document(self.first / "report/analysis_report_v2.docx").inline_shapes), 0)
        self.assertTrue(output.exists())
        # Author edits stay protected even with an unchanged source config.
        revised = self.first / "report/analysis_report_v2.docx"
        edited = Document(revised)
        edited.add_paragraph("Retained synthetic author edit.")
        edited.save(revised)
        retained = digest(revised)
        with self.assertRaises(ValueError):
            self.workspace.report("SYNTHETIC_BINARY", "run_001", True, version="analysis_report_v2", reporting_library=library)
        self.assertEqual(digest(revised), retained)
        self.assertEqual(list(self.first.rglob("*.md")), [])
        self.assertFalse((self.root / "output").exists())
        asset = self.first / "output/tables/primary_effects.csv"
        retained_asset = asset.read_bytes()
        try:
            asset.write_bytes(retained_asset + b"\n")
            with self.assertRaisesRegex(WorkspaceError, "unchanged output"):
                self.workspace.report("SYNTHETIC_BINARY", "run_001", True, version="changed_asset", reporting_library=library)
        finally:
            asset.write_bytes(retained_asset)
        # Cross-project, input-level and unconfirmed sources are all rejected.
        for path in ("../SYNTHETIC_CONTINUOUS/runs/run_001/output/tables/primary_effects.csv",
                     "input/private/analysis_data.csv", "output/internal/analysis_internal.rds"):
            config["results"][0]["path"] = path
            write_json(source, config)
            with self.assertRaises(WorkspaceError):
                self.workspace.report("SYNTHETIC_BINARY", "run_001", True, version="rejected", reporting_library=library)
        config["data_classification"] = "UNCONFIRMED"
        write_json(source, config)
        with self.assertRaises(WorkspaceError):
            self.workspace.report("SYNTHETIC_BINARY", "run_001", True, version="rejected", reporting_library=library)


if __name__ == "__main__":
    unittest.main()
