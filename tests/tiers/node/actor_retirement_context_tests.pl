:- module(test_actor_retirement_context, []).

:- use_module('../../../prolog/web_prolog/node.pl', []).
:- use_module('../../../prolog/web_prolog/actors.pl', []).
:- use_module('../../../prolog/web_prolog/pid_utils.pl', []).
:- use_module('../../../prolog/web_prolog/node_runtime_state.pl').
:- use_module(library(plunit)).
:- use_module(library(gensym)).

:- dynamic probe/2, protected_child/1.
:- multifile actors:hook_check_exit/1.
actors:hook_check_exit(Pid) :-
    (test_actor_retirement_context:protected_child(Pid)
    -> throw(error(permission_error(exit,retirement_probe,Pid),_))
    ; true).
:- multifile actors:hook_pid_retired/1.
actors:hook_pid_retired(Pid) :-
    test_actor_retirement_context:probe(Pid,Events),
    (current_node_port(Port) -> true ; Port=none),
    thread_send_message(Events,retired(Pid,Port)).

worker(Events,Name,Outcome) :-
    actors:self(Me),actors:register(Name,Me),
    thread_send_message(Events,ready),
    actors:receive({finish -> true}),
    (Outcome==true -> true ; Outcome==false -> fail ; throw(retirement_probe)).

fixture(Outcome) :-
    (pid_utils:registered_self_node_url(Old) -> Saved=some(Old);Saved=none),
    gensym(retirement_name_,Name),
    setup_call_cleanup(
      (register_node_runtime(19381,_{url:'http://127.0.0.1:19381'}),
       register_node_runtime(19382,_{url:'http://127.0.0.1:19382'}),
       pid_utils:register_node_self('http://127.0.0.1:19382'),
       message_queue_create(Events)),
      with_node_port_context(19381,
        setup_call_cleanup(
          actors:spawn(test_actor_retirement_context:worker(Events,Name,Outcome),Pid,
                       [link(false),monitor(true)]),
          setup_call_cleanup(assertz(probe(Pid,Events)),
            (thread_get_message(Events,ready,[timeout(2)]),
             actors:send(Pid,finish),
             thread_get_message(Events,retired(Pid,19381),[timeout(2)]),
             actors:receive({down(Pid,Pid,Reason) -> true},[timeout(2),on_timeout(fail)]),
             expected_reason(Outcome,Reason),
             assertion(\+actors:registered(_,Name,_)),
             assertion(\+actors:monitor(_,Pid,_))),
            retractall(probe(Pid,_))),
          (actors:exit(Pid,kill),actors:unregister(Name),node_lifetime:forget_actor(Pid)))),
      (message_queue_destroy(Events),
       retractall(node_runtime_state:node_runtime(19381,_)),
       retractall(node_runtime_state:node_runtime(19382,_)),restore_url(Saved))).

restore_url(some(URL)) :- pid_utils:register_node_self(URL).
restore_url(none) :- retractall(pid_utils:self_node(_)).
expected_reason(true,true).
expected_reason(false,false).
expected_reason(exception,exception(retirement_probe)).


linked_parent(Events) :-
    actors:spawn(actors:receive({}),Child,[]),
    assertz(protected_child(Child)),thread_send_message(Events,child(Child)),
    actors:receive({finish -> true}).

:- begin_tests(actor_retirement_context).
test(retirement_keeps_original_node_identity_and_context,
     [forall(member(Outcome,[true,false,exception])),timeout(5)]) :- fixture(Outcome).
test(public_exit_policy_does_not_strand_authoritative_parent_cleanup, [timeout(5)]) :-
    setup_call_cleanup(message_queue_create(Events),
      setup_call_cleanup(
        actors:spawn(test_actor_retirement_context:linked_parent(Events),Parent,
                     [link(false),monitor(true)]),
        (thread_get_message(Events,child(Child),[timeout(2)]),
         actors:monitor(Child,Ref),
         catch(actors:exit(Child,kill),Denied,true),
         assertion(Denied=error(permission_error(exit,retirement_probe,Child),_)),
         actors:send(Parent,finish),
         actors:receive({down(Child,Ref,kill)->true},[timeout(2),on_timeout(fail)]),
         actors:receive({down(Parent,Parent,true)->true},[timeout(2),on_timeout(fail)])),
        (retractall(protected_child(_)),actors:exit(Parent,kill))),
      message_queue_destroy(Events)).
:- end_tests(actor_retirement_context).
