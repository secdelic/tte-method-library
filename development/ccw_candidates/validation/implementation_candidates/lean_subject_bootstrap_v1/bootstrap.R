# Isolated synthetic candidate. The frozen estimator is loaded, never edited.
estimand_names <- c("R_E", "R_D", "RD", "RR")
omitted_views <- c("artificial_censors", "terminal_settlements",
                  "entry_members", "entry_weight_ledger")
sha_file <- function(path) digest::digest(file=path, algo="sha256", serialize=FALSE)
write_json_new <- function(x, path) {
  if (file.exists(path)) stop("REFUSE_OVERWRITE: ", path)
  jsonlite::write_json(x, path, auto_unbox=TRUE, pretty=TRUE, digits=17,
                      na="null", null="null")
}
load_frozen_core <- function(root, contract) {
  for (p in names(contract$approved_files))
    if (!identical(sha_file(file.path(root, p)), contract$approved_files[[p]]))
      stop("APPROVED_INPUT_IDENTITY_CHANGED: ", p)
  for (p in names(contract$dependencies))
    if (!identical(sha_file(file.path(root, p)), contract$dependencies[[p]]))
      stop("DEPENDENCY_IDENTITY_CHANGED: ", p)
  engine <- new.env(parent=globalenv())
  sys.source(file.path(root, contract$core_file), envir=engine)
  engine
}
validate_canary_request <- function(contract, B, source_file, output_inference=FALSE) {
  if (!identical(contract$kind, "ISOLATED_SEALED_SYNTHETIC_CANARY_ONLY") ||
      length(B)!=1L || !is.finite(B) || B!=floor(B) || B<1 || B>20 ||
      B!=contract$B || B>contract$total_random_draw_budget ||
      !identical(source_file, contract$source_file) || output_inference ||
      isTRUE(contract$emit_CI) || isTRUE(contract$emit_SE) ||
      isTRUE(contract$emit_covariance))
    stop("OUTSIDE_AUTHORIZED_SYNTHETIC_CANARY_SCOPE")
  invisible(TRUE)
}
validate_source <- function(case, engine) {
  # This adapter accepts the sealed, pre-eligible, one-unit-per-subject fixture.
  # It is not a clinical eligibility filter or a multiple-unit adapter.
  if (anyDuplicated(vapply(case$subjects, function(s) s$original_id, "")))
    stop("ONE_UNIT_PER_ORIGINAL_SUBJECT_REQUIRED")
  probe <- case
  probe$multiplicity <- as.list(rep(1L, length(case$subjects)))
  x <- engine$assemble_input(probe)
  if (!all(x$eligible)) stop("PREELIGIBLE_INPUT_REQUIRED_NO_AUTOMATIC_EXCLUSION")
  invisible(length(case$subjects))
}
refit_subject_draw <- function(case, indices, engine, mode="Q_SAT") {
  n <- length(case$subjects)
  if (!is.integer(indices) || length(indices)!=n || anyNA(indices) ||
      any(indices<1L | indices>n)) stop("INVALID_COMPLETE_SUBJECT_DRAW")
  if (!mode %in% c("Q_SAT", "KNOWN")) stop("UNSUPPORTED_MODEL_NO_FALLBACK")
  draw <- case
  draw$multiplicity <- as.list(tabulate(indices, nbins=n))
  draw$representation <- "SOURCE_MULTIPLICITY"
  # All required cells, models, weights, hazards and paired contrasts are refit.
  engine$analyze_candidate(draw, mode, retain_ledger=TRUE)
}
unavailable_estimates <- function(stage, reason) {
  setNames(lapply(estimand_names, function(id)
    list(value=NA_real_, point_status="UNAVAILABLE_EXECUTION_DEPENDENCY",
         availability="EXECUTION_UNAVAILABLE", ci_eligible=FALSE,
         failed_stage=stage, reasons=as.list(reason))), estimand_names)
}
extract_estimates <- function(result) {
  if (!isTRUE(result$input_valid))
    return(unavailable_estimates(result$failed_stage, result$reason))
  out <- list()
  for (id in estimand_names) {
    dep <- switch(id, R_E="E_PL", R_D="D_PL", c("E_PL", "D_PL"))
    z <- if (id=="R_E") result$components$E_PL else if (id=="R_D")
      result$components$D_PL else result$contrasts[[id]]
    execution <- any(vapply(result$components[dep],
      function(x) identical(x$source_status, "MODEL_FAILURE"), TRUE))
    finite <- length(z$value)==1L && is.finite(z$value)
    reasons <- unique(unlist(lapply(result$components[dep], function(x)
      c(if (!identical(x$source_status, "AVAILABLE")) x$source_status,
        unlist(x$failure_reasons))), use.names=FALSE))
    if (!finite) reasons <- unique(c(reasons, z$point_status))
    out[[id]] <- list(value=z$value, point_status=z$point_status,
      availability=if (finite) "AVAILABLE" else if (execution)
        "EXECUTION_UNAVAILABLE" else "SCIENTIFIC_NONESTIMABLE",
      ci_eligible=finite && identical(z$CI_eligibility, "ELIGIBLE_BY_CONSERVATIVE_POLICY"),
      failed_stage=unique(unlist(lapply(result$components[dep], `[[`, "failed_stage"))),
      reasons=as.list(reasons))
  }
  out
}
statistical_state <- function(estimates) {
  failed <- vapply(estimates[c("R_E", "R_D")],
    function(x) x$availability=="EXECUTION_UNAVAILABLE", TRUE)
  if (all(failed)) "FAILED" else if (any(failed)) "PARTIALLY_FAILED" else "COMPLETED"
}
compact_result <- function(full, reconstruction_gate) {
  if (!isTRUE(reconstruction_gate)) stop("INDEPENDENT_RECONSTRUCTION_GATE_REQUIRED")
  full[setdiff(names(full), omitted_views)]
}
run_schedule <- function(ids, execute, event=function(x) invisible(NULL)) {
  if (anyDuplicated(ids)) stop("DUPLICATE_ATTEMPT_ID")
  records <- setNames(lapply(ids, function(id) list(id=id, state="NOT_STARTED")), ids)
  for (id in ids) {
    start <- format(Sys.time(), "%Y-%m-%dT%H:%M:%OS6%z")
    event(list(id=id, state="STARTED", actual_time=start))
    warnings <- character()
    failure <- NULL
    interrupted <- FALSE
    t <- proc.time()
    answer <- tryCatch(withCallingHandlers(execute(id),
      warning=function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }), interrupt=function(e) {
        failure <<- e; interrupted <<- TRUE; NULL
      }, error=function(e) {
        failure <<- e; NULL
      })
    if (!is.null(failure)) {
      state <- if (interrupted) "ABORTED" else "FAILED"
      reason <- if (interrupted) "INTERRUPTED" else conditionMessage(failure)
      stage <- if (is.null(failure$failed_stage)) "ATTEMPT_EXECUTION" else failure$failed_stage
      answer <- list(estimates=unavailable_estimates(stage, reason))
    } else state <- statistical_state(answer$estimates)
    record <- list(id=id, state=state, actual_start=start,
      actual_end=format(Sys.time(), "%Y-%m-%dT%H:%M:%OS6%z"),
      warnings=as.list(warnings),
      error=if (is.null(failure)) NULL else list(message=conditionMessage(failure),
        classes=class(failure), failed_stage=stage, call=if (is.null(conditionCall(failure))) NULL
          else paste(deparse(conditionCall(failure)), collapse="\n")),
      timings=list(wall_seconds=unname((proc.time()-t)[[3L]]),
                   cpu_seconds=unname(sum((proc.time()-t)[1:2]))),
      estimates=answer$estimates, evidence=answer$evidence)
    records[[id]] <- record
    event(record)
    # A technical error is retained and stops new work. There is no retry,
    # replacement draw, or broad catch-and-continue fallback.
    if (!is.null(failure)) break
  }
  records
}
type1_interval <- function(values, log_scale=FALSE) {
  if (!length(values) || any(!is.finite(values))) stop("NONFINITE_QUANTILE_INPUT")
  if (log_scale && any(values<=0)) stop("LOG_RR_DOMAIN_FAILURE")
  z <- if (log_scale) log(values) else values
  bounds <- as.numeric(stats::quantile(z, probs=c(.025, .975), type=1, names=FALSE))
  if (log_scale) bounds <- exp(bounds)
  if (any(!is.finite(bounds))) stop("NONFINITE_QUANTILE_OUTPUT")
  bounds
}
aggregate_bootstrap <- function(original, records, requested_ids,
                                emit_test_intervals=FALSE) {
  if (anyDuplicated(requested_ids) || !identical(names(records), requested_ids))
    stop("ATTEMPT_IDENTITY_OR_ORDER_MISMATCH")
  requested <- length(requested_ids)
  states <- vapply(records, `[[`, "", "state")
  allowed <- c("NOT_STARTED", "COMPLETED", "PARTIALLY_FAILED", "FAILED", "ABORTED")
  if (!all(states %in% allowed)) stop("UNCLOSED_ATTEMPT_STATE")
  attempted <- records[states!="NOT_STARTED"]
  count <- as.list(setNames(vapply(allowed, function(s) sum(states==s), 0L),
                           tolower(allowed)))
  count$requested <- requested
  count$attempted <- length(attempted)
  stopifnot(count$requested==count$not_started+count$attempted,
    count$attempted==sum(unlist(count[c("completed","partially_failed","failed","aborted")])))
  output <- list()
  for (id in estimand_names) {
    aa <- lapply(attempted, function(x) x$estimates[[id]])
    avail <- vapply(aa, `[[`, "", "availability")
    eligible <- vapply(aa, function(x) isTRUE(x$ci_eligible), TRUE)
    ready <- isTRUE(original[[id]]$ci_eligible) &&
      requested>0L && length(aa)==requested && all(eligible)
    bounds <- c(NA_real_, NA_real_)
    aggregation_error <- NULL
    status <- if (ready) "QUALIFIED_BUT_NOT_COMPUTED_CANARY" else
      "UNAVAILABLE_ORIGINAL_OR_REQUIRED_DRAWS"
    if (ready && emit_test_intervals) {
      bounds <- tryCatch(type1_interval(vapply(aa, `[[`, 0.0, "value"), id=="RR"),
        error=function(e) {aggregation_error <<- conditionMessage(e); c(NA_real_,NA_real_)})
      status <- if (is.null(aggregation_error))
        "DETERMINISTIC_ARITHMETIC_TEST_ONLY" else "UNAVAILABLE_AGGREGATION_FAILURE"
    }
    cc <- list(point_available=sum(avail=="AVAILABLE"),
      scientific_nonestimable=sum(avail=="SCIENTIFIC_NONESTIMABLE"),
      execution_unavailable=sum(avail=="EXECUTION_UNAVAILABLE"),
      CI_eligible=sum(eligible), CI_unavailable=sum(!eligible))
    stopifnot(sum(unlist(cc[1:3]))==length(attempted),
              cc$CI_eligible+cc$CI_unavailable==length(attempted))
    bad <- attempted[!eligible]
    output[[id]] <- list(point=original[[id]], draw_counts=cc, CI_qualified=ready,
      CI_status=status, CI=as.list(bounds), aggregation_error=aggregation_error,
      unavailable_attempts=lapply(bad, function(x)
        list(id=x$id, state=x$state, detail=x$estimates[[id]])),
      point_preserved_despite_CI_failure=TRUE)
  }
  covariance <- list(status="NOT_COMPUTED_CANARY", value=NULL)
  if (emit_test_intervals) {
    joint <- vapply(attempted, function(x)
      all(vapply(x$estimates, function(z) z$availability=="AVAILABLE" &&
                 is.finite(z$value), TRUE)), TRUE)
    n <- sum(joint)
    mat <- if (n) t(vapply(attempted[joint], function(x)
      vapply(x$estimates[estimand_names], `[[`, 0.0, "value"), numeric(4))) else NULL
    covariance <- list(status=if (n<2L) "UNAVAILABLE_TOO_FEW_COMMON_DRAWS"
      else if (n==requested) "DETERMINISTIC_TEST_COMPLETE_COMMON_DRAWS"
      else "DETERMINISTIC_TEST_DESCRIPTIVE_INCOMPLETE_COMMON_DRAWS",
      common_draw_count=n, requested=requested,
      columns=as.list(estimand_names), value=if (n>=2L) unname(stats::cov(mat)) else NULL)
  }
  list(accounting=count, estimands=output, covariance=covariance,
       formal_CI_computed=FALSE, formal_SE_computed=FALSE,
       arithmetic_test_intervals_only=emit_test_intervals)
}
