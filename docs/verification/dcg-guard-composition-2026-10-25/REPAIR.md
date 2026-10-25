# Native SWI DCG guard composition — repair and verification

25 October 2026. Candidate tested against native base `786737f3352c9a3abc3f59c6e09a393008579b5a`.

## Outcome and cause

The public sandbox and reserved-control rewriters both wrapped the DCG argument
of `phrase/2-3`. The outer wrapper translated and sandbox-checked the inner
implementation helper as a foreign module-qualified call. Valid grammars were
therefore rejected. This is an adapter composition defect, not a SWI engine bug.
The original [investigation](REPORT.md) and its negative-control evidence are retained.

The control rewriter now preserves the existing public DCG closure only when
its stored caller module is identical to the current caller. The public closure
already translates the original grammar and routes its ordinary goal through
sandbox validation and control rewriting. No module allowlist or general helper
exemption was added. Matching does not bind unknown module qualifiers or calls.

## Regression scope

Expanded `tests/tiers/node/public_goal_guard_tests.pl` exercises the combined
public/control path with goals constructed at runtime, avoiding compiler
pre-expansion of literal `phrase` calls. Coverage includes:

- `phrase/2-3`, terminals, named/private and runtime-selected grammars;
- remainders, alternatives, backtracking, failure and variable sharing;
- unbound grammars, ordinary exceptions and ordinary `catch/3`;
- reserved controls bypassing recovery and actor-exit cleanup;
- forbidden braces, qualified forbidden calls and crafted internal helpers;
- nonbinding recognition, wrong stored context and guard restoration;
- copied grammar source prepared afresh in the destination actor.

The initial run exposed fixture issues (a prohibited `link(false)` option and a
negative grammar reduced by DCG translation to harmless unification). Those
fixtures were corrected before the final baseline/candidate comparison. Both
engines in that comparison use identical final tests and waits. The initial
[unit results](initial-unit-results.json) remain available.

## Results

| Check | Result |
|---|---|
| Unmodified control rewriter with final expanded tests | 16 failures, 33 passes: reproduces the defect |
| Candidate public-guard suite | 46 tests plus 3 parameterized sub-tests pass |
| Native T1 and T4 partitions | Both pass; exit 0 |
| Shared ACTOR, copying/isolation, creation validation and child-spec packs | SWI 25/25; Trealla 25/25 |
| Candidate SWI DCG HTTP/WebSocket controls | 7/7 pass |
| Common DCG controls on Trealla | 5/5 pass |

The two extra transport controls assert SWI's native `"ab"` DCG convention
(`[97,98]`). Trealla fails those SWI-specific expectations because its terminals
are character lists. Those raw failures are retained as representation contrasts,
not shared conformance failures or new Trealla defects. See [coverage](COVERAGE.md).

## Experimental text findings remain separate

The unchanged experimental `portable-text-0.2` pack reports SWI 4 pass/22 fail and
Trealla 21 pass/5 fail. In SWI, TXT-015 now returns ordinary failure instead of
rejecting the internal sandbox helper: its `"ab"` grammar expects codes whereas
the draft assertion supplies `[a,b]`. The bounded repair does not change readers,
DCG terminal representation, serialization or deployed text semantics. The
unmodified Trealla JSON library's supplementary-Unicode findings remain separate.
No experimental failures were reclassified or folded into the shared pass count.

## Reproducibility and boundaries

Native tests use an isolated archive of the committed base with only
`control_guard.pl` and the expanded test file overlaid. The separate verified
SWI 10.1.18 launcher was used; Trealla uses the separate unmodified v3.14.10
engine and committed adapter `6fb21f1c39fc05377751d842ae7a34e7cc18464f`.
Pending Boolean/URI work is excluded from fixtures and preserved in the working tree.

- [Source and engine provenance](repair-provenance.json), [candidate source](candidate-source.json), [conformance fixture](conformance-source.json)
- [Unit commands/results](unit-results.json), [candidate log](candidate.log), [negative-control log](unmodified-control.log)
- [Native tier command/result](native-tiers.json), [tier log](native-tiers.log)
- [Shared/transport commands and reports](shared-local/provenance.json)
- [Experimental text commands and reports](portable-text/provenance.json)
- [Machine-readable validation](repair-validation.json), [repair-only patch](repair-only.patch)
- [Preservation checks](repair-preservation.json)

The README explains the composition rule and the unchanged native string
convention. Blacklist mode remains a prototype policy, not a complete security
boundary. This batch does not update the dependency pin, installed engines or
libraries, restart n3/n5, change the shared manual or book, or modify Trealla code.
Only disposable verification nodes were started. Preservation checks pass.

Report schema validation caught an unsupported `supporting` scope label in the
local DCG controls. It was corrected to `required` (assertions in those local
manifests, not a shared profile requirement). The runner treats both labels
identically; cases and execution results were unchanged. Original and corrected
hashes and the metadata correction are recorded in `shared-local/provenance.json`.

## Portability follow-up sources

The [ISO Prolog working documents](https://www.complang.tuwien.ac.at/ulrich/iso-prolog/)
identify the published DCG specification as ISO/IEC TS 13211-3:2025 and link
a reference implementation and test cases. The [phrase comparison](https://www.complang.tuwien.ac.at/ulrich/iso-prolog/phrase)
records implementation-specific differences, including a SWI 9.3.17 column.
These are inputs to a future conformance assessment, not a test result for the
current SWI engine or proof that a replacement library is required. No DCG
library replacement or additional standards-conformance run is included here.
