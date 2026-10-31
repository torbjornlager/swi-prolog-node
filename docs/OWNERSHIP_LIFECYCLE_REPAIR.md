# Ownership and independent monitor follow-up — 31 October 2026

WebSocket teardown used to retract every monitor targeting an owned actor
before requesting its termination. This also erased independent observers'
monitors. `ws_kill_actor/1` now leaves those records to normal actor retirement,
which generates their down/3 notifications. Initial unpublished-spawn failure
cleanup remains separate. The shared conformance controls compare explicit
owner termination with EOF, and include a computing grandchild.

A legitimate-administrator control exposed a related context lookup defect.
`current_owner_context/1` now selects and commits to the authoritative frame
before unifying it with the caller's pattern; a bound false-owner query can
no longer skip an administrator frame and select an outer/public context.
The lifetime_authority native group tests nested and stored actor contexts.
Its foreign-exit assertion now requires an actual throw, rather than allowing
an unbound variable to unify with an expected exception after a normal return.

The original paper assertions, new shared ownership/lifecycle cases and
positive authority controls are rerun separately on pinned sources. No installed
engine or deployed node was changed. Full native results and original-source
controls are preserved in trinity-conformance's dated 31 October report;
pre-existing supervisor assertions that fail in that environment are retained
separately rather than reported as passing.
