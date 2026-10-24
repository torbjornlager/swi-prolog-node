:- module(test_supervisor_admission, []).
:- use_module('../../../prolog/web_prolog/node.pl', []).
:- use_module('../../../prolog/web_prolog/node_sandbox.pl').
:- use_module('../../../prolog/web_prolog/node_execution_context.pl').
:- use_module('../../../prolog/web_prolog/supervisor_actor.pl').
:- use_module('../../../prolog/web_prolog/actors.pl').
:- use_module('../../../prolog/web_prolog/isolation.pl', []).
:- use_module(library(modules)).
:- use_module(library(settings)).
:- use_module(library(plunit)).

:- meta_predicate policy(+,0), runtime_context(+,0).
policy(Mode, Goal) :-
    setup_call_cleanup(
        (setting(node:sandbox, Saved), set_setting(node:sandbox,Mode)),
        with_public_execution_profile(actor,Goal),
        set_setting(node:sandbox,Saved)).
% The orchestration is trusted test scaffolding; constructor admission itself
% is checked separately above/below, and execution exercises the node guard.
runtime_context(Mode, Goal) :- policy(Mode,Goal).

waiter :- receive({never -> true}).
mode(blacklist).
mode(whitelist).

:- begin_tests(supervisor_admission).

test(nonbinding_data, [forall(member(Goal,[
        supervisor_spawn(_,_),supervisor_spawn([_],_),
        supervisor_spawn([child(a,_)],_),
        supervisor_spawn([child(a,[_])],_),
        supervisor_spawn([child(a,[start(_)])],_),
        supervisor_spawn([child(a,[start(start_sub_supervisor([_],[]))])],_),
        supervisor_spawn([child(a,[start(true)])|_],_),
        supervisor_spawn_child(_,_,_)
    ]))]) :-
    term_variables(Goal,Before),
    forall(test_supervisor_admission:mode(Mode),
      (test_supervisor_admission:policy(Mode,
         node_sandbox:sandbox_check_goal_in_module(actor,test_supervisor_admission,Goal)),
       maplist(var,Before),term_variables(Goal,After),assertion(Before==After))).

test(runtime_list_blacklist) :-
    test_supervisor_admission:runtime_context(blacklist,
      (Specs=[child(a,[start(receive({never->true})),restart(temporary)])],
       supervisor_spawn(Specs,Sup,[monitor(true)]),
       supervisor_which_children(Sup,[info(a,_,worker,temporary)]),
       supervisor_halt(Sup),
       receive({down(Sup,Sup,_)->true},[timeout(2),on_timeout(fail)]))).

test(missing_start_runtime, [forall(test_supervisor_admission:mode(Mode))]) :-
    test_supervisor_admission:runtime_context(Mode,
      (Specs=[child(a,[])],catch(supervisor_spawn(Specs,Sup),E,true),
       nonvar(E),E=error(missing_start_option(a),_),var(Sup))).

test(malformed_runtime, [forall(test_supervisor_admission:mode(Mode))]) :-
    test_supervisor_admission:runtime_context(Mode,
      (Specs=[child(a,[start(true)])|bad],catch(supervisor_spawn(Specs,Sup),E,true),
       nonvar(E),E=error(type_error(list,_),_),var(Sup))).

test(duplicate_runtime, [forall(test_supervisor_admission:mode(Mode))]) :-
    test_supervisor_admission:runtime_context(Mode,
      (Specs=[child(a,[start(true)]),child(a,[start(true)])],
       catch(supervisor_spawn(Specs,Sup),E,true),nonvar(E),
       E=error(permission_error(duplicate,supervisor_child_id,a),_),var(Sup))).

test(static_forbidden, [forall(test_supervisor_admission:mode(Mode))]) :-
    catch(test_supervisor_admission:policy(Mode,
      node_sandbox:sandbox_check_goal_in_module(actor,test_supervisor_admission,
        supervisor_spawn([child(a,[start(open(missing,read,_))])],_))),E,true),
    assertion(nonvar(E)),assertion(E=error(permission_error(call,sandboxed,_),_)).

test(runtime_forbidden_before_any_creation, [forall(test_supervisor_admission:mode(Mode))]) :-
    test_supervisor_admission:runtime_context(Mode,
      (actors(Before),Specs=[child(first,[start(receive({never->true}))]),
                            child(bad,[start(open(missing,read,_))])],
       catch(supervisor_spawn(Specs,Sup),E,true),nonvar(E),
       E=error(permission_error(call,sandboxed,_),_),var(Sup),
       actors(After),sort(Before,Sorted),sort(After,Sorted))).

test(runtime_nested_forbidden, [forall(test_supervisor_admission:mode(Mode))]) :-
    test_supervisor_admission:runtime_context(Mode,
      (Specs=[child(outer,[start(supervisor_actor:start_sub_supervisor(
                  [child(bad,[start(open(missing,read,_))])],[]))])],
       catch(supervisor_spawn(Specs,Sup),E,true),nonvar(E),
       E=error(permission_error(call,sandboxed,_),_),var(Sup))).

test(dynamic_forbidden_keeps_sibling, [forall(test_supervisor_admission:mode(Mode))]) :-
    % Establish the witness in trusted fixture code. Only the dynamic request
    % crosses the selected policy boundary; full whitelist startup is separate.
    setup_call_cleanup(
      supervisor_spawn([child(a,[start(receive({never->true})),restart(temporary)])],Sup,[monitor(true)]),
      (supervisor_which_children(Sup,Before),
       test_supervisor_admission:runtime_context(Mode,
         (Spec=child(bad,[start(open(missing,read,_))]),
          catch(supervisor_spawn_child(Sup,Spec,Reply),E,true),nonvar(E),
          E=error(permission_error(call,sandboxed,_),_),var(Reply))),
       supervisor_which_children(Sup,After),assertion(After==Before)),
      (supervisor_halt(Sup),receive({down(Sup,Sup,_)->true},[timeout(2),on_timeout(fail)]))).

test(sharing, [forall(test_supervisor_admission:mode(Mode))]) :-
    Goal=supervisor_spawn([child(a,[start(member(X,[X,_Y]))])],_),
    term_variables(Goal,Before),
    test_supervisor_admission:policy(Mode,
      node_sandbox:sandbox_check_goal_in_module(actor,test_supervisor_admission,Goal)),
    maplist(var,Before),term_variables(Goal,After),assertion(Before==After).

test(private_source_check, [forall(test_supervisor_admission:mode(Mode))]) :-
    in_temporary_module(Module,
      isolation:prepare_actor_module(Module,test_supervisor_admission,
        [src_text('private_value(ok).')]),
      test_supervisor_admission:policy(Mode,
        (Specs=[child(a,[start(private_value(Value))])],
         node_sandbox:sandbox_check_goal_in_module(actor,Module,supervisor_spawn(Specs,_)),
         node_sandbox:sandbox_check_supervisor_child_specs(actor,Module,Specs),var(Value)))).

test(private_source_execution_blacklist) :-
    in_temporary_module(Module,
      isolation:prepare_actor_module(Module,test_supervisor_admission,
        [src_text('private_report(Parent,X) :- X=ok, Parent ! private_checked.')]),
      test_supervisor_admission:policy(blacklist,
        (self(Parent),Specs=[child(a,[start(private_report(Parent,Value)),restart(temporary)])],
         supervisor_spawn(Module:Specs,Sup,[monitor(true)]),
         receive({private_checked->true},[timeout(2),on_timeout(fail)]),var(Value),
         supervisor_halt(Sup),receive({down(Sup,Sup,_)->true},[timeout(2),on_timeout(fail)])))).

:- end_tests(supervisor_admission).
