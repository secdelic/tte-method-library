from pathlib import Path
from fractions import Fraction as F
import json,hashlib,math,struct,zlib,ast,difflib,statistics
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];OUT=ROOT/'output/gv_oracle_minimal_core_v1'
REF=ROOT/'validation/reference_candidates/gv_oracle_reference_only_v1';ORIG=REF/'runs/attempt_001';REPRO=HERE/'reference_reproduction/attempt_001'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def frac(v):return F(v['numerator'],v['denominator'])
def save(p,x):
    with p.open('x',encoding='utf-8') as f:json.dump(x,f,ensure_ascii=False,sort_keys=True,indent=2)
def main():
    checks=[]
    def ck(name,test):
        checks.append({'check':name,'status':'PASS' if test else 'FAIL'});assert test,name
    for name in ['dp_exact.json','enum_exact.json','validation_exact.json']:
        ck('REFERENCE_FULL_JSON_EQUAL:'+name,read(ORIG/name)==read(REPRO/name))
        ck('REFERENCE_BYTES_EQUAL:'+name,sha(ORIG/name)==sha(REPRO/name))
    validation=read(REPRO/'validation_exact.json')
    ck('ALL_493_ASSERTIONS_REAL_PASS',len(validation['checks'])==493 and all(x['status']=='PASS' for x in validation['checks']))
    ck('ASSERTION_NAMES_UNIQUE',len({x['check'] for x in validation['checks']})==493)
    for p,h in read(OUT/'reference_original_hashes.json').items():ck('ORIGINAL_REF_BYTES:'+p,sha(REF/p)==h['sha256'])
    dp=read(ORIG/'dp_exact.json');conversion=read(ORIG/'input_and_conversion_review.json');cv=0
    for row in conversion['conversion_errors']:
        law=row['law'];g=row['policy'];name=row['quantity']
        if g=='CONTRAST':value=dp['contrasts'][law][name]['value'] if name=='RR' else dp['contrasts'][law][name]
        elif name in ['R5','S5']:value=dp['laws'][law][g][name]
        elif name.startswith('d'):value=dp['laws'][law][g]['d'][int(name[1:])-1]
        else:
            z,k,field=name.split('_');value=dp['laws'][law][g]['conditional_moments'][int(k)][z][field]
        exact=frac(value);observed=F.from_float(float(exact));error=abs(observed-exact)
        ck(f'ACTUAL_BINARY64_ERROR:{law}:{g}:{name}',error==frac(row['exact_absolute_binary64_conversion_error']));cv+=1
    for file in ['ref_dp.py','ref_enum.py']:
        tree=ast.parse((REF/file).read_text(encoding='utf-8'))
        imports=[n.module for n in ast.walk(tree) if isinstance(n,ast.ImportFrom)]+[a.name for n in ast.walk(tree) if isinstance(n,ast.Import) for a in n.names]
        ck('NO_SHARED_TRANSITION_IMPORTS:'+file,set(imports)<={'fractions','pathlib','json','sys','time'})
    original_inputs=read(REF/'inputs/expanded_parameters.json');params_checked=0
    for law,obj in original_inputs['laws'].items():
        ck('SINGLE_OVERRIDE:'+law,obj['single_override'] is None if law=='LAW-BASE-RATIONAL-V1' else obj['single_override']==law[4:-3])
        for cell,item in obj['parameters'].items():
            if item['exact'] is None:ck('NO_DEFAULT:'+law+cell,not item['consumers']);continue
            q=item['exact'];ck('INTEGER_INPUT:'+law+cell,type(q['numerator']) is int and type(q['denominator']) is int and q['denominator']>0);params_checked+=1
    small=read(HERE/'results/small_verification_002.json');ck('DETERMINISTIC_CORE_SUITE',small['status']=='PASS' and all(c['status']=='PASS' for c in small['checks']))
    # Preserve the original failure and all code-repair differences, no overwritten attempt.
    repairs=[]
    for old,new,label in [(HERE/'runs/fixture_oracle_001/source_snapshot/prepare_fixtures.py',HERE/'prepare_fixtures.py','fixture_input_support_repair'),
      (HERE/'runs/core_small_001/source_snapshot/run_stage.py',HERE/'run_stage.py','Windows_R_descendant_metering'),
      (HERE/'runs/core_small_001/source_snapshot/core_candidate.R',HERE/'core_candidate.R','explicit_failure_metadata_and_known_support'),
      (HERE/'runs/engineering_replay_001/source_snapshot/replay_engineering.R',HERE/'replay_engineering.R','per_replay_CPU_and_heap_instrumentation')]:
        text=''.join(difflib.unified_diff(old.read_text(encoding='utf-8').splitlines(True),new.read_text(encoding='utf-8').splitlines(True),fromfile=str(old.relative_to(HERE)),tofile=str(new.relative_to(HERE))))
        p=HERE/'results'/(label+'.diff');p.write_text(text,encoding='utf-8');repairs.append({'diff':p.relative_to(HERE).as_posix(),'old_sha256':sha(old),'new_sha256':sha(new)})
    engineering=[];summaries=[]
    for attempt in ['engineering_attempt_001','engineering_attempt_002']:
        d=HERE/'results'/attempt;ledger=read(d/'engineering_timing_ledger.json');ck(attempt+':FIXED_RUN_COUNT',len(ledger['records'])==32)
        for record in ledger['records']:
            N=record['N'];spec=read(HERE/f'inputs/engineering_N{N}.json');mapping=next(x for x in spec['maps'] if x['map_id']==record['map_id'])
            original=struct.pack('<'+'i'*N,*mapping['indices']);raw=(d/record['full_index_file']).read_bytes()
            ck(attempt+':FULL_ORDERED_INDEX:'+str(N)+record['map_id']+record['mode'],raw==original and sha(d/record['full_index_file'])==mapping['uncompressed_int32_sha256'])
            ck(attempt+':DECOMPRESS_FULL_MAP:'+str(N)+record['map_id']+record['mode'],zlib.decompress((HERE/mapping['compressed_file']).read_bytes())==raw)
            answer=read(d/record['result_file']);m=[0]*N
            for i in mapping['indices']:m[i-1]+=1
            # Independent P opportunity counts, no candidate helper or clone filtering.
            for cell,nd in answer['P_counts'].items():
                k,w,l=map(int,cell[1:].split('_'));n=0;success=0
                for s,mi in zip(spec['subjects'],m):
                    if not mi:continue
                    t=s['terminal_time'];st=s['actual_effective_start_time']
                    if t is not None and t<=k or st is not None and st<k or s['W']!=w:continue
                    value=next(h['L'] for h in s['history'] if h['k']==k)
                    if value!=l:continue
                    n+=mi;success+=mi*(st==k)
                ck(attempt+':P_COUNT:'+str(N)+record['map_id']+record['mode']+cell,nd=={'n':n,'d':success})
            if record['map_id']=='ALL_EARLY_LOCAL_D_EMPTY':
                ck(attempt+':D_EMPTY_LOCAL:'+str(N)+record['mode'],answer['components']['D_PL']['source_status']=='NONESTIMABLE_EMPTY_RISKSET' and answer['components']['E_PL']['source_status']=='AVAILABLE')
            if record['map_id']=='E_LOCAL_MODEL_BOUNDARY' and record['mode']=='Q_SAT':
                ck(attempt+':E_MODEL_LOCAL:'+str(N),answer['components']['E_PL']['source_status']=='MODEL_FAILURE' and answer['components']['D_PL']['source_status']=='AVAILABLE')
            if record['map_id']=='SHARED_FAILURE_INJECTION' and record['mode']=='Q_SAT':
                ck(attempt+':SHARED_MODEL:'+str(N),all(answer['components'][g+'_PL']['source_status']=='MODEL_FAILURE' for g in ['E','D']))
            if attempt=='engineering_attempt_002':
                prev=read(HERE/'results/engineering_attempt_001'/record['result_file'])
                for field in ['components','contrasts','required_cells','P_counts','fits','artificial_censors','terminal_settlements','entry_ESS','eligible_instances']:
                    ck('REPLAY_SCIENCE_IDENTICAL:'+str(N)+record['map_id']+record['mode']+field,answer[field]==prev[field])
            engineering.append({'attempt':attempt,**record})
    for attempt in ['engineering_attempt_001','engineering_attempt_002']:
        for N in [1000,5000]:
            for mode in ['KNOWN','Q_SAT']:
                for status in ['BOTH_PL_AVAILABLE','ONE_OR_MORE_PL_UNAVAILABLE']:
                    group=[r for r in engineering if r['attempt']==attempt and r['N']==N and r['mode']==mode and (all(r['component_statuses'][g+'_PL']=='AVAILABLE' for g in ['E','D']))==(status=='BOTH_PL_AVAILABLE')]
                    if not group:continue
                    v=[r['total_replay_wall_seconds'] for r in group]
                    cpu=[r['R_process_CPU_seconds'] for r in group if 'R_process_CPU_seconds'in r]
                    summaries.append({'attempt':attempt,'N':N,'mode':mode,'path_class':status,'count':len(group),'wall_min':min(v),'wall_mean':statistics.mean(v),'wall_max':max(v),
                      'R_CPU_min':min(cpu) if cpu else None,'R_CPU_mean':statistics.mean(cpu) if cpu else None,'R_CPU_max':max(cpu) if cpu else None,
                      'stage_wall_means':{k:statistics.mean(r['stages'][k] for r in group) for k in group[0]['stages']}})
    save(HERE/'results/reference_qualification_checks.json',{'status':'PASS','scope':'GV_ORACLE_7_LAW_2_POLICY_TAU5_REFERENCE','checks':checks,
      'reference_493_assertions':493,'conversion_errors_recomputed':cv,'integer_parameter_cells_reviewed':params_checked,
      'core_case_mode_runs':small['test_case_mode_runs'],'core_assertions':len(small['checks']),
      'isolated_reference_reproductions':1,'reference_scientific_fields_omitted':0,'engineering_unique_maps':16,'engineering_total_replays_including_instrumentation_repeat':64,
      'repairs':repairs,'G01_G08':'NOT_EXECUTED / NOT_ASSESSED'})
    save(HERE/'results/engineering_summary.json',{'groups':summaries,'all_attempts_reported':True,'formal_inner_cost_inference':'NOT_IDENTIFIED_FROM_THIS_FIXED_REPLAY',
      'no_MC_SE_CI_bias_coverage':True,'candidate_F03_budget_unchanged':True})
    print(json.dumps({'status':'PASS','reference_qualification_checks':len(checks),'conversion_certificates':cv,'small_case_mode_runs':small['test_case_mode_runs'],'small_checks':len(small['checks']),'engineering_replays':len(engineering)},ensure_ascii=False))
if __name__=='__main__':main()
