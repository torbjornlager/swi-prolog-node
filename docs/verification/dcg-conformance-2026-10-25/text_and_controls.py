"""Separate native/experimental-reader diagnostics and guard activation controls."""
from pathlib import Path
import json,os,subprocess,tempfile,time
from assess import HERE,ROOT,SWIPL,snap,sha

def main():
 before=snap();rows=[];controls=[];sequences=[]
 text_cases=[
 ('TD-001','X="ab".',None,'X="ab"','X="ab"'),
 ('TD-002','X="".',None,'X=""','X=""'),
 ('TD-003','X="é😀".',None,'X="é😀"','X="é😀"'),
 ('TD-004','phrase(tokens,L).','tokens --> "ab".','L=[97,98]','L=[a,b]'),
 ('TD-005','phrase(tokens,L).','tokens --> "".','L=[]','L=[]'),
 ('TD-006','phrase(tokens,L).','tokens --> "é😀".','L=[233,128512]',"L=['é','😀']"),
 ('TD-007','X="ab",X=[a,b].',None,None,'X=[a,b]'),
 ('TD-008','phrase("ab",L).',None,'L=[97,98]','L=[a,b]')]
 cases=[]
 for id,query,source,native,chars in text_cases:
  for quotes,answer in [('string',native),('chars',chars)]:
   c=dict(id=id+'-'+quotes,query=query,quote_mode=quotes,expected=[dict(kind='solutions',answers=[] if answer is None else [answer])])
   if source is not None:c['source']=source
   cases.append(c)
 guard_cases=[
  dict(id='GC-001',query='phrase({nb_getval(dcg_forbidden,_)},[]).',expected=[dict(kind='error',formal='permission_error(call,sandboxed,...)')]),
  dict(id='GC-002',query='phrase(system:({nb_getval(dcg_forbidden,_)}),[]).',expected=[dict(kind='error',formal='permission_error(call,sandboxed,...)')]),
  dict(id='GC-003',query="phrase(public_goal_guard:'$sandbox_dcg'(dcg_assessment,{nb_getval(dcg_forbidden,_)}),[]).",expected=[dict(kind='error',formal='permission_error(call,sandboxed,...)')]),
  dict(id='GC-004',query="phrase({catch(throw('$abort_goal'),_,Recovered=true)},[]).",expected=[dict(kind='error',formal="'$abort_goal'")])]
 (HERE/'text-cases.json').write_text(json.dumps(cases,ensure_ascii=False,indent=2)+'\n')
 (HERE/'guard-controls.json').write_text(json.dumps(guard_cases,indent=2)+'\n')
 env=dict(os.environ)
 for k in ['SWI_HOME_DIR','SWIPL_HOME_DIR','WP_CONFIG_FILE','WP_ASSET_ROOT','WP_NATIVE_MODE']:env.pop(k,None)
 revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
 with tempfile.TemporaryDirectory(prefix='dcg-text-controls-') as t:
  t=Path(t);fixture=t/'source';fixture.mkdir();tar=t/'native.tar'
  subprocess.run(['git','archive','--format=tar','--output='+str(tar),revision],cwd=ROOT,check=True);subprocess.run(['tar','-xf',str(tar),'-C',str(fixture)],check=True)
  sequence_cases=json.loads((HERE/'sequence-cases.json').read_text())
  for c in cases+guard_cases+sequence_cases:
   for mode in (['guarded'] if c['id'].startswith('GC-') else ['direct','guarded']):
    input=t/'case.json';input.write_text(json.dumps(c,ensure_ascii=False)+'\n')
    command=[str(SWIPL),'-f','none','-q','-s',str(HERE/'probe.pl'),'-g','dcg_assessment:main','--',mode,str(input),str(fixture)]
    start=time.monotonic();r=subprocess.run(command,cwd=fixture,env=env,capture_output=True,text=True,timeout=4)
    (HERE/'raw'/f'{mode}-{c["id"]}.stdout').write_text(r.stdout);(HERE/'raw'/f'{mode}-{c["id"]}.stderr').write_text(r.stderr)
    parsed=[json.loads(line) for line in r.stdout.splitlines() if line.startswith('{')];observation=parsed[-1] if parsed else dict(classification='harness_error',stderr=r.stderr,stdout=r.stdout)
    row=dict(case_id=c['id'],mode=mode,exit_code=r.returncode,command=command,duration_ms=round((time.monotonic()-start)*1000),observation=observation)
    (controls if c['id'].startswith('GC-') else sequences if c['id'].startswith('SC-') else rows).append(row)
    print(c['id'],mode,observation['classification'],flush=True)
 for name,data in [('text-results.json',rows),('guard-control-results.json',controls),('sequence-results.json',sequences)]:
  (HERE/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 after=snap();checks={k:before[k]==after[k] for k in before};assert all(checks.values()),checks
 (HERE/'text-preservation.json').write_text(json.dumps({'checks':checks,'source_revision':revision,'engine_sha256':sha(SWIPL),'script_sha256':sha(Path(__file__))},indent=2)+'\n')
if __name__=='__main__':main()
