:- module(test_remote_demonitor_races, []).
:- use_module('../../../prolog/web_prolog/node.pl', []).
:- use_module('../../../prolog/web_prolog/actor_api.pl').
:- use_module('../../../prolog/web_prolog/node_controller.pl', []).
:- use_module(library(plunit)).
:- use_module(library(prolog_wrap)).
:- dynamic barrier/4.

:- begin_tests(remote_demonitor_races).

test(selected_down_precedes_confirmed_flush, [timeout(5)]) :-
    self(Self),make_ref(Removed),make_ref(Keep),P=98101@'http://monitor-race.test',
    setup_call_cleanup(
      (message_queue_create(Events),message_queue_create(Gate),
       assertz(test_remote_demonitor_races:barrier(Self,Removed,Events,Gate)),
       assertz(actors:monitor(Self,P,Removed)),assertz(actors:monitor(Self,P,Keep)),
       node_controller:add_remote_monitor(Self,P,Removed),
       node_controller:add_remote_monitor(Self,P,Keep),
       wrap_predicate(actors:send_system(To,Message),monitor_race,W,
         (test_remote_demonitor_races:pause_selected(To,Message),W))),
      (send(Self,down(P,Removed,queued_one)),send(Self,down(P,Removed,queued_two)),
       send(Self,application_marker),
       thread_create(distribution:deliver_remote_down_via_controller(P,_{type:"down",reason:"normal"}),Delivery,[]),
       thread_get_message(Events,selected,[timeout(2)]),
       % The delivery still owns the monitor lifecycle lock.  Another thread
       % releases it only after the owning watcher begins its removal.
       thread_create((thread_get_message(Events,removing,[timeout(2)]),
                      thread_send_message(Gate,go)),Release,[]),
       thread_send_message(Events,removing),demonitor(Removed,[flush]),
       thread_join(Delivery,true),thread_join(Release,true),
       receive({down(P,Removed,_) -> fail},[timeout(0),on_timeout(true)]),
       receive({down(P,Keep,normal) -> true},[timeout(0),on_timeout(fail)]),
       receive({application_marker -> true},[timeout(0),on_timeout(fail)]),
       demonitor(Removed,[flush])),
      (thread_send_message(Gate,go),
       unwrap_predicate(actors:send_system/2,monitor_race),
       retractall(test_remote_demonitor_races:barrier(_,_,_,_)),
       retractall(actors:monitor(Self,P,_)),node_controller:remove_remote_monitor_by_pid(P),
       message_queue_destroy(Events),message_queue_destroy(Gate))).

test(withdrawal_precedes_down_selection, [timeout(5)]) :-
    self(Self),make_ref(Removed),make_ref(Keep),P=98102@'http://monitor-race.test',
    setup_call_cleanup(
      (assertz(actors:monitor(Self,P,Removed)),assertz(actors:monitor(Self,P,Keep)),
       node_controller:add_remote_monitor(Self,P,Removed),node_controller:add_remote_monitor(Self,P,Keep)),
      (thread_create(actors:demonitor(Removed,[flush]),Foreign,[]),thread_join(Foreign,true),
       assertion(actors:monitor(Self,P,Removed)),
       send(Self,down(P,Removed,already_queued)),demonitor(Removed),
       receive({down(P,Removed,already_queued) -> true},[timeout(0),on_timeout(fail)]),
       distribution:deliver_remote_down_via_controller(P,_{type:"down",reason:"normal"}),
       receive({down(P,Keep,normal) -> true},[timeout(0),on_timeout(fail)]),
       receive({down(P,Removed,_) -> fail},[timeout(0),on_timeout(true)])),
      (retractall(actors:monitor(Self,P,_)),node_controller:remove_remote_monitor_by_pid(P))).

:- end_tests(remote_demonitor_races).

pause_selected(To,down(_,Ref,_)) :-
    barrier(To,Ref,Events,Gate),!,
    thread_send_message(Events,selected),thread_get_message(Gate,go,[timeout(2)]).
pause_selected(_,_).
