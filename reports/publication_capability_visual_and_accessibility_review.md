# Publication capability visual and accessibility review

Review date: 2026-10-15. Scope: nine original synthetic scenes, PDF/SVG actual
renders at requested 85/178 mm, plus double-width actual PNG simulations for
grayscale, deutan, protan and tritan. This is machine and AI-assisted technical
review, not researcher approval of the new figures or a real study.

| Check | Observed result / scope |
| --- | --- |
| Actual formats | 72/72 file inspections PASS; 18 PDFs rendered through Poppler and 18 SVGs through rsvg; PDF/SVG contain vector paths rather than rasterized plot panels. |
| Raster dimensions/DPI | 600-DPI PNG/TIFF within native pixel rounding; PNG/TIFF pixel contents match. |
| Canvas | Native whole-point PDF/SVG quantization: 84.67/177.80 mm for requested 85/178 mm; error less than 1 pt. Requested heights are recorded in the manifest. |
| Fonts | Extractable actual PDF text minimum 7 pt. SVG glyphs are outlines, visually inspected rather than asserted as extractable text. |
| Text/page clipping | All 18 PDF text-bounding checks report zero outside-page text; actual PDF/SVG renders show no clipped synthetic labels/counts/CI text. This does not certify arbitrary future long labels or dense real datasets. |
| Flow / timelines | Boxes/connectors, exclusions/branches/counts, research stages, clone/strategy lanes, event shapes, grace boundaries and endpoints visible. Tied events are vertically separated without changing times. |
| Risk tables | Raw counts preserved; endpoint alignment prevents left-row-label collision and last-count clipping; curve/table plotting widths aligned. Row labels have a visible margin from counts. |
| Outcome panels | Strategy mapping and single legend consistent. Panel letters visible. Optional shared x range tested; example horizons are caller-supplied. |
| Forests | Neutral difference/ratio null lines, CIs, hierarchy, indentation, estimate/CI/N/interaction text visible. Shared rows and fonts; restrained panel gutter; dense 85-mm assembly stacks vertically. |
| CI ribbons / reference lines | Ribbons remain visible below curves; reference lines remain visible in grayscale/CVD previews. No uncertainty or comparison is selected by significance. |
| Accessibility | Nine cases x four simulations = 36 previews. Lines distinguish strategies by solid/dashed as well as color; timelines use event shapes; forests use neutral/navy text/intervals and hierarchy rather than P-based color. |
| Palette | Existing SCI v1.1 colors/theme retained; light monochrome diagram fills and row shading are supporting neutrals. No second categorical palette. |
| Text contrast | Existing colorspace contrast calculation: charcoal text on white 11.91:1, diagram fill 10.58:1, alternating row fill 10.89:1 (each above 4.5:1). This evaluates text/background pairs, not every geometric mark. |

The accessibility conversion is shared with the original style validator,
using installed colorspace 2.1.1 severity-1 simulations and grayscale on actual
PNG pixels. Previews are downsampled for inspection; they do not substitute for
the full-resolution export or certify visibility for every vision condition.
No dependencies were upgraded. Full previews stay in ignored output.
The refactored shared style-preview helper was also exercised on the unchanged,
byte-preserved 14-case style export set: 56 previews/9 contrast checks PASS;
the default export validator path checked all 112 original exports PASS.

Evidence: [actual file checks](publication_capability_export_validation.csv),
[gallery manifest](publication_capability_gallery_manifest.csv),
[fixtures](../figure_gallery/publication_capability_fixtures.R),
[tests](../tests/test_publication_capabilities.R),
[selected PNGs](../figure_gallery/publication_capability/README.md).

`publication_ready=FALSE`; `manual_review=PENDING` for all new QC rows.
The researcher's earlier 14-figure cbc4424 PASS applies to the original style
candidate only and is not reused as approval of this new capability gallery.
