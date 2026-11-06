:- module(test_worker_ownership_cleanup, []).

:- use_module('../../../prolog/web_prolog/node.pl', []).
:- use_module('../../../prolog/web_prolog/actors.pl').
:- use_module('../../../prolog/web_prolog/node_lifetime.pl', [with_owner_context/4]).
:- use_module('../../../prolog/web_prolog/node_execution_context.pl', [with_public_execution_namespace/2]).
:- use_module('../../../prolog/web_prolog/worker_cleanup.pl', []).
:- use_module(library(plunit)).

:- dynamic retirement_probe/3.
:- multifile actors:hook_stop/1, actors:hook_pid_retired/1.

% Registered after node_glue: pause after the node's pre-retirement work,
% then report completion after its ownership reclamation. Private host queues
% make both boundaries deterministic without consuming any actor messages.
actors:hook_stop(Pid) :-
    test_worker_ownership_cleanup:retirement_probe(Pid, Events, Gate),
    thread_send_message(Events, stopping),
    thread_get_message(Gate, release).
actors:hook_pid_retired(Pid) :-
    test_worker_ownership_cleanup:retirement_probe(Pid, Events, _),
    thread_send_message(Events, retired).

:- meta_predicate with_paused_retirement(1).
with_paused_retirement(Goal) :-
    setup_call_cleanup(
        (message_queue_create(Events), message_queue_create(Gate)),
        with_owner_context(principal{id:"retirement-owner", capabilities:[execute], unknown:false},
          retirement_probe, local,
          setup_call_cleanup(
            start_paused_actor(Events, Gate, Pid),
            (await_retirement(Events), call(Goal, Pid)),
            finish_paused_actor(Events, Gate, Pid))),
        (message_queue_destroy(Gate), message_queue_destroy(Events))).

start_paused_actor(Events, Gate, Pid) :-
    spawn(thread_get_message(Gate, finish), Pid),
    assertz(retirement_probe(Pid, Events, Gate)),
    thread_send_message(Gate, finish).

await_retirement(Events) :-
    (thread_get_message(Events, stopping, [timeout(3)]) -> true;
     throw(missing_retirement_barrier)).

finish_paused_actor(Events, Gate, Pid) :-
    thread_send_message(Gate, release),
    (thread_get_message(Events, retired, [timeout(3)]) -> true;
     throw(missing_retirement_completion)),
    retractall(retirement_probe(Pid, _, _)),
    assertion(\+ actors:resolve_actor_thread(Pid, _)),
    assertion(\+ node_lifetime:actor_owner(Pid, _)),
    assertion(\+ node_lifetime:cpu_sample(Pid, _)),
    assertion(\+ node_lifetime:mailbox_count(Pid, _)),
    % A redundant stop remains harmless after retirement too.
    exit(Pid, kill).

check_retiring_actor(Pid) :-
    assertion(actors:resolve_actor_thread(Pid, _)),
    assertion(node_lifetime:actor_owner(Pid, _)),
    assertion(node_lifetime:cpu_sample(Pid, _)),
    % The same still-resolvable worker remains protected from another owner.
    with_owner_context(principal{id:"retirement-outsider", capabilities:[execute], unknown:false},
        outsider, local, catch(exit(Pid, kill), Error, true)),
    assertion(nonvar(Error)),
    assertion(Error = error(permission_error(exit, actor, Pid), _)),
    % This public stop used to raise the ownership error in this exact window.
    exit(Pid, kill).

:- begin_tests(worker_ownership_cleanup).

test(ownership_survives_until_pid_retirement) :-
    with_paused_retirement(check_retiring_actor).

test(worker_scope_preserves_original_exception) :-
    with_owner_context(principal{id:"scope-owner", capabilities:[execute], unknown:false},
      scope_probe, local,
      (Scope = workers([]),
       catch(worker_cleanup:with_worker_scope(Scope,
          (worker_cleanup:spawn_worker(Scope, true, _), throw(original_worker_scope_error))),
          Error, true),
       assertion(Error == original_worker_scope_error),
       assertion(Scope == workers([])))).

% A replacement command can acquire its ownership context while the last old
% actor is still retiring. Complete that retirement before creating the new
% actor, then check authority in a subsequent command on the same connection.
test(browser_reload_during_last_actor_retirement,
     [forall(member(Id,["reload-owner","anon:reload-visitor"]))]) :-
    Principal=principal{id:Id,capabilities:[execute],unknown:false},
    setup_call_cleanup(
      (message_queue_create(Connection),message_queue_create(Events),message_queue_create(Gate),
       node_execution_context:open_client_connection(Connection,ws_client(Connection))),
      with_public_execution_namespace(ws_client(Connection),
        (with_owner_context(Principal,Connection,local,start_paused_actor(Events,Gate,Old)),
         await_retirement(Events),
         with_owner_context(Principal,Connection,local,
           (finish_paused_actor(Events,Gate,Old),spawn(receive({stop->true}),New))),
         setup_call_cleanup(true,
           with_owner_context(Principal,Connection,local,
             assertion(node_lifetime:connection_owns(Connection,New))),
           exit(New,kill)))),
      (node_execution_context:close_client_connection(Connection),
       message_queue_destroy(Connection),message_queue_destroy(Events),message_queue_destroy(Gate))).

test(idle_browser_lineage_lives_until_connection_close) :-
    Principal=principal{id:"idle-reload-owner",capabilities:[execute],unknown:false},
    setup_call_cleanup(
      (message_queue_create(Connection),
       node_execution_context:open_client_connection(Connection,ws_client(Connection))),
      (with_owner_context(Principal,Connection,local,node_lifetime:current_owner_context(First)),
       with_owner_context(Principal,Connection,local,node_lifetime:current_owner_context(Second)),
       assertion(First==Second),
       node_execution_context:close_client_connection(Connection),
       assertion(\+node_lifetime:principal_lineage(_,tree(_,Connection),_))),
      (node_execution_context:close_client_connection(Connection),message_queue_destroy(Connection))).

test(browser_connections_do_not_share_replacement_authority) :-
    Principal=principal{id:"same-reload-owner",capabilities:[execute],unknown:false},
    setup_call_cleanup(
      (message_queue_create(A),message_queue_create(B),
       node_execution_context:open_client_connection(A,ws_client(A)),
       node_execution_context:open_client_connection(B,ws_client(B))),
      setup_call_cleanup(
       with_owner_context(Principal,A,local,spawn(receive({stop->true}),Pid)),
       (with_owner_context(Principal,A,local,assertion(node_lifetime:connection_owns(A,Pid))),
        with_owner_context(Principal,B,local,assertion(\+node_lifetime:connection_owns(B,Pid)))),
       exit(Pid,kill)),
      (node_execution_context:close_client_connection(A),node_execution_context:close_client_connection(B),
       message_queue_destroy(A),message_queue_destroy(B))).

:- end_tests(worker_ownership_cleanup).
