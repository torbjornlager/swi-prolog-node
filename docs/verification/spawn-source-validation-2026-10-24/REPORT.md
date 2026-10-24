# SWI spawn source validation — 24 October 2026

The working-tree candidate over native commit
`8c90a4dedcee7e6c590a5745fed02fc6b986dcbf` validates plain nested
spawn/3 options before source preparation in the public admission paths.
It reuses actors:validate_spawn_options/2 with the runtime schema; it does not
introduce a second schema or alter wrapper/source-loading semantics.

Ground lists are checked before fetching. Proper lists with pending data defer
source preparation without binding their entries. Known goal checks remain active;
only a missing-procedure error is deferred when pending source may supply that
procedure. Runtime option validation, source profile/sandbox checking and the
loaded child goal guard still precede activation. Origin and size checks remain.
The change does not make blacklist mode a complete security boundary.

## Verification

- Focused spawn_source_validation group: all 34 parameterized checks pass
  (13 named cases), covering both sandbox modes, zero requests on validation
  errors, duplicate validation, pending values/entries, source order, sharing,
  forbidden goals/directives, origins, size limits and runtime guard rejection.
- Dependency graph LINT: passes.
- Full T4_NATIVE: exits 0, all 1008 named cases pass (including parameterized
  cases); existing assertions and timeouts are unchanged.
- Shared runner unit tests: 32 pass.
- Shared creation-option validation: 12/12; child-specification validation:
  12/12 across disposable SWI and Trealla nodes.
- Admission diagnostics: 20 complete observations, zero diagnostic errors.
  AP-009 now reports a spawn_option domain error before entry, replacing the
  source socket error. AP-010 still catches the runtime validation error.
  Admission observations are not counted as conformance passes.

regressions.json gives commands, engine hash, durations and final log names.
before-controls.json and its four logs compare git-archived pre-repair production
source with the candidate using the same new loopback HTTP fixture. Previously,
unknown options were admitted after requesting /safe; now they are rejected with
zero requests. A pending monitor boolean formerly fetched /safe during admission;
it now remains unbound with no fetch. The archived checkout was removed.

During development, two new source-order fixtures were corrected to use distinct
predicates (SWI replaces a static predicate loaded from another source), and the
unsafe-source fixture was corrected to call its unsafe predicate rather than an
unrelated true goal. No existing assertion was weakened. An initial full run
also exposed validation accidentally applied through a helper shared with
`toplevel_spawn/2`; validation was moved to the plain spawn/3 profile branch.
The final full run includes both affected existing tests and passes.

## Conformance and preservation

Shared reports are in sibling trinity-conformance/reports/
2026-10-24-swi-spawn-source-{admission-probes,creation-validation,child-specs}.
Their raw reports, matrices and provenance retain the complete observations.
The fixture explicitly selects native base 8c90a4d as a descendant of the unchanged
demonstrator pin f316e65503bff863dfbd2e182f7487988c91480c. Its strict default still
requires the clean exact pin; no production checker or launcher was changed.
Candidate mode requires an explicit immutable full commit and verifies ancestry.

All fixture preservation flags are true and disposable nodes stopped. The patched
source remained stable during the final runs. Installed-preservation.json checks
installed executable targets/hashes against the earlier preservation record.
No installed engine, launcher, live n3/n5, dependency pin, Trealla source, shared
language manual or book source was changed. patch-inputs.json records the final
patch hashes; source/probe hashes and engine identities are in provenance.json.

The previous batch's intermittent T3 supervisor replacement-cleanup failure and
whitelist supervisor startup qualification remain separate; T3 was not rerun in
this node-layer batch. Wrapper admission, source URI schemes and broader lifecycle
work are unchanged. Pin promotion remains a separate task.
