assigned <- Sys.getenv("LEAN_JOB_ASSIGNED_FILE")
if (nzchar(assigned)) {
  for (i in 1:100) {if(file.exists(assigned)) break; Sys.sleep(.05)}
  if (!file.exists(assigned)) stop("RESOURCE_JOB_NOT_ASSIGNED")
}
source("inference_component.R")
args <- commandArgs(trailingOnly=TRUE)
if (length(args)!=2L) stop("EXPLICIT_MODE_AND_TEST_OUTPUT_REQUIRED")
mode <- args[[1L]]; out <- args[[2L]]
require_execution_mode(mode)
if (dir.exists(out)) stop("TEST_OUTPUT_EXISTS")
dir.create(out, recursive=TRUE)
root <- normalizePath("../../..", winslash="/")
context <- load_inference_context(root, mode)
api <- context$api
checks <- list(); failure <- NULL
check <- function(name, value) {
  checks[[length(checks)+1L]] <<- list(test=name, pass=isTRUE(value))
  if (!isTRUE(value)) stop("TEST_FAILED: ", name)
}
reject <- function(expr) inherits(tryCatch({force(expr); NULL}, error=identity), "error")
science <- function(z) {z$timings <- NULL; z}
tryCatch({
  check("mode_missing_rejected", reject(require_execution_mode()))
  check("mode_null_rejected", reject(load_inference_context(root, NULL)))
  spec <- jsonlite::read_json(file.path(root, "config_templates/analysis_spec_lean_candidate.yml"))
  e <- tryCatch(load_inference_context(root, "FORMAL_ANALYSIS", spec), error=identity)
  check("formal_blocked_before_source_or_RNG", inherits(e, "ccw_formal_not_authorized"))
  check("null_project_model_reported", "weighting.probability_model.formula_link_time_basis" %in%
          e$missing_project_fields)
  check("permission_mismatch_rejected", {
    bad <- context; bad$mode <- "FORMAL_ANALYSIS"
    reject(prepare_sealed_input(bad, mode))
  })
  check("ineligible_not_silently_dropped",
        reject(prepare_sealed_input(context, mode, "BASELINE_EXCLUSIONS")))
  for (id in c("REJECT_EVENT_START_TIE_1", "REJECT_EVENT_START_TIE_3", "REJECT_LATE_L",
               "REJECT_T0_ORDER", "REJECT_DUPLICATE_L", "REJECT_POST_TERMINAL_L"))
    check(paste("sealed_negative_input", id), reject(prepare_sealed_input(context, mode, id)))

  old <- jsonlite::read_json("results/deterministic_004/sealed_boundary_results.json")
  fixtures <- jsonlite::read_json(file.path(root,
    "validation/implementation_candidates/gv_oracle_minimal_core_v1/inputs/small_fixtures.json"))$cases
  sealed <- list()
  for (label in names(old)) {
    prior <- old[[label]]
    p <- prepare_sealed_input(context, mode, prior$case_id)
    idx <- as.integer(unlist(prior$indices))
    draw <- subject_draw_mapping(p, idx, "DETERMINISTIC", label, mode)
    z <- refit_and_estimate_one_draw(p, draw, mode, prior$mode)
    case <- Filter(function(c) identical(c$case_id, prior$case_id), fixtures)[[1L]]
    raw <- api$refit_subject_draw(case, idx, context$staged$frozen_core, prior$mode)
    check(paste(label, "PreparedData_raw_full_science_identical"),
          identical(science(z$result), science(raw)))
    check(paste(label, "same_point_status_and_eligibility"),
          identical(z$estimates, api$extract_estimates(raw)))
    check(paste(label, "shared_ED_draw_and_distinct_instances"),
      identical(draw$E_D_shared_draw_identity$E, draw$E_D_shared_draw_identity$D) &&
        !anyDuplicated(draw$source_to_draw_instance$draw_instance_id) &&
        identical(draw$multiplicity, tabulate(idx, nbins=length(case$subjects))))
    sealed[[label]] <- list(case_id=prior$case_id, mode=prior$mode,
      indices=as.list(idx), result=z$result, estimates=z$estimates)
  }
  api$write_json_new(sealed, file.path(out, "sealed_boundary_results.json"))
  main <- prepare_sealed_input(context, mode, "HAND_LEDGER_MAIN")
  x <- checked_prepared(main, mode)
  d <- subject_draw_mapping(main, c(1L,1L,3L,3L,5L,5L,7L,7L), "DETERMINISTIC", "DUP", mode)
  check("duplicate_sources_keep_distinct_instances", sum(d$ordered_subject_draw=="S01")==2L &&
    d$multiplicity[1L]==2L && !anyDuplicated(d$source_to_draw_instance$draw_instance_id))
  corrupt <- d; corrupt$multiplicity[1] <- 1L
  check("tampered_mapping_rejected", reject(refit_and_estimate_one_draw(main, corrupt, mode)))
  check("clinical_model_not_synthetic_fallback",
        reject(refit_and_estimate_one_draw(main, d, mode, "CLINICAL_LOGISTIC")))
  check("prepared_binding_immutable", reject(main$pd$payload <- list()))
  base <- sealed$HAND_LEDGER_MAIN_Q_SAT$result
  weighted <- sealed$NONUNIFORM_MULTIPLICITY_Q_SAT$result
  check("draw_refits_Q_and_weights", !identical(base$fits, weighted$fits) &&
          !identical(base$entry_weight_ledger, weighted$entry_weight_ledger))
  check("paired_RD_RR_direct", abs(base$contrasts$RD$value -
    (base$components$E_PL$value-base$components$D_PL$value))<1e-12 &&
    abs(base$contrasts$RR$value-base$components$E_PL$value/base$components$D_PL$value)<1e-12)
  for (g in c("E", "D")) {
    check(paste(g, "T5_included_no_K5_entry"), length(base$entry_members[[g]])==5L &&
      any(vapply(base$terminal_settlements[[g]], function(z) z$k==5, TRUE)))
    for (ac in base$artificial_censors[[g]])
      check(paste(g, ac$id, "no_post_AC_contribution"),
        all(vapply(base$entry_members[[g]][(ac$k+1L):5L],
          function(ids) !ac$id %in% unlist(ids), TRUE)))
    check(paste(g, "terminal_precedes_grace_action"),
      !"S04" %in% unlist(base$entry_members[[g]][[4L]]))
  }
  check("B14_zero_numerator_point_retained",
    sealed$ZERO_NUMERATOR_SAMPLE_KNOWN$estimates$RR$value==0 &&
    !sealed$ZERO_NUMERATOR_SAMPLE_KNOWN$estimates$RR$ci_eligible)
  check("B14_zero_denominator_unavailable",
    is.na(sealed$ZERO_REFERENCE_SAMPLE_KNOWN$estimates$RR$value))
  check("B14_both_zero_risks_retained",
    sealed$NO_EVENT_LEGAL_KNOWN$estimates$R_E$value==0 &&
    sealed$NO_EVENT_LEGAL_KNOWN$estimates$R_D$value==0 &&
    is.na(sealed$NO_EVENT_LEGAL_KNOWN$estimates$RR$value))
  arithmetic <- jsonlite::read_json("results/deterministic_004/arithmetic_fixtures_and_results.json")
  ids <- names(arithmetic$records)
  values <- seq_len(1000)
  check("type1_hand_sorted_ranks", identical(api$type1_interval(values), as.numeric(values[c(25,975)])))
  check("type1_independent_R_quantile",
    identical(api$type1_interval(values), as.numeric(quantile(values,c(.025,.975),type=1))))
  can <- aggregate_bootstrap_ci(arithmetic$original, arithmetic$records, ids, mode, context)
  check("CANARY_never_emits_SE_CI_covariance", !can$formal_CI_computed &&
    !can$formal_SE_computed && is.null(can$covariance$value) &&
    all(vapply(can$estimands, function(z) all(is.na(unlist(z$CI))), TRUE)))
  check("aggregate_FORMAL_refused",
    reject(aggregate_bootstrap_ci(arithmetic$original, arithmetic$records, ids,
                                  "FORMAL_ANALYSIS", context)))
  # Re-evaluate only the pure arithmetic fixture; this is not bootstrap.
  fresh <- api$aggregate_bootstrap(arithmetic$original, arithmetic$records, ids, TRUE)
  for (name in api$estimand_names)
    check(paste(name, "type1_matches_previous_independent_fixture"),
      isTRUE(all.equal(unlist(fresh$estimands[[name]]$CI),
                      unlist(arithmetic$summary$estimands[[name]]$CI), tolerance=1e-12)))
  arithmetic$summary <- fresh
  api$write_json_new(arithmetic, file.path(out, "arithmetic_fixtures_and_results.json"))
  partial <- aggregate_bootstrap_ci(arithmetic$original, arithmetic$partial_records, ids, mode, context)
  check("local_failure_does_not_cancel_D", partial$estimands$R_D$CI_qualified &&
    !partial$estimands$R_E$CI_qualified && !partial$estimands$RD$CI_qualified)
  records <- api$run_schedule(c("ERR","UNSTARTED"), function(id) stop("CONTROLLED_CONNECTOR_ERROR"))
  check("real_error_retained_unstarted_not_failed", records$ERR$state=="FAILED" &&
    records$ERR$error$message=="CONTROLLED_CONNECTOR_ERROR" && records$UNSTARTED$state=="NOT_STARTED")
  aborted <- api$run_schedule(c("INT","UNSTARTED"), function(id)
    stop(structure(list(message="CONTROLLED_CONNECTOR_INTERRUPT",call=NULL),class=c("interrupt","condition"))))
  check("actual_interrupt_retained", aborted$INT$state=="ABORTED" && aborted$UNSTARTED$state=="NOT_STARTED")
  api$write_json_new(list(controlled_error=records, controlled_interrupt=aborted),
                    file.path(out,"controlled_faults.json"))
  p <- prepare_sealed_input(context, mode)
  frame <- checked_prepared(p, mode)$original
  first <- jsonlite::read_json(context$contract$stream_source)$draws[[1L]]
  sampling <- list(analysis_id=context$contract$analysis_id,attempt_id=first$id,
    N=length(frame),design="IID_N_OUT_OF_N_WITH_REPLACEMENT")
  stream <- as.integer(unlist(first$initial_state))
  check("bootstrap_rejects_separate_clone_frame",
        reject(bootstrap_subject_draw(p,rep(frame,2),sampling,stream,mode)))
  wrong <- sampling; wrong$N <- 2*length(frame)
  check("bootstrap_rejects_2N_clone_sample_size",
        reject(bootstrap_subject_draw(p,frame,wrong,stream,mode)))
  check("bootstrap_rejects_unallocated_stream",
        reject(bootstrap_subject_draw(p,frame,sampling,integer(),mode)))
  check("bootstrap_requires_explicit_mode",
        reject(bootstrap_subject_draw(p,frame,sampling,stream)))
  check("bootstrap_FORMAL_rejected_before_draw",
        reject(bootstrap_subject_draw(p,frame,sampling,stream,"FORMAL_ANALYSIS")))
  idx <- as.integer(rep(seq(1L,999L,by=2L),each=2L))
  draw <- subject_draw_mapping(p,idx,"DETERMINISTIC","RETENTION",mode)
  result <- refit_and_estimate_one_draw(p,draw,mode)
  api$write_json_new(list(source_file=context$contract$source_file,
    source_sha256=p$source_sha256, indices=as.list(idx),mode="Q_SAT",result=result$result),
    file.path(out,"retention_probe_full.json"))
  api$write_json_new(list(missing_project_fields=clinical_spec_gaps(spec),
    unrepresented_input_bindings=c("input_artifact_path","input_sha256","variable_dictionary"),
    formal_execution_authorized=FALSE),file.path(out,"clinical_spec_gap_check.json"))
}, error=function(e) failure <<- e)
api$write_json_new(list(status=if(is.null(failure))"PASS"else"FAIL", count=length(checks),
  tests=checks, random_bootstrap_draws=0L, formal_CI_computed=FALSE,
  implementation_sha256=api$sha_file("inference_component.R"),
  test_code_sha256=api$sha_file("test_inference.R"),
  error=if(is.null(failure))NULL else conditionMessage(failure)),file.path(out,"TEST_RESULTS.json"))
if (!is.null(failure)) stop(failure)
cat("Inference connection assertions passed:",length(checks),"; RNG draws: 0\n")
