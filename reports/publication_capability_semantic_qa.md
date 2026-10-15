# Publication capability synthetic semantics

This revision follows the gallery at `c7ac2b06db4f45ce864eb6b1e03df15b89e1e394`.
It changes synthetic examples and their explanation, plus one reproduced
timeline symbol-overprinting defect. It does not change an estimator, estimand,
production registry, CCW Scientific Authority, palette, theme or export contract.
All examples remain SYNTHETIC_DEMONSTRATION_ONLY, independently authored toy
inputs, not patient records or reproduced JAR study results.

## Fixture before and after

| Scene / field | Before | Revised meaning |
| --- | --- | --- |
| Participant flow | 620 -> 480 / 140 -> 240 / 240, generic meaning implicit | Same counts; GENERIC_PARTICIPANT_FLOW_DEMONSTRATION in fixture/gallery and visible non-CCW caption |
| Competing timeline, S1 | C1 natural censor at 6; C2 outcome at 8 | One original history: treatment at 2, outcome at 8; C1 artificial censor at 2, C2 outcome at 8 |
| Competing timeline, S2 | C3 competing event at 9; C4 natural censor at 7 | One original history: no treatment, competing event at 9; C3 contributes to 9, C4 artificial censor at 3 |
| Natural loss example | Conflicting clone-specific natural loss | Additional synthetic S3: both inherit original loss at 6; C5 contributes to loss at 6, C6 artificial censor at 3 |
| Research timeline | Original four clone rows and events | Same rows/events, now backed by explicit shared subject source |
| Risk counts | Caller integers without encoded unit/timing | Same integers; explicit original-subject, immediately-before-t, unweighted synthetic sidecar |
| Curves / intervals | Supplied points with arithmetic toy bands | Same probability estimates and mathematical bounds; bounds explicitly listed as toy 95% CI inputs, not estimated intervals |
| Effect annotation | Difference without named outcome/horizon | Survival or CIF, t=12, Treatment-minus-Control; same point contrast and supplied contrast CI |
| Time labels | Follow-up time | Synthetic time units, including the illustrative 30/60 rescaling |

The participant flow is not a baseline-clone diagram. If all 480 eligible
subjects were cloned to both strategies, each strategy would begin with 480
clones. This revision neither replaces the generic flow nor claims those
clones are represented by its 240/240 split.

In these timelines, natural censor explicitly means original observation loss.
The constructor itself only checks the provided event labels and bounds.
Original treatment and terminal events are shared across a subject's clones;
an earlier artificial censor removes subsequent analysis contribution, without
changing the original observed history. The displayed toy strategy definitions
are no initiation by 3 versus initiation by 3. They are fixture assumptions,
not scientific authority for a real CCW analysis. Same-time treatment and
artificial censor at 2 are caller-supplied; their vertical separation does not
specify a general event-priority rule.

## Reproduced public drawing defect

With the old competing fixture, `ggplot_build()` returned endpoint squares at
(6,4), (8,3), (9,2), (7,1), and terminal-event symbols at the same four positions.
Thus all four terminal glyphs were overprinted by an unnecessary square.
The minimal constructor repair suppresses the square when a terminal event
is supplied at that clone's end; an unmarked end still gets a square. No event
x/time, lane ordering, shape mapping, CI or statistical value is changed.
Tests cover both terminal and unmarked ends as well as unchanged event x values.

## Counts, effects and acceptance boundaries

The [API guide](../docs/figures/publication_capability_guide.md) distinguishes
original subjects, analysis units, clones and weighted risk-set mass. The
backward-compatible gallery solution is caller metadata beside the image and
on the supplied count table; no statistical interface or automatic unit
inference is introduced. The declared toy counts are distinct original subjects
within disjoint groups, immediately before all events/censors at t. Weighted
mass must not be rounded into participant counts.

Survival and CIF are independent legal probability sequences, not complements
of one another. Supplied 95% CI values are display fixtures with no inference
or coverage claim. Survival at 12 differs by 0.85 - 0.79 = 0.06; CIF at 12
differs by 0.11 - 0.15 = -0.04. Contrast intervals are independent supplied toy
inputs, not subtraction of pointwise bands. Difference/null=0, ratio/null=1
on a linear axis, and interaction P inputs remain explicit. The 30/60 panels
reuse the toy survival values on rescaled axes, not new study estimates.

The existing five-script suite includes additional assertions for source-history
coherence, deliberately inconsistent histories, monotonic probabilities, CI
containment, effect direction/horizon, metadata retention and terminal glyphs.
The new commit must also pass the unchanged 14 frozen regression checks,
11 independent checks, 112 native exports and 72 capability exports. Per-HEAD
execution evidence and actual-render inspection accompany the local review
package; prior-HEAD results alone do not certify this revision.

New gallery scientific semantics/readability/symbols/counts/CI/time labels/
forest scales/panel alignment remain subject to researcher component-level
acceptance. That acceptance is not study-figure publication approval. Every
export retains `publication_ready=FALSE` and `manual_review=PENDING` until its
own authorized review. AI-assisted fixture/code/test/documentation work and
technical inspection are distinct from researcher approval.
