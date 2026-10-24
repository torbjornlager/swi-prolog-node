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
