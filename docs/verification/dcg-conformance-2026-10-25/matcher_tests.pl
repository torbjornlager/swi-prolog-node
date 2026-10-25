:- use_module(probe,[]).
:- use_module(library(plunit)).
:- begin_tests(dcg_assessment_matcher).
test(listed_error_alternative) :-
 E=[_{kind:"error",formal:"instantiation_error"},_{kind:"error",formal:"type_error(callable,1)"}],
 dcg_assessment:classify(E,[],[],exception,type_error(callable,1),match).
test(culprit_not_hidden) :-
 dcg_assessment:classify([_{kind:"error",formal:"type_error(list,[a])"}],[],[],exception,type_error(list,[b]),culprit_difference).
test(type_not_hidden) :-
 dcg_assessment:classify([_{kind:"error",formal:"instantiation_error"}],[],[],exception,type_error(list,[a|_]),different).
test(wildcard_expansion) :-
 dcg_assessment:classify([_{kind:"error",formal:"type_error(callable,(...,...))"}],[],[],exception,type_error(callable,(a,b)),match).
test(binding_matches) :- dcg_assessment:matches_answer(['L'=_],"L=[a]",['L'=[a]]).
test(binding_cannot_instantiate_actual_to_pass,[fail]) :- dcg_assessment:matches_answer(['L'=_],"L=[a]",['L'=_]).
test(sharing_retained) :- dcg_assessment:matches_answer(['X'=_,'Y'=_],"X=Y",['X'=V,'Y'=V]).
test(sharing_mismatch_rejected,[fail]) :- dcg_assessment:matches_answer(['X'=_,'Y'=_],"X=Y",['X'=_,'Y'=_]).
test(solution_sequence) :-
 dcg_assessment:classify([_{kind:"solutions",answers:["L=[a]","L=[]"]}],['L'=_],[['L'=[a]],['L'=[]]],exhausted,none,match).
test(solution_prefix_insufficient) :-
 dcg_assessment:classify([_{kind:"solutions",answers:["L=[a]","L=[]"]}],['L'=_],[['L'=[a]]],exhausted,none,different).
test(nontermination_not_failure) :- dcg_assessment:classify([],[],[],time_limit,none,time_limit).
test(bounded_enumeration_not_pass) :- dcg_assessment:classify([],[],[],answer_limit,none,answer_limit).
:- end_tests(dcg_assessment_matcher).
