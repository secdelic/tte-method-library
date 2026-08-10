# Unified runtime contracts for the TTE statistical execution library.
#
# These validators check structure and declared consistency only. They never
# select scientific variables, estimands, models, thresholds, or strategies.

tte_required_analysis_fields <- function() {
  c(
    "design", "population", "time_zero", "treatment", "strategies",
    "grace_period", "follow_up", "outcome", "estimand",
    "baseline_confounders", "time_varying_confounders", "missing_data",
    "weighting", "variance", "sensitivity", "figures", "governance"
  )
}

tte_required_dictionary_columns <- function() {
  c(
    "variable", "label", "role", "type", "unit", "reference", "levels",
    "measurement_time", "availability_time", "relation_to_time_zero",
    "missing_code", "valid_min", "valid_max", "impute", "mice_method",
    "include_in_model", "notes"
  )
}

tte_allowed_variable_roles <- function() {
  c(
    "population_id", "cluster_id", "eligibility", "treatment", "outcome",
    "baseline_confounder", "time_varying_confounder", "time", "censoring",
    "descriptive_only"
  )
}

tte_scalar_text <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) && nzchar(trimws(x))
}

tte_is_placeholder <- function(x) {
  is.null(x) || !length(x) || is.na(x[[1]]) ||
    grepl("^<.*>$", trimws(as.character(x[[1]])))
}

read_analysis_spec <- function(path) {
  if (!file.exists(path)) stop("Missing analysis specification: ", path)
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("Package 'yaml' is required to read analysis_spec.yml")
  }
  yaml::read_yaml(path)
}

select_analysis_definition <- function(spec, profile = NULL) {
  if (!is.null(spec$analyses)) {
    if (is.null(profile) || !tte_scalar_text(profile)) {
      stop("A profile is required when analysis_spec.yml contains analyses")
    }
    if (!profile %in% names(spec$analyses)) {
      stop("Profile is absent from analysis_spec.yml: ", profile)
    }
    return(spec$analyses[[profile]])
  }
  spec
}

validate_analysis_spec <- function(spec, profile = NULL,
                                   execution_mode = "TEMPLATE") {
  mode <- toupper(execution_mode)
  allowed_modes <- c("TEMPLATE", "SYNTHETIC_TEST", "CANARY", "FORMAL_CANDIDATE")
  if (!mode %in% allowed_modes) stop("Invalid execution mode: ", execution_mode)
  analysis <- select_analysis_definition(spec, profile)
  missing_fields <- setdiff(tte_required_analysis_fields(), names(analysis))
  issues <- character()
  if (length(missing_fields)) {
    issues <- c(issues, paste0(
      "Missing analysis specification fields: ",
      paste(missing_fields, collapse = ", ")
    ))
  }
  if (!is.null(analysis$governance$result_dependent_changes_allowed) &&
      isTRUE(analysis$governance$result_dependent_changes_allowed)) {
    issues <- c(issues, "Result-dependent analysis specification changes are prohibited")
  }
  frozen <- isTRUE(analysis$scientific_fields_frozen) ||
    isTRUE(spec$scientific_fields_frozen)
  if (mode %in% c("CANARY", "FORMAL_CANDIDATE") && !frozen) {
    issues <- c(issues, "Scientific fields are not frozen")
  }
  required_scientific_values <- list(
    population_id = analysis$population$id,
    time_zero_variable = analysis$time_zero$variable,
    treatment_variable = analysis$treatment$variable,
    outcome_variable = analysis$outcome$variable,
    estimand = analysis$estimand$name
  )
  if (mode != "TEMPLATE") {
    unresolved <- names(required_scientific_values)[vapply(
      required_scientific_values, tte_is_placeholder, logical(1)
    )]
    if (length(unresolved)) {
      issues <- c(issues, paste0(
        "Unresolved researcher-supplied scientific fields: ",
        paste(unresolved, collapse = ", ")
      ))
    }
  }
  data.frame(
    check = c("required_fields", "scientific_fields_frozen",
              "result_dependent_changes_disabled", "scientific_values_resolved"),
    pass = c(
      !length(missing_fields),
      mode %in% c("TEMPLATE", "SYNTHETIC_TEST") || frozen,
      !isTRUE(analysis$governance$result_dependent_changes_allowed),
      mode == "TEMPLATE" || !any(vapply(
        required_scientific_values, tte_is_placeholder, logical(1)
      ))
    ),
    evidence = c(
      if (length(missing_fields)) paste(missing_fields, collapse = "|") else "complete",
      paste0("execution_mode=", mode, "; frozen=", frozen),
      paste0("result_dependent_changes_allowed=",
             isTRUE(analysis$governance$result_dependent_changes_allowed)),
      if (length(issues)) paste(unique(issues), collapse = " | ") else "resolved"
    ),
    stringsAsFactors = FALSE
  )
}

read_variable_dictionary <- function(path) {
  if (!file.exists(path)) stop("Missing variable dictionary: ", path)
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE,
                  na.strings = character())
}

validate_variable_dictionary <- function(dictionary, data_names = NULL,
                                         allow_template_row = FALSE) {
  required <- tte_required_dictionary_columns()
  missing_columns <- setdiff(required, names(dictionary))
  if (length(missing_columns)) {
    stop("Variable dictionary is missing columns: ",
         paste(missing_columns, collapse = ", "))
  }
  dictionary <- dictionary[, required, drop = FALSE]
  template_row <- grepl("^<.*>$", trimws(dictionary$variable))
  assessed <- if (allow_template_row) dictionary[!template_row, , drop = FALSE] else dictionary
  duplicate_variables <- unique(assessed$variable[duplicated(assessed$variable)])
  invalid_roles <- setdiff(unique(assessed$role), tte_allowed_variable_roles())
  invalid_baseline_time <- assessed$role == "baseline_confounder" &
    !assessed$relation_to_time_zero %in% c("before", "at")
  invalid_model_flag <- !toupper(assessed$include_in_model) %in% c("TRUE", "FALSE")
  invalid_impute_flag <- !toupper(assessed$impute) %in% c("TRUE", "FALSE")
  missing_from_data <- character()
  if (!is.null(data_names)) {
    missing_from_data <- setdiff(assessed$variable, data_names)
  }
  data.frame(
    check = c(
      "required_columns", "one_row_per_variable", "declared_roles_allowed",
      "baseline_temporal_role_consistent", "boolean_flags_valid",
      "declared_variables_present_in_data"
    ),
    pass = c(
      TRUE, !length(duplicate_variables), !length(invalid_roles),
      !any(invalid_baseline_time),
      !any(invalid_model_flag) && !any(invalid_impute_flag),
      is.null(data_names) || !length(missing_from_data)
    ),
    evidence = c(
      paste(required, collapse = "|"),
      if (length(duplicate_variables)) paste(duplicate_variables, collapse = "|") else "unique",
      if (length(invalid_roles)) paste(invalid_roles, collapse = "|") else "allowed",
      if (any(invalid_baseline_time)) paste(assessed$variable[invalid_baseline_time], collapse = "|") else "consistent",
      if (any(invalid_model_flag) || any(invalid_impute_flag)) "invalid TRUE/FALSE value" else "valid",
      if (length(missing_from_data)) paste(missing_from_data, collapse = "|") else "present_or_not_checked"
    ),
    stringsAsFactors = FALSE
  )
}

validate_spec_dictionary_alignment <- function(spec, dictionary,
                                               profile = NULL) {
  analysis <- select_analysis_definition(spec, profile)
  role_map <- list(
    population_id = analysis$population$id,
    cluster_id = analysis$population$cluster_id,
    eligibility = analysis$population$eligibility_variables,
    time = analysis$time_zero$variable,
    treatment = analysis$treatment$variable,
    outcome = analysis$outcome$variable,
    baseline_confounder = analysis$baseline_confounders,
    time_varying_confounder = analysis$time_varying_confounders
  )
  role_map <- role_map[vapply(role_map, function(x) {
    length(x) && !all(vapply(as.list(x), tte_is_placeholder, logical(1)))
  }, logical(1))]
  checks <- lapply(names(role_map), function(role) {
    variable <- as.character(role_map[[role]])
    variable <- variable[!vapply(as.list(variable), tte_is_placeholder, logical(1))]
    actual <- dictionary$role[match(variable, dictionary$variable)]
    aligned <- length(variable) > 0L && !anyNA(actual) && all(actual == role)
    data.frame(
      check = paste0("role_alignment_", role),
      pass = aligned,
      evidence = paste0(
        paste(variable, collapse = "|"), ": expected=", role,
        "; declared=", paste(actual, collapse = "|")),
      stringsAsFactors = FALSE
    )
  })
  if (!length(checks)) {
    return(data.frame(
      check = "role_alignment", pass = TRUE,
      evidence = "no resolved role mappings in template mode",
      stringsAsFactors = FALSE
    ))
  }
  do.call(rbind, checks)
}

validate_input_data_contract <- function(contract) {
  required <- c(
    "dataset_id", "relative_path", "format", "analysis_unit", "required",
    "primary_key", "time_structure", "contains_patient_level_rows",
    "expected_columns", "sha256", "approved_by", "notes"
  )
  missing <- setdiff(required, names(contract))
  if (length(missing)) {
    stop("Input data contract is missing columns: ", paste(missing, collapse = ", "))
  }
  paths <- gsub("\\\\", "/", contract$relative_path)
  absolute <- grepl("^[A-Za-z]:/|^/", paths)
  traversal <- grepl("(^|/)[.][.](/|$)", paths)
  sql_like <- grepl("[.](sql|db|sqlite)$", paths, ignore.case = TRUE) |
    tolower(contract$format) %in% c("sql", "database", "sqlite")
  outside_private <- !startsWith(paths, "input/private/")
  duplicate_dataset <- duplicated(contract$dataset_id) |
    duplicated(contract$dataset_id, fromLast = TRUE)
  invalid_format <- tolower(contract$format) != "csv"
  invalid_required <- !toupper(as.character(contract$required)) %in%
    c("TRUE", "FALSE")
  invalid_patient_flag <-
    !toupper(as.character(contract$contains_patient_level_rows)) %in%
      c("TRUE", "FALSE")
  required_rows <- toupper(as.character(contract$required)) == "TRUE"
  missing_primary_key <- required_rows & !nzchar(trimws(contract$primary_key))
  data.frame(
    check = c(
      "dataset_ids_unique", "relative_paths_only", "no_path_traversal",
      "csv_inputs_only", "no_sql_or_database_input",
      "contract_boolean_fields_valid", "required_primary_keys_declared",
      "patient_level_files_are_private"
    ),
    pass = c(
      !any(duplicate_dataset), !any(absolute), !any(traversal),
      !any(invalid_format), !any(sql_like),
      !any(invalid_required) && !any(invalid_patient_flag),
      !any(missing_primary_key), !any(outside_private)
    ),
    evidence = c(
      if (any(duplicate_dataset)) paste(unique(contract$dataset_id[duplicate_dataset]), collapse = "|") else "unique",
      if (any(absolute)) paste(paths[absolute], collapse = "|") else "relative",
      if (any(traversal)) "parent-directory traversal detected" else "none",
      if (any(invalid_format)) paste(unique(contract$format[invalid_format]), collapse = "|") else "csv",
      if (any(sql_like)) paste(paths[sql_like], collapse = "|") else "CSV/file inputs only",
      if (any(invalid_required) || any(invalid_patient_flag)) "invalid TRUE/FALSE value" else "valid",
      if (any(missing_primary_key)) paste(contract$dataset_id[missing_primary_key], collapse = "|") else "declared",
      if (any(outside_private)) paste(paths[outside_private], collapse = "|") else "input/private"
    ),
    stringsAsFactors = FALSE
  )
}

ensure_tte_output_tree <- function(root = "output") {
  subdirs <- c("diagnostics", "tables", "figures", "sensitivity", "internal", "logs")
  paths <- file.path(root, subdirs)
  invisible(vapply(
    paths, dir.create, logical(1), recursive = TRUE, showWarnings = FALSE
  ))
  paths
}

validate_runtime_contract_files <- function(
    analysis_spec_path = "config/analysis_spec.yml",
    variable_dictionary_path = "config/variable_dictionary.csv",
    input_contract_path = "config/input_data_contract.csv",
    profile = NULL, execution_mode = "TEMPLATE", data_names = NULL) {
  spec <- read_analysis_spec(analysis_spec_path)
  dictionary <- read_variable_dictionary(variable_dictionary_path)
  input_contract <- utils::read.csv(
    input_contract_path, check.names = FALSE, stringsAsFactors = FALSE,
    na.strings = character()
  )
  checks <- rbind(
    validate_analysis_spec(spec, profile, execution_mode),
    validate_variable_dictionary(
      dictionary, data_names,
      allow_template_row = toupper(execution_mode) == "TEMPLATE"
    ),
    validate_spec_dictionary_alignment(spec, dictionary, profile),
    validate_input_data_contract(input_contract)
  )
  if (any(!checks$pass)) {
    stop("Unified runtime contract validation failed: ",
         paste(checks$check[!checks$pass], collapse = ", "))
  }
  checks
}
