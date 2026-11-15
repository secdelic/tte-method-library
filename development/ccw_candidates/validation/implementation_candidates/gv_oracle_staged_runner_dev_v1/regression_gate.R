source('staged_core.R');dir.create('results/deterministic_gate_001',recursive=TRUE)
out<-'results/deterministic_gate_001';stopifnot(!file.exists(file.path(out,'gate_R.json')))
fixtures<-jsonlite::read_json('../gv_oracle_minimal_core_v1/inputs/small_fixtures.json',simplifyVector=FALSE)
all<-list();checks<-list();i<-0L
for(case in fixtures$cases) {
  id<-list(file=runtime_identity$small_input_sha256,case_id=case$case_id)
  pd<-prepare_dataset(case,id);indices<-full_draw(case$multiplicity);all[[case$case_id]]<-list()
  for(mode in c('KNOWN','Q_SAT')) {
    if(case$case_id=='ZERO_E_POPULATION_SUPPORT'&&mode=='Q_SAT')next
    a<-frozen_core$analyze_candidate(case,mode,TRUE);b<-refit_one_draw(pd,indices,id,mode)
    same<-identical(science_only(a),science_only(b));i<-i+1L
    checks[[i]]<-list(case_id=case$case_id,mode=mode,scientific_R_identity=same)
    all[[case$case_id]][[mode]]<-b
    full_writer(b,file.path(out,paste0(case$case_id,'_',mode,'.json')))
    if(!same) {
      saveRDS(list(case=case,old=a,new=b),file.path(out,'first_counterexample.rds'))
      stop('SCIENTIFIC_INVARIANCE_REGRESSION_BLOCKED')
    }
  }
}
jsonlite::write_json(list(cases=all),file.path(out,'actual_small.json'),auto_unbox=TRUE,pretty=FALSE,digits=17,na='null',null='null')
fixed<-list();ii<-0L
for(N in c(1000L,5000L)) {
  spec<-jsonlite::read_json(paste0('../gv_oracle_minimal_core_v1/inputs/engineering_N',N,'.json'),simplifyVector=FALSE)
  source_case<-list(subjects=spec$subjects,multiplicity=as.list(rep(1L,N)),known_q=spec$known_q,representation='SOURCE_MULTIPLICITY')
  # Forced fit failures are fixed method/test configuration, not a cached fit.
  for(mapping in spec$maps) {
    cc<-source_case;cc$forced_fit_failures<-mapping$forced_fit_failures
    id<-list(file=runtime_identity$engineering_input_sha256[[as.character(N)]],test_configuration=mapping$map_id)
    pd<-prepare_dataset(cc,id);ix<-as.integer(unlist(mapping$indices))
    for(mode in c('KNOWN','Q_SAT')) {
      cc$multiplicity<-as.list(tabulate(ix,nbins=N))
      a<-frozen_core$analyze_candidate(cc,mode,TRUE);b<-refit_one_draw(pd,ix,id,mode)
      same<-identical(science_only(a),science_only(b));ii<-ii+1L
      fixed[[ii]]<-list(N=N,map_id=mapping$map_id,mode=mode,scientific_R_identity=same)
      full_writer(b,file.path(out,paste0('N',N,'_',mapping$map_id,'_',mode,'.json')))
      if(!same){saveRDS(list(old=a,new=b,id=id),file.path(out,'first_counterexample.rds'));stop('FIXED_MAPPING_REGRESSION_BLOCKED')}
    }
  }
}
# Cache invalidation and aliasing, before any DEV randomness.
case<-fixtures$cases[[1L]];id<-list(input='CACHE_TEST_INPUT_A');p<-prepare_dataset(case,id);ix<-full_draw(case$multiplicity)
rejects<-function(expr,needle) {e<-tryCatch({force(expr);NULL},error=function(e)conditionMessage(e));!is.null(e)&&grepl(needle,e,fixed=TRUE)}
invalidation<-list(
  different_input=rejects(refit_one_draw(p,ix,list(input='CACHE_TEST_INPUT_B'),'KNOWN'),'PREPARED_IDENTITY_MISMATCH'),
  different_outputs=rejects(refit_one_draw(p,ix,id,'KNOWN',outputs=list('R_E_ONLY')),'PREPARED_IDENTITY_MISMATCH'),
  locked_mutation=rejects({p$payload<-NULL},'locked binding'))
old_policy<-runtime_identity$policy_history;runtime_identity$policy_history<-'DIFFERENT_POLICY'
invalidation$policy_change<-rejects(refit_one_draw(p,ix,id,'KNOWN'),'PREPARED_IDENTITY_MISMATCH');runtime_identity$policy_history<-old_policy
old_model<-runtime_identity$model;runtime_identity$model<-'DIFFERENT_MODEL'
invalidation$model_change<-rejects(refit_one_draw(p,ix,id,'KNOWN'),'PREPARED_IDENTITY_MISMATCH');runtime_identity$model<-old_model
old_code<-runtime_identity$code;runtime_identity$code<-'DIFFERENT_CODE'
invalidation$code_change<-rejects(refit_one_draw(p,ix,id,'KNOWN'),'PREPARED_IDENTITY_MISMATCH');runtime_identity$code<-old_code
unlockBinding('payload',p);v<-p$payload;v$typed$W[1L]<-1-v$typed$W[1L];p$payload<-v;lockBinding('payload',p)
invalidation$mutated_source<-rejects(refit_one_draw(p,ix,id,'KNOWN'),'PREPARED_PAYLOAD_CHANGED')
stopifnot(all(unlist(invalidation)),i==39L,ii==32L)
jsonlite::write_json(list(status='PASS',small=checks,fixed=fixed,invalidation=invalidation,DEV_randomness_executed=FALSE),
  file.path(out,'gate_R.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
cat('39 small and all 16 fixed maps in both modes exact; all invalidation checks passed.\n')
