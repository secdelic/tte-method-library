# Publication figure guide

## Scope

The figure layer converts synthetic or non-identifying aggregate statistical
summaries into reproducible SCI-oriented figures. It does not estimate effects,
infer scientific meaning, create manuscript prose or choose journal-specific
claims. Decorative AI-style illustration and automated visual approval are
`OUT_OF_SCOPE`.

The standard functions are implemented in
`R/figures/publication_figures.R` for cohort flow, missingness, propensity-score
and weight distributions, Love/standardized-balance plots, forest plots,
survival/risk curves, cumulative incidence, sensitivity forests, CCW strategy
schematics and LMTP policy plots.

Function availability is not evidence of estimator validity or module maturity.
The current formal runtime automatically adapts only its allowlisted aggregate
results; any other figure requires an appropriate validated statistical output
and manual review.

## Configuration

Copy `config_templates/figure_config.yml` to `config/figure_config.yml` and
freeze it with the analysis specification. The default contract requires:

- 85 mm single-column width;
- 178 mm double-column width;
- minimum font size of 7 pt;
- PDF/SVG vector output;
- TIFF/PNG raster output at 600 dpi;
- a journal-neutral, color-blind-safe palette;
- shape/linetype redundancy and grayscale compatibility;
- no 3D effects, decorative gradients or AI-style decoration.

A project may change dimensions to meet an official journal instruction, but
must record the source and freeze the change before formal rendering. Do not
select colors or scales to make an observed effect look stronger.

## Output location

All figures and their QC registry go only to:

```text
output/figures/
├─ <figure>.pdf or <figure>.svg
├─ <figure>.tiff or <figure>.png
└─ figure_qc.csv
```

The surrounding project output tree remains limited to
`diagnostics/`, `tables/`, `figures/`, `sensitivity/`, `internal/` and `logs/`.
Figures must use aggregate/model-summary data; identifiable patient-level
labels, IDs, trajectories or tooltips are prohibited.

## Required QC fields

`figure_qc.csv` contains:

```text
figure,width_mm,height_mm,dpi,minimum_font_pt,vector_output,
clipping,overlap,grayscale_pass,publication_ready,manual_review
```

Machine checks verify dimensions, files, vector output, minimum font and raster
resolution. They do not reliably determine clipping, overlap or grayscale
legibility. Therefore generated rows default to:

```text
publication_ready = FALSE
manual_review = PENDING
```

No script may set `publication_ready=TRUE` unless every machine-checkable item
passes. Final visual approval remains a human decision.

## Human visual review

Inspect the actual vector and 600-dpi raster files at their intended page size:

1. no clipped text, points, intervals or annotations;
2. no label, legend or panel overlap;
3. axes identify the statistic, time scale and units;
4. confidence intervals and null/reference lines remain visible;
5. line widths and point sizes survive reduction;
6. whitespace is sufficient but not excessive;
7. colors remain distinguishable under common color-vision deficiencies;
8. groups remain distinguishable in grayscale;
9. figure numbering and the frozen configuration agree;
10. no individual-level information can be recovered.

Record the review result in `figure_qc.csv`; do not encode interpretation,
Discussion language or publication claims in the figure-generation layer.

## SCI Figure Style v1.1 Candidate

This feature branch uses a classic/minimal hybrid with a white background,
charcoal text, subtle axes, and no panel box. `tte_sci_colors()` names treatment,
control, comparator, favorable, caution, neutral, text, and grid roles;
`tte_sci_palette()` supplies a restrained categorical palette.

Binary labels 0/1 map to control/treatment colors. Explicit control/reference/
treatment labels use the same roles. Arbitrary strategy labels receive
deterministic categorical colors; their names do not establish treatment roles.
Survival, risk, and cumulative incidence share this mapping. Existing input
contracts and supported group counts are unchanged; the reviewed fixtures use
two strategies. Review larger or differently labeled strategy sets separately.

Unweighted/Weighted use terracotta/navy with different shapes. Forest estimates
and intervals use navy; sensitivity rows use slate unless explicitly labeled
Primary. CCW statuses have semantic fills and repeated status text. LMTP uses
charcoal Observed and navy Policy, with linetype and shape redundancy.

Default text is 8 pt, with axes/legend labels at least 7 pt. Axis strokes are
0.45 pt. ggplot geometry units remain explicit: curve linewidth 0.7 mm,
CI linewidth 0.55 mm, reference linewidth 0.4 mm, forest point size 2.2 mm.
The legacy geometry configuration fields do not override constructor geometry.
Native R PDF/SVG devices quantize the requested 85/178 mm canvas to whole points;
the measured widths are 84.67/177.80 mm in this environment (less than 1 pt
rounding). No export or statistical contract has been relaxed.

See the [native gallery](../../figure_gallery/README.md),
[before/after pairs](../../figure_style_comparison/README.md), and
[accessibility results](../../reports/sci_palette_accessibility_validation.md).
The researcher confirmed the original style candidate's visual review PASS;
each study-specific export still requires human publication review.

## Additional publication information architecture

The separate v1.2 candidate provides six additional constructors/composers for
caller-supplied flow counts, schematic clone events, curves/risk tables and
subgroup effects. See the [publication capability guide](publication_capability_guide.md)
and [synthetic gallery](../../figure_gallery/publication_capability/README.md).
These utilities preserve the SCI style and export contract; they implement no
CCW, survival or competing-risk estimator.
