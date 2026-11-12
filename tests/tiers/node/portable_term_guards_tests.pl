:- module(test_portable_term_guards, []).
:- use_module(library(plunit)).
:- use_module('../../../prolog/web_prolog/wire_text.pl').
:- use_module('../../../prolog/web_prolog/node_response.pl').


:- use_module('multi_node_harness.pl').
:- use_module(library(http/websocket)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/json)).
:- use_module('../../../prolog/web_prolog/node_ws.pl', []).

:- http_handler('/test_portable_answers', portable_upgrade, []).
portable_upgrade(Request) :- http_upgrade_to_websocket(portable_peer, [], Request).
portable_peer(WS) :-
    setup_call_cleanup(message_queue_create(Q),
        (ws_receive(WS, Frame, [format(json)]),
         node_ws:ws_action_transport_hello(Frame.data, Q),
         thread_get_message(Q, Welcome), node_ws:ws_relay_message(WS, Q, Welcome),
         forall(excluded(_, Term),
             (node_ws:ws_relay_message(WS,Q,success(42,[bindings{'A':Term}],false)),
              node_ws:ws_relay_message(WS,Q,'$toplevel_reply'(12345,success(42,[bindings{'A':Term}],false))))),
         node_ws:ws_relay_message(WS,Q,success(42,[bindings{'A':[a]}],false)),
         ws_receive(WS,_,[])),
        (retractall(node_ws:ws_answer_terms(Q)), message_queue_destroy(Q))).

excluded(dot, T) :- T =.. ['.', a, []].
excluded(empty_list_atom, '[]').
excluded(zero_arity, f()).

:- begin_tests(portable_term_guards).

test(wire_exclusions, [forall(excluded(_, T)),
                      throws(error(representation_error(portable_term), _))]) :-
    term_to_wire_text(T, _).

test(nested_wire_exclusions, [forall(excluded(_, T)),
                             throws(error(representation_error(portable_term), _))]) :-
    term_to_wire_text(nested([ok, T]), _).

test(json_bindings_return_error, [forall(excluded(_, T))]) :-
    answer_to_json(success([bindings{'A':T}], false), JSON),
    assertion(JSON.type == error),
    once(sub_string(JSON.details, _, _, _, "representation_error(portable_term)")).

test(pid_and_correlation_preserved, [forall(excluded(_, T))]) :-
    portable_answer('$toplevel_reply'(ticket(17), success(123, [bindings{'A':T}], true)), Answer),
    assertion(Answer = '$toplevel_reply'(ticket(17), error(123, error(representation_error(portable_term), _)))).

test(error_with_excluded_culprit_is_safe, [forall(excluded(_, T))]) :-
    answer_to_json(error(123, error(test_error(T), _)), JSON),
    assertion(JSON.type == error), assertion(JSON.pid == 123),
    once(sub_string(JSON.details, _, _, _, "representation_error(portable_term)")).

test(lists_compounds_and_variable_identity) :-
    T = value([], [a], [a|tail], pair(X,X,Y)),
    check_portable_wire_term(T),
    assertion(var(X)), assertion(var(Y)), assertion(X \== Y),
    terms_to_wire_texts([T, X, Y], [Text, XText, YText]),
    assertion(XText \== YText), atom(Text),
    answer_to_json(success(123, [bindings{'A':[a],'Empty':[],'Pair':pair(X,X,Y)}], false), JSON),
    assertion(JSON.type == success), assertion(JSON.pid == 123).

test(websocket_rejection_preserves_correlation_and_connection,
     [forall(member(Typed,[false,true])),timeout(10)]) :-
    with_test_nodes([node_spec(portable,[profile(actor),auth(open)])],
        (nb_getval(node_url_portable, URL),atom_concat(URL,'/test_portable_answers',Endpoint),
         setup_call_cleanup(http_open_websocket(Endpoint,WS,[]),
             (ws_send(WS,json(json{command:transport_hello,version:1,answer_terms:Typed})),
              ws_receive(WS,Welcome,[format(json)]),assertion(Welcome.data.type == "transport_welcome"),
              forall(between(1,3,_),
                  (ws_receive(WS,Plain,[format(json)]),assertion(Plain.data.type == "error"),
                   assertion(Plain.data.pid == 42),
                   assertion(sub_string(Plain.data.details,_,_,_,"representation_error(portable_term)")),
                   ws_receive(WS,Correlated,[format(json)]),assertion(Correlated.data.type == "error"),
                   assertion(Correlated.data.pid == 42),
                   assertion(Correlated.data.toplevel_correlation == "12345"),
                   assertion(sub_string(Correlated.data.term,_,_,_,"representation_error(portable_term)")))),
              ws_receive(WS,Safe,[format(json)]),assertion(Safe.data.type == "success")),
             ws_close(WS,1000,"done")))).

:- end_tests(portable_term_guards).
