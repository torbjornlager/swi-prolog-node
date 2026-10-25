# DCG sandbox rejection: guard composition — 25 October 2026

**Follow-up:** the approved repair and verification are recorded in [REPAIR.md](REPAIR.md). The following is the retained pre-repair investigation.

Investigation only. Runtime code, dependency pin, installed engines and n3/n5
are unchanged. The probe loads archived committed native source `786737f`
under the separate verified SWI 10.1.18 runtime. Pending Boolean/URI edits are
excluded. No HTTP server or production node is started or restarted.

## Cause

The isolation layer's `prepared_goal/3` applies the public blacklist rewriter,
then the control-transfer rewriter. Their generic meta-predicate handling both
recognize `phrase/2-3`'s `//` argument and wrap the grammar:

```prolog
phrase(public_goal_guard:'$sandbox_dcg'(M,G), Input)
```

becomes:

```prolog
phrase(control_guard:'$dcg'(M,
    public_goal_guard:'$sandbox_dcg'(M,G)), Input)
```

The outer control guard translates its grammar, yielding a fully applied call
to the inner helper, and sends that call to `runtime_execute_goal/2` for sandbox
checking. The sandbox sees an explicit `public_goal_guard:...` qualification
outside the actor's current module and correctly rejects it under the normal
qualification rule. It is inspecting an implementation wrapper instead of the
original grammar. This is our guard-composition bug, not a SWI engine defect.

## Evidence

[The standalone composition probe](composition-probe.pl) builds goals at runtime
so the compiler cannot pre-expand its `phrase` calls. [Results](results.json)
compare public-only rewriting against the real public-then-control order:

| Grammar | Public guard only | Both guards |
|---|---|---|
| `[a,b]` terminals | succeeds with `[a,b]` | rejects internal sandbox helper |
| Named grammar with `[a,b]` terminals | succeeds with `[a,b]` | same rejection |
| Named grammar with native `"ab"` terminals | succeeds with `[97,98]` | same rejection |
| `{nb_getval(...,_)}` | rejects the forbidden operation | rejects internal helper first |

The existing `public_goal_guard` unit helper tests only the first rewriter.
That explains why its isolated DCG tests do not detect this combined-path bug.
The original experimental TXT-015 source uses `"ab"` but expects `[a,b]`.
Fixing guard composition would expose that separate native-string/DCG-code-list
difference; it does not by itself make TXT-015 pass or adopt portable-text 0.2.

## Smallest proposed repair

Make the DCG rewriters compose without adding a second guard around an already
guarded grammar. A narrow recognition case in the control rewriter can preserve
the sandbox's DCG closure for the same caller module. The existing sandbox DCG
helper already translates the original grammar and runs its ordinary goal
through sandbox validation and control rewriting. Preserve that path and its
reserved-control handling. Do not broadly whitelist the internal module or
exempt arbitrary qualified calls from validation.

Regression tests should exercise the combined isolation/public path, not only
each helper separately: `phrase/2-3`, explicit terminals, named/private and
runtime-selected grammars, remainders, sharing, alternatives/backtracking,
ordinary exceptions and reserved control transfers. Include forbidden braces
and qualified/crafted helper calls, plus copied-source restoration so wrappers
do not accumulate or retain the wrong actor module. Keep native string semantics
and experimental text findings separate. This is a proposal, not a tested repair.

[Preservation checks](preservation.json) pass against the preceding recorded
native-source, binary/library, installed-target, pin and n3/n5 snapshot.
