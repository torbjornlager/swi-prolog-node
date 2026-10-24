# SWI runtime-bound supervisor admission — 24 October 2026

## Repair

The admission walker previously returned an unknown child list as [Module:Var],
which made library(sandbox) inspect a variable as executable code and reject the
whole query before its receive or catch could run. Child/start clause heads could
also manufacture structure while inspecting unknown data.

The walker now inspects known structure without binding specification, option,
entry or start variables. Unknown specification data is deferred, not represented
as an executable variable. Known starts still undergo admission checks. Context
qualification is retained, and no application terms are copied to break sharing.

This deferral is paired with a behaviour-layer guard hook. The supervisor APIs
normalise the complete specification first, then invoke registered guards before
initial creation, nested startup or dynamic request dispatch. The node registers
a guard that checks the selected actual starts in their source modules under the
current public profile and sandbox policy. Existing per-child spawn/source checks
remain active. A failing registered guard cannot be mistaken for an absent hook.
Standalone behaviour code retains its downward-only dependencies and no node
policy applies when there is no public execution context.

No blanket primitive exemption for internal supervisor loops, public API, wire
protocol, lifecycle policy, engine patch or dependency-pin update was added.
Blacklist mode remains a curated prototype policy, not a complete security boundary.

## Verification and important qualifications

- New focused unit group: **28 parameterised checks pass** across 12 named tests.
  These cover nonbinding/partial data, runtime lists, unchanged malformed and
  duplicate errors, static and runtime forbidden goals, nested rejection before
  startup, dynamic rejection preserving a sibling, sharing and private source.
- Rejection/admission checks run in both blacklist and whitelist modes. Successful
  startup/private-source execution is tested in blacklist mode; a pure private
  source predicate is checked in both modes. Full whitelist supervisor startup
  retains its pre-existing framework restriction, described below.
- Full **T4_NATIVE passes** (995 registered test selections, with parameterised
  variants). The new group is included in that tier.
- Layering lint passes: 513 import edges checked.
- Full **T3_NATIVE has one unresolved failure** among its 294 registered selections:
  supervisor_restart:group_monitor_failure_reclaims_live_provisional_replacements.
  The original failed tier log remains in T3_NATIVE.log; it is not waived or called
  green. No existing assertion or timeout was relaxed.
- A predeclared isolated comparison of that failing test, three archived-source
  runs and three candidate runs, passes all six. Candidate logs record an empty
  guard registry in this native-only tier, which has not loaded the public node
  glue. These controls do not reproduce or explain the full-sequence failure and
  do not establish that it is fixed or pre-existing. Broader lifecycle tracing
  remains separate.

regressions.json records exact commands, engine identity and exit codes. The
separate complete SWI candidate is the previously verified 10.1.18 build with
core 09b6299 and HTTP shutdown candidate; version alone does not identify it.
No installed executable was used or replaced for these tests.

## Archived-source controls and whitelist restriction

A temporary git archive of base f316e65503bff863dfbd2e182f7487988c91480c reproduces
opaque-initial-list rejection: rejected(error(instantiation_error,_)), with the
specification variable still unbound. The candidate accepts admission and leaves
that variable unbound. before-controls.json and corresponding logs retain the
exact commands/results; the archive was removed afterward.

Both archived and candidate literal whitelist startup fail while library(sandbox)
unfolds the internal sup_init/with_startup_scope path to nb_setval. That existing
restriction is not caused by runtime-list deferral and was not removed. Exempting
more framework code would require separate policy review and regressions. Early
new-test drafts also used whole-body trusted orchestration and a control-guarded
receive helper as whitelist probes; those exercised other existing whitelist
restrictions. Final tests separate selected constructor admission/runtime rejection
from trusted fixture orchestration, without changing any existing test.

## Shared conformance

Unchanged committed public-interface manifests ran on disposable ACTOR/blacklist
SWI and Trealla nodes:

| Selection | Result |
| --- | --- |
| Child specifications | **12/12**, SWI 6/6 and Trealla 6/6 |
| Local runtime creation-option validation | **12/12** |
| Admission comparisons | **20 complete diagnostic observations**, no probe errors/timeouts |

SWI's valid runtime initial list now starts and halts normally (AP-002). A missing
start supplied at runtime now enters the query and is caught as the constructor's
missing_start_option error (AP-004). Static controls remain intact. Trealla's
committed nonbinding repair remains unchanged. SWI AP-009 still attempts literal
URI preparation before rejecting the later unknown option; that separate finding
is not fixed. Historical matrices/failures are not overwritten by this checkpoint.

Reports/matrices are in the sibling trinity-conformance repository under
reports/2026-10-24-swi-runtime-specs-child-specs,
reports/2026-10-24-swi-runtime-specs-admission-probes and
reports/2026-10-24-swi-runtime-specs-creation-validation. All raw schema/accounting
checks and all 29 runner regressions pass. This does not erase the failed broad
T3 tier or establish full whitelist, lifecycle, remote or browser certification.

## Candidate selection, provenance and preservation

The ordinary conformance adapter initially refused the dirty native checkout,
correctly enforcing the clean dependency pin before starting any fixture. Its
strict default still invokes the unchanged demonstrator pin checker. An explicit
--swi-source-candidate test-only option permits this working-tree patch only over
the same exact pinned base revision, verifies package entry files, records pin
bytes/hash/source mode and checks the pin again after teardown. Three regressions
cover strict default behavior, explicit metadata and rejection of a changed base.
No production launcher or pin checker was modified.

patch-inputs.json identifies base revision and final changed-file hashes. Shared
fixture provenance additionally records .pl source hashes, source status, commands,
configuration and executable/library identities. All final source/manifest inputs
match their recorded snapshots. The native patch was uncommitted while tested;
its eventual containing commit and these hashes identify the exact candidate.

SWI is evaluated from its separate native repository. Trealla remains at committed
7220bb5 using the separate unmodified v3.14.10 engine and matching library. All
fixture preservation checks are true, including the unchanged dependency pin and
live n3/n5 identities. Each disposable pair stopped. Installed executable targets
and hashes match the prior preservation record. No installation, launcher,
restart/reload, repository-access or dependency-pin change occurred. Demonstrator,
Trealla runtime and book sources remain unchanged.

Remaining work: the broad T3 failure, whitelist startup policy and literal-source
validation order need separate investigation/review. Promotion through a native
commit/dependency-pin update is also separate; this checkpoint does not deploy it.
