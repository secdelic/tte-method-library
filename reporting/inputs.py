"""Read explicitly supplied aggregate outputs; never run an estimator."""
from __future__ import annotations

import csv
import hashlib
import json
import math
import re
from pathlib import Path


HEADINGS = {
    "en": ("1 Methods", "2 Results", "3 Next Steps"),
    "zh-CN": ("1 方法（Methods）", "2 结果（Results）", "3 后续工作"),
}
STUDY_LABELS = {
    "design": ("Study design", "研究设计"),
    "population": ("Analysis population", "分析人群"),
    "eligibility": ("Eligibility", "纳入排除"),
    "time": ("Time definitions", "时间定义"),
    "exposure": ("Exposure", "暴露"),
    "comparator": ("Comparator", "对照"),
    "outcome": ("Outcome", "结局"),
    "models": ("Models", "模型"),
    "adjustment": ("Adjustment variables", "调整变量"),
    "missing": ("Missing observations", "缺失观察"),
    "uncertainty": ("Uncertainty", "不确定性"),
}
IDENTIFIERS = {"subjectid", "patientid", "analysisid", "personid", "stayid",
               "hadmid", "cloneid", "recordid", "patientname", "身份证", "患者id", "姓名"}
MISSING = {"", "NA", "N/A", "NULL", "NAN"}


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read_config(path):
    config = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    if not isinstance(config, dict):
        raise ValueError("Report configuration must be an object")
    if type(config.get("report_enabled", False)) is not bool:
        raise ValueError("report_enabled must be a Boolean")
    return config


def report_text(value, label, *, empty=False):
    if not isinstance(value, str) or (not empty and not value.strip()):
        raise ValueError(f"{label} must be supplied as text")
    if re.search(r"[A-Za-z]:[\\/]|\\\\[^\s]+|(?:^|\s)/(?:home|Users|tmp|mnt)/", value):
        raise ValueError(f"{label} contains a local path; keep provenance outside the report")
    return value


def _number(value, name, optional=False):
    if value is None or str(value).strip().upper() in MISSING:
        if optional:
            return None
        raise ValueError(f"Missing {name}")
    try:
        number = float(value)
    except (ValueError, TypeError) as error:
        raise ValueError(f"Invalid numeric {name}") from error
    if not math.isfinite(number):
        raise ValueError(f"Non-finite {name}")
    return number


def _decimals(value):
    if type(value) is not int or not 0 <= value <= 12:
        raise ValueError("Display decimals must be an integer from 0 to 12")
    return value


def _csv(path):
    with path.open(encoding="utf-8-sig", newline="") as source:
        reader = csv.DictReader(source)
        headers = reader.fieldnames
        if not headers or len(headers) != len(set(headers)):
            raise ValueError("CSV must have unique named columns")
        if any(re.sub(r"[\W_]", "", name).lower() in IDENTIFIERS for name in headers):
            raise ValueError("Patient-level identifier column is not allowed in a report input")
        rows = list(reader)
    if not rows or any(None in row or any(v is None for v in row.values()) for row in rows):
        raise ValueError("Aggregate CSV is empty or has inconsistent row widths")
    return headers, rows


def _alias(row, names, *, optional=False):
    values = [row[key] for key in names if key in row]
    if not values:
        if optional:
            return None
        raise ValueError("Missing result column: " + names[0])
    numbers = [_number(value, names[0], optional=optional) for value in values]
    if any(value != numbers[0] for value in numbers[1:]):
        raise ValueError("Conflicting result aliases: " + ", ".join(names))
    return numbers[0]


def _effects(block, path, language):
    _, rows = _csv(path)
    decimals = _decimals(block.get("decimals", 4))
    scale = _number(block.get("scale", 1), "display scale")
    if scale <= 0:
        raise ValueError("Display scale must be positive")
    values = []
    analyses = []
    for row in rows:
        analysis = row.get("analysis")
        analyses.append(analysis)
        effect = row.get("effect_measure", row.get("effect"))
        if "effect_measure" in row and "effect" in row and row["effect_measure"] != row["effect"]:
            raise ValueError("Conflicting effect labels")
        effect = report_text(effect, "Effect label")
        estimate = _alias(row, ("estimate",))
        se = _alias(row, ("standard_error", "se", "std_error"), optional=True)
        low = _alias(row, ("ci_lower", "conf_low"), optional=True)
        high = _alias(row, ("ci_upper", "conf_high"), optional=True)
        if (low is None) != (high is None):
            raise ValueError("An interval needs both endpoints, or neither")
        if low is not None and low > high:
            raise ValueError("Interval endpoints are reversed")
        if se is not None and se < 0:
            raise ValueError("Standard error must be nonnegative")
        values.append((effect, estimate, se, low, high))
    has_se = any(row[2] is not None for row in values)
    has_ci = any(row[3] is not None for row in values)
    has_analysis = any(value is not None for value in analyses)
    zh = language == "zh-CN"
    missing = "未提供" if zh else "Not provided"
    headers = ["指标" if zh else "Effect", "估计值" if zh else "Estimate"]
    if has_analysis:
        headers.insert(0, "分析" if zh else "Analysis")
    if has_se:
        headers.append("标准误" if zh else "SE")
    if has_ci:
        headers.append(report_text(block.get("interval_label"), "interval_label"))
    cells = []
    display = lambda number: format(number * scale, f".{decimals}f")
    for analysis, (effect, estimate, se, low, high) in zip(analyses, values):
        result = [effect, display(estimate)]
        if has_analysis:
            result.insert(0, report_text(analysis, "Analysis label"))
        if has_se:
            result.append(display(se) if se is not None else missing)
        if has_ci:
            result.append(f"{display(low)} to {display(high)}" if low is not None else missing)
        cells.append(result)
    return headers, cells


def prepare_report(config_path):
    """Resolve only named files and adapt existing CSV schemas to display cells.

    Configuration is investigator-authored. No missing design, uncertainty,
    interpretation, figure or next step is inferred by this adapter.
    """
    config_path = Path(config_path).resolve(strict=True)
    config = read_config(config_path)
    if config.get("report_format", "docx") != "docx":
        raise ValueError("Only docx is supported")
    if config.get("report_template", "methods_results_next_steps") != "methods_results_next_steps":
        raise ValueError("Unsupported report template")
    if config.get("data_classification") not in {"AGGREGATE_ONLY_CONFIRMED", "SYNTHETIC_CONFIRMED"}:
        raise ValueError("An explicit aggregate-only or synthetic data_classification is required")
    language = config.get("language", "en")
    if language not in HEADINGS:
        raise ValueError("language must be en or zh-CN")
    title = report_text(config.get("title"), "title")
    bindings = [{"path": str(config_path), "sha256": sha256(config_path), "role": "config"}]

    def asset(item, role):
        name = item.get("path")
        if not isinstance(name, str) or not name or re.match(r"^[a-z]+://", name, re.I):
            raise ValueError("Assets must be explicitly named local files")
        path = (config_path.parent / name).resolve(strict=True)
        if not path.is_file():
            raise ValueError("Asset is not a file")
        digest = sha256(path)
        if item.get("sha256") and item["sha256"].lower() != digest:
            raise ValueError("Input SHA-256 mismatch: " + role)
        bindings.append({"path": str(path), "sha256": digest, "role": role})
        return path

    if "author_reference" in config:
        from .author_word import inspect_word
        reference = config["author_reference"]
        if not reference.get("sha256"):
            raise ValueError("author_reference requires a confirmed SHA-256")
        author = inspect_word(asset(reference, "author_reference"))
        if author["has_comment_markup"]:
            raise ValueError("Author comments require review before report generation")
        if reference.get("wording_reviewed") is not True:
            raise ValueError("Review accepted author wording against the report content and set wording_reviewed; identity alone is not alignment")

    study = config.get("study", {})
    if not isinstance(study, dict) or set(study) - set(STUDY_LABELS):
        raise ValueError("Unknown study fields; use explicit prose blocks for other definitions")
    for key in ("design", "population"):
        report_text(study.get(key), "study." + key)
    sections = []
    for name, heading in zip(("methods", "results", "next_steps"), HEADINGS[language]):
        source_blocks = config.get(name, [])
        if not isinstance(source_blocks, list):
            raise ValueError(name + " must be a list")
        blocks = []
        if name == "methods":
            for key, value in study.items():
                label = STUDY_LABELS[key][language == "zh-CN"]
                blocks.append({"type": "paragraph", "text": label + ": " + report_text(value, "study." + key)})
        for block in source_blocks:
            kind = block.get("type")
            if kind in ("paragraph", "heading"):
                blocks.append({"type": kind, "text": report_text(block.get("text"), kind)})
            elif kind in ("table", "effects"):
                path = asset(block, "aggregate_table")
                if path.suffix.lower() != ".csv":
                    raise ValueError("Table inputs must be CSV")
                if kind == "effects":
                    headers, rows = _effects(block, path, language)
                else:
                    fields, source_rows = _csv(path)
                    columns = block.get("columns")
                    if not isinstance(columns, list) or not columns:
                        raise ValueError("Table columns must be explicitly selected")
                    if any(col["key"] not in fields for col in columns):
                        raise ValueError("Requested table column is absent")
                    headers = [report_text(col.get("label", col["key"]), "column label") for col in columns]
                    rows = []
                    for source_row in source_rows:
                        row = []
                        for col in columns:
                            value = source_row[col["key"]]
                            if "digits" in col and value.strip().upper() not in MISSING:
                                value = format(_number(value, col["key"]), f".{_decimals(col['digits'])}f")
                            row.append(report_text(value, "table cell", empty=True))
                        rows.append(row)
                result = {"type": "table", "headers": headers, "rows": rows,
                          "caption": report_text(block.get("caption"), "table caption"),
                          "note": report_text(block.get("note", ""), "table note", empty=True)}
                if "column_widths" in block:
                    result["column_widths"] = block["column_widths"]
                blocks.append(result)
            elif kind == "figure":
                path = asset(block, "figure")
                if path.suffix.lower() not in {".png", ".jpg", ".jpeg"}:
                    raise ValueError("Figures must be existing PNG or JPEG files")
                result = {"type": kind, "path": str(path),
                          "caption": report_text(block.get("caption"), "figure caption")}
                if "width_inches" in block:
                    result["width_inches"] = block["width_inches"]
                blocks.append(result)
            else:
                raise ValueError("Unsupported report block: " + str(kind))
        if not blocks:
            raise ValueError(name + " needs explicit content; do not infer missing findings or actions")
        sections.append({"title": heading, "blocks": blocks})
    for binding in bindings:
        if sha256(binding["path"]) != binding["sha256"]:
            raise ValueError("Input changed while reading")
    return {"title": title, "language": language, "sections": sections}, bindings
