assigned <- Sys.getenv("LEAN_JOB_ASSIGNED_FILE")
if (!nzchar(assigned)) stop("BOUNDED_RESOURCE_LAUNCHER_REQUIRED")
for (i in 1:100) {if(file.exists(assigned)) break; Sys.sleep(.05)}
if (!file.exists(assigned)) stop("RESOURCE_JOB_NOT_ASSIGNED")
source("inference_component.R")
args <- commandArgs(trailingOnly=TRUE)
if (length(args)!=1L) stop("EXPLICIT_RUN_MODE_REQUIRED")
mode <- args[[1L]]
context <- load_inference_context(normalizePath("../../..", winslash="/"), mode)
api <- context$api; contract <- context$contract
gate <- jsonlite::read_json("results/inference_v1/reconstruction/RECONSTRUCTION_VALIDATION.json")
if (!identical(gate$status, "PASS")) stop("RECONSTRUCTION_GATE_NOT_PASSED")
for (p in names(gate$bindings))
  if (!identical(api$sha_file(p), gate$bindings[[p]])) stop("GATE_CODE_OR_INPUT_CHANGED: ", p)
run <- contract$run_directory
if (dir.exists(run)) stop("CONTROLLED_CANARY_ALREADY_EXISTS_NO_RETRY")
prior <- jsonlite::read_json(contract$stream_source)
if (length(prior$draws)!=20L || contract$B!=20L || contract$max_RNG_draw_calls!=20L)
  stop("CANARY_DRAW_BUDGET_MISMATCH")
p <- prepare_sealed_input(context, mode)
x <- checked_prepared(p, mode)
dir.create(file.path(run,"maps"),recursive=TRUE)
dir.create(file.path(run,"attempts"))
api$write_json_new(list(mode=mode,analysis_id=contract$analysis_id,
  source_sha256=p$source_sha256,contract_sha256=api$sha_file("inputs/inference_contract_v1.json"),
  gate_sha256=api$sha_file("results/inference_v1/reconstruction/RECONSTRUCTION_VALIDATION.json"),
  code_sha256=setNames(lapply(c("inference_component.R","run_inference.R"),api$sha_file),
                      c("inference_component.R","run_inference.R")),
  actual_start=format(Sys.time(),"%Y-%m-%dT%H:%M:%OS6%z"),
  R_version=R.version.string,session_info=capture.output(sessionInfo()),
  formal_execution_authorized=FALSE),file.path(run,"execution_identity.json"))
api$write_json_new(lapply(seq_len(x$n),function(i)
  list(index=i,subject_id=x$original[i],source_row_id=x$ids[i])),file.path(run,"source_index.json"))
plan <- prior
plan$kind <- "EXACT_TECHNICAL_REPRODUCTION_THROUGH_EXPLICIT_MODE_PREPAREDDATA_INTERFACE"
plan$analysis_id <- contract$analysis_id
plan$prior_plan_sha256 <- contract$stream_source_sha256
plan$source_to_instance_representation <- list(
  ordered_source_index="maps/<attempt_id>.int32le with source_index.json",
  draw_instance_id="analysis_id/attempt_id/draw_position_as_six_digits",
  E_D_shared=TRUE,source_records_repeated_in_outputs=FALSE)
api$write_json_new(plan,file.path(run,"plan.json"))
event <- function(z) {
  cat(jsonlite::toJSON(z,auto_unbox=TRUE,digits=17,na="null",null="null"),"\n",
      file=file.path(run,"attempt_events.jsonl"),append=TRUE,sep="")
  # Small checkpoint points into append-only events; it does not replace them.
  jsonlite::write_json(list(last_event_id=z$id,last_event_state=z$state,
    authoritative_log="attempt_events.jsonl",requested=20L),
    file.path(run,"checkpoint.json"),auto_unbox=TRUE,pretty=TRUE)
}
original_draw <- subject_draw_mapping(p,seq_len(x$n),contract$analysis_id,"ORIGINAL",mode)
original <- refit_and_estimate_one_draw(p,original_draw,mode)
api$write_json_new(api$compact_result(original$result,TRUE),file.path(run,"original_compact.json"))
api$write_json_new(original$estimates,file.path(run,"original_estimates.json"))
ids <- vapply(plan$draws,`[[`,"","id")
completed_sampling_calls <- 0L
execute <- function(id) {
  task <- plan$draws[[match(id,ids)]]
  stage <- "SUBJECT_DRAW"
  tryCatch({
    caller_kind <- RNGkind()
    caller_seed <- if(exists(".Random.seed",.GlobalEnv,inherits=FALSE)) .Random.seed else NULL
    draw <- bootstrap_subject_draw(p,x$original,
      list(analysis_id=contract$analysis_id,attempt_id=id,N=x$n,
           design="IID_N_OUT_OF_N_WITH_REPLACEMENT"),
      as.integer(unlist(task$initial_state)),mode)
    completed_sampling_calls <<- completed_sampling_calls+1L
    returned_seed <- if(exists(".Random.seed",.GlobalEnv,inherits=FALSE)) .Random.seed else NULL
    if (!identical(caller_kind,RNGkind()) || !identical(caller_seed,returned_seed))
      stop("CALLER_RNG_STATE_NOT_RESTORED")
    stage <- "ORDERED_MAP_DIRECT_RETENTION"
    map <- file.path(run,task$map_file)
    writeBin(draw$indices,map,size=4L,endian="little")
    if (!identical(api$sha_file(map),task$map_sha256) ||
        !identical(draw$RNG$after_draw_state,task$after_draw_state))
      stop("PREALLOCATED_STREAM_REPRODUCTION_MISMATCH")
    assign(".Random.seed",as.integer(unlist(draw$RNG$after_draw_state)),.GlobalEnv)
    before <- .Random.seed
    stage <- "FULL_REFIT_PREPAREDDATA"
    answer <- refit_and_estimate_one_draw(p,draw,mode)
    if (!identical(.Random.seed,before)) stop("UNEXPECTED_RNG_USE_IN_SYNTHETIC_FULL_REFIT")
    stage <- "DIRECT_FIT_WEIGHT_RISK_EVIDENCE_IO"
    rel <- paste0("attempts/",id,".json")
    api$write_json_new(api$compact_result(answer$result,TRUE),file.path(run,rel))
    list(estimates=answer$estimates,evidence=list(result_file=rel,
      result_sha256=api$sha_file(file.path(run,rel)),map_file=task$map_file,
      map_sha256=api$sha_file(map),source_sha256=p$source_sha256,
      draw_id=draw$draw_id,E_D_shared_draw_identity=draw$E_D_shared_draw_identity,
      initial_draw_state=draw$RNG$initial_state,after_draw_state=draw$RNG$after_draw_state,
      after_refit_state=as.list(.Random.seed),draw_instances=length(draw$indices),
      unique_subjects=length(unique(draw$indices)),multiplicity=as.list(draw$multiplicity),
      fit_recomputed_for_this_draw=TRUE,prepared_source_only=TRUE,caller_RNG_restored=TRUE))
  },error=function(e){e$failed_stage<-stage;stop(e)},
    interrupt=function(e){e$failed_stage<-stage;stop(e)})
}
records <- api$run_schedule(ids,execute,event)
api$write_json_new(records,file.path(run,"attempt_records.json"))
summary <- aggregate_bootstrap_ci(original$estimates,records,ids,mode,context)
api$write_json_new(summary,file.path(run,"summary.json"))
api$write_json_new(list(actual_end=format(Sys.time(),"%Y-%m-%dT%H:%M:%OS6%z"),
  completed_sampling_calls=completed_sampling_calls,
  requested=20L,formal_B_executed=0L,new_independent_statistical_draws=0L,
  reproduction_scope="SAME_PREALLOCATED_20_MAPS_NO_REPLACEMENT",
  formal_CI_SE_covariance_computed=FALSE),file.path(run,"execution_end.json"))
if (any(vapply(records,function(z)!is.null(z$error),TRUE)))
  stop("CANARY_STOPPED_WITH_RETAINED_TECHNICAL_ERROR")
cat(jsonlite::toJSON(summary$accounting,auto_unbox=TRUE),"\n")
