:- module(test_sandbox_source_names, []).

:- use_module('../../../prolog/web_prolog/node.pl', []).
:- use_module('../../../prolog/web_prolog/node_sandbox.pl', []).
:- use_module(library(modules)).
:- use_module(library(settings)).
:- use_module(library(plunit)).

:- meta_predicate with_mode(+, 0).
with_mode(Mode, Goal) :-
    setting(node:sandbox, Previous),
    setup_call_cleanup(set_setting(node:sandbox, Mode), Goal,
                       set_setting(node:sandbox, Previous)).

load_probe(Module, Label, Value) :-
    format(string(Source), 'source_name_probe(~q).~n', [Value]),
    node_sandbox:validate_and_load_source_text(actor, Module, Source, Label).

values(Module, Values) :- findall(Value, call(Module:source_name_probe(Value)), Values).

:- begin_tests(sandbox_source_names).

test(overlapping_modules_remain_isolated_and_same_module_reload_is_preserved,
     [forall((member(Mode,[blacklist,whitelist]),
              member(Label,[sandbox_source,sandbox_source_1])))]) :-
    with_mode(Mode,
      in_temporary_module(A, true,
        (test_sandbox_source_names:load_probe(A,Label,first),
         % Keep A alive while loading the same logical source label into B.
         % The old loader fails deterministically here, without timing sleeps.
         in_temporary_module(B, true,
           (test_sandbox_source_names:load_probe(B,Label,second),
            test_sandbox_source_names:values(A,Before), assertion(Before==[first]),
            test_sandbox_source_names:values(B,Other), assertion(Other==[second]),
            test_sandbox_source_names:load_probe(A,Label,reloaded),
            test_sandbox_source_names:values(A,After), assertion(After==[reloaded]),
            test_sandbox_source_names:values(B,Unchanged), assertion(Unchanged==[second])))))).

test(numbered_source_options_keep_order_contents_and_non_source_options,
     [forall(member(Mode,[blacklist,whitelist]))]) :-
    First="ordered_source_first(a).\n",
    Options=[src_text(First),monitor(false),src_list([ordered_source_second(b)])],
    with_mode(Mode,
      in_temporary_module(Module,true,
        (node_sandbox:prepare_source_options(actor,Module,user,Options,Prepared),
         assertion(Prepared=[src_text(First),monitor(false),src_text(_)]),
         Prepared=[_,_,src_text(Second)],
         read_term_from_atom(Second,Term,[]), assertion(Term==ordered_source_second(b)),
         assertion(call(Module:ordered_source_first(a))),
         assertion(call(Module:ordered_source_second(b)))))).

% SWI-Prolog 11 defers module reclamation to GC. Cleanup must still abolish
% every predicate immediately, including on exceptions and rejected sources.
test(temporary_module_is_cleared_after_success,
     [forall(member(Mode,[blacklist,whitelist]))]) :-
    with_mode(Mode,in_temporary_module(Module,true,test_sandbox_source_names:load_probe(Module,sandbox_source,success))),
    assertion(\+ predicate_property(Module:_, defined)),
    assertion(\+ current_predicate(Module:source_name_probe/1)).

test(temporary_module_is_cleared_after_exception,
     [forall(member(Mode,[blacklist,whitelist]))]) :-
    Saved=module(none),
    with_mode(Mode,
      catch(in_temporary_module(Module,nb_setarg(1,Saved,Module),
              (test_sandbox_source_names:load_probe(Module,sandbox_source_1,exception),throw(source_name_probe_error))),
            Error,true)),
    assertion(Error==source_name_probe_error),arg(1,Saved,Retired),
    assertion(Retired\==none),assertion(\+ predicate_property(Retired:_, defined)),
    assertion(\+ current_predicate(Retired:source_name_probe/1)).

test(forbidden_directives_remain_rejected_and_module_is_cleared,
     [forall(member(Mode,[blacklist,whitelist]))]) :-
    Saved=module(none),
    with_mode(Mode,
      catch(in_temporary_module(Module,nb_setarg(1,Saved,Module),
              node_sandbox:validate_and_load_source_text(actor,Module,
                  ":- initialization(true).\n",sandbox_source_1)),Error,true)),
    assertion(nonvar(Error)),
    assertion(Error=error(permission_error(execute,sandboxed_directive,(:- initialization(true))),_)),
    arg(1,Saved,Retired),assertion(Retired\==none),assertion(\+ predicate_property(Retired:_, defined)).

% Blacklist mode refuses a forbidden goal directive before loading. Whitelist
% mode refuses it when it executes (safe_goal/1), which SWI-Prolog reports as a
% load warning; either way the directive's effect must never happen.
test(forbidden_goal_directives_never_run,
     [forall((member(Mode,[blacklist,whitelist]),
              member(Text-Directive,
                     [":- open('/dev/null',read,S), close(S), assertz(directive_ran).\n"-
                          (open('/dev/null',read,S1),close(S1),assertz(directive_ran)),
                      "directive_fact(a).\n:- directive_fact(a), shell(true), assertz(directive_ran).\n"-
                          (directive_fact(a),shell(true),assertz(directive_ran))])))]) :-
    with_mode(Mode,
      catch(in_temporary_module(Module,true,
              ( node_sandbox:validate_and_load_source_text(actor,Module,Text,sandbox_source_1),
                (   current_predicate(Module:directive_ran/0)
                ->  throw(forbidden_directive_ran)
                ;   true ) )),
            Error,true)),
    (   Mode == blacklist
    ->  Error = error(permission_error(execute,sandboxed_directive,(:- Found)),_),
        assertion(Found=@=Directive)
    ;   assertion(Error \== forbidden_directive_ran)
    ).

test(safe_goal_directives_and_declarations_still_load,
     [forall(member(Mode,[blacklist,whitelist]))]) :-
    with_mode(Mode,
      in_temporary_module(Module,true,
        ( node_sandbox:validate_and_load_source_text(actor,Module,
              ":- dynamic directive_counter/1.\n:- assertz(directive_counter(1)).\n:- true.\n",
              sandbox_source_1),
          assertion(call(Module:directive_counter(1))) ))).

:- end_tests(sandbox_source_names).
