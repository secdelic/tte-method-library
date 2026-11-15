source("bootstrap.R")
root <- normalizePath("../../..",winslash="/",mustWork=TRUE)
contract <- jsonlite::read_json("inputs/development_contract.json")
args <- commandArgs(trailingOnly=TRUE)
B <- if (length(args)) as.numeric(args[[1]]) else contract$B
validate_canary_request(contract,B,contract$source_file,FALSE)
engine <- load_frozen_core(root,contract)
gate <- jsonlite::read_json("results/independent_001/RECONSTRUCTION_VALIDATION.json")
if (!identical(gate$status,"PASS")) stop("INDEPENDENT_GATE_NOT_PASSED")
for (f in names(gate$bindings))
  if (!identical(sha_file(f),gate$bindings[[f]])) stop("RECONSTRUCTION_GATE_IDENTITY_CHANGED")
if (!identical(sha_file(file.path(root,contract$source_file)),contract$source_sha256))
  stop("SEALED_SOURCE_CHANGED")
case <- jsonlite::read_json(file.path(root,contract$source_file))
N <- validate_source(case,engine)
stopifnot(N==contract$N)
run <- contract$run_directory
# A single, predeclared canary directory prevents accidental rerun/replacement.
if (dir.exists(run)) stop("CANARY_ALREADY_EXISTS_DO_NOT_REGENERATE_DRAWS")
dir.create(run,recursive=TRUE)
dir.create(file.path(run,"maps"))
dir.create(file.path(run,"attempts"))
start <- proc.time()
write_json_new(list(contract_sha256=sha_file("inputs/development_contract.json"),
  authorization_sha256=sha_file("inputs/authorization.json"),
  gate_sha256=sha_file("results/independent_001/RECONSTRUCTION_VALIDATION.json"),
  code_sha256=setNames(lapply(c("bootstrap.R","run_canary.R","verify_candidate.py"),sha_file),
                      c("bootstrap.R","run_canary.R","verify_candidate.py")),
  dependencies=contract$dependencies,approved_files=contract$approved_files,
  source_sha256=contract$source_sha256,
  R_version=R.version.string,session_info=capture.output(sessionInfo()),
  packages=list(jsonlite=as.character(packageVersion("jsonlite")),
                digest=as.character(packageVersion("digest"))),
  actual_start=format(Sys.time(),"%Y-%m-%dT%H:%M:%OS6%z"),
  scope="SEALED_SYNTHETIC_CANARY_NOT_CLINICAL_OR_FORMAL_INFERENCE"),
  file.path(run,"execution_identity.json"))
write_json_new(lapply(seq_along(case$subjects),function(i)
  list(index=i,subject_id=case$subjects[[i]]$original_id,source_row_id=case$subjects[[i]]$id)),
  file.path(run,"source_index.json"))

RNGkind(kind=contract$RNG$kind,normal.kind=contract$RNG$normal_kind,
        sample.kind=contract$RNG$sample_kind)
set.seed(as.integer(contract$RNG$development_seed))
stream <- .Random.seed
oldbank <- jsonlite::read_json(file.path(root,
  "validation/implementation_candidates/gv_oracle_staged_runner_dev_v1/rng/DEV_STREAM_BANK_V1.json"))$bank
oldstates <- vapply(oldbank,function(x)paste(unlist(x$seed),collapse=","),"")
tasks <- vector("list",B)
for (i in seq_len(B)) {
  if (paste(stream,collapse=",") %in% oldstates) stop("EXISTING_DEV_STREAM_STATE_COLLISION")
  assign(".Random.seed",stream,envir=.GlobalEnv)
  before <- .Random.seed
  # Exactly N original subjects, with replacement; both policies share this map.
  idx <- as.integer(sample.int(N,N,replace=TRUE))
  after <- .Random.seed
  id <- sprintf("DRAW_%03d",i)
  rel <- paste0("maps/",id,".int32le")
  writeBin(idx,file.path(run,rel),size=4L,endian="little")
  stopifnot(identical(idx,readBin(file.path(run,rel),integer(),n=N,size=4L,endian="little")),
            file.info(file.path(run,rel))$size==4*N)
  tasks[[i]] <- list(id=id,map_file=rel,map_sha256=sha_file(file.path(run,rel)),
    N=N,initial_state=as.list(before),after_draw_state=as.list(after),
    E_D_shared=TRUE,state="NOT_STARTED")
  stream <- parallel::nextRNGStream(before)
}
ids <- vapply(tasks,`[[`,"","id")
write_json_new(list(kind="ONE_PREALLOCATED_SYNTHETIC_CANARY",
  RNG=contract$RNG,draws=tasks,requested=B,formal_B=0L,
  existing_1024_DEV_initial_states_checked=length(oldstates),
  reuse_of_failed_draws_allowed=FALSE,ordered_maps_retained=TRUE),
  file.path(run,"plan.json"))

point <- refit_subject_draw(case,seq_len(N),engine,contract$method)
original <- extract_estimates(point)
write_json_new(compact_result(point,TRUE),file.path(run,"original_compact.json"))
write_json_new(original,file.path(run,"original_estimates.json"))
event <- function(x) {
  line <- jsonlite::toJSON(x,auto_unbox=TRUE,digits=17,na="null",null="null")
  cat(line,"\n",file=file.path(run,"attempt_events.jsonl"),append=TRUE,sep="")
}
execute <- function(id) {
  task <- tasks[[match(id,ids)]]
  stage <- "DRAW_MAP_READBACK"
  tryCatch({
    map <- file.path(run,task$map_file)
    if (!identical(sha_file(map),task$map_sha256)) stop("DRAW_MAP_CHANGED")
    idx <- readBin(map,integer(),n=N,size=4L,endian="little")
    stage <- "SOURCE_IDENTITY_CHECK"
    if (!identical(sha_file(file.path(root,contract$source_file)),contract$source_sha256))
      stop("SEALED_SOURCE_CHANGED")
    assign(".Random.seed",as.integer(unlist(task$after_draw_state)),envir=.GlobalEnv)
    before <- .Random.seed
    stage <- "FULL_REFIT"
    full <- refit_subject_draw(case,idx,engine,contract$method)
    if (!identical(before,.Random.seed)) stop("UNEXPECTED_RNG_USE_DURING_DETERMINISTIC_REFIT")
    stage <- "DIRECT_FIT_HAZARD_STATUS_EVIDENCE_IO"
    rel <- paste0("attempts/",id,".json")
    write_json_new(compact_result(full,TRUE),file.path(run,rel))
    list(estimates=extract_estimates(full),
      evidence=list(result_file=rel,result_sha256=sha_file(file.path(run,rel)),
        map_file=task$map_file,map_sha256=task$map_sha256,
        source_sha256=contract$source_sha256,
        initial_draw_state=task$initial_state,after_draw_state=task$after_draw_state,
        after_refit_state=as.list(.Random.seed),
        unique_subjects=length(unique(idx)),draw_instances=length(idx),
        fit_recomputed_for_this_draw=TRUE,views_omitted_after_independent_gate=as.list(omitted_views)))
  },error=function(e){e$failed_stage<-stage;stop(e)},
    interrupt=function(e){e$failed_stage<-stage;stop(e)})
}
records <- run_schedule(ids,execute,event)
write_json_new(records,file.path(run,"attempt_records.json"))
summary <- aggregate_bootstrap(original,records,ids,FALSE)
write_json_new(summary,file.path(run,"summary.json"))
write_json_new(list(actual_end=format(Sys.time(),"%Y-%m-%dT%H:%M:%OS6%z"),
  wall_seconds=unname((proc.time()-start)[[3L]]),
  R_CPU_seconds=unname(sum((proc.time()-start)[1:2])),
  random_draws_generated=length(tasks),formal_B_executed=0L,
  attempted=summary$accounting$attempted,not_started=summary$accounting$not_started,
  runtime_technical_errors=sum(vapply(records,function(x)!is.null(x$error),TRUE)),
  formal_CI_SE_covariance_computed=FALSE),
  file.path(run,"execution_end.json"))
cat(jsonlite::toJSON(list(accounting=summary$accounting,
  formal_CI_SE_covariance_computed=FALSE),auto_unbox=TRUE),"\n")
if (any(vapply(records,function(x)!is.null(x$error),TRUE))) stop("CANARY_STOPPED_WITH_RETAINED_TECHNICAL_ERROR")
