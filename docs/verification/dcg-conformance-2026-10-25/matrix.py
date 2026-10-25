"""Publish a comparison matrix without reclassifying raw observations."""
from pathlib import Path
import collections,json,re
HERE=Path(__file__).resolve().parent

def cell(s):return str(s).replace('\n',' ').replace('|','\\|')
def code(s):return '`'+cell(s)+'`'
def actual(o):
 if o['terminal']=='exception':return o['formal']
 if not o['answers']:return 'false'
 return ' ; '.join(o['answers'])
def review(id,o):
 if o['classification']=='match':return 'listed-outcome match'
 if id in ['26','31','32'] and o['classification']=='culprit_difference':return 'qualified error indicator'
 return 'comparison difference'
def main():
 cases=json.loads((HERE/'cases-with-expectations.json').read_text());raw=json.loads((HERE/'results.json').read_text());lookup={(r['case_id'],r['mode']):r['observation'] for r in raw}
 assert len(cases)==58 and len(raw)==116
 for c in cases:
  a,b=lookup[c['id'],'direct'],lookup[c['id'],'guarded']
  assert all(a[k]==b[k] for k in ['answers','formal','terminal','classification']),c['id']
  assert a['terminal']=='exception' or a['terminal']=='exhausted',c['id']
 header='''# SWI DCG comparison checkpoint — 25 October 2026

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
'''
 lines=[header]
 for c in cases:
  a,b=lookup[c['id'],'direct'],lookup[c['id'],'guarded']
  lines.append('| '+ ' | '.join([c['id'],code(c['query']),code(actual(a)),code(actual(b)),review(c['id'],a)])+' |\n')
 lines.append('''
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
''')
 (HERE/'COVERAGE.md').write_text(''.join(lines))
 summary={mode:dict(collections.Counter(review(c['id'],lookup[c['id'],mode]) for c in cases)) for mode in ['direct','guarded']}
 summary['dcg_numeric_cases']={mode:dict(collections.Counter(review(c['id'],lookup[c['id'],mode]) for c in cases if c['id'].isdigit())) for mode in ['direct','guarded']}
 summary['paired_semantic_outcomes_equal']=58;summary['timeouts']=0;summary['answer_caps']=0
 (HERE/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
 text_rows=json.loads((HERE/'text-results.json').read_text());text_cases={c['id']:c for c in json.loads((HERE/'text-cases.json').read_text())};parts=['''# Separate DCG/text diagnostics

These 32 observations are **not** part of Ulrich's comparison or a portable-text
profile adoption. Each quote mode is set explicitly on the test module before
reading the query and any supplied source. The native default remains `string`.
The `chars` configuration exists only inside disposable test processes.

Eight diagnostics cover ordinary/empty/Unicode literals, supplied grammars with
those terminals, literal/list equality and runtime `phrase` on a literal. Both
paths match all diagnostic expectations. The supplied-source guarded path uses
`isolation:load_source_text/3` with the public profile active. This does not test
all production option/input readers, serialization or cross-node text migration.

| Case | Quote mode | Query | Source | Direct | Guarded |
|---|---|---|---|---|---|
''']
 for id,c in text_cases.items():
  a,b=[r['observation'] for r in text_rows if r['case_id']==id];assert a['classification']==b['classification']=='match'
  parts.append('| '+' | '.join([id,c['quote_mode'],code(c['query']),code(c.get('source','')),code(actual(a)),code(actual(b))])+' |\n')
 parts.append('''
The compiled native `"ab"` grammar consumes `[97,98]`; the character-list
configuration consumes `[a,b]`. The supplementary character U+1F600 is represented
as code 128512 in the native DCG and as one atom in the character-list DCG.
Empty text is a native empty string or an empty character list respectively;
both empty grammars consume no terminals. These representation differences are
not, by themselves, evidence of a DCG standards violation.
''');(HERE/'TEXT-DIAGNOSTICS.md').write_text(''.join(parts))
 print(json.dumps(summary,indent=2))
if __name__=='__main__':main()
