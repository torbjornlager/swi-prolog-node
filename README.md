# SWI-Prolog Web Prolog node

Native SWI-Prolog implementation of Web Prolog, extracted from
[trinity-demonstrator](https://github.com/torbjornlager/trinity-demonstrator).
The SWI pack is still named `web_prolog` (version 0.2.0). Existing
`library(web_prolog)`, selective layer imports and `load.pl` remain compatible.

This repository starts with a clean native-package snapshot. Earlier research,
review documents and investigation logs are not part of its Git ancestry.
The complete pre-extraction history remains in the original demonstrator and
in a separately verified private backup. See [provenance](docs/ORIGIN.md).

## Load and test

```sh
swipl load.pl
SWIPL=/path/to/verified/swipl ./tools/test.sh
```

The default runs LINT, T0, T1_NATIVE, T2, T3_NATIVE, T4_NATIVE and T5 in fresh
processes. T5 starts temporary peers on fresh ports using the checksummed,
byte-identical historical server in [tests/fixtures](tests/fixtures/README.md).
It needs no historical Git tag, network fetch or existing n3/n5 process.
All original T5 interoperability assertions are preserved.

## External demonstrator assets

The native API works without a browser asset tree. To serve the existing
frontend and run its integration selections:

```sh
WP_ASSET_ROOT=/path/to/trinity-demonstrator \
WP_WASM_SOURCE_DIR=/path/to/assembled/browser-prolog \
SWIPL=/path/to/verified/swipl \
  ./tools/test.sh T1_INTEGRATION T3_INTEGRATION T4_INTEGRATION
```

The demonstrator's `tools/package_wasm_prolog.py` assembles the five browser
Prolog modules plus this package's `prolog/web_prolog/wasm/sxml_schema.pl`.
Its equivalence tool accepts `--native-root` and `--wasm-dir` and rejects schema
drift. Treat assembled schema files as generated copies of the selected native
revision, not independently maintained sources. Existing URLs are preserved.
The DTD and default shared database remain native package files.

`interpret_example/1` uses `WP_ASSET_ROOT/examples/statecharts` when configured;
unset configuration retains its original colocated path. Ordinary source
loading, sandboxing and URI resolution are unchanged. The browser suite and two
legacy colocated-layout assertions run in the original demonstrator checkout.

## Documentation and boundaries

The [runtime README](prolog/web_prolog/README.md) contains implementation details;
the shared language manual and tutorials remain in the demonstrator. Native
architecture/specification documents are retained under `docs/`; the layering
plan is historical design context, not a second language manual.

Separating this repository does not switch the demonstrator to a new native
dependency, migrate Docker/CI assembly, update installed engines or restart
live n3/n5. Those changes require separate integration work.

### Runtime-bound supervisor child specifications

Public supervisor admission inspects known child starts without binding unknown
specifications, option lists, entries or start goals. Unknown specification data
is deferred to execution rather than treated as an opaque executable variable.
After complete API normalisation, the behaviour invokes its registered node guard
before initial creation, nested supervisor startup or a dynamic start request.
The guard checks the selected child goals in their source modules under the
current public profile and sandbox policy. Existing per-child spawn/source checks
remain active. Malformed specifications retain the constructor's validation
errors, and guard checks preserve shared variables.

The optional behaviour-layer guard hook keeps node dependencies out of standalone
supervisor code. Known forbidden starts still fail during admission; runtime-bound
forbidden starts fail before any initial child is created or dynamic request is
sent. No public predicate, protocol or lifecycle policy is added. Blacklist mode
remains a curated prototype policy, not a complete security boundary.

`tests/tiers/node/supervisor_admission_tests.pl` covers nonbinding admission,
malformed/duplicate/nested data, sharing, private source and rejection under both
sandbox modes. It is included in `T4_NATIVE`. Full successful supervisor startup
in whitelist mode retains a separate pre-existing internal-startup restriction;
this batch does not exempt framework loops or claim complete whitelist support.
Verification, shared conformance and remaining findings are recorded in
[`docs/verification/runtime-supervisor-admission-2026-10-24/REPORT.md`](docs/verification/runtime-supervisor-admission-2026-10-24/REPORT.md).

This repair was evaluated as an explicit working-tree candidate over the unchanged
demonstrator dependency pin, using separate verified engines and disposable nodes.
The dependency pin, installed runtimes and live n3/n5 were not updated or restarted.
Promoting the source through a reviewed pin update remains a separate step.

### Nested spawn validation before source fetching

Public admission of plain `spawn/3` validates a ground option list with the
native runtime schema before inspecting or fetching its source. Unknown options,
invalid values (including later duplicates) and malformed lists cannot trigger a
URI fetch first. Recognised framework metadata retains its existing handling.

A proper option list containing variables is inspected without binding them;
source fetching is deferred until runtime option validation succeeds. Pending
source may supply a procedure that is not yet defined during admission. That
missing-procedure check is deferred, while known forbidden calls remain rejected.
The existing runtime profile and sandbox checks still check the loaded child goal
before activation. Source ordering, variable sharing, URI origin restrictions and
source-size limits remain active in both blacklist and whitelist modes.

This is a plain `spawn/3` admission repair, not a general change to wrapper option
schemas. Literal invalid options can still fail admission before the submitted
query executes; the corresponding runtime-bound validation error remains catchable
inside the query. Blacklist mode retains its prototype qualification above.
The [verification report](docs/verification/spawn-source-validation-2026-10-24/REPORT.md)
records regression and conformance results. The demonstrator pin, installed
runtimes and live n3/n5 remain unchanged.
