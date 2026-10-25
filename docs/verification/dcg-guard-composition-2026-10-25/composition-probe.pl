 :- module(dcg_composition_probe,[main/0]).
:- use_module('prolog/web_prolog/node.pl',[]).
:- use_module('prolog/web_prolog/public_goal_guard.pl',[]).
:- use_module('prolog/web_prolog/control_guard.pl',[]).
:- use_module('prolog/web_prolog/node_execution_context.pl').
:- use_module(library(settings)).

tokens --> [a,b].
native_literal --> "ab".

probe(Label,Grammar) :-
 Goal=..[phrase,Grammar,Input],
 public_goal_guard:rewrite_goal_if_needed(dcg_composition_probe,Goal,Public),
 control_guard:rewrite_goal(dcg_composition_probe,Public,Combined),
 writeq(rewritten(Label,Public,Combined)),nl,
 observe(Label-public_only,Public,Input),
 observe(Label-combined,Combined,Input).
observe(Label,Goal,Input) :-
 catch((call(dcg_composition_probe:Goal)->Result=success(Input);Result=failure),E,Result=error(E)),
 writeq(result(Label,Result)),nl.
main :-
 set_setting(node:sandbox,blacklist),
 with_public_execution_profile(actor,
   (probe(terminals,[a,b]),probe(named,tokens),probe(native_string_dcg,native_literal),
    probe(forbidden,{nb_getval(must_not_read,_)}))),halt.
