"""REF-ENUM-HISTORY-V1. Complete history leaves, no DP state merging.
No imports from ref_dp, input expansion traversal, or statistical runtime.
Prefix masses below are reconstructed from finished leaves, not used to branch.
"""
import json,sys
from pathlib import Path
from fractions import Fraction as F

def packed(value):
    if isinstance(value,F):return dict(numerator=value.numerator,denominator=value.denominator)
    if isinstance(value,list):return list(map(packed,value))
    if isinstance(value,dict):return {key:packed(val) for key,val in value.items()}
    return value

def enumerate_policy(record,policy):
    cells=record['parameters'];asked={};leaves=[];local_checks=[]
    def probability(label,indices):
        ident=label+(':'+','.join(str(v) for v in indices) if indices else '')
        cell=cells[ident];assert cell['exact'] is not None and policy in cell['consumers'] and cell['structurally_legal'],ident
        integer=cell['exact'];n=integer['numerator'];den=integer['denominator']
        assert type(n)==int and type(den)==int and den>0
        ans=F(n,den);assert 0<=ans<=1
        asked[ident]=asked.get(ident,0)+1
        return ans
    def branch(w,ls,bs,path,mass):
        assert mass>0
        k=len(ls)-1;l=ls[-1];prior=bs[-1] if bs else 0
        assert 0<=k<5 and not(k==0 and prior)
        if prior:choices=((1,F(1)),)
        elif policy=='D' and k<4:choices=((0,F(1)),)
        elif policy=='E' and k==3:choices=((1,F(1)),)
        else:
            assert policy!='E' or k<3
            chance=probability('q',(k,w,l));choices=((0,1-chance),(1,chance))
        descendants=F(0)
        for current,pr in choices:
            if pr==0:continue
            amass=mass*pr
            history=path+[(k,w,l,prior,current)]
            death=probability('h',(k,w,l,prior,current))
            ev=amass*death;alive=amass*(1-death)
            if ev:
                leaves.append({'history':history,'terminal_time':k+1,'mass':ev})
                descendants+=ev
            if not alive:continue
            if k==4:
                leaves.append({'history':history,'terminal_time':None,'mass':alive})
                descendants+=alive
            else:
                chance_next=probability('r',(k,w,l,prior,current))
                for nextl,factor in [(0,1-chance_next),(1,chance_next)]:
                    if factor:
                        branch(w,ls+[nextl],bs+[current],history,alive*factor)
                        descendants+=alive*factor
        assert descendants==mass
        local_checks.append({'incoming':mass,'outgoing':descendants,'residual':mass-descendants})
    pw=probability('omega',())
    for w in [0,1]:
        pl=probability('b',(w,))
        for l in [0,1]:
            start=(pw if w else 1-pw)*(pl if l else 1-pl)
            if start:branch(w,[l],[],[],start)
    assert len(leaves)<=4776 and sum(x['mass'] for x in leaves)==1
    death_mass=[F(0)]*5;end_survival=F(0)
    states=[{} for _ in range(5)];actions=[{} for _ in range(5)]
    for leaf in leaves:
        assert leaf['mass']>0
        if leaf['terminal_time'] is None:end_survival+=leaf['mass']
        else:death_mass[leaf['terminal_time']-1]+=leaf['mass']
        for k,w,l,s,b in leaf['history']:
            sid=f'{w},{l},{s}';aid=f'{w},{l},{s},{b}'
            states[k][sid]=states[k].get(sid,F(0))+leaf['mass']
            actions[k][aid]=actions[k].get(aid,F(0))+leaf['mass']
    stages=[];mom=[];absorbed=F(0)
    for k in range(5):
        entering=sum(states[k].values(),F(0));after=sum(actions[k].values(),F(0))
        alive=sum(x['mass'] for x in leaves if x['terminal_time'] is None or x['terminal_time']>k+1)
        absorbed+=death_mass[k]
        assert entering==after==alive+death_mass[k] and alive+absorbed==1
        item={}
        for variable in ['W','L']:
            pairs=[(tuple(map(int,s.split(','))),v) for s,v in states[k].items()]
            if variable=='L':pairs=[(s,v) for s,v in pairs if s[-1]==0]
            pi=sum((v for s,v in pairs),F(0));nu=sum((s[0 if variable=='W' else 1]*v for s,v in pairs),F(0))
            cls='C' if pi==0 else ('B' if record['law_id']=='LAW-ZERO-E-V1' and policy=='E' and k==4 else 'A')
            item[variable]={'pi':pi,'nu':nu,'mean':nu/pi if pi else None,'truth_class':cls}
        mom.append(item)
        stages.append({'k':k,'predecision_state_mass':states[k],'post_action_state_mass':actions[k],
          'predecision_mass':entering,'post_action_mass':after,'event_at_k_plus_1':death_mass[k],
          'survival_after_interval':alive,'cumulative_event_mass':absorbed,
          'conservation_residual':entering-death_mass[k]-alive,'all_nonnegative':all(v>=0 for v in actions[k].values())})
    return {'law_id':record['law_id'],'policy':policy,'d':death_mass,'S5':end_survival,'R5':sum(death_mass),
      'risk_truth_class':'B' if record['law_id']=='LAW-ZERO-E-V1' and policy=='E' else 'A',
      'stage':stages,'conditional_moments':mom,'kernel_query_counts':asked,
      'enumeration_evidence':{'leaf_count':len(leaves),'local_branch_conservation_checks':len(local_checks),
         'all_local_residuals_zero':all(c['residual']==0 for c in local_checks)},'complete_leaves':leaves}

def main():
    assert sys.version_info[:3]==(3,12,14)
    inputs=json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'));laws={};contrasts={}
    for identity,table in inputs['laws'].items():
        laws[identity]={p:enumerate_policy(table,p) for p in ['E','D']}
        re=laws[identity]['E']['R5'];rd=laws[identity]['D']['R5']
        if rd:ratio={'status':'FINITE','value':re/rd}
        else:ratio={'status':'EXTENDED_POSITIVE_INFINITY' if re else 'UNDEFINED_BOTH_ZERO','value':None}
        contrasts[identity]={'RD':re-rd,'RR':ratio,'truth_class':'B' if identity=='LAW-ZERO-E-V1' else 'A'}
    output={'algorithm':'REF-ENUM-HISTORY-V1','result_status':'REFERENCE_RESULTS_GENERATED_AWAITING_REVIEW','laws':laws,'contrasts':contrasts}
    with Path(sys.argv[2]).open('x',encoding='utf-8',newline='\n') as file:json.dump(packed(output),file,sort_keys=True,indent=2);file.write('\n')
    print(json.dumps({'status':'COMPLETE','law_policy_combinations':14,'leaves':sum(x['enumeration_evidence']['leaf_count'] for law in laws.values() for x in law.values())}))
if __name__=='__main__':main()
