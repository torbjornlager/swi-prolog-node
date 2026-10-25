# Current character-list adoption checkpoint — 25 October 2026

**Regular n3 has not been switched.** The focused check confirms consistent
character-list reading and portable round trips on the current repaired code,
but finds three output-alignment mismatches and the known model/Jev input
boundaries. Adopting the reader now would expose those differences to users.
No production runtime code, examples, installed engine, dependency pin or live
n3/n5 process was changed by this checkpoint.

## Configuration and scope

Two disposable n3-like nodes use the current native working runtime files over
`b61270d`, including the computed-answer cycle repair. One retains native-string
reading; the other sets `WP_EXPERIMENTAL_TEXT=portable-text-0.2` before loading.
Each uses a fresh port, the verified installed SWI 10.1.18 prefix, the existing
n3 profile/sandbox/origins/assets and resident-service startup, and the required
SGML/option preloads. The only shared DB addition is a temporary fixture containing
`checkpoint_shared("abc").`. No deployed shared DB file is edited.

The Trealla reference is the unchanged public n5, now running its verified
`write/1` repair with unmodified v3.14.10. Cross-node probes use fresh sessions,
complete their promises and halt their own toplevels. The temporary nodes are
stopped after the check. Pure service validation calls never invoke a provider.

[Provenance](results/provenance.json) records source/binary hashes, exact commands,
ports and PIDs. [Preservation](results/preservation.json) covers runtime sources,
engines/libraries, installed process identities and pin. The live process commands
and start times for n3, n5, its frontend and the auxiliary listener are unchanged.

## Results

| Check | Default strings | Experimental chars |
|---|---|---|
| Public goal/Unicode/shared-DB readers | pass | pass |
| HTTP and WebSocket private source | pass | pass |
| Constructed `src_list/1` actor source | pass | pass |
| RPC character-list/variable-sharing round trip, both directions | pass | pass |
| Promise callback/retry/sharing round trip, both directions | pass | pass |
| Current computed-cycle rejection | pass | pass |
| Required public controls | **16/16** | **13/13** |
| Output alignment diagnostics | ordinary mode matches current Trealla explicit-list behavior | **3 mismatches**, kept separate |
| TEXT/library-boundary tier | **40 selections pass** | **40 pass** |
| Read-only representative example checks | **10 pass** | **10 pass** |

The required controls and diagnostic selections are intentionally separate.
The example suite includes assertions that character-list prompts are rejected
by the existing native-string guards; its passing result does **not** certify
that model/Jev examples are migration-ready. These overlapping suites are not
added into a cumulative language conformance total. Full T2/T4, WASM, GNU and
all book/tutorial examples were not rerun in this bounded checkpoint.

### Output mismatch

| Query | Current n3/default | Temporary n3/chars | Current n5/Trealla |
|---|---|---|---|
| `write(abc)` | `abc` | `abc` | `abc` |
| `write("abc")` | `abc` (native string) | `abc` (character list rendered as text) | `[a,b,c]` |
| `write([a,b,c])` | `[a,b,c]` | `abc` | `[a,b,c]` |
| `writeln([a,b,c])` | `[a,b,c]` | `abc` | `[a,b,c]` |

[Current live controls](live-output-controls.json) confirm the ordinary n3/n5 columns.
The reader alignment succeeds: the temporary node's literal is exactly
`[a,b,c]`, including in options, private source and the shared database. The
misleading output comes later. `actor_io_template` and the generated prelude in
`actor_io_support` forward a raw term for `write/1` and `writeln/1`.
`node_response:terminal_output_to_json_string/2` calls the prompt/text conversion
helper, which interprets a character list as text in chars mode. A term-writing
operation is therefore treated as a text-presentation operation. `format/2`
continues to render text correctly in both modes. This is not a reader failure
or evidence that the term was secretly a native string.

The smallest next runtime repair is to render the term for `write/1` and
`writeln/1` before entering the text-output bridge, in both the executable and
generated prelude. Preserve prompt/format character-list support rather than
removing the general text conversion. Keep variable sharing, output routing and
other sandbox restrictions intact. Add explicit list-writing tests in both
modes and compare them with Trealla.

### Model/Jev application boundaries

[Pure validator observations](service-boundaries.json) use text produced by the
selected reader and native-library-string controls:

| Input | Model validator | Jev validator |
|---|---|---|
| Default reader `"hi"` | accepted | accepted |
| Character-list reader `"hi"` | **rejected** | **rejected** |
| Explicit native string control, either mode | accepted | accepted |

`model_service:message_text/3` and `jev_service:valid_text/1` require native
strings and native-string lengths. The model actor example also rejects a
character-list prompt before its service call. These confirm the earlier audit;
no model inference, Jev provider request, chargeable call or live service
configuration update was made.

A subsequent application-boundary batch should explicitly convert accepted
portable text to native library strings at service entry and define portable
reply conversion. Preserve existing length/history limits and provider JSON
string values; use mocked providers for request/reply tests. Corresponding
example-level native-string guards need a deliberate migration decision too.
Simply enabling the reader flag cannot fix these consumers.

## Decision and reproduction

Keep regular n3 in its current string-reading mode for now. Resolve term-writing
first, then the model/Jev boundaries before treating character-list reading as a
complete tutorial deployment configuration. No ISO-mode or global flag change
was applied to a running process.

`run.py` recreates the disposable nodes and reruns the public controls and existing
TEXT/example checks. It refuses to overwrite its `results/` directory. Copy the
report harness to a new dated directory or select a fresh output path when
repeating; its paths identify the current local runtime and durable n3 launcher.
The existing source-relative TEXT/example paths must remain valid when copied.
`service_boundaries.pl` independently runs only the pure validators; its exact
commands and results are retained in `service-boundaries.json`.

[Raw observations](results/observations.json), [suite commands](results/suite-checks.json)
and [validation](validation.json) retain all results. Existing historical reports,
prior pending repairs and their assertions are preserved. Nothing was committed
or pushed in this batch.
