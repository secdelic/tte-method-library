# CCW development source snapshot

This directory preserves 47 existing development source files and one unresolved
configuration template that had not been committed in the original development
worktree. It is **not a production module or an independently runnable CCW
package**. Nothing here is sourced by `tte_source_library`, registered as an
approved profile, or executed by the migration smoke test.

[SOURCE_MANIFEST.json](SOURCE_MANIFEST.json) records each original repository-relative
path and byte hash alongside its snapshot hash. The original worktree, its
staged files and all historical evidence remain untouched. Git preserves the
snapshot bytes rather than converting their line endings.

Included source families: reference-only rational calculations; minimal core and
GLM comparator; core optimization; staged synthetic DEV runner and DGP; lean
subject bootstrap and inference connector; Phase 0 validator; lean candidate
configuration. These are preserved code, not a new execution authorization.

Two files have technical path adaptations: the bounded launcher discovers
`Rscript` from `RSCRIPT` or `PATH`; the reference input expander requires an
explicit `TTE_CCW_AUTHORIZATION_SOURCE` instead of a personal attachment path.
No estimator, scientific parameter, method selection or approval is changed.
The corresponding original and adapted hashes remain distinct in the manifest.

Sealed authorization documents, authority amendments, session messages,
identity/source mappings, generated histories, draw maps, runtime receipts,
internal review ZIPs and historical result directories are intentionally absent.
Several scripts enforce hashes of those original dependencies. Their historical
contracts must not be replaced or rehashed merely to make this snapshot run.
Consequently the original CCW development/canary workflow cannot yet be restored
from GitHub alone. No new CCW test, canary, bootstrap or clinical run was performed
for this migration; source parsing is not statistical validation.

PR #4 and its original `feature/ccw-production-validation` branch remain
independently fetchable at `b595a938c88e535b0cb12e56dfc0558b309b8c61`.
They contain the earlier, unapproved scientific authority and validation plans,
not the later local implementation or evidence. They are not merged here.
The later local records must be reviewed for scope and sharing before a separate
CCW migration is authorized; this snapshot does not certify those records.

See [cross-PC migration](../../docs/CROSS_PC_MIGRATION.md) for the fully runnable
approved statistical, figure, Word and project workflows and this explicit gap.
