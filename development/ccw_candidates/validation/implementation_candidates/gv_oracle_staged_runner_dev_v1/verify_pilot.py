from pathlib import Path
from fractions import Fraction as F
from collections import Counter,defaultdict
import sys,json,hashlib,math,struct,zlib,time,statistics,traceback
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;OPT=HERE.parent/'gv_oracle_core_optimization_v1'
sys.path.insert(0,str(OPT))
from verify_optimization import read,science,compare
from finalize_evidence import independent_audit
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def close(a,b):return a is None if b is None else a is not None and math.isfinite(a)and abs(a-float(b))<=1e-12+1e-10*abs(float(b))
def rat(z):return F(z['numerator'],z['denominator'])
def independent_risk(source,indices,mode):
    ss=source['subjects'];m=Counter(indices);N=len(indices);tt=[s['terminal_time']for s in ss];st=[s['actual_effective_start_time']for s in ss]
    L=[{h['k']:h['L']for h in s['history']}for s in ss]
    counts={};opps=defaultdict(list)
    for i,s in enumerate(ss):
        for k,l in L[i].items():
            if st[i]is None or st[i]>=k:opps[f'c{k}_{s["W"]}_{l}'].append((i,st[i]==k))
    def q(c):
        if mode=='KNOWN':return rat(source['known_q'][c])
        if c not in counts:
            n=sum(m[i+1]for i,_ in opps[c]);d=sum(m[i+1]for i,a in opps[c]if a);counts[c]=(n,d)
        n,d=counts[c];return F(d,n)if 0<d<n else None
    refs={};hazards={}
    for g in ['E','D']:
        stages=[]
        for k in range(5):
            values=[]
            for i,s in enumerate(ss):
                mi=m[i+1]
                if not mi or tt[i]is not None and tt[i]<=k:continue
                ac=(3 if(st[i]is None or st[i]>3)else None)if g=='E'else(st[i]if st[i]is not None and st[i]<=3 else None)
                if ac is not None and ac<=k:continue
                keys=([f'c3_{s["W"]}_{L[i][3]}']if k>=3 and st[i]==3 else[])if g=='E'else[f'c{j}_{s["W"]}_{L[i][j]}'for j in range(min(k,3)+1)]
                weight=F(1)
                for c in keys:
                    prob=q(c);den=prob if g=='E'else 1-prob if prob is not None else None
                    if den is None or den<=0:weight=None;break
                    weight/=den
                values.append((mi,weight,tt[i]==k+1))
            stages.append(values)
        S=F(1);curve=[];status='AVAILABLE';value=None
        for rows in stages:
            if any(w is None for _,w,_ in rows):status='MODEL_FAILURE';break
            den=sum(mi*w for mi,w,_ in rows);num=sum(mi*w for mi,w,e in rows if e)
            if S==0:curve.append({'denominator':den,'numerator':num,'hazard':None,'status':'ABSORBED_CONTINUATION'});continue
            if den<=0:
                curve.append({'denominator':den,'numerator':num,'hazard':None,'status':'NONESTIMABLE_EMPTY_RISKSET'})
                status='NONESTIMABLE_EMPTY_RISKSET';break
            h=num/den;curve.append({'denominator':den,'numerator':num,'hazard':h,'status':'DEFINED'});S*=1-h
        if status=='AVAILABLE':value=1-S
        ht_status='AVAILABLE';ht=F(0)
        for rows in stages:
            for mi,w,event in rows:
                if event:
                    if w is None:ht_status='MODEL_FAILURE';ht=None;break
                    ht+=mi*w
            if ht is None:break
        if ht is not None:ht/=N
        if g in source.get('unsupported_policies',[]):status=ht_status='IDENTIFICATION_NOT_SUPPORTED';value=ht=None;curve=None
        refs[g+'_PL']=(status,value);refs[g+'_HT']=(ht_status,ht);hazards[g]=curve
    return refs,hazards
def main():
    assert read(HERE/'runs/dev_analyses_001/execution.json')['status']=='COMPLETED'
    assert read(HERE/'technical_reproduction_002/RNG_REPRODUCTION.json')['status']=='PASS'
    manifest=read(HERE/'inputs/dev_task_stream_manifest.json');catalog=read(HERE/'inputs/dev_source_catalog.json')['datasets']
    ledger=read(HERE/'dev_analyses/attempt_ledger.json')['records'];tasks=[t for t in manifest['tasks']if t['phase']in['DEV_P','DEV_D']]
    assert len(ledger)==len(tasks)==108
    out=[];audits=[];sample_risks=[];sources={};compression=[];context={}
    run_id=sys.argv[1]if len(sys.argv)>1 else'001'
    compressed=HERE/('map_compression_evidence_'+run_id);compressed.mkdir(exist_ok=False)
    try:
        for task in tasks:
            did=task['dataset_id'];ds=catalog[did]
            if did not in sources:
                assert sha(HERE/ds['source_file'])==ds['source_sha256'];sources[did]=read(HERE/ds['source_file'])
            source=sources[did];folder=HERE/'dev_analyses'/task['task_id'];record=read(folder/'attempt_record.json')
            raw=(folder/'draw.int32le').read_bytes();indices=list(struct.unpack('<'+'i'*task['N'],raw))
            context={'task':task['task_id'],'input_sha256':ds['source_sha256'],'draw_sha256':sha(folder/'draw.int32le'),'stage':'DIRECT_LEDGER_IDENTITY'}
            assert len(raw)==4*task['N']and all(1<=i<=task['N']for i in indices)
            assert record==ledger[task['task_id']]and record['task']==task and record['input_sha256']==ds['source_sha256']
            assert 'execution_error'not in record and record['all_scientific_fields_exact_vs_uncached']is True
            assert record['CI_computed']is False and record['bootstrap_SE_computed']is False
            assert record['formal_M']==record['formal_B']==0
            a=read(folder/'result_full.json');b=read(folder/'uncached_comparator_full.json')
            compare(science(a),science(b),'UNCACHED/'+task['task_id'])
            if task['phase']=='DEV_P':assert indices==list(range(1,task['N']+1))
            else:
                replay=HERE/'technical_reproduction_002/maps'/f'{task["task_id"]}.int32le';assert replay.read_bytes()==raw
                t=time.perf_counter();c0=time.process_time();c=zlib.compress(raw,level=6);p=compressed/f'{task["task_id"]}.int32le.zlib';p.write_bytes(c)
                compression_wall=time.perf_counter()-t;compression_CPU=time.process_time()-c0;t=time.perf_counter();c0=time.process_time();decomp=zlib.decompress(p.read_bytes());dtime=time.perf_counter()-t;dCPU=time.process_time()-c0
                assert decomp==raw
                compression.append({'task_id':task['task_id'],'raw_sha256':sha(folder/'draw.int32le'),'raw_bytes':len(raw),
                  'compressed_bytes':len(c),'compressed_sha256':sha(p),'compress_and_write_wall_seconds':compression_wall,
                  'compress_and_write_CPU_seconds':compression_CPU,'decompress_read_verify_wall_seconds':dtime,
                  'decompress_read_verify_CPU_seconds':dCPU,'lossless_all_ordered_indices_exact':True})
            context['stage']='INDEPENDENT_SOURCE_GRAPH_COUNTS_STOPPED_WEIGHTS_ESS'
            mapping={'map_id':task['task_id'],'indices':indices,'forced_fit_failures':[]}
            audits.append(independent_audit(task['N'],mapping,task['method'],a,source))
            context['stage']='INDEPENDENT_SAMPLE_PL_HT_AND_CONTRASTS'
            refs,hazards=independent_risk(source,indices,task['method'])
            for output,(status,val)in refs.items():
                z=a['components'][output];assert z['source_status']==status,(output,z['source_status'],status)
                assert close(z['value'],val),(output,z['value'],str(val))
                if output.endswith('_PL')and hazards[output[0]]is not None:
                    hh=hazards[output[0]];assert len(z['hazards'])==len(hh)
                    for aa,bb in zip(z['hazards'],hh):
                        assert aa['status']==bb['status']
                        for k in ['denominator','numerator','hazard']:assert close(aa[k],bb[k]),(output,k,aa[k],str(bb[k]))
            e,d=refs['E_PL'][1],refs['D_PL'][1]
            if e is not None and d is not None:
                assert close(a['contrasts']['RD']['value'],e-d)
                if d>0:
                    assert close(a['contrasts']['RR']['value'],e/d)
                    assert close(a['contrasts']['logRR']['value'],math.log(float(e))-math.log(float(d))if e>0 else None)
                else:assert a['contrasts']['RR']['value']is None and a['contrasts']['RR']['point_status']=='NONESTIMABLE_ZERO_REFERENCE'
            else:assert a['contrasts']['RD']['value']is None and a['contrasts']['RR']['value']is None
            sample_risks.append({'task_id':task['task_id'],'status':'PASS','PL_HT_reference':'INDEPENDENT_DIRECT_HISTORY_FORMULAS_AND_EXACT_RATIONAL_WEIGHTS_NO_DUT_HELPERS'})
            fits_failed=any(z['status']=='MODEL_FAILURE'for z in a['fits'].values())if isinstance(a['fits'],dict)else False
            cls='MODEL_DEPENDENCY_FAILED'if fits_failed else'SCIENTIFIC_NONESTIMABLE'if any(a['components'][g+'_PL']['value']is None for g in ['E','D'])else'PRIMARY_POINTS_AVAILABLE'
            out.append({'task':task,'statistical_attempt_status':record['attempt_execution_status'],'point_path_class':cls,
              'prepared_refit_R_CPU_seconds':record['timings']['prepared_refit_R_CPU_seconds'],
              'prepared_refit_wall_seconds':record['timings']['prepared_refit_seconds'],
              'full_ledger_IO_seconds':record['timings']['full_result_serialization_IO_seconds'],
              'all_checks_evidence_wall_seconds':record['timings']['all_checks_and_evidence_wall_seconds'],
              'all_checks_R_CPU_seconds':record['timings']['R_CPU_seconds'],'mapping_IO_seconds':record['timings']['mapping_IO_seconds'],
              'draw_generation_seconds':record['timings']['draw_generation_seconds'],
              'uncached_wall_seconds':record['timings']['uncached_comparator_seconds'],'core_stages':record['timings']['core_stages'],
              'result_full_bytes':(folder/'result_full.json').stat().st_size,'uncached_comparator_bytes':(folder/'uncached_comparator_full.json').stat().st_size,
              'attempt_metadata_bytes':(folder/'attempt_record.json').stat().st_size,'complete_draw_bytes':len(raw),
              'per_output_point_status':{g:a['components'][g]['point_status']for g in ['E_PL','D_PL','E_HT','D_HT']},
              'warnings':record['warnings'],'explicit_instance_check':record.get('explicit_instances_agree')})
            if task['phase']=='DEV_D'and task['draw_id']==1:assert record['explicit_instances_agree']is True
        assert len(out)==108 and sum(x['task']['phase']=='DEV_P'for x in out)==44 and len(compression)==64
        assert len({sha(HERE/'dev_analyses'/t['task_id']/'draw.int32le')for t in tasks if t['phase']=='DEV_D'})==64
    except BaseException as ex:
        with(HERE/('FIRST_INDEPENDENT_DIFFERENCE_'+run_id+'.json')).open('x',encoding='utf-8')as f:json.dump({'context':context,'error':repr(ex),'traceback':traceback.format_exc(),'expected_or_truth_changed':False},f,indent=2)
        raise
    result={'status':'PASS','DEV_P_method_analyses':44,'DEV_D_random_draws':64,'source_datasets':28,'source_subjects':84000,
      'all_108_full_raw_vs_prepared_scientific_fields_exact':True,'independent_graph_count_weight_ESS_audits':audits,
      'independent_PL_HT_contrast_audits':sample_risks,'all_records':out,'compression':compression,
      'statistical_attempt_status_counts':dict(Counter(r['statistical_attempt_status']for r in out)),
      'point_path_counts':dict(Counter(r['point_path_class']for r in out)),
      'explicit_instance_checks':sum(r['explicit_instance_check']is True for r in out),
      'formal_M':0,'formal_B':0,'bootstrap_SE_CI_coverage_computed':False,'G01_G08':'ACCURATE_SUBEVIDENCE_ONLY_NOT_FULL_GATE_PASS'}
    with(HERE/'results/DEV_PILOT_INDEPENDENT_VERIFICATION.json').open('x',encoding='utf-8')as f:json.dump(result,f,ensure_ascii=False,indent=2)
    print(json.dumps({k:result[k]for k in ['status','DEV_P_method_analyses','DEV_D_random_draws','statistical_attempt_status_counts','point_path_counts','explicit_instance_checks']}))
if __name__=='__main__':main()
