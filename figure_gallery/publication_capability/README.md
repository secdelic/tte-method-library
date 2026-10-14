# Publication capability v1.2 candidate gallery

**SYNTHETIC_DEMONSTRATION_ONLY.** All counts, event times, curves, intervals,
interaction values and subgroup labels are original toy inputs supplied to
visualization utilities. The examples are independent, not an estimated study.
No benchmark patient data, numerical results, artwork, icons or code are used.

Nine selected documentation PNGs are retained here. Flowcharts, individual
curves and forests use 85 mm; timelines and multi-panel figures use 178 mm.
The complete nine-case, two-width, four-format matrix (72 files) is rebuilt by
`Rscript figure_gallery/render_publication_capabilities.R` under ignored
`output/publication_capability/`. CVD/grayscale simulations and PDF/SVG review
renders are also ignored. The [manifest](../../reports/publication_capability_gallery_manifest.csv)
and [actual-file export checks](../../reports/publication_capability_export_validation.csv)
retain small, inspectable evidence. Full risk tables/forests at 85 mm were
checked separately; dense forests stack vertically at that width.

| Information architecture | Selected original demonstration |
| --- | --- |
| Participant flow with exclusions, reason, remaining N and branches | ![Synthetic participant flow](png/participant_flowchart.png) |
| Research stages plus assigned clone/adherence timeline | ![Synthetic research timeline](png/research_ccw_timeline.png) |
| Natural censor, outcome and competing events | ![Synthetic competing-event timeline](png/competing_event_timeline.png) |
| Supplied cumulative incidence, bands, annotation and risk counts | ![Synthetic cumulative incidence](png/cumulative_incidence_risk_table.png) |
| Supplied survival, bands, annotation and risk counts | ![Synthetic survival](png/survival_risk_table.png) |
| Hierarchical difference-scale forest with text/N/interaction | ![Synthetic difference forest](png/subgroup_difference_forest.png) |
| Independently supplied ratio-scale forest, null=1 | ![Synthetic ratio forest](png/subgroup_ratio_forest.png) |
| Caller-specified outcomes/horizons with shared strategy legend | ![Synthetic outcome panels](png/multi_panel_outcomes.png) |
| Identical subgroup rows across supplied outcome forests | ![Synthetic forest panels](png/multi_panel_forests.png) |

Use the [API guide](../../docs/figures/publication_capability_guide.md) for input
schemas and limits. `publication_ready=FALSE` and `manual_review=PENDING`
remain unchanged for every export. Machine/AI-assisted review does not approve
a real study figure. **Visualization support does not establish CCW production
readiness.**
