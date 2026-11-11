#!/usr/bin/env python3
"""Exercise visitor ownership over real HTTP, not just internal cache keys."""
import concurrent.futures
import http.client
import http.cookiejar
import json
import os
from pathlib import Path
import select
import socket
import subprocess
import tempfile
import time
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request,build_opener,HTTPCookieProcessor

ROOT=Path(__file__).resolve().parents[1]
SWIPL=os.environ.get('SWIPL','swipl')
with socket.socket() as sock:
    sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
with tempfile.TemporaryDirectory() as directory:
    fixture=Path(directory)/'server.pl'
    fixture.write_text(f""":- use_module('{ROOT}/prolog/web_prolog/node.pl',[]).
:- use_module(library(settings)).
:- initialization(main,main).
main :- set_setting(node_http_identity:anonymous_visitors,true),
 node:node({port},[profile(isotope),auth(open),sandbox(blacklist),timeout(0.5),cache_size(8),max_inflight_calls(2),max_call_requests_per_window(20)]),
 writeln(ready),flush_output,thread_get_message(stop).
""")
    node=subprocess.Popen([SWIPL,'-q',str(fixture)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    try:
        assert select.select([node.stdout],[],[],10)[0]
        assert node.stdout.readline().strip()=='ready'
        base=f'http://127.0.0.1:{port}'
        def browser():
            jar=http.cookiejar.CookieJar();return build_opener(HTTPCookieProcessor(jar)),jar
        def request(client,path='/call',ip='198.51.100.1',owner=None,data=None,**params):
            headers={'X-Forwarded-For':ip}
            if owner is not None:headers['X-Web-Prolog-Query-Owner']=owner
            if params:path+='?'+urlencode(params)
            if data is not None:headers['Content-Type']='application/json';data=json.dumps(data).encode()
            try:
                with client.open(Request(base+path,headers=headers,data=data),timeout=5) as r:
                    body=r.read();return r.status,json.loads(body)
            except HTTPError as r:return r.code,r.read().decode()
        def page(client,offset=0,ip='198.51.100.1',owner=None):
            code,result=request(client,ip=ip,owner=owner,goal='get_time(T),member(X,[a,b,c,d])',format='json',limit=1,offset=offset)
            assert code==200 and result['type']=='success',(code,result)
            return result['data'][0]
        A,ja=browser();B,jb=browser()
        a=page(A);b=page(B,1);a2=page(A,1)
        assert a['T']==a2['T']!=b['T'] and a2['X']=='b'
        cookie=next(iter(ja));assert 'httponly' in {k.lower() for k in cookie._rest}
        # An attacker can choose its own nonce, but a corrupted signed cookie
        # must never let it select an existing cookie owner's continuation.
        c=http.client.HTTPConnection('127.0.0.1',port,timeout=5)
        c.request('GET','/call?'+urlencode(dict(goal='get_time(T),member(X,[a,b,c,d])',format='json',limit=1,offset=2)),headers={'Cookie':cookie.name+'='+cookie.value[:-1]+('0' if cookie.value[-1]!='0' else '1'),'X-Forwarded-For':'198.51.100.2'})
        r=c.getresponse();tampered=json.loads(r.read());c.close()
        assert tampered['data'][0]['T']!=a['T'] and page(A,2)['T']==a['T']
        D,_=browser();E,_=browser()
        d=page(D,owner='d'*64,ip='198.51.100.3')
        assert page(D,1,owner='d'*64,ip='198.51.100.3')['T']==d['T']
        assert page(E,2,owner='e'*64,ip='198.51.100.3')['T']!=d['T']
        assert request(E,owner='bad',ip='198.51.100.3',goal='true')[0]==400
        c=http.client.HTTPConnection('127.0.0.1',port,timeout=5)
        c.putrequest('GET','/call?goal=true');c.putheader('X-Web-Prolog-Query-Owner','d'*64);c.putheader('X-Web-Prolog-Query-Owner','e'*64);c.endheaders()
        r=c.getresponse();assert r.status==400;r.read();c.close()
        # Filling the shared cache must not evict another owner's live work.
        for i in range(12):page(E,owner=f'{100+i:064x}',ip='198.51.100.9')
        assert page(A,3)['T']==a['T']
        # Existing ISOTOPE session ownership now separates anonymous visitors too.
        code,spawn=request(A,'/toplevel_spawn',data={'options':'[]'})
        assert code==200 and 'pid' in spawn,spawn
        pid=spawn['pid']
        denied_code,denied=request(B,'/toplevel_call',data={},pid=pid,goal='true',format='json')
        assert isinstance(denied,dict),(denied_code,denied)
        assert denied['type']=='error' and 'authorization' in str(denied),denied
        _,allowed=request(A,'/toplevel_call',data={},pid=pid,goal='X=owner',format='json')
        assert allowed['type']=='success',allowed
        request(A,'/toplevel_stop',data={},pid=pid)
        # Per-IP limits cannot be bypassed by minting fresh visitor capabilities.
        rate_errors=[]
        for i in range(41):
            _,reply=request(E,ip='198.51.100.44',owner=f'{i:064x}',goal='true',format='json')
            if reply['type']=='error':rate_errors.append(reply)
        assert any('rate_limit' in str(error) for error in rate_errors),rate_errors
        assert request(E,ip='198.51.100.45',owner='f'*64,goal='true',format='json')[1]['type']=='success'
        # A saturated client's active work must leave another IP usable.
        def slow():return request(D,ip='198.51.100.50',goal='sleep(0.35),true',format='json')
        with concurrent.futures.ThreadPoolExecutor() as pool:
            jobs=[pool.submit(slow) for _ in range(2)];time.sleep(.1)
            _,busy=request(E,ip='198.51.100.50',goal='true',format='json')
            assert busy['type']=='error' and 'resource_limit' in str(busy),busy
            assert request(E,ip='198.51.100.51',goal='true',format='json')[1]['type']=='success'
            assert all(job.result()[1]['type']=='success' for job in jobs)
        # Private controller/cache entry points cannot bypass HTTP ownership.
        for goal in ["node:cache(G,N,P)","node_engine:cache(G,N,P)",
                     "node:with_query_owner(forged,true)",
                     "G=node:cache(_,_,_),call(G)",
                     "node:call(cache(_,_,_))","node:once(cache(_,_,_))",
                     "node:isobase_request_event([],anonymous,json,A)"]:
            _,blocked=request(E,ip='198.51.100.61',goal=goal,format='json')
            assert blocked['type']=='error' and 'permission' in str(blocked),blocked
        # Public programs cannot forge proxy identity through nested RPC.
        for name in ['X-Forwarded-For','X_Web_Prolog_User','x-web-prolog-capabilities']:
            goal=f"H='{name}',rpc('http://127.0.0.1:{port}',true,[request_header(H=forged)])"
            _,blocked=request(E,ip='198.51.100.60',goal=goal,format='json')
            assert blocked['type']=='error' and 'proxy_header' in str(blocked),blocked
        # RPC must reuse its own capability across pages without inbound cookies.
        goal=f"use_module('{ROOT}/prolog/web_prolog/rpc.pl'),findall(T,rpc('{base}',(get_time(T),member(X,[a,b,c])),[limit(1)]),Ts),Ts=[A,A,A],halt"
        completed=subprocess.run([SWIPL,'-q','-g',goal],capture_output=True,text=True,timeout=10)
        assert completed.returncode==0,completed.stderr
        print('PASS HTTP visitors: independent paging, tampered/duplicate identities, session ownership, cache/IP churn/concurrency fairness, native RPC paging')
    finally:
        node.terminate()
        try:node.wait(timeout=5)
        except subprocess.TimeoutExpired:node.kill();node.wait();raise
        errors=node.stderr.read()
        assert 'ERROR:' not in errors,errors
