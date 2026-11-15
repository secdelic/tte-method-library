"""Sequential isolated reference run. Failed attempts are never removed."""
from pathlib import Path
import ctypes,ctypes.wintypes as wt,subprocess,sys,hashlib,json,time,datetime
HERE=Path(__file__).resolve().parent
LIMITS={'workers':1,'RAM_bytes':4*2**30,'disk_bytes':5*2**30,'cpu_seconds':7200,'wall_seconds':14400}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(path,x):path.write_text(json.dumps(x,ensure_ascii=False,sort_keys=True,indent=2)+'\n',encoding='utf-8')
class Memory(ctypes.Structure):
    _fields_=[('cb',wt.DWORD),('PageFaultCount',wt.DWORD)]+[(n,ctypes.c_size_t) for n in ['PeakWorkingSetSize','WorkingSetSize','QuotaPeakPagedPoolUsage','QuotaPagedPoolUsage','QuotaPeakNonPagedPoolUsage','QuotaNonPagedPoolUsage','PagefileUsage','PeakPagefileUsage']]
def main():
    assert sys.version_info[:3]==(3,12,14)
    assert not (HERE/'runs'/'attempt_001').exists(),'Existing attempt preserved; use explicit new version/attempt after review.'
    run=HERE/'runs'/'attempt_001';run.mkdir(parents=True)
    sources={p.name:sha(p) for p in sorted(HERE.glob('*.py'))}
    source_copy=run/'source_snapshot';source_copy.mkdir()
    for name in sources:(source_copy/name).write_bytes((HERE/name).read_bytes())
    start=time.perf_counter();cpu_total=0;tasks=[]
    env={'python_version':sys.version,'executable':sys.executable,'executable_sha256':sha(Path(sys.executable)),
      'platform':sys.platform,'limits':LIMITS,'start_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
      'source_sha256':sources,'randomness':'NONE_DETERMINISTIC','execution':'REFERENCE_ONLY','status':'RUNNING'}
    dump(run/'execution_manifest.json',env)
    try:
        if not (HERE/'inputs'/'expanded_parameters.json').exists():
            tasks.append(('expand','expand_inputs.py',[]))
        tasks.extend([('dp','ref_dp.py',[str(HERE/'inputs'/'expanded_parameters.json'),str(run/'dp_exact.json')]),
                      ('enum','ref_enum.py',[str(HERE/'inputs'/'expanded_parameters.json'),str(run/'enum_exact.json')]),
                      ('analytic','ref_analytic.py',[str(HERE/'inputs'/'expanded_parameters.json'),str(run)])])
        stages=[]
        for name,script,args in tasks:
            meter=run/(name+'_resources.json')
            command=[sys.executable,'-X','utf8',str(HERE/'measure_child.py'),str(meter),str(HERE/script),*args]
            with (run/(name+'.stdout.log')).open('x',encoding='utf-8') as stdout,(run/(name+'.stderr.log')).open('x',encoding='utf-8') as stderr:
                child=subprocess.Popen(command,stdout=stdout,stderr=stderr,cwd=HERE)
                psapi=ctypes.WinDLL('psapi');psapi.GetProcessMemoryInfo.argtypes=[wt.HANDLE,ctypes.POINTER(Memory),wt.DWORD]
                kernel=ctypes.WinDLL('kernel32');kernel.GetProcessTimes.argtypes=[wt.HANDLE,*([ctypes.POINTER(wt.FILETIME)]*4)]
                while child.poll() is None:
                    mem=Memory();mem.cb=ctypes.sizeof(mem)
                    if psapi.GetProcessMemoryInfo(wt.HANDLE(int(child._handle)),ctypes.byref(mem),mem.cb):
                        if mem.PeakWorkingSetSize>LIMITS['RAM_bytes']:
                            child.kill();child.wait();raise RuntimeError('RAM_LIMIT; failed artifacts preserved')
                    times=[wt.FILETIME() for _ in range(4)]
                    if kernel.GetProcessTimes(wt.HANDLE(int(child._handle)),*[ctypes.byref(v) for v in times]):
                        seconds=sum((v.dwHighDateTime*2**32+v.dwLowDateTime) for v in times[2:])/10**7
                        if cpu_total+seconds>LIMITS['cpu_seconds']:
                            child.kill();child.wait();raise RuntimeError('CPU_LIMIT; failed artifacts preserved')
                    if time.perf_counter()-start>LIMITS['wall_seconds']:
                        child.kill();child.wait();raise RuntimeError('WALL_LIMIT; failed artifacts preserved')
                    if sum(p.stat().st_size for p in HERE.rglob('*') if p.is_file())>LIMITS['disk_bytes']:
                        child.kill();child.wait();raise RuntimeError('DISK_LIMIT; failed artifacts preserved')
                    time.sleep(.05)
            resources=json.loads(meter.read_text()) if meter.exists() else None
            stages.append({'stage':name,'command':command,'returncode':child.returncode,'resources':resources})
            dump(run/'stage_execution_log.json',stages)
            assert child.returncode==0,('REFERENCE_STAGE_FAILED',name,child.returncode)
            cpu_total+=resources['cpu_seconds']
            assert cpu_total<LIMITS['cpu_seconds'] and resources['peak_working_set_bytes']<=LIMITS['RAM_bytes']
            print(json.dumps({'stage':name,'status':'COMPLETE','resources':resources}),flush=True)
        env['status']='REFERENCE_RESULTS_GENERATED_AWAITING_REVIEW'
    except BaseException as error:
        env['status']='INDEPENDENT_REFERENCE_VALIDATION_BLOCKED';env['error']=repr(error)
        raise
    finally:
        env['wall_seconds']=time.perf_counter()-start;env['child_cpu_seconds']=cpu_total
        env['stored_bytes']=sum(p.stat().st_size for p in HERE.rglob('*') if p.is_file())
        env['current_source_sha256']={p.name:sha(p) for p in HERE.glob('*.py')}
        env['input_sha256']={str(p.relative_to(HERE)):sha(p) for p in (HERE/'inputs').glob('*') if p.is_file()}
        dump(run/'execution_manifest.json',env)
        dump(run/'file_sha256.json',{str(p.relative_to(HERE)):sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p.name!='file_sha256.json'})
if __name__=='__main__':main()
