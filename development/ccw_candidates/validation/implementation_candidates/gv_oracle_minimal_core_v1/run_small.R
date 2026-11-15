args<-commandArgs(trailingOnly=TRUE)
stopifnot(as.character(getRversion())=='4.5.1',as.character(packageVersion('stats'))=='4.5.1')
source('core_candidate.R',local=TRUE)
inputs<-jsonlite::read_json('inputs/small_fixtures.json',simplifyVector=FALSE)
target<-args[[1]];if(dir.exists(target)) stop('Never overwrite an attempt directory')
dir.create(target,recursive=TRUE)
all<-list()
for(case in inputs$cases) {
  modes<-if(identical(case$case_id,'ZERO_E_POPULATION_SUPPORT')) 'KNOWN' else c('KNOWN','Q_SAT')
  all[[case$case_id]]<-setNames(lapply(modes,function(mode)analyze_candidate(case,mode,retain_ledger=TRUE)),modes)
}
jsonlite::write_json(list(candidate='MINIMAL_CCW_CORE_CANDIDATE_V1',cases=all,
  environment=list(R=as.character(getRversion()),stats=as.character(packageVersion('stats')),jsonlite=as.character(packageVersion('jsonlite'))),
  random_sampling_executed=FALSE,CI_executed=FALSE),file.path(target,'actual_small.json'),auto_unbox=TRUE,pretty=TRUE,digits=17,na='null',null='null')
cat('SMALL_CASE_RUNS_COMPLETED=',sum(vapply(all,length,0L)),'\n')
