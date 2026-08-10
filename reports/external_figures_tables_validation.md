# External Figure and Table Validation

`EXTERNAL_FIGURES_TABLES = PASS`

The anonymous clean clone generated the following from fixed-seed synthetic inputs:

- Table 1 in CSV and HTML, with unweighted and weighted summaries and SMD;
- main result table in CSV and HTML, including risks, RD, RR, standard errors and confidence intervals;
- a covariate-balance plot;
- difference-scale and ratio-scale forest plots;
- PDF and SVG vector outputs;
- PNG and TIFF raster outputs at 600 DPI.

All six raster files were readable and measured `2007 x 2598` pixels at `600 x 600` DPI. All six corresponding PDF/SVG vector files were present and non-empty. The public figure synthetic test generated 14 figure types in four formats and passed. The public table synthetic test generated Table 1, main-result and sensitivity tables and passed.

Visual inspection of the balance and difference-scale forest PNGs found no clipping, overlap or missing-glyph blocker. The warnings table was empty. `figure_qc.csv` correctly retained clipping and overlap as `PENDING_MANUAL_REVIEW`; machine validation did not falsely grant final study-specific visual approval.
