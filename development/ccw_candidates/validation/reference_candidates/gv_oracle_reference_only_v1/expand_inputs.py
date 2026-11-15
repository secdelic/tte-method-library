import os
"""Expand adopted integer rules, never simulations or fitted probabilities."""
from pathlib import Path
from fractions import Fraction
import json,hashlib,itertools
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
LAW_NAMES=['BASE-RATIONAL','NULL','NEAR','ZERO-E','NATURAL-ZERO','ABSORBED','SPARSE']
SOURCES={
 'reports/GV_ORACLE_F1_RATIONAL_PARAMETER_AND_REACHABILITY_MANIFEST_CANDIDATE_V1.md':'08335cfa8426d2bdfd0c1012dacabad35c62becdba6fa4fc22cbda90b78e6598',
 'reports/GV_ORACLE_F1_SCENARIO_TARGET_OVERRIDE_BINDINGS_CANDIDATE_V1.md':'8352c717dad7a19dcc296a305036c5a9dfd6c24a882ba0716cd8ca7cfc09beb0',
 'reports/GV_ORACLE_F1_FINAL_Q_MODEL_REQUIRED_CELL_SPEC_CANDIDATE_V1.md':'7060addccdf82068c4315490907b1d7a076f87daf773ecd58364e731f0cc45a8',
 'reports/GV_ORACLE_F1_INDEPENDENT_TRUTH_INPUT_AND_ALGORITHM_BINDING_CANDIDATE_V1.md':'0c803a230c451b797fb528d195ad17ce714c10efea22d8f48d30d114e30fe193'}
def rat(n,d):
    assert type(n) is int and type(d) is int and d>0
    f=Fraction(n,d);return {'numerator':f.numerator,'denominator':f.denominator}
def raw(law,kind,idx):
    if kind=='omega':return 2,5
    if kind=='b':return 1+idx[0],4
    k,w,l=idx[:3]
    if kind=='q':
        if law=='NEAR' and k==3:return 1,1000
        if (law=='ZERO-E' and k==3) or (law=='NATURAL-ZERO' and k==0):return 0,1
        return 8+2*k+3*w+4*l+2*w*l,40
    s,b=idx[3:]
    if kind=='h':
        if law=='ABSORBED' and k==0:return 1,1
        return 14+k+2*w+4*l-(0 if law=='NULL' else 3*b+s),80000 if law=='SPARSE' else 80
    assert kind=='r' and k<4
    return 8+k+2*w+5*l-(0 if law=='NULL' else 2*b+s),20
def key(kind,idx):return kind+(':'+','.join(map(str,idx)) if idx else '')
def expand(law):
    rows={}
    def add(kind,idx,structural=True):
        rows[key(kind,idx)]={'kind':kind,'indices':list(idx),'structurally_legal':structural,'consumers':[],
          'exact':None,'binding_rule':'THETA-RULES-V1' if law=='BASE-RATIONAL' else 'BASE->'+law+'_ONLY',
          'status':'STRUCTURAL_NA' if not structural else 'UNCONSUMED_NO_QUERY'}
    add('omega',());[add('b',(w,)) for w in (0,1)]
    for k,w,l in itertools.product(range(5),(0,1),(0,1)):add('q',(k,w,l))
    for kind,limit in [('h',5),('r',4)]:
        for k,w,l,(s,b) in itertools.product(range(limit),(0,1),(0,1),[(0,0),(0,1),(1,1)]):add(kind,(k,w,l,s,b),not(k==0 and s==1))
    reach={}
    # Input-domain audit only. Neither reference imports this traversal.
    for consumer in ['P','E','D']:
        for kind,idx in [('omega',()),('b',(0,)),('b',(1,))]:rows[key(kind,idx)]['consumers'].append(consumer)
        states={(w,l,0) for w,l in itertools.product((0,1),repeat=2)}
        reach[consumer]=[]
        for k in range(5):
            reach[consumer].append([list(x) for x in sorted(states)])
            nxt=set()
            for w,l,s in states:
                if s:actions=[(1,1,1)]
                elif consumer=='E' and k==3:actions=[(1,1,1)]
                elif consumer=='D' and k<4:actions=[(0,1,1)]
                else:
                    assert not(consumer=='E' and k==4)
                    rows[key('q',(k,w,l))]['consumers'].append(consumer)
                    n,d=raw(law,'q',(k,w,l));actions=[(0,d-n,d),(1,n,d)]
                for b,n,d in actions:
                    if n==0:continue
                    hk=key('h',(k,w,l,s,b));rows[hk]['consumers'].append(consumer)
                    hn,hd=raw(law,'h',(k,w,l,s,b))
                    if hn==hd or k==4:continue
                    rk=key('r',(k,w,l,s,b));rows[rk]['consumers'].append(consumer)
                    rn,rd=raw(law,'r',(k,w,l,s,b))
                    if rn<rd:nxt.add((w,0,b))
                    if rn>0:nxt.add((w,1,b))
            states=nxt
    for row in rows.values():
        row['consumers']=sorted(set(row['consumers']))
        if row['consumers']:
            assert row['structurally_legal']
            row['exact']=rat(*raw(law,row['kind'],row['indices']))
            row['status']='ADOPTED_RULE_EXPANDED_REFERENCE_ONLY'
        elif row['structurally_legal']:
            row['dormant_binding']='Named base rule retained as text; no value assigned on this unconsumed conditional domain.'
    assert len(rows)==131 and sum(not x['structurally_legal'] for x in rows.values())==8
    return {'law_id':'LAW-'+law+'-V1','single_override':None if law=='BASE-RATIONAL' else law,
      'parameters':rows,'legal_predecision_states_by_consumer':reach,
      'policy_ids':{'E':'G_EARLY_BY_3','D':'G_DEFER_THROUGH_3'},'horizon':5}
def main():
    for p,h in SOURCES.items():assert hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h,p
    target=HERE/'inputs';target.mkdir(exist_ok=True)
    data={'schema':'EXACT_INTEGER_PARAMETER_INPUT_V1','authority_status':'F_LEAVES_PENDING',
      'reference_status':'CANDIDATE_NOT_GOLDEN','sources':SOURCES,
      'laws':{('LAW-'+law+'-V1'):expand(law) for law in LAW_NAMES}}
    with (target/'expanded_parameters.json').open('x',encoding='utf-8',newline='\n') as f:json.dump(data,f,ensure_ascii=False,sort_keys=True,indent=2);f.write('\n')
    attachment=Path(os.environ['TTE_CCW_AUTHORIZATION_SOURCE'])
    rawbody=attachment.read_bytes();body=rawbody.decode('utf-8-sig').replace('\r\n','\n').rstrip('\n')
    evidence={'kind':'CURRENT_RESEARCHER_REFERENCE_ONLY_EXECUTION_AUTHORIZATION','source_path':str(attachment),
      'raw_sha256':hashlib.sha256(rawbody).hexdigest(),'body_utf8_lf_no_trailing_newline_sha256':hashlib.sha256(body.encode()).hexdigest(),
      'message_body':body,'platform_message_id':None,'signature':None,'F_leaf_approval':False,'golden_authorized':False}
    with (target/'execution_authorization.json').open('x',encoding='utf-8',newline='\n') as f:json.dump(evidence,f,ensure_ascii=False,indent=2);f.write('\n')
    print(json.dumps({'laws':len(data['laws']),'slots_per_law':131,'base_assigned':sum(p['exact'] is not None for p in data['laws']['LAW-BASE-RATIONAL-V1']['parameters'].values()),'no_randomness':True}))
if __name__=='__main__':main()
