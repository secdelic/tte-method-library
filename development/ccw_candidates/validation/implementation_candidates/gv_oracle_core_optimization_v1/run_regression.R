args<-commandArgs(trailingOnly=TRUE)
old<-normalizePath('../gv_oracle_minimal_core_v1',mustWork=TRUE)
target<-args[[1]];if(dir.exists(target))stop('Preserve prior regression attempts')
dir.create(target,recursive=TRUE)
source('write_result.R')
baseline<-new.env();optimized<-new.env()
sys.source(file.path(old,'core_candidate.R'),baseline)
sys.source('core_candidate_optimized.R',optimized)
cases<-jsonlite::read_json(file.path(old,'inputs/small_fixtures.json'),simplifyVector=FALSE)$cases
results<-list(baseline=list(),optimized=list());checks<-list();n<-0L
strip_timing<-function(x){x$timings<-NULL;x}
for(case in cases) {
  cid<-case$case_id;results$baseline[[cid]]<-list();results$optimized[[cid]]<-list()
  for(mode in c('KNOWN','Q_SAT')) {
    if(cid=='ZERO_E_POPULATION_SUPPORT'&&mode=='Q_SAT')next
    a<-baseline$analyze_candidate(case,mode,retain_ledger=TRUE)
    b<-optimized$analyze_candidate(case,mode,retain_ledger=TRUE)
    same<-identical(strip_timing(a),strip_timing(b))
    n<-n+1L;checks[[n]]<-list(case_id=cid,mode=mode,all_R_fields_identical_excluding_timings=same)
    results$baseline[[cid]][[mode]]<-a;results$optimized[[cid]][[mode]]<-b
  }
}
for(version in names(results)) {
  obj<-list(candidate='MINIMAL_CCW_DETERMINISTIC_CORE',cases=results[[version]],RNG_executed=FALSE,CI_computed=FALSE)
  if(version=='baseline')jsonlite::write_json(obj,file.path(target,'baseline_small.json'),pretty=TRUE,auto_unbox=TRUE,digits=17,na='null',null='null')
  else jsonlite::write_json(obj,file.path(target,'optimized_small.json'),pretty=TRUE,auto_unbox=TRUE,digits=17,na='null',null='null')
}
# Independently exercise the optimized result writer on every full small ledger.
for(cid in names(results$optimized))for(mode in names(results$optimized[[cid]]))
  write_result_optimized(results$optimized[[cid]][[mode]],file.path(target,paste0(cid,'_',mode,'_serialized.json')))
jsonlite::write_json(list(checks=checks,case_mode_runs=n,status=if(all(vapply(checks,function(z)z$all_R_fields_identical_excluding_timings,TRUE)))'PASS' else 'FAIL'),
  file.path(target,'regression_R_identity.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
stopifnot(n==39L,all(vapply(checks,function(z)z$all_R_fields_identical_excluding_timings,TRUE)))
cat('Exact R identity: ',n,' case x mode; excluding timings only.\n',sep='')
