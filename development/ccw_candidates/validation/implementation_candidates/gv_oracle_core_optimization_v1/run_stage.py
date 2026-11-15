"""One sequential child, bounded scoped runs and append-only attempt artifacts."""
from pathlib import Path
import ctypes,ctypes.wintypes as wt,json,subprocess,sys,time,os,hashlib
HERE=Path(__file__).resolve().parent
class Memory(ctypes.Structure):
    _fields_=[('cb',wt.DWORD),('PageFaultCount',wt.DWORD)]+[(s,ctypes.c_size_t) for s in ['PeakWorkingSetSize','WorkingSetSize','QuotaPeakPagedPoolUsage','QuotaPagedPoolUsage','QuotaPeakNonPagedPoolUsage','QuotaNonPagedPoolUsage','PagefileUsage','PeakPagefileUsage']]
class BasicLimit(ctypes.Structure):
    _fields_=[('PerProcessUserTimeLimit',ctypes.c_longlong),('PerJobUserTimeLimit',ctypes.c_longlong),('LimitFlags',wt.DWORD),('MinimumWorkingSetSize',ctypes.c_size_t),('MaximumWorkingSetSize',ctypes.c_size_t),('ActiveProcessLimit',wt.DWORD),('Affinity',ctypes.c_size_t),('PriorityClass',wt.DWORD),('SchedulingClass',wt.DWORD)]
class IOCounters(ctypes.Structure):
    _fields_=[(x,ctypes.c_ulonglong) for x in ['ReadOperationCount','WriteOperationCount','OtherOperationCount','ReadTransferCount','WriteTransferCount','OtherTransferCount']]
class ExtendedLimit(ctypes.Structure):
    _fields_=[('BasicLimitInformation',BasicLimit),('IoInfo',IOCounters),('ProcessMemoryLimit',ctypes.c_size_t),('JobMemoryLimit',ctypes.c_size_t),('PeakProcessMemoryUsed',ctypes.c_size_t),('PeakJobMemoryUsed',ctypes.c_size_t)]
class Accounting(ctypes.Structure):
    _fields_=[(x,ctypes.c_longlong) for x in ['TotalUserTime','TotalKernelTime','ThisPeriodTotalUserTime','ThisPeriodTotalKernelTime']]+[(x,wt.DWORD) for x in ['TotalPageFaultCount','TotalProcesses','ActiveProcesses','TotalTerminatedProcesses']]
def write(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def main():
    tag=sys.argv[1];command=sys.argv[2:];runs=HERE/'runs';runs.mkdir(exist_ok=True)
    statefile=runs/'resource_ledger.json';state=json.loads(statefile.read_text()) if statefile.exists() else {'start_epoch':time.time(),'completed_child_CPU_seconds':0,'attempts':[]}
    # A user-aborted turn can leave hours of inactive chat time between runs.
    # Retain the calendar anchor, CPU and every attempt; cap cumulative actual
    # process-tree execution wall rather than counting the human pause as CPU work.
    if 'completed_child_wall_seconds' not in state:
        state['completed_child_wall_seconds']=sum(json.loads((HERE/a/'execution.json').read_text())['wall_seconds'] for a in state['attempts'])
    n=1
    while (runs/f'{tag}_{n:03d}').exists():n+=1
    attempt=runs/f'{tag}_{n:03d}';attempt.mkdir()
    env=os.environ.copy();env.update({'OMP_NUM_THREADS':'1','OPENBLAS_NUM_THREADS':'1','MKL_NUM_THREADS':'1','R_ENABLE_JIT':'0'})
    ps=ctypes.WinDLL('psapi');ps.GetProcessMemoryInfo.argtypes=[wt.HANDLE,ctypes.POINTER(Memory),wt.DWORD]
    kernel=ctypes.WinDLL('kernel32');kernel.GetProcessTimes.argtypes=[wt.HANDLE,*([ctypes.POINTER(wt.FILETIME)]*4)]
    kernel.CreateJobObjectW.argtypes=[ctypes.c_void_p,wt.LPCWSTR];kernel.CreateJobObjectW.restype=wt.HANDLE
    kernel.SetInformationJobObject.argtypes=[wt.HANDLE,ctypes.c_int,ctypes.c_void_p,wt.DWORD]
    kernel.QueryInformationJobObject.argtypes=[wt.HANDLE,ctypes.c_int,ctypes.c_void_p,wt.DWORD,ctypes.c_void_p]
    kernel.AssignProcessToJobObject.argtypes=[wt.HANDLE,wt.HANDLE]
    kernel.TerminateJobObject.argtypes=[wt.HANDLE,wt.UINT];kernel.CloseHandle.argtypes=[wt.HANDLE]
    job=kernel.CreateJobObjectW(None,None)
    if not job:raise ctypes.WinError()
    lim=ExtendedLimit();lim.BasicLimitInformation.LimitFlags=0x2000|0x200;lim.JobMemoryLimit=4*2**30
    if not kernel.SetInformationJobObject(job,9,ctypes.byref(lim),ctypes.sizeof(lim)):raise ctypes.WinError()
    def job_usage():
        ac=Accounting();ex=ExtendedLimit()
        if not kernel.QueryInformationJobObject(job,1,ctypes.byref(ac),ctypes.sizeof(ac),None):raise ctypes.WinError()
        if not kernel.QueryInformationJobObject(job,9,ctypes.byref(ex),ctypes.sizeof(ex),None):raise ctypes.WinError()
        return (ac.TotalUserTime+ac.TotalKernelTime)/10**7,ex.PeakJobMemoryUsed,ac.ActiveProcesses,ac.TotalProcesses
    def cpu(handle):
        v=[wt.FILETIME() for _ in range(4)]
        if not kernel.GetProcessTimes(handle,*[ctypes.byref(x) for x in v]):raise ctypes.WinError()
        return sum(x.dwHighDateTime*2**32+x.dwLowDateTime for x in v[2:])/10**7
    def memory(handle):
        mem=Memory();mem.cb=ctypes.sizeof(mem)
        if not ps.GetProcessMemoryInfo(handle,ctypes.byref(mem),mem.cb):raise ctypes.WinError()
        return mem.PeakWorkingSetSize
    source_hashes={p.relative_to(HERE).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('*') if p.suffix in ['.py','.R']}
    snap=attempt/'source_snapshot';snap.mkdir()
    for p in HERE.glob('*'):
        if p.suffix in ['.py','.R']:(snap/p.name).write_bytes(p.read_bytes())
    meta={'command':command,'source_sha256':source_hashes,'status':'STARTED','workers':1,'scientific_RNG':'NOT_USED','start_epoch':time.time()}
    write(attempt/'execution.json',meta);t=time.perf_counter();peak=0;rc=None;error=None;used=0
    try:
        with (attempt/'stdout.log').open('x',encoding='utf-8') as out,(attempt/'stderr.log').open('x',encoding='utf-8') as err:
            child=subprocess.Popen(command,cwd=HERE,env=env,stdout=out,stderr=err)
            handle=wt.HANDLE(int(child._handle))
            if not kernel.AssignProcessToJobObject(job,handle):raise ctypes.WinError()
            while child.poll() is None or job_usage()[2]>0:
                used,jobpeak,active,total_processes=job_usage();peak=max(peak,jobpeak)
                disk=sum(p.stat().st_size for p in HERE.rglob('*') if p.is_file())
                violation='RAM' if peak>4*2**30 else 'CPU' if state['completed_child_CPU_seconds']+used>7200 else 'WALL' if state['completed_child_wall_seconds']+time.perf_counter()-t>14400 else 'DISK' if disk>2*2**30 else None
                if violation:kernel.TerminateJobObject(job,1);child.wait();raise RuntimeError('RESOURCE_LIMIT_'+violation)
                time.sleep(.05)
            rc=child.returncode;used,jobpeak,active,total_processes=job_usage();peak=max(peak,jobpeak)
            if rc:raise RuntimeError('CHILD_FAILED_EXIT_'+str(rc))
        meta['status']='COMPLETED'
    except BaseException as e:
        error=repr(e);meta['status']='FAILED_OR_ABORTED';meta['error']=error
    finally:
        meta.update({'exit_code':rc,'wall_seconds':time.perf_counter()-t,'OS_child_cpu_seconds':used,'peak_job_committed_bytes':peak,'measurement_scope':'WINDOWS_JOB_ALL_DESCENDANTS','job_total_processes':job_usage()[3]})
        write(attempt/'execution.json',meta)
        state['completed_child_wall_seconds']+=meta['wall_seconds']
        state['completed_child_CPU_seconds']+=used;state['attempts'].append(str(attempt.relative_to(HERE)));write(statefile,state)
        print(json.dumps(meta,ensure_ascii=False),flush=True)
        kernel.CloseHandle(job)
    if error:sys.exit(1)
if __name__=='__main__':main()
