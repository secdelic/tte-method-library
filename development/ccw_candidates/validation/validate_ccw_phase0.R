# Read-only PHASE 0 handoff checks, not a statistical validator or execution gate.
# No analysis-ready input, runtime loading, model fitting or authority mutation.
if (.Platform$OS.type == "windows") Sys.setlocale("LC_CTYPE", ".UTF-8")
if (!requireNamespace("yaml", quietly = TRUE)) stop("Existing yaml package is required")

base <- "b595a938c88e535b0cb12e56dfc0558b309b8c61"
pending <- "HUMAN_SCIENTIFIC_DECISION_REQUIRED"
read_utf8 <- function(path) paste(readLines(path, encoding = "UTF-8", warn = TRUE), collapse = "\n")
authority_path <- "governance/CCW_SCIENTIFIC_AUTHORITY_V1.yml"
authority <- yaml::yaml.load(read_utf8(authority_path))
stopifnot(
  identical(authority$authority_id, "CCW_SCIENTIFIC_AUTHORITY_V1"),
  identical(authority$status, "CCW_SCIENTIFIC_AUTHORITY_AWAITING_HUMAN_APPROVAL"),
  identical(authority$scientific_fields_frozen, FALSE),
  identical(authority$implementation_authorized, FALSE),
  identical(authority$production_authorized, FALSE),
  identical(authority$task_constraints$bootstrap_resampling_unit, "original_subject"),
  identical(authority$task_constraints$bootstrap_refit_all_required_models, TRUE),
  identical(authority$task_constraints$fixed_weight_bootstrap_equivalence_claim_allowed, FALSE)
)
decisions <- authority$scientific_decisions
stopifnot(length(decisions) == 28L, all(vapply(decisions, function(x) identical(x$status, pending), logical(1))))
paths <- unlist(lapply(names(decisions), function(group) {
  values <- decisions[[group]]$values
  stopifnot(length(values) > 0L, all(vapply(values, function(x) identical(x, pending), logical(1))))
  paste("scientific_decisions", group, "values", names(values), sep = ".")
}), use.names = FALSE)
stopifnot(length(paths) == 86L, !anyDuplicated(paths), length(authority$approval) == 7L,
          all(vapply(authority$approval, function(x) identical(x, pending), logical(1))))

deliverables <- c(
  "reports/ccw_historical_validation_recovery.md",
  "governance/ccw_existing_evidence_registry.csv",
  "docs/ccw/CCW_SCIENTIFIC_DECISION_PACKET_V1.md",
  "docs/ccw/ccw_generic_validation_profile_candidates.md",
  "docs/ccw/ccw_scientific_decision_dependency_graph.md",
  "reports/ccw_parity_implementation_backlog.csv",
  "reports/ccw_phase0_readiness.md",
  "reports/CCW_JAR_METHOD_PARITY_FINAL_MATRIX.md",
  "docs/ccw/ccw_phase0_interface_contract.md",
  "validation/validate_ccw_phase0.R"
)
stopifnot(all(file.exists(deliverables)))
contents <- vapply(deliverables, read_utf8, character(1))
stopifnot(all(nzchar(contents)),
          !grepl("VALIDATION_RESULTS_PLACEHOLDER", read_utf8("reports/ccw_phase0_readiness.md"), fixed = TRUE))
packet <- read_utf8("docs/ccw/CCW_SCIENTIFIC_DECISION_PACKET_V1.md")
packet_rows <- strsplit(packet, "\n", fixed = TRUE)[[1]]
packet_rows <- packet_rows[grepl("^\\| V[0-9]{3} \\|", packet_rows)]
stopifnot(length(packet_rows) == 86L)
for (path in paths) {
  stopifnot(sum(grepl(paste0("`", path, "`"), packet_rows, fixed = TRUE)) == 1L)
}
stopifnot(all(grepl(pending, packet_rows, fixed = TRUE)))

read_csv <- function(path) {
  table <- utils::read.csv(path, fileEncoding = "UTF-8", stringsAsFactors = FALSE,
                           check.names = FALSE, na.strings = character())
  stopifnot(nrow(table) > 0L, !anyNA(table), all(vapply(table, function(x) all(nzchar(as.character(x))), logical(1))))
  table
}
evidence <- read_csv("governance/ccw_existing_evidence_registry.csv")
stopifnot(nrow(evidence) == 20L, !anyDuplicated(evidence$evidence_id),
          all(evidence$recovered_executable_implementation == "NO"),
          all(evidence$numerically_reproduced_this_phase == "NOT_RUN"))
historical <- evidence[grepl("^H", evidence$evidence_id), ]
stopifnot(nrow(historical) == 8L,
          historical$evidence_status[historical$evidence_id == "H00"] == "NOT_AVAILABLE",
          historical$sha256[historical$evidence_id == "H00"] == "NOT_AVAILABLE",
          historical$evidence_status[historical$evidence_id == "H07"] == "UNRESOLVED")
for (column in c("dgp", "true_effects", "bias", "se_ratio", "coverage", "ci_method",
                 "bootstrap_refitting", "failed_frozen_gates", "before_after_difference")) {
  stopifnot(all(historical[[column]] == "UNKNOWN"))
}
identified <- evidence[evidence$evidence_class == "VERIFIED_CURRENT_SOURCE_IDENTITY", ]
stopifnot(nrow(identified) == 10L, all(grepl("^[a-f0-9]{64}$", identified$sha256)))

backlog <- read_csv("reports/ccw_parity_implementation_backlog.csv")
stopifnot(!anyDuplicated(backlog$task_id), all(backlog$production_authorized == "FALSE"),
          all(backlog$statistical_execution_this_phase == "NOT_RUN"),
          all(backlog$status[backlog$phase != 0L] == "BLOCKED_HUMAN_SCIENTIFIC_FREEZE"))
for (i in seq_len(nrow(backlog))) {
  groups <- strsplit(backlog$authority_groups[i], "|", fixed = TRUE)[[1]]
  stopifnot(all(groups == "NOT_APPLICABLE" | groups %in% names(decisions)))
  dependencies <- strsplit(backlog$depends_on[i], "|", fixed = TRUE)[[1]]
  stopifnot(all(dependencies == "NONE" | dependencies %in% backlog$task_id),
            !backlog$task_id[i] %in% dependencies)
  if (!identical(dependencies, "NONE")) {
    stopifnot(all(match(dependencies, backlog$task_id) < i))
  }
}
stopifnot(all(sprintf("P3-S%02d", 1:14) %in% backlog$task_id))
matrix <- read_csv("reports/ccw_benchmark_methods_matrix.csv")
gates <- read_csv("reports/ccw_production_gate_checklist.csv")
stopifnot(nrow(matrix) == 22L, nrow(gates) == 18L)
for (ids in backlog$benchmark_capability_ids) {
  values <- strsplit(ids, "|", fixed = TRUE)[[1]]
  stopifnot(all(values == "NOT_APPLICABLE" | values %in% matrix$capability_id))
}
parity <- strsplit(read_utf8("reports/CCW_JAR_METHOD_PARITY_FINAL_MATRIX.md"), "\n", fixed = TRUE)[[1]]
stopifnot(sum(grepl("^\\| M[0-9]{2} /", parity)) == 22L)
scenarios <- read_utf8("docs/ccw/ccw_known_truth_simulation_plan.md")
stopifnot(all(vapply(sprintf("| S%02d |", 1:14), function(x) grepl(x, scenarios, fixed = TRUE), logical(1))))

# Compare inherited tracked content to the selected PR #4 commit. No mutation.
inherited <- c(authority_path,
  "docs/ccw/ccw_implementation_architecture.md", "docs/ccw/ccw_input_contract.md",
  "docs/ccw/ccw_validation_protocol.md", "docs/ccw/ccw_independent_comparator_plan.md",
  "docs/ccw/ccw_known_truth_simulation_plan.md", "reports/ccw_benchmark_methods_matrix.csv",
  "reports/ccw_production_gate_checklist.csv", "reports/ccw_readiness_report.md")
if (system2("git", c("diff", "--exit-code", base, "--", inherited)) != 0L) {
  stop("Inherited PR4 files differ; this PHASE 0 check requires review")
}
registry <- read_csv("runtime/production_registry.csv")
stopifnot(identical(registry$profile, c("BASELINE_BINARY_RISK", "MI_PS_CONTINUOUS_ATE")))

cat("CCW_PHASE0_STRUCTURE=PASS; GROUPS=28; VALUES=86; APPROVAL_FIELDS_PENDING=7\n")
cat("EVIDENCE_ROWS=20; INHERITED_FILES_UNCHANGED=9; CAPABILITIES=22; GATES=18; SCENARIOS=14\n")
cat("DELIVERABLES=10; CCW_STATISTICAL_EXECUTION=NOT_RUN; SCIENTIFIC_APPROVAL=PENDING\n")
