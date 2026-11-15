"""REF-DP-RATIONAL-V1. Absolute policy masses; no estimator imports."""
from fractions import Fraction
from pathlib import Path
import json,sys,time

def encode(x):
    if isinstance(x,Fraction):return {'numerator':x.numerator,'denominator':x.denominator}
    if isinstance(x,dict):return {k:encode(v) for k,v in x.items()}
    if isinstance(x,list):return [encode(v) for v in x]
    return x

def solve(law,g):
    params=law['parameters'];queries={}
    def take(kind,*idx):
        name=kind+(':'+','.join(map(str,idx)) if idx else '')
        item=params[name]
        assert g in item['consumers'] and item['structurally_legal'] and item['exact'] is not None,('OUT_OF_DOMAIN',name,g)
        z=item['exact'];assert type(z['numerator']) is type(z['denominator']) is int and z['denominator']>0
        queries[name]=queries.get(name,0)+1
        p=Fraction(z['numerator'],z['denominator']);assert 0<=p<=1
        return p
    omega=take('omega');m={}
    for w in (0,1):
        bw=take('b',w)
        for l in (0,1):m[(w,l,0)]=(omega if w else 1-omega)*(bw if l else 1-bw)
    stages=[];events=[];moments=[];prefix_events=Fraction(0)
    for k in range(5):
        assert all(v>0 for v in m.values())
        before=sum(m.values(),Fraction(0));assert before+prefix_events==1
        cond={}
        for variable in ['W','L']:
            selected=[(x,v) for x,v in m.items() if variable=='W' or x[2]==0]
            pi=sum((v for x,v in selected),Fraction(0))
            nu=sum((x[0 if variable=='W' else 1]*v for x,v in selected),Fraction(0))
            tag='C' if pi==0 else ('B' if law['law_id']=='LAW-ZERO-E-V1' and g=='E' and k==4 else 'A')
            cond[variable]={'pi':pi,'nu':nu,'mean':nu/pi if pi>0 else None,'truth_class':tag}
        moments.append(cond)
        action={};nxt={};d=Fraction(0);survive=Fraction(0)
        for (w,l,s),mass in sorted(m.items()):
            if s:options=[(1,Fraction(1))]
            elif g=='E' and k==3:options=[(1,Fraction(1))]
            elif g=='D' and k<=3:options=[(0,Fraction(1))]
            else:
                assert not(g=='E' and k==4)
                q=take('q',k,w,l);options=[(0,1-q),(1,q)]
            assert sum(v for b,v in options)==1
            for b,a in options:
                if a==0:continue
                c=mass*a;assert c>0
                action[f'{w},{l},{s},{b}']=c
                h=take('h',k,w,l,s,b);d+=c*h;v=c*(1-h);survive+=v
                if v==0 or k==4:continue
                r=take('r',k,w,l,s,b)
                for lp,p in [(0,1-r),(1,r)]:
                    if p==0:continue
                    xx=(w,lp,b);nxt[xx]=nxt.get(xx,Fraction(0))+v*p
        assert sum(action.values(),Fraction(0))==before
        assert d+survive==before
        if k<4:assert sum(nxt.values(),Fraction(0))==survive
        prefix_events+=d;assert prefix_events+survive==1
        stages.append({'k':k,'predecision_state_mass':{','.join(map(str,x)):v for x,v in sorted(m.items())},
          'post_action_state_mass':action,'predecision_mass':before,'post_action_mass':sum(action.values(),Fraction(0)),
          'event_at_k_plus_1':d,'survival_after_interval':survive,'cumulative_event_mass':prefix_events,
          'conservation_residual':before-d-survive,'all_nonnegative':all(v>=0 for v in action.values())})
        events.append(d);m=nxt
    risk=sum(events,Fraction(0));assert risk+survive==1
    return {'law_id':law['law_id'],'policy':g,'d':events,'S5':survive,'R5':risk,
      'risk_truth_class':'B' if law['law_id']=='LAW-ZERO-E-V1' and g=='E' else 'A',
      'stage':stages,'conditional_moments':moments,'kernel_query_counts':queries}

def main():
    assert sys.version_info[:3]==(3,12,14)
    data=json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'));out={};contrast={}
    for name,law in data['laws'].items():
        out[name]={g:solve(law,g) for g in ['E','D']}
        e=out[name]['E']['R5'];d=out[name]['D']['R5']
        rr={'status':'FINITE','value':e/d} if d>0 else {'status':'EXTENDED_POSITIVE_INFINITY' if e>0 else 'UNDEFINED_BOTH_ZERO','value':None}
        contrast[name]={'RD':e-d,'RR':rr,'truth_class':'B' if name=='LAW-ZERO-E-V1' else 'A'}
    result={'algorithm':'REF-DP-RATIONAL-V1','result_status':'REFERENCE_RESULTS_GENERATED_AWAITING_REVIEW','laws':out,'contrasts':contrast}
    with Path(sys.argv[2]).open('x',encoding='utf-8',newline='\n') as f:json.dump(encode(result),f,sort_keys=True,indent=2);f.write('\n')
    print(json.dumps({'status':'COMPLETE','law_policy_combinations':14}))
if __name__=='__main__':main()
