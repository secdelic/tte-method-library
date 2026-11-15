from pathlib import Path
import json,subprocess,sys,hashlib,importlib.util
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;OLD=HERE.parent/'gv_oracle_minimal_core_v1';OPT=HERE.parent/'gv_oracle_core_optimization_v1'
sys.path.insert(0,str(OPT))
from verify_optimization import read,science,compare
from finalize_evidence import independent_audit
def main():
    out=HERE/'results/deterministic_gate_001';gate=read(out/'gate_R.json');assert gate['status']=='PASS'
    subprocess.run([sys.executable,'-X','utf8',str(OLD/'verify_small.py'),str(out/'actual_small.json'),str(out/'independent_expected_verification.json')],check=True)
    small=read(out/'actual_small.json')['cases'];compare(science(small),science(read(OLD/'results/small_attempt_003/actual_small.json')['cases']))
    for cid,modes in small.items():
        for mode,result in modes.items():compare(result,read(out/f'{cid}_{mode}.json'),'FULL_WRITER/'+cid+'/'+mode)
    audits=[]
    for n in [1000,5000]:
        ss=read(OLD/f'inputs/engineering_N{n}.json')
        for mapping in ss['maps']:
            for mode in ['KNOWN','Q_SAT']:
                name=f'N{n}_{mapping["map_id"]}_{mode}.json';a=read(out/name)
                compare(science(a),science(read(OPT/'results/audit_full_001'/name)),name)
                audits.append(independent_audit(n,mapping,mode,a,ss))
    assert len(gate['small'])==39 and len(gate['fixed'])==32 and all(gate['invalidation'].values())
    result={'status':'PASS','small_case_modes':39,'frozen_independent_checks':len(read(out/'independent_expected_verification.json')['checks']),
      'fixed_maps':16,'fixed_map_modes':32,'independent_full_audits':audits,'cache_invalidation':gate['invalidation'],
      'all_R_scientific_fields_exact':True,'full_writer_schema_and_numbers_exact':True,'DEV_randomness_allowed_after_this_gate':True}
    with(out/'DETERMINISTIC_GATE_COMPLETE.json').open('x',encoding='utf-8')as f:json.dump(result,f,ensure_ascii=False,indent=2)
    print(json.dumps({k:v for k,v in result.items()if k!='independent_full_audits'}))
if __name__=='__main__':main()
