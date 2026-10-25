#!/usr/bin/env python3
"""Read-only, temporary-node text adoption checkpoint over current repaired code."""
from pathlib import Path
import os,sys,json,subprocess,socket,time,hashlib
from urllib.request import urlopen
from urllib.parse import urlencode
ROOT=Path(__file__).resolve().parents[3];DEMO=ROOT.parent/'trinity-demonstrator';CONF=ROOT.parent/'trinity-conformance'
sys.path[:0]=[str(CONF/'adapters'),str(CONF/'runner')]
import cyclic_boundaries as c
from write_output import query
OUT=Path(__file__).resolve().parent;RESULTS=OUT/'results'
EXE=Path.home()/'.local/share/trinity-runtimes/swi-current/bin/swipl'
ACTIVE=Path.home()/'.local/share/trinity-local-nodes/code-restart-2026-10-25/n3-active'
PROTECTED=['91992','94384','91509','97669']
def protected():return subprocess.check_output(['ps','-p',','.join(PROTECTED),'-o','pid=,lstart=,command='],text=True)
def http(url,goal,template='Outcome',extra=None):
 params=dict(goal='('+goal+')',template='('+template+')',format='prolog',limit='1');params.update(extra or {})
 with urlopen(url+'/call?'+urlencode(params),timeout=7) as r:return r.read(16384).decode()
def expected_goal(expr,mode):
 return f'{expr},(X==[a,b,c]->Outcome=chars;string(X)->Outcome=string;Outcome=other)'
def main():
 RESULTS.mkdir(exist_ok=False);before=c.preservation(ROOT,c.TREALLA,c.SWI,c.TPL);before['protected']=protected();before['pin']=c.sha(DEMO/'dependencies/swi-prolog-node.json')
 nodes=[];rows=[]
 def record(name,mode,result,passed,kind='required'):
  row=dict(case=name,mode=mode,kind=kind,passed=passed,result=result);rows.append(row)
  (RESULTS/'observations.json').write_text(json.dumps(rows,indent=2)+'\n');print(mode,name,passed,flush=True)
 try:
  fixture=RESULTS/'shared-text.pl';fixture.write_text('checkpoint_shared("abc").\n')
  for mode in ['default','chars']:
   port=c.free_port();url=f'http://localhost:{port}'
   source=(ACTIVE/'start_local_node.pl').read_text().replace(str(Path.home()/'.local/share/trinity-local-nodes/code-restart-2026-10-25/swi-active-source/load.pl'),str(ROOT/'load.pl'))
   source=source.replace('config(n3,3053,open,',f'config(n3,{port},open,').replace('node(Port,Options),',f'node(Port,[load_shared_db_file({c.quote(fixture)})|Options]),')
   startfile=RESULTS/(mode+'-start.pl');startfile.write_text(source)
   env=dict(c.ENV,WP_ASSET_ROOT=str(DEMO),WP_WASM_SOURCE_DIR=str(json.loads((DEMO/'.trinity/native-swi.json').read_text())['wasm_root']))
   if mode=='chars':env['WP_EXPERIMENTAL_TEXT']='portable-text-0.2'
   else:env.pop('WP_EXPERIMENTAL_TEXT',None)
   cmd=[str(EXE),'-f','none','-q','-s',str(startfile),'--','n3']
   log=(RESULTS/(mode+'-node.log')).open('w');proc=subprocess.Popen(cmd,cwd=DEMO,env=env,stdin=subprocess.DEVNULL,stdout=log,stderr=log,start_new_session=True)
   entry=dict(mode=mode,url=url,pid=proc.pid,command=cmd,experimental_text=env.get('WP_EXPERIMENTAL_TEXT'));nodes.append((proc,log,entry))
   for _ in range(100):
    if proc.poll() is not None:raise RuntimeError('startup exit')
    try:
     with urlopen(url+'/healthz',timeout=.3) as r:assert r.status==200
     break
    except Exception:time.sleep(.1)
   else:raise RuntimeError('startup timeout')
   want='chars' if mode=='chars' else 'string'
   for name,goal,extra in [
    ('goal_reader',expected_goal('X="abc"',mode),None),
    ('unicode_reader','X="😀",(X==[\'😀\']->Outcome=chars;string(X)->Outcome=string;Outcome=other)',None),
    ('shared_database',expected_goal('checkpoint_shared(X)',mode),None),
    ('http_private_source',expected_goal('checkpoint_private(X)',mode),dict(src_text='checkpoint_private("abc").')),
   ]:
    result=http(url,goal,extra=extra);record(name,mode,result,'success(['+want+'],false)' in result)
   source='checkpoint_private("abc").'
   result=query(url,expected_goal('checkpoint_private(X)',mode),source=source)
   record('websocket_private_source',mode,result,result['answer'].get('data')==[want])
   gen='self(Parent),Source=[checkpoint_private("abc")],spawn((checkpoint_private(X),Parent ! text(X)),C,[src_list(Source),monitor(true)]),receive({text(X)->true},[timeout(2),on_timeout(fail)]),receive({down(C,C,true)->true},[timeout(2),on_timeout(fail)]),(X==[a,b,c]->Outcome=chars;string(X)->Outcome=string;Outcome=other)'
   result=query(url,gen);record('constructed_source',mode,result,result['answer'].get('data')==[want])
   for name,goal,expected in [
     ('write_atom','write(abc),Outcome=ok',['abc']),
     ('write_literal','write("abc"),Outcome=ok',['abc'] if mode=='default' else ['[a,b,c]']),
     ('write_explicit_chars','write([a,b,c]),Outcome=ok',['[a,b,c]']),
     ('writeln_explicit_chars','writeln([a,b,c]),Outcome=ok',['[a,b,c]']),
     ('format_chars','format("~s",[[a,b,c]]),Outcome=ok',['abc']),
   ]:
    result=query(url,goal);passed=result['outputs']==expected and result['answer'].get('data')==['ok']
    record(name,mode,result,passed,'output_alignment' if mode=='chars' and name in ['write_literal','write_explicit_chars','writeln_explicit_chars'] else 'required')
   result=query(url,'X=f(X),Outcome=X');record('cyclic_answer_rejection',mode,result,'representation_error' in json.dumps(result) and 'cyclic_term' in json.dumps(result))
   for caller,peer,label in [(url,'http://localhost:3060','temporary_to_trealla'),('http://localhost:3060',url,'trealla_to_temporary')]:
    goal=f'rpc({c.quote(peer)},X=pair([a,b,c],V,V),[limit(1),once(true)]),X=pair([a,b,c],A,B),var(A),A==B,Outcome=ok'
    result=query(caller,goal);record(label+'_rpc',mode,result,result['answer'].get('data')==['ok'])
    goal=f'promise({c.quote(peer)},(sleep(0.15),X=pair([a,b,c],V,V)),Ref,[template(X),limit(1),once(true)]),yield(Ref,Early,[timeout(0),on_timeout(Early=waiting)]),Early==waiting,yield(Ref,success([pair([a,b,c],A,B)],false),[timeout(2)]),var(A),A==B,Outcome=ok'
    result=query(caller,goal);record(label+'_promise',mode,result,result['answer'].get('data')==['ok'])
  # Existing pure example checks validate model/Jev guards without provider calls.
  commands=[]
  for mode in ['default','chars']:
   env=dict(c.ENV,WP_AUDIT_DEMONSTRATOR_ROOT=str(DEMO))
   if mode=='chars':env['WP_EXPERIMENTAL_TEXT']='portable-text-0.2'
   for label,cmd in [
    ('TEXT',[str(EXE),'-f','none','-q','-s',str(ROOT/'tests/tiers/node/portable_text_tests.pl'),'-g','run_tests,halt']),
    ('examples',[str(EXE),'-f','none','-q','-s',str(ROOT/'docs/verification/portable-text-migration-2026-10-25/example_checks.pl'),'-g','run_tests(portable_text_example_checks),halt'])]:
     with (RESULTS/(mode+'-'+label+'.log')).open('w') as log:
      r=subprocess.run(cmd,cwd=ROOT,env=env,stdout=log,stderr=log,timeout=80)
     commands.append(dict(mode=mode,label=label,command=cmd,exit_code=r.returncode))
     print(mode,label,r.returncode,flush=True)
  (RESULTS/'suite-checks.json').write_text(json.dumps(commands,indent=2)+'\n')
 finally:
  for proc,log,entry in reversed(nodes):
   if proc.poll() is None:
    proc.terminate()
    try:proc.wait(timeout=8)
    except subprocess.TimeoutExpired:proc.kill();proc.wait()
   log.close();entry['stopped']=proc.poll() is not None
  after=c.preservation(ROOT,c.TREALLA,c.SWI,c.TPL);after['protected']=protected();after['pin']=c.sha(DEMO/'dependencies/swi-prolog-node.json')
  (RESULTS/'preservation.json').write_text(json.dumps(dict(checks={k:before[k]==after[k] for k in before},before=before,after=after),indent=2)+'\n')
  (RESULTS/'provenance.json').write_text(json.dumps(dict(nodes=[x[2] for x in nodes],swi_revision=c.git(ROOT,'rev-parse','HEAD'),trealla_revision=c.git(c.TREALLA,'rev-parse','HEAD'),swi_runtime_hashes=before['native_prolog'],trealla_runtime_hashes=before['trealla_sources'],engines=before['engines'],runner_sha256=c.sha(Path(__file__)),configuration='explicit current working sources; default and opt-in portable-text-0.2'),indent=2)+'\n')
  (RESULTS/'observations.json').write_text(json.dumps(rows,indent=2)+'\n')
if __name__=='__main__':main()
