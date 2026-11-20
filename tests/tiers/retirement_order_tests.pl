:- module(test_retirement_order, []).
:- use_module('../../prolog/web_prolog/actors.pl').
:- use_module(library(plunit)).

:- dynamic delivery_barrier/6.
:- multifile actors:hook_send/2, actors:hook_pid_retired/1.

% A transport may deliver a notification before its send hook returns.
% Hold that return until the observer has inspected the active actor list.
actors:hook_send(To, down(Pid, Ref, Reason)) :-
    test_retirement_order:delivery_barrier(To, Pid, Ref, Thread, Gate, _),
    !,
    thread_send_message(Thread, down(Pid, Ref, Reason)),
    thread_get_message(Gate, release).

actors:hook_pid_retired(Pid) :-
    test_retirement_order:delivery_barrier(_, Pid, _, _, _, Events),
    thread_send_message(Events, retired(Pid)).

observe_at_delivery(Pid, Visible) :-
    message_queue_create(Gate),
    message_queue_create(Events),
    setup_call_cleanup(
        (self(Self), thread_self(Thread),
         spawn(receive({finish -> true}), Pid), monitor(Pid, Ref),
         assertz(delivery_barrier(Self, Pid, Ref, Thread, Gate, Events))),
        setup_call_cleanup(
            true,
            (send(Pid, finish),
             receive({down(Pid, Ref, true) -> true},
                     [timeout(3), on_timeout(throw(missing_down))]),
             actors(Visible)),
            (thread_send_message(Gate, release),
             thread_get_message(Events, retired(Pid), [timeout(3)]))),
        (retractall(delivery_barrier(_, Pid, _, _, _, _)),
         exit(Pid, kill),
         message_queue_destroy(Gate), message_queue_destroy(Events))).

:- begin_tests(retirement_order).

test(down_is_delivered_after_the_actor_leaves_the_active_list) :-
    observe_at_delivery(Pid, Visible),
    assertion(\+ memberchk(Pid, Visible)).

:- end_tests(retirement_order).
