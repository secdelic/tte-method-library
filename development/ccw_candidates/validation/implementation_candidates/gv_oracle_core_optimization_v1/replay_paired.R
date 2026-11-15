# One deterministic traversal of every sealed N/map/mode, both versions.
# Fixed alternating version order; no random ordering or fastest-run selection.
args<-commandArgs(trailingOnly=TRUE)
target<-args[[1]];if(dir.exists(target))stop('Do not overwrite a paired replay')
dir.create(target,recursive=TRUE)
old<-normalizePath('../gv_oracle_minimal_core_v1',mustWork=TRUE)
source('write_result.R')
engines<-list(baseline=new.env(),optimized=new.env())
sys.source(file.path(old,'core_candidate.R'),engines$baseline)
sys.source('core_candidate_optimized.R',engines$optimized)
clock<-function()unname(proc.time()[[3L]])
stopifnot(as.character(getRversion())=='4.5.1',as.character(packageVersion('jsonlite'))=='2.0.0')
records<-list();pair<-0L
for(N in c(1000L,5000L)) {
  t<-clock();spec<-jsonlite::read_json(file.path(old,paste0('inputs/engineering_N',N,'.json')),simplifyVector=FALSE);source_IO<-clock()-t
  for(mapping in spec$maps)for(mode in c('KNOWN','Q_SAT')) {
    pair<-pair+1L
    versions<-if(pair%%2L==1L)c('baseline','optimized')else c('optimized','baseline')
    for(version in versions) {
      folder<-file.path(target,version);dir.create(folder,showWarnings=FALSE)
      gc(reset=TRUE);cpu_start<-proc.time();start<-clock();t<-clock()
      indices<-as.integer(unlist(mapping$indices));stopifnot(length(indices)==N,all(indices>=1L&indices<=N))
      stem<-paste0('N',N,'_',mapping$map_id,'_',mode)
      mapfile<-file.path(folder,paste0(stem,'.int32le'))
      writeBin(indices,mapfile,size=4L,endian='little')
      stopifnot(identical(indices,readBin(mapfile,integer(),n=N,size=4L,endian='little')))
      mapping_IO<-clock()-t
      t<-clock();case<-list(subjects=spec$subjects,multiplicity=as.list(tabulate(indices,nbins=N)),known_q=spec$known_q,
        representation='SOURCE_MULTIPLICITY',forced_fit_failures=mapping$forced_fit_failures)
      draw_assembly<-clock()-t
      answer<-engines[[version]]$analyze_candidate(case,mode,retain_ledger=FALSE)
      # Identical engineering retention as the sealed original replay.
      # Complete raw history+draw indices are retained; no extra ledger fields removed.
      answer$entry_members<-NULL
      t<-clock();outfile<-file.path(folder,paste0(stem,'.json'))
      if(version=='baseline')jsonlite::write_json(answer,outfile,auto_unbox=TRUE,pretty=FALSE,digits=17,na='null',null='null')
      else write_result_optimized(answer,outfile)
      ledger_IO<-clock()-t
      cpu_used<-sum((proc.time()-cpu_start)[1:2]);heap<-gc()
      records[[length(records)+1L]]<-list(pair_id=pair,N=N,map_id=mapping$map_id,mode=mode,version=version,order_in_pair=match(version,versions),
        full_index_file=paste0(version,'/',basename(mapfile)),result_file=paste0(version,'/',basename(outfile)),
        mapping_IO_seconds=mapping_IO,draw_assembly_seconds=draw_assembly,initial_shared_source_IO_seconds=source_IO,
        stages=answer$timings,ledger_IO_seconds=ledger_IO,total_replay_wall_seconds=clock()-start,
        R_process_CPU_seconds=unname(cpu_used),R_heap_peak_MiB=sum(heap[,6]),heap_measure_is_not_OS_RSS=TRUE,
        component_statuses=lapply(answer$components,function(z)z$source_status),fixed_mapping_not_bootstrap=TRUE,
        bootstrap_replicates=0L,SE_computed=FALSE,CI_computed=FALSE)
      cat('PAIRED ',pair,' ',version,' ',stem,' ',tail(records,1L)[[1L]]$total_replay_wall_seconds,'\n',sep='');flush.console()
    }
  }
}
stopifnot(pair==32L,length(records)==64L)
jsonlite::write_json(list(records=records,paired_cases=pair,version_order='ALTERNATING_BY_FIXED_PAIR_ID',
  source_read_policy='ONCE_PER_N_SHARED_EQUAL_INPUT_BOTH_VERSIONS_SEPARATELY_RECORDED',workers=1L,
  random_sampling=FALSE,bootstrap=FALSE,MC=FALSE,CI=FALSE,R=as.character(getRversion()),jsonlite=as.character(packageVersion('jsonlite'))),
  file.path(target,'paired_timing_ledger.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
