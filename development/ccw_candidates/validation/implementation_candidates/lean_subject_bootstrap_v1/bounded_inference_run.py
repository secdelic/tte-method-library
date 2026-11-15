"""One R child, existing Windows Job primitives, bounded internal candidate work."""
from pathlib import Path
import ctypes
import ctypes.wintypes as wt
import hashlib
import importlib.util
import json
import os
import subprocess
import shutil
import sys
import time

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RSCRIPT = shutil.which(os.environ.get("RSCRIPT", "Rscript"))
if not RSCRIPT:
    raise RuntimeError("Rscript is required; configure RSCRIPT or PATH")
CONTRACT = json.loads((HERE / "inputs/inference_contract_v1.json").read_text(encoding="utf-8"))
BASE = HERE.parent / "gv_oracle_staged_runner_dev_v1"

def save(path, value):
    with path.open("x", encoding="utf-8") as f:
        json.dump(value, f, ensure_ascii=False, indent=2, allow_nan=False)

def main():
    if len(sys.argv) != 3 or sys.argv[1] != "CANARY" or sys.argv[2] not in ("deterministic", "canary"):
        raise ValueError("EXPLICIT_CANARY_AND_STAGE_REQUIRED; FORMAL_ANALYSIS not authorized")
    stage = sys.argv[2]
    for name in ("run_stage.py", "evidence_abort.py"):
        path = BASE / name
        assert hashlib.sha256(path.read_bytes()).hexdigest() == CONTRACT["dependencies"][path.relative_to(ROOT).as_posix()]
    sys.path.insert(0, str(BASE))
    spec = importlib.util.spec_from_file_location("existing_job_primitives", BASE / "run_stage.py")
    legacy = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(legacy)  # Guarded main is not called; no old files written.
    output = HERE / CONTRACT["new_output_root"]
    runs = output / "executions"
    runs.mkdir(parents=True, exist_ok=True)
    receipts = [json.loads(p.read_text()) for p in runs.glob("*/execution.json")]
    used_cpu = sum(x["OS_job_cpu_seconds"] for x in receipts)
    used_wall = sum(x["wall_seconds"] for x in receipts)
    limits = CONTRACT["resource_limits"]
    if used_cpu >= limits["cumulative_cpu_seconds"] or used_wall >= limits["cumulative_execution_wall_seconds"]:
        raise RuntimeError("CUMULATIVE_RESOURCE_BUDGET_EXHAUSTED")
    number = 1
    while (runs / f"{stage}_{number:03d}").exists():
        number += 1
    attempt = runs / f"{stage}_{number:03d}"
    attempt.mkdir()
    result_dir = (attempt / "result").relative_to(HERE).as_posix()
    command = [RSCRIPT, "--vanilla",
               "test_inference.R" if stage == "deterministic" else "run_inference.R",
               "CANARY", result_dir] if stage == "deterministic" else [
               RSCRIPT, "--vanilla", "run_inference.R", "CANARY"]
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CreateJobObjectW.argtypes = [ctypes.c_void_p, wt.LPCWSTR]
    kernel.CreateJobObjectW.restype = wt.HANDLE
    kernel.SetInformationJobObject.argtypes = [wt.HANDLE, ctypes.c_int, ctypes.c_void_p, wt.DWORD]
    kernel.QueryInformationJobObject.argtypes = [wt.HANDLE, ctypes.c_int, ctypes.c_void_p, wt.DWORD, ctypes.c_void_p]
    kernel.AssignProcessToJobObject.argtypes = [wt.HANDLE, wt.HANDLE]
    kernel.TerminateJobObject.argtypes = [wt.HANDLE, wt.UINT]
    kernel.CloseHandle.argtypes = [wt.HANDLE]
    job = kernel.CreateJobObjectW(None, None)
    if not job:
        raise ctypes.WinError(ctypes.get_last_error())
    lim = legacy.ExtendedLimit()
    lim.BasicLimitInformation.LimitFlags = 0x2000 | 0x200
    lim.JobMemoryLimit = limits["RAM_bytes"]
    if not kernel.SetInformationJobObject(job, 9, ctypes.byref(lim), ctypes.sizeof(lim)):
        raise ctypes.WinError(ctypes.get_last_error())
    def usage():
        ac = legacy.Accounting(); ex = legacy.ExtendedLimit()
        if not kernel.QueryInformationJobObject(job, 1, ctypes.byref(ac), ctypes.sizeof(ac), None):
            raise ctypes.WinError(ctypes.get_last_error())
        if not kernel.QueryInformationJobObject(job, 9, ctypes.byref(ex), ctypes.sizeof(ex), None):
            raise ctypes.WinError(ctypes.get_last_error())
        return (ac.TotalUserTime + ac.TotalKernelTime) / 1e7, ex.PeakJobMemoryUsed, ac.ActiveProcesses
    env = dict(os.environ, OMP_NUM_THREADS="1", OPENBLAS_NUM_THREADS="1", MKL_NUM_THREADS="1")
    started = time.perf_counter()
    child = None; error = None; rc = None; cpu = peak = 0
    try:
        with (attempt / "stdout.log").open("x") as stdout, (attempt / "stderr.log").open("x") as stderr:
            # The R entry waits for this file before loading inputs or drawing.
            env["LEAN_JOB_ASSIGNED_FILE"] = str(attempt / "job_assigned")
            child = subprocess.Popen(command, cwd=HERE, env=env, stdout=stdout, stderr=stderr)
            if not kernel.AssignProcessToJobObject(job, wt.HANDLE(int(child._handle))):
                raise ctypes.WinError(ctypes.get_last_error())
            (attempt / "job_assigned").write_text("assigned", encoding="ascii")
            while child.poll() is None or usage()[2]:
                cpu, peak, _ = usage()
                disk = sum(p.stat().st_size for p in output.rglob("*") if p.is_file())
                reason = ("RAM" if peak > limits["RAM_bytes"] else
                          "CPU" if used_cpu + cpu > limits["cumulative_cpu_seconds"] else
                          "WALL" if used_wall + time.perf_counter() - started > limits["cumulative_execution_wall_seconds"] else
                          "OUTPUT" if disk > limits["new_output_bytes"] else None)
                if reason:
                    raise RuntimeError("RESOURCE_LIMIT_" + reason)
                time.sleep(.05)
            rc = child.returncode
            if rc:
                raise RuntimeError("CHILD_FAILED_EXIT_" + str(rc))
    except BaseException as exc:
        error = repr(exc)
        if child is not None and child.poll() is None:
            kernel.TerminateJobObject(job, 1)
            child.wait()
        if child is not None:
            rc = child.returncode
    finally:
        cpu, peak, _ = usage()
        receipt = {"stage": stage, "command": command, "status": "PASS" if error is None else "FAILED_OR_ABORTED",
                   "error": error, "exit_code": rc, "OS_job_cpu_seconds": cpu,
                   "wall_seconds": time.perf_counter() - started,
                   "peak_job_committed_bytes": peak, "measurement_scope": "Windows Job child process tree",
                   "workers": 1, "prior_cumulative_cpu_seconds": used_cpu,
                   "prior_cumulative_wall_seconds": used_wall, "limits": limits,
                   "result_directory": result_dir if stage == "deterministic" else CONTRACT["run_directory"],
                   "entry_code_sha256": hashlib.sha256((HERE / command[2]).read_bytes()).hexdigest()}
        save(attempt / "execution.json", receipt)
        if error and stage == "canary":
            run = HERE / CONTRACT["run_directory"]
            if (run / "plan.json").exists():
                tasks = json.loads((run / "plan.json").read_text())["draws"]
                events = [json.loads(s) for s in (run / "attempt_events.jsonl").read_text().splitlines()] if (run / "attempt_events.jsonl").exists() else []
                states = {t["id"]: "NOT_STARTED" for t in tasks}
                for event in events:
                    states[event["id"]] = event["state"]
                closure = {k: "ABORTED" if v == "STARTED" else v for k, v in states.items()}
                save(attempt / "abort_checkpoint.json",
                     {"reason": error, "states": closure, "unknown_in_progress_stage": "NOT_INFERRED"})
        kernel.CloseHandle(job)
        print(json.dumps(receipt), flush=True)
    if error:
        sys.exit(1)

if __name__ == "__main__":
    main()
