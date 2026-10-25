# Four-way ISO/text assessment — 25 October 2026

**Assessment only. Runtime code, installed engines, the dependency pin and n3/n5
are unchanged. No ISO-mode or source-copying repair is included.**

The [outcome matrix](COVERAGE.md) records 41 probes in each configuration:
ordinary native strings, experimental character lists, ISO mode with native
strings, and ISO mode plus experimental character lists. These are **164
observations**, not a pass percentage for ISO Prolog.

Native source is committed `b61270d`. The separate tested executable identifies
as SWI-Prolog 10.1.18 (arm64-darwin), SHA-256
`915c4758b6aba3d01ade4fe4f46332b6f526ad6c70a8e2574dd05278c2b0ce9c`.
It is the previously verified separate runtime, including its earlier core/HTTP
changes, not a claim about an unmodified upstream release. Commands, source
hashes and script hashes are in `assessment-results/provenance.json`.

## Scope and execution order

Each configuration uses a new OS process with personal startup files disabled.
Host/runtime modules load with ordinary host syntax first. The process then
selects the ISO flag before the assessed queries, supplied source compilation,
sandbox checks and newly created workers. The portable-text environment selector
is supplied only to its disposable process. No public node is started or changed.

An additional process per configuration enables the requested ISO flag **before**
loading the unchanged runtime. These bootstrap controls are recorded separately.
There are five-second per-probe limits and outer process limits. All four main
processes complete, all 41 rows are present, and no probe times out. After probes
and worker cleanup finish, ISO is reset only to write the JSON report; that reset
is not inside an assessed operation or a workaround for copying/admission.

## Main findings

### ISO mode does not select character-list literals

S01/S02 show native strings with or without ISO when the language text mode is
ordinary. They show lists of character atoms in both character-list configurations.
The shared/private source and DCG controls follow the same split. Retaining the
explicit portable reader configuration is therefore necessary; `iso=true` is
not a substitute for it.

### Useful semantic changes are real, but selective

- A01: `4/2` yields integer `2` ordinarily and float `2.0` under ISO.
- A02: ordering `1.5` against `1` changes from `>` to `<`: floats precede integers
  under the selected ISO order.
- E01: `atom_length(42,_)` succeeds ordinarily and raises an exception under ISO.
  This build labels the formal error `type_error(string,42)`; the exact result
  is retained rather than silently corrected to an assumed ISO error term.
- E04/E05: static `clause/2` access and static `abolish/1` become permission errors.
- S03: `[a :- b,c]` is rejected under ISO; its explicitly parenthesized version
  S04 is accepted everywhere.
- S05's unparenthesized operator operand remains accepted in this build. S06's
  double comma is already rejected in ordinary mode. S07 dictionaries remain
  accepted under ISO, and E06's unknown read-term option is still ignored.

These observations illustrate selective compatibility settings, not a guarantee
that all non-ISO extensions disappear or all ISO restrictions are enforced.
SWI's [flag reference](https://www.swi-prolog.org/pldoc/man?section=flags) describes
`iso` and `double_quotes` as separate controls; its syntax examples should not
replace testing the actual selected binary.

### Static source copying and listing are incompatible with this ISO execution scope

C02 (`predicates_to_source`) and C03 (actual actor `src_predicates` startup) work
in the two ordinary-ISO-flag configurations and raise static-procedure access
errors in both ISO configurations. The failing engine entry is `$rule/3`, called
by the listing/source reconstruction path. This confirms an implementation
compatibility problem, rather than a character-list or variable-sharing failure.

C07's private listing similarly fails through `clause/2`. C08/C09, using explicitly
dynamic predicates, succeed in all four configurations. They are controls, not a
proposal to redeclare every application predicate dynamic or weaken protection.

Direct `src_text`, constructed `src_list`, shared-database loading and the supplied
DCG fixture still work. The constructed-source control preserves its numeric
list, repeated-variable identity and unbound caller variable. ISO does not make
source loading uniformly unusable; the static inspection paths are the issue.

### Whitelist admission is affected before user execution

A simple fact is admitted without binding its caller variable in both policies
and all configurations. An ordinary rule (`p(X) :- X is 4/2`) is also admitted
ordinarily and by blacklist mode, but **whitelist admission under ISO raises a
static `clause/3` access error**. This is a benign program being blocked by host
inspection rules.

The forbidden `open/3` body is checked only for admission, never executed.
Blacklist mode consistently rejects it for the intended sandbox reason.
Ordinary whitelist mode also identifies the forbidden operation. Under ISO,
whitelist mode instead hits static inspection of `p/0` first. That exception is
not counted as successful verification of the forbidden-operation policy.
No forbidden output file is created and no sandbox policy is disabled or patched.

### Worker inheritance is thread-sensitive

W01 creates a raw thread before the parent selects ISO. That thread retains
`iso=false`, even in the ISO configurations. W02's new raw thread and W03's actual
new actor inherit the parent's selected ISO flag.

Text flags require a different interpretation. W03 records both default host
reader behavior and the actor's explicit private-module configuration:

```
flags(ISO, HostDoubleQuotes, DefaultReaderTerm,
      ActorModuleDoubleQuotes, CompiledLiteral, ExplicitModuleReaderTerm)
```

In character-list mode the host defaults still give `string` / `"ab"`, while the
actor's explicit module flag, compiled literal and module-selected reader give
`chars` / `[a,b]` / `[a,b]`. This is expected: a generic native reader without a
module option is not the Web Prolog reader boundary. It is not evidence that the
actor lost its portable-text configuration. Module-qualifying the **flag key**
and selecting the reader's module explicitly are essential in this probe.

Because ISO follows the execution thread, putting user source in a separate
module does not by itself insulate trusted library calls in that same thread
from ISO's static-inspection restrictions. That is an inference supported by
the copy/listing and whitelist results above.

### DCG results do not show a benefit from ISO in this selection

Literal terminals yield numeric codes in native-string mode and character atoms
in the character-list configuration. Selected cut/negation controls behave the
same with either ISO flag. Partial terminals and a malformed negated grammar
retain their recorded errors. This is a small comparison, not a rerun of the
complete Ulrich matrix, and it does not settle the outstanding final-standard
questions about partial lists or unreachable negation.

## Early-bootstrap controls

Default and character-list processes load cleanly. Enabling ISO before loading
the runtime produces errors in **both** text configurations:

1. `statechart_actor.pl:360` uses the unparenthesized operator argument
   `assert_local(Module, :-Body)`, rejected by the stricter parser.
2. The installed `library(sandbox)` verification initialization attempts static
   clause inspection and raises a permission error on `sandbox:safe_primitive/1`.

All four bootstrap commands exit zero and print their completion marker, so
exit status alone would have falsely classified the ISO loads as successful.
The driver inspects recorded error messages and marks both ISO bootstrap controls
`clean_load=false`. The ordinary execution probes above use preloaded host
modules and must not be presented as clean early-ISO startup verification.

## Recommendation and remaining work

Keep ISO mode as a separate diagnostic axis for now. It provides useful stricter
syntax/arithmetic behavior, but cannot currently be enabled wholesale for this
runtime. Adopting character-list reading does not require accepting these separate
breakages and is not blocked by this assessment.

Any future ISO compatibility batch must decide the intended user-language
semantics and how trusted source/sandbox inspection should execute. That needs
explicit scope and tests; blindly suppressing permission errors, disabling the
sandbox, or making every copied predicate dynamic is not assessed here. No such
runtime change is made.

The four main configurations and controls use only the chosen separate SWI
build. Other SWI versions, Trealla/GNU/browser comparisons, performance, full
actor/lifecycle suites, all syntax extensions and full standards conformance are
outside this bounded assessment. Earlier T3 diagnostics and model/Jev migration
work remain separate.

## Evidence and reproduction

- [Matrix](COVERAGE.md), [accounting checks](validation.json), [preservation](preservation.json).
- `assessment-results/{default,chars,iso,iso_chars}.json` contain exact outcomes.
- `assessment-results/bootstrap-*.log` preserve early-load failures.
- `probes.pl`, `run.py` and `summarise.py` reproduce the assessment with explicit
  `--swipl`, `--native-root` and a fresh `--output` directory.

The initial `results/` run had an unqualified test wrapper that supplied the
wrong source module to actor copying; that baseline fixture error is corrected
in `qualified-results/` and the definitive `assessment-results/`. Intermediate
`final-results/` also established explicit private-module reader checks before
the dynamic-predicate/rule-admission controls were added. No runtime change was
used to correct the fixture, and intermediate counts are not added to 164.

Runtime source hashes, installed binary targets/hashes, dependency pin and n3/n5
process identities are preserved. No examples or historical reports are edited.
