stopifnot(jsonlite::read_json('results/deterministic_gate_001/DETERMINISTIC_GATE_COMPLETE.json')$status=='PASS')
source('dgp_observational.R')
manifest<-jsonlite::read_json('inputs/dev_task_stream_manifest.json',simplifyVector=FALSE)
bank<-jsonlite::read_json('rng/DEV_STREAM_BANK_V1.json',simplifyVector=FALSE);stopifnot(bank$status=='PASS')
RNGkind(kind="L'Ecuyer-CMRG",normal.kind='Inversion',sample.kind='Rejection')
tasks<-Filter(function(t)t$phase=='DEV_SOURCE',manifest$tasks);stopifnot(length(tasks)==28L)
dir.create('dev_sources',showWarnings=FALSE)
states<-lapply(tasks,function(t)list(task_id=t$task_id,status='NOT_STARTED'))
ledgerfile<-'dev_sources/source_execution_ledger.json';stopifnot(!file.exists(ledgerfile))
saveledger<-function()jsonlite::write_json(list(records=states,formal_M_contribution=0L),ledgerfile,auto_unbox=TRUE,pretty=TRUE,digits=17)
saveledger()
for(j in seq_along(tasks)) {
  task<-tasks[[j]];folder<-file.path('dev_sources',task$dataset_id)
  if(dir.exists(folder))stop('Do not overwrite source attempt')
  dir.create(folder);states[[j]]$status<-'STARTED';states[[j]]$started<-format(Sys.time(),'%Y-%m-%dT%H:%M:%OS6%z');saveledger()
  initial<-initial_task_seed(task,bank);cpu<-proc.time();tic<-unname(proc.time()[[3L]])
  generated<-tryCatch(generate_observational_P(task,initial),error=function(e){
    states[[j]]$status<<-'FAILED';states[[j]]$error<<-conditionMessage(e);saveledger();stop(e)})
  generation_seconds<-unname(proc.time()[[3L]])-tic;io_tic<-unname(proc.time()[[3L]])
  jsonlite::write_json(generated$case,file.path(folder,'source.json'),auto_unbox=TRUE,pretty=FALSE,digits=17,na='null',null='null')
  jsonlite::write_json(generated$trace,file.path(folder,'innovation_trace.json'),auto_unbox=TRUE,pretty=FALSE,digits=17,na='null',null='null')
  result<-list(task=task,initial_Random_seed=initial,final_Random_seed=generated$final_seed,
    uniform_calls=generated$uniform_calls,status='COMPLETED',DGP='OBSERVATIONAL_P_NOT_POLICY',
    generation_seconds=generation_seconds,source_and_trace_IO_seconds=unname(proc.time()[[3L]])-io_tic,
    R_CPU_seconds=unname(sum((proc.time()-cpu)[1:2])),ended=format(Sys.time(),'%Y-%m-%dT%H:%M:%OS6%z'))
  jsonlite::write_json(result,file.path(folder,'generation_record.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
  states[[j]]<-list(task_id=task$task_id,status='COMPLETED',record_file=file.path(folder,'generation_record.json'))
  saveledger();cat('DEV_SOURCE ',j,'/28 ',task$dataset_id,'\n',sep='');flush.console()
}
stopifnot(all(vapply(states,function(s)s$status=='COMPLETED',TRUE)))
