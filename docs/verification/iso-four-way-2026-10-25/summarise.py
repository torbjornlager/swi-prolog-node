#!/usr/bin/env python3
"""Generate an outcome matrix; these are observations, not ISO pass scores."""
import json,re
from pathlib import Path
D=Path(__file__).resolve().parent/'assessment-results'
MODES=['default','chars','iso','iso_chars']

def normal(text):return re.sub(r'tmp-\d+-\d+','<temporary-module>',text)
def cell(row):
    if row['kind']=='exception':value=row['formal'] or row['outcome']
    elif row['kind']=='failure':value='failure'
    else:value=row['outcome'][len('success('):-1]
    return '`'+normal(value).replace('|','\\|')+'`'

def main():
    reports={m:json.loads((D/(m+'.json')).read_text()) for m in MODES}
    tables={m:{r['id']:r for r in data['cases']} for m,data in reports.items()}
    ids=list(tables['default']);assert all(list(tables[m])==ids for m in MODES)
    controls={
        'all_four_execution_processes_completed':all(r['case_count']==41 for r in reports.values()),
        'no_probe_timeouts':all('time_limit_exceeded' not in r['outcome'] and 'missing_actor_' not in r['outcome'] for d in reports.values() for r in d['cases']),
        'static_actor_copy_baselines_work':all(tables[m]['C03']['kind']=='success' for m in ['default','chars']),
        'dynamic_copy_controls_work':all(tables[m]['C08']['kind']=='success' for m in MODES),
        'dynamic_listing_controls_work':all(tables[m]['C09']['kind']=='success' for m in MODES),
        'existing_workers_keep_old_iso_flag':all(tables[m]['W01']['outcome'].startswith('success(flags(false,') for m in MODES),
        'new_workers_inherit_iso_flag':all(tables[m]['W02']['outcome'].startswith('success(flags('+('true' if m in ['iso','iso_chars'] else 'false')+',') for m in MODES),
        'new_actors_inherit_iso_flag':all(tables[m]['W03']['outcome'].startswith('success(flags('+('true' if m in ['iso','iso_chars'] else 'false')+',') for m in MODES),
        'actor_private_chars_and_explicit_reader_agree':all(tables[m]['W03']['outcome'].endswith(',chars,[a,b],[a,b]))') for m in ['chars','iso_chars']),
        'iso_does_not_select_chars':tables['default']['S01']['outcome']==tables['iso']['S01']['outcome'] and tables['chars']['S01']['outcome']==tables['iso_chars']['S01']['outcome'],
        'ordinary_and_chars_clean_bootstrap':True,
        'iso_bootstrap_errors_kept_as_diagnostics':True,
    }
    provenance=json.loads((D/'provenance.json').read_text())
    boot={r['mode']:r for r in provenance['runs'][4:]}
    controls['ordinary_and_chars_clean_bootstrap']=all(boot['bootstrap-'+m]['clean_load'] for m in ['default','chars'])
    controls['iso_bootstrap_errors_kept_as_diagnostics']=all(not boot['bootstrap-'+m]['clean_load'] and boot['bootstrap-'+m]['exit_code']==0 for m in ['iso','iso_chars'])
    assert all(controls.values()),controls
    lines=['# Four-way SWI ISO/text outcome matrix — 25 October 2026','','41 probes per configuration, **164 observations**. Exceptions and syntax','rejections are recorded outcomes, not counted as conformance passes or failures.','Trusted host modules load before the ISO flag is selected for these probes.','See REPORT.md for the independent early-bootstrap controls and limitations.','','| Probe | Category | Default | Chars | ISO | ISO + chars |','|---|---|---|---|---|---|']
    for id in ids:lines.append('| '+id+' | '+tables['default'][id]['category']+' | '+' | '.join(cell(tables[m][id]) for m in MODES)+' |')
    lines+=['','Temporary module identities are normalised only for display. Raw outcomes,','contexts, exact commands, engine/source hashes and bootstrap logs are preserved','in assessment-results/. This matrix is not the full Ulrich DCG assessment, a','language-profile certification, a benchmark, or approval to enable ISO mode.']
    (D.parent/'COVERAGE.md').write_text('\n'.join(lines)+'\n')
    (D.parent/'validation.json').write_text(json.dumps(dict(controls=controls,observations=sum(d['case_count'] for d in reports.values()),source_preserved=provenance['runtime_source_unchanged']),indent=2)+'\n')
if __name__=='__main__':main()
