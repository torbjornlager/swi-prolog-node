:- module(test_rpc_endpoints, []).
:- use_module('../../../prolog/web_prolog/node.pl', []).
:- use_module('../../../prolog/web_prolog/rpc.pl').
:- use_module('../../../prolog/web_prolog/node_runtime_state.pl').
:- use_module(library(plunit)).
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_parameters)).

:- meta_predicate with_route(+,+,0), with_peers(-,-,0).
with_route(Logical, Endpoint, Goal) :-
    setup_call_cleanup(register_node_runtime(61992, _{rpc_endpoint_overrides:[Logical-Endpoint]}),
        with_node_port_context(61992, Goal),
        retractall(node_runtime_state:node_runtime(61992,_))).
with_peers(Logical, Endpoint, Goal) :-
    setup_call_cleanup(http_server(test_rpc_endpoints:unavailable,[port(PublicPort)]),
      setup_call_cleanup(http_server(test_rpc_endpoints:backend,[port(PrivatePort)]),
        (format(atom(Logical),'http://localhost:~d',[PublicPort]),
         format(atom(Endpoint),'http://localhost:~d',[PrivatePort]),call(Goal)),
        http_stop_server(PrivatePort,[])),http_stop_server(PublicPort,[])).
unavailable(_) :-
    format('Content-type: application/x-prolog~n~n'),
    write_canonical(error(error(resource_error(time),fixture_public_route))),write('.'),nl.
backend(Request) :-
    http_parameters(Request,[offset(Offset,[integer]),limit(Limit,[default('none')]),goal(Goal,[])]),
    (sub_atom(Goal,_,_,_,'remote_error') -> Answer=error(error(resource_error(time),fixture_backend))
    ;Offset=:=1 -> Answer=success([v(aristotle)],false)
    ;Limit=='1' -> Answer=success([v(plato)],true)
    ;Answer=success([v(plato),v(aristotle)],false)),
    format('Content-type: application/x-prolog~n~n'),write_canonical(Answer),write('.'),nl.

:- begin_tests(rpc_endpoints).
test(unconfigured_transport_unchanged) :-
    rpc:rpc_endpoint('https://n4.example','https://n4.example').
test(exact_owner_mapping_and_no_prefix_match) :-
    with_route('https://n4.example','http://private:3055',
        (rpc:rpc_endpoint('https://n4.example','http://private:3055'),
         rpc:rpc_endpoint('https://n4.example.evil','https://n4.example.evil'))).
test(mapping_is_scoped_to_the_calling_node) :-
    with_route('https://n4.example','http://private:3055',
        with_node_port_context(61993,
            rpc:rpc_endpoint('https://n4.example','https://n4.example'))).
test(client_cannot_install_transport_mapping,
     [throws(error(domain_error(rpc_option,rpc_endpoint('http://private')), _))]) :-
    rpc('http://unused',true,[rpc_endpoint('http://private')]).
test(public_route_timeout_is_preserved_without_override) :-
    with_peers(Logical,_,
        catch((rpc(Logical,human(_)),throw(unexpected_success)),
              error(resource_error(time),fixture_public_route),true)).
test(owner_route_avoids_unavailable_public_route) :-
    with_peers(Logical,Endpoint,with_route(Logical,Endpoint,
        (findall(X,rpc(Logical,human(X)),Xs),assertion(Xs==[plato,aristotle])))).
test(paging_keeps_the_same_route_and_bindings) :-
    with_peers(Logical,Endpoint,with_route(Logical,Endpoint,
        (findall(X,rpc(Logical,human(X),[limit(1)]),Xs),assertion(Xs==[plato,aristotle])))).
test(promise_captures_route_before_worker_loses_node_context) :-
    with_peers(Logical,Endpoint,with_route(Logical,Endpoint,
        (promise(Logical,human(X),Ref,[template(v(X))]),
         yield(Ref,Answer,[timeout(2)]),
         assertion(Answer==success([v(plato),v(aristotle)],false))))).
test(backend_time_errors_are_not_retried_or_hidden) :-
    with_peers(Logical,Endpoint,with_route(Logical,Endpoint,
        catch((rpc(Logical,remote_error),throw(unexpected_success)),
              error(resource_error(time),fixture_backend),true))).
:- end_tests(rpc_endpoints).
