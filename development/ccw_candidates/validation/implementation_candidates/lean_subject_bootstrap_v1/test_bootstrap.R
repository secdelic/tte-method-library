source("bootstrap.R")
root <- normalizePath("../../..", winslash="/", mustWork=TRUE)
contract <- jsonlite::read_json("inputs/development_contract.json")
engine <- load_frozen_core(root, contract)
args <- commandArgs(trailingOnly=TRUE)
out <- if (length(args)) args[[1]] else "results/deterministic_001"
if (dir.exists(out)) stop("REFUSE_OVERWRITE_TEST_ATTEMPT")
dir.create(out, recursive=TRUE)
checks <- list()
check <- function(label, value) {
  checks[[length(checks)+1L]] <<- list(test=label, pass=isTRUE(value))
  if (!isTRUE(value)) stop("TEST_FAILED: ", label)
}
rejects <- function(expr) inherits(tryCatch({force(expr); NULL}, error=function(e)e), "error")
near <- function(x,y) identical(unname(is.na(x)),unname(is.na(y))) &&
  all(abs(x[!is.na(y)]-y[!is.na(y)])<=1e-12+1e-10*abs(y[!is.na(y)]))
number <- function(v) if (is.null(v)) NA_real_ else if (is.list(v) &&
  all(c("numerator","denominator") %in% names(v))) v$numerator/v$denominator else as.numeric(v)
toy_estimates <- function(e,d) {
  values <- c(R_E=e,R_D=d,RD=e-d,RR=if (d>0) e/d else NA_real_)
  setNames(lapply(estimand_names, function(id) list(value=unname(values[[id]]),
    point_status=if (is.finite(values[[id]])) "ESTIMABLE_INTERIOR" else "NONESTIMABLE_ZERO_REFERENCE",
    availability=if (is.finite(values[[id]])) "AVAILABLE" else "SCIENTIFIC_NONESTIMABLE",
    ci_eligible=if (id=="R_E") e>0&&e<1 else if (id=="R_D") d>0&&d<1
      else e>0&&e<1&&d>0&&d<1, failed_stage=NULL, reasons=list())), estimand_names)
}
failure <- NULL
tryCatch({
  check("B1000_execution_refused_before_RNG",
    rejects(validate_canary_request(contract,1000,contract$source_file)))
  check("B21_execution_refused_before_RNG",
    rejects(validate_canary_request(contract,21,contract$source_file)))
  check("clinical_or_unsealed_input_refused",
    rejects(validate_canary_request(contract,20,"unapproved_patient_input.json")))
  check("canary_inference_request_refused",
    rejects(validate_canary_request(contract,20,contract$source_file,TRUE)))
  fixtures <- jsonlite::read_json(file.path(root,
    "validation/implementation_candidates/gv_oracle_minimal_core_v1/inputs/small_fixtures.json"))$cases
  expected <- jsonlite::read_json(file.path(root,
    "validation/implementation_candidates/gv_oracle_minimal_core_v1/inputs/independent_expected.json"))$cases
  selected <- c("HAND_LEDGER_MAIN","NONUNIFORM_MULTIPLICITY","NO_EVENT_LEGAL",
    "ABSORBED_AT_1","E_EMPTY_RISKSET_D_LEGAL","ZERO_REFERENCE_SAMPLE",
    "ZERO_NUMERATOR_SAMPLE","SHARED_FIT_FAILURE","E_LOCAL_MODEL_FAILURE_D_VALID",
    "OPTIONAL_DIAGNOSTIC_FAILURE")
  sealed <- list()
  for (cid in selected) {
    case <- Filter(function(x) x$case_id==cid, fixtures)[[1L]]
    idx <- as.integer(rep(seq_along(case$subjects), unlist(case$multiplicity)))
    for (mode in c("KNOWN","Q_SAT")) {
      actual <- refit_subject_draw(case,idx,engine,mode)
      ref <- expected[[cid]][[mode]]
      for (nm in names(ref$components)) {
        check(paste(cid,mode,nm,"sealed_point"),
          near(actual$components[[nm]]$value, number(ref$components[[nm]]$value)))
        check(paste(cid,mode,nm,"sealed_status"),
          identical(actual$components[[nm]]$source_status,ref$components[[nm]]$source_status))
      }
      for (cell in names(ref$P_counts))
        check(paste(cid,mode,cell,"original_P_counts"),
          identical(as.numeric(unlist(actual$P_counts[[cell]][c("n","d")])),
                    as.numeric(unlist(ref$P_counts[[cell]][c("n","d")]))))
      record <- list(case_id=cid,mode=mode,indices=as.list(idx),
                     result=actual,estimates=extract_estimates(actual))
      sealed[[paste(cid,mode,sep="_")]] <- record
    }
  }
  write_json_new(sealed,file.path(out,"sealed_boundary_results.json"))
  main <- Filter(function(x)x$case_id=="HAND_LEDGER_MAIN",fixtures)[[1L]]
  validate_source(main,engine)
  check("ordered_index_length_rejected", rejects(refit_subject_draw(main,1:7,engine)))
  check("out_of_range_index_rejected", rejects(refit_subject_draw(main,c(1:7,9L),engine)))
  check("noninteger_indices_rejected", rejects(refit_subject_draw(main,as.numeric(1:8),engine)))
  duplicate <- main;duplicate$subjects[[2]]$original_id<-duplicate$subjects[[1]]$original_id
  check("multiple_units_rejected",rejects(validate_source(duplicate,engine)))
  ineligible <- Filter(function(x)x$case_id=="BASELINE_EXCLUSIONS",fixtures)[[1L]]
  check("no_silent_baseline_exclusion",rejects(validate_source(ineligible,engine)))
  weighted <- sealed$NONUNIFORM_MULTIPLICITY_Q_SAT$result
  base <- sealed$HAND_LEDGER_MAIN_Q_SAT$result
  check("multiplicity_changes_refitted_P_counts",!identical(base$P_counts,weighted$P_counts))
  check("paired_contrast_from_same_draw",near(weighted$contrasts$RD$value,
    weighted$components$E_PL$value-weighted$components$D_PL$value))
  local <- sealed$E_LOCAL_MODEL_FAILURE_D_VALID_Q_SAT$estimates
  check("local_E_failure_preserves_D",local$R_E$availability=="EXECUTION_UNAVAILABLE" &&
    local$R_D$availability=="AVAILABLE" && local$RD$availability=="EXECUTION_UNAVAILABLE")
  shared <- sealed$SHARED_FIT_FAILURE_Q_SAT$estimates
  check("shared_failure_reaches_consumers",
    all(vapply(shared,function(x)x$availability=="EXECUTION_UNAVAILABLE",TRUE)))
  diag <- sealed$OPTIONAL_DIAGNOSTIC_FAILURE_KNOWN$estimates
  check("optional_diagnostic_does_not_cancel_points",
    all(vapply(diag,function(x)x$availability=="AVAILABLE",TRUE)))
  check("compact_requires_independent_gate",rejects(compact_result(base,FALSE)))

  # New arithmetic fixtures are neither data analyses nor bootstrap draws.
  ids <- sprintf("T%03d",1:40)
  records <- setNames(lapply(seq_along(ids),function(i)
    list(id=ids[i],state="COMPLETED",estimates=toy_estimates(.2+i/100,.8-i/150))),ids)
  original <- toy_estimates(.5,.4)
  arithmetic <- aggregate_bootstrap(original,records,ids,TRUE)
  check("CI_type1_R_E_rank",near(unlist(arithmetic$estimands$R_E$CI),c(.21,.59)))
  rr <- vapply(records,function(x)x$estimates$RR$value,0.0)
  check("RR_log_then_exp_type1",near(unlist(arithmetic$estimands$RR$CI),
                                   exp(log(sort(rr)[c(1,39)]))))
  check("zero_RD_unit_RR_are_allowed",all(vapply(toy_estimates(.5,.5),`[[`,TRUE,"ci_eligible")))
  canary <- aggregate_bootstrap(original,records,ids,FALSE)
  check("canary_no_intervals_or_covariance",
    all(vapply(canary$estimands,function(x)all(is.na(unlist(x$CI))),TRUE)) &&
      is.null(canary$covariance$value) && !canary$formal_CI_computed && !canary$formal_SE_computed)
  onebad <- records
  onebad[[3]]$state <- "PARTIALLY_FAILED"
  for (id in c("R_E","RD","RR")) onebad[[3]]$estimates[[id]] <-
    unavailable_estimates("NUISANCE_E_SPECIFIC","CONTROLLED_TEST_FAILURE")[[id]]
  partial <- aggregate_bootstrap(original,onebad,ids,TRUE)
  check("local_failure_only_blocks_affected_CI",
    !partial$estimands$R_E$CI_qualified && partial$estimands$R_D$CI_qualified &&
      !partial$estimands$RD$CI_qualified && !partial$estimands$RR$CI_qualified)
  check("successful_subset_CI_forbidden",all(is.na(unlist(partial$estimands$R_E$CI))))
  check("incomplete_covariance_descriptive",
    partial$covariance$status=="DETERMINISTIC_TEST_DESCRIPTIVE_INCOMPLETE_COMMON_DRAWS")
  for (pair in list(c(0,.4),c(.3,0),c(0,0),c(1,.4),c(.3,1))) {
    obs <- toy_estimates(pair[1],pair[2])
    boundary <- aggregate_bootstrap(obs,records,ids,TRUE)
    check(paste("boundary_original_policy",paste(pair,collapse="_")),
      !boundary$estimands$RR$CI_qualified && !boundary$estimands$RD$CI_qualified)
  }
  badmath <- records
  badmath[[2]]$estimates$RR$value <- Inf
  fail_ci <- aggregate_bootstrap(original,badmath,ids,TRUE)
  check("aggregation_failure_local",fail_ci$estimands$RR$CI_status=="UNAVAILABLE_AGGREGATION_FAILURE" &&
    fail_ci$estimands$R_E$CI_qualified && identical(fail_ci$estimands$RR$point,original$RR))
  check("type1_not_default_type7",
    identical(type1_interval(1:1000),c(25,975)) &&
    !identical(type1_interval(1:1000),as.numeric(quantile(1:1000,c(.025,.975),type=7))))
  check("B2000_arithmetic_ranks",identical(type1_interval(1:2000),c(50,1950)))
  check("record_order_mismatch_rejected",rejects(aggregate_bootstrap(original,records[40:1],ids)))
  events <- list()
  schedule <- run_schedule(c("S1","S2","S3"),function(id) {
    if (id=="S2") stop("CONTROLLED_TECHNICAL_FAULT")
    warning("CONTROLLED_WARNING")
    list(estimates=original,evidence=list(kind="DETERMINISTIC_TEST"))
  },function(x)events[[length(events)+1L]]<<-x)
  check("technical_failure_stops_without_retry",
    identical(vapply(schedule,`[[`,"","state"),c(S1="COMPLETED",S2="FAILED",S3="NOT_STARTED")))
  check("actual_warning_retained",identical(schedule$S1$warnings,list("CONTROLLED_WARNING")))
  counted <- aggregate_bootstrap(original,schedule,names(schedule),TRUE)
  check("failure_accounting",counted$accounting$requested==3L &&
    counted$accounting$attempted==2L && counted$accounting$failed==1L &&
    counted$accounting$not_started==1L)
  interrupted <- run_schedule(c("I1","I2"),function(id)
    stop(structure(list(message="CONTROLLED_INTERRUPT",call=NULL),
                   class=c("interrupt","condition"))))
  check("interrupt_closure",interrupted$I1$state=="ABORTED" &&
        interrupted$I2$state=="NOT_STARTED")
  staged_fault <- run_schedule("F1",function(id) {
    e <- simpleError("CONTROLLED_STAGE_FAULT")
    e$failed_stage <- "FULL_REFIT"
    stop(e)
  })
  check("technical_failed_stage_preserved",
    staged_fault$F1$error$failed_stage=="FULL_REFIT" &&
    staged_fault$F1$estimates$R_E$failed_stage=="FULL_REFIT")
  write_json_new(list(kind="DETERMINISTIC_ARITHMETIC_NOT_BOOTSTRAP",
    original=original,records=records,summary=arithmetic,
    partial_records=onebad,partial_summary=partial),
    file.path(out,"arithmetic_fixtures_and_results.json"))
  write_json_new(list(controlled_fault=schedule,events=events,
    controlled_interrupt=interrupted,controlled_stage_fault=staged_fault,actual_canary_fault=FALSE),
    file.path(out,"scheduler_fault_tests.json"))

  # Prespecified nonrandom source/map pair for the independent retention gate.
  source <- jsonlite::read_json(file.path(root,contract$source_file))
  validate_source(source,engine)
  idx <- as.integer(rep(seq(1L,999L,by=2L),each=2L))
  gate <- list(source_file=contract$source_file,source_sha256=contract$source_sha256,
               mode="Q_SAT",indices=as.list(idx),
               result=refit_subject_draw(source,idx,engine,"Q_SAT"))
  write_json_new(gate,file.path(out,"retention_probe_full.json"))
}, error=function(e)failure<<-e)
write_json_new(list(status=if(is.null(failure))"PASS" else "FAIL",
  tests=checks,count=length(checks),error=if(is.null(failure))NULL else conditionMessage(failure),
  deterministic_only=TRUE,random_bootstrap_draws=0L,formal_CI_computed=FALSE),
  file.path(out,"TEST_RESULTS.json"))
if (!is.null(failure)) stop(failure)
cat("Targeted deterministic checks passed:",length(checks),"; random draws=0; formal CI=FALSE\n")
