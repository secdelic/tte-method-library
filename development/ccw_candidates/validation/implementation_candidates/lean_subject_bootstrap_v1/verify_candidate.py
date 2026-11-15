"""Independent retained-evidence reconstruction and arithmetic checks; no RNG."""
import ast
import collections
from fractions import Fraction
import hashlib
import json
import math
from pathlib import Path
import statistics
import struct
import sys
import traceback

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
VIEWS = ("artificial_censors", "terminal_settlements", "entry_members", "entry_weight_ledger")

def read(path):
    return json.loads(path.read_text(encoding="utf-8"))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def save(path, value):
    with path.open("x", encoding="utf-8") as f:
        json.dump(value, f, ensure_ascii=False, indent=2, allow_nan=False)

def arr(x):
    return x if isinstance(x, list) else [] if x is None else [x]

def finite_close(a, b):
    return a is None if b is None else (
        a is not None and math.isfinite(a) and abs(a-float(b)) <= 1e-12+1e-10*abs(float(b)))

def compare(a, b, path=""):
    if isinstance(b, dict):
        assert isinstance(a, dict) and a.keys() == b.keys(), ("FIELDS", path)
        for k in b:
            compare(a[k], b[k], path+"/"+k)
    elif isinstance(b, list):
        assert isinstance(a, list) and len(a) == len(b), ("LENGTH", path)
        for i, (x, y) in enumerate(zip(a, b)):
            compare(x, y, path+"/"+str(i))
    elif isinstance(b, (int, float)) and not isinstance(b, bool):
        assert finite_close(a, b), ("NUMBER", path, a, b)
    else:
        assert a == b, ("VALUE", path, a, b)

def normalize_views(result):
    out = {k: result[k] for k in VIEWS}
    out["artificial_censors"] = {g: arr(v) for g, v in out["artificial_censors"].items()}
    out["terminal_settlements"] = {
        g: [dict(z, ids=arr(z["ids"])) for z in arr(v)]
        for g, v in out["terminal_settlements"].items()}
    out["entry_members"] = {g: [arr(v) for v in stages] for g, stages in out["entry_members"].items()}
    out["entry_weight_ledger"] = {
        g: [arr(v) for v in stages] for g, stages in out["entry_weight_ledger"].items()}
    return out

def reconstruct_views(source, indices, saved):
    """Reconstruct the four omitted views from source, complete map and saved fits.

    Does not call the R engine, fit a model, rerun RNG, or invent errors/warnings.
    This formula applies only to the sealed GV-ORACLE synthetic policy adapter.
    """
    ss = source["subjects"]
    m = collections.Counter(indices)
    active = [i for i, s in enumerate(ss)
              if m[i+1] and (s["actual_effective_start_time"] is None or s["actual_effective_start_time"] >= 0)
              and (s["terminal_time"] is None or s["terminal_time"] > 0)]
    out = {k: {} for k in VIEWS}
    for g in ("E", "D"):
        ac = {}
        for i in active:
            s = ss[i]; st = s["actual_effective_start_time"]; tt = s["terminal_time"]
            if g == "E":
                ac[i] = 3 if (st is None or st > 3) and (tt is None or tt > 3) else None
            else:
                ac[i] = st if st is not None and st <= 3 and (tt is None or st < tt) else None
        out["artificial_censors"][g] = [
            {"id": ss[i]["id"], "k": ac[i]}
            for i in sorted(active, key=lambda i: (99 if ac[i] is None else ac[i], i))
            if ac[i] is not None]
        terminal = []
        for k in range(1, 6):
            ids = [ss[i]["id"] for i in active if ss[i]["terminal_time"] == k
                   and (ac[i] is None or k <= ac[i])]
            if ids:
                terminal.append({"k": k, "ids": ids})
        out["terminal_settlements"][g] = terminal
        members = []; ledgers = []
        for k in range(5):
            ix = [i for i in active if (ss[i]["terminal_time"] is None or ss[i]["terminal_time"] > k)
                  and (ac[i] is None or ac[i] > k)]
            members.append([ss[i]["id"] for i in ix])
            rows = []
            for i in ix:
                s = ss[i]; history = {h["k"]: h["L"] for h in s["history"]}
                times = ([3] if k >= 3 and s["actual_effective_start_time"] == 3 else []) if g == "E" else range(min(k, 3)+1)
                weight = 1.0
                for j in times:
                    q = saved["fits"][f'c{j}_{s["W"]}_{history[j]}']["q"]
                    denominator = q if g == "E" else 1-q if q is not None else None
                    if denominator is None or denominator <= 0:
                        weight = None; break
                    weight /= denominator
                if weight is not None and (not math.isfinite(weight) or weight < 0):
                    weight = None
                rows.append({"id": s["id"], "weight": weight,
                             "multiplicity": m[i+1], "event": s["terminal_time"] == k+1})
            ledgers.append(rows)
        out["entry_members"][g] = members
        out["entry_weight_ledger"][g] = ledgers
    return out

def frozen_function(path, name, namespace):
    # Reuse the exact existing pure comparator function without importing its
    # CLI, historical output writers or unrelated preparation modules.
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    node = next(x for x in tree.body if isinstance(x, ast.FunctionDef) and x.name == name)
    code = compile(ast.fix_missing_locations(ast.Module(body=[node], type_ignores=[])), str(path), "exec")
    exec(code, namespace)
    return namespace[name]

def comparators():
    base = HERE.parent
    audit = frozen_function(base/"gv_oracle_core_optimization_v1/finalize_evidence.py",
        "independent_audit", {"Counter": collections.Counter, "Fraction": Fraction,
                             "arr": arr, "finite_close": finite_close})
    risk = frozen_function(base/"gv_oracle_staged_runner_dev_v1/verify_pilot.py",
        "independent_risk", {"F": Fraction, "Counter": collections.Counter,
                            "defaultdict": collections.defaultdict,
                            "rat": lambda z: Fraction(z["numerator"], z["denominator"])})
    return audit, risk

def check_sample(source, indices, mode, result):
    audit, risk = comparators()
    full = dict(result, **reconstruct_views(source, indices, result))
    a = audit(len(source["subjects"]), {"map_id": "LEAN_RETAINED_EVIDENCE",
        "indices": indices, "forced_fit_failures": source.get("forced_fit_failures", [])}, mode, full, source)
    refs, hazards = risk(source, indices, mode)
    for key, (status, value) in refs.items():
        assert result["components"][key]["source_status"] == status
        assert finite_close(result["components"][key]["value"], value)
        if key.endswith("_PL") and hazards[key[0]] is not None:
            observed = result["components"][key].get("hazards", [])
            expected = hazards[key[0]]
            assert len(observed) == len(expected)
            for x, y in zip(observed, expected):
                assert x["status"] == y["status"]
                for field in ("numerator", "denominator", "hazard"):
                    assert finite_close(x[field], y[field])
    e, d = refs["E_PL"][1], refs["D_PL"][1]
    assert finite_close(result["contrasts"]["RD"]["value"], None if e is None or d is None else e-d)
    assert finite_close(result["contrasts"]["RR"]["value"], None if e is None or d is None or d == 0 else e/d)
    return a

def deterministic(folder, output):
    assert read(folder/"TEST_RESULTS.json")["status"] == "PASS"
    fixtures = read(HERE.parent/"gv_oracle_minimal_core_v1/inputs/small_fixtures.json")
    sources = {c["case_id"]: c for c in fixtures["cases"]}
    cases = read(folder/"sealed_boundary_results.json")
    for label, z in cases.items():
        reconstructed = reconstruct_views(sources[z["case_id"]], z["indices"], z["result"])
        compare(reconstructed, normalize_views(z["result"]), label)
    probe = read(folder/"retention_probe_full.json")
    assert sha(ROOT/probe["source_file"]) == probe["source_sha256"]
    source = read(ROOT/probe["source_file"])
    compare(reconstruct_views(source, probe["indices"], probe["result"]),
            normalize_views(probe["result"]), "PRESPECIFIED_NONRANDOM_MAP")
    check_sample(source, probe["indices"], probe["mode"], probe["result"])
    arithmetic = read(folder/"arithmetic_fixtures_and_results.json")
    records = list(arithmetic["records"].values())
    for key in ("R_E", "R_D", "RD", "RR"):
        values = sorted(z["estimates"][key]["value"] for z in records)
        if key == "RR":
            values = [math.log(x) for x in values]
        ends = [values[math.ceil(len(values)*p)-1] for p in (.025, .975)]
        if key == "RR":
            ends = [math.exp(x) for x in ends]
        compare(arithmetic["summary"]["estimands"][key]["CI"], ends, "INDEPENDENT_RANK/"+key)
    mat = [[z["estimates"][key]["value"] for key in ("R_E","R_D","RD","RR")] for z in records]
    means = [statistics.mean(row[j] for row in mat) for j in range(4)]
    cov = [[sum((row[i]-means[i])*(row[j]-means[j]) for row in mat)/(len(mat)-1)
            for j in range(4)] for i in range(4)]
    compare(arithmetic["summary"]["covariance"]["value"], cov, "INDEPENDENT_PAIRED_COVARIANCE")
    output.mkdir()
    gate = {"status": "PASS", "scope": "SEALED_SYNTHETIC_GV_ORACLE_ADAPTER_ONLY",
            "boundary_case_modes": len(cases), "prespecified_nonrandom_N1000_map": True,
            "all_four_omitted_views_reconstructed": True, "new_random_draws": 0,
            "independent_type1_logRR_covariance": True,
            "test_directory": folder.relative_to(HERE).as_posix(),
            "bindings": {p: sha(HERE/p) for p in
                         ("bootstrap.R", "verify_candidate.py", "inputs/development_contract.json")},
            "retained_errors_or_warnings_recreated": False}
    save(output/"RECONSTRUCTION_VALIDATION.json", gate)
    print(json.dumps({k: v for k, v in gate.items() if k != "bindings"}))

def canary(folder, output):
    contract = read(HERE/"inputs/development_contract.json")
    source = read(ROOT/contract["source_file"])
    assert sha(ROOT/contract["source_file"]) == contract["source_sha256"]
    plan = read(folder/"plan.json")
    records = read(folder/"attempt_records.json")
    summary = read(folder/"summary.json")
    assert len(plan["draws"]) == contract["B"] == 20
    audits = []
    original = read(folder/"original_compact.json")
    assert not any(k in original for k in VIEWS)
    audits.append(check_sample(source, list(range(1,contract["N"]+1)), "Q_SAT", original))
    events = [json.loads(line) for line in (folder/"attempt_events.jsonl").read_text().splitlines()]
    for task in plan["draws"]:
        idx = list(struct.unpack("<"+"i"*contract["N"], (folder/task["map_file"]).read_bytes()))
        assert len(idx) == contract["N"] and all(1<=i<=contract["N"] for i in idx)
        assert sha(folder/task["map_file"]) == task["map_sha256"]
        record = records[task["id"]]
        assert record["state"] in ("COMPLETED","PARTIALLY_FAILED","FAILED"), record["state"]
        assert record["error"] is None
        assert sum(e["id"] == task["id"] and e["state"] == "STARTED" for e in events) == 1
        assert next(e for e in events if e["id"] == task["id"] and e["state"] != "STARTED") == record
        result = read(folder/record["evidence"]["result_file"])
        assert not any(k in result for k in VIEWS)
        assert record["evidence"]["after_draw_state"] == record["evidence"]["after_refit_state"]
        audits.append(check_sample(source, idx, "Q_SAT", result))
    counts = summary["accounting"]
    assert counts["requested"] == counts["attempted"] == 20 and counts["not_started"] == 0
    assert sum(counts[k] for k in ("completed","partially_failed","failed","aborted")) == 20
    for key, z in summary["estimands"].items():
        cc = z["draw_counts"]
        assert cc["point_available"]+cc["scientific_nonestimable"]+cc["execution_unavailable"] == 20
        assert cc["CI_eligible"]+cc["CI_unavailable"] == 20
        assert z["CI"] == [None,None]
    assert summary["formal_CI_computed"] is False and summary["formal_SE_computed"] is False
    assert summary["covariance"]["value"] is None
    result = {"status": "PASS", "random_canary_draws": 20, "point_plus_draw_independent_audits": len(audits),
              "independent_source_map_counts_fits_PL_HT_RD_RR_verified": True,
              "complete_ordered_maps_and_rng_states_verified": True,
              "formal_CI_SE_covariance_computed": False, "audit_details": audits,
              "conclusion": "BOUNDED_SYNTHETIC_EXECUTION_ONLY_NOT_COVERAGE_OR_PRODUCTION"}
    save(output, result)
    print(json.dumps({k: v for k, v in result.items() if k != "audit_details"}))

if __name__ == "__main__":
    try:
        if sys.argv[1] == "deterministic":
            deterministic(HERE/sys.argv[2], HERE/sys.argv[3])
        elif sys.argv[1] == "canary":
            canary(HERE/sys.argv[2], HERE/sys.argv[3])
        else:
            raise ValueError("Unknown verification mode")
    except Exception:
        existing = list((HERE/"results").glob("INDEPENDENT_CHECK_FAILURE_*.json"))
        save(HERE/"results"/f"INDEPENDENT_CHECK_FAILURE_{len(existing)+1:03}.json",
             {"status": "FAIL", "arguments": sys.argv[1:], "traceback": traceback.format_exc()})
        raise
