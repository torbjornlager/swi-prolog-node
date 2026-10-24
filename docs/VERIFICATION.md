# Clean native snapshot verification

Verified before creating the new Git history, using the existing separate
PCRE-enabled SWI-Prolog 10.1.18 build containing Jan's `09b6299` fix.
No installed engines or existing n3/n5 processes were changed.

All 71 native Prolog/schema files are byte-identical to the preceding native
rehearsal. No runtime code was removed. The existing 20 T5 test bodies are
byte-identical; only historical-peer materialization changed. Three additional
fixture checks verify the pinned hash, corruption rejection and extracted files.
The 53 fixture files match their historical source hashes and retain its license.

The tests below ran with no `.git` directory in the snapshot, demonstrating
that T5 and package loading no longer depend on retained ancestry.

| Gate | Result |
| --- | --- |
| LINT | PASS (0.132 s) |
| T0 | PASS (7.228 s) |
| T1_NATIVE | PASS (0.573 s) |
| T2 | PASS (6.677 s) |
| T3_NATIVE | PASS (36.258 s) |
| T4_NATIVE | PASS (50.863 s) |
| T5 | PASS (1.205 s) |
| T1_INTEGRATION | PASS (0.185 s) |
| T3_INTEGRATION | PASS (4.102 s) |
| T4_INTEGRATION | PASS (1.644 s) |
| browser-equivalence | PASS (0.078 s) |
| package-loader | PASS (0.236 s) |

The first full native T4 run passed all 983 tests. The historical peer and test
nodes used temporary processes and fresh ports. External integration used the
unchanged demonstrator asset tree. Browser equivalence also checked schema
identity. Full process logs and the pre-replacement backup are retained privately
outside this repository rather than copying local paths and old investigation
records into the new public-facing snapshot.
