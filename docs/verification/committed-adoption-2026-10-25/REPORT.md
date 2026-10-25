# Committed native SWI adoption checkpoint — 25 October 2026

Selected native commit: `abbc56f3d5104bd6d40d2ed5f99fe6199d75c4a8`.
Its runtime tree includes the separately committed cyclic-answer/exception and
character-list term-output repairs. Diagnostic documentation is committed
separately. The demonstrator pin now selects this exact revision.

All native/integration tiers pass via the demonstrator pinned runner: LINT,
T0, T1_NATIVE, T2, T3_NATIVE, T4_NATIVE, T5 and T1/T3/T4 integration. Module-origin,
startup, pin and runner checks pass. The original default/native assertions are
unchanged. Logs are in the demonstrator's
`docs/verification/committed-adoption-2026-10-25/pinned-integration/` directory.

An independent detached checkout of this revision also passes TEXT in both modes
and full T4_NATIVE with `WP_EXPERIMENTAL_TEXT=portable-text-0.2`. Local logs and
[checks.json](checks.json) record those exact-commit runs.

n3 now runs this immutable selection through the demonstrator's strict pinned
loader, with character-list reading explicitly enabled. Host/library modules
retain native strings. Native package defaults, installed engine and repository
access are unchanged. The launcher checks HEAD, tracked/untracked runtime drift
and the selected engine identity before starting. Earlier source/launcher
snapshots remain available for rollback. Subsequent results-only commits do not
silently advance the selected deployment revision.

See the [complete adoption and deployment record](../../../../trinity-demonstrator/docs/verification/committed-adoption-2026-10-25/REPORT.md)
for the demonstrator/Trealla selections, browser checks, live interoperability,
rollback paths and separate unresolved diagnostics. This is local adoption of
the configured text mode, not a new ISO or cumulative cross-runtime baseline.
