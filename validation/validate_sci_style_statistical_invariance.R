# Use the unchanged public regression runner, frozen expected values/tolerance,
# and independent formulas. This wrapper retains this candidate's evidence.
source("validation/run_public_numerical_regression.R")
stopifnot(all(result$status == "PASS"),
          all(independent_baseline$status == "PASS"),
          all(independent_mi$status == "PASS"))
tte_write_csv(result, "reports/sci_style_numerical_regression.csv")
independent_baseline$profile <- "BASELINE_BINARY_RISK"
independent_mi$profile <- "MI_PS_CONTINUOUS_ATE"
tte_write_csv(tte_bind_rows_fill(independent_baseline, independent_mi),
              "reports/sci_style_independent_validation.csv")
cat("SCI_STATISTICAL_INVARIANCE=PASS NUMERICAL_CHECKS=", nrow(result),
    " INDEPENDENT_CHECKS=", nrow(independent_baseline) + nrow(independent_mi), "\n", sep = "")
