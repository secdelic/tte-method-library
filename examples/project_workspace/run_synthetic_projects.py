"""Run two isolated projects using only the repository's existing synthetic CSVs.

Run once in a fresh checkout; existing projects are preserved and cause refusal.
Word remains off unless --enable-word is supplied with the optional adapter.
"""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from runtime.project_workspace import CONFIG_FILES, Workspace, WorkspaceError, digest, write_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--enable-word", action="store_true")
    parser.add_argument("--reporting-library")
    args = parser.parse_args()
    workspace = Workspace(ROOT)
    studies = [("SYNTHETIC_BINARY", "quick_start", "BASELINE_BINARY_RISK"),
               ("SYNTHETIC_CONTINUOUS", "mi_ps", "MI_PS_CONTINUOUS_ATE")]
    # Check both before creating anything; never populate a pre-existing study.
    for project_id, _, _ in studies:
        if (workspace.projects / project_id).exists():
            raise WorkspaceError("Synthetic demonstration projects already exist; preserve them and use the project CLI for a new run")
    results = []
    for project_id, fixture, profile in studies:
        workspace.initialize(project_id)
        project = workspace.project(project_id)
        for name in CONFIG_FILES:
            shutil.copyfile(ROOT / "examples" / fixture / "config" / name, project / "config" / name)
        shutil.copyfile(ROOT / "examples" / fixture / "input/private/analysis_data.csv",
                        project / "input/private/analysis_data.csv")
        # Git checkouts may use LF or CRLF. Bind this new synthetic project's
        # manifest to its actual copied bytes, without modifying source fixtures
        # or weakening hash validation for researcher-prepared inputs.
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
        config = {
            "report_enabled": False, "data_classification": "SYNTHETIC_CONFIRMED",
            "title": "Synthetic analysis report", "language": "en",
            "study": {"design": "Existing synthetic baseline treatment comparison.",
                      "population": "Fixed-seed synthetic analysis units from the existing " + fixture + " example."},
            "results": [{"type": "effects", "path": "output/tables/primary_effects.csv",
                         "caption": "Table 1. Saved synthetic effects", "interval_label": "95% interval",
                         "column_widths": [0.9, 1.65, 0.9, 0.8, 2.25],
                         "note": "Synthetic results are not clinical evidence. Supplied estimates and intervals are copied without refitting."}],
            "next_steps": [{"type": "paragraph", "text": "Review the supplied synthetic results and report layout before adapting any configuration."}]
        }
        if fixture == "quick_start":
            config["study"].update(models="Propensity-score weighting with fixed-weight influence-curve inference.",
                                   uncertainty="The saved 95% intervals use the existing binary example's inference procedure.")
            config["results"].append({"type": "figure", "path": "output/figures/covariate_balance.png",
                                       "caption": "Figure 1. Saved synthetic covariate balance", "width_inches": 3.35})
        else:
            config["study"].update(models="Within-imputation WeightIt M-estimation and Rubin pooling.",
                                   missing="The existing synthetic example uses 10 PMM imputations; this report performs no imputation.",
                                   uncertainty="The supplied 95% interval is copied from the saved pooled result.")
        write_json(project / "config/report_config.json", config)
        results.append(workspace.run(project_id, profile, "SYNTHETIC_TEST", "run_001"))
        if fixture == "quick_start":
            results.append(workspace.run(project_id, profile, "SYNTHETIC_TEST", "run_002"))
        if args.enable_word:
            results.append(workspace.report(project_id, "run_001", True, reporting_library=args.reporting_library))
    print(json.dumps(results, ensure_ascii=True, indent=2))


if __name__ == "__main__":
    main()
