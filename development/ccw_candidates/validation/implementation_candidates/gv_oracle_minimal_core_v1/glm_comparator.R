# Independent counts and intercept-binomial GLM; does NOT source candidate code.
args<-commandArgs(trailingOnly=TRUE)
stopifnot(as.character(getRversion())=='4.5.1',as.character(packageVersion('stats'))=='4.5.1')
data<-jsonlite::read_json('inputs/small_fixtures.json',simplifyVector=FALSE)
oracle<-jsonlite::read_json('inputs/independent_expected.json',simplifyVector=FALSE)
out<-list()
for(case in data$cases) {
  spec<-oracle$cases[[case$case_id]]$Q_SAT
  if(is.null(spec)||!isTRUE(spec$input_valid)) next
  required<-sort(unique(unlist(spec$required_cells)));fits<-list()
  for(c in required) {
    v<-as.integer(strsplit(substring(c,2),'_',fixed=TRUE)[[1]]);k<-v[1];w<-v[2];ell<-v[3]
    n<-0;d<-0
    for(i in seq_along(case$subjects)) {
      s<-case$subjects[[i]];multip<-as.numeric(case$multiplicity[[i]])
      st<-s$actual_effective_start_time;t<-s$terminal_time
      if(multip==0||(!is.null(st)&&st<0)||(!is.null(t)&&t<=0)) next
      if((!is.null(t)&&t<=k)||(!is.null(st)&&st<k)||s$W!=w) next
      h<-Filter(function(r)r$k==k,s$history);stopifnot(length(h)==1)
      if(h[[1]]$L!=ell) next
      n<-n+multip
      if(!is.null(st)&&st==k) d<-d+multip
    }
    if(n==0||d==0||d==n) {fits[[c]]<-list(n=n,d=d,status='NO_FINITE_INTERIOR_MLE');next}
    warnings<-character()
    fit<-withCallingHandlers(stats::glm(cbind(d,n-d)~1,family=stats::binomial(link='logit'),start=0,
      control=stats::glm.control(epsilon=1e-12,maxit=100,trace=FALSE),na.action=stats::na.fail),warning=function(e){warnings<<-c(warnings,conditionMessage(e));invokeRestart('muffleWarning')})
    fits[[c]]<-list(n=n,d=d,q=unname(stats::predict(fit,type='response')[[1]]),eta=unname(coef(fit)[[1]]),
      converged=fit$converged,status='FINITE_MLE',warnings=warnings,iterations=fit$iter)
  }
  out[[case$case_id]]<-fits
}
jsonlite::write_json(list(comparator='INDEPENDENT_R451_INTERCEPT_BINOMIAL_GLM_V1',counts_do_not_read_DUT=TRUE,
  candidate_code_imported=FALSE,results=out),args[[1]],pretty=TRUE,auto_unbox=TRUE,digits=17,na='null',null='null')
cat('GLM_COMPARATOR_CASES=',length(out),'\n')
