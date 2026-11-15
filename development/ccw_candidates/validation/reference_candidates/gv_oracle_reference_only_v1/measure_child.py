"""Standard-library process metering, not scientific result computation."""
from pathlib import Path
import ctypes,ctypes.wintypes as wt,json,runpy,sys,time
class Memory(ctypes.Structure):
    _fields_=[('cb',wt.DWORD),('PageFaultCount',wt.DWORD)]+[(n,ctypes.c_size_t) for n in ['PeakWorkingSetSize','WorkingSetSize','QuotaPeakPagedPoolUsage','QuotaPagedPoolUsage','QuotaPeakNonPagedPoolUsage','QuotaNonPagedPoolUsage','PagefileUsage','PeakPagefileUsage']]
metric_path=Path(sys.argv[1]);script=sys.argv[2];arguments=sys.argv[3:]
t=time.perf_counter();c=time.process_time();success=False
try:
    sys.argv=[script,*arguments];runpy.run_path(script,run_name='__main__');success=True
finally:
    mem=Memory();mem.cb=ctypes.sizeof(mem)
    kernel=ctypes.WinDLL('kernel32');kernel.GetCurrentProcess.restype=wt.HANDLE
    psapi=ctypes.WinDLL('psapi');psapi.GetProcessMemoryInfo.argtypes=[wt.HANDLE,ctypes.POINTER(Memory),wt.DWORD]
    if not psapi.GetProcessMemoryInfo(kernel.GetCurrentProcess(),ctypes.byref(mem),mem.cb):raise ctypes.WinError()
    metrics={'success':success,'wall_seconds':time.perf_counter()-t,'cpu_seconds':time.process_time()-c,
      'peak_working_set_bytes':mem.PeakWorkingSetSize,'peak_pagefile_bytes':mem.PeakPagefileUsage,'python':sys.version,'executable':sys.executable}
    metric_path.write_text(json.dumps(metrics,indent=2),encoding='utf-8')
