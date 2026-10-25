# SWI character-list term output — 25 October 2026

The term-output blocker found by the preceding temporary-node checkpoint is
repaired in the native SWI candidate. In both ordinary and experimental chars
mode, `write([a,b,c])` and `writeln([a,b,c])` display list syntax. In chars mode,
`write("abc")` consequently displays `[a,b,c]`, matching current Trealla.

**Regular n3 has not been switched or restarted.** Its frozen source and default
string reader remain unchanged; n5, its frontend and both installed engines are
also unchanged. This batch changes candidate runtime files and tests only.
The model/Jev input/reply boundaries remain the next migration task.

## Bounded implementation

Both the precompiled `actor_io_template` and generated `actor_io_support` prelude
send character-list arguments through term rendering before the terminal bridge.
This prevents the chars-mode prompt/text conversion from treating a list term
as literal output text. Rendering uses the existing quoted list representation,
including empty lists and Unicode/space characters.

The change is restricted to proper lists of one-character atoms. Other arguments
retain their existing event payloads: atoms, native strings, numeric code lists,
non-character atom lists, compounds, shared variables and partial lists. Tests
check that validating the candidate list does not bind its variables. No general
term-to-text coercion or new wire envelope is introduced.

Prompt handling and `format/2` are unchanged and retain intentional character-list
text support. The actor's inherited output target is still used. The new helper
is registered alongside the existing hidden I/O prelude predicates so private
`listing/0` remains unchanged. Sandbox policy, stream permissions, reading modes,
source ordering and the compiled/generated prelude selection are unchanged.

## Verification

| Check | Default strings | Experimental chars |
|---|---|---|
| Final TEXT tier | **56 selections pass** | **56 pass** |
| T1_NATIVE | **98 selections pass** | **98 pass** |
| T2 | **145 selections pass** | **145 pass** |
| Full T4_NATIVE | **1529 selections pass** | **1529 pass** |
| Temporary-node public checks | **16/16** | **16/16** |
| Existing read-only example checks | **10 pass** | **10 pass** |

These checks overlap and are not added into a new conformance total. The sixteen
new TEXT parameter selections cover both prelude forms and writers, with ordinary,
empty and Unicode character lists and preservation of other payload types.
Existing prompt/format guards, library string boundaries and exact default-mode
assertions remain intact. The layer dependency check passes (571 edges).

The public checks repeat the previous checkpoint on current working sources,
with real temporary n3-like nodes and current Trealla n5 as the peer. They confirm
consistent goal/private/shared-DB/constructed-source readers, finite local output,
cycle rejection, RPC sharing and promise timeout-callback/retry in both directions.
All three formerly mismatching chars-mode output cases now pass. The public
assertions and expected values were not relaxed.

[Raw observations](results/observations.json), [suite commands](results/suite-checks.json),
[provenance](results/provenance.json) and [validation](validation.json) record
candidate source hashes, engine hashes, commands, ports, PIDs and preservation.
The source base is `b61270d` plus prior pending cycle guards and this term-output
repair; it is a working-source candidate, not a new committed/deployed-head claim.
The selected engine is the already verified SWI 10.1.18 prefix with its prior
core/HTTP fixes. The Trealla reference remains the current unmodified v3.14.10
engine and its deployed write/1 adapter repair.

Initial full T4 checks caught the new helper appearing in private listings in
both modes. The helper was added to `private_listing_hidden/1`; unchanged listing
assertions then passed in the complete reruns. Those initial logs are labelled
`integration-initial-*` and are not final failures or unresolved diagnostics.
Other test assertions and timeouts were preserved.

## Remaining work and preservation

The [preceding service observations](../portable-text-current-checkpoint-2026-10-25/service-boundaries.json)
remain applicable: portable character-list inputs are rejected by the model/Jev
native-string guards. The passing example suite deliberately checks those
rejections and does not certify model/Jev readiness. No provider, chargeable
request or application-boundary repair was made here.

Before selecting character-list reading for regular n3, repair the model/Jev
boundaries with explicit portable/native text conversions and mocked request/reply
checks, preserving length/history limits and JSON string types. Any example-level
native-string guards need an explicit migration decision. Earlier supplementary
Unicode/opaque native-string diagnostics and unmeasured runtime surfaces remain
separate; this is not a rerun of the whole portable-text profile or all nodes.

The shared manual documents list term output separately from prompt/format text
presentation. Book examples, services, installed runtime targets/libraries,
dependency pin, n3/n5/frontends/auxiliary processes and previous reports are
unchanged. All temporary nodes are stopped. Nothing was committed or pushed.

## Reproduction

Select the verified separate SWI executable in `SWIPL` and run
`tools/test.sh TEXT T1_NATIVE T2 T4_NATIVE` once without `WP_EXPERIMENTAL_TEXT`
and once with `WP_EXPERIMENTAL_TEXT=portable-text-0.2`. Keep the logs separate.
`run.py` uses the current source checkout and repeats the temporary-node public,
TEXT and example checks, refusing to overwrite its `results/` directory. Its
source-relative paths and recorded commands identify this local setup; select
fresh output paths when repeating rather than replacing historical reports.
