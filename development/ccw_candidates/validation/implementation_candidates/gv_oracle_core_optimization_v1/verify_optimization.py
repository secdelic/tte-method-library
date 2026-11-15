from pathlib import Path
import json,hashlib,statistics,struct,zlib,sys
HERE=Path(__file__).resolve().parent
OLD=HERE.parent/'gv_oracle_minimal_core_v1'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def science(x):
    if isinstance(x,dict):return {k:science(v) for k,v in x.items() if k!='timings'}
    if isinstance(x,list):return [science(v) for v in x]
    return x
def compare(a,b,path=''):
    # Exact decoded scalar equality, array order and field-set equality.
    # Numeric R integer/double representations may share an equal JSON number.
    if isinstance(a,dict):
        assert isinstance(b,dict) and a.keys()==b.keys(),('FIELDS',path)
        for k in a:compare(a[k],b[k],path+'/'+k)
    elif isinstance(a,list):
        assert isinstance(b,list) and len(a)==len(b),('ARRAY',path)
        for i,(x,y) in enumerate(zip(a,b)):compare(x,y,path+'/'+str(i))
    else:assert a==b,('VALUE',path,a,b)
def main():
    target=HERE/'results/verification_001.json'
    assert not target.exists()
    small=HERE/'results/regression_001'
    baseline=read(small/'baseline_small.json')['cases'];optimized=read(small/'optimized_small.json')['cases']
    compare(science(baseline),science(optimized),'ALL_SMALL_FIELDS')
    compare(science(read(OLD/'results/small_attempt_003/actual_small.json')['cases']),science(optimized),'PRIOR_FROZEN_SMALL')
    count=0
    for cid,modes in optimized.items():
        for mode,result in modes.items():
            compare(result,read(small/f'{cid}_{mode}_serialized.json'),'OPTIMIZED_SERIALIZER/'+cid+'/'+mode);count+=1
    assert count==39
    replay=HERE/'results/paired_replay_001';timing=read(replay/'paired_timing_ledger.json');records=timing['records']
    rows=[]
    for n in [1000,5000]:
        spec=read(OLD/f'inputs/engineering_N{n}.json')
        for mapping in spec['maps']:
            for mode in ['KNOWN','Q_SAT']:
                stem=f'N{n}_{mapping["map_id"]}_{mode}'
                a=read(replay/'baseline'/f'{stem}.json');b=read(replay/'optimized'/f'{stem}.json')
                compare(science(a),science(b),stem)
                compare(science(read(OLD/'results/engineering_attempt_002'/f'{stem}.json')),science(b),'PRIOR_ENGINEERING/'+stem)
                expected=struct.pack('<'+'i'*n,*mapping['indices'])
                for version in ['baseline','optimized']:
                    p=replay/version/f'{stem}.int32le';assert p.read_bytes()==expected,('DRAW_MAP',p)
                selected={r['version']:r for r in records if r['N']==n and r['map_id']==mapping['map_id'] and r['mode']==mode}
                assert len(selected)==2
                rows.append({'N':n,'map_id':mapping['map_id'],'mode':mode,'result_scientific_identity':'EXACT',
                  'complete_map_sha256':sha(replay/'baseline'/f'{stem}.int32le'),
                  'source_statuses':selected['baseline']['component_statuses'],
                  'baseline_wall':selected['baseline']['total_replay_wall_seconds'],'optimized_wall':selected['optimized']['total_replay_wall_seconds'],
                  'baseline_CPU':selected['baseline']['R_process_CPU_seconds'],'optimized_CPU':selected['optimized']['R_process_CPU_seconds']})
    assert len(rows)==32
    # The scientific program functions outside the two authorized hot functions
    # are byte-for-byte equal as text, including weight arithmetic and risk/contrast.
    base=(OLD/'core_candidate.R').read_text();opt=(HERE/'core_candidate_optimized.R').read_text()
    assert base[base.index('count_original_P <-'):]==opt[opt.index('count_original_P <-'):]
    groups=[]
    for n in [1000,5000]:
        for mode in ['KNOWN','Q_SAT']:
            rr=[r for r in records if r['N']==n and r['mode']==mode]
            for failure in [False,True]:
                subset=[r for r in rr if (any(s!='AVAILABLE' for s in r['component_statuses'].values()))==failure]
                if not subset:continue
                item={'N':n,'mode':mode,'path_group':'AT_LEAST_ONE_COMPONENT_UNAVAILABLE' if failure else 'ALL_FOUR_COMPONENTS_AVAILABLE'}
                for version in ['baseline','optimized']:
                    vv=[r for r in subset if r['version']==version]
                    item[version]={'runs':len(vv),'mean_wall_seconds':statistics.mean(r['total_replay_wall_seconds'] for r in vv),
                      'min_wall_seconds':min(r['total_replay_wall_seconds'] for r in vv),'max_wall_seconds':max(r['total_replay_wall_seconds'] for r in vv),
                      'mean_CPU_seconds':statistics.mean(r['R_process_CPU_seconds'] for r in vv),
                      'mean_ledger_IO_seconds':statistics.mean(r['ledger_IO_seconds'] for r in vv),
                      'stage_means':{s:statistics.mean(r['stages'][s] for r in vv) for s in vv[0]['stages']}}
                item['wall_ratio_optimized_over_baseline']=item['optimized']['mean_wall_seconds']/item['baseline']['mean_wall_seconds']
                groups.append(item)
    for p,h in read(OLD/'inputs/sealed_input_manifest.json')['files'].items():assert sha(OLD/'inputs'/p)==h,('SEALED_INPUT',p)
    independent=read(HERE/'results/independent_expected_verification_001.json');assert independent['status']=='PASS'
    obj={'status':'PASS','small_case_modes':39,'R_objects_identical_excluding_timings':True,
      'serializer_all_39_full_small_ledgers_identical':True,'paired_cases':32,'engineering_runs':64,
      'old_engineering_science_identical':True,'all_scientific_fields_preserved':True,
      'excluded_fields':['timings'],'unchanged_functions_from_count_original_P_through_analyze_candidate':True,
      'independent_frozen_expected_checks':len(independent['checks']),'fixed_maps_retained_and_exact':64,
      'pairs':rows,'groups':groups,'G01_G08':'NOT_EXECUTED / NOT_ASSESSED','formal_MC':False,'CI_calibration':False}
    target.parent.mkdir(exist_ok=True)
    with target.open('x',encoding='utf-8')as f:json.dump(obj,f,ensure_ascii=False,indent=2);f.write('\n')
    print(json.dumps({k:obj[k]for k in ['status','small_case_modes','paired_cases','independent_frozen_expected_checks','fixed_maps_retained_and_exact']}))
    print(json.dumps(groups))
if __name__=='__main__':main()
