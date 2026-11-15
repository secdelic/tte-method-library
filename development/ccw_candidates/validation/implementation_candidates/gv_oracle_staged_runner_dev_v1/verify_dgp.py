from pathlib import Path
from fractions import Fraction as F
import json,hashlib,itertools
HERE=Path(__file__).resolve().parent;REF=HERE.parents[1]/'reference_candidates/gv_oracle_reference_only_v1'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def key(kind,idx=()):return kind+(':'+','.join(map(str,idx))if idx else'')
def expected(law,kind,idx):
    if kind=='omega':return F(2,5)
    if kind=='b':return F(1+idx[0],4)
    k,w,l=idx[:3]
    if kind=='q':
        if law=='NEAR'and k==3:return F(1,1000)
        if law=='ZERO-E'and k==3 or law=='NATURAL-ZERO'and k==0:return F(0)
        return F(8+2*k+3*w+4*l+2*w*l,40)
    s,b=idx[3:]
    if kind=='h':
        if law=='ABSORBED'and k==0:return F(1)
        return F(14+k+2*w+4*l-(0 if law=='NULL'else 3*b+s),80000 if law=='SPARSE'else 80)
    assert kind=='r'and k<4
    return F(8+k+2*w+5*l-(0 if law=='NULL'else 2*b+s),20)
def rat(z):return F(z['numerator'],z['denominator'])
def threshold(u,p):
    assert isinstance(u,(float,int))and 0<u<1
    return int(F.from_float(float(u))<p)
def main():
    assert read(HERE/'runs/dev_sources_001/execution.json')['status']=='COMPLETED','GENERATOR_MUST_FINISH'
    assert read(HERE/'results/deterministic_gate_001/DETERMINISTIC_GATE_COMPLETE.json')['status']=='PASS'
    theta=read(REF/'inputs/expanded_parameters.json');manifest=read(HERE/'inputs/dev_task_stream_manifest.json');bank=read(HERE/'rng/DEV_STREAM_BANK_V1.json')
    assert len(bank['bank'])==1024 and bank['DEV_first_index']==23956750 and bank['formal_last_index']==23956749
    assert bank['total_R_nextRNGStream_advances_to_DEV_first']==23956750 and bank['random_variates_generated']==0
    assigned={t['task_id']:t for t in manifest['tasks']};assert len(assigned)==136
    assert len({tuple(b['seed'])for b in bank['bank']})==1024
    primitive_cells=0
    for lid,law in theta['laws'].items():
        name=lid[4:-3];name='BASE'if name=='BASE-RATIONAL'else name
        assert law['single_override']==(None if name=='BASE'else name)
        for p in law['parameters'].values():
            if p['exact']is not None:assert rat(p['exact'])==expected(name,p['kind'],p['indices']);primitive_cells+=1
            else:assert not p['consumers']
    results=[];catalog={}
    for ds in manifest['datasets']:
        folder=HERE/'dev_sources'/ds['dataset_id'];source=read(folder/'source.json');trace=read(folder/'innovation_trace.json');rec=read(folder/'generation_record.json')
        task=assigned[ds['dataset_id']+'_SOURCE'];assert rec['task']==task and rec['status']=='COMPLETED'
        assert rec['initial_Random_seed']==bank['bank'][task['stream_index_zero_based']-23956750]['seed']
        assert source['case_id']==ds['dataset_id']and len(source['subjects'])==len(trace['subjects'])==ds['N']
        assert source['multiplicity']==[1]*ds['N'] and source['representation']=='SOURCE_MULTIPLICITY'
        assert source['unsupported_policies']==(['E']if ds['law']=='ZERO-E'else[])
        assert trace['single_override']==(None if ds['law']=='BASE'else ds['law'])
        assert not any(k in source for k in ['h','r','H','R','outcome_kernel','DGP_parameters'])
        seen=set();u_count=0;steps_checked=0
        for subject,tr in zip(source['subjects'],trace['subjects']):
            sid=subject['id'];assert sid==subject['original_id']==tr['id']and sid not in seen;seen.add(sid)
            w=threshold(tr['U_W'],expected(ds['law'],'omega',[]));l=threshold(tr['U_L0'],expected(ds['law'],'b',[w]));u_count+=2
            assert subject['W']==w;s=0;start=None;terminal=None;history=[]
            for k,z in enumerate(tr['steps']):
                assert k<=4 and z['k']==k and z['W']==w and z['L']==l and z['S_pre']==s
                history.append({'k':k,'L':l,'measurement_time':k,'availability_time':k})
                if s==0:
                    assert z['q_key']==key('q',[k,w,l]);q=expected(ds['law'],'q',[k,w,l]);b=threshold(z['U_Q'],q);u_count+=1
                    if b:start=k
                else:
                    assert z['q_key']is None and z['U_Q']is None;b=1
                assert z['B_post']==b and z['h_key']==key('h',[k,w,l,s,b])
                event=bool(threshold(z['U_H'],expected(ds['law'],'h',[k,w,l,s,b])));u_count+=1;steps_checked+=1
                assert z['event']==event
                if event:terminal=k+1
                if event or k==4:
                    assert z['r_key']is None and z['U_R']is None and z['next_L']is None
                    assert k==len(tr['steps'])-1;break
                assert z['r_key']==key('r',[k,w,l,s,b])
                nxt=threshold(z['U_R'],expected(ds['law'],'r',[k,w,l,s,b]));u_count+=1
                assert z['next_L']==nxt;s=b;l=nxt
            assert subject['actual_effective_start_time']==start and subject['terminal_time']==terminal
            assert subject['history']==history and len(history)==(terminal if terminal is not None else 5)
            assert start is None or terminal is None or start<terminal
            assert subject['t0_start_stage']==('POST_ELIGIBILITY_AND_CLONE_ASSIGNMENT'if start==0 else None)
            assert len(history)<=5 and (terminal is None or all(z['k']<terminal for z in history))
        assert rec['uniform_calls']==u_count
        for c,q in source['known_q'].items():assert rat(q)==expected(ds['law'],'q',list(map(int,c[1:].split('_'))))
        cat={**ds,'source_file':str((folder/'source.json').relative_to(HERE)).replace('\\','/'),
          'source_sha256':sha(folder/'source.json'),'source_md5_for_fast_read_guard':hashlib.md5((folder/'source.json').read_bytes()).hexdigest(),
          'trace_sha256':sha(folder/'innovation_trace.json'),'generation_record_sha256':sha(folder/'generation_record.json'),
          'source_task_stream':task['stream_index_zero_based'],'source_bytes':(folder/'source.json').stat().st_size}
        catalog[ds['dataset_id']]=cat
        results.append({'dataset_id':ds['dataset_id'],'status':'PASS','subjects':ds['N'],'stage_transitions':steps_checked,'uniform_calls':u_count,
          'checks':'INDEPENDENT_APPROVED_FORMULAS_EXACT_BINARY64_UNIFORM_THRESHOLDS_LEGAL_P_HISTORY_NO_POLICY_FORCE'})
    assert len(catalog)==28
    for name,obj in [('dev_source_catalog.json',{'datasets':catalog,'source_files_per_dataset':1,'formal_M_contribution':0}),
      ('DGP_INDEPENDENT_VALIDATION.json',{'status':'PASS','datasets':results,'primitive_assigned_cells_exact':primitive_cells,
        'all_28_observational_sources_verified':True,'no_fitted_estimator_or_truth_used_to_validate_generation':True,
        'DEV_only':True,'formal_M':0})]:
        with(HERE/'inputs'/name).open('x',encoding='utf-8')as f:json.dump(obj,f,ensure_ascii=False,indent=2)
    print(json.dumps({'status':'PASS','datasets':len(results),'subjects':sum(d['subjects']for d in results),'transition_rows':sum(d['stage_transitions']for d in results),'primitive_cells':primitive_cells}))
if __name__=='__main__':main()
