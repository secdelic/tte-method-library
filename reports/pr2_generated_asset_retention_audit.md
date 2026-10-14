# PR #2 generated-asset retention audit

Date: 2026-10-14. Audited original head: `cbc4424`, 223 changed files.
The [complete classification manifest](pr2_asset_retention_manifest.csv)
records every original changed path, byte count, content identity, class and
destination. This is asset governance for STYLE ONLY, not estimator development.

| Original class | Files | Retention |
| --- | ---: | --- |
| KEEP_IN_MAIN | 55 | 27 source/config/test/CSV/MD files, 14 selected candidate PNGs, 14 original-style documentation PNGs |
| CI_ARTIFACT_OR_REGENERABLE | 168 | Nonselected full-resolution formats/widths, duplicated comparison candidate PNGs, all 56 CVD/grayscale preview PNGs |

Original generated graphics: 196 files, 13,875,411 bytes.
Retained documentation graphics: 28 PNGs, 2,799,935 bytes, a 79.82% reduction
in generated graphic bytes in the proposed main-tree contents.
Candidate comparison cells reference gallery PNGs rather than duplicate them.
The two QC CSVs are relocated to `figure_gallery/figure_qc_single.csv` and
`figure_gallery/figure_qc_double.csv` and retain their pending publication gate.
New small retention/visual audit records and ignore rules are also retained.

The complete original generated asset set and development validation snapshot
were archived locally before any removal, and every archived graphic was
compared byte-for-byte with its original. The archive is intentionally ignored
and is not an external deliverable or a new Release. The original cbc4424 commit
also remains recoverable in this draft branch's history. No unique numerical,
accessibility, typography or visual-review evidence was discarded.

All 28 retained documentation PNGs match the original reviewed bytes exactly.
The unchanged synthetic fixtures and native constructors regenerated the full
112-file matrix, 14 comparison pairs and 56 simulation previews successfully.
Actual-file validation still checks vector output, 600 DPI, physical requests,
minimum 7 pt fonts, pixel-identical PNG/TIFF pairs and pending human QC.

## Rebuild location

From the repository root:

```text
Rscript figure_gallery/render_all_native_figures.R
Rscript validation/validate_sci_style_accessibility.R
python validation/validate_sci_style_exports.py
```

Complete export matrices, comparisons and simulations go under ignored
`output/sci_style_gallery/`. `TTE_FIGURE_ASSET_ROOT` selects another generation
root. Development-only Poppler renderings/metadata inventories stay ignored.
Small scalar/CSV evidence and selected documentation PNGs are retained in Git.

## Git-history boundary

This change removes rebuildable binaries from the proposed final tree; it does
not pretend that their earlier cbc4424 Git blobs have disappeared. No force push
or history rewrite was performed. When the researcher separately authorizes
merge, a squash merge can keep the final main commit free of those draft-only
asset additions. This task does not merge, release, retag or alter main.

## Gates

The researcher confirmed the cbc4424 style visuals at both sizes on 2026-10-14.
Source constructors and reviewed documentation PNG bytes are unchanged.
Statistical regression and independent validation retain the frozen tolerances;
CI must be checked on the updated PR head before recommending review readiness.
No new figure-capability implementation or JAR-method claim belongs in PR #2.
