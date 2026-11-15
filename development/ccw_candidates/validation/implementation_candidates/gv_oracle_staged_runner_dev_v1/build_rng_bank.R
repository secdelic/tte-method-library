stopifnot(as.character(getRversion())=='4.5.1',as.character(packageVersion('parallel'))=='4.5.1')
gate<-jsonlite::read_json('results/deterministic_gate_001/DETERMINISTIC_GATE_COMPLETE.json')
stopifnot(gate$status=='PASS')
manifest<-jsonlite::read_json('inputs/dev_task_stream_manifest.json',simplifyVector=FALSE)
RNGkind(kind="L'Ecuyer-CMRG",normal.kind='Inversion',sample.kind='Rejection');set.seed(104729)
root<-.Random.seed;s<-root
target<-23956750L;before<-NULL
# Definitionally S_j=nextRNGStream^j(S_0), with zero-based formal indices.
# All intermediate states are overwritten, not retained or written.
for(j in seq_len(target)) {
  if(j==target)before<-s
  s<-parallel::nextRNGStream(s)
  if(j%%2000000L==0L){cat('R controlled stream advances ',j,'/',target,'\n',sep='');flush.console()}
}
bank<-vector('list',1024L)
for(i in seq_len(1024L)) {
  bank[[i]]<-list(stream_index_zero_based=target+i-1L,seed=s)
  s<-parallel::nextRNGStream(s)
}
stopifnot(identical(parallel::nextRNGStream(before),bank[[1L]]$seed))
stopifnot(length(unique(vapply(bank,function(z)paste(z$seed,collapse=','),'')))==1024L)
for(i in 2:1024)stopifnot(identical(parallel::nextRNGStream(bank[[i-1L]]$seed),bank[[i]]$seed))
dir.create('rng',showWarnings=FALSE)
stopifnot(!file.exists('rng/DEV_STREAM_BANK_V1.json'))
jsonlite::write_json(list(status='PASS',root_seed=104729,root_actual_Random_seed=root,
  formal_last_index=23956749L,formal_last_seed=before,DEV_first_index=target,DEV_last_index=23957773L,
  total_R_nextRNGStream_advances_to_DEV_first=target,bank=bank,
  algorithm='CONTROLLED_R_PARALLEL_NEXT_RNG_STREAM_ITERATION_NO_GUESSED_STATES_NO_SKIPPED_STEPS',
  R=as.character(getRversion()),parallel=as.character(packageVersion('parallel')),RNGkind=RNGkind(),
  actual_RNGversion_override=NULL,random_variates_generated=0L,intermediate_formal_states_saved=0L),
  'rng/DEV_STREAM_BANK_V1.json',pretty=TRUE,auto_unbox=TRUE,digits=17)
cat('Verified R stream bank saved, all 1024 DEV states and formal boundary; no DEV data or draws generated.\n')
