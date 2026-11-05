:- module(node_execution_context, [
    with_public_execution_context/3,
    with_public_execution_profile/2,
    with_public_execution_namespace/2,
    without_public_execution_context/1,
    current_public_execution_profile/1,
    current_public_execution_namespace/1,
    open_client_namespace/1, close_client_namespace/1,
    open_client_connection/2, close_client_connection/1,
    client_namespace_status/2,
    bind_client_lineage/4, resolve_client_lineage/7,
    client_lineage/4, bind_connection_context/4, connection_context/4,
    forget_client_lineage/3
]).

/** <module> Public Execution Context

Thread-local execution context used to distinguish public client execution from
owner-controlled local runtime activity.
*/

:- use_module(node_profile_policy, [normalize_profile/2]).
:- use_module(actors, []).
:- use_module(library(error)).

:- thread_local current_public_execution_profile_local/1.
:- thread_local current_public_execution_namespace_local/1.

:- meta_predicate
    with_public_execution_context(+, +, 0),
    with_public_execution_profile(+, 0),
    with_public_execution_namespace(+, 0),
    without_public_execution_context(0).


%!  with_public_execution_context(+Profile, +Namespace, :Goal) is det.
with_public_execution_context(Profile, Namespace, Goal) :-
    with_public_execution_profile(
        Profile,
        with_public_execution_namespace(Namespace, Goal)
    ).


%!  with_public_execution_profile(+Profile, :Goal) is det.
with_public_execution_profile(Profile0, Goal) :-
    normalize_profile(Profile0, Profile),
    setup_call_cleanup(
        asserta(current_public_execution_profile_local(Profile), Ref),
        Goal,
        erase(Ref)
    ).


%!  with_public_execution_namespace(+Namespace, :Goal) is det.
with_public_execution_namespace(Namespace, Goal) :-
    setup_call_cleanup(
        asserta(current_public_execution_namespace_local(Namespace), Ref),
        Goal,
        erase(Ref)
    ).


%!  without_public_execution_context(:Goal) is det.
without_public_execution_context(Goal) :-
    setup_call_cleanup(
        (   asserta(current_public_execution_profile_local('$suppressed'),
                    ProfileRef),
            asserta(current_public_execution_namespace_local('$suppressed'),
                    NamespaceRef)
        ),
        Goal,
        (   erase(NamespaceRef),
            erase(ProfileRef)
        )
    ).


%!  current_public_execution_profile(-Profile) is semidet.
current_public_execution_profile(Profile) :-
    current_public_execution_profile_local(Value),
    !,
    Value \== '$suppressed',
    Profile = Value.


%!  current_public_execution_namespace(-Namespace) is semidet.
current_public_execution_namespace(Namespace) :-
    current_public_execution_namespace_local(Value),
    !,
    Value \== '$suppressed',
    Namespace = Value.


% Runtime-only namespace admission. No per-client tombstone is needed:
% missing open namespaces reject writes; delegated closure markers live only
% until their owning connection ends. All access is under actors_registry.
:- dynamic open_namespace/1, namespace_connection/2, closed_lineage/2.
% A context identity is independent of any one transport attachment.
:- dynamic client_lineage/4, lineage_attachment/5, connection_context/4.
:- multifile hook_namespace_closed/1, hook_connection_closed/1,
             hook_namespace_closed_after/1.

open_client_namespace(Namespace) :-
    must_be(ground, Namespace),
    with_mutex(actors_registry,
        (open_namespace(Namespace) -> true; assertz(open_namespace(Namespace)))).

open_client_connection(Queue, Namespace) :-
    with_mutex(actors_registry,
        (open_client_namespace(Namespace), assertz(namespace_connection(Queue, Namespace)))).

close_client_namespace(Namespace) :-
    must_be(ground, Namespace),
    with_mutex(actors_registry,close_namespace_locked(Namespace,WasOpen)),
    finish_namespace_close(Namespace,WasOpen).

% Caller holds actors_registry. Admission and the last-attachment decision
% share this lock; promise/route teardown keeps its existing cleanup phases.
close_namespace_locked(Namespace,WasOpen) :-
    (namespace_is_open(Namespace) -> WasOpen=true ; WasOpen=false),
    retractall(open_namespace(Namespace)),
    (Namespace=ws_lineage(Queue,Token),namespace_connection(Queue,_)
    -> (closed_lineage(Queue,Token) -> true;assertz(closed_lineage(Queue,Token)))
    ;true),
    actors:retire_registry_namespace(Namespace),
    forall(hook_namespace_closed(Namespace),true).

finish_namespace_close(Namespace,WasOpen) :-
    (WasOpen==true -> forall(hook_namespace_closed_after(Namespace),true);true).

close_client_connection(Queue) :-
    with_mutex(actors_registry,
        (findall(NS,retract(namespace_connection(Queue,NS)),Roots),
         findall(NS,retract(lineage_attachment(_,Queue,_,_,NS)),Attached),
         retractall(connection_context(Queue,_,_,_)),
         retractall(closed_lineage(Queue,_)))),
    maplist(close_client_namespace,Roots),
    sort(Attached,Namespaces),
    forall(member(NS,Namespaces),close_unattached_namespace(NS)),
    actors:retire_registry_namespace(ws_lineage(Queue,_)),
    forall(hook_connection_closed(Queue),true).

close_unattached_namespace(NS) :-
    with_mutex(actors_registry,
        (NS=delegated_context(_), \+ lineage_attachment(_,_,_,_,NS)
        -> close_namespace_locked(NS,WasOpen),Retired=true
        ;Retired=false)),
    (Retired==true
    -> setup_call_cleanup(true,finish_namespace_close(NS,WasOpen),
           with_mutex(actors_registry,retractall(client_lineage(_,_,_,NS))))
    ;true).

bind_client_lineage(Scope, Origin, Token, NS) :-
    with_mutex(actors_registry,
        (   client_lineage(Scope,Origin,Token,Stored)
        ->  (Stored==NS -> true;throw(error(permission_error(bind,client_context,Token),_)))
        ;   ensure_namespace_open(NS),assertz(client_lineage(Scope,Origin,Token,NS)))).

resolve_client_lineage(Scope, LocalOrigin, Origin, Token, Queue, Mode, NS) :-
    with_mutex(actors_registry,
        (   Mode==close
        ->  (client_lineage(Scope,Origin,Token,Known) -> NS=Known
            ;lineage_attachment(Scope,Queue,Origin,Token,Known) -> NS=Known
            ;Origin==LocalOrigin -> NS=ws_lineage(Queue,Token)
            ;namespace_connection(Queue,_),
             flag(native_client_context,N,N+1),NS=delegated_context(context(Scope,N)),
             assertz(client_lineage(Scope,Origin,Token,NS)),
             assertz(lineage_attachment(Scope,Queue,Origin,Token,NS)))
        ;   namespace_connection(Queue,_),
            (client_lineage(Scope,Origin,Token,Known) -> NS=Known
            ; Origin==LocalOrigin
            -> throw(error(permission_error(use,closed_client_context,Token),_))
            ; flag(native_client_context,N,N+1),NS=delegated_context(context(Scope,N)),
              open_client_namespace(NS),assertz(client_lineage(Scope,Origin,Token,NS))),
            ensure_namespace_open(NS),
            (lineage_attachment(Scope,Queue,Origin,Token,NS) -> true
            ;assertz(lineage_attachment(Scope,Queue,Origin,Token,NS))))).

ensure_namespace_open(NS) :-
    (client_namespace_status(NS,closed)
    -> throw(error(permission_error(use,closed_client_context,NS),_));true).

bind_connection_context(Queue,Scope,Origin,Token) :-
    with_mutex(actors_registry,
        (connection_context(Queue,S,O,T)
        -> (S-O-T==Scope-Origin-Token -> true
           ;throw(error(permission_error(rebind,client_context,Queue),_)))
        ;assertz(connection_context(Queue,Scope,Origin,Token)))).

forget_client_lineage(Scope,Origin,Token) :-
    with_mutex(actors_registry,retractall(client_lineage(Scope,Origin,Token,_))).

client_namespace_status(Namespace, Status) :-
    managed_namespace(Namespace),
    (   namespace_is_open(Namespace) -> Status = open; Status = closed).
managed_namespace(ws_client(_)).
managed_namespace(isotope_session(_)).
managed_namespace(ws_lineage(_, _)).
managed_namespace(delegated_context(_)).
namespace_is_open(ws_lineage(Queue, Token)) :-
    namespace_connection(Queue, _), \+ closed_lineage(Queue, Token).
namespace_is_open(ws_client(Id)) :- open_namespace(ws_client(Id)).
namespace_is_open(isotope_session(Id)) :- open_namespace(isotope_session(Id)).

namespace_is_open(NS) :- NS=delegated_context(_),open_namespace(NS).
