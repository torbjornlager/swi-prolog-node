:- module(test_http_identity, []).
:- use_module('../../../prolog/web_prolog/node_http_identity.pl').
:- use_module('../../../prolog/web_prolog/node_runtime_state.pl',[with_node_port_context/2]).
:- use_module(library(plunit)).

cookie_at(Expiry,Cookie) :-
    node_http_identity:fresh_nonce(Nonce),
    format(atom(Data),'~d.~w',[Expiry,Nonce]),
    node_http_identity:sign_cookie(Data,Mac),
    format(atom(Cookie),'~w.~w',[Data,Mac]).

:- begin_tests(http_identity).
test(cookie_expiry_tamper_and_node_binding) :-
    get_time(Now),Expiry is floor(Now)+100,
    with_node_port_context(19001,
      (cookie_at(Expiry,Cookie),node_http_identity:valid_cookie(Cookie,_),
       atom_concat(Cookie,x,Tampered),assertion(\+node_http_identity:valid_cookie(Tampered,_)),
       Past is floor(Now)-1,cookie_at(Past,Expired),assertion(\+node_http_identity:valid_cookie(Expired,_)),
       Future is floor(Now)+90000,cookie_at(Future,TooFar),assertion(\+node_http_identity:valid_cookie(TooFar,_)))),
    with_node_port_context(19002,assertion(\+node_http_identity:valid_cookie(Cookie,_))).
test(metadata_id_is_not_a_reusable_capability) :-
    node_http_identity:fresh_nonce(Nonce),node_http_identity:visitor_id(Nonce,Id),
    assertion(Nonce\==Id),atom_string(Copy,Id),node_http_identity:visitor_id(Copy,Other),
    assertion(Id\==Other).
test(owner_context_is_nested_and_unwinds_after_exception) :-
    assertion(\+current_query_owner(_)),
    with_query_owner(a,
      (catch(with_query_owner(b,(current_query_owner(b),throw(test))),test,true),
       current_query_owner(a))),
    assertion(\+current_query_owner(_)).
:- end_tests(http_identity).
