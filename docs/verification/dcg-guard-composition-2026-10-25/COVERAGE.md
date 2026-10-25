# DCG composition checkpoint — 25 October 2026

Candidate evidence, not a new published profile requirement. Source/engine
identities and commands are recorded in [REPAIR.md](REPAIR.md).

| Unchanged shared pack | SWI candidate | Trealla committed adapter |
|---|---:|---:|
| language-actor-0.1 | 7/7 | 7/7 |
| copying-isolation-0.1 | 6/6 | 6/6 |
| creation-validation-0.1 | 6/6 | 6/6 |
| child-specs-0.1 | 6/6 | 6/6 |
| **Total shared assertions** | **25/25** | **25/25** |

## Supporting runtime regressions

| Check | SWI | Trealla |
|---|---:|---:|
| DCG HTTP common cases | 2/2 | 2/2 |
| DCG WebSocket common cases, including copied source | 3/3 | 3/3 |
| SWI-native code-list terminal controls (HTTP and WS) | 2/2 | 0/2, expected representation contrast |
| Combined guard unit suite | 46 + 3 sub-tests pass | Not applicable |
| Native T1/T4 partitions | Pass | Not run in this batch |

The supporting manifests are `dcg-http-controls.json` and `dcg-ws-controls.json`.
They retain the two SWI-specific expectations when run against Trealla to expose
the native text difference. Raw reports retain those failures. They are separate
from the unchanged shared manifests and their 50 total passing assertions.

## Experimental portable-text-0.2

| Node | Pass | Fail | Unsupported |
|---|---:|---:|---:|
| SWI native readers | 4 | 22 | 0 |
| Trealla, unmodified v3.14.10 JSON library | 21 | 5 | 0 |

TXT-015 now reaches logical failure on SWI rather than an internal-helper sandbox
rejection. Reader/DCG terminal representation migration is not implemented here.
Supplementary Unicode JSON failures and the cross-node text convention contrast
remain separate. Historical reports are preserved.

No browser, GNU ISOBASE, full remote-runtime matrix, installed-node or deployment
acceptance is claimed by this bounded checkpoint.
