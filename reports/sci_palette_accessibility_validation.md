# SCI palette accessibility validation - v1.1 Candidate

The numeric evidence below is retained. Full CVD preview PNGs are regenerable
under ignored `output/sci_style_gallery/figure_gallery/accessibility/` and are
not permanent source assets. Gallery documentation retains selected originals.

Date: 2026-10-13. Scope: the actual 14 synthetic native gallery exports.
This is AI-assisted technical and display review, not investigator visual
adoption or approval of figures for a real study.

## Palette and contrast

Semantic colors: treatment `#355C7D`, control `#6D7378`, comparator `#AD6058`,
favorable `#5B8E7D`, caution `#C49A5A`, neutral `#A5ADB4`, text `#30383F`,
grid `#E7EAEC`. Categorical colors: `#355C7D`, `#AD6058`, `#5B8E7D`,
`#C49A5A`, `#687780`, `#30383F`.

The proposed comparator `#B5655D` gave white text a 4.213:1 contrast ratio.
It was minimally darkened to `#AD6058` (4.574:1). This matters for CCW
censored/deviation tiles; it changes no status or statistical meaning.
Tile text uses white or dark charcoal `#151B20`, selected by contrast.
Main text on white is 11.911:1. All nine checked text/background pairs pass
the 4.5:1 regular-text review criterion; the minimum is 4.574:1.
See [actual contrast calculations](../figure_gallery/accessibility/text_contrast.csv).
The criterion and formula follow [colorspace contrast documentation](https://colorspace.r-forge.r-project.org/reference/contrast_ratio.html).
This is a text contrast check, not a claim of universal chart accessibility.

## Grayscale and color-vision simulation

`colorspace` 2.1.1 was used for desaturation and Machado-model deutan,
protan, and tritan simulations, severity 1, linear sRGB enabled.
The model is described in [official simulation documentation](https://colorspace.r-forge.r-project.org/reference/simulate_cvd.html).
The simulations convert colors in the actual candidate PNGs after reducing
them to 1000 px width for review. They are explicitly review aids, not
600-DPI publication exports. The originals are preserved.

All 56 converted previews were generated and inspected through contact sheets.
Group/state distinctions remained readable through non-color encoding.
Color pairs can converge in simulated CVD or grayscale; these results do not
establish that each swatch is distinguishable by color alone.
See [palette simulations](../figure_gallery/accessibility/palette_simulations.csv)
and the rebuild instructions in the [gallery](../figure_gallery/README.md).

| Native figure | Non-color distinction | Display review in all four modes |
| --- | --- | --- |
| Cohort flow | Stage labels, bar length, count labels | No loss of information observed |
| Missingness | Variable labels, bar length | No loss of information observed |
| PS distribution | Solid/dashed lines | Groups distinguishable |
| Weight distribution | Solid/dashed lines | Groups distinguishable |
| Love plot | Circle/triangle | Stages distinguishable |
| Standardized balance | Circle/triangle | Stages distinguishable |
| Difference forest | Row labels, point/CI position | Estimates readable |
| Ratio forest | Row labels, point/CI position | Estimates readable |
| Survival | Solid/dashed steps | Strategies distinguishable |
| Risk | Same strategy/linetype mapping | Strategies distinguishable |
| Cumulative incidence | Same strategy/linetype mapping | Strategies distinguishable |
| Sensitivity forest | Explicit analysis labels | Primary/sensitivity identifiable |
| CCW schematic | Status text in every tile | States identifiable |
| LMTP policy | Solid/dashed lines and circle/triangle | Series distinguishable |

The CCW v1.0.0 fixture relied on nearly equal-luminance colors. The candidate
uses gold/navy and adds status text. The frozen Grace/Follow-up assignments
are unchanged. A separate diagnostic probe checks contrast for all eight
documented state labels; it does not replace or augment the gallery fixtures.

## Limits and human review

The reviewed fixtures contain two groups/strategies and short labels.
Larger group counts, unfamiliar status labels, crowded real-study figures,
printing, different journal reductions, and viewing conditions need their
own assessment. CVD simulation is a review aid, not an affected viewer study.
Confirm subtle grid/reference visibility, low-alpha confidence ribbons,
and CCW label fit at intended page size before adoption.

All gallery QC rows retain `publication_ready=FALSE`, `manual_review=PENDING`.
No human reviewer, approval date, or publication approval has been created.

## Reproduce

From the feature-branch repository root, with development packages
`colorspace`, `magick`, `rsvg`, and the existing plotting dependencies:

```text
Rscript figure_gallery/render_all_native_figures.R
Rscript validation/validate_sci_style_accessibility.R
```
