source('staged_core.R');source('rng_common.R')
stopifnot(jsonlite::read_json('inputs/DGP_INDEPENDENT_VALIDATION.json')$status=='PASS')
tasks<-jsonlite::read_json('inputs/dev_task_stream_manifest.json',simplifyVector=FALSE)
catalog<-jsonlite::read_json('inputs/dev_source_catalog.json',simplifyVector=FALSE)$datasets
bank<-jsonlite::read_json('rng/DEV_STREAM_BANK_V1.json',simplifyVector=FALSE)
code_identity<-jsonlite::read_json('inputs/pilot_execution_code_identity.json',simplifyVector=FALSE)
RNGkind(kind="L'Ecuyer-CMRG",normal.kind='Inversion',sample.kind='Rejection')
requested<-Filter(function(t)t$phase%in%c('DEV_P','DEV_D'),tasks$tasks);stopifnot(length(requested)==108L)
dir.create('dev_analyses',showWarnings=FALSE)
ledger_path<-'dev_analyses/attempt_ledger.json';stopifnot(!file.exists(ledger_path))
ledger<-setNames(lapply(requested,function(t)list(task=t,attempt_execution_status='NOT_STARTED')),vapply(requested,function(t)t$task_id,''))
put_ledger<-function()jsonlite::write_json(list(records=ledger,formal_M=0L,formal_B=0L),ledger_path,pretty=TRUE,auto_unbox=TRUE,digits=17)
put_ledger()
cache<-list();prep_records<-list()
load_prepared<-function(did) {
  if(!is.null(cache[[did]]))return(cache[[did]])
  ds<-catalog[[did]];tic<-frozen_core$clock()
  if(!identical(unname(tools::md5sum(ds$source_file)),ds$source_md5_for_fast_read_guard))stop('SOURCE_FILE_CONTENT_CHANGED')
  cc<-jsonlite::read_json(ds$source_file,simplifyVector=FALSE);io<-frozen_core$clock()-tic
  id<-list(input_sha256=ds$source_sha256,dataset_id=did,source_MD5=ds$source_md5_for_fast_read_guard)
  pd<-prepare_dataset(cc,id)
  prep_records[[did]]<<-list(dataset_id=did,source_read_seconds=io,prepare_seconds=pd$prepare_seconds,
    source_sha256=ds$source_sha256,prepared_object_bytes=as.numeric(object.size(pd$payload)),
    no_cached_fit_weights_risk_or_required_cells=TRUE)
  list(case=cc,pd=pd,identity=id,source=ds)
}
statistical_status<-function(a) {
  if(!isTRUE(a$input_valid))return('FAILED')
  failed<-vapply(a$components[c('E_PL','D_PL')],function(z)z$source_status=='MODEL_FAILURE',TRUE)
  if(all(failed))'FAILED'else if(any(failed))'PARTIALLY_FAILED'else'COMPLETED'
}
same_finite<-function(a,b) {
  if(is.numeric(a)&&is.numeric(b))return(identical(is.na(a),is.na(b))&&all(abs(a[!is.na(a)]-b[!is.na(b)])<=1e-12+1e-10*abs(b[!is.na(b)])))
  if(is.list(a)&&is.list(b))return(identical(names(a),names(b))&&length(a)==length(b)&&all(mapply(same_finite,a,b)))
  identical(a,b)
}
execute<-function(task,prepared,indices,initial_seed,after_draw_seed,draw_seconds) {
  folder<-file.path('dev_analyses',task$task_id);if(dir.exists(folder))stop('DO_NOT_OVERWRITE_ATTEMPT')
  dir.create(folder);warn<-character();stage<-'START';cpu<-proc.time();start<-frozen_core$clock()
  record<-list(task=task,attempt_execution_status='STARTED',input_sha256=prepared$source$source_sha256,
    code_identity=code_identity,science_identity=runtime_identity,
    source_file=prepared$source$source_file,initial_Random_seed=initial_seed,after_draw_Random_seed=after_draw_seed,
    actual_start=format(Sys.time(),'%Y-%m-%dT%H:%M:%OS6%z'),timezone=Sys.timezone(),
    formal_M=0L,formal_B=0L,DEV_random_draw=task$phase=='DEV_D',DEV_not_formal_bootstrap=TRUE)
  ledger[[task$task_id]]<<-record;put_ledger()
  jsonlite::write_json(record,file.path(folder,'attempt_record.json'),auto_unbox=TRUE,pretty=TRUE,digits=17)
  error<-NULL
  tryCatch(withCallingHandlers({
    stage<-'COMPLETE_DRAW_INDEX_IO';t<-frozen_core$clock();map<-file.path(folder,'draw.int32le')
    writeBin(indices,map,size=4L,endian='little')
    stopifnot(identical(indices,readBin(map,integer(),n=length(indices),size=4L,endian='little')))
    mapping_IO<-frozen_core$clock()-t
    stage<-'SOURCE_IDENTITY_CHECK'
    if(!identical(unname(tools::md5sum(prepared$source$source_file)),prepared$source$source_md5_for_fast_read_guard))stop('SOURCE_FILE_CONTENT_CHANGED')
    seed_before<-.Random.seed
    stage<-'PREPARED_REFIT';t<-frozen_core$clock();c0<-proc.time()
    a<-refit_one_draw(prepared$pd,indices,prepared$identity,task$method,retain_ledger=TRUE)
    refit_seconds<-frozen_core$clock()-t;refit_CPU<-unname(sum((proc.time()-c0)[1:2]))
    stopifnot(identical(seed_before,.Random.seed))
    stage<-'FULL_RESULT_LEDGER_IO';t<-frozen_core$clock();full_writer(a,file.path(folder,'result_full.json'));ledger_IO<-frozen_core$clock()-t
    stage<-'UNCACHED_RAW_HISTORY_COMPARISON';t<-frozen_core$clock();raw<-prepared$case
    raw$multiplicity<-as.list(tabulate(indices,nbins=length(raw$subjects)))
    b<-frozen_core$analyze_candidate(raw,task$method,TRUE)
    uncached_seconds<-frozen_core$clock()-t
    same<-identical(science_only(a),science_only(b));full_writer(b,file.path(folder,'uncached_comparator_full.json'))
    if(!same){saveRDS(list(task=task,old=b,new=a),file.path(folder,'first_counterexample.rds'));stop('PREPARED_VS_RAW_SCIENTIFIC_DIFFERENCE')}
    explicit<-NULL
    if(task$phase=='DEV_D'&&task$draw_id==1L) {
      stage<-'EXPLICIT_DRAW_INSTANCE_COMPARISON';ex<-prepared$case
      ex$subjects<-lapply(seq_along(indices),function(j){s<-prepared$case$subjects[[indices[j]]];s$id<-paste0(s$id,'_INSTANCE',j);s})
      ex$multiplicity<-as.list(rep(1L,length(indices)));ex$representation<-'EXPLICIT_DRAW_INSTANCES'
      ea<-frozen_core$analyze_candidate(ex,task$method,TRUE)
      explicit<-same_finite(a[c('components','contrasts','required_cells','P_counts','fits','entry_ESS','eligible_instances','unique_original_subjects')],
        ea[c('components','contrasts','required_cells','P_counts','fits','entry_ESS','eligible_instances','unique_original_subjects')])
      full_writer(ea,file.path(folder,'explicit_instances_full.json'));stopifnot(explicit)
    }
    stage<-'RESULT_RECORD'
    record$attempt_execution_status<-statistical_status(a)
    record$actual_end<-format(Sys.time(),'%Y-%m-%dT%H:%M:%OS6%z')
    record$point_and_CI_eligibility<-lapply(c(a$components[c('E_PL','D_PL')],a$contrasts),function(z)z[c('point_status','CI_eligibility','source_status','failed_stage','failure_reasons')])
    record$full_draw_map<-list(file='draw.int32le',length=length(indices),bytes=file.info(map)$size,MD5=unname(tools::md5sum(map)),ordered_indices_preserved=TRUE,
      multiplicity_total=sum(tabulate(indices,nbins=task$N)),unique_sources=length(unique(indices)),E_D_shared=TRUE)
    record$timings<-list(draw_generation_seconds=draw_seconds,mapping_IO_seconds=mapping_IO,prepared_refit_seconds=refit_seconds,
      prepared_refit_R_CPU_seconds=refit_CPU,full_result_serialization_IO_seconds=ledger_IO,
      uncached_comparator_seconds=uncached_seconds,all_checks_and_evidence_wall_seconds=frozen_core$clock()-start,
      R_CPU_seconds=unname(sum((proc.time()-cpu)[1:2])),core_stages=a$timings)
    record$all_scientific_fields_exact_vs_uncached<-same;record$explicit_instances_agree<-explicit
    record$actual_final_Random_seed<-.Random.seed
    record$warnings<-as.list(warn);record$CI_computed<-FALSE;record$bootstrap_SE_computed<-FALSE
  },warning=function(w){warn<<-c(warn,conditionMessage(w))}),error=function(e){error<<-e})
  if(!is.null(error)) {
    record$attempt_execution_status<-'FAILED';record$execution_error<-conditionMessage(error);record$failed_stage<-stage
    record$warnings<-as.list(warn);record$actual_end<-format(Sys.time(),'%Y-%m-%dT%H:%M:%OS6%z')
  }
  jsonlite::write_json(record,file.path(folder,'attempt_record.json'),auto_unbox=TRUE,pretty=TRUE,digits=17)
  ledger[[task$task_id]]<<-record;put_ledger()
  if(!is.null(error))stop(error)
  cat('DEV_ANALYSIS ',task$task_id,' ',record$attempt_execution_status,'\n',sep='');flush.console()
}
for(ds in tasks$datasets) {
  did<-ds$dataset_id;prepared<-load_prepared(did)
  for(task in Filter(function(t)t$phase=='DEV_P'&&t$dataset_id==did,requested)) {
    initial<-initial_task_seed(task,bank);assign('.Random.seed',initial,envir=.GlobalEnv)
    execute(task,prepared,seq_len(task$N),initial,initial,0)
  }
  if(ds$law%in%c('BASE','NULL','NEAR','SPARSE')&&ds$N==5000L&&ds$replicate==1L)cache[[did]]<-prepared
  gc()
}
for(task in Filter(function(t)t$phase=='DEV_D',requested)) {
  prepared<-cache[[task$dataset_id]];stopifnot(!is.null(prepared))
  initial<-initial_task_seed(task,bank);assign('.Random.seed',initial,envir=.GlobalEnv)
  t<-frozen_core$clock();indices<-sample.int(task$N,size=task$N,replace=TRUE);draw_seconds<-frozen_core$clock()-t;after<-.Random.seed
  execute(task,prepared,as.integer(indices),initial,after,draw_seconds)
}
stopifnot(length(ledger)==108L,!any(vapply(ledger,function(z)z$attempt_execution_status%in%c('NOT_STARTED','STARTED','ABORTED'),TRUE)))
jsonlite::write_json(list(datasets=prep_records,prepared_once_each=TRUE,DEV_only=TRUE),'dev_analyses/preparation_records.json',pretty=TRUE,auto_unbox=TRUE,digits=17)
cat('All 44 DEV original methods and 64 DEV random draws evaluated. No SE, CI or coverage computed.\n')
