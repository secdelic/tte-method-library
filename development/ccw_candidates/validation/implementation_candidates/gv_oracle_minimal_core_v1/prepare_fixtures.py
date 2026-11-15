"""Independent closed-form fixture oracle, sealed BEFORE the candidate is run.
Fixed histories are development fixtures, not draws from any DGP.
No candidate imports; no reference outcome H/R kernels used by estimators.
"""
from pathlib import Path
from fractions import Fraction as F
import json,hashlib,itertools,struct,zlib
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
def save(p,x):
    p.parent.mkdir(parents=True,exist_ok=True)
    with p.open('x',encoding='utf-8',newline='\n') as f:json.dump(x,f,ensure_ascii=False,sort_keys=True,indent=2);f.write('\n')
def encode(x):
    if isinstance(x,F):return {'numerator':x.numerator,'denominator':x.denominator}
    if isinstance(x,list):return [encode(v) for v in x]
    if isinstance(x,dict):return {k:encode(v) for k,v in x.items()}
    return x
def subject(i,start=None,event=None,w=0,l=0):
    return {'id':i,'original_id':i,'actual_effective_start_time':start,'terminal_time':event,
      't0_start_stage':'POST_ELIGIBILITY_AND_CLONE_ASSIGNMENT',
      'history':[{'k':k,'L':l,'measurement_time':k,'availability_time':k} for k in range(5) if event is None or k<event]}
def prior(s,k):return s['actual_effective_start_time'] is not None and s['actual_effective_start_time']<k
def alive(s,k):return s['terminal_time'] is None or s['terminal_time']>k
def eligible(s):return not(s['actual_effective_start_time'] is not None and s['actual_effective_start_time']<0) and not(s['terminal_time'] is not None and s['terminal_time']<=0)
def entry(s,g,k):
    if not alive(s,k):return False
    st=s['actual_effective_start_time']
    return (k<3 or (st is not None and st<=3)) if g=='E' else not(st is not None and st<=min(k,3))
def cell(s,k):return 'c'+str(k)+'_'+str(s['W'])+'_'+str(next(r['L'] for r in s['history'] if r['k']==k))
def factors(s,g,k):
    if g=='E':return [cell(s,3)] if k>=3 and s['actual_effective_start_time']==3 else []
    return [cell(s,j) for j in range(min(k,3)+1)]
def oracle(case,mode):
    if case.get('invalid_reason'):return {'input_valid':False,'reason':case['invalid_reason']}
    sources=[s for s in case['subjects'] if eligible(s)];mult={s['id']:case['multiplicity'][case['subjects'].index(s)] for s in sources}
    subjects=[s for s in sources if mult[s['id']]>0];N=sum(mult[s['id']] for s in subjects)
    ledger={g:[[s['id'] for s in subjects if entry(s,g,k)] for k in range(5)] for g in ['E','D']}
    refs={};counts={};needed={}
    for g in ['E','D']:
        for role in ['PL','HT']:
            output=g+'_'+role;req=set()
            for k in range(5):
                for s in subjects:
                    if s['id'] in ledger[g][k] and (role=='PL' or s['terminal_time']==k+1):req.update(factors(s,g,k))
            needed[output]=sorted(req)
    union=sorted(set(c for v in needed.values() for c in v))
    for c in union:
        k=int(c[1]);subset=[s for s in subjects if alive(s,k) and not prior(s,k) and cell(s,k)==c]
        n=sum(mult[s['id']] for s in subset);d=sum(mult[s['id']] for s in subset if s['actual_effective_start_time']==k)
        counts[c]={'n':n,'d':d}
        if mode=='KNOWN':refs[c]=F(case['known_q'][c]['numerator'],case['known_q'][c]['denominator'])
        else:refs[c]=None if n==0 or d==0 or d==n or c in case.get('forced_fit_failures',[]) else F(d,n)
    components={};weighted={};ess={};ac={}
    for g in ['E','D']:
        ac[g]=[{'id':s['id'],'k':3 if g=='E' else s['actual_effective_start_time']} for s in subjects if (g=='E' and alive(s,3) and (s['actual_effective_start_time'] is None or s['actual_effective_start_time']>3)) or (g=='D' and s['actual_effective_start_time'] is not None and 0<=s['actual_effective_start_time']<=3)]
        weighted[g]=[];ess[g]=[]
        for k in range(5):
            rows=[]
            for s in subjects:
                if s['id'] not in ledger[g][k]:continue
                req=factors(s,g,k);weight=F(1)
                if any(refs[c] is None for c in req):weight=None
                else:
                    for c in req:weight/=refs[c] if g=='E' else 1-refs[c]
                rows.append({'id':s['id'],'weight':weight,'multiplicity':mult[s['id']],'event':s['terminal_time']==k+1})
            weighted[g].append(rows)
            if rows and all(r['weight'] is not None for r in rows):
                s1=sum(r['multiplicity']*r['weight'] for r in rows);s2=sum(r['multiplicity']*r['weight']**2 for r in rows)
                ess[g].append({'S1':s1,'S2':s2,'ESS':s1*s1/s2})
            else:ess[g].append(None)
        for role in ['PL','HT']:
            output=g+'_'+role
            if g in case.get('unsupported_policies',[]):components[output]={'value':None,'source_status':'IDENTIFICATION_NOT_SUPPORTED'};continue
            if any(refs[c] is None for c in needed[output]):components[output]={'value':None,'source_status':'MODEL_FAILURE'};continue
            if role=='HT':
                value=sum((r['multiplicity']*r['weight'] for phase in weighted[g] for r in phase if r['event']),F(0))/N
                components[output]={'value':value,'source_status':'AVAILABLE'}
            else:
                survival=F(1);hazards=[];failed=False
                for phase in weighted[g]:
                    mass=sum((r['multiplicity']*r['weight'] for r in phase),F(0))
                    ev=sum((r['multiplicity']*r['weight'] for r in phase if r['event']),F(0))
                    if survival==0:hazards.append({'denominator':mass,'numerator':ev,'hazard':None,'status':'ABSORBED_CONTINUATION'});continue
                    if mass==0:failed=True;hazards.append({'denominator':mass,'numerator':ev,'hazard':None,'status':'NONESTIMABLE_EMPTY_RISKSET'});break
                    hazard=ev/mass;survival*=1-hazard;hazards.append({'denominator':mass,'numerator':ev,'hazard':hazard,'status':'DEFINED'})
                components[output]={'value':None if failed else 1-survival,'source_status':'NONESTIMABLE_EMPTY_RISKSET' if failed else 'AVAILABLE','hazards':hazards}
    return {'input_valid':True,'eligible_instances':N,'entry_members':ledger,'artificial_censors':ac,'required_cells':needed,'P_counts':counts,'components':components,'entry_weight_ledger':weighted,'entry_ESS':ess}
def main():
    qraw=json.loads((ROOT/'validation/reference_candidates/gv_oracle_reference_only_v1/inputs/expanded_parameters.json').read_text())['laws']['LAW-BASE-RATIONAL-V1']['parameters']
    q={'c'+str(k)+'_'+str(w)+'_'+str(l):qraw[f'q:{k},{w},{l}']['exact'] for k,w,l in itertools.product(range(5),(0,1),(0,1))}
    def withw(s,w):s['W']=w;return s
    def S(i,st=None,t=None,w=0,l=0):return withw(subject(i,st,t,w,l),w)
    main=[S('S01',0,1),S('S02',2,3),S('S03',3,5),S('S04',None,3),S('S05',4,5),S('S06'),S('S07',1),S('S08',3)]
    cases=[]
    def add(name,ss,m=None,**kw):
        case={'case_id':name,'subjects':ss,'multiplicity':m or [1]*len(ss),'known_q':q,'representation':'SOURCE_MULTIPLICITY',**kw};cases.append(case);return case
    add('HAND_LEDGER_MAIN',main)
    add('NONUNIFORM_MULTIPLICITY',main,[2,1,2,1,1,0,0,1])
    expanded=[]
    for s,m in zip(main,[2,1,2,1,1,0,0,1]):
        for j in range(m):
            x=json.loads(json.dumps(s));x['id']=s['id']+'#'+str(j+1);expanded.append(x)
    add('EXPLICIT_DRAW_EQUIVALENT',expanded,representation='EXPLICIT_DRAW_INSTANCES')
    add('NO_EVENT_LEGAL', [S(s['id'],s['actual_effective_start_time'],None) for s in main])
    add('ABSORBED_AT_1',[S('A1',0,1),S('A2',None,1)])
    add('E_EMPTY_RISKSET_D_LEGAL',[S('K1',None,5),S('K2',4,None)])
    add('ZERO_REFERENCE_SAMPLE',[S('Z1',0,5),S('Z2',4,None)])
    add('ZERO_NUMERATOR_SAMPLE',[S('Z1',0,None),S('Z2',4,5)])
    add('SHARED_FIT_FAILURE',main,forced_fit_failures=['c3_0_0'])
    add('UNCONSUMED_FIT_FAILURE',main,forced_fit_failures=['c4_1_1'])
    add('OPTIONAL_DIAGNOSTIC_FAILURE',main,forced_diagnostic_failure=True)
    local=[S(f'L{l}_{i}',st,5 if i%2 else None,l=l) for l,starts in [(0,[0,1,2,3,4,None]),(1,[0,1,2,3])] for i,st in enumerate(starts)]
    add('E_LOCAL_MODEL_FAILURE_D_VALID',local)
    zero_sources=[S(s['id'],None if s['actual_effective_start_time']==3 else s['actual_effective_start_time'],s['terminal_time']) for s in main]
    add('ZERO_E_POPULATION_SUPPORT',zero_sources,unsupported_policies=['E'],known_q={**q,**{f'c3_{w}_{l}':{'numerator':0,'denominator':1} for w,l in itertools.product((0,1),repeat=2)}})
    add('BASELINE_EXCLUSIONS',main+[S('B1',-1,None),S('B2',None,0),S('B3',None,-1)])
    for t in [1,3]:add('REJECT_EVENT_START_TIE_'+str(t),[S('BAD',t,t)],invalid_reason='ACTUAL_START_NOT_BEFORE_TERMINAL')
    late=S('BAD',None,5);late['history'][0]['availability_time']=1
    add('REJECT_LATE_L',[late],invalid_reason='INVALID_MEASUREMENT_AVAILABILITY')
    stage=S('BAD',0,5);stage['t0_start_stage']='BEFORE_CLONING'
    add('REJECT_T0_ORDER',[stage],invalid_reason='INVALID_T0_MICRO_ORDER')
    duplicate=S('BAD',None,5);duplicate['history'].append(duplicate['history'][0].copy())
    add('REJECT_DUPLICATE_L',[duplicate],invalid_reason='INVALID_HISTORY_GRID')
    post=S('BAD',None,1);post['history'].append({'k':1,'L':0,'measurement_time':1,'availability_time':1})
    add('REJECT_POST_TERMINAL_L',[post],invalid_reason='INVALID_HISTORY_GRID')
    fixture={'schema':'FIXED_DEVELOPMENT_HISTORY_V1','not_random_DGP':True,'cases':cases}
    expected={'oracle':'CLOSED_FORM_SOURCE_LEDGER_EXACT_V1','compiled_before_DUT_execution':True,'cases':{}}
    for c in cases:
        expected['cases'][c['case_id']]={mode:oracle(c,mode) for mode in ['KNOWN','Q_SAT'] if c['case_id']!='ZERO_E_POPULATION_SUPPORT' or mode=='KNOWN'}
    a=expected['cases']['HAND_LEDGER_MAIN']
    assert a['KNOWN']['components']['E_PL']['value']==F(241,376)
    assert a['KNOWN']['components']['D_PL']['value']==F(3,5)
    assert a['KNOWN']['components']['E_HT']['value']==F(41,56)
    assert a['KNOWN']['components']['D_HT']['value']==F(275,364)
    assert a['Q_SAT']['components']['E_PL']['value']==F(5,8)
    assert a['Q_SAT']['components']['D_PL']['value']==F(3,5)
    inp=HERE/'inputs';save(inp/'small_fixtures.json',fixture);save(inp/'independent_expected.json',encode(expected))
    # Two fixed scale fixtures, eight PREDECLARED maps each, no RNG or probability generation.
    templates=[S(f'B{w}{l}{i}{t}',st,t,w,l) for w,l in itertools.product((0,1),repeat=2) for i,st in enumerate([0,1,2,3,4,None]) for t in [5,None]]
    engineering=[]
    for N in [1000,5000]:
        ss=[]
        for i in range(N):
            x=json.loads(json.dumps(templates[i%len(templates)]));x['id']=f'F{N}_{i+1:05d}';x['original_id']=x['id'];ss.append(x)
        def repeated(indices):return [indices[i%len(indices)] for i in range(N)]
        early=[i+1 for i,s in enumerate(ss) if s['actual_effective_start_time']==0]
        local_idx=[i+1 for i,s in enumerate(ss) if s['W']==0 and (s['history'][0]['L']==0 or s['actual_effective_start_time'] in [0,1,2,3])]
        maps=[('IDENTITY',list(range(1,N+1))),('REVERSED',list(range(N,0,-1))),('ROTATED',list(range(18,N+1))+list(range(1,18))),
          ('DOUBLE_FIRST_HALF',[i//2+1 for i in range(N)]),('TRIPLE_PREFIX',[i//3+1 for i in range(N)]),
          ('ALL_EARLY_LOCAL_D_EMPTY',repeated(early)),('E_LOCAL_MODEL_BOUNDARY',repeated(local_idx)),('SHARED_FAILURE_INJECTION',list(range(1,N+1)))]
        scale={'scale_id':f'N{N}','N':N,'subjects':ss,'known_q':q,'not_random_DGP':True,'maps':[]}
        for name,indices in maps:
            raw=struct.pack('<'+'i'*N,*indices);packed=zlib.compress(raw,level=9)
            assert zlib.decompress(packed)==raw
            p=inp/f'fixed_maps/N{N}_{name}.int32le.zlib';p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(packed)
            scale['maps'].append({'map_id':name,'indices':indices,'uncompressed_int32_sha256':hashlib.sha256(raw).hexdigest(),
              'compressed_file':p.relative_to(HERE).as_posix(),'compressed_sha256':hashlib.sha256(packed).hexdigest(),
              'forced_fit_failures':['c3_0_0'] if name=='SHARED_FAILURE_INJECTION' else []})
        save(inp/f'engineering_N{N}.json',scale);engineering.append({'file':f'engineering_N{N}.json','N':N,'map_count':len(maps)})
    files={p.relative_to(inp).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(inp.rglob('*')) if p.is_file()}
    save(inp/'sealed_input_manifest.json',{'phase':'BEFORE_CANDIDATE_IMPLEMENTATION_AND_EXECUTION','files':files,
      'small_cases':len(cases),'engineering':engineering,'fitting_or_DUT_executed':False,'randomness':'NONE_FIXED_INPUTS'})
    print(json.dumps({'small_cases':len(cases),'oracle_assertions_fixed_before_DUT':6,'engineering_maps':16,'inputs_sha256_sealed':len(files)}))
if __name__=='__main__':main()
