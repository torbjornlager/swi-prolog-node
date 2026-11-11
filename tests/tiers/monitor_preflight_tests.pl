:- module(test_monitor_preflight, []).
:- use_module('../../prolog/web_prolog/actors.pl').
:- use_module(library(plunit)).

:- begin_tests(monitor_preflight).

test(variable_target_does_not_resolve_a_registered_name) :-
    setup_call_cleanup(
        (spawn(receive({finish -> true}),Pid),register(preflight_named,Pid)),
        (catch(monitor(Target,Ref),Error,true),
         assertion(Error=error(instantiation_error,_)),
         assertion(var(Target)),assertion(var(Ref))),
        (unregister(preflight_named),exit(Pid,kill))).

test(node_component_validation_precedes_hooks_and_reference_creation,
     [forall(member(Node-Formal,
       [_-instantiation_error,
        "https://example.test"-type_error(atom,"https://example.test"),
        [104,116,116,112]-type_error(atom,[104,116,116,112]),
        42-type_error(atom,42)]))]) :-
    copy_term(Node,Before),
    catch(monitor('@'(1,Node),Ref),Error,true),
    assertion(nonvar(Error)),Error=error(Actual,_),
    assertion(Actual=@=Formal),assertion(Node=@=Before),assertion(var(Ref)).

test(invalid_options_preserve_observation_queued_data_and_variables,
     [forall(member(Options-Formal,
       [_-instantiation_error,
        [flush|_]-instantiation_error,
        [_]-instantiation_error,
        bad-type_error(list,bad),
        [flush|bad]-type_error(list,[flush|bad]),
        [flush,unknown]-domain_error(demonitor_option,unknown),
        [flush,flush(X)]-domain_error(demonitor_option,flush(X))]))]) :-
    setup_call_cleanup(
        (spawn(receive({finish -> true}),Pid),monitor(Pid,Ref),self(Self)),
        (send(Self,down(Pid,Ref,queued)),copy_term(Options,Before),
         catch(demonitor(Ref,Options),Error,true),
         assertion(nonvar(Error)),Error=error(Actual,_),
         assertion(Actual=@=Formal),assertion(Options=@=Before),
         assertion(actors:monitor(Self,_,Ref)),
         receive({down(Pid,Ref,queued) -> true},
                 [timeout(0),on_timeout(throw(preflight_flushed))])),
        (send(Pid,finish),receive({down(Pid,Ref,true) -> true},
                                [timeout(2),on_timeout(throw(preflight_removed_monitor))]))).

test(unground_reference_leaves_queued_data_and_variables) :-
    self(Self),send(Self,down(example,wrapper(keep),queued)),
    catch(demonitor(wrapper(X),[flush]),Error,true),
    assertion(Error=error(instantiation_error,_)),assertion(var(X)),
    receive({down(example,wrapper(keep),queued) -> true},
            [timeout(0),on_timeout(throw(preflight_flushed))]).

:- end_tests(monitor_preflight).
