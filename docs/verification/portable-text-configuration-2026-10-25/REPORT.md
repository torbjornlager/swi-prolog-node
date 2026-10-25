# Isolated SWI portable-text configuration — 25 October 2026

Status: **experimental source candidate, not a deployment or adoption decision**.
The installed runtimes, launchers, dependency pin and n3/n5 are unchanged.
The public language defaults and book examples are unchanged.

## Configuration and scope

`WP_EXPERIMENTAL_TEXT=portable-text-0.2` selects character-list reading once
when `text_config` loads in a disposable process. Absence retains native-string
reading. This is a process configuration, not an option a client can submit.
It does not change the host `user` module or SWI library reader flags.

The selected reader is used for HTTP goals/templates/options, WebSocket
terms/options/input, HTTP term input, source-policy checks, source-rewriting
passes, restored/copied source, remote answer decoding, and statechart
expressions/options. Private actor modules and per-node shared-database modules
receive the selected module flag before source compilation. Shared source loaded
from text, a file or a URI converges on that same shared-database loader.
Reloads and a child actor's view of a shared fact have dedicated regressions.
Already constructed `src_list` clauses retain numbers and variable relationships;
there is no recursive data conversion.

Host implementation modules remain compiled with native strings. Trusted host
code or trusted shared source can still explicitly change host flags; this is
an isolated configuration, not a new sandbox policy forbidding owner actions.

## Native-library boundary audit

| Boundary | Treatment |
|---|---|
| JSON, HTTP headers, XML input, output buffers, logging/configuration files | Keep native library text representations; JSON strings remain JSON strings. These are not Prolog double-quoted literals. |
| Source content and byte-limit checks | Existing `source_utils:text_to_string/2` converts accepted source text to native strings for stream/library operations; selected readers then parse the contents. Numeric data inside clauses is not converted. |
| Remote source options | Internally materialized native-string `src_text` and native-string `src_uri` fields are explicitly emitted as atoms in experimental mode. This converts a documented text field, not arbitrary application terms. |
| Actor `format/1-2` guards | The precompiled I/O template, generated prelude and sandbox scanner now inspect character lists as well as code lists; a character-list `~@` cannot evade the callback guard. |
| Prompt/terminal JSON rendering | In experimental mode proper character lists become JSON text; unrelated terms keep ordinary term rendering. |
| Statechart expressions and supplied source | Read under the same selected literal convention; trusted interpreter implementation code stays native. |
| Native string-returning extensions | Still return native strings. Portable application code must explicitly convert, e.g. `string_chars(Native, Chars)`, before relying on list/portable-wire semantics. No blanket native-string-to-list traversal was added. |
| URI and Boolean identifiers | Existing strict typing remains. Use URI atoms and Boolean atoms; double quotes do not grant extra accepted URI or Boolean representations. |

**Important remaining boundary:** a native string and a double-quoted portable
literal have the same textual spelling on the existing protocol. This experiment
does not preserve opaque native-string identity across a character-list reader.
The old exact-native-string transport assertions therefore fail in experimental
mode. Native-extension usage and examples still require an adoption/migration
audit; passing the portable subset is not a claim that every SWI extension is
portable. Error envelopes retain existing host diagnostic spellings.

An exploratory blanket rejection of native strings in term writers was removed:
it incorrectly turned host syntax-error context strings into HTTP 500 errors.
The retained code uses explicit known text-field conversions and preserves
ordinary error reporting. No new wire encoding or native-string protocol tag
was introduced.

## Verification

The conformance repository's
`reports/2026-10-25-swi-portable-text-final-r2/COVERAGE.md` links all definitive
raw reports and the default-reader control. Both use the same archived Trealla
source and the same separate Unicode JSON candidate, with SWI working-source
hashes recorded as an explicit overlay. Disposable peer trust is restricted to
loopback; production trust settings were not changed.

- Portable-text 0.2: **26/26 on each caller/peer direction** with the separate
  Trealla JSON candidate; **52/52 total**.
- Shared actor, language, copying, worker, promise, synchronous-wait and
  cross-runtime HTTP/ACTOR packs: **45/45 per runtime, 90/90 total**.
- Default SWI reader control: the same 90 required selections pass; text remains
  SWI 4/26 and Trealla 25/26 (the latter's SWI-peer literal assertion fails).
- Unmodified Trealla v3.14.10 control: configured SWI 26/26; Trealla 22/26.
  Its four supplementary-Unicode JSON failures remain the separate #1181 issue.
- Final focused TEXT tier: **21 named tests / 26 parameter selections pass in
  each mode**, including shared DB reload/actor visibility and generated I/O.
- Default-reader native tiers TEXT/T0/T1_NATIVE/T2/T3_NATIVE/T4_NATIVE/T5 pass
  in the recorded complete control run. The final added generated-I/O regression
  also passes separately in both modes.
- Experimental T0/T1_NATIVE/T2 pass; T5 passes again after restoring ordinary
  error reporting. Experimental T4 runs all existing assertions and has exactly
  four representation differences, listed in DIAGNOSTICS.md. No assertions or
  timeouts were relaxed.
- T3 exposed intermittent supervisor-fixture failures and a one-off SGML option
  import failure; preserve these as separate diagnostics, not text-contract
  failures or a claim that the entire experimental native suite is green.
- All 47 conformance-runner regressions and validation of the 18 definitive
  reports pass. Layering and whitespace checks pass.

No browser/GNU portable-text configuration, invalid-encoding policy, performance
benchmark, blanket extension conversion or book-example migration is claimed.
Do not enable this configuration on n3 until a separate adoption batch addresses
those remaining surfaces and the retained native-suite diagnostics.

## Running it again

From trinity-conformance, use `adapters/local_portable_text.py` with the normal
explicit runtime/repository/output paths and these candidate flags:

```
--swi-working-tree-candidate --swi-portable-text --shared-checks \
--trusted-loopback-transport
```

The adapter archives committed source and overlays only SWI `prolog/` files,
records their hashes, selects the environment variable only for its owned SWI
process and stops both owned nodes afterward. Use the separately patched Trealla
binary **and its adjacent library** for the 26/26 Unicode candidate result.
Omit `--swi-portable-text` for the default-reader control; use an unmodified
v3.14.10 executable/library for the Unicode limitation control.

Native focused checks are `SWIPL=/path/to/separate/swipl ./tools/test.sh TEXT`,
once with the environment variable absent and once with it set. This selects
language readers, not the host command-line REPL's literal convention.

Commit preparation removes one redundant final blank line from text_config.pl;
this has no semantic effect. Raw logs and embedded patch context retain their
original whitespace; source/document whitespace checks exclude those evidence
formats. Test-run overlay hashes preserve the original tested bytes.
