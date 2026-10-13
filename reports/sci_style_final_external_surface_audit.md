# Candidate external-surface audit

Date: 2026-10-13. Scope: all 223 new/modified files in this candidate's
Git diff against its latest-main base, including the actual exported assets,
comparison PNGs, review previews, source/config changes, manifests and reports.
Unchanged stable repository files are outside this bounded change audit.
No new release ZIP or GitHub Release is an external deliverable of this task.

```text
FINAL_EXTERNAL_SURFACE_AUDIT
FILES_CHECKED = 223
FILES_TOTAL = 223
UNINTENDED_TOOL_OR_TEMPLATE_LABELS = NONE
IDENTITY_METADATA_REVIEW = NONE within changed file metadata
NORMAL_SOFTWARE_METADATA = 28 PDF files: R 4.5.1 producer, R creator, R Graphics Output title; PNG/TIFF raster resolution/compression; SVG device glyph definitions
LEGITIMATE_AI_DISCLOSURES = reports/sci_figure_style_v1_1_candidate.md and reports/sci_palette_accessibility_validation.md describe AI-assisted code/style/rendering/display review with human adoption pending
INTERNAL_WORKFLOW_RESIDUE = NONE requiring removal
UNCHECKED_SURFACES = SVG outlined glyphs are not machine-readable text; latent pixel-level provenance signatures/watermarks in PNG/TIFF were not independently assessed
EXTERNAL_SURFACE_STATUS = PARTIAL_UNCHECKED
```

The checked representations are the staged Git blobs and the final native
files. Text files, CSV labels, filenames and figure labels were read; actual
PDF document properties, available XMP, annotations and attachments were
inspected; SVG XML elements/attributes and raster metadata/TIFF tags were read.
All 28 PDF and 28 SVG native outputs were rendered; PNG/TIFF candidate pairs
are pixel-identical. Actual candidate figure renderings and the four sets of
accessibility previews were inspected for visible inappropriate labels.
The 28 comparison PNGs match the manifest's image dimensions and 600-DPI
setting. No personal creator/author/company fields were found in the changed
artifact metadata. No metadata identity was replaced or invented.

The PDF title is the R device's ordinary graphics title. Along with Producer
and Creator, it is retained as normal software metadata, not treated as
evidence of AI authorship. Public baseline commit hashes, fixed seeds,
candidate status, QC/manual-review field names and source-file references
are legitimate reproducibility/software documentation in this repository;
they are not unintentional internal identifiers.

No Office documents, tracked changes, speaker notes or hidden worksheets
are part of this change. The unchecked surfaces above are explicit capability
limits. Zero text keyword hits do not establish absence of AI activity.
AI assistance is described accurately in the candidate report, and this
surface audit grants no scientific, author-adoption or publication approval.
