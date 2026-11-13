
:- begin_tests(static_peer_credentials).
:- use_module('../prolog/web_prolog/node.pl').
:- use_module('../prolog/web_prolog/node_auth.pl').
:- use_module('../prolog/web_prolog/node_runtime_state.pl').
token("synthetic-static-peer-credential-000000").
test(startup_and_scope) :-
 token(T), node:extract_static_peer_tokens([bearer_token(peer,T,[execute,internal_transport]),auth(open)],Tokens,[auth(open)]),
 register_node_runtime(19987,_{auth:open,static_bearer_tokens:Tokens}),
 register_node_runtime(19988,_{auth:open,static_bearer_tokens:[]}),
 string_concat("Bearer ",T,H),
 with_node_port_context(19987,(node_auth:request_principal([authorization(H)],P),assertion(P.id=="peer"),assertion(P.capabilities==[execute,internal_transport]),assertion(\+node_auth:principal_has_capability(P,admin)))),
 with_node_port_context(19988,(node_auth:request_principal([authorization(H)],Other),assertion(\+node_auth:principal_has_capability(Other,internal_transport)))),
 with_node_port_context(19987,(node_auth:request_principal([authorization("Bearer wrong")],Bad),assertion(\+node_auth:principal_has_capability(Bad,internal_transport)))).
test(invalid,[throws(error(domain_error(static_bearer_credential,invalid),_))]) :-
 node:extract_static_peer_tokens([bearer_token(peer,short,[execute])],_,_).
:- end_tests(static_peer_credentials).
