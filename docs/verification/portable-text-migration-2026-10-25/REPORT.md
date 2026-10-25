# Portable-text migration tests and example audit — 25 October 2026

This is a **test/documentation batch** over native SWI source commit `c347b11`.
Production runtime sources, examples, installed engines, n3/n5 and the dependency
pin are unchanged. Character-list reading remains experimental and opt-in.

## Tests in the two configurations

The four earlier representation-dependent tests now have explicit default-mode
selection and separate character-list counterparts. Their original default
expected values, body assertions, messages, deadlines, errors and sharing checks
are preserved. [Body hashes](default-assertions.json) verify that all four original
test bodies are byte-identical to the committed originals. No default assertion
was broadened to accept either representation.

| Concern | Ordinary default assertion | Experimental counterpart |
|---|---|---|
| HTTP/RPC literals and supplied source | Native strings `"ab"` / `"q"`, even with the host REPL flag set to codes | Exactly `[a,b]` / `[q]`, under the same host-flag disturbance |
| Canonical RPC terms | Native `"s"`; all other exact term components retained | Exactly `[s]`; the same dollar-variable, quoting, operator and portray controls |
| Guarded DCG literals | Exactly numeric terminals `[97,98]` | Exactly character terminals `[a,b]` |
| Remote asynchronous toplevel answer | Native string identity plus Unicode/sharing/errors | Character-list result plus the same Unicode/sharing/error assertions and deadlines |

Both suites are registered together: each process executes its own four exact
contracts and does not apply the other configuration's incompatible contract.
This is an explicit configuration split, not a retroactive rewrite of the old
failed-run evidence. The original native-string extension remains tested in its
ordinary configuration; it is not promised by the portable subset.

## Library boundaries

Nine new named boundary tests (14 parameter selections) augment the TEXT tier.
They check native JSON strings versus embedded Prolog text, explicit Unicode
conversion from `format(string(...))` and `read_string/3`, numeric code lists
versus character lists, source text, JSON-carried canonical term text, variable
sharing, and both HTTP and actor error serialization.

The tests also make the remaining extension limitation explicit: an opaque
native string has the same quoted wire spelling as a portable literal. It does
not retain native-string identity after a character-list reader. Converting
with `string_chars/2` before portable transport gives an unambiguous list in
both modes. No blanket recursive conversion, new native-string wire tag, or
error-context rejection is added by this batch.

| Check | Default | Experimental chars |
|---|---|---|
| Four representation-specific contracts | 4/4 | 4/4 |
| Complete T4_NATIVE tier | **1041 active named tests / 1529 parameter selections pass** | **1041 / 1529 pass** |
| TEXT tier, including library boundaries | **30 named tests / 40 selections pass** | **30 / 40 pass** |
| Read-only representative example checks | **10/10** | **10/10** |

These rows overlap; do not add their counts into a new language conformance
score. The [accounting](test-accounting.json) and raw `t4-*`, `boundaries-*` and
`examples-*` logs retain the actual outcomes. No runtime repair was needed.

The preceding 26-case shared portable-text and 90-selection cross-runtime packs
were **not rerun**: production modules are byte-unchanged in this test-only
batch. Their previously committed results remain the interoperability evidence;
this batch adds native SWI migration coverage, not new Trealla/GNU/browser claims.

## Read-only example audit

The [audit inventory](audit/audit-summary.json) covers:

- ten tutorial pages: 500 preformatted blocks, of which 390 are classified as
  Prolog examples; 26 Prolog blocks contain quoted-text/native-API review hints;
- 44 Prolog sources: deployment/shared databases, actor examples, Jev helpers
  and the two service adapters; all parse without executing directives;
- 21 statechart XML files: all parse as XML; fourteen extracted fragments merit
  review. XML attribute quoting and nested XML are not themselves Prolog string
  literals. Not every embedded Prolog fragment was parsed or executed.

The inventory is a review aid, **not** a claim that all examples have been run.
HTML protocol/JavaScript JSON examples keep JSON strings; their quotes do not
change with the Prolog reader. Inline prose, book examples and arbitrary dynamic
JavaScript-generated commands are outside this inventory.

Five unedited actor-profile tutorial queries run through disposable ACTOR
WebSocket sessions: receive/format, guarded receive/format, receive timeout,
private-source price and private-source list. Fixtures remove only the UI `?-`
prefix and final query terminator to frame the unchanged query fragment for
transport. Source text and format literals are not rewritten. A slice limit of two
verifies the exact single result without presuming that a
one-element slice has exhausted a choicepoint.

The other checks execute the unedited word-list grammar (both expected parses),
load the common/actor/n3 shared source and query price/ancestry/marker facts, and
confirm model/Jev native-string guards without calling a provider. All example
file hashes still match the pre-audit inventory.

### Findings

| Examples | Finding and migration consequence |
|---|---|
| Tutorial receive/format and private `src_text` snippets | The five selected public-interface examples pass unchanged in both modes. |
| `examples/actors/02 grammar.pl` and ordinary shared facts | Word-list terminals and atom/numeric data do not depend on native string literals. The checked grammar and shared-source queries pass in both modes. No numeric DCG terminals or double-quoted URI options were flagged in the parsed source inventory. This does not certify every possible embedded query. |
| `examples/actors/07 selective-receive.pl`, `11 ring.pl`, `12 dining_philosophers.pl`, `19 promise-and-yield.pl` | Their actual string literals feed format or source-text inputs already supported by the configuration. They are static compatible candidates; full ring/dining/promise demonstrations were not executed in this audit. |
| `examples/actors/21 model-actor.pl` | `chat_exchange/4` tests `string(Text)` and uses `string_length/2`. A character-list prompt follows its `error(invalid_prompt)` branch; the read-only check confirms this. Its history-size logic also needs review. |
| `examples/statecharts/19 model-statechart.xml` | The datamodel similarly requires native string prompts and lengths. Static finding; no live model request was made. |
| `examples/services/model_service.pl` | The host validation accepts native strings and rejects character lists. The pure `message_text/3` check confirms this without provider calls. Input and reply conversions need a deliberate portable/application boundary. |
| `examples/services/jev_service.pl`, `examples/jev/deployment_observation.pl` | `valid_text/1` and `must_be(string,Text)` reject portable character lists. The service's pure validator check confirms the mismatch. Actor examples 23/24 and statechart 20 delegate to that boundary. |
| Jev question-building / replies (`examples/jev/jev.pl`, `jev_http.pl`, actor 23 and statechart 20) | JSON must still receive native library text. Portable prompts/descriptions/replies need explicit conversions and output-expectation review; replacing every host string blindly would produce the wrong JSON/data representations. This broader behavior is not verified here. |
| Statechart 08 and nested chart 17 | Quote hits are format text and nested XML respectively. They are not proof of a native-string dependency; complete statechart runtime checks remain separate. |

The next application migration batch should handle the model/Jev text boundaries
with mocked providers, retaining provider JSON types and resource limits. It
should cover both requests and replies, then decide what example edits are
actually necessary. No such example or service repair is included here.

## Separate diagnostics and preservation

The earlier T3 supervisor scheduling and SGML import diagnostics are not rerun,
reclassified or repaired. Four historical T4 representation failures remain in
the previous report; this batch supplies explicitly selected contracts for both
configurations and a complete passing T4 run per mode.

Early audit-harness attempts used HTTP `/call` for ACTOR examples or included the
UI terminator inside its query-fragment parameter. Those were fixture errors,
not example/runtime failures. The final runner uses ACTOR WebSocket sessions,
explicit metadata framing, bounded event selection and its own module context.
The initial framing/profile logs remain labelled separately; they do not feed
any pass count. No public-node policy was relaxed to make examples run.

[Preservation](preservation.json) verifies unchanged runtime modules, original
engines/libraries, installed launchers/targets, pin, n3/n5 identities and every
audited example. The demonstrator working tree remains clean. Book examples and
all previous reports are untouched.

## Reproduction

From the native checkout, select the verified separate SWI executable with
`SWIPL=/path/to/separate/swipl`, and run `./tools/test.sh TEXT T4_NATIVE` once
with `WP_EXPERIMENTAL_TEXT` absent and once with it set to `portable-text-0.2`.
Keep each mode's logs separate.

The read-only inventory is reproducible with `audit_examples.py --swipl ...
--native-root ... --demonstrator-root ... --output ...` in this directory. The
example checks use the same separate executable, `-s example_checks.pl`, and
`-g 'run_tests(portable_text_example_checks),halt'`, with
`WP_AUDIT_DEMONSTRATOR_ROOT` pointing to the demonstrator checkout. Run once per
mode. The stored tutorial query inputs retain their page IDs and source lines.
