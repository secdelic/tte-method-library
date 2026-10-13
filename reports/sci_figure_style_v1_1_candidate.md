# SCI Figure Style v1.1 Candidate

Date: 2026-10-13. Branch: `feature/sci-figure-style-v1.1`.
Base: latest fetched public `main`, `56c6314689aee66b2de588ac773c8770ca5be346`.
Original style: immutable `v1.0.0` commit
`998e3c0a83656eae5e3ee8dae909e2edcd2625ec`.
Stable software metadata/version remains v1.0.0. This is a visual candidate.

## Changes and boundaries

`tte_theme_publication()` uses a white classic/minimal hybrid, charcoal text,
subtle axes/grid, bottom legends, and no panel box. Native figures already
omit redundant titles; gallery titles remain outside the images.
`tte_sci_colors()` and `tte_sci_palette()` provide semantic and categorical
colors; `tte_journal_palette()` remains a compatible palette accessor.
`tte_sci_group_colors()` gives known labels semantic colors and arbitrary
labels deterministic categorical colors without inferring scientific roles.

All native constructors received only display changes: `plot_cohort_flow`,
`plot_missingness`, `plot_propensity_score_distribution`,
`plot_weight_distribution`, `plot_love`, `plot_standardized_balance`,
`plot_forest`, `plot_survival_risk`, `plot_cumulative_incidence` (via the
shared curve constructor), `plot_sensitivity_forest`,
`plot_ccw_strategy_schematic`, and `plot_lmtp_policy`.
Changes include monochrome bars, consistent balance-stage colors,
restrained reference lines, uniform forests, subtle ribbons, explicit
Primary highlighting, line-shaped density legend keys, and CCW status text.
The template and two example figure configs declare the same candidate palette.

No estimand, estimator, numerical input/output, weighting, imputation,
effect measure, production registry, module readiness, input contract,
statistical fixture or expected statistical value has been modified.
The export/QC approval functions are unchanged.

## Old and new colors

| Use | v1.0.0 | v1.1 Candidate |
| --- | --- | --- |
| Categorical palette | `#0072B2 #D55E00 #009E73 #CC79A7 #000000` | `#355C7D #AD6058 #5B8E7D #C49A5A #687780 #30383F` |
| Binary control/treatment | Positional blue/orange | Semantic slate/navy |
| Unweighted/Weighted | Orange/blue (Love); positional (balance) | Terracotta/navy in both |
| Forest estimate/CI | Black | Navy; sensitivity rows slate |
| CCW Grace/Follow-up | Orange/blue | Gold/navy plus text |
| LMTP Observed/Policy | Black/blue | Charcoal/navy |

The proposed terracotta was adjusted from `#B5655D` to `#AD6058` after
text/background contrast review. See the [accessibility report](sci_palette_accessibility_validation.md).

## Gallery, formats and typography

All 14 requested native figure variants rendered successfully using the
unchanged v1.0.0 synthetic fixtures and fixed seed 20260809.
The [gallery](../figure_gallery/README.md) contains both requested widths
and all four formats: 14 x 2 x 4 = 112 candidate files.
The [comparison](../figure_style_comparison/README.md) contains 14 original/
candidate PNG pairs, with the same data, physical-width request and DPI.
The [comparison manifest](../figure_style_comparison/figure_style_comparison_manifest.csv)
and [coordinate equality record](../figure_gallery/figure_data_invariance.csv)
show exact equality of plot data and all common native layer coordinates,
including density calculations and confidence ribbons.

Actual-file checks in [export validation](../figure_gallery/export_validation.csv):

- PNG and TIFF: 600 DPI, 2007/4204 px width, 2598 px height; pixel-identical pairs.
- PDF and SVG: vector content; 28 PDFs and 28 SVGs rendered for display review.
- Requests: 85/178 mm wide, 110 mm high, unchanged from the native gallery setup.
- R vector canvas rounding: measured 84.667/177.800 mm wide, 109.714 mm high;
  errors below one PostScript point (0.353 mm), also present in v1.0.0.
  This is reported explicitly, not represented as exact physical equality.
- Base text: 8 pt. Actual candidate PDF text is at least 7 pt, including
  rotated axis titles checked with their perpendicular text extent.
- SVG fonts are outlined glyphs; font sizes are checked in the native plot
  specification and parallel PDF, with SVG rendering checked visually.
- Axis strokes: 0.45 pt. ggplot geometry: curves 0.7 mm, CI 0.55 mm,
  reference lines 0.4 mm, forest points 2.2 mm. No decorative heavy frame.

No outside-page PDF text, obvious clipping or overlap was observed in the
reviewed native fixtures. This is AI-assisted display inspection, not human
publication approval. Native QC keeps clipping/overlap/grayscale human-review
fields pending. Review reference-line subtlety, ribbons, real-data label
lengths and final reduction before adoption.

## Statistical invariance

The unchanged public regression runner passed 14 frozen numerical checks
for `BASELINE_BINARY_RISK` and `MI_PS_CONTINUOUS_ATE`, tolerance `1e-8`.
Maximum difference was `5.32907051820075e-15`.
[Candidate regression results](sci_style_numerical_regression.csv).
Independent baseline and MI formulas passed all 11 checks at their unchanged
`1e-7` tolerances. [Independent results](sci_style_independent_validation.csv).
The four existing test scripts passed; the targeted publication-figure test
also passed after the final legend adjustment. Synthetic production Quick
Start passed. Expected files and statistical source paths remain unchanged.
Metadata, documentation links, R parsing, public privacy/secret scans and the
synthetic aggregate release dry run also passed. On this Windows host the
pre-existing `C.UTF-8` startup locale is unavailable; the privacy scan was
executed with a process-local `LC_CTYPE=Chinese_China.utf8` and UTF-8 source
reading. No global locale or validation source was changed.

## Review and final state

AI assistance covered style/code implementation, synthetic rendering,
technical validation and display inspection. It was not limited to language
editing. No real patient data or study-specific scientific result was used.
Investigator visual adoption and real-study publication approval are pending.
Every candidate QC row has `publication_ready=FALSE`, `manual_review=PENDING`.
The [final surface audit](sci_style_final_external_surface_audit.md) covers
all changed deliverables and reports its read/metadata/watermark limits as
`PARTIAL_UNCHECKED`; no file-surface finding awaits removal authorization.

The draft PR is solely for human visual review; it must not be automatically
merged or released. The `v1.0.0` tag is unchanged. No Release is created.

`SCI_FIGURE_STYLE_V1_1_CANDIDATE_READY_FOR_VISUAL_REVIEW`

Reproduction commands (from repository root):

```text
Rscript tests/run_tests.R
Rscript validation/validate_sci_style_statistical_invariance.R
Rscript figure_gallery/render_all_native_figures.R
Rscript validation/validate_sci_style_accessibility.R
python validation/validate_sci_style_exports.py
```

The last two development checks use `colorspace`, `magick`, `rsvg`, Pillow,
pdfplumber, pypdf and Poppler; they are not new runtime dependencies or
changes to the statistical environment lockfile.
