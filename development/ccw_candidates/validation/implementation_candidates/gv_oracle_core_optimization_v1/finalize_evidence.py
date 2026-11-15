from pathlib import Path
from fractions import Fraction
from collections import Counter
import json,hashlib,statistics,math,time,importlib.util
from verify_optimization import read,sha,science,compare
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2];OLD=HERE.parent/'gv_oracle_minimal_core_v1'
OUT=ROOT/'output/gv_oracle_core_optimization_v1'
spec=importlib.util.spec_from_file_location('identity',ROOT/'output/gv_oracle_f1_independent_scientific_audit_v1/prepare.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def save(p,x):
    with p.open('x',encoding='utf-8',newline='\n')as f:json.dump(x,f,ensure_ascii=False,indent=2);f.write('\n')
def arr(x):return x if isinstance(x,list) else [] if x is None else [x]
def finite_close(a,b):
    if b is None:return a is None
    return a is not None and math.isfinite(a) and abs(a-float(b))<=1e-12+1e-10*abs(float(b))
def field_bytes(p,field):
    s=p.read_text(encoding='utf-8');key='"'+field+'":';i=s.index(key)+len(key)
    while s[i].isspace():i+=1
    _,end=json.JSONDecoder().raw_decode(s,i)
    return len(s[i:end].encode('utf-8'))
def stat(v):return {'min':min(v),'mean':statistics.mean(v),'median':statistics.median(v),'max':max(v)}
def independent_audit(N,mapping,mode,actual,spec):
    subjects=spec['subjects'];mult=Counter(mapping['indices']);active=[i for i in range(N)if mult[i+1]>0]
    starts=[s['actual_effective_start_time']for s in subjects];tt=[s['terminal_time']for s in subjects]
    L=[{h['k']:h['L']for h in s['history']}for s in subjects]
    req={z:set()for z in ['E_PL','D_PL','E_HT','D_HT']};prefixes={};members={};expected_ac={};expected_terminal={}
    def cell(i,k):return f'c{k}_{subjects[i]["W"]}_{L[i][k]}'
    def censor(i,g):
        t=tt[i];st=starts[i]
        if g=='E':return 3 if (t is None or t>3)and(st is None or st>3) else None
        return st if st is not None and st<=3 and(t is None or st<t)else None
    for g in ['E','D']:
        ac={i:censor(i,g)for i in active};expected_ac[g]=sorted((subjects[i]['id'],ac[i])for i in active if ac[i]is not None)
        expected_terminal[g]=sorted((subjects[i]['id'],tt[i])for i in active if tt[i]is not None and(ac[i]is None or tt[i]<=ac[i]))
        for k in range(5):
            ix=[i for i in active if(tt[i]is None or tt[i]>k)and(ac[i]is None or ac[i]>k)]
            members[g,k]=ix;prefixes[g,k]={}
            for i in ix:
                cells=([cell(i,3)]if k>=3 and starts[i]==3 else [])if g=='E'else[cell(i,j)for j in range(min(k,3)+1)]
                prefixes[g,k][i]=cells;req[g+'_PL'].update(cells)
                if tt[i]==k+1:req[g+'_HT'].update(cells)
    for output in req:assert sorted(arr(actual['required_cells'][output]))==sorted(req[output]),('RECONSTRUCT_REQUIRED',N,mapping['map_id'],mode,output)
    counts={};qs={}
    for c in sorted(set.union(*req.values())):
        k,w,l=map(int,c[1:].split('_'))
        fit_ix=[i for i in active if(tt[i]is None or tt[i]>k)and(starts[i]is None or starts[i]>=k)and subjects[i]['W']==w and L[i][k]==l]
        n=sum(mult[i+1]for i in fit_ix);d=sum(mult[i+1]for i in fit_ix if starts[i]==k)
        counts[c]={'n':n,'d':d}
        assert actual['P_counts'][c]==counts[c],('INDEPENDENT_P_COUNT',N,c)
        if mode=='KNOWN':q=spec['known_q'][c];qs[c]=Fraction(q['numerator'],q['denominator'])
        else:qs[c]=Fraction(d,n)if 0<d<n and c not in mapping.get('forced_fit_failures',[])else None
        consumers=[z for z in ['E_PL','D_PL','E_HT','D_HT']if c in req[z]]
        assert arr(actual['fits'][c]['consumers'])==consumers
        assert finite_close(actual['fits'][c]['q'],qs[c])
    rows_checked=0;stages_checked=0
    for g in ['E','D']:
        assert sorted((z['id'],z['k'])for z in arr(actual['artificial_censors'][g]))==expected_ac[g]
        assert sorted((i,z['k'])for z in arr(actual['terminal_settlements'][g])for i in arr(z['ids']))==expected_terminal[g]
        for k in range(5):
            ix=members[g,k];assert arr(actual['entry_members'][g][k])==[subjects[i]['id']for i in ix]
            ledger=arr(actual['entry_weight_ledger'][g][k]);assert len(ledger)==len(ix)
            good=[]
            for i,z in zip(ix,ledger):
                w=Fraction(1)
                for c in prefixes[g,k][i]:
                    q=qs[c]
                    if q is None or(g=='E'and q==0)or(g=='D'and q==1):w=None;break
                    w/=q if g=='E'else 1-q
                assert z['id']==subjects[i]['id']and z['multiplicity']==mult[i+1]and z['event']==(tt[i]==k+1)
                assert finite_close(z['weight'],w),('INDEPENDENT_STOPPED_WEIGHT',N,mapping['map_id'],mode,g,k,i)
                good.append((mult[i+1],w));rows_checked+=1
            if good and all(w is not None for _,w in good):
                s1=sum(mi*w for mi,w in good);s2=sum(mi*w*w for mi,w in good)
                for key,expected in [('S1',s1),('S2',s2),('ESS',s1*s1/s2)]:assert finite_close(actual['entry_ESS'][g][k][key],expected)
            stages_checked+=1
    return {'N':N,'map_id':mapping['map_id'],'mode':mode,'status':'PASS','risk_stages_checked':stages_checked,'individual_weight_rows_checked':rows_checked}
def main():
    assert read(HERE/'runs/audit_full_001/execution.json')['status']=='COMPLETED','FULL_AUDIT_MUST_FINISH_BEFORE_READING'
    assert read(HERE/'results/verification_001.json')['status']=='PASS'
    rounds=['paired_replay_001','paired_replay_002_complete'];records=[];pairs=[];audit=[]
    for rid,d in enumerate(rounds,1):
        folder=HERE/'results'/d;rows=read(folder/'paired_timing_ledger.json')['records'];assert len(rows)==64
        for r in rows:
            n=r['N'];spec=read(OLD/f'inputs/engineering_N{n}.json');mapping=next(x for x in spec['maps']if x['map_id']==r['map_id'])
            a=read(folder/r['result_file']);stem=Path(r['result_file']).name
            compare(science(a),science(read(OLD/'results/engineering_attempt_002'/stem)),f'ROUND_{rid}/{r["result_file"]}')
            ix=(folder/r['full_index_file']).read_bytes();assert hashlib.sha256(ix).hexdigest()==mapping['uncompressed_int32_sha256']
            r.update({'round':rid,'result_bytes':(folder/r['result_file']).stat().st_size,'full_index_bytes':len(ix),
              'AC_value_bytes':field_bytes(folder/r['result_file'],'artificial_censors'),
              'terminal_value_bytes':field_bytes(folder/r['result_file'],'terminal_settlements')})
            records.append(r)
        for n in [1000,5000]:
            for mapping in read(OLD/f'inputs/engineering_N{n}.json')['maps']:
                for mode in ['KNOWN','Q_SAT']:
                    pp=[r for r in rows if r['N']==n and r['map_id']==mapping['map_id']and r['mode']==mode]
                    assert len(pp)==2
                    aa={r['version']:r for r in pp}
                    assert [aa['baseline']['order_in_pair'],aa['optimized']['order_in_pair']]==([1,2]if (aa['baseline']['pair_id']+rid)%2==0 else[2,1])
                    pairs.append({'round':rid,'N':n,'mode':mode,'map_id':mapping['map_id'],
                      'baseline_CPU':aa['baseline']['R_process_CPU_seconds'],'optimized_CPU':aa['optimized']['R_process_CPU_seconds'],
                      'baseline_wall':aa['baseline']['total_replay_wall_seconds'],'optimized_wall':aa['optimized']['total_replay_wall_seconds'],
                      'all_scientific_fields':'EXACT','complete_map_retained':True,'statuses':aa['baseline']['component_statuses']})
    for n in [1000,5000]:
        ss=read(OLD/f'inputs/engineering_N{n}.json')
        for mapping in ss['maps']:
            for mode in ['KNOWN','Q_SAT']:
                name=f'N{n}_{mapping["map_id"]}_{mode}.json';a=read(HERE/'results/audit_full_001'/name)
                replay=read(HERE/'results/paired_replay_001/optimized'/name)
                comparable={k:v for k,v in science(a).items()if k not in ['entry_members','entry_weight_ledger']}
                compare(comparable,science(replay),'FULL_AUDIT_VS_TIMED_ENGINEERING/'+name)
                audit.append(independent_audit(n,mapping,mode,a,ss))
    groups=[]
    for round_id in [1,2,0]:
        for n in [1000,5000]:
            for mode in ['KNOWN','Q_SAT']:
                for success in [True,False]:
                    rr=[r for r in records if(r['round']==round_id or round_id==0)and r['N']==n and r['mode']==mode and all(z=='AVAILABLE'for z in r['component_statuses'].values())==success]
                    if not rr:continue
                    item={'round':round_id or 'BOTH','N':n,'mode':mode,'path':'ALL_FOUR_COMPONENTS_AVAILABLE'if success else'ONE_OR_MORE_COMPONENTS_UNAVAILABLE'}
                    for version in ['baseline','optimized']:
                        v=[r for r in rr if r['version']==version]
                        item[version]={'runs':len(v),'wall_seconds':stat([r['total_replay_wall_seconds']for r in v]),
                          'CPU_seconds':stat([r['R_process_CPU_seconds']for r in v]),'ledger_IO_seconds':stat([r['ledger_IO_seconds']for r in v]),
                          'result_bytes':stat([r['result_bytes']for r in v]),'index_bytes':stat([r['full_index_bytes']for r in v]),
                          'AC_and_terminal_value_fraction':stat([(r['AC_value_bytes']+r['terminal_value_bytes'])/r['result_bytes']for r in v]),
                          'stages_mean':{k:statistics.mean(r['stages'][k]for r in v)for k in v[0]['stages']},
                          'R_heap_peak_MiB':max(r['R_heap_peak_MiB']for r in v)}
                    item['wall_reduction_fraction']=1-item['optimized']['wall_seconds']['mean']/item['baseline']['wall_seconds']['mean'];groups.append(item)
    historical=[]
    for d in ['engineering_attempt_001','engineering_attempt_002']:
        rr=read(OLD/'results'/d/'engineering_timing_ledger.json')['records']
        for n in [1000,5000]:
            for mode in ['KNOWN','Q_SAT']:
                for success in [True,False]:
                    v=[r for r in rr if r['N']==n and r['mode']==mode and all(z=='AVAILABLE'for z in r['component_statuses'].values())==success]
                    if not v:continue
                    files=[OLD/'results'/d/r['result_file']for r in v]
                    historical.append({'attempt':d,'N':n,'mode':mode,'all_components_available':success,'runs':len(v),
                      'wall_seconds':stat([r['total_replay_wall_seconds']for r in v]),
                      'R_CPU_seconds':stat([r['R_process_CPU_seconds']for r in v])if all('R_process_CPU_seconds'in r for r in v)else'NOT_MEASURED_PER_REPLAY',
                      'stage_means':{k:statistics.mean(r['stages'][k]for r in v)for k in v[0]['stages']},
                      'ledger_IO_seconds':stat([r['ledger_IO_seconds']for r in v]),
                      'result_bytes':stat([p.stat().st_size for p in files]),
                      'AC_and_terminal_value_fraction':stat([(field_bytes(p,'artificial_censors')+field_bytes(p,'terminal_settlements'))/p.stat().st_size for p in files])})
    before=read(OUT/'before.json')
    for p,fp in before['files'].items():assert m.fingerprint(ROOT/p)==fp,('PROTECTED_FILE_CHANGED',p)
    assert m.git(ROOT,'rev-parse','HEAD').decode().strip()==before['head']
    assert m.git(ROOT,'branch','--show-current').decode().strip()==before['branch']
    assert m.git(ROOT,'for-each-ref','--format=%(refname) %(objectname)','refs/heads','refs/tags','refs/remotes').decode()==before['refs']
    idx=Path(m.git(ROOT,'rev-parse','--git-path','index').decode().strip());idx=idx if idx.is_absolute()else ROOT/idx
    assert sha(idx)==before['index_sha256']
    newstatus=m.git(ROOT,'status','--porcelain=v1','-z').decode();assert set(before['status'].split('\0'))<=set(newstatus.split('\0'))
    resource=read(HERE/'runs/resource_ledger.json');executions=[read(HERE/p/'execution.json')for p in resource['attempts']]
    peak=max(x['peak_job_committed_bytes']for x in executions);disk=sum(p.stat().st_size for p in HERE.rglob('*')if p.is_file())
    assert peak<4*2**30 and resource['completed_child_CPU_seconds']<7200 and resource['completed_child_wall_seconds']<14400 and disk<2*2**30
    save(HERE/'results/final_scientific_invariance_and_performance.json',{'status':'PASS','rounds':2,'paired_cases':64,'engineering_method_executions':128,
      'small_case_mode_identity':39,'independent_presealed_checks':6092,'all_scientific_fields_compared':True,'excluded_fields':['timings'],
      'groups':groups,'pairs':pairs,'all_timing_records':records,'historical_baselines':historical,
      'audit_full_reconstruction':audit,'compact_ledger_adopted':False,'new_estimator_or_failure_rule':False,
      'resource':{'cumulative_child_CPU_seconds':resource['completed_child_CPU_seconds'],'cumulative_actual_execution_wall_seconds':resource['completed_child_wall_seconds'],
        'calendar_elapsed_including_user_interruption_seconds':time.time()-resource['start_epoch'],'peak_job_committed_bytes':peak,'candidate_bytes_before_reports':disk,
        'all_attempts':executions,'paused_calendar_clock_issue_retained':True},
      'protection':{'preexisting_files_exact_bytes_and_newlines':len(before['files']),'index_sha256':before['index_sha256'],'HEAD':before['head'],
        'heads_tags_remotes_unchanged':True,'original_candidate_sha256':sha(OLD/'core_candidate.R'),'Authority_sha256':sha(ROOT/'governance/CCW_SCIENTIFIC_AUTHORITY_V1.yml')},
      'F_leaves':'PENDING','G01_G08':'NOT_EXECUTED / NOT_ASSESSED','resource_projection':'MINIMAL_CORE_RESOURCE_PROJECTION_ONLY'})
    print(json.dumps({'status':'PASS','paired_cases':64,'all_scientific_fields':'EXACT','audit_fulls':32,'independent_weight_rows':sum(a['individual_weight_rows_checked']for a in audit),'protected_files':len(before['files'])}))
if __name__=='__main__':main()
