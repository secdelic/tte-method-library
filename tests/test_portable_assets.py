"""Integrity of preserved source and the integrated, standalone checkout."""
import hashlib
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PortableAssets(unittest.TestCase):
    def test_development_snapshot_matches_its_recorded_bytes(self):
        snapshot = ROOT / "development/ccw_candidates"
        manifest = json.loads((snapshot / "SOURCE_MANIFEST.json").read_text(encoding="utf-8"))
        self.assertEqual(len(manifest["files"]), 48)
        for item in manifest["files"]:
            path = snapshot / item["snapshot_path"]
            self.assertTrue(path.resolve().is_relative_to(snapshot.resolve()))
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), item["snapshot_sha256"])
            if not item["portability_path_adaptation"]:
                self.assertEqual(item["source_sha256"], item["snapshot_sha256"])

    def test_enabled_workflows_have_in_checkout_dependencies(self):
        required = ("reporting/workflow.py", "reporting/assemble_docx.py", "reporting/requirements.txt",
                    "reporting/constraints.txt", "runtime/project_workspace.py", "runtime/render_report.py",
                    "scripts/setup_windows.ps1", "scripts/restore_environment.R", "scripts/check_environment.R",
                    "scripts/smoke_test_windows.ps1", "docs/CROSS_PC_MIGRATION.md")
        for name in required:
            self.assertTrue((ROOT / name).is_file(), name)
        workflow = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
        self.assertNotIn(".reporting-dependency", workflow)
        self.assertNotIn("70b53b186ac8cf302ba2d07e10b5525f5cda1fe5", workflow)


if __name__ == "__main__":
    unittest.main()
