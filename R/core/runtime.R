# Registered production runtime. Only allowlisted profiles can execute.

tte_read_production_registry <- function(path) {
  if (!file.exists(path)) stop("Production registry not found: ", path)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

tte_assert_profile_allowed <- function(profile, registry) {
  row <- registry[registry$profile == profile, , drop = FALSE]
  if (nrow(row) != 1L || toupper(row$production_allowed) != "TRUE") {
    stop("Profile is not production-approved: ", profile)
  }
  invisible(row)
}

tte_evaluate_diagnostic_gate <- function(profile, result, configuration,
                                         warnings, independent) {
  failures <- character()
  blocking_warning <- warnings$severity %in% c("CRITICAL", "UNCLASSIFIED") |
    warnings$review_status == "NOT_REVIEWED"
  if (any(blocking_warning)) failures <- c(failures, "blocking runtime warning")
  if (any(independent$status == "FAIL")) failures <- c(failures, "independent numerical mismatch")
  if (profile == "BASELINE_BINARY_RISK") {
    if (tte_maximum_absolute_smd(result$balance) > configuration$max_abs_smd) {
      failures <- c(failures, "balance threshold failed")
    }
    if (result$weight_summary$total_ess < configuration$min_total_ess) {
      failures <- c(failures, "total ESS threshold failed")
    }
    if (min(result$weight_summary$n_control, result$weight_summary$n_treated) <
        configuration$min_group_n) {
      failures <- c(failures, "minimum treatment-group count failed")
    }
    if (result$weight_summary$positivity_violation_rate >
        configuration$max_positivity_violation_rate) {
      failures <- c(failures, "positivity threshold failed")
    }
  } else {
    if (result$weight_summary$maximum_abs_smd > configuration$max_abs_smd) {
      failures <- c(failures, "at least one imputation failed balance")
    }
    if (result$weight_summary$minimum_total_ess < configuration$min_total_ess) {
      failures <- c(failures, "at least one imputation failed ESS")
    }
    if (result$weight_summary$maximum_positivity_violation_rate >
        configuration$max_positivity_violation_rate) {
      failures <- c(failures, "at least one imputation failed positivity")
    }
    if (result$weight_summary$mice_logged_events > 0) {
      failures <- c(failures, "MICE logged events require review")
    }
  }
  data.frame(
    profile = profile,
    diagnostic_gate_pass = !length(failures),
    failure_count = length(failures),
    stopping_reasons = paste(unique(failures), collapse = " | "),
    scientific_approval_granted_by_code = FALSE,
    stringsAsFactors = FALSE
  )
}

tte_run_analysis <- function(
    profile, data_path, config_dir, output_dir = "output",
    execution_mode = "SYNTHETIC_TEST", project_root = ".") {
  if (!execution_mode %in% c("SYNTHETIC_TEST", "CANARY", "FORMAL_CANDIDATE")) {
    stop("Invalid execution_mode")
  }
  registry <- tte_read_production_registry(
    file.path(project_root, "runtime", "production_registry.csv")
  )
  tte_assert_profile_allowed(profile, registry)
  specification <- tte_read_analysis_spec(
    file.path(config_dir, "analysis_spec.yml"), profile
  )
  configuration <- tte_profile_configuration(specification, profile)
  dictionary <- tte_read_variable_dictionary(
    file.path(config_dir, "variable_dictionary.csv")
  )
  data <- utils::read.csv(
    data_path, check.names = FALSE, stringsAsFactors = FALSE,
    colClasses = c(subject_id = "character", analysis_id = "character")
  )
  contract_checks <- validate_runtime_contract_files(
    analysis_spec_path = file.path(config_dir, "analysis_spec.yml"),
    variable_dictionary_path = file.path(config_dir, "variable_dictionary.csv"),
    input_contract_path = file.path(config_dir, "input_data_contract.csv"),
    profile = profile, execution_mode = execution_mode,
    data_names = names(data)
  )
  audit <- tte_validate_inputs(data, dictionary, profile, configuration)
  tte_ensure_output_tree(output_dir)
  tte_write_csv(contract_checks, file.path(output_dir, "diagnostics", "contract_validation.csv"))
  tte_write_csv(data.frame(
    profile = profile, structural_pass = audit$pass,
    issue_count = length(audit$issues),
    issues = paste(audit$issues, collapse = " | "),
    stringsAsFactors = FALSE
  ), file.path(output_dir, "diagnostics", "structure_audit.csv"))
  if (!audit$pass) stop(paste(audit$issues, collapse = " | "))
  captured <- tte_capture_warnings({
    if (profile == "BASELINE_BINARY_RISK") {
      tte_run_baseline_tte(data, audit$covariates, configuration)
    } else {
      tte_run_mi_ps(data, dictionary, audit$covariates, configuration)
    }
  })
  tte_write_csv(captured$warnings, file.path(output_dir, "logs", "warnings.csv"))
  if (captured$failed) stop(captured$value$error)
  result <- captured$value
  independent <- if (profile == "BASELINE_BINARY_RISK") {
    tte_independent_validate_baseline(data, audit$covariates, result)
  } else {
    tte_independent_validate_mi(result, nrow(data))
  }
  gate <- tte_evaluate_diagnostic_gate(
    profile, result, configuration, captured$warnings, independent
  )
  tte_write_csv(independent, file.path(output_dir, "diagnostics", "independent_validation.csv"))
  tte_write_csv(gate, file.path(output_dir, "diagnostics", "diagnostic_gate.csv"))
  tte_write_csv(result$balance, file.path(output_dir, "diagnostics", "balance.csv"))
  tte_write_csv(result$weight_summary, file.path(output_dir, "diagnostics", "weight_summary.csv"))
  if (profile == "MI_PS_CONTINUOUS_ATE") {
    tte_write_csv(
      result$per_imputation,
      file.path(output_dir, "diagnostics", "per_imputation_estimates.csv")
    )
  }
  tte_write_csv(data.frame(
    input_file = basename(data_path),
    input_sha256 = tte_sha256_file(data_path),
    analysis_spec_sha256 = tte_sha256_file(file.path(config_dir, "analysis_spec.yml")),
    variable_dictionary_sha256 = tte_sha256_file(file.path(config_dir, "variable_dictionary.csv")),
    row_count = nrow(data), column_count = ncol(data), profile = profile,
    stringsAsFactors = FALSE
  ), file.path(output_dir, "diagnostics", "input_manifest.csv"))
  tte_write_csv(
    tte_package_versions(c("mice", "WeightIt", "cobalt", "ggplot2", "yaml", "digest")),
    file.path(output_dir, "logs", "package_versions.csv")
  )
  figure_config <- read_figure_config(file.path(config_dir, "figure_config.yml"))
  release_status <- if (execution_mode == "SYNTHETIC_TEST") {
    "SYNTHETIC_TEST_NOT_FOR_REPORTING"
  } else {
    "AUDIT_ONLY_NOT_FOR_FORMAL_REPORTING"
  }
  publication <- tte_write_publication_outputs(
    result, profile, configuration$analysis_population,
    data, audit$covariates, output_dir, figure_config, release_status
  )
  if (nrow(result$sensitivity)) {
    sensitivity <- tte_standardize_effects(
      result$sensitivity, profile, configuration$analysis_population, release_status
    )
    tte_write_csv(
      sensitivity,
      file.path(output_dir, "sensitivity", "sensitivity_results.csv")
    )
  }
  saveRDS(result$internal, file.path(output_dir, "internal", "analysis_internal.rds"))
  invisible(list(
    result = result, independent = independent, gate = gate,
    publication = publication, configuration = configuration
  ))
}
