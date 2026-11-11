%% Public source and private runtime bridges must keep separate admission.
:- module(test_copied_receive_admission, []).
:- use_module('../../../prolog/web_prolog/node.pl', []).
:- use_module('../../../prolog/web_prolog/node_sandbox.pl', []).
:- use_module(library(settings)).
:- use_module(library(modules)).
:- use_module('../../../prolog/web_prolog/isolation.pl', []).
:- use_module(library(plunit)).
:- meta_predicate with_whitelist(0).
with_whitelist(Goal) :-
    setup_call_cleanup((setting(node:sandbox,Old),set_setting(node:sandbox,whitelist)),
                       Goal,set_setting(node:sandbox,Old)).
check_compiled_source(Source, Goal) :-
    in_temporary_module(Module,
      isolation:prepare_actor_module(Module,user,[src_text(Source)]),
      sandbox:safe_goal(Module:Goal)).
:- begin_tests(copied_receive_admission).
test(private_receive_callbacks_are_analyzed) :-
    with_whitelist(check_compiled_source(
      "copied(S):-receive({probe if runtime_property(persistent(true))->send(S,ok)}).",copied(_))).
test(forbidden_callback_stays_denied,
     [throws(error(permission_error(call,sandboxed,_),_))]) :-
    with_whitelist(check_compiled_source(
      "copied:-receive({probe if halt->true}).",copied)).
test(runtime_bridge_is_not_a_public_entry,
     [throws(error(permission_error(call,sandboxed,_),_))]) :-
    with_whitelist(node_sandbox:sandbox_check_goal_in_module(actor,user,
                      control_guard:'$receive'(user,{}))).
test(deferred_copy_checks_known_operations,
     [throws(error(permission_error(call,sandboxed,_),_))]) :-
    with_whitelist(node_sandbox:sandbox_check_goal_in_module(actor,user,
      spawn((not_yet_copied,halt),_,[src_predicates([not_yet_copied/0])]))).
:- end_tests(copied_receive_admission).
