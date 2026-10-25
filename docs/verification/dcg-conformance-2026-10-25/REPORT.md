# Native SWI DCG conformance assessment — 25 October 2026

## Result

All 58 queries from Ulrich Neumerkel's comparison were run directly and through
the guarded Web Prolog execution path: 116 observations, with no timeouts or
answer caps. On each path, 42 match a listed outcome, three differ only by a
module-qualified procedure indicator in an existence error, and 13 have other
comparison differences. Every direct/guarded pair agrees on answers, terminal
state and formal exception; implementation error contexts differ.

The [complete case matrix](COVERAGE.md) retains every case identifier. The 48
numeric DCG cases account for 34 listed-outcome matches, three qualified
indicators and 11 other differences. The ten `c*`/`f*` Prolog support controls
account for eight matches and two differences. Do not describe 42/58 as a
percentage of the DCG specification: this is an intentionally diagnostic case
collection, not a complete or weighted conformance suite.

## Sources and limits of the claim

- [Comparison and expected alternatives](https://www.complang.tuwien.ac.at/ulrich/iso-prolog/phrase)
- [Executable query/answer listing](https://www.complang.tuwien.ac.at/ulrich/iso-prolog/phrase_quad.pl)
- [Linked draft error subclause](https://www.complang.tuwien.ac.at/ulrich/iso-prolog/draft-8.18.1.3)
- [ISO Prolog working documents, published-TS link and reference implementation](https://www.complang.tuwien.ac.at/ulrich/iso-prolog/)

Retrieval hashes, author attribution and timestamp are in `upstream-sources.json`.
The executable listing is frozen in `phrase_quad.pl`; extracted inputs and
expectations are in `cases.json` and `cases-with-expectations.json`. All listed
alternative outcomes are retained, including implementation-defined terminal-list
checks and the comparison's alternative error choices. Wildcards in the source's
abbreviated error descriptions remain wildcards, not exact culprit assertions.

The page's SWI column is headed 9.3.17, and some cells retain older version
comments. It is historical evidence, not a prediction for this engine. The
linked errors page is explicitly a draft. This batch compares observations with
these public expectations; it does **not** certify compliance with the complete
published ISO/IEC TS 13211-3:2025, whose full normative text was not reviewed.
A suspected standards deviation needs that final-text check before an upstream
claim. No reference DCG library was installed or substituted.

## What differs, and why

### Partial terminal-list grammar bodies: seven cases

Cases **6, 7, 8, 17, 18, 19 and 38** produce `type_error(list,[a|_])` on both
paths. The comparison expects `instantiation_error` for six of them, and permits
that or `type_error(callable,1)` for case 19. These are partial lists **inside the
grammar body**, distinct from a partial input or remainder sequence.

The tested engine's `boot/dcg.pl`, lines 117–124, recognizes a nonempty terminal
list, calls `is_list/1`, and raises a list type error when that test fails. That
also rejects a variable tail. Case 17 is translated before its preceding brace
goal could bind the tail. The public guard reaches the same host DCG translation;
it does not introduce the distinction. The current engine terminates on cases
that the historical SWI column records as enumeration or looping.

### Negation and eager validation: two cases

Cases **29 and 30** raise `type_error(callable,1)`. The comparison permits
`representation_error(dcg_body)` or, when negation is supported, failure/success
respectively. The host translator supports grammar negation but translates its
argument before execution (`boot/dcg.pl`, lines 165–169). Invalid grammar `1` is
therefore rejected even behind a terminal mismatch or an alternative which
could otherwise succeed. The guards preserve this host outcome.

### The runtime status of `(-->) / 2`: two cases

Case **24** succeeds in asserting an ordinary `(a-->b)` term rather than raising
the comparison's static-procedure permission error. Case **25**, in a fresh
process, fails to find such a clause rather than raising a private-procedure
permission error. These concern the status of the grammar-rule functor as a
runtime procedure, not ordinary use of `phrase` with a well-formed grammar.

To distinguish fixture state from engine behaviour, an additional isolated
sequence asserts the term and then inspects it. Both direct and guarded paths
return `B=true` in that sequence (`sequence-results.json`). Thus a clause lookup
after assertion must not be compared with our fresh-process case 25. The page's
historical `B=true` observation is reproducible with that explicit setup; its
precise original interactive state is not assumed.

### Supporting Prolog controls: two cases

- **c5:** `call((!;\+1))` raises a callable type error rather than succeeding.
  This concerns host meta-call validation, not a DCG library.
- **f3:** `functor([_],'.',2)` fails. The current SWI list-cell representation
  distinguishes its list constructor from the ordinary `'.'/2` functor. This
  is a host representation issue, not introduced by the DCG guard.

### Qualified error indicators: three cases

Cases **26, 31 and 32** produce the listed existence-error kind and procedure
indicator with the explicit test module attached, e.g.
`existence_error(procedure,dcg_assessment:phrase/4)`. Raw results retain the
`culprit_difference` classification; the matrix marks these as qualified error
indicators rather than silently dropping namespace information or treating them
as unexplained missing answers. This assessment does not settle ISO module
qualification requirements.

## Harness and guard checks

`probe.pl` reads queries as data at runtime; the compiler cannot pre-expand
literal `phrase` calls in the harness. Each case/path uses a fresh OS process
and module context, so case 24 cannot affect another case. Execution is limited
to one second inside SWI, four seconds externally, and eleven answers. Limits
are reported as inconclusive boundaries, never failure or a conformance pass.
All final observations exhausted normally or raised an exception.

The guarded path loads committed native source, activates ACTOR public execution
with blacklist mode, invokes `sandbox_check_goal_in_module/3`, then
`isolation:prepared_goal/3` and the prepared goal. Prepared terms are recorded;
`phrase` contains the expected public DCG wrapper. This exercises the actual
in-process admission/preparation/execution functions, not an HTTP or browser
transport. No server is started. The prepared public helper applies both
sandbox and reserved-control rewriting at runtime.

Four separate activation controls confirm that forbidden brace calls, qualified
forbidden calls and crafted helper calls are rejected, and `$abort_goal` escapes
ordinary recovery. All pass. The existing blacklist prototype qualification
remains: these checks do not establish a complete security boundary.

Twelve matcher regression tests pass. They verify alternatives, error family
and culprit visibility, wildcard descriptions, exact solution sequences,
variable sharing and refusal to count truncation as success. The initial harness
qualification and quote-flag fixture mistakes are documented in
`initial-harness-check.json`; final raw reports come from the corrected harness.

## Text diagnostics are separate

[TEXT-DIAGNOSTICS.md](TEXT-DIAGNOSTICS.md) contains eight diagnostics, each run
directly and guarded with native strings and with explicitly selected
module-local character-list readers: 32 observations, all matching their
configuration-specific expectations. Ordinary, empty and supplementary-Unicode
literals, supplied DCG source and runtime literal grammars are included.

Native `"ab"` terminals consume codes; the `chars` configuration consumes
one-character atoms. This contrast alone does not establish a DCG conformance
failure. The experiment does not configure all production goal/option/input
readers or serialization, change a shared profile or migrate a deployed node.
Text observations are excluded from the 58-case totals.

## Recommendation

There is no evidence here for another guard-composition repair. The next bounded
step would be to check the **seven partial-list error cases** and **two eager
negation cases** against the final published TS, then decide whether a narrow
upstream report or a test-only run of the reference library is warranted.

A separate DCG library remains an option if confirmed semantic requirements
cannot be supplied reliably by the host. This assessment does not justify that
migration yet: two findings concern broader Prolog representation/meta-call
behaviour, and changing DCG translation would still require sandbox, private
source, copied-source and reserved-control integration testing.

## Reproduction and preservation

Run with Python 3 and the recorded separate engine available:

```sh
python3 docs/verification/dcg-conformance-2026-10-25/assess.py
python3 docs/verification/dcg-conformance-2026-10-25/text_and_controls.py
python3 docs/verification/dcg-conformance-2026-10-25/matrix.py
```

`freeze.py` refreshes upstream inputs and must be invoked deliberately; it is not
run by the assessment. The default assessment reuses the frozen listing.
Matcher tests run using the recorded `swipl` launcher with `-f none -q -s
matcher_tests.pl -g 'run_tests,halt'` from this directory.

Native source is archived from commit `70c88e21d2019b2dedf449a0b8b11a7049ab0e16`;
pending Boolean/URI edits are excluded. The separate verified SWI build reports
10.1.18, with the previously verified Jan core and HTTP shutdown fixes; this is
not a claim about a pristine release build. Engine, boot DCG file and fixture
hashes are recorded in the provenance files.

All preservation checks pass: tracked working files (including pending work),
runtime source trees, installed engine targets/hashes, matching libraries,
dependency pin and live n3/n5 identities are unchanged. The batch adds test-only
scripts, raw observations and reports. No runtime or book edits, installed
engine updates, dependency-pin updates or n3/n5 restarts were performed.
