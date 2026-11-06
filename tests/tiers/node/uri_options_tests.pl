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
test(canonical_text,[forall(member(Input-Expected,['http://example/x?y=%2F'-'http://example/x?y=%2F','https://example/é'-'https://example/é']))]) :-
    source_utils:uri_atom(Input,Source),assertion(Source==Expected),
    pid_utils:node_url_atom(Input,Node),assertion(Node==Expected),
    rpc:resolve_rpc_uri(Input,RPC),assertion(RPC==Expected),assertion(atom(RPC)).
test(node_identity_normalization_preserves_source_uri) :-
    URI='https://example.org/',
    pid_utils:node_url_atom(URI,Node),assertion(Node=='https://example.org'),
    source_utils:uri_atom(URI,Source),assertion(Source==URI),
    pid_utils:normalize_node_url(Node,Again),assertion(Again==Node).
test(invalid_destinations_before_source,[forall((member(V,[42,1.5,foo(bar),"https://example.org",localhost:3053,host:bad,[104,116,116,112],[h,t,t,p]]),member(Kind,[rpc,promise])))]) :-
    test_uri_options:with_endpoint(Base,Q,
      (atom_concat(Base,'/source',Source),
       (Kind==rpc -> Goal=rpc(V,true,[src_uri(Source)]) ; Goal=promise(V,true,Ref,[src_uri(Source)])),
       catch(call(Goal),E,true),assertion(nonvar(E)),assertion(E=error(type_error(atom,V),_)),
       assertion(var(Ref)),test_uri_options:no_requests(Q))).
test(pending_destination_not_bound,[forall(member(Kind,[rpc,promise]))]) :-
    (Kind==rpc -> Goal=rpc(V,true) ; Goal=promise(V,true,_)),
    catch(call(Goal),E,true),assertion(nonvar(E)),assertion(E=error(instantiation_error,_)),assertion(var(V)).
test(uri_compound_variables_not_bound,[forall(member(Input,[_H:1,localhost:_P,localhost:bad,42:80]))]) :-
    catch(rpc:resolve_rpc_uri(Input,_),E,true),assertion(nonvar(E)),assertion(E=error(type_error(atom,Input),_)),
    term_variables(Input,Vars),maplist(var,Vars).
test(uri_options_rejected_before_creation,
     [forall((member(V,["http://invalid.example",[h,t,t,p],host:80]),member(Name,[node,src_uri])))]) :-
    Option=..[Name,V],
    catch(actors:spawn(true,Pid,[Option]),E,true),assertion(nonvar(E)),
    assertion(E=error(type_error(atom,V),_)),assertion(var(Pid)).
test(public_rpc_and_promise,[forall(member(Kind,[atom]))]) :-
    test_uri_options:with_endpoint(Base,_Q,
      (test_uri_options:representation(Kind,Base,Input),
       once(rpc(Input,X=ok)),assertion(X==ok),
       promise(Input,Y=ok,Ref,[template(pair(Y,Y))]),yield(Ref,Answer,[timeout(2)]),
       assertion(Answer==success([pair(ok,ok)],false)),assertion(var(Y)))).
test(source_uri_atoms,[forall(member(Kind,[atom]))]) :-
    test_uri_options:with_endpoint(Base,_Q,
      (atom_concat(Base,'/source',Source),test_uri_options:representation(Kind,Source,Input),
       source_utils:uri_to_source(Input,Text),assertion(sub_string(Text,_,_,_,"uri_fact(ok)")))).
:- end_tests(uri_options).
