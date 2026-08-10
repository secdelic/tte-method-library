# Structural and temporal input checks for the two production profiles.

tte_validate_inputs <- function(data, dictionary, profile, configuration) {
  issues <- character()
  variable_col <- if ("variable_name" %in% names(dictionary)) "variable_name" else "variable"
  type_col <- if ("data_type" %in% names(dictionary)) "data_type" else "type"
  required <- if ("required" %in% names(dictionary)) {
    dictionary[[variable_col]][toupper(dictionary$required) == "TRUE"]
  } else {
    dictionary[[variable_col]]
  }
  missing_columns <- setdiff(required, names(data))
  if (length(missing_columns)) {
    return(list(
      pass = FALSE,
      issues = paste("missing columns:", paste(missing_columns, collapse = ",")),
      covariates = character()
    ))
  }
  for (id in c("subject_id", "analysis_id")) {
    if (anyNA(data[[id]]) || anyDuplicated(data[[id]])) {
      issues <- c(issues, paste(id, "must be nonmissing and unique"))
    }
  }
  if (anyNA(data$treatment) || !all(data$treatment %in% c(0, 1))) {
    issues <- c(issues, "treatment must be nonmissing binary 0/1")
  }
  time_fields <- c(
    "eligibility_time", "time_zero", "treatment_assignment_time",
    "followup_start", "followup_end"
  )
  parsed <- lapply(data[time_fields], tte_parse_iso_time)
  if (any(vapply(parsed, anyNA, logical(1)))) {
    issues <- c(issues, "all time fields must parse as ISO 8601 with timezone")
  } else {
    if (any(parsed$eligibility_time != parsed$time_zero)) {
      issues <- c(issues, "eligibility_time must equal time_zero")
    }
    if (any(parsed$treatment_assignment_time != parsed$time_zero)) {
      issues <- c(issues, "treatment_assignment_time must equal time_zero")
    }
    if (any(parsed$followup_start != parsed$time_zero)) {
      issues <- c(issues, "followup_start must equal time_zero")
    }
    if (any(parsed$followup_end <= parsed$followup_start)) {
      issues <- c(issues, "followup_end must be after followup_start")
    }
  }
  covariates <- if ("include_in_ps" %in% names(dictionary)) {
    dictionary[[variable_col]][toupper(dictionary$include_in_ps) == "TRUE"]
  } else {
    dictionary[[variable_col]][
      dictionary$role == "baseline_confounder" &
        toupper(dictionary$include_in_model) == "TRUE"
    ]
  }
  cov_rows <- dictionary[match(covariates, dictionary[[variable_col]]), , drop = FALSE]
  if (!length(covariates)) issues <- c(issues, "no approved propensity-score covariates")
  if (any(cov_rows$role != "baseline_confounder") ||
      any(!cov_rows$relation_to_time_zero %in% c("before", "at", "before_or_at_time_zero"))) {
    issues <- c(issues, "propensity-score variables must be baseline confounders available by time zero")
  }
  if (profile == "BASELINE_BINARY_RISK") {
    if (configuration$outcome_type != "binary" || anyNA(data$outcome) ||
        !all(data$outcome %in% c(0, 1))) {
      issues <- c(issues, "baseline binary profile requires nonmissing outcome 0/1")
    }
    if (anyNA(data[covariates])) {
      issues <- c(issues, "baseline binary profile prohibits missing propensity-score covariates")
    }
    if (!configuration$estimand %in% c("ATE", "ATO")) {
      issues <- c(issues, "baseline binary profile allows ATE or ATO only")
    }
  } else if (profile == "MI_PS_CONTINUOUS_ATE") {
    if (configuration$outcome_type != "continuous" || anyNA(data$outcome) ||
        !is.numeric(data$outcome)) {
      issues <- c(issues, "MI+PS profile requires a nonmissing continuous outcome")
    }
    if (configuration$estimand != "ATE") issues <- c(issues, "MI+PS profile allows ATE only")
    missing_covariates <- covariates[vapply(data[covariates], anyNA, logical(1))]
    allowed <- cov_rows[[variable_col]][
      toupper(cov_rows$impute) == "TRUE" & cov_rows$mice_method == "pmm" &
        cov_rows[[type_col]] %in% c("numeric", "double")
    ]
    bad <- setdiff(missing_covariates, allowed)
    if (length(bad)) {
      issues <- c(issues, paste(
        "missingness outside audited PMM numeric covariates:",
        paste(bad, collapse = ",")
      ))
    }
  } else {
    issues <- c(issues, paste("unsupported profile:", profile))
  }
  list(pass = !length(issues), issues = issues, covariates = covariates)
}
