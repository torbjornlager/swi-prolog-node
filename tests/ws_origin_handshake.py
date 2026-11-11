#!/usr/bin/env python3
"""Check canonical Origin allowlisting through real WebSocket handshakes."""
import http.client
import os
from pathlib import Path
import select
import socket
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with socket.socket() as sock:
    sock.bind(('127.0.0.1', 0))
    port = sock.getsockname()[1]
with tempfile.TemporaryDirectory(prefix='ws-origin-') as directory:
    fixture = Path(directory) / 'node.pl'
    fixture.write_text(f""":- use_module('{ROOT}/prolog/web_prolog/node.pl', []).
:- use_module(library(socket)).
:- initialization(main, main).
main :- tcp_socket(Socket),tcp_bind(Socket,ip(127,0,0,1):{port}),tcp_listen(Socket,128),
    node:node({port},[tcp_socket(Socket),profile(actor),auth(open),
    ws_allowed_origins(['https://partner.example.test'])]),
    writeln(ready),flush_output,thread_get_message(stop).
""")
    process = subprocess.Popen([os.environ.get('SWIPL', 'swipl'), '-q', str(fixture)],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        assert select.select([process.stdout], [], [], 10)[0], 'node did not start'
        assert process.stdout.readline().strip() == 'ready'
        for origin, allowed in [('https://partner.example.test', True),
                                ('https://partner.example.test:443', True),
                                ('https://partner.example.test:444', False),
                                ('https://unlisted.example.test', False)]:
            connection = http.client.HTTPConnection('127.0.0.1', port, timeout=3)
            try:
                connection.request('GET', '/ws', headers={
                    'Connection': 'Upgrade', 'Upgrade': 'websocket',
                    'Sec-WebSocket-Version': '13',
                    'Sec-WebSocket-Key': 'dGhlIHNhbXBsZSBub25jZQ==', 'Origin': origin})
                response = connection.getresponse()
                assert (response.status == 101) == allowed, (origin, response.status)
                if not allowed:
                    assert response.status in (400, 403), (origin, response.status)
                    response.read()
            finally:
                connection.close()
        print('PASS WebSocket origins: implicit/explicit HTTPS default port admitted; other port/origin denied')
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        errors = process.stderr.read()
        assert 'ERROR:' not in errors, errors
