:- module(test_public_goal_guard, []).

:- use_module('../../../prolog/web_prolog/node.pl', []).
:- use_module('../../../prolog/web_prolog/public_goal_guard.pl').
:- use_module('../../../prolog/web_prolog/node_execution_context.pl').
:- use_module('../../../prolog/web_prolog/actor_api.pl',
              [spawn/3,self/1,receive/2,exit/2,send/2,demonitor/2]).
:- use_module(library(apply)).
:- use_module(library(settings)).
:- use_module(library(plunit)).

:- meta_predicate guarded(0), meta_zero(0), meta_data(:), meta_large(8), meta_exist(^).
:- meta_predicate combined_guarded(0), in_public_context(0).

in_public_context(Goal) :-
    setup_call_cleanup(
        (setting(node:sandbox, Saved), set_setting(node:sandbox, blacklist)),
        with_public_execution_profile(actor, Goal),
        set_setting(node:sandbox, Saved)).

combined_guarded(Goal) :-
    strip_module(Goal, Module, Plain),
    in_public_context(
        (isolation:prepared_goal(Module,Plain,Safe),call(Module:Safe))).

% Build phrase as data so SWI compilation cannot expand it before the guards.
phrase_goal(Grammar, Input, Goal) :- Goal =.. [phrase,Grammar,Input].
phrase_goal(Grammar, Input, Rest, Goal) :- Goal =.. [phrase,Grammar,Input,Rest].
grammar_tokens --> [a,b].

private_observation(Source, Value) :-
    self(Parent),
    in_public_context(
      setup_call_cleanup(
        spawn(run(Parent),Pid,[src_text(Source),monitor(true)]),
        (receive({observed(Value)->true;
                  down(Pid,Pid,Early)->throw(early_dcg_exit(Early))},
                 [timeout(2),on_timeout(throw(missing_dcg_observation))]),
         receive({down(Pid,Pid,Reason)->true},
                 [timeout(2),on_timeout(throw(missing_dcg_down))]),
         assertion(Reason==true)),
        (catch(exit(Pid,test_cleanup),_,true),catch(demonitor(Pid,[flush]),_,true)))).

guarded(Goal) :-
    strip_module(Goal, Module, PlainGoal),
    setup_call_cleanup(
        (setting(node:sandbox, Saved), set_setting(node:sandbox, blacklist)),
        with_public_execution_profile(actor,
            (rewrite_goal_if_needed(Module, PlainGoal, Safe), call(Module:Safe))),
        set_setting(node:sandbox, Saved)).

meta_zero(Goal) :- call(Goal).
meta_data(Data) :- Data = _:_ .
meta_large(_).
meta_exist(_).
plus_one(X,Y) :- Y is X+1.
add(X,A,B) :- B is A+X.
choice(X) :- member(X,[a,b]).

:- begin_tests(public_goal_guard).

test(maplist_bindings, true(Y == [2,3])) :- guarded(maplist(plus_one,[1,2],Y)).
test(maplist_sharing) :- guarded(maplist(=(X),[a,Y])), assertion(X==a), assertion(Y==a).
test(maplist_backtracking, true(Answers == [[a,a],[a,b],[b,a],[b,b]])) :-
    findall(X,guarded((X=[_,_],maplist(choice,X))),Answers).
test(maplist_failure, [fail]) :- guarded(maplist(=(a),[a,b])).
test(foldl_context, true(Total==6)) :- guarded(foldl(add,[1,2,3],0,Total)).
test(explicit_caller_module, true(Y==[2,3])) :-
    context_module(Module),
    guarded(maplist(Module:plus_one,[1,2],Y)).
test(include_context, true(Selected==[a,a])) :- guarded(include(=(a),[a,b,a],Selected)).
test(callback_exception, [throws(callback_error)]) :- guarded(maplist(throw,[callback_error])).
test(runtime_closure, true(X==[a,a])) :- guarded((X=[_,_], P = =(a), maplist(P,X))).
test(empty_list_does_not_invoke_unbound_closure) :-
    guarded(maplist(P,[])), assertion(var(P)).
test(unbound_invoked_closure, [throws(error(instantiation_error,_))]) :-
    guarded(maplist(_P,[a])).
test(forbidden_callback, [throws(error(permission_error(call,sandboxed,_),_))]) :-
    guarded(maplist(nb_getval, [guard_probe], [_])).
test(nested_forbidden_callback, [throws(error(permission_error(call,sandboxed,_),_))]) :-
    guarded(maplist(maplist(nb_getval(guard_probe)), [[_]])).
test(qualified_forbidden_callback, [throws(error(permission_error(call,sandboxed,_),_))]) :-
    guarded(maplist(system:nb_getval(guard_probe), [_])).
test(zero_argument_meta_callback, [throws(error(permission_error(call,sandboxed,_),_))]) :-
    guarded(meta_zero(nb_getval(guard_probe,_))).
test(module_sensitive_data) :-
    public_goal_guard:rewrite_goal(test_public_goal_guard, meta_data(foo), Rewritten),
    assertion(Rewritten == meta_data(foo)).
test(unsupported_closure, [throws(error(domain_error(sandbox_closure_arity,8),_))]) :-
    guarded(meta_large(foo)).
test(unsupported_existential_meta, [throws(error(domain_error(sandbox_meta_argument,^),_))]) :-
    guarded(meta_exist(true)).
test(dcg_terminals, true(L==[a,b])) :- guarded(phrase([a,b],L)).
test(dcg_variable_and_braces, true(L==[a,b])) :-
    guarded((G=([a],{X=b},[X]),phrase(G,L))).
test(dcg_forbidden, [throws(error(permission_error(call,sandboxed,_),_))]) :-
    guarded(phrase({nb_getval(guard_probe,_)},[])).
test(restore_closure_identity) :-
    Original=maplist(=(X),[Y]),
    public_goal_guard:rewrite_goal(test_public_goal_guard,Original,Safe),
    public_goal_guard:restore_goal(test_public_goal_guard,Safe,Restored),
    assertion(Restored==Original), assertion(var(X)), assertion(var(Y)).
test(restore_zero_meta) :-
    Original=meta_zero(member(X,[a,b])),
    public_goal_guard:rewrite_goal(test_public_goal_guard,Original,Safe),
    public_goal_guard:restore_goal(test_public_goal_guard,Safe,Restored),
    assertion(Restored==Original), assertion(var(X)).
test(restore_dcg_identity) :-
    Original=phrase((G,{X=a},[X]),L,R),
    public_goal_guard:rewrite_goal(test_public_goal_guard,Original,Safe),
    public_goal_guard:restore_goal(test_public_goal_guard,Safe,Restored),
    assertion(Restored==Original), assertion(var(G)), assertion(var(L)), assertion(var(R)).
test(restore_unguarded_variables,
     [forall(member(Name,[maplist,meta_zero,phrase]))]) :-
    (Name==maplist -> Original=maplist(P,[]) ;
     Name==phrase -> Original=phrase(P,[]) ; Original=meta_zero(P)),
    public_goal_guard:restore_goal(test_public_goal_guard,Original,Restored),
    assertion(Restored==Original), assertion(var(P)).

test(dcg_composed_terminals, true(Input==[a,b])) :-
    phrase_goal([a,b],Input,Goal),combined_guarded(Goal).
test(dcg_composed_named, true(Input==[a,b])) :-
    phrase_goal(grammar_tokens,Input,Goal),combined_guarded(Goal).
test(dcg_composed_remainder, true(Rest==[c])) :-
    phrase_goal([a,b],[a,b,c],Rest,Goal),combined_guarded(Goal).
test(dcg_composed_failure, [fail]) :-
    phrase_goal([a],[b],Goal),combined_guarded(Goal).
test(dcg_composed_alternatives, true(All==[[a],[b]])) :-
    phrase_goal(([a];[b]),Input,Goal),
    findall(Input,combined_guarded(Goal),All).
test(dcg_composed_sharing) :-
    phrase_goal(([X],{X=Y},[Y]),Input,Goal),combined_guarded(Goal),
    assertion(Input==[X,X]),assertion(X==Y),assertion(var(X)).
test(dcg_composed_runtime_grammar, true(Input==[a,b])) :-
    phrase_goal(Grammar,Input,Goal),
    combined_guarded((Grammar=([a],{X=b},[X]),Goal)).
test(dcg_composed_unbound, [throws(error(instantiation_error,_))]) :-
    phrase_goal(_Grammar,[],Goal),combined_guarded(Goal).
test(dcg_composed_exception, [throws(grammar_error)]) :-
    phrase_goal({throw(grammar_error)},[],Goal),combined_guarded(Goal).
test(dcg_composed_ordinary_catch, true(Error==grammar_error)) :-
    phrase_goal({catch(throw(grammar_error),Error,true)},[],Goal),combined_guarded(Goal).
test(dcg_composed_reserved_control,
     [forall(member(Control,['$abort_goal','$ptcp_time_limit']))]) :-
    phrase_goal({catch(throw(Control),_,Recovered=true)},[],Goal),
    catch(combined_guarded(Goal),Error,true),
    assertion(Error==Control),assertion(var(Recovered)).
test(dcg_composed_forbidden_brace,
     [throws(error(permission_error(call,sandboxed,_),_))]) :-
    phrase_goal({nb_getval(guard_probe,_)},[],Goal),combined_guarded(Goal).
test(dcg_composed_qualified_grammar,
     [throws(error(permission_error(call,sandboxed,_),_))]) :-
    phrase_goal(system:({nb_getval(guard_probe,_)}),[],Goal),combined_guarded(Goal).
test(dcg_composed_crafted_helper,
     [throws(error(permission_error(call,sandboxed,_),_))]) :-
    context_module(Module),
    Grammar=public_goal_guard:'$sandbox_dcg'(Module,{nb_getval(guard_probe,_)}),
    phrase_goal(Grammar,[],Goal),combined_guarded(Goal).
test(dcg_composed_recognition_does_not_bind) :-
    phrase_goal(Module:'$sandbox_dcg'(Stored,Grammar),[],Goal),
    control_guard:rewrite_goal(test_public_goal_guard,Goal,_),
    assertion(var(Module)),assertion(var(Stored)),assertion(var(Grammar)),
    phrase_goal(public_goal_guard:Unknown,[],Other),
    control_guard:rewrite_goal(test_public_goal_guard,Other,_),assertion(var(Unknown)).
test(dcg_composed_foreign_stored_context_is_not_preserved) :-
    Closure=public_goal_guard:'$sandbox_dcg'(other_module,[a]),
    phrase_goal(Closure,[],Original),
    control_guard:rewrite_goal(test_public_goal_guard,Original,Safe),
    assertion(Safe==phrase(control_guard:'$dcg'(test_public_goal_guard,Closure),[])).
test(dcg_composed_restore_and_rewrite) :-
    context_module(Module),phrase_goal(([X],{X=Y}),Input,Rest,Original),
    public_goal_guard:rewrite_goal(Module,Original,Public),
    control_guard:rewrite_goal(Module,Public,Safe),
    control_guard:restore_goal(Module,Safe,RestoredControl),
    public_goal_guard:restore_goal(Module,RestoredControl,Restored),
    assertion(Restored==Original),assertion(var(X)),assertion(var(Y)),
    assertion(var(Input)),assertion(var(Rest)),
    public_goal_guard:rewrite_goal(Module,Restored,Again),
    control_guard:rewrite_goal(Module,Again,CombinedAgain),assertion(CombinedAgain==Safe).
test(dcg_composed_private_source, true(Value==[a,b])) :-
    private_observation("tokens --> [a,b]. run(Parent) :- phrase(tokens,Input), send(Parent,observed(Input)).",Value).
test(dcg_composed_copied_source, true(Value==[c])) :-
    private_observation("tokens --> [a,b]. parse(Input,Rest) :- phrase(tokens,Input,Rest). run(Parent) :- self(Self), spawn((parse([a,b,c],Rest),send(Self,copied(Rest))),Child,[src_predicates([parse/2,tokens/2]),monitor(true)]), receive({copied(Rest)->send(Parent,observed(Rest))},[timeout(2),on_timeout(fail)]), receive({down(Child,Child,true)->true},[timeout(2),on_timeout(fail)]).",Value).
test(dcg_composed_native_literal_stays_codes, true(Value==[97,98])) :-
    private_observation("tokens --> \"ab\". run(Parent) :- phrase(tokens,Input), send(Parent,observed(Input)).",Value).
test(dcg_composed_exit_runs_cleanup_without_recovery) :-
    self(Parent),
    in_public_context(
      setup_call_cleanup(
        spawn(run(Parent),Pid,[monitor(true),
          src_text("run(Parent) :- phrase({setup_call_cleanup(send(Parent,dcg_ready),catch(sleep(60),_,send(Parent,dcg_recovered)),send(Parent,dcg_cleaned))},[]).")]),
        (receive({dcg_ready->true},[timeout(2),on_timeout(throw(missing_dcg_ready))]),
         exit(Pid,killed_by_dcg_test),
         receive({dcg_cleaned->true},[timeout(2),on_timeout(throw(missing_dcg_cleanup))]),
         receive({dcg_recovered->throw(dcg_exit_was_caught);
                  down(Pid,Pid,killed_by_dcg_test)->true},
                 [timeout(2),on_timeout(throw(missing_dcg_exit))])),
        (catch(exit(Pid,test_cleanup),_,true),catch(demonitor(Pid,[flush]),_,true)))).

:- end_tests(public_goal_guard).
