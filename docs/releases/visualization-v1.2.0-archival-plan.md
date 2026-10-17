# Visualization v1.2.0 archival plan

`RELEASE_READY_FOR_ARCHIVAL` describes source metadata prepared for archiving.
It is not a claim that a tag, GitHub Release or Zenodo record already exists.
Final publication requires a separate researcher decision on the exact validated
commit and the proposed Release body in [the release notes](visualization-v1.2.0.md).

## State contract

- `UNRELEASED_RC`: the existing RC contract, returned by the validator as
  `UNRELEASED_V1_2_0_CANDIDATE`. Missing `Release-Status` retains this meaning for
  the already reviewed RC snapshot; its explicit RC descriptions are required.
- `RELEASE_READY_FOR_ARCHIVAL`: explicitly recorded in DESCRIPTION. CFF citation
  wording and Zenodo software description contain no RC wording, date or DOI.
  The notes' first paragraph must equal the Zenodo description. The complete
  notes are the proposed GitHub Release body; use that file verbatim when a
  later publication action is explicitly authorized.
- Actually archived: established only by the published GitHub Release, its
  immutable tag/commit, successful Zenodo record and matching archive contents.
  This is not a source flag that can be set to bypass publication verification.

## Verified mechanism and date handling

Read-only repository inspection confirmed an active Zenodo webhook subscribed
to GitHub `release` events. The recent delivery list was empty, so this confirms
configuration, not a new end-to-end archival run. Recheck the hook and the
Zenodo repository connection before the eventual authorized publication.

[Zenodo's documentation](https://help.zenodo.org/docs/github/describe-software/zenodo-json/)
states that `.zenodo.json` takes precedence over `CITATION.cff` when both exist.
The [Zenodo integration implementation](https://github.com/zenodo/zenodo-rdm/blob/1fab575d6b7eea09e5ebef5329ee366efbddc802/site/zenodo_rdm/github/release.py)
loads metadata from the tagged source and overlays JSON metadata on its defaults.
The [underlying GitHub metadata implementation](https://github.com/inveniosoftware/invenio-rdm-records/blob/54f6d18597223b6f5bf97a36044bf2e25e7db0e5/invenio_rdm_records/services/github/metadata.py)
starts with the actual GitHub Release `published_at` date for `publication_date`.
However, the [Zenodo legacy JSON conversion](https://github.com/zenodo/zenodo-rdm/blob/1fab575d6b7eea09e5ebef5329ee366efbddc802/site/zenodo_rdm/legacy/deserializers/metadata.py)
fills an omitted `publication_date` with the processing day's date. That JSON
metadata then overlays the GitHub defaults. Do not assume both dates are equal,
especially after a delayed or retried webhook.
These are inspected upstream sources, not a claim to know Zenodo's deployed
commit. The eventual record must still be checked against the actual release.

Keep `publication_date` out of `.zenodo.json` and `date-released` out of CFF
while no real release date exists. These omissions are supported by the file
schemas and let the actual archival process resolve the date rather than
inserting a guessed date. Compare the resulting record date with the GitHub
Release date and investigate any discrepancy before accepting the archive.
Keep DOI fields absent until a real version DOI has been assigned.
The v1.0.0 DOI `10.5281/zenodo.21879884` must never identify v1.2.0.

## Publication and subsequent maintenance

After separate authorization, recheck the approved SHA, its CI and 68-file
freeze before creating an immutable v1.2.0 tag and publishing the GitHub Release.
Use the checked-in release notes as its description. Follow
[Zenodo's archive workflow](https://help.zenodo.org/docs/github/archive-software/github-upload/)
and verify the resulting version, creators, ORCID, MIT license, repository,
publication date, version DOI, archive files and association with the intended
record/version series. Stop if the record or DOI cannot be verified.

Only then may a separately authorized maintenance commit update citation/date
references on main using the actual record. That follow-up must extend the
validator with evidence-bound archived metadata and tests; this preparation
contract deliberately rejects DOI/date fields and a self-declared archived
state. Never move the v1.2.0 tag to insert a DOI after publication. Preserve the
tagged archival source and the v1.0.0 tag, Release and DOI.

No statistical estimator, registry, lockfile, expected value, tolerance, frozen
visualization file or PR #4 scientific authority is changed by this process.
Gallery acceptance remains component-level approval; real-study figures need
their own QC and human review.
