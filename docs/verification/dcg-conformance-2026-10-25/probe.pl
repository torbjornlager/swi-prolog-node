:- module(dcg_assessment, [main/0]).
:- use_module(library(json)).
:- use_module(library(time)).
:- use_module(library(settings)).

% All tested goals are read as data. No literal phrase call is compiled here.
text(T,S) :- copy_term(T,C),numbervars(C,0,_),term_string(C,S,[quoted(true),numbervars(true)]).
emit(D) :- json_write_dict(current_output,D,[width(0)]),nl,flush_output.
main :-
 current_prolog_flag(argv,[Mode,Input,Fixture]),
 setup_call_cleanup(open(Input,read,Stream),json_read_dict(Stream,Case),close(Stream)),
 (Mode==guarded -> directory_file_path(Fixture,'prolog/web_prolog/node.pl',Node),use_module(Node,[]),set_setting(node:sandbox,blacklist);true),
 (get_dict(quote_mode,Case,Q) -> atom_string(QuoteMode,Q),set_prolog_flag(dcg_assessment:double_quotes,QuoteMode);true),
 (get_dict(source,Case,Source) -> load_test_source(Mode,Source);true),
 read_term_from_atom(Case.query,Goal,[variable_names(Vars),module(dcg_assessment)]),
 nb_setval(answers,[]),nb_setval(stage,execution),nb_setval(terminal,exhausted),nb_setval(prepared,not_prepared),
 catch(call_with_time_limit(1,run(Mode,Goal,Vars)),Error,record_error(Error)),
 nb_getval(answers,Reverse),reverse(Reverse,Answers),nb_getval(terminal,Terminal),nb_getval(stage,Stage),
 maplist(text,Answers,AnswerText),
 (nb_current(caught,Exception)->text(Exception,ExceptionText),formal(Exception,Formal),text(Formal,FormalText);ExceptionText="",FormalText="",Formal=none),
 classify(Case.expected,Vars,Answers,Terminal,Formal,Classification),
 nb_getval(prepared,Prepared),text(Prepared,PreparedText),current_prolog_flag(dcg_assessment:double_quotes,Quotes),current_prolog_flag(iso,Iso),
 emit(_{prepared:PreparedText,double_quotes:Quotes,iso:Iso,mode:Mode,id:Case.id,stage:Stage,terminal:Terminal,answers:AnswerText,exception:ExceptionText,formal:FormalText,classification:Classification}),halt.
load_test_source(direct,Source) :- !,
 setup_call_cleanup(open_string(Source,In),load_files(dcg_assessment:dcg_assessment_text,[stream(In),silent(true)]),close(In)).
load_test_source(guarded,Source) :-
 node_execution_context:with_public_execution_profile(actor,
   isolation:load_source_text(Source,dcg_assessment,dcg_assessment_text)).
run(direct,Goal,Vars) :- !,nb_setval(prepared,Goal),enumerate(Goal,Vars).
run(guarded,Goal,Vars) :-
 node_execution_context:with_public_execution_profile(actor,
   (nb_setval(stage,admission),node_sandbox:sandbox_check_goal_in_module(actor,dcg_assessment,Goal),
    nb_setval(stage,preparation),isolation:prepared_goal(dcg_assessment,Goal,Safe),
    nb_setval(prepared,Safe),nb_setval(stage,execution),dcg_assessment:enumerate(Safe,Vars))).
enumerate(Goal,Vars) :-
 (call(Goal),copy_term(Vars,Answer),nb_getval(answers,Old),nb_setval(answers,[Answer|Old]),
  length(Old,N),(N>=10 -> nb_setval(terminal,answer_limit);fail)
 ; true).
record_error(Error) :-
 nb_setval(caught,Error),
 (Error==time_limit_exceeded -> nb_setval(terminal,time_limit);nb_setval(terminal,exception)).
formal(error(F,_),F) :- !.
formal(E,E).

% Comparison matching preserves all listed alternatives. Only implementation
% error context is discarded; type and culprit differences remain visible.
classify(_,_,_,time_limit,_,time_limit) :- !.
classify(_,_,_,answer_limit,_,answer_limit) :- !.
classify(Expected,Vars,Answers,Terminal,Formal,match) :-
 member(E,Expected),matches(E,Vars,Answers,Terminal,Formal),!.
classify(Expected,_,_,exception,Formal,culprit_difference) :-
 member(E,Expected),E.kind=="error",read_term_from_atom(E.formal,Pattern,[]),
 same_error_family(Pattern,Formal),!.
classify(_,_,_,_,_,different).
matches(E,_,_,exception,Formal) :- E.kind=="error",!,
 read_term_from_atom(E.formal,Pattern0,[]),wildcards(Pattern0,Pattern),copy_term(Formal,Actual),Pattern=Actual.
matches(E,Vars,Answers,exhausted,_) :- E.kind=="solutions",same_length(E.answers,Answers),
 maplist(matches_answer(Vars),E.answers,Answers).
matches_answer(Vars,Constraint,Actual) :-
 copy_term(Vars,ExpectedVars),read_term_from_atom(Constraint,Goal,[variable_names(Names),module(dcg_assessment)]),
 share_names(Names,ExpectedVars),call(Goal),ExpectedVars =@= Actual.
share_names([], _).
share_names([Name=Value|Rest],Vars) :- (memberchk(Name=Var,Vars)->Value=Var;true),share_names(Rest,Vars).
wildcards(T,_) :- T=='...',!.
wildcards(T,T) :- var(T),!.
wildcards(T,T) :- atomic(T),!.
wildcards(T,P) :- T=..[F|Args],maplist(wildcards,Args,New),P=..[F|New].
same_error_family(type_error(Type,_),type_error(Type,_)).
same_error_family(existence_error(Type,_),existence_error(Type,_)).
same_error_family(permission_error(Op,Type,_),permission_error(Op,Type,_)).
