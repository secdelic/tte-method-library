# Untimed deterministic audit views, not another performance sample.
args<-commandArgs(trailingOnly=TRUE);target<-args[[1]]
if(dir.exists(target))stop('Preserve audit evidence');dir.create(target,recursive=TRUE)
source('core_candidate_optimized.R');source('write_result.R')
old<-normalizePath('../gv_oracle_minimal_core_v1',mustWork=TRUE)
for(N in c(1000L,5000L)) {
  spec<-jsonlite::read_json(file.path(old,paste0('inputs/engineering_N',N,'.json')),simplifyVector=FALSE)
  for(mapping in spec$maps)for(mode in c('KNOWN','Q_SAT')) {
    indices<-as.integer(unlist(mapping$indices))
    case<-list(subjects=spec$subjects,multiplicity=as.list(tabulate(indices,nbins=N)),known_q=spec$known_q,
      representation='SOURCE_MULTIPLICITY',forced_fit_failures=mapping$forced_fit_failures)
    result<-analyze_candidate(case,mode,retain_ledger=TRUE)
    write_result_optimized(result,file.path(target,paste0('N',N,'_',mapping$map_id,'_',mode,'.json')))
  }
}
cat('All 32 full audit views retained; no performance selection, random generation or CI.\n')
