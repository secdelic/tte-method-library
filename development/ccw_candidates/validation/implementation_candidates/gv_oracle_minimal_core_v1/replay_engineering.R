args<-commandArgs(trailingOnly=TRUE);source('core_candidate.R',local=TRUE)
target<-args[[1]];if(dir.exists(target)) stop('Do not overwrite engineering replay')
dir.create(target,recursive=TRUE);records<-list()
for(N in c(1000L,5000L)) {
  source_tic<-clock();spec<-jsonlite::read_json(paste0('inputs/engineering_N',N,'.json'),simplifyVector=FALSE);source_IO<-clock()-source_tic
  for(mapping in spec$maps) for(mode in c('KNOWN','Q_SAT')) {
    gc(reset=TRUE);cpu_start<-proc.time();start<-clock();io_tic<-clock();indices<-as.integer(unlist(mapping$indices));stopifnot(length(indices)==N,all(indices>=1L&indices<=N))
    mapfile<-file.path(target,paste0('N',N,'_',mapping$map_id,'_',mode,'.int32le'))
    writeBin(indices,mapfile,size=4L,endian='little');back<-readBin(mapfile,integer(),n=N,size=4L,endian='little');stopifnot(identical(indices,back))
    mapping_IO<-clock()-io_tic
    assembly_tic<-clock();case<-list(subjects=spec$subjects,multiplicity=as.list(tabulate(indices,nbins=N)),known_q=spec$known_q,
      representation='SOURCE_MULTIPLICITY',forced_fit_failures=mapping$forced_fit_failures)
    draw_assembly<-clock()-assembly_tic
    answer<-analyze_candidate(case,mode,retain_ledger=FALSE)
    # Keep complete input+map, fit/cell/point/status evidence; no per-person weights copy per replay.
    answer$entry_members<-NULL
    outname<-paste0('N',N,'_',mapping$map_id,'_',mode,'.json')
    ledger_tic<-clock()
    jsonlite::write_json(answer,file.path(target,outname),auto_unbox=TRUE,pretty=FALSE,digits=17,na='null',null='null')
    ledger_IO<-clock()-ledger_tic
    cpu_used<-sum((proc.time()-cpu_start)[1:2]);heap<-gc()
    summary<-list(N=N,map_id=mapping$map_id,mode=mode,full_index_file=basename(mapfile),result_file=outname,
      mapping_IO_seconds=mapping_IO,draw_assembly_seconds=draw_assembly,initial_source_IO_seconds=source_IO,
      stages=answer$timings,ledger_IO_seconds=ledger_IO,total_replay_wall_seconds=clock()-start,
      R_process_CPU_seconds=unname(cpu_used),R_heap_peak_MiB=sum(heap[,6]),heap_measure_is_not_OS_RSS=TRUE,
      component_statuses=lapply(answer$components,function(x)x$source_status),fixed_mapping_not_bootstrap=TRUE,
      bootstrap_replicates=0L,SE_computed=FALSE,CI_computed=FALSE)
    records[[length(records)+1L]]<-summary
    cat('REPLAY ',N,' ',mapping$map_id,' ',mode,' ',summary$total_replay_wall_seconds,'\n',sep='');flush.console()
  }
}
jsonlite::write_json(list(records=records,N_values=c(1000,5000),maps_per_N=8L,method_runs=length(records),
  random_sampling=FALSE,performance_MC=FALSE,CI=FALSE,R=as.character(getRversion()),stats=as.character(packageVersion('stats'))),
  file.path(target,'engineering_timing_ledger.json'),auto_unbox=TRUE,pretty=TRUE,digits=17)
