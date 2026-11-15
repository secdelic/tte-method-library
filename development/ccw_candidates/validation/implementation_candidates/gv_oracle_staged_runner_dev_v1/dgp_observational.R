# Generates observational P only. No policy force or CCW helper is imported.
theta_input<-jsonlite::read_json('../../reference_candidates/gv_oracle_reference_only_v1/inputs/expanded_parameters.json',simplifyVector=FALSE)
law_input_id<-function(law)paste0('LAW-',if(law=='BASE')'BASE-RATIONAL'else law,'-V1')
initial_task_seed<-function(task,bank) {
  i<-as.integer(task$stream_index_zero_based)-23956750L+1L
  stopifnot(i>=1L,i<=1024L,bank$bank[[i]]$stream_index_zero_based==task$stream_index_zero_based)
  as.integer(unlist(bank$bank[[i]]$seed))
}
generate_observational_P<-function(task,initial_seed) {
  law<-theta_input$laws[[law_input_id(task$law)]];stopifnot(!is.null(law))
  assign('.Random.seed',initial_seed,envir=.GlobalEnv)
  used<-0L
  U<-function(){used<<-used+1L;runif(1L)}
  K<-function(kind,indices=integer()) {
    name<-paste0(kind,if(length(indices))paste0(':',paste(indices,collapse=','))else'')
    z<-law$parameters[[name]]
    stopifnot(!is.null(z),isTRUE(z$structurally_legal),'P'%in%unlist(z$consumers),!is.null(z$exact))
    p<-z$exact$numerator/z$exact$denominator
    stopifnot(is.finite(p),p>=0,p<=1);list(key=name,p=p)
  }
  subjects<-vector('list',task$N);trace<-vector('list',task$N)
  omega<-K('omega')
  for(i in seq_len(task$N)) {
    id<-sprintf('%s_S%05d',task$dataset_id,i)
    uw<-U();w<-as.integer(uw<omega$p);bl<-K('b',w);ul0<-U();l<-as.integer(ul0<bl$p)
    start<-NULL;terminal<-NULL;s<-0L;history<-list();steps<-list()
    for(k in 0:4) {
      history[[k+1L]]<-list(k=k,L=l,measurement_time=k,availability_time=k)
      q<-NULL;uq<-NULL;b<-s
      if(s==0L) {q<-K('q',c(k,w,l));uq<-U();b<-as.integer(uq<q$p);if(b==1L)start<-k}
      h<-K('h',c(k,w,l,s,b));uh<-U();event<-uh<h$p
      ur<-NULL;r<-NULL;next_l<-NULL
      if(event)terminal<-k+1L
      else if(k<4L) {r<-K('r',c(k,w,l,s,b));ur<-U();next_l<-as.integer(ur<r$p)}
      steps[[k+1L]]<-list(k=k,W=w,L=l,S_pre=s,B_post=b,q_key=if(is.null(q))NULL else q$key,
        U_Q=uq,h_key=h$key,U_H=uh,event=event,r_key=if(is.null(r))NULL else r$key,U_R=ur,next_L=next_l)
      if(event||k==4L)break
      s<-b;l<-next_l
    }
    subjects[[i]]<-list(id=id,original_id=id,W=w,actual_effective_start_time=start,terminal_time=terminal,
      t0_start_stage=if(!is.null(start)&&start==0L)'POST_ELIGIBILITY_AND_CLONE_ASSIGNMENT'else NULL,history=history)
    trace[[i]]<-list(id=id,U_W=uw,U_L0=ul0,steps=steps)
  }
  # KNOWN receives only initiation q and explicit support classification.
  # H/R and DGP innovations stay in the separate generator audit evidence.
  q_input<-list()
  for(z in law$parameters)if(z$kind=='q'&&!is.null(z$exact)&&'P'%in%unlist(z$consumers)) {
    v<-as.integer(unlist(z$indices));q_input[[paste0('c',v[1L],'_',v[2L],'_',v[3L])]]<-z$exact
  }
  list(case=list(case_id=task$dataset_id,subjects=subjects,multiplicity=as.list(rep(1L,task$N)),known_q=q_input,
    representation='SOURCE_MULTIPLICITY',unsupported_policies=if(task$law=='ZERO-E')list('E')else list()),
    trace=list(law_id=law_input_id(task$law),single_override=law$single_override,subjects=trace),
    final_seed=.Random.seed,uniform_calls=used)
}
