:- module(test_server_upgrade_lifecycle, []).

:- use_module('../../prolog/web_prolog/actors.pl').
:- use_module('../../prolog/web_prolog/server_actor.pl').
:- use_module(library(plunit)).
:- use_module(library(gensym)).
:- use_module(library(time)).

:- thread_local upgrade_send_error/2.
:- multifile actors:hook_check_send/2.
actors:hook_check_send(Pid, '$upgrade'(_, _, _, _)) :-
    test_server_upgrade_lifecycle:upgrade_send_error(Pid, Error), throw(Error).

upgrade_counter(inc, N, ok, Next) :- Next is N + 1.
upgrade_counter(get, N, N, N).

upgrade(short, Pid, Callback) :- server_upgrade(Pid, Callback).
upgrade(options, Pid, Callback) :- server_upgrade(Pid, Callback, []).

:- meta_predicate with_server(-,0).
with_server(Pid, Goal) :-
    setup_call_cleanup(
        server_spawn(upgrade_counter, 0, Pid,
                     [src_predicates([upgrade_counter/4])]),
        Goal,
        stop_actor(Pid)).

stop_actor(Pid) :-
    monitor(Pid, Ref),
    exit(Pid, true),
    receive({down(Pid, Ref, _) -> true},
            [timeout(2), on_timeout(throw(missing_cleanup_down))]).

monitor_refs(Pid, Refs) :-
    self(Self), findall(Ref, actors:monitor(Self, Pid, Ref), Refs).

:- begin_tests(server_upgrade_lifecycle).

test(dead_target_reports_no_process, [forall(member(Form,[short,options]))]) :-
    spawn(true, Pid, [monitor(true),link(false)]),
    receive({down(Pid, Pid, true) -> true},
            [timeout(2), on_timeout(throw(missing_initial_down))]),
    catch(call_with_time_limit(2, upgrade(Form, Pid, upgrade_counter)), Error, true),
    assertion(Error == server_down(no_process)),
    receive({down(Pid, _, _) -> fail}, [timeout(0)]).

test(death_before_ack_preserves_existing_monitor,
     [forall(member(Form,[short,options]))]) :-
    setup_call_cleanup(
        spawn(receive({'$upgrade'(_,_,_,_) -> exit(upgrade_crash)}), Pid,
              [monitor(true),link(false)]),
        (   catch(call_with_time_limit(2, upgrade(Form, Pid, upgrade_counter)), Error, true),
            assertion(Error == server_down(upgrade_crash)),
            receive({down(Pid, Pid, upgrade_crash) -> true},
                    [timeout(2), on_timeout(throw(missing_existing_down))]),
            receive({down(Pid, _, _) -> fail}, [timeout(0)])
        ),
        stop_actor(Pid)).

test(success_preserves_state_and_removes_only_private_monitor,
     [forall(member(Form,[short,options]))]) :-
    with_server(Pid,
        (   server_request(Pid, inc, ok),
            monitor(Pid, Existing),
            upgrade(Form, Pid, upgrade_counter),
            server_request(Pid, get, State), assertion(State == 1),
            monitor_refs(Pid, Refs), assertion(Refs == [Existing]),
            server_halt(Pid, true),
            receive({down(Pid, Existing, true) -> true},
                    [timeout(2), on_timeout(throw(missing_existing_down))]),
            receive({down(Pid, _, _) -> fail}, [timeout(0)])).

test(callback_error_preserves_state_and_removes_only_private_monitor,
     [forall(member(Form,[short,options]))]) :-
    with_server(Pid,
        (   server_request(Pid, inc, ok),
            monitor(Pid, Existing),
            catch(upgrade(Form, Pid, missing_upgrade_callback), Error, true),
            assertion(nonvar(Error)),
            assertion(Error = error(existence_error(procedure,_),_)),
            server_request(Pid, get, State), assertion(State == 1),
            monitor_refs(Pid, Refs), assertion(Refs == [Existing]),
            server_halt(Pid, true),
            receive({down(Pid, Existing, true) -> true},
                    [timeout(2), on_timeout(throw(missing_existing_down))]),
            receive({down(Pid, _, _) -> fail}, [timeout(0)])).

test(send_error_preserved_and_private_monitor_removed,
     [forall(member(Form,[short,options]))]) :-
    with_server(Pid,
        (   monitor(Pid, Existing),
            Expected = error(upgrade_send_failed, context(test_transport, original)),
            setup_call_cleanup(
                asserta(upgrade_send_error(Pid, Expected), Row),
                catch(upgrade(Form, Pid, upgrade_counter), Error, true),
                erase(Row)),
            assertion(Error == Expected),
            monitor_refs(Pid, Refs), assertion(Refs == [Existing]),
            server_halt(Pid, true),
            receive({down(Pid, Existing, true) -> true},
                    [timeout(2), on_timeout(throw(missing_existing_down))]),
            receive({down(Pid, _, _) -> fail}, [timeout(0)])).

test(missing_name_flushes_private_down_and_preserves_other_messages,
     [forall(member(Form,[short,options]))]) :-
    gensym(missing_upgrade_, Name),
    self(Self), send(Self, down(other_server, other_ref, other_reason)),
    catch(upgrade(Form, Name, upgrade_counter), Error, true),
    assertion(Error = error(existence_error(actor_name,Name),_)),
    receive({down(Name, _, _) -> fail}, [timeout(0)]),
    receive({down(other_server, other_ref, other_reason) -> true},
            [timeout(0), on_timeout(throw(missing_unrelated_message))]).

test(interrupted_wait_removes_private_monitor,
     [forall(member(Form,[short,options]))]) :-
    setup_call_cleanup(
        spawn(receive({stop -> true}), Pid, [link(false)]),
        (   catch(call_with_time_limit(0.1, upgrade(Form, Pid, upgrade_counter)), Error, true),
            assertion(Error == time_limit_exceeded),
            monitor_refs(Pid, Refs), assertion(Refs == [])
        ),
        stop_actor(Pid)).

:- end_tests(server_upgrade_lifecycle).
