# Stream lookup only; no outcome kernels or observational DGP are exposed to core.
initial_task_seed<-function(task,bank) {
  i<-as.integer(task$stream_index_zero_based)-23956750L+1L
  stopifnot(i>=1L,i<=1024L,bank$bank[[i]]$stream_index_zero_based==task$stream_index_zero_based)
  as.integer(unlist(bank$bank[[i]]$seed))
}
