"""Compare actual candidate to presealed exact closed-form ledgers and GLM."""
from pathlib import Path
from fractions import Fraction
import json,sys,math,hashlib
HERE=Path(__file__).resolve().parent
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def scalar(x):return Fraction(x['numerator'],x['denominator']) if isinstance(x,dict) and set(x)=={'numerator','denominator'} else x
def arr(x):return [] if x is None else x if isinstance(x,list) else [x]
def main():
    actual=read(HERE/(sys.argv[1] if len(sys.argv)>1 else 'results/small_attempt_002/actual_small.json'));expected=read(HERE/'inputs/independent_expected.json');fixtures=read(HERE/'inputs/small_fixtures.json')
    glm=read(HERE/'results/glm_comparator_001.json');checks=[]
    target=HERE/(sys.argv[2] if len(sys.argv)>2 else 'results/small_verification_001.json')
    def check(name,condition,detail=None):
        checks.append({'check':name,'status':'PASS' if condition else 'FAIL','detail':detail})
        assert condition,(name,detail)
    def close(name,x,y,atol=1e-12,rtol=1e-10):
        y=scalar(y)
        check(name,x is None if y is None else x is not None and math.isfinite(x) and abs(x-float(y))<=atol+rtol*abs(float(y)),{'actual':x,'reference':str(y)})
    status='FAIL'
    try:
        sealed=read(HERE/'inputs/sealed_input_manifest.json')
        for p,h in sealed['files'].items():check('SEALED_INPUT:'+p,hashlib.sha256((HERE/'inputs'/p).read_bytes()).hexdigest()==h)
        for cid,modes in expected['cases'].items():
            src=next(c for c in fixtures['cases'] if c['case_id']==cid)
            for mode,e in modes.items():
                a=actual['cases'][cid][mode];prefix=cid+':'+mode
                check(prefix+':INPUT_STATUS',a['input_valid']==e['input_valid'])
                if not e['input_valid']:
                    check(prefix+':INPUT_REASON',a['reason']==e['reason']);continue
                check(prefix+':BASELINE_N',a['eligible_instances']==e['eligible_instances'])
                check(prefix+':PREFIT_GRAPH',a['graph_fixed_before_fit'] is True)
                for output,req in e['required_cells'].items():check(prefix+':REQUIRED:'+output,sorted(arr(a['required_cells'][output]))==req)
                for cell,nd in e['P_counts'].items():
                    for v in ['n','d']:check(prefix+':COUNT:'+cell+':'+v,a['P_counts'][cell][v]==nd[v])
                for g in ['E','D']:
                    for k in range(5):
                        check(prefix+f':ENTRY:{g}:{k}',sorted(arr(a['entry_members'][g][k]))==sorted(e['entry_members'][g][k]))
                        observed={r['id']:r for r in arr(a['entry_weight_ledger'][g][k])}
                        for row in e['entry_weight_ledger'][g][k]:
                            z=observed[row['id']];close(prefix+f':WEIGHT:{g}:{k}:'+row['id'],z['weight'],row['weight'])
                            check(prefix+f':MULT:{g}:{k}:'+row['id'],z['multiplicity']==row['multiplicity'])
                            check(prefix+f':EVENT:{g}:{k}:'+row['id'],z['event']==row['event'])
                        if e['entry_ESS'][g][k] is not None and not src.get('forced_diagnostic_failure'):
                            for z in ['S1','S2','ESS']:close(prefix+f':ESS:{g}:{k}:'+z,a['entry_ESS'][g][k].get(z),e['entry_ESS'][g][k][z])
                        if src.get('forced_diagnostic_failure'):check(prefix+f':OPTIONAL_DIAG:{g}:{k}',a['entry_ESS'][g][k]['reason']=='NUMERICAL_FAILURE')
                    norm=lambda c:sorted((v['id'],v['k']) for v in arr(c))
                    check(prefix+':AC:'+g,norm(a['artificial_censors'][g])==norm(e['artificial_censors'][g]))
                for output,component in e['components'].items():
                    observed=a['components'][output]
                    check(prefix+':STATUS:'+output,observed['source_status']==component['source_status'])
                    close(prefix+':POINT:'+output,observed['value'],component['value'])
                    if 'hazards' in component:
                        check(prefix+':HAZARD_COUNT:'+output,len(observed['hazards'])==len(component['hazards']))
                        for t,(hh,oo) in enumerate(zip(observed['hazards'],component['hazards']),1):
                            check(prefix+':HAZARD_STAGE:'+output+':'+str(t),hh['status']==oo['status'])
                            for z in ['numerator','denominator','hazard']:close(prefix+':HAZARD:'+output+':'+str(t)+':'+z,hh[z],oo[z])
                re=scalar(e['components']['E_PL']['value']);rd=scalar(e['components']['D_PL']['value'])
                if re is not None and rd is not None:
                    close(prefix+':RD',a['contrasts']['RD']['value'],re-rd)
                    if rd>0:
                        close(prefix+':RR',a['contrasts']['RR']['value'],re/rd)
                        if re==0:check(prefix+':LOG_ZERO_NUMERATOR',a['contrasts']['logRR']['point_status']=='NONESTIMABLE_LOG_ZERO_NUMERATOR')
                    else:check(prefix+':SAMPLE_ZERO_REFERENCE',a['contrasts']['RR']['value'] is None and a['contrasts']['RR']['point_status']=='NONESTIMABLE_ZERO_REFERENCE')
                    if re in [0,1] or rd in [0,1]:check(prefix+':CI_BOUNDARY',a['contrasts']['RD']['CI_eligibility']=='INELIGIBLE_BOUNDARY_POLICY')
                check(prefix+':NO_CI_EXECUTED',a['CI_computed'] is False and a['bootstrap_attempts_executed']==0)
                if mode=='Q_SAT':
                    for cell,ref in glm['results'].get(cid,{}).items():
                        fit=a['fits'][cell]
                        for z in ['n','d']:check(prefix+':INDEPENDENT_GLM_COUNT:'+cell+':'+z,fit[z]==ref[z])
                        if fit['status']=='FINITE_MLE':
                            check(prefix+':GLM_CONVERGED:'+cell,ref['converged'] is True)
                            close(prefix+':GLM_Q:'+cell,fit['q'],ref['q'],1e-9,1e-8)
                            close(prefix+':GLM_ETA:'+cell,fit['eta'],ref['eta'],1e-7,1e-8)
        # Explicit checks of the intended scientific boundaries, not only numeric totals.
        main=actual['cases']['HAND_LEDGER_MAIN']
        check('PL_VS_HT_NOT_FORCED_EQUAL',main['KNOWN']['components']['E_PL']['value']!=main['KNOWN']['components']['E_HT']['value'])
        check('ONLY_FOUR_REQUESTED_CELLS',len(main['Q_SAT']['fits'])==4)
        check('UNCONSUMED_FAILURE_NOT_GLOBAL',actual['cases']['UNCONSUMED_FIT_FAILURE']['Q_SAT']['components']['E_PL']['source_status']=='AVAILABLE')
        local=actual['cases']['E_LOCAL_MODEL_FAILURE_D_VALID']['Q_SAT']
        check('LOCAL_E_FAILURE',local['components']['E_PL']['source_status']=='MODEL_FAILURE')
        check('LEGAL_D_PRESERVED',local['components']['D_PL']['source_status']=='AVAILABLE')
        shared=actual['cases']['SHARED_FIT_FAILURE']['Q_SAT']
        check('SHARED_FAILURE_BOTH_CONSUMERS',all(shared['components'][g+'_PL']['source_status']=='MODEL_FAILURE' for g in ['E','D']))
        check('EMPTY_PL_NOT_REPLACED_BY_HT',actual['cases']['E_EMPTY_RISKSET_D_LEGAL']['KNOWN']['components']['E_PL']['source_status']=='NONESTIMABLE_EMPTY_RISKSET' and actual['cases']['E_EMPTY_RISKSET_D_LEGAL']['KNOWN']['components']['E_HT']['value']==0)
        for mode in ['KNOWN','Q_SAT']:
            aa=actual['cases']['NONUNIFORM_MULTIPLICITY'][mode];bb=actual['cases']['EXPLICIT_DRAW_EQUIVALENT'][mode]
            for out in ['E_PL','D_PL','E_HT','D_HT']:close('MULTIPLICITY_EXPLICIT:'+mode+':'+out,aa['components'][out]['value'],bb['components'][out]['value'])
            for g in ['E','D']:
                for k in range(5):
                    for field in ['S1','S2','ESS']:close('MULTIPLICITY_INSTANCE_S2:'+mode+g+str(k)+field,aa['entry_ESS'][g][k].get(field),bb['entry_ESS'][g][k].get(field))
        status='PASS'
    finally:
        output={'status':status,'checks':checks,'test_case_mode_runs':sum(len(x) for x in expected['cases'].values()),'G01_G08':'NOT_EXECUTED / NOT_ASSESSED','CI_calibration':False,'production_authorized':False}
        with target.open('x',encoding='utf-8') as f:json.dump(output,f,ensure_ascii=False,indent=2)
    print(json.dumps({'status':status,'checks':len(checks),'case_mode_runs':output['test_case_mode_runs']}))
if __name__=='__main__':main()
