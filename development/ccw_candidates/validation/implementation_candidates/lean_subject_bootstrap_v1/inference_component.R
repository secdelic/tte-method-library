# Isolated connection layer. Frozen core, PreparedData and CI arithmetic are reused.
clinical_required_paths <- c(
  "analysis_id", "design.analysis_population", "design.protocol_reference",
  "population.id", "population.cluster_id", "population.analysis_unit_id",
  "population.eligibility_definition", "population.eligibility_information_cutoff",
  "time_zero.variable", "time_zero.definition",
  "time_zero.eligibility_cloning_initiation_micro_order",
  "treatment.definition", "treatment.actual_effective_start_variable",
  "strategies.1.definition", "strategies.1.within_grace_intervention_distribution",
  "strategies.1.postgrace_policy", "strategies.2.definition",
  "strategies.2.within_grace_intervention_distribution", "strategies.2.postgrace_policy",
  "grace_period.start", "grace_period.end", "grace_period.unit", "grace_period.inclusivity",
  "follow_up.start", "follow_up.end", "follow_up.administrative_end", "follow_up.unit",
  "follow_up.decision_grid", "follow_up.measurement_and_availability_mapping",
  "follow_up.treatment_terminal_tie_rule", "follow_up.artificial_censoring_rule",
  "follow_up.natural_censoring_handling", "outcome.variable", "outcome.definition",
  "outcome.terminal_codes", "estimand.target_population", "estimand.horizon",
  "estimand.policy_law_definition", "baseline_confounders", "time_varying_confounders",
  "weighting.probability_model.fitting_population_and_risk_subset",
  "weighting.probability_model.response_orientation",
  "weighting.probability_model.formula_link_time_basis",
  "weighting.probability_model.variables_interactions_lags",
  "weighting.probability_model.availability_cutoff",
  "weighting.probability_model.required_fit_consumers_before_fitting",
  "weighting.probability_model.solver_and_convergence_contract",
  "variance.cluster_id", "variance.bootstrap.subject_sampling_design",
  "variance.bootstrap.rng.project_seed", "variance.bootstrap.rng.stream_allocation")

clinical_spec_gaps <- function(spec) {
  absent <- function(path) {
    x <- spec
    for (part in strsplit(path, ".", fixed=TRUE)[[1L]]) {
      if (!is.list(x)) return(TRUE)
      key <- if (grepl("^[0-9]+$", part)) as.integer(part) else part
      if (is.numeric(key) && key>length(x)) return(TRUE)
      x <- x[[key]]
    }
    is.null(x) || (is.character(x) && (!length(x) || all(!nzchar(trimws(x)))))
  }
  clinical_required_paths[vapply(clinical_required_paths, absent, TRUE)]
}

require_execution_mode <- function(mode, spec=NULL) {
  if (missing(mode) || is.null(mode) || length(mode)!=1L ||
      !is.character(mode) || is.na(mode) || !mode %in% c("CANARY", "FORMAL_ANALYSIS"))
    stop("EXPLICIT_CANARY_OR_FORMAL_ANALYSIS_MODE_REQUIRED")
  if (mode=="FORMAL_ANALYSIS")
    stop(structure(list(message="FORMAL_ANALYSIS_NOT_AUTHORIZED_CLINICAL_ADAPTER_PENDING",
      call=NULL, missing_project_fields=clinical_spec_gaps(spec)),
      class=c("ccw_formal_not_authorized", "error", "condition")))
  invisible(mode)
}

load_inference_context <- function(root, mode, analysis_spec=NULL) {
  require_execution_mode(mode, analysis_spec)
  here <- file.path(root, "validation/implementation_candidates/lean_subject_bootstrap_v1")
  api <- new.env(parent=globalenv())
  sys.source(file.path(here, "bootstrap.R"), api)
  contract <- jsonlite::read_json(file.path(here, "inputs/inference_contract_v1.json"))
  if (!identical(contract$allowed_actual_mode, mode) ||
      !isFALSE(contract$formal_execution_authorized))
    stop("EXECUTION_PERMISSION_MISMATCH")
  for (p in names(c(contract$approved_files, contract$dependencies))) {
    expected <- c(contract$approved_files, contract$dependencies)[[p]]
    if (!identical(api$sha_file(file.path(root, p)), expected))
      stop("APPROVED_OR_DEPENDENCY_BYTES_CHANGED: ", p)
  }
  if (!identical(api$sha_file(file.path(here, "inputs/authorization.json")),
                 contract$previous_authorization_sha256))
    stop("AUTHORIZATION_BYTES_CHANGED")
  if (!identical(api$sha_file(file.path(here, contract$stream_source)),
                 contract$stream_source_sha256))
    stop("PREALLOCATED_STREAM_PLAN_CHANGED")
  staged <- new.env(parent=globalenv())
  staged$frozen_core <- new.env(parent=globalenv())
  sys.source(file.path(root,
    "validation/implementation_candidates/gv_oracle_core_optimization_v1/core_candidate_optimized.R"),
    staged$frozen_core)
  base <- file.path(root, "validation/implementation_candidates/gv_oracle_staged_runner_dev_v1")
  staged$runtime_identity <- jsonlite::read_json(file.path(base, "inputs/runtime_identity.json"))
  # Evaluate the exact existing function definitions, omitting the old CLI's
  # working-directory-dependent top-level sourcing and unused full writer.
  wanted <- c("immutable_env", "prepare_dataset", "prepared_payload", "draw_assembler",
              "refit_one_draw", "science_only")
  expressions <- parse(file.path(base, "staged_core.R"))
  for (name in wanted) {
    found <- Filter(function(x) is.call(x) && identical(x[[1L]], as.name("<-")) &&
      identical(x[[2L]], as.name(name)), as.list(expressions))
    if (length(found)!=1L) stop("PREPARED_INTERFACE_DEFINITION_MISSING: ", name)
    eval(found[[1L]], staged)
  }
  staged$prepared_scope <- new.env(parent=staged$frozen_core)
  staged$prepared_scope$assemble_input <- staged$draw_assembler
  staged$prepared_analyze <- staged$frozen_core$analyze_candidate
  environment(staged$prepared_analyze) <- staged$prepared_scope
  list(root=root, here=here, contract=contract, api=api, staged=staged, mode=mode)
}

prepare_sealed_input <- function(context, mode, fixture_id=NULL) {
  require_execution_mode(mode)
  if (!identical(context$mode, mode)) stop("CONTEXT_MODE_MISMATCH")
  rel <- if (is.null(fixture_id)) context$contract$source_file else
    "validation/implementation_candidates/gv_oracle_minimal_core_v1/inputs/small_fixtures.json"
  file <- file.path(context$root, rel)
  digest <- context$api$sha_file(file)
  if (!identical(digest, context$contract$dependencies[[rel]]))
    stop("SEALED_SOURCE_CHANGED")
  source <- jsonlite::read_json(file)
  if (!is.null(fixture_id)) {
    found <- Filter(function(z) identical(z$case_id, fixture_id), source$cases)
    if (length(found)!=1L) stop("SEALED_FIXTURE_ID_NOT_FOUND")
    source <- found[[1L]]
  }
  context$api$validate_source(source, context$staged$frozen_core)
  identity <- list(input_sha256=digest, case_id=source$case_id, fixture_id=fixture_id)
  pd <- context$staged$prepare_dataset(source, identity)
  list(pd=pd, identity=identity, source_file=file, source_sha256=digest,
       context=context, synthetic_only=TRUE)
}

checked_prepared <- function(prepared, mode) {
  require_execution_mode(mode)
  if (!isTRUE(prepared$synthetic_only) || !identical(prepared$context$mode, mode))
    stop("SEALED_SYNTHETIC_PREPARED_INPUT_REQUIRED")
  if (!identical(prepared$context$api$sha_file(prepared$source_file), prepared$source_sha256))
    stop("SOURCE_CHANGED_AFTER_PREPARATION")
  prepared$context$staged$prepared_payload(prepared$pd, prepared$identity,
    prepared$context$staged$runtime_identity$outputs)$typed
}

subject_draw_mapping <- function(prepared, indices, analysis_id, attempt_id, mode) {
  x <- checked_prepared(prepared, mode)
  if (!is.integer(indices) || length(indices)!=x$n || anyNA(indices) ||
      any(indices<1L | indices>x$n)) stop("INVALID_N_OUT_OF_N_SUBJECT_MAP")
  ids <- c(analysis_id, attempt_id)
  if (length(ids)!=2L || anyNA(ids) || any(!grepl("^[A-Za-z0-9_-]+$", ids)))
    stop("EXPLICIT_ANALYSIS_AND_ATTEMPT_ID_REQUIRED")
  key <- paste(analysis_id, attempt_id, sep="/")
  list(analysis_id=analysis_id, attempt_id=attempt_id, draw_id=key,
    source_identity=prepared$identity, indices=indices,
    ordered_subject_draw=x$original[indices],
    source_to_draw_instance=data.frame(
      draw_instance_id=paste(key, sprintf("%06d", seq_along(indices)), sep="/"),
      source_index=indices, source_original_subject_id=x$original[indices],
      source_analysis_unit_id=x$ids[indices], stringsAsFactors=FALSE),
    multiplicity=tabulate(indices, nbins=x$n),
    E_D_shared_draw_identity=list(E=key, D=key))
}

bootstrap_subject_draw <- function(prepared, source_subject_ids, sampling_contract,
                                   rng_stream, mode) {
  x <- checked_prepared(prepared, mode)
  if (!identical(source_subject_ids, x$original) || anyDuplicated(source_subject_ids))
    stop("SOURCE_SUBJECT_FRAME_MISMATCH")
  if (!identical(sampling_contract$design, "IID_N_OUT_OF_N_WITH_REPLACEMENT") ||
      length(sampling_contract$N)!=1L || !is.finite(sampling_contract$N) ||
      sampling_contract$N!=x$n)
    stop("UNAPPROVED_SUBJECT_SAMPLING_DESIGN")
  plan <- jsonlite::read_json(file.path(prepared$context$here,
                                      prepared$context$contract$stream_source))
  tasks <- Filter(function(z) identical(z$id, sampling_contract$attempt_id), plan$draws)
  if (length(tasks)!=1L || tasks[[1L]]$N!=x$n ||
      !identical(prepared$source_sha256,
                 prepared$context$contract$dependencies[[prepared$context$contract$source_file]]) ||
      !is.integer(rng_stream) || length(rng_stream)!=7L ||
      anyNA(rng_stream) || !identical(rng_stream, as.integer(unlist(tasks[[1L]]$initial_state))) ||
      !identical(sampling_contract$analysis_id, prepared$context$contract$analysis_id))
    stop("PREALLOCATED_ATTEMPT_STREAM_IDENTITY_REQUIRED")
  old_kind <- RNGkind()
  had_seed <- exists(".Random.seed", .GlobalEnv, inherits=FALSE)
  old_seed <- if (had_seed) get(".Random.seed", .GlobalEnv) else NULL
  on.exit({
    do.call(RNGkind, as.list(old_kind))
    if (had_seed) assign(".Random.seed", old_seed, .GlobalEnv)
    else if (exists(".Random.seed", .GlobalEnv, inherits=FALSE)) rm(".Random.seed", envir=.GlobalEnv)
  })
  RNGkind("L'Ecuyer-CMRG", "Inversion", "Rejection")
  assign(".Random.seed", rng_stream, .GlobalEnv)
  indices <- as.integer(sample.int(x$n, x$n, replace=TRUE))
  after <- get(".Random.seed", .GlobalEnv)
  out <- subject_draw_mapping(prepared, indices, sampling_contract$analysis_id,
                              sampling_contract$attempt_id, mode)
  out$RNG <- list(initial_state=as.list(rng_stream), after_draw_state=as.list(after),
                 kind="L'Ecuyer-CMRG", normal_kind="Inversion", sample_kind="Rejection")
  out
}

refit_and_estimate_one_draw <- function(prepared, draw, mode, model="Q_SAT") {
  checked_prepared(prepared, mode)
  if (!model %in% c("Q_SAT", "KNOWN")) stop("CLINICAL_PROBABILITY_MODEL_NOT_IMPLEMENTED")
  check <- subject_draw_mapping(prepared, draw$indices, draw$analysis_id, draw$attempt_id, mode)
  if (!identical(draw[names(check)], check)) stop("DRAW_IDENTITY_OR_MULTIPLICITY_CHANGED")
  full <- prepared$context$staged$refit_one_draw(prepared$pd, draw$indices,
    prepared$identity, model, retain_ledger=TRUE)
  list(result=full, estimates=prepared$context$api$extract_estimates(full),
       draw_id=draw$draw_id, full_refit=TRUE, model_scope="SEALED_SYNTHETIC_ONLY")
}

aggregate_bootstrap_ci <- function(original_point, attempt_records, requested_ids,
                                   mode, context) {
  require_execution_mode(mode)
  if (!identical(context$mode, mode)) stop("CONTEXT_MODE_MISMATCH")
  out <- context$api$aggregate_bootstrap(original_point, attempt_records, requested_ids,
                                        emit_test_intervals=FALSE)
  out$mode <- mode
  out$original_point_eligibility <- lapply(original_point, `[[`, "ci_eligible")
  out$CI_definition <- list(level=.95, type="pointwise_percentile", quantile_type=1L,
    risk_RD_scale="identity", RR_scale="log_then_exp",
    all_required_draws_eligible=TRUE, adopted_formal_B=1000L,
    formal_execution_authorized=FALSE)
  out
}
