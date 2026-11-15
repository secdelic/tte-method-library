# Technical reexecution of the same DEV identities, never new statistical reps.
stopifnot(jsonlite::read_json('runs/dev_analyses_001/execution.json')$status=='COMPLETED')
source('dgp_observational.R')
manifest<-jsonlite::read_json('inputs/dev_task_stream_manifest.json',simplifyVector=FALSE)
bank<-jsonlite::read_json('rng/DEV_STREAM_BANK_V1.json',simplifyVector=FALSE)
RNGkind(kind="L'Ecuyer-CMRG",normal.kind='Inversion',sample.kind='Rejection')
target<-commandArgs(trailingOnly=TRUE)[[1L]]
stopifnot(!dir.exists(target));dir.create(target,recursive=TRUE)
source_checks<-list();draw_checks<-list()
source_tasks<-rev(Filter(function(t)t$phase=='DEV_SOURCE',manifest$tasks))
for(task in source_tasks) {
  original<-file.path('dev_sources',task$dataset_id);initial<-initial_task_seed(task,bank)
  a<-generate_observational_P(task,initial)
  b<-jsonlite::read_json(file.path(original,'source.json'),simplifyVector=FALSE)
  tr<-jsonlite::read_json(file.path(original,'innovation_trace.json'),simplifyVector=FALSE)
  rec<-jsonlite::read_json(file.path(original,'generation_record.json'),simplifyVector=FALSE)
  same_source<-identical(a$case,b);same_trace<-identical(a$trace,tr)
  final<-as.integer(unlist(rec$final_Random_seed));same_end<-identical(a$final_seed,final)
  # Actual single-uniform progression is independently checked against its
  # declared consumption count; the stream/substream budget is never approached.
  assign('.Random.seed',initial,envir=.GlobalEnv);invisible(runif(a$uniform_calls));same_consumption<-identical(.Random.seed,final)
  stopifnot(same_source,same_trace,same_end,same_consumption)
  source_checks[[task$task_id]]<-list(task_id=task$task_id,source_R_object_exact=same_source,innovation_trace_exact=same_trace,
    final_seed_exact=same_end,uniform_consumption_exact=same_consumption,uniform_calls=a$uniform_calls,
    reverse_task_order=TRUE,new_DEV_dataset=FALSE,formal_M=0L)
  jsonlite::write_json(source_checks,file.path(target,'source_check_checkpoint.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
  cat('SOURCE_REPLAY ',task$task_id,' exact\n',sep='');flush.console()
}
maps<-file.path(target,'maps');dir.create(maps,showWarnings=FALSE)
for(task in rev(Filter(function(t)t$phase=='DEV_D',manifest$tasks))) {
  initial<-initial_task_seed(task,bank);assign('.Random.seed',initial,envir=.GlobalEnv)
  ix<-as.integer(sample.int(task$N,size=task$N,replace=TRUE));after<-.Random.seed
  original<-file.path('dev_analyses',task$task_id)
  before_ix<-readBin(file.path(original,'draw.int32le'),integer(),n=task$N,size=4L,endian='little')
  meta<-jsonlite::read_json(file.path(original,'attempt_record.json'),simplifyVector=FALSE)
  stopifnot(identical(ix,before_ix),identical(after,as.integer(unlist(meta$after_draw_Random_seed))),
    identical(after,as.integer(unlist(meta$actual_final_Random_seed))))
  path<-file.path(maps,paste0(task$task_id,'.int32le'));writeBin(ix,path,size=4L,endian='little')
  stopifnot(identical(ix,readBin(path,integer(),n=task$N,size=4L,endian='little')))
  # Locate the exact state reached by sample.int using single R uniforms.
  # No guessed draw-count or integer-seed independence claim is used.
  assign('.Random.seed',initial,envir=.GlobalEnv);steps<-0L
  repeat {
    invisible(runif(1L));steps<-steps+1L
    if(identical(.Random.seed,after))break
    if(steps>task$N*100L)stop('CANNOT_VERIFY_ACTUAL_DRAW_STREAM_CONSUMPTION')
  }
  draw_checks[[task$task_id]]<-list(task_id=task$task_id,full_ordered_map_exact=TRUE,initial_seed=initial,final_seed_exact=TRUE,
    reverse_task_order=TRUE,actual_uniform_state_advances=steps,E_D_common_draw=TRUE,technical_not_bootstrap_replicate=TRUE,
    actual_reproduction_map=path)
  jsonlite::write_json(draw_checks,file.path(target,'draw_check_checkpoint.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
}
stopifnot(length(source_checks)==28L,length(draw_checks)==64L)
hashes<-unname(tools::md5sum(list.files(maps,full.names=TRUE)));stopifnot(length(unique(hashes))==64L)
jsonlite::write_json(list(status='PASS',sources=source_checks,draws=draw_checks,all_random_maps_distinct=TRUE,
  technical_reexecution_only=TRUE,new_statistical_data_or_draws=0L,formal_M=0L,formal_B=0L,
  RNGkind=RNGkind(),session_text=as.list(capture.output(sessionInfo())),OS=as.list(Sys.info()),external_libraries=as.list(extSoftVersion()),
  package_versions=list(R=as.character(getRversion()),stats=as.character(packageVersion('stats')),
    parallel=as.character(packageVersion('parallel')),jsonlite=as.character(packageVersion('jsonlite')))),
  file.path(target,'RNG_REPRODUCTION.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
cat('Reverse-order 28 source and 64 complete-draw reproductions exact; actual stream consumption verified.\n')
