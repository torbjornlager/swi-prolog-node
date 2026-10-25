# SWI DCG comparison checkpoint — 25 October 2026

Test-only assessment of Ulrich Neumerkel's [phrase comparison](https://www.complang.tuwien.ac.at/ulrich/iso-prolog/phrase)
and linked [executable case listing](https://www.complang.tuwien.ac.at/ulrich/iso-prolog/phrase_quad.pl).
Source snapshot, alternative expectations, exact engine identity and raw results
are retained locally. See [REPORT.md](REPORT.md) for interpretation and limits.

## Summary

| Path | Listed-outcome matches | Qualified error indicators | Other comparison differences | Total |
|---|---:|---:|---:|---:|
| Direct SWI | 42 | 3 | 13 | 58 |
| Guarded Web Prolog | 42 | 3 | 13 | 58 |

All 58 pairs agree in answers, terminal state and formal exception. Error
contexts identify different execution helpers. There are no timeouts or answer
caps in the final runs. This is not certification against the full published TS.
The ten `c*`/`f*` rows are supporting Prolog controls, not DCG-specific cases.

## All comparison cases

Only implementation error context is omitted in this table. Raw exceptions,
prepared goals and complete named bindings are in [results.json](results.json).
The three qualified-indicator rows retain raw `culprit_difference` classifications;
the review column explains their module namespace detail rather than silently
normalizing it away. Listed alternatives are kept in the expectation file.

| Case | Query | Direct outcome | Guarded outcome | Review |
|---|---|---|---|---|
| c1 | `call(1).` | `type_error(callable,1)` | `type_error(callable,1)` | listed-outcome match |
| c2 | `call((1,fail)).` | `type_error(callable,(1,fail))` | `type_error(callable,(1,fail))` | listed-outcome match |
| c3 | `call((fail,1)).` | `type_error(callable,(fail,1))` | `type_error(callable,(fail,1))` | listed-outcome match |
| c4 | `call((!;1)).` | `type_error(callable,(!;1))` | `type_error(callable,(!;1))` | listed-outcome match |
| c5 | `call((!;\+1)).` | `type_error(callable,(!;\+1))` | `type_error(callable,(!;\+1))` | comparison difference |
| c6 | `call((!;call(1))).` | `[]` | `[]` | listed-outcome match |
| c7 | `call((\+!;X=a)).` | `['X'=a]` | `['X'=a]` | listed-outcome match |
| f1 | `functor(T,F,A).` | `instantiation_error` | `instantiation_error` | listed-outcome match |
| f2 | `functor(T,1,2).` | `type_error(atom,1)` | `type_error(atom,1)` | listed-outcome match |
| f3 | `functor([_],.,2).` | `false` | `false` | comparison difference |
| 1 | `phrase(=,L).` | `['L'=[]]` | `['L'=[]]` | listed-outcome match |
| 2 | `phrase(1,L).` | `type_error(callable,1)` | `type_error(callable,1)` | listed-outcome match |
| 39 | `phrase(K,L).` | `instantiation_error` | `instantiation_error` | listed-outcome match |
| 40 | `K = [], phrase(K,L).` | `['K'=[],'L'=[]]` | `['K'=[],'L'=[]]` | listed-outcome match |
| 24 | `asserta((a-->b)).` | `[]` | `[]` | comparison difference |
| 25 | `clause((a-->b),B).` | `false` | `false` | comparison difference |
| 26 | `(X-->Y).` | `existence_error(procedure,dcg_assessment:(-->)/2)` | `existence_error(procedure,dcg_assessment:(-->)/2)` | qualified error indicator |
| 3 | `phrase(!,L).` | `['L'=[]]` | `['L'=[]]` | listed-outcome match |
| 4 | `phrase([a],L).` | `['L'=[a]]` | `['L'=[a]]` | listed-outcome match |
| 5 | `phrase([a\|b],L).` | `type_error(list,[a\|b])` | `type_error(list,[a\|b])` | listed-outcome match |
| 6 | `phrase([a\|L],K).` | `type_error(list,[a\|A])` | `type_error(list,[a\|A])` | comparison difference |
| 38 | `phrase([a\|L],L).` | `type_error(list,[a\|A])` | `type_error(list,[a\|A])` | comparison difference |
| 7 | `phrase([a\|L],[a,b]).` | `type_error(list,[a\|A])` | `type_error(list,[a\|A])` | comparison difference |
| 8 | `phrase([a\|L],[]).` | `type_error(list,[a\|A])` | `type_error(list,[a\|A])` | comparison difference |
| 9 | `phrase(([a],[]),[a]).` | `[]` | `[]` | listed-outcome match |
| 10 | `phrase(([a],{1}),[]).` | `type_error(callable,([]=[a\|A],1,[]=A))` | `type_error(callable,([]=[a\|A],1,[]=A))` | listed-outcome match |
| 37 | `phrase((!,[a],{1}),[]).` | `type_error(callable,((!,A=[]),A=[a\|B],1,[]=B))` | `type_error(callable,((!,A=[]),A=[a\|B],1,[]=B))` | listed-outcome match |
| 11 | `phrase(({!,fail};[]),L).` | `false` | `false` | listed-outcome match |
| 12 | `phrase('\|'([],[a]),[a]).` | `[]` | `[]` | listed-outcome match |
| 13 | `phrase(({fail},1),L).` | `type_error(callable,1)` | `type_error(callable,1)` | listed-outcome match |
| 14 | `phrase(([a];[]),L).` | `['L'=[a]] ; ['L'=[]]` | `['L'=[a]] ; ['L'=[]]` | listed-outcome match |
| 15 | `phrase({fail,1},L).` | `type_error(callable,((fail,1),[]=A))` | `type_error(callable,((fail,1),[]=A))` | listed-outcome match |
| 16 | `phrase({throw(h)},[a]).` | `h` | `h` | listed-outcome match |
| 17 | `phrase(({L=[]},[a\|L]),[a]).` | `type_error(list,[a\|A])` | `type_error(list,[a\|A])` | comparison difference |
| 18 | `phrase([a\|L],K), L=[b].` | `type_error(list,[a\|A])` | `type_error(list,[a\|A])` | comparison difference |
| 19 | `phrase(([a\|L],1),[]).` | `type_error(list,[a\|A])` | `type_error(list,[a\|A])` | comparison difference |
| 20 | `phrase((1,[a\|L]),[]).` | `type_error(callable,1)` | `type_error(callable,1)` | listed-outcome match |
| 21 | `phrase((1,[a\|b]),[]).` | `type_error(callable,1)` | `type_error(callable,1)` | listed-outcome match |
| 46 | `phrase((1,{2}),[]).` | `type_error(callable,1)` | `type_error(callable,1)` | listed-outcome match |
| 47 | `phrase(({2},1),[]).` | `type_error(callable,1)` | `type_error(callable,1)` | listed-outcome match |
| 48 | `phrase((1,(2,[_\|_],3),4),[]).` | `type_error(callable,1)` | `type_error(callable,1)` | listed-outcome match |
| 22 | `phrase('\|'(([x]->[y]),[z]),L).` | `['L'=[x,y]]` | `['L'=[x,y]]` | listed-outcome match |
| 23 | `phrase(;(([x]->[y]),[z]),L).` | `['L'=[x,y]]` | `['L'=[x,y]]` | listed-outcome match |
| 45 | `phrase(([a],phrase(2)),[]).` | `false` | `false` | listed-outcome match |
| 27 | `phrase(\+[a],[]).` | `[]` | `[]` | listed-outcome match |
| 28 | `phrase(\+1,L).` | `type_error(callable,1)` | `type_error(callable,1)` | listed-outcome match |
| 29 | `phrase(([a],\+1),[]).` | `type_error(callable,1)` | `type_error(callable,1)` | comparison difference |
| 30 | `phrase(([a],\+1;[]),[]).` | `type_error(callable,1)` | `type_error(callable,1)` | comparison difference |
| 31 | `phrase(phrase(phrase,[]),L).` | `existence_error(procedure,dcg_assessment:phrase/4)` | `existence_error(procedure,dcg_assessment:phrase/4)` | qualified error indicator |
| 32 | `phrase(call([]),[]).` | `existence_error(procedure,dcg_assessment:[]/2)` | `existence_error(procedure,dcg_assessment:[]/2)` | qualified error indicator |
| 33 | `L=[],phrase([a\|L],[b]).` | `false` | `false` | listed-outcome match |
| 36 | `L=[],phrase([a\|L],[a]).` | `['L'=[]]` | `['L'=[]]` | listed-outcome match |
| 34 | `phrase([a],[b]).` | `false` | `false` | listed-outcome match |
| 35 | `phrase(!,[_]) ; L=1.` | `['L'=1]` | `['L'=1]` | listed-outcome match |
| 41 | `phrase([], non_list).` | `type_error(list,non_list)` | `type_error(list,non_list)` | listed-outcome match |
| 42 | `phrase([], [a\|non_list]).` | `false` | `false` | listed-outcome match |
| 43 | `phrase([], L,non_list).` | `type_error(list,non_list)` | `type_error(list,non_list)` | listed-outcome match |
| 44 | `phrase([], L,[a\|non_list]).` | `['L'=[a\|non_list]]` | `['L'=[a\|non_list]]` | listed-outcome match |

## Separate supporting and experimental evidence

| Group | Result | Interpretation |
|---|---|---|
| Matcher regressions | 12/12 pass | Checks alternatives, bindings/sharing, sequence completeness and visible error differences |
| Guard activation controls | 4/4 pass | Forbidden/crafted grammar calls rejected; reserved control bypasses recovery |
| Stateful assertion/clause control | 2/2 paths match | Explains why fresh-case clause inspection differs from inspection after assertion |
| Native string text diagnostics | 16/16 observations match | Eight diagnostics, direct and guarded |
| Experimental module-local character-list diagnostics | 16/16 observations match | Same eight diagnostics; separate test-process configuration |

Text results are in [TEXT-DIAGNOSTICS.md](TEXT-DIAGNOSTICS.md) and are excluded
from all 58-case totals. No Trealla, browser or GNU conformance claim is made.
No runtime changes or deployed reader migration are included.
