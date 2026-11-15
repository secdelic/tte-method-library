# Isolated scientific-invariant performance candidate V1; original core preserved.
# Never sourced by canonical runtime; no new statistical method or execution gate.
# No outcome H/R kernels, random sampling, bootstrap, CI computation or MIS.
clock <- function() unname(proc.time()[[3L]])
contract_stop <- function(reason) stop(structure(list(message=reason,call=NULL),class=c('ccw_input_contract','error','condition')))
null_number <- function(x) if(is.null(x)) NA_real_ else as.numeric(x)
cell_name <- function(k,w,l) paste0('c',k,'_',w,'_',l)

assemble_input <- function(case) {
  ss <- case$subjects; n <- length(ss)
  ids <- vapply(ss, function(s) as.character(s$id), '')
  original <- vapply(ss,function(s) as.character(s$original_id), '')
  if(anyDuplicated(ids)) contract_stop('DUPLICATE_ANALYSIS_SOURCE_ID')
  m <- as.numeric(unlist(case$multiplicity)); if(length(m)!=n || any(!is.finite(m)|m<0|m!=floor(m))) contract_stop('INVALID_MULTIPLICITY')
  st <- vapply(ss,function(s) null_number(s$actual_effective_start_time),0.0)
  tt <- vapply(ss,function(s) null_number(s$terminal_time),0.0)
  W <- vapply(ss,function(s) as.numeric(s$W),0.0)
  if(any(!is.na(st)&(!is.finite(st)|st!=floor(st))) || any(!is.na(tt)&(!is.finite(tt)|tt!=floor(tt)))) contract_stop('INVALID_TIME_GRID')
  # Baseline eligibility is determined before consulting postbaseline history.
  eligible <- (is.na(st)|st>=0)&(is.na(tt)|tt>0)
  L <- matrix(NA_real_,n,5L)
  for(i in which(eligible)) {
    if(!W[i]%in%c(0,1)) contract_stop('INVALID_BASELINE_W')
    if(!is.na(st[i])&&(st[i]<0||st[i]>4)) contract_stop('UNSUPPORTED_ACTION_TIME')
    if(!is.na(tt[i])&&tt[i]>5) contract_stop('UNSUPPORTED_TERMINAL_TIME')
    if(!is.na(st[i])&&!is.na(tt[i])&&st[i]>=tt[i]) contract_stop('ACTUAL_START_NOT_BEFORE_TERMINAL')
    if(!is.na(st[i])&&st[i]==0&&!identical(ss[[i]]$t0_start_stage,'POST_ELIGIBILITY_AND_CLONE_ASSIGNMENT')) contract_stop('INVALID_T0_MICRO_ORDER')
    h <- ss[[i]]$history
    ks <- vapply(h,function(z) as.numeric(z$k),0.0)
    should <- (0:4)[is.na(tt[i])|(0:4)<tt[i]]
    if(length(ks)!=length(should)||anyDuplicated(ks)||!setequal(ks,should)) contract_stop('INVALID_HISTORY_GRID')
    # Same per-subject validation order; batch the equal-length history rows.
    values<-vapply(h,function(z)c(as.numeric(z$availability_time),as.numeric(z$measurement_time),as.numeric(z$L)),numeric(3L))
    av<-values[1L,];mt<-values[2L,];l<-values[3L,]
    if(any(!is.finite(av)|!is.finite(mt)|mt>av|av>as.integer(ks)|!l%in%c(0,1))) contract_stop('INVALID_MEASUREMENT_AVAILABILITY')
    L[i,as.integer(ks)+1L]<-l
  }
  if(sum(m[eligible])<=0) contract_stop('NO_ELIGIBLE_DRAW_INSTANCES')
  # Explicit instances may share an original ID only as the declared draw representation.
  if(anyDuplicated(original[eligible&m>0])&&!identical(case$representation,'EXPLICIT_DRAW_INSTANCES')) contract_stop('DUPLICATE_ORIGINAL_SUBJECT')
  list(ids=ids,original=original,st=st,tt=tt,W=W,L=L,m=m,eligible=eligible,N=sum(m[eligible]),n=n)
}

plan_clones <- function(x) {
  plans<-list();acs<-list();events<-list();req<-list(E_PL=character(),D_PL=character(),E_HT=character(),D_HT=character())
  # Cache labels only; unreachable/NA cells are never selected or fitted.
  cells<-vapply(0:4,function(k)cell_name(k,x$W,x$L[,k+1L]),character(x$n))
  for(g in c('E','D')) {
    active<-x$eligible & x$m>0;periods<-list();censors<-list();settlements<-list()
    for(k in 0:4) {
      terminated<-which(active & !is.na(x$tt)&x$tt==k)
      if(length(terminated)) settlements[[length(settlements)+1L]]<-list(k=k,ids=x$ids[terminated])
      active<-active & (is.na(x$tt)|x$tt>k)
      actual<-!is.na(x$st)&x$st==k
      deviation<-active & if(g=='D'&&k<=3) actual else if(g=='E'&&k==3) (is.na(x$st)|x$st>3) else FALSE
      censors<-c(censors,lapply(which(deviation),function(i)list(id=x$ids[i],k=k)))
      active[deviation]<-FALSE;ix<-which(active)
      if(g=='E') {
        prefix<-rep(list(character()),length(ix))
        if(k>=3) {
          late<-which(!is.na(x$st[ix])&x$st[ix]==3)
          prefix[late]<-as.list(cells[ix[late],4L])
        }
      } else {
        blocks<-seq_len(min(k,3)+1L)
        prefix<-lapply(ix,function(i)cells[i,blocks])
      }
      ev<-!is.na(x$tt[ix])&x$tt[ix]==k+1
      allcells<-unique(unlist(prefix,use.names=FALSE));eventcells<-unique(unlist(prefix[ev],use.names=FALSE))
      req[[paste0(g,'_PL')]]<-union(req[[paste0(g,'_PL')]],allcells)
      req[[paste0(g,'_HT')]]<-union(req[[paste0(g,'_HT')]],eventcells)
      periods[[k+1L]]<-list(k=k,indices=ix,event=ev,prefix=prefix)
    }
    # k5 terminal settlement only; no k5 action, L, new AC or entry.
    terminal5<-which(active & !is.na(x$tt)&x$tt==5)
    if(length(terminal5)) settlements[[length(settlements)+1L]]<-list(k=5,ids=x$ids[terminal5])
    plans[[g]]<-periods;acs[[g]]<-censors;events[[g]]<-settlements
  }
  req<-lapply(req,function(z) sort(unique(z)))
  list(plans=plans,AC=acs,terminal_settlements=events,required_cells=req,graph_fixed_before_fit=TRUE)
}

count_original_P <- function(x,requested) {
  counts<-setNames(vector('list',length(requested)),requested)
  for(c in requested) {
    v<-as.integer(strsplit(substring(c,2),'_',fixed=TRUE)[[1]]);k<-v[1];w<-v[2];l<-v[3]
    valid<-x$eligible & x$m>0 & (is.na(x$tt)|x$tt>k) & (is.na(x$st)|x$st>=k)
    valid<-valid & x$W==w & !is.na(x$L[,k+1L]) & x$L[,k+1L]==l
    ix<-which(valid)
    counts[[c]]<-list(n=sum(x$m[ix]),d=sum(x$m[ix][!is.na(x$st[ix])&x$st[ix]==k]))
  }
  counts
}

fit_requested_cells <- function(counts,graph,case,mode) {
  fits<-list()
  for(c in names(counts)) {
    nd<-counts[[c]];consumers<-names(Filter(function(z)c%in%z,graph$required_cells))
    if(mode=='KNOWN') {
      q<-case$known_q[[c]]
      if(is.null(q)||q$denominator<=0) contract_stop('KNOWN_PROBABILITY_NOT_AVAILABLE')
      probability<-as.numeric(q$numerator)/as.numeric(q$denominator)
      if(!is.finite(probability)||probability<0||probability>1) contract_stop('INVALID_KNOWN_PROBABILITY')
      fits[[c]]<-list(n=nd$n,d=nd$d,q=probability,eta=if(probability>0&&probability<1) log(probability)-log1p(-probability) else NA_real_,status='KNOWN',consumers=consumers)
    } else {
      failure<-if(nd$n==0) 'NO_TRAINING_OPPORTUNITY' else if(nd$d==0||nd$d==nd$n) 'NO_FINITE_INTERIOR_MLE' else if(c%in%unlist(case$forced_fit_failures)) 'PREDECLARED_TEST_FIT_FAILURE' else NULL
      fits[[c]]<-list(n=nd$n,d=nd$d,q=if(is.null(failure))nd$d/nd$n else NA_real_,eta=if(is.null(failure))log(nd$d)-log(nd$n-nd$d) else NA_real_,status=if(is.null(failure))'FINITE_MLE' else 'MODEL_FAILURE',reason=failure,consumers=consumers)
      if(!is.null(failure)) fits[[c]]$failed_stage<-if(any(startsWith(consumers,'E_'))&&any(startsWith(consumers,'D_'))) 'NUISANCE_SHARED' else if(any(startsWith(consumers,'E_'))) 'NUISANCE_E_SPECIFIC' else 'NUISANCE_D_SPECIFIC'
    }
  }
  fits
}

materialize_weights <- function(x,graph,fits,g) {
  lapply(graph$plans[[g]],function(stage) {
    weights<-vapply(stage$prefix,function(prefix) {
      value<-1
      for(c in prefix) {
        p<-fits[[c]]$q
        if(is.na(p)) return(NA_real_)
        denom<-if(g=='E')p else 1-p
        if(denom<=0) return(NA_real_)
        value<-value/denom
      }
      if(!is.finite(value)||value<0) return(NA_real_)
      value
    },0.0)
    list(k=stage$k,indices=stage$indices,weights=weights,m=x$m[stage$indices],event=stage$event)
  })
}

product_limit_candidate <- function(stages) {
  survival<-1;out<-list()
  for(stage in stages) {
    if(any(!is.finite(stage$weights))) return(list(value=NA_real_,source_status='MODEL_FAILURE',hazards=out))
    den<-sum(stage$m*stage$weights);num<-sum(stage$m[stage$event]*stage$weights[stage$event])
    if(survival==0) {out[[length(out)+1L]]<-list(denominator=den,numerator=num,hazard=NA_real_,status='ABSORBED_CONTINUATION');next}
    if(den<=0) {out[[length(out)+1L]]<-list(denominator=den,numerator=num,hazard=NA_real_,status='NONESTIMABLE_EMPTY_RISKSET');return(list(value=NA_real_,source_status='NONESTIMABLE_EMPTY_RISKSET',hazards=out))}
    hazard<-num/den
    if(!is.finite(hazard)||hazard<0||hazard>1) stop('Invalid candidate hazard, no clipping')
    survival<-survival*(1-hazard)
    out[[length(out)+1L]]<-list(denominator=den,numerator=num,hazard=hazard,status='DEFINED')
  }
  list(value=1-survival,source_status='AVAILABLE',hazards=out)
}

direct_HT_candidate <- function(stages,N) {
  total<-0
  for(stage in stages) {
    j<-which(stage$event)
    if(any(!is.finite(stage$weights[j]))) return(list(value=NA_real_,source_status='MODEL_FAILURE'))
    total<-total+sum(stage$m[j]*stage$weights[j])
  }
  list(value=total/N,source_status='AVAILABLE')
}

point_contract <- function(components) {
  decorate<-function(v) {
    if(is.na(v$value)) {
      v$point_status<-if(v$source_status=='MODEL_FAILURE')'UNAVAILABLE_EXECUTION_DEPENDENCY' else 'NONESTIMABLE_UNSUPPORTED'
      v$CI_eligibility<-if(v$source_status=='MODEL_FAILURE')'INELIGIBLE_EXECUTION_DEPENDENCY' else 'INELIGIBLE_UNSUPPORTED'
    } else {
      v$point_status<-if(v$value==0||v$value==1)'ESTIMABLE_BOUNDARY' else 'ESTIMABLE_INTERIOR'
      v$CI_eligibility<-if(v$value>0&&v$value<1)'ELIGIBLE_BY_CONSERVATIVE_POLICY' else 'INELIGIBLE_BOUNDARY_POLICY'
    };v
  }
  components$E_PL<-decorate(components$E_PL);components$D_PL<-decorate(components$D_PL)
  e<-components$E_PL$value;d<-components$D_PL$value
  if(is.na(e)||is.na(d)) {
    fail<-components$E_PL$source_status=='MODEL_FAILURE'||components$D_PL$source_status=='MODEL_FAILURE'
    v<-list(value=NA_real_,point_status=if(fail)'UNAVAILABLE_EXECUTION_DEPENDENCY' else 'UNAVAILABLE_DEPENDENCY',CI_eligibility=if(fail)'INELIGIBLE_EXECUTION_DEPENDENCY' else 'INELIGIBLE_UNSUPPORTED')
    contrasts<-list(RD=v,RR=v,logRR=v)
  } else {
    ci<-if(e>0&&e<1&&d>0&&d<1)'ELIGIBLE_BY_CONSERVATIVE_POLICY' else 'INELIGIBLE_BOUNDARY_POLICY'
    contrasts<-list(RD=list(value=e-d,point_status=if(abs(e-d)==1)'ESTIMABLE_BOUNDARY' else 'ESTIMABLE_INTERIOR',CI_eligibility=ci))
    if(d==0) {
      v<-list(value=NA_real_,point_status='NONESTIMABLE_ZERO_REFERENCE',CI_eligibility='INELIGIBLE_UNDEFINED');contrasts$RR<-v;contrasts$logRR<-v
    } else {
      contrasts$RR<-list(value=e/d,point_status=if(e==0)'ESTIMABLE_BOUNDARY' else 'ESTIMABLE_INTERIOR',CI_eligibility=ci)
      contrasts$logRR<-list(value=if(e>0)log(e)-log(d) else NA_real_,point_status=if(e>0)'ESTIMABLE_INTERIOR' else 'NONESTIMABLE_LOG_ZERO_NUMERATOR',CI_eligibility=if(e>0)ci else 'INELIGIBLE_UNDEFINED')
    }
  }
  list(components=components,contrasts=contrasts)
}

analyze_candidate <- function(case,mode='KNOWN',retain_ledger=TRUE) {
  if(!mode%in%c('KNOWN','Q_SAT')) stop('MIS and other methods are HOLD')
  timing<-list();tic<-clock()
  x<-tryCatch(assemble_input(case),ccw_input_contract=function(e)e)
  timing$input_assembly<-clock()-tic
  if(inherits(x,'ccw_input_contract')) return(list(input_valid=FALSE,reason=x$message,failed_stage='INPUT_ELIGIBILITY_SHARED',timings=timing,CI_computed=FALSE))
  tic<-clock();graph<-plan_clones(x);timing$clone_AC_symbolic_graph<-clock()-tic
  tic<-clock();requested<-sort(unique(unlist(graph$required_cells,use.names=FALSE)));counts<-count_original_P(x,requested);timing$required_cell_and_count<-clock()-tic
  tic<-clock();fits<-fit_requested_cells(counts,graph,case,mode);timing$Q_analytic<-clock()-tic
  tic<-clock();weights<-setNames(lapply(c('E','D'),function(g)materialize_weights(x,graph,fits,g)),c('E','D'));timing$clone_AC_weights_materialization<-clock()-tic
  tic<-clock();comp<-list();diagnostics<-list()
  for(g in c('E','D')) {
    if(g%in%unlist(case$unsupported_policies)) {
      comp[[paste0(g,'_PL')]]<-list(value=NA_real_,source_status='IDENTIFICATION_NOT_SUPPORTED')
      comp[[paste0(g,'_HT')]]<-list(value=NA_real_,source_status='IDENTIFICATION_NOT_SUPPORTED')
    } else {
      comp[[paste0(g,'_PL')]]<-product_limit_candidate(weights[[g]])
      comp[[paste0(g,'_HT')]]<-direct_HT_candidate(weights[[g]],x$N)
    }
    for(role in c('PL','HT')) {
      output<-paste0(g,'_',role);dep<-graph$required_cells[[output]]
      bad<-dep[vapply(dep,function(c)fits[[c]]$status=='MODEL_FAILURE',TRUE)]
      unsupported<-if(mode=='KNOWN')dep[vapply(dep,function(c)if(g=='E')fits[[c]]$q==0 else fits[[c]]$q==1,TRUE)] else character()
      if(length(unsupported)) comp[[output]]<-list(value=NA_real_,source_status='IDENTIFICATION_NOT_SUPPORTED',unsupported_cells=unsupported)
      if(length(bad)) {comp[[output]]$failed_cells<-bad;comp[[output]]$failed_stage<-unique(vapply(bad,function(c)fits[[c]]$failed_stage,''));comp[[output]]$failure_reasons<-lapply(fits[bad],function(z)z$reason)}
      if(role=='HT') {comp[[output]]$point_status<-if(!is.na(comp[[output]]$value)) 'ESTIMABLE_FINITE' else if(length(bad))'UNAVAILABLE_EXECUTION_DEPENDENCY' else 'NONESTIMABLE_UNSUPPORTED';comp[[output]]$CI_eligibility<-'NOT_APPLICABLE_COMPARATOR'}
    }
    diagnostics[[g]]<-lapply(weights[[g]],function(z) {
      if(isTRUE(case$forced_diagnostic_failure)) return(list(value=NULL,reason='NUMERICAL_FAILURE',failed_stage='DIAGNOSTICS'))
      if(!length(z$indices)) return(list(value=NULL,reason='UNDEFINED_EMPTY_SET'))
      if(any(!is.finite(z$weights)|z$weights<0)) return(list(value=NULL,reason='INVALID_WEIGHT'))
      s1<-sum(z$m*z$weights);s2<-sum(z$m*z$weights^2);ess<-s1*s1/s2
      if(!is.finite(s1)||!is.finite(s2)||!is.finite(ess)) return(list(value=NULL,reason='NUMERICAL_FAILURE',failed_stage='DIAGNOSTICS'))
      if(s1<=0||s2<=0) return(list(value=NULL,reason='UNDEFINED_ZERO_MASS'))
      list(S1=s1,S2=s2,ESS=ess,unique_original_subjects=length(unique(x$original[z$indices])),draw_instances=sum(z$m),stage='ENTER_NEXT_INTERVAL',weight_time=z$k)
    })
  }
  result<-point_contract(comp);timing$PL_HT_contrasts_and_diagnostics<-clock()-tic
  result$input_valid<-TRUE;result$eligible_instances<-x$N;result$unique_original_subjects<-length(unique(x$original[x$eligible&x$m>0]))
  result$mode<-mode;result$required_cells<-graph$required_cells;result$graph_fixed_before_fit<-graph$graph_fixed_before_fit
  result$estimand_dependencies<-list(R_E='E_PL',R_D='D_PL',RD=c('E_PL','D_PL'),RR=c('E_PL','D_PL'),logRR=c('E_PL','D_PL'))
  result$P_counts<-counts;result$fits<-fits;result$artificial_censors<-graph$AC;result$terminal_settlements<-graph$terminal_settlements
  result$entry_members<-lapply(graph$plans,function(pp) lapply(pp,function(z)x$ids[z$indices]));result$entry_ESS<-diagnostics
  result$CI_computed<-FALSE;result$bootstrap_attempts_executed<-0L;result$timings<-timing
  if(retain_ledger) result$entry_weight_ledger<-lapply(weights,function(pp)lapply(pp,function(z) lapply(seq_along(z$indices),function(a)list(id=x$ids[z$indices[a]],weight=z$weights[a],multiplicity=z$m[a],event=z$event[a]))))
  result
}
