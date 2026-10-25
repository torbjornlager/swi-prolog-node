#!/usr/bin/env python3
"""Bounded read-only four-way assessment; no runtime or installed-file edits."""
import argparse,hashlib,json,os,signal,subprocess,tempfile,time
from pathlib import Path

HERE=Path(__file__).resolve().parent

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def clean_env():
    env=dict(os.environ)
    for key in ['WP_EXPERIMENTAL_TEXT','WP_CONFIG_FILE','WP_ASSET_ROOT','WP_NATIVE_MODE',
                'WP_WASM_SOURCE_DIR','WP_NATIVE_STATE','SWI_HOME_DIR','SWIPL_HOME_DIR']:
        env.pop(key,None)
    return env

def run(command,env,log,timeout):
    with log.open('w') as stream:
        proc=subprocess.Popen(command,env=env,stdout=stream,stderr=subprocess.STDOUT,start_new_session=True)
        try:code=proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid,signal.SIGKILL);proc.wait();code=124
    return code

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--swipl',type=Path,required=True)
    p.add_argument('--native-root',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
    source={str(f.relative_to(a.native_root)):sha(f) for f in (a.native_root/'prolog').rglob('*') if f.is_file()}
    results=[]
    for mode in ['default','chars','iso','iso_chars']:
        env=clean_env()
        if mode in ['chars','iso_chars']:env['WP_EXPERIMENTAL_TEXT']='portable-text-0.2'
        report=a.output/(mode+'.json');log=a.output/(mode+'.log')
        cmd=[str(a.swipl),'-f','none','-q','-s',str(HERE/'probes.pl'),'-g','iso_assessment:main','--',str(a.native_root),mode,str(report)]
        code=run(cmd,env,log,45)
        row=dict(mode=mode,exit_code=code,command=cmd,report=report.name if report.exists() else None,log=log.name)
        results.append(row);print(mode,code,flush=True)
    # Loading compatibility is a separate control, never confused with the
    # assessed execution mode after trusted host modules have been loaded.
    for mode in ['default','chars','iso','iso_chars']:
        env=clean_env();iso=mode in ['iso','iso_chars'];label='bootstrap-'+mode
        if mode in ['chars','iso_chars']:env['WP_EXPERIMENTAL_TEXT']='portable-text-0.2'
        loader=str(a.native_root/'load.pl').replace("'","''")
        goal=("set_prolog_flag(iso,true)," if iso else '')+f"consult('{loader}'),writeln(assessment_bootstrap_complete),halt"
        cmd=[str(a.swipl),'-f','none','-q','-g',goal]
        log=a.output/(label+'.log');code=run(cmd,env,log,20);text=log.read_text()
        errors=[line for line in text.splitlines() if line.startswith('ERROR:')]
        results.append(dict(mode=label,exit_code=code,command=cmd,log=log.name,
                            load_errors=errors,completion_marker='assessment_bootstrap_complete' in text,
                            clean_load=code==0 and not errors and 'assessment_bootstrap_complete' in text))
        print(label,code,'load_errors',len(errors),flush=True)
    after={str(f.relative_to(a.native_root)):sha(f) for f in (a.native_root/'prolog').rglob('*') if f.is_file()}
    assert source==after
    (a.output/'provenance.json').write_text(json.dumps(dict(
        native_commit=subprocess.check_output(['git','-C',str(a.native_root),'rev-parse','HEAD'],text=True).strip(),
        swipl=dict(path=str(a.swipl),sha256=sha(a.swipl),version=subprocess.check_output([str(a.swipl),'--version'],text=True).strip()),
        inputs={str(p.name):sha(p) for p in [HERE/'probes.pl',Path(__file__)]},
        runs=results,runtime_source_unchanged=source==after,runtime_sources=source),indent=2)+'\n')
    if any(r['exit_code'] for r in results[:4]):raise SystemExit(1)
if __name__=='__main__':main()
