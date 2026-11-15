"""REF-ANALYTIC-V1: separate algebra plus exact intermediate comparisons.
Does not import DP or enumeration code, or create an alternative DGP.
"""
from fractions import Fraction as Q
from pathlib import Path
import json,sys,hashlib,ast,operator

def restore(x):
    if isinstance(x,dict) and set(x)=={'numerator','denominator'}:
        assert type(x['numerator']) is type(x['denominator']) is int and x['denominator']>0
        return Q(x['numerator'],x['denominator'])
    if isinstance(x,dict):return {k:restore(v) for k,v in x.items()}
    if isinstance(x,list):return [restore(v) for v in x]
    return x
def serial(x):
    if isinstance(x,Q):return {'numerator':x.numerator,'denominator':x.denominator}
    if isinstance(x,dict):return {k:serial(v) for k,v in x.items()}
    if isinstance(x,list):return list(map(serial,x))
    return x
def main():
    src=Path(sys.argv[1]);folder=Path(sys.argv[2])
    raw=json.loads(src.read_text(encoding='utf-8'));data=restore(raw)
    dp=restore(json.loads((folder/'dp_exact.json').read_text(encoding='utf-8')))
    en=restore(json.loads((folder/'enum_exact.json').read_text(encoding='utf-8')))
    checks=[];detail=[]
    def check(name,condition,evidence=None):
        checks.append({'check':name,'status':'PASS' if condition else 'FAIL','evidence':evidence})
        assert condition, name
    def val(law,kind,*idx):
        return data['laws'][law]['parameters'][kind+(':'+','.join(map(str,idx)) if idx else '')]['exact']
    def integer_expr(text):
        node=ast.parse(text,mode='eval').body
        def go(n):
            if isinstance(n,ast.Constant) and type(n.value) is int:return n.value
            assert isinstance(n,ast.BinOp) and type(n.op) in [ast.Add,ast.Sub,ast.Mult]
            return {ast.Add:operator.add,ast.Sub:operator.sub,ast.Mult:operator.mul}[type(n.op)](go(n.left),go(n.right))
        return go(node)
    # Independently read all 131 manifest table rows rather than trust expansion.
    root=Path(__file__).resolve().parents[3]
    manifest=(root/'reports/GV_ORACLE_F1_RATIONAL_PARAMETER_AND_REACHABILITY_MANIFEST_CANDIDATE_V1.md').read_text(encoding='utf-8')
    base=data['laws']['LAW-BASE-RATIONAL-V1']['parameters'];matched=set()
    for line in manifest.splitlines():
        if not line.startswith('| '):continue
        cols=[x.strip() for x in line.strip().strip('|').split('|')]
        name=cols[0]
        if name=='omega':key='omega'
        elif name.startswith('b_'):key='b:'+name[2:]
        elif name[:2] in ['q_','h_','r_']:key=name[0]+':'+name[2:]
        else:continue
        if key not in base:continue
        entry=base[key];cell=cols[3]
        if 'STRUCTURAL_NA' in cell:check('INPUT_MANIFEST:'+key,entry['exact'] is None and not entry['structurally_legal'])
        else:
            n,d=cell.rsplit('/',1)
            exact=Q(integer_expr(n),int(d))
            check('INPUT_MANIFEST:'+key,entry['exact']==exact)
        matched.add(key)
    check('INPUT_MANIFEST_ALL_131',len(matched)==131,len(matched))
    for law,policies in dp['laws'].items():
        check(law+':CONTRAST_EXACT',dp['contrasts'][law]==en['contrasts'][law])
        for g,a in policies.items():
            b=en['laws'][law][g]
            fields=['law_id','policy','d','S5','R5','risk_truth_class','stage','conditional_moments']
            for field in fields:check(law+':'+g+':EXACT_'+field,a[field]==b[field])
            check(law+':'+g+':LEAF_CONSERVATION',b['enumeration_evidence']['all_local_residuals_zero'])
            check(law+':'+g+':TOTAL_MASS',a['S5']+sum(a['d'])==1)
            check(law+':'+g+':NONNEGATIVE',a['R5']>=0 and a['S5']>=0 and all(x>=0 for x in a['d']))
            # Baseline and first event interval independent direct four-state sum.
            pw=val(law,'omega');lmean=(1-pw)*val(law,'b',0)+pw*val(law,'b',1)
            check(law+':'+g+':BASELINE_W',a['conditional_moments'][0]['W']['mean']==pw)
            check(law+':'+g+':BASELINE_L',a['conditional_moments'][0]['L']['mean']==lmean)
            d1=Q(0)
            for w in [0,1]:
                for l in [0,1]:
                    pp=(pw if w else 1-pw)*(val(law,'b',w) if l else 1-val(law,'b',w))
                    if g=='D':d1+=pp*val(law,'h',0,w,l,0,0)
                    else:
                        q=val(law,'q',0,w,l)
                        if q<1:d1+=pp*(1-q)*val(law,'h',0,w,l,0,0)
                        if q>0:d1+=pp*q*val(law,'h',0,w,l,0,1)
            check(law+':'+g+':FIRST_EVENT',d1==a['d'][0],d1)
            for k in range(5):
                st=a['stage'][k]
                check(law+':'+g+f':STAGE_{k}',st['conservation_residual']==0 and st['cumulative_event_mass']+st['survival_after_interval']==1)
                if k<4:check(law+':'+g+f':NEXT_{k}',st['survival_after_interval']==a['stage'][k+1]['predecision_mass'])
            if g=='E':check(law+':E:L4_EMPTY',a['conditional_moments'][4]['L']['pi']==0 and a['conditional_moments'][4]['L']['mean'] is None)
            if law=='LAW-ABSORBED-V1':
                check(law+':'+g+':ABSORB',a['d']==[Q(1),Q(0),Q(0),Q(0),Q(0)] and a['S5']==0)
                check(law+':'+g+':NO_POST_TERMINAL_QUERY',all(not x.startswith('r:') and (not x.startswith(('q:','h:')) or x[2]=='0') for x in a['kernel_query_counts']))
                check(law+':'+g+':EMPTY_AFTER_1',all(a['conditional_moments'][k][z]['truth_class']=='C' for k in range(1,5) for z in ['W','L']))
            detail.append({'law':law,'policy':g,'status':'PASS','leaves':b['enumeration_evidence']['leaf_count']})
    null=dp['laws']['LAW-NULL-V1']
    check('NULL_RISKS_EQUAL',null['E']['R5']==null['D']['R5']>0)
    check('NULL_RD_ZERO_RR_ONE',dp['contrasts']['LAW-NULL-V1']['RD']==0 and dp['contrasts']['LAW-NULL-V1']['RR']['value']==1)
    # Stronger null check: after marginalising treatment, all W/L state masses coincide.
    for k in range(5):
        sums=[]
        for g in ['E','D']:
            s={}
            for ident,mass in null[g]['stage'][k]['predecision_state_mass'].items():
                wl=','.join(ident.split(',')[:2]);s[wl]=s.get(wl,Q(0))+mass
            sums.append(s)
        check('NULL_WL_MARGINAL_'+str(k),sums[0]==sums[1])
    ze=dp['laws']['LAW-ZERO-E-V1']['E'];zd=dp['laws']['LAW-ZERO-E-V1']['D']
    check('ZERO_E_LABELS',ze['risk_truth_class']=='B' and zd['risk_truth_class']=='A' and dp['contrasts']['LAW-ZERO-E-V1']['truth_class']=='B')
    for k in range(4):check('ZERO_E_EARLY_DOMAIN_'+str(k),all(ze['conditional_moments'][k][z]['truth_class']=='A' for z in ['W','L']))
    check('ZERO_E_W4_B_L4_C',ze['conditional_moments'][4]['W']['truth_class']=='B' and ze['conditional_moments'][4]['L']['truth_class']=='C')
    sensitivity=[]
    for ident,mass in ze['stage'][3]['predecision_state_mass'].items():
        w,l,s=map(int,ident.split(','))
        if s:continue
        r=val('LAW-ZERO-E-V1','r',3,w,l,0,1)
        v=(1-r)*val('LAW-ZERO-E-V1','h',4,w,0,1,1)+r*val('LAW-ZERO-E-V1','h',4,w,1,1,1)
        coefficient=mass*(1-v)
        consumers=data['laws']['LAW-ZERO-E-V1']['parameters'][f'h:3,{w},{l},0,1']['consumers']
        check('ZERO_E_OFF_SUPPORT:'+ident,'P' not in consumers and 'E' in consumers and mass>0 and v<1 and coefficient>0)
        sensitivity.append({'state':ident,'residual_mass':mass,'later_event_v':v,'delta_R_E_per_delta_h':coefficient,
          'identity':'Delta R_E = m * delta * (1-v); no alternative theta executed'})
    # Static import/AST audit: each reference has disjoint business functions.
    independence={}
    for script in ['ref_dp.py','ref_enum.py']:
        tree=ast.parse((Path(__file__).parent/script).read_text(encoding='utf-8'))
        imports=[n.module for n in ast.walk(tree) if isinstance(n,ast.ImportFrom)]+[x.name for n in ast.walk(tree) if isinstance(n,ast.Import) for x in n.names]
        check(script+':NO_SHARED_BUSINESS_IMPORTS',set(imports)<={'fractions','pathlib','json','sys','time'})
        independence[script]={'imports':imports,'functions':[n.name for n in ast.walk(tree) if isinstance(n,ast.FunctionDef)]}
    output={'algorithm':'REF-ANALYTIC-V1','status':'PASS','result_status':'REFERENCE_RESULTS_GENERATED_AWAITING_REVIEW',
      'checks':checks,'law_policy_runs':detail,'zero_E_symbolic_sensitivity':sensitivity,
      'implementation_independence':independence,'external_blinded_review':False,
      'G01_G08':'NOT_EXECUTED / NOT_ASSESSED','golden_status':'NOT_QUALIFIED'}
    with (folder/'validation_exact.json').open('x',encoding='utf-8',newline='\n') as f:json.dump(serial(output),f,ensure_ascii=False,sort_keys=True,indent=2);f.write('\n')
    print(json.dumps({'status':'PASS','checks':len(checks),'law_policy_combinations':len(detail),'exact_differences':0}))
if __name__=='__main__':main()
