"""Read-only runtime assessment; isolated process per case and path."""
from pathlib import Path
import datetime,hashlib,json,os,re,subprocess,sys,tempfile,tarfile,time
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
SWIPL=Path('/Users/torbjorn.lager/.local/share/trinity-runtime-tests/swi-default-startup-2026-10-24/runtime/bin/swipl')
sys.path.insert(0,str(ROOT.parent/'trinity-conformance/adapters'))
from local_promises import preservation,sha
TPL=ROOT.parent/'trealla-port/.build/trealla-current/tpl'
def snap():
 d=preservation(ROOT,ROOT.parent/'trealla-port',SWIPL,TPL)
 d['pin']=sha(ROOT.parent/'trinity-demonstrator/dependencies/swi-prolog-node.json')
 d['installed']={str(p):{'target':str(p.resolve()),'sha256':sha(p)} for p in [Path('/Users/torbjorn.lager/.local/share/trinity-runtimes/swi-current/bin/swipl'),TPL]}
 d['tracked_working']={f:sha(ROOT/f) for f in subprocess.check_output(['git','ls-files'],cwd=ROOT,text=True).splitlines() if (ROOT/f).is_file()}
 return d

def expectations(description):
 out=[]
 for alt in re.split(r'\n\s*\|\s*',description):
  alt=alt.strip().removesuffix('.')
  if re.match(r'^(type_error|permission_error|existence_error|representation_error)\(',alt) or alt=='instantiation_error':out.append(dict(kind='error',formal=alt))
  elif alt=='throw(h)':out.append(dict(kind='error',formal='h'))
  elif alt=='false':out.append(dict(kind='solutions',answers=[]))
  else:out.append(dict(kind='solutions',answers=[v.strip() for v in alt.split(';')]))
 return out

def main():
 before=snap();(HERE/'before.json').write_text(json.dumps(before,indent=2)+'\n')
 revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
 raw=json.loads((HERE/'cases.json').read_text());cases=[dict(c,expected=expectations(c['expected_description'])) for c in raw]
 (HERE/'cases-with-expectations.json').write_text(json.dumps(cases,indent=2)+'\n')
 rows=[];out=HERE/'raw';out.mkdir(exist_ok=True)
 env=dict(os.environ)
 for k in ['SWI_HOME_DIR','SWIPL_HOME_DIR','WP_CONFIG_FILE','WP_ASSET_ROOT','WP_NATIVE_MODE']:env.pop(k,None)
 with tempfile.TemporaryDirectory(prefix='swi-dcg-assessment-') as temp:
  fixture=Path(temp)/'native';fixture.mkdir();archive=Path(temp)/'native.tar'
  subprocess.run(['git','archive','--format=tar','--output='+str(archive),revision],cwd=ROOT,check=True)
  subprocess.run(['tar','-xf',str(archive),'-C',str(fixture)],check=True)
  archive_hash=sha(archive)
  for c in cases:
   for mode in ['direct','guarded']:
    input=Path(temp)/'case.json';input.write_text(json.dumps(c)+'\n')
    command=[str(SWIPL),'-f','none','-q','-s',str(HERE/'probe.pl'),'-g','dcg_assessment:main','--',mode,str(input),str(fixture)]
    start=time.monotonic()
    try:
     r=subprocess.run(command,cwd=fixture,env=env,capture_output=True,text=True,timeout=4)
     (out/f'{mode}-{c["id"]}.stdout').write_text(r.stdout);(out/f'{mode}-{c["id"]}.stderr').write_text(r.stderr)
     parsed=[json.loads(line) for line in r.stdout.splitlines() if line.startswith('{')]
     observation=parsed[-1] if parsed else dict(classification='harness_error',stderr=r.stderr,stdout=r.stdout)
     observation.update(exit_code=r.returncode)
    except subprocess.TimeoutExpired as e:
     observation=dict(classification='process_timeout',stdout=str(e.stdout),stderr=str(e.stderr))
    row=dict(case_id=c['id'],mode=mode,duration_ms=round((time.monotonic()-start)*1000),observation=observation);rows.append(row)
    print(c['id'],mode,observation.get('classification'),flush=True)
 (HERE/'results.json').write_text(json.dumps(rows,indent=2)+'\n')
 after=snap();checks={k:before[k]==after[k] for k in before};assert all(checks.values()),checks
 (HERE/'preservation.json').write_text(json.dumps(dict(checks=checks,after=after),indent=2)+'\n')
 (HERE/'provenance.json').write_text(json.dumps(dict(started_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),runtime_revision=revision,archive_sha256=archive_hash,engine=str(SWIPL),engine_sha256=sha(SWIPL),version=subprocess.check_output([str(SWIPL),'--version'],text=True).strip(),process_timeout_seconds=4,goal_timeout_seconds=1,answer_limit=11,source_pending_edits_excluded=True,mode='no servers started; disposable process/module per case',input_hashes={f:sha(HERE/f) for f in ['probe.pl','assess.py','cases.json','cases-with-expectations.json','phrase_quad.pl']}),indent=2)+'\n')
if __name__=='__main__':main()
