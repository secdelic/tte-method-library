"""Project-local runs around the unchanged registered R statistical runtime.

Python 3.11+, standard library only unless Word reporting is explicitly enabled.
All CLI paths are anchored to this checkout, never to the shell directory.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import csv
from datetime import datetime, timezone
import hashlib
import importlib
import importlib.util
import json
import os
from pathlib import Path, PureWindowsPath
import re
import shutil
import subprocess
import sys
import uuid


ROOT = Path(__file__).resolve().parents[1]
CONFIG_FILES = ("analysis_spec.yml", "variable_dictionary.csv",
                "input_data_contract.csv", "figure_config.yml")


class WorkspaceError(ValueError):
    """A project boundary, identity or lifecycle contract was not satisfied."""


def safe_id(value):
    # Deliberately portable, short, non-identifying research codes only.
    if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}", value):
        raise WorkspaceError("Use a 1-64 character research code: letters, digits, underscore or hyphen; no patient identity")
    if re.fullmatch(r"CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9]|CONIN\$|CONOUT\$", value, re.I):
        raise WorkspaceError("System-reserved names are prohibited")
    return value


def relative_parts(value):
    if not isinstance(value, str) or not value or PureWindowsPath(value).drive:
        raise WorkspaceError("Only project-relative paths are allowed")
    value = value.replace("\\", "/")
    parts = value.split("/")
    if value.startswith("/") or any(p in ("", ".", "..") or
            re.search(r'[<>:"|?*\x00-\x1f]', p) or p.endswith((" ", ".")) for p in parts):
        raise WorkspaceError("Absolute, ambiguous or traversing paths are prohibited")
    return parts


def inside(root, path):
    """Check every component, including Windows junctions and dangling links.

    Rejecting links altogether is intentional: even an in-project link could
    otherwise become a cross-project reference after retargeting.
    """
    root, path = Path(root).absolute(), Path(path).absolute()
    try:
        parts = path.relative_to(root).parts
    except ValueError as error:
        raise WorkspaceError("Path is outside its permitted root") from error
    current = root
    for part in ("", *parts):
        if part:
            current = current / part
        if current.is_symlink() or (hasattr(current, "is_junction") and current.is_junction()):
            raise WorkspaceError("Linked workspace paths are prohibited")
        # Python 3.11 on Windows has no Path.is_junction().
        if os.name == "nt" and current.exists():
            import stat
            if current.lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT:
                raise WorkspaceError("Reparse-point workspace paths are prohibited")
    if not path.resolve().is_relative_to(root.resolve()):
        raise WorkspaceError("Resolved path escapes its permitted root")
    return path


def digest(path):
    with Path(path).open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def write_json(path, value):
    path = Path(path)
    inside(path.parent, path)
    temporary = path.with_name(path.name + "." + uuid.uuid4().hex + ".tmp")
    try:
        with temporary.open("x", encoding="utf-8") as target:
            json.dump(value, target, ensure_ascii=False, indent=2)
            target.write("\n")
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def now():
    return datetime.now(timezone.utc).isoformat()


class Workspace:
    def __init__(self, repository=ROOT):
        self.root = Path(repository).resolve(strict=True)
        top = subprocess.run(["git", "-C", str(self.root), "rev-parse", "--show-toplevel"],
                             check=True, capture_output=True, text=True).stdout.strip()
        if Path(top).resolve() != self.root or not (self.root / "runtime/load_library.R").is_file():
            raise WorkspaceError("Workspace must use the actual method-library Git root")
        self.projects = inside(self.root, self.root / "project")

    def project(self, project_id, create=False):
        safe_id(project_id)
        inside(self.root, self.projects)
        if create:
            self.projects.mkdir(exist_ok=True)
        if self.projects.exists():
            conflicts = [p for p in self.projects.iterdir() if p.name.casefold() == project_id.casefold()
                         and p.name != project_id]
            if conflicts:
                raise WorkspaceError("Project ID has a case-insensitive name conflict")
        project = inside(self.projects, self.projects / project_id)
        if not create and not project.is_dir():
            raise WorkspaceError("Initialize the project first")
        if create:
            project.mkdir(exist_ok=True)
        return project

    def path(self, project, name, prefix=None):
        parts = relative_parts(name)
        if prefix and parts[0] != prefix:
            raise WorkspaceError("Path must stay in the designated project subdirectory")
        return inside(project, project.joinpath(*parts))

    def initialize(self, project_id):
        project = self.project(project_id, create=True)
        for name in ("input/private", "config", "runs"):
            self.path(project, name).mkdir(parents=True, exist_ok=True)
        for name in CONFIG_FILES:
            target = self.path(project, "config/" + name)
            if not target.exists():
                with target.open("xb") as output:
                    output.write((self.root / "config_templates" / name).read_bytes())
        target = self.path(project, "config/report_config.json")
        if not target.exists():
            with target.open("x", encoding="utf-8") as output:
                output.write((self.root / "config_templates/project_report_config.json").read_text(encoding="utf-8"))
        return {"status": "PROJECT_READY", "project": str(project)}

    @contextmanager
    def lock(self, project):
        lock = self.path(project, "runs/.workspace.lock")
        try:
            lock.mkdir()
        except FileExistsError as error:
            raise WorkspaceError("Project is busy or has an interrupted-run lock; inspect before removing the lock") from error
        try:
            yield
        finally:
            lock.rmdir()

    def record(self, project, run, metadata):
        write_json(inside(project, run / "internal/run.json"), metadata)
        index_path = self.path(project, "runs/index.json")
        index = read_json(index_path) if index_path.exists() else {}
        index[run.name] = {"status": metadata["status"], "profile": metadata["profile"],
                           "started_at": metadata["started_at"],
                           "metadata": f"{run.name}/internal/run.json",
                           "output": f"{run.name}/output", "reports": metadata.get("reports", {})}
        write_json(index_path, index)

    def approved(self, profile):
        registry = self.root / "runtime/production_registry.csv"
        with registry.open(encoding="utf-8-sig", newline="") as source:
            rows = [r for r in csv.DictReader(source) if r["profile"] == profile]
        if len(rows) != 1 or rows[0]["production_allowed"].upper() != "TRUE":
            raise WorkspaceError("Profile is not production-approved by the repository Registry")
        return registry

    def run(self, project_id, profile, execution_mode, run_id=None,
            data="input/private/analysis_data.csv", rscript="Rscript"):
        registry = self.approved(profile)
        if execution_mode not in ("SYNTHETIC_TEST", "CANARY", "FORMAL_CANDIDATE"):
            raise WorkspaceError("Invalid execution_mode")
        project = self.project(project_id)
        source = self.path(project, data, "input")
        if not source.is_file() or source.suffix.lower() != ".csv":
            raise WorkspaceError("A prepared project input CSV is required")
        configs = {name: self.path(project, "config/" + name) for name in CONFIG_FILES}
        if not all(p.is_file() for p in configs.values()):
            raise WorkspaceError("All four researcher-supplied configuration files are required")
        executable = shutil.which(rscript)
        if not executable:
            raise WorkspaceError("Rscript executable is unavailable")
        with self.lock(project):
            run_id = safe_id(run_id) if run_id is not None else (
                "run_" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S") + "_" + uuid.uuid4().hex[:12])
            runs = self.path(project, "runs")
            if any(p.name.casefold() == run_id.casefold() for p in runs.iterdir()):
                raise WorkspaceError("Run ID already exists; historical runs cannot be overwritten")
            run = self.path(project, "runs/" + run_id)
            run.mkdir()
            (run / "internal/config").mkdir(parents=True)
            (run / "report").mkdir()
            inputs = {data.replace("\\", "/"): digest(source)}
            inputs.update({"config/" + name: digest(path) for name, path in configs.items()})
            revision = subprocess.run(["git", "-C", str(self.root), "rev-parse", "HEAD"],
                                      check=True, capture_output=True, text=True).stdout.strip()
            code = sorted((self.root / "R").rglob("*.R")) + [
                self.root / "runtime/load_library.R", self.root / "runtime/run_project_analysis.R",
                self.root / "runtime/project_workspace.py", self.root / ".Rprofile"]
            code_hashes = {p.relative_to(self.root).as_posix(): digest(p) for p in code}
            metadata = {"project_id": project_id, "run_id": run_id, "profile": profile,
                        "execution_mode": execution_mode, "started_at": now(), "status": "RUNNING",
                        "repository_commit": revision, "registry_sha256": digest(registry),
                        "inputs_sha256": inputs, "code_sha256": code_hashes,
                        "rscript": executable, "reports": {}, "scientific_approval": "NOT_GRANTED_BY_CODE"}
            self.record(project, run, metadata)
            try:
                for name, path in configs.items():
                    shutil.copyfile(path, run / "internal/config" / name)
                    if digest(run / "internal/config" / name) != inputs["config/" + name]:
                        raise WorkspaceError("Configuration changed while snapshotting")
                # Validate contract paths too, even though the existing runtime
                # only reads the explicitly supplied data_path.
                contract = run / "internal/config/input_data_contract.csv"
                with contract.open(encoding="utf-8-sig", newline="") as handle:
                    declared = []
                    for row in csv.DictReader(handle):
                        declared_path = self.path(project, row["relative_path"], "input")
                        declared.append(declared_path)
                        if row.get("required", "").upper() == "TRUE" and not declared_path.is_file():
                            raise WorkspaceError("Required contract input is missing")
                        if row.get("sha256") and declared_path.exists() and digest(declared_path) != row["sha256"].lower():
                            raise WorkspaceError("Contract input hash mismatch")
                    if source not in declared:
                        raise WorkspaceError("Selected data must be declared in the project's input contract")
                command = [executable, str(self.root / "runtime/run_project_analysis.R"),
                           str(self.root), str(project), profile, str(source),
                           str(run / "internal/config"), str(run / "output"), execution_mode]
                environment = os.environ.copy()
                environment["R_PROFILE_USER"] = str(self.root / ".Rprofile")
                with (run / "internal/runtime.log").open("xb") as log:
                    # Repository startup activates its installed renv library;
                    # the R bridge then enters the project before analysis.
                    result = subprocess.run(command, cwd=self.root, env=environment, stdout=log, stderr=log)
                if result.returncode:
                    raise WorkspaceError("Statistical runtime failed; inspect this run's private internal/runtime.log")
                for name, expected in inputs.items():
                    if digest(self.path(project, name)) != expected:
                        raise WorkspaceError("Project input/configuration changed during execution; outputs remain unadopted")
                if digest(registry) != metadata["registry_sha256"]:
                    raise WorkspaceError("Repository Registry changed during execution")
                if any(digest(self.root / name) != expected for name, expected in code_hashes.items()):
                    raise WorkspaceError("Library code changed during execution")
                metadata["outputs_sha256"] = {
                    p.relative_to(run).as_posix(): digest(inside(run, p))
                    for p in sorted((run / "output").rglob("*")) if p.is_file()}
                metadata["status"] = "COMPLETED"
                with (run / "output/diagnostics/diagnostic_gate.csv").open(encoding="utf-8-sig") as handle:
                    metadata["diagnostic_gate_pass"] = next(csv.DictReader(handle))["diagnostic_gate_pass"] == "TRUE"
            except Exception:
                # Persist failure, then propagate it; never continue with an
                # alternative model, inputs or a successful run designation.
                metadata["status"] = "FAILED"
                raise
            finally:
                metadata["finished_at"] = now()
                self.record(project, run, metadata)
        return {"status": metadata["status"], "run_id": run_id, "run": str(run),
                "diagnostic_gate_pass": metadata["diagnostic_gate_pass"], "word_report": "DISABLED"}

    def report(self, project_id, run_id, enable=False, config="config/report_config.json",
               version="analysis_report", reporting_library=None):
        if not enable:
            return {"status": "REPORT_DISABLED"}
        project = self.project(project_id)
        run = self.path(project, "runs/" + safe_id(run_id))
        version = safe_id(version)
        with self.lock(project):
            metadata = read_json(inside(run, run / "internal/run.json"))
            if (metadata["status"] != "COMPLETED" or metadata["project_id"] != project_id
                    or metadata["run_id"] != run_id):
                raise WorkspaceError("Report needs a completed run belonging to this project")
            config_path = self.path(project, config, "config")
            raw = config_path.read_bytes()
            effective = json.loads(raw.decode("utf-8-sig"))
            if effective.get("data_classification") not in ("AGGREGATE_ONLY_CONFIRMED", "SYNTHETIC_CONFIRMED"):
                raise WorkspaceError("Report requires explicit aggregate-only or synthetic confirmation")
            def unresolved(value):
                if isinstance(value, str):
                    return value.startswith("<") and value.endswith(">")
                if isinstance(value, dict):
                    return any(unresolved(v) for v in value.values())
                return isinstance(value, list) and any(unresolved(v) for v in value)
            if unresolved(effective):
                raise WorkspaceError("Replace report template placeholders with confirmed content")
            if effective.get("project_id", project_id) != project_id:
                raise WorkspaceError("Report configuration belongs to another project")
            effective["title"] = effective["title"] + f" [{project_id} / {run_id}]"
            effective["report_enabled"] = True
            if not metadata["diagnostic_gate_pass"]:
                effective.setdefault("results", []).insert(0, {"type": "paragraph", "text":
                    "The recorded diagnostic gate did not pass. Review the saved diagnostics before using these results."})
            for section in ("methods", "results", "next_steps"):
                for block in effective.get(section, []):
                    if block.get("type") not in ("table", "effects", "figure"):
                        continue
                    parts = relative_parts(block["path"])
                    allowed = ("figures",) if block["type"] == "figure" else ("tables", "sensitivity")
                    if len(parts) < 3 or parts[0] != "output" or parts[1] not in allowed:
                        raise WorkspaceError("Report assets must be aggregate tables or figures in this run's output")
                    asset = inside(run, run.joinpath(*parts))
                    expected = metadata["outputs_sha256"].get("/".join(parts))
                    if not expected or digest(asset) != expected:
                        raise WorkspaceError("Report asset is not an unchanged output of this run")
                    if block.get("sha256") and block["sha256"].lower() != expected:
                        raise WorkspaceError("Configured report asset identity does not match this run")
                    block.update(path=str(asset), sha256=expected)
            if "author_reference" in effective:
                reference = effective["author_reference"]
                reference["path"] = str(self.path(project, reference["path"], "config"))
            # Load the optional adapter under its own namespace. External code
            # roots are explicit; data paths remain restricted to this project.
            library = Path(reporting_library).resolve(strict=True) if reporting_library else self.root
            package = library / "reporting/__init__.py"
            if not package.is_file():
                raise WorkspaceError("Optional Word module is unavailable; install PR #7 in an isolated checkout and supply --reporting-library")
            namespace = "_tte_report_" + hashlib.sha256(str(library).encode()).hexdigest()[:16]
            spec = importlib.util.spec_from_file_location(namespace, package,
                submodule_search_locations=[str(package.parent)])
            module = importlib.util.module_from_spec(spec)
            sys.modules[namespace] = module
            spec.loader.exec_module(module)
            workflow = importlib.import_module(namespace + ".workflow")
            internal = self.path(project, f"runs/{run_id}/internal/reports/{version}")
            internal.mkdir(parents=True, exist_ok=True)
            frozen = inside(project, internal / "effective_config.json")
            original = inside(project, internal / "source_config.json")
            if frozen.exists():
                if read_json(frozen) != effective or original.read_bytes() != raw:
                    raise WorkspaceError("Report configuration changed; choose a new --report-version")
            else:
                write_json(frozen, effective)
                with original.open("xb") as output:
                    output.write(raw)
            output = self.path(project, f"runs/{run_id}/report/{version}.docx")
            checks = inside(project, internal / "checks")
            if checks.exists():
                for path in checks.rglob("*"):
                    inside(project, path)
            result = workflow.run(frozen, output, checks, enable=True)
            metadata.setdefault("reports", {})[version] = {"path": f"report/{version}.docx",
                "sha256": digest(output), "source_config_sha256": hashlib.sha256(raw).hexdigest()}
            self.record(project, run, metadata)
            return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    initialize = commands.add_parser("init", help="Create directories and unresolved templates without replacing files")
    initialize.add_argument("project_id")
    run = commands.add_parser("run", help="Execute an approved profile in a fresh project run")
    run.add_argument("project_id")
    run.add_argument("--profile", required=True)
    run.add_argument("--execution-mode", required=True, choices=("SYNTHETIC_TEST", "CANARY", "FORMAL_CANDIDATE"))
    run.add_argument("--run-id")
    run.add_argument("--data", default="input/private/analysis_data.csv")
    run.add_argument("--rscript", default="Rscript")
    report = commands.add_parser("report", help="Optionally assemble Word from one completed run without refitting")
    report.add_argument("project_id")
    report.add_argument("--run-id", required=True)
    report.add_argument("--enable", action="store_true")
    report.add_argument("--config", default="config/report_config.json")
    report.add_argument("--report-version", default="analysis_report")
    report.add_argument("--reporting-library")
    args = parser.parse_args()
    try:
        workspace = Workspace()
        if args.action == "init":
            result = workspace.initialize(args.project_id)
        elif args.action == "run":
            result = workspace.run(args.project_id, args.profile, args.execution_mode,
                                   args.run_id, args.data, args.rscript)
        else:
            result = workspace.report(args.project_id, args.run_id, args.enable,
                                      args.config, args.report_version, args.reporting_library)
        print(json.dumps(result, ensure_ascii=True))
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as error:
        # Do not echo a data value or an exception's arbitrary clinical content.
        message = str(error) if isinstance(error, WorkspaceError) else "Required file or configuration is invalid; inspect the project locally"
        parser.exit(1, "Project operation failed: " + message + "\n")


if __name__ == "__main__":
    main()
