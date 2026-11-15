# DEV-only adapter. Frozen optimized core and writer are sourced, never edited.
frozen_core<-new.env(parent=globalenv())
sys.source('../gv_oracle_core_optimization_v1/core_candidate_optimized.R',frozen_core)
source('../gv_oracle_core_optimization_v1/write_result.R')
runtime_identity<-jsonlite::read_json('inputs/runtime_identity.json',simplifyVector=FALSE)
immutable_env<-function(values) {
  e<-list2env(values,parent=emptyenv());lockEnvironment(e,bindings=TRUE);e
}
prepare_dataset<-function(case,input_identity,outputs=runtime_identity$outputs) {
  tic<-frozen_core$clock()
  # Probe source/history invariants only. Duplicate originals and draw counts
  # remain draw-dependent; the source is not fitted or cloned here.
  probe<-case;probe$multiplicity<-as.list(rep(1,length(case$subjects)))
  probe$representation<-'EXPLICIT_DRAW_INSTANCES'
  x<-tryCatch(frozen_core$assemble_input(probe),ccw_input_contract=function(e)e)
  reject<-if(inherits(x,'ccw_input_contract'))x$message else NULL
  typed<-if(is.null(reject))x[c('ids','original','st','tt','W','L','n')]else NULL
  metadata<-case[setdiff(names(case),c('subjects','multiplicity'))]
  key<-list(input=input_identity,policy_history=runtime_identity$policy_history,
    model=runtime_identity$model,outputs=outputs,code=runtime_identity$code)
  payload<-list(typed=typed,metadata=metadata,source_rejection=reject)
  snap<-serialize(payload,NULL,version=3)
  immutable_env(list(payload=payload,identity=key,snapshot=snap,
    prepare_seconds=frozen_core$clock()-tic,kind='GV_ORACLE_DEV_PREPARED_V1'))
}
prepared_payload<-function(p,identity,outputs) {
  if(!is.environment(p)||!environmentIsLocked(p)||!all(vapply(ls(p),function(n)bindingIsLocked(n,p),TRUE)))
    stop('PREPARED_OBJECT_NOT_IMMUTABLE')
  if(!identical(p$identity,list(input=identity,policy_history=runtime_identity$policy_history,
    model=runtime_identity$model,outputs=outputs,code=runtime_identity$code)))stop('PREPARED_IDENTITY_MISMATCH')
  if(!identical(serialize(p$payload,NULL,version=3),p$snapshot))stop('PREPARED_PAYLOAD_CHANGED')
  p$payload
}
draw_assembler<-function(case) {
  p<-prepared_payload(case$prepared,case$input_identity,case$outputs)
  if(!is.null(p$source_rejection))frozen_core$contract_stop(p$source_rejection)
  x<-p$typed;idx<-case$ordered_indices
  if(!is.integer(idx)||!length(idx)||anyNA(idx)||any(idx<1L|idx>x$n))frozen_core$contract_stop('INVALID_COMPLETE_DRAW_INDEX')
  x$m<-as.numeric(tabulate(idx,nbins=x$n))
  x$eligible<-(is.na(x$st)|x$st>=0)&(is.na(x$tt)|x$tt>0)
  x$N<-sum(x$m[x$eligible])
  if(x$N<=0)frozen_core$contract_stop('NO_ELIGIBLE_DRAW_INSTANCES')
  if(anyDuplicated(x$original[x$eligible&x$m>0])&&!identical(case$representation,'EXPLICIT_DRAW_INSTANCES'))
    frozen_core$contract_stop('DUPLICATE_ORIGINAL_SUBJECT')
  x
}
prepared_scope<-new.env(parent=frozen_core);prepared_scope$assemble_input<-draw_assembler
prepared_analyze<-frozen_core$analyze_candidate
environment(prepared_analyze)<-prepared_scope
refit_one_draw<-function(p,ordered_indices,input_identity,mode,outputs=runtime_identity$outputs,retain_ledger=TRUE) {
  payload<-prepared_payload(p,input_identity,outputs)
  case<-payload$metadata
  case$prepared<-p;case$ordered_indices<-ordered_indices;case$input_identity<-input_identity;case$outputs<-outputs
  prepared_analyze(case,mode,retain_ledger)
}
full_writer<-function(result,path) {
  # Same complete row schema, with a column writer for homogeneous weight rows.
  # This is serialization, not a compact omission mode or a new estimator.
  v<-result
  if(!is.null(v$entry_weight_ledger))v$entry_weight_ledger<-lapply(v$entry_weight_ledger,function(pp)lapply(pp,function(rows) {
    if(!length(rows))return(rows)
    data.frame(id=vapply(rows,function(z)z$id,''),weight=vapply(rows,function(z)z$weight,0.0),
      multiplicity=vapply(rows,function(z)z$multiplicity,0.0),event=vapply(rows,function(z)z$event,TRUE),stringsAsFactors=FALSE)
  }))
  write_result_optimized(v,path)
}
science_only<-function(z){z$timings<-NULL;z}
full_draw<-function(m)as.integer(rep(seq_along(m),times=as.integer(unlist(m))))
