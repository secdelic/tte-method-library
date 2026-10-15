# PR #2 retention external-surface audit

Date: 2026-10-14. Scope: the proposed final PR #2 diff against main, read from
staged Git blobs. Deleted assets are outside the current delivery count; their
original validation/archive record is preserved separately. The benchmark PDF,
its extracted text/renderings, and the user-created untracked comparison ZIP
are not included in this PR or external delivery.

```text
FINAL_EXTERNAL_SURFACE_AUDIT
FILES_CHECKED = 60
FILES_TOTAL = 60
UNINTENDED_TOOL_OR_TEMPLATE_LABELS = NONE
IDENTITY_METADATA_REVIEW = NONE within changed file metadata
NORMAL_SOFTWARE_METADATA = retained PNG raster resolution information; historical R PDF attributes are documented as archival evidence
LEGITIMATE_AI_DISCLOSURES = retained candidate/accessibility reports describe the actual AI-assisted work
INTERNAL_WORKFLOW_RESIDUE = NONE requiring removal; public commit/content hashes and rebuild paths are reproducibility evidence
UNCHECKED_SURFACES = latent pixel-level provenance signatures/watermarks in retained PNGs not independently assessed
EXTERNAL_SURFACE_STATUS = PARTIAL_UNCHECKED
```

All retained PNGs were decoded and their available metadata/EXIF read. Text,
CSV records, filenames and generated-path references were read. Selected
original/candidate PNGs remain identical to the researcher-reviewed bytes. No
PDF, SVG, TIFF or Office documents are part of this final main-tree change.
No file author identity, timestamp or legitimate disclosure was replaced.
This surface check does not establish absence of AI use or publication approval.
