# SCI Figure Style v1.1 Candidate

Selected native documentation PNGs use the unchanged v1.0.0 synthetic fixtures. Full exports and simulations are regenerable; they are not permanent source assets.

The researcher confirmed visual PASS for the 14 cbc4424 variants at both requested widths on 2026-10-14. Study-specific publication approval remains pending.

See [visual audit](../reports/pr2_visual_audit.md), [retention audit](../reports/pr2_generated_asset_retention_audit.md), [before/after comparison](../figure_style_comparison/README.md), and [accessibility evidence](../reports/sci_palette_accessibility_validation.md).

Rebuild from repository root:

```text
Rscript figure_gallery/render_all_native_figures.R
Rscript validation/validate_sci_style_accessibility.R
python validation/validate_sci_style_exports.py
```

Full PDF/SVG/TIFF/PNG exports (both widths), original/candidate comparison pairs and CVD previews go under ignored `output/sci_style_gallery/`. Set `TTE_FIGURE_ASSET_ROOT` to choose another generation location. Only selected PNGs and small summary evidence are retained here.

## 01 cohort flow

![Candidate 01 cohort flow](png/figure_01_cohort_flow.png)

Selected request: 178 mm. Both 85/178 mm outputs are available after regeneration.

## 02 missingness

![Candidate 02 missingness](png/figure_02_missingness.png)

Selected request: 178 mm. Both 85/178 mm outputs are available after regeneration.

## 03 propensity score distribution

![Candidate 03 propensity score distribution](png/figure_03_propensity_score_distribution.png)

Selected request: 85 mm. Both 85/178 mm outputs are available after regeneration.

## 04 weight distribution

![Candidate 04 weight distribution](png/figure_04_weight_distribution.png)

Selected request: 85 mm. Both 85/178 mm outputs are available after regeneration.

## 05 love plot

![Candidate 05 love plot](png/figure_05_love_plot.png)

Selected request: 178 mm. Both 85/178 mm outputs are available after regeneration.

## 06 standardized balance

![Candidate 06 standardized balance](png/figure_06_standardized_balance.png)

Selected request: 178 mm. Both 85/178 mm outputs are available after regeneration.

## 07 difference forest

![Candidate 07 difference forest](png/figure_07_difference_forest.png)

Selected request: 178 mm. Both 85/178 mm outputs are available after regeneration.

## 08 ratio forest

![Candidate 08 ratio forest](png/figure_08_ratio_forest.png)

Selected request: 178 mm. Both 85/178 mm outputs are available after regeneration.

## 09 survival curve

![Candidate 09 survival curve](png/figure_09_survival_curve.png)

Selected request: 85 mm. Both 85/178 mm outputs are available after regeneration.

## 10 risk curve

![Candidate 10 risk curve](png/figure_10_risk_curve.png)

Selected request: 85 mm. Both 85/178 mm outputs are available after regeneration.

## 11 cumulative incidence

![Candidate 11 cumulative incidence](png/figure_11_cumulative_incidence.png)

Selected request: 85 mm. Both 85/178 mm outputs are available after regeneration.

## 12 sensitivity forest

![Candidate 12 sensitivity forest](png/figure_12_sensitivity_forest.png)

Selected request: 178 mm. Both 85/178 mm outputs are available after regeneration.

## 13 ccw strategy schematic

![Candidate 13 ccw strategy schematic](png/figure_13_ccw_strategy_schematic.png)

Selected request: 178 mm. Both 85/178 mm outputs are available after regeneration.

## 14 lmtp policy plot

![Candidate 14 lmtp policy plot](png/figure_14_lmtp_policy_plot.png)

Selected request: 85 mm. Both 85/178 mm outputs are available after regeneration.
