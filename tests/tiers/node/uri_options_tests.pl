% Canonical URI representations; loopback-only HTTP fixture.
:- module(test_uri_options, []).
:- use_module('../../../prolog/web_prolog/node.pl', []).
:- use_module('../../../prolog/web_prolog/rpc.pl').
:- use_module('../../../prolog/web_prolog/source_utils.pl', []).
:- use_module('../../../prolog/web_prolog/pid_utils.pl', []).
:- use_module(library(plunit)).
:- use_module(library(socket)).
:- use_module(library(http/thread_httpd)).
:- meta_predicate with_endpoint(-,-,0).
with_endpoint(URI,Q,Goal) :-
    setup_call_cleanup(message_queue_create(Q),
      setup_call_cleanup(
        (tcp_socket(S),tcp_bind(S,ip(127,0,0,1):Port),tcp_listen(S,16),
         http_server(test_uri_options:reply(Q),[tcp_socket(S),port(Port),workers(1)])),
        (format(atom(URI),'http://127.0.0.1:~w',[Port]),Goal),http_stop_server(Port,[])),
      message_queue_destroy(Q)).
reply(Q,Request) :-
    thread_send_message(Q,request(Request)),memberchk(path(Path),Request),
    format('Content-type: application/x-prolog; charset=UTF-8~n~n'),
    (Path=='/source' -> writeln('uri_fact(ok).')
    ; memberchk(search(Params),Request),memberchk(template=Template,Params),
      sub_atom(Template,_,5,_,'pair(') -> writeln('success([pair(ok,ok)],false).')
    ; writeln('success([v(ok)],false).')).
representation(atom,URI,URI).
representation(string,URI,Text) :- atom_string(URI,Text).
representation(chars,URI,Chars) :- atom_chars(URI,Chars).
representation(codes,URI,Codes) :- atom_codes(URI,Codes).
no_requests(Q) :- assertion(\+thread_get_message(Q,_,[timeout(0)])).
:- use_module(library(uri)).
:- begin_tests(uri_options).
test(advertised_origin,
     [forall(member(origin(Scheme,Host,Port,Expected),
                    [origin(http,localhost,80,'http://localhost'),
                     origin(https,'example.test',443,'https://example.test'),
                     origin(http,'127.0.0.1',3060,'http://127.0.0.1:3060'),
                     origin(https,'::1',443,'https://[::1]'),
                     origin(https,'::1',8443,'https://[::1]:8443'),
                     origin(http,'2001:db8::1',3060,'http://[2001:db8::1]:3060')]))]) :-
    node:make_url(Scheme,Host,Port,URL),
    assertion(URL==Expected),
    uri_components(URL,Parts),uri_data(authority,Parts,Authority),
    uri_authority_components(Authority,Parsed),uri_authority_data(host,Parsed,ParsedHost),
    assertion(ParsedHost==Host).
% A URI is an atom or a string: a string object, or a list of characters or codes.
test(canonical_text,[forall(member(Input-Expected,['http://example/x?y=%2F'-'http://example/x?y=%2F',"https://example/é"-'https://example/é',
                                                   [h,t,t,p,:,/,/,e,x]-'http://ex',[104,116,116,112,58,47,47,101,120]-'http://ex']))]) :-
    source_utils:uri_atom(Input,Source),assertion(Source==Expected),
    pid_utils:node_url_atom(Input,Node),assertion(Node==Expected),
    rpc:resolve_rpc_uri(Input,RPC),assertion(RPC==Expected),assertion(atom(RPC)).
test(invalid_destinations_before_source,[forall((member(V,[42,1.5,foo(bar),[h,1.5],[]]),member(Kind,[rpc,promise])))]) :-
    test_uri_options:with_endpoint(Base,Q,
      (atom_concat(Base,'/source',Source),
       (Kind==rpc -> Goal=rpc(V,true,[src_uri(Source)]) ; Goal=promise(V,true,Ref,[src_uri(Source)])),
       catch(call(Goal),E,true),assertion(nonvar(E)),assertion(E=error(type_error(atom_or_string,V),_)),
       assertion(var(Ref)),test_uri_options:no_requests(Q))).
test(pending_destination_not_bound,[forall(member(Kind,[rpc,promise]))]) :-
    (Kind==rpc -> Goal=rpc(V,true) ; Goal=promise(V,true,_)),
    catch(call(Goal),E,true),assertion(nonvar(E)),assertion(E=error(instantiation_error,_)),assertion(var(V)).
% Id@localhost names this node, for sending and for monitoring.
test(localhost_address_is_local) :-
    actors:self(Self),(Self='@'(Id,_) -> true ; Id=Self),
    actors:send('@'(Id,localhost),uri_localhost_probe),
    actors:receive({uri_localhost_probe -> true},[timeout(1),on_timeout(fail)]),
    actors:spawn(actors:receive({stop -> true}),Child),(Child='@'(ChildId,_) -> true ; ChildId=Child),
    actors:monitor('@'(ChildId,localhost),Ref),actors:send(Child,stop),
    actors:receive({down(_,Ref,Reason) -> true},[timeout(2),on_timeout(fail)]),
    assertion(Reason==true).

% Host:Port is not a URI: it is refused before anything is bound or requested.
test(authority_shorthand_refused,[forall(member(Input,[_H:1,localhost:_P,localhost:bad,42:80,localhost:8080]))]) :-
    catch(rpc:resolve_rpc_uri(Input,_),E,true),assertion(nonvar(E)),
    assertion(subsumes_term(error(type_error(atom_or_string,Input),_),E)),
    term_variables(Input,Vars),maplist(var,Vars).
test(public_rpc_and_promise,[forall(member(Kind,[atom,string,chars,codes]))]) :-
    test_uri_options:with_endpoint(Base,_Q,
      (test_uri_options:representation(Kind,Base,Input),
       once(rpc(Input,X=ok)),assertion(X==ok),
       promise(Input,Y=ok,Ref,[template(pair(Y,Y))]),yield(Ref,Answer,[timeout(2)]),
       assertion(Answer==success([pair(ok,ok)],false)),assertion(var(Y)))).
test(source_text_inputs,[forall(member(Kind,[atom,string,chars,codes]))]) :-
    test_uri_options:with_endpoint(Base,_Q,
      (atom_concat(Base,'/source',Source),test_uri_options:representation(Kind,Source,Input),
       source_utils:uri_to_source(Input,Text),assertion(sub_string(Text,_,_,_,"uri_fact(ok)")))).
:- end_tests(uri_options).
