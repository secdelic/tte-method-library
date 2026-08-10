# Reproducibility

The RC1 records the software version, `renv.lock`, fixed synthetic seeds, input hashes, analysis specifications, variable dictionaries, package versions, output contracts and numerical tolerances.

The canonical-to-public comparison used identical synthetic CSVs. Public CI reruns the reimplemented estimators against synthetic fixtures created only after zero-difference comparison with the internal frozen implementation.

Real research projects must retain their private input manifest and hashes outside the public repository. Formal release packages must contain aggregate outputs only.
