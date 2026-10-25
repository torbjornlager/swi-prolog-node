# Diagnostics kept outside the portable-text pass counts

The final T4 experimental run is `final-t4-chars.log`; it preserves all 1041
named tests (and parameterized selections), assertions and timeouts. Four fail:

| Test | Observed difference |
|---|---|
| `node:double_quotes_fixed_as_string_on_the_wire` | Explicitly requires native string `"ab"`; configured readers return `[a,b]`. |
| `node:rpc_term_text_is_canonical` | Its native string `"s"` component reads as `[s]`; the rest of the canonical-term test is unchanged. |
| `public_goal_guard:dcg_composed_native_literal_stays_codes` | Explicitly expects `[97,98]`; configured literal terminals yield `[a,b]`. |
| `cross_node_lifecycle:remote_toplevel_answers_keep_exact_terms` | Explicitly expects opaque native string identity for `"s"`; the configured peer returns a character list. |

These are migration obligations/extension limitations. They were not deleted,
relabelled as passes, or altered to make the experimental suite green.
The default-reader complete run (`final-tiers-default.log`) passes those tests.

Earlier exploratory logs remain for traceability. `final-tiers-chars.log`
includes the since-removed native-string rejection experiment: its T5 HTTP 500
and several extra wire failures do not describe the retained implementation.
`recheck-chars.log` confirms T5's unchanged golden assertions pass after its
removal. A transient browser fixture read-header error in the earlier T4 run
also does not recur in the final full T4 run.

The T3 runs have intermittent supervisor restart-fixture failures: the numeric/
brutal-shutdown case failed in the first experimental full run, and the
cleanup-error case failed in a later full T3 run. Neither test contains a
double-quoted user literal. The fixture has a zero-time receive for the second
supervisor termination notification; that is a plausible scheduling-sensitive
step, not a confirmed trace of these particular failures. `supervisor-controls.json`
records a fixed three-process comparison per reader mode with the exact original
two tests and their unchanged assertions/timeouts. No lifecycle or fixture repair
is included here.

One T3 recheck also encountered `sgml:select_option/3` missing on its first XML
parse. A separate test-only process with `sgml:use_module(library(option))`
passes XML parsing; no installed library or runtime source was changed to mask
that diagnostic. Full T3 still cannot be claimed green for experimental mode.

The conformance adapter initially selected the wrong runner for baseline-format
manifests (a harness KeyError, no node assertion executed). It now dispatches
those manifests to the existing baseline runner. Initial remote-actor tests also
lacked Trealla's required explicit trusted-loopback policy: the same permission
errors occurred with ordinary readers. Final runs set that policy only on the
disposable peer and pass. No transport-identifier repair was necessary.

Historical reports predating this experiment are untouched. Development runs
in the conformance repository are intermediate evidence, not additional
conformance coverage. In particular, the early default control's source-hash
preservation check noticed authorized source edits during that exploratory run;
the later definitive candidate/control snapshots remain stable throughout.
