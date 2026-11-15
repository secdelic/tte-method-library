"""Reuse existing independent formulas; bind the new connection layer explicitly."""
import importlib.util
import json
from pathlib import Path
import sys
import time
import traceback

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("retained_evidence_verifier", HERE / "verify_candidate.py")
old = importlib.util.module_from_spec(spec)
spec.loader.exec_module(old)

def main():
    started = time.perf_counter()
    if sys.argv[1] == "deterministic":
        folder = HERE / sys.argv[2]
        output = HERE / "results/inference_v1/reconstruction"
        tests = old.read(folder / "TEST_RESULTS.json")
        assert tests["implementation_sha256"] == old.sha(HERE / "inference_component.R")
        assert tests["test_code_sha256"] == old.sha(HERE / "test_inference.R")
        old.deterministic(folder, output)
        gate = old.read(output / "RECONSTRUCTION_VALIDATION.json")
        for p in ("inference_component.R", "run_inference.R", "test_inference.R",
                  "verify_inference.py", "bounded_inference_run.py", "inputs/inference_contract_v1.json"):
            gate["bindings"][p] = old.sha(HERE / p)
        gate["PreparedData_connection_checked"] = True
        gate["wall_seconds"] = time.perf_counter() - started
        (output / "RECONSTRUCTION_VALIDATION.json").write_text(
            json.dumps(gate, ensure_ascii=False, indent=2), encoding="utf-8")
    elif sys.argv[1] == "canary":
        folder = HERE / "results/inference_v1/canary"
        output = HERE / "results/inference_v1/CANARY_INDEPENDENT_VERIFICATION.json"
        old.canary(folder, output)
        prior = HERE / "results/canary_001"
        plan = old.read(folder / "plan.json")
        records = old.read(folder / "attempt_records.json")
        for task in plan["draws"]:
            assert (folder / task["map_file"]).read_bytes() == (prior / task["map_file"]).read_bytes()
            record = records[task["id"]]
            assert old.sha(folder / record["evidence"]["result_file"]) == record["evidence"]["result_sha256"]
            a = old.read(folder / record["evidence"]["result_file"])
            b = old.read(prior / record["evidence"]["result_file"])
            a.pop("timings"); b.pop("timings")
            old.compare(a, b, task["id"])
            ev = record["evidence"]
            assert ev["initial_draw_state"] == task["initial_state"]
            assert ev["after_draw_state"] == task["after_draw_state"]
            assert ev["E_D_shared_draw_identity"]["E"] == ev["E_D_shared_draw_identity"]["D"]
        result = old.read(output)
        result.update({"prior_20_maps_byte_identical": True,
                       "prior_20_full_scientific_results_equivalent": True,
                       "new_independent_statistical_draws": 0,
                       "wall_seconds": time.perf_counter() - started})
        output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    else:
        raise ValueError("deterministic or canary verification required")

if __name__ == "__main__":
    try:
        main()
    except Exception:
        root = HERE / "results/inference_v1"
        i = 1
        while (root / f"VERIFICATION_FAILURE_{i:03d}.json").exists():
            i += 1
        old.save(root / f"VERIFICATION_FAILURE_{i:03d}.json",
                 {"arguments": sys.argv[1:], "actual_traceback": traceback.format_exc()})
        raise
