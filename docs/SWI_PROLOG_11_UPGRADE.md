# SWI-Prolog 11.0.0 upgrade

Validated on macOS on 2026-11-19 using the official universal 11.0.0-1
installer, unpacked into a separate staging directory before installation.
The previously installed engine was 10.1.19.

- [Release announcement](https://swi-prolog.discourse.group/t/ann-swi-prolog-11-0-0-stable/9919)
- [Official stable downloads](https://www.swi-prolog.org/download/stable)
- Installer: `swipl-11.0.0-1.fat.pkg`
- SHA256: `6085ea66dc4a08d95a6343df99aa5d9c491faf93504b300cebaab4c59fd69147`

The SHA256 matched the official download page. `pkgutil --check-signature`
confirmed Jan Wielemaker's Developer ID Installer signature and trusted Apple
notarization. The staged executable reported 11.0.0 and loaded `library(pcre)`.

## Temporary module lifecycle

SWI-Prolog 11 changes `in_temporary_module/3`: cleanup abolishes predicates
immediately, but the empty module is reclaimed later when unreferenced and
`gc_code` is `module`. The upstream default is `clause`, which retains empty
modules. Loading this package's isolation layer therefore sets the process-wide
`gc_code` flag to `module` when that flag exists. Older engines without the flag
retain their existing behavior.

The first native run found six failed assertions in `sandbox_source_names`
that expected immediate disappearance from `current_module/1`. These checks now
require that no defined predicates remain after successful loading, an exception,
or a rejected directive. The explicit probe-predicate absence checks remain.
Overlapping module isolation, reloading and directive rejection tests also pass.
No application admission or sandbox policy was relaxed.

## Verification

The final run passed after enabling module GC and updating the lifecycle checks.
Each tier used a fresh 11.0.0 process. Temporary peers and test ports were used.

| Gate | Result |
| --- | --- |
| LINT | PASS |
| TEXT | PASS |
| T0 | PASS |
| T1_NATIVE | PASS |
| T2 | PASS |
| T3_NATIVE | PASS |
| T4_NATIVE | PASS |
| T5 historical-peer interoperability | PASS |
| WebSocket Origin handshakes | PASS |
| HTTP visitor ownership | PASS |
| T1_INTEGRATION | PASS |
| T3_INTEGRATION | PASS |
| T4_INTEGRATION | PASS |
| Focused sandbox source cleanup and isolation | PASS |

Reproduce with an explicit 11.0.0 executable:

```sh
SWIPL=/path/to/swipl-11.0.0 ./tools/test.sh
WP_ASSET_ROOT=/path/to/trinity-demonstrator \
WP_WASM_SOURCE_DIR=/path/to/assembled/browser-prolog \
SWIPL=/path/to/swipl-11.0.0 \
  ./tools/test.sh T1_INTEGRATION T3_INTEGRATION T4_INTEGRATION
```

Integration requires both asset paths. An initial attempt without the assembled
browser directory failed to serve `/wasm/sxml_schema.pl`; assembling the six
browser Prolog files with the demonstrator's `tools/package_wasm_prolog.py`
resolved this configuration error. Source and live asset trees were unchanged.

The macOS application and framework were backed up before installation. Full
validation logs and the backup are retained locally outside this repository.
The browser WASM engine, demonstrator dependency pin and deployed n3/n5 services
were not upgraded by this validation. Existing historical verification records
continue to describe their original engine versions.
