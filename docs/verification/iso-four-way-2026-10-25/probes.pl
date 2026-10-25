:- module(iso_assessment,[main/0]).
:- use_module(library(http/json)).
:- use_module(library(time)).
:- use_module(library(modules)).
:- use_module(library(settings)).
:- use_module(library(option)).
:- op(800,xfx,!).
:- op(200,xfx,@).
:- op(1000,xfy,if).
static_probe(a).
abolish_probe(a).
:- dynamic dynamic_copy_probe/2.
dynamic_copy_probe(pair(X,X),[97,98]).
copy_probe(pair(X,X),[97,98]).
copy_worker(Parent) :- copy_probe(pair(A,B),Codes),
    actors:self(Me),actors:send(Parent,assessment_reply(Me,copied(A,B,Codes))).

main :-
    current_prolog_flag(argv,[Root,Mode,Output]),
    directory_file_path(Root,'load.pl',Loader),load_files(Loader,[silent(true)]),
    setup_call_cleanup(message_queue_create(Q),
      (thread_create(iso_assessment:old_worker(Q),Old,[]),
       (memberchk(Mode,[iso,iso_chars])->set_prolog_flag(iso,true);true),
       current_prolog_flag(iso,ISO),text_config:text_double_quotes(Quotes),
       findall(Row,language_case(Quotes,Row),Language),
       findall(Row,integration_case(Row),Integration),
       findall(Row,inheritance_case(Old,Q,Row),Inheritance),
       thread_join(Old,OldStatus),
       append([Language,Integration,Inheritance],Rows),
       % Formatting metadata is not part of the assessed execution scope.
       set_prolog_flag(iso,false),
       length(Rows,N),
       Report=_{mode:Mode,iso:ISO,language_double_quotes:Quotes,
                host_loading:before_iso_switch,report_writer_iso:false,
                old_thread_status:OldStatus,case_count:N,cases:Rows},
       setup_call_cleanup(open(Output,write,S,[encoding(utf8)]),
         json_write_dict(S,Report,[width(0)]),close(S))),
      message_queue_destroy(Q)),halt.

capture(Id,Group,Goal,Value,Row) :-
    get_time(Start),
    catch(call_with_time_limit(5,(once(Goal)->Outcome=success(Value);Outcome=failure)),
          E,Outcome=exception(E)),
    get_time(End),Ms is round((End-Start)*1000),
    (Outcome=success(_)->Kind=success;Outcome=failure->Kind=failure;Kind=exception),
    printable(Outcome,Text),
    (Outcome=exception(error(Formal,_))->printable(Formal,FormalText);FormalText=""),
    Row=_{id:Id,category:Group,kind:Kind,outcome:Text,formal:FormalText,duration_ms:Ms}.
printable(Term,Text) :- copy_term(Term,Copy),numbervars(Copy,0,_),
    with_output_to(string(Text),write_term(Copy,[quoted(true),ignore_ops(true),numbervars(true),portray(false)])).

syntax('S01','"abc"').
syntax('S02','"😀"').
syntax('S03','[a :- b, c]').
syntax('S04','[(a :- b), c]').
syntax('S05','X == -, true').
syntax('S06','f(,,a)').
syntax('S07','_{a:1,b:"x"}').
syntax('S08','receive({hello -> true})').
language_case(Quotes,Row) :- syntax(Id,Text),
    capture(Id,syntax,read_term_from_atom(Text,Term,[module(iso_assessment),double_quotes(Quotes)]),Term,Row).
query('A01',arithmetic,'X is 4/2').
query('A02',arithmetic,'compare(Order,1.5,1)').
query('A03',arithmetic,'X is -7//3, R is -7 rem 3').
query('E01',errors,'atom_length(42,N)').
query('E02',errors,'X is 1/0').
query('E03',errors,'call(X)').
query('E04',errors,'clause(static_probe(X),B)').
query('E05',errors,'abolish(iso_assessment:abolish_probe/1)').
query('E06',errors,'read_term_from_atom(x,T,[assessment_unknown_option(true)])').
query('D01',dcg,'phrase("ab",Tokens)').
query('D02',dcg,'phrase(([a],!,[b]),[a,b])').
query('D03',dcg,'phrase((\\+ [b],[a]),[a])').
query('D04',dcg,'phrase([a|Tail],[a])').
query('D05',dcg,'phrase((\\+ 1,[]),[])').
language_case(Quotes,Row) :- query(Id,Group,Text),
    capture(Id,Group,read_and_call(Quotes,Text,Bindings),Bindings,Row).
read_and_call(Quotes,Text,Bindings) :-
    read_term_from_atom(Text,Goal,[module(iso_assessment),double_quotes(Quotes),variable_names(Bindings)]),
    call(Goal).

integration_case(Row) :-
    capture('C01',source,private_source('p("ab").',p(Value)),Value,Row).
integration_case(Row) :-
    capture('C02',source,static_copy(Value),Value,Row).
integration_case(Row) :-
    capture('C03',source,actor_copy(Value),Value,Row).
integration_case(Row) :-
    capture('C04',source,constructed_source(Value),Value,Row).
integration_case(Row) :-
    capture('C05',dcg,private_source('tokens --> "ab".',phrase(tokens,Value)),Value,Row).
integration_case(Row) :-
    capture('C06',source,(node:set_node_shared_db('assessment_shared("ab").'),
                        node:call_current_shared_db(assessment_shared(Value))),Value,Row).
integration_case(Row) :-
    capture('C07',source,private_listing(Text),Text,Row).
integration_case(Row) :-
    capture('C08',source,dynamic_copy(Value),Value,Row).
integration_case(Row) :-
    capture('C09',source,dynamic_listing(Text),Text,Row).
integration_case(Row) :- member(Policy,[blacklist,whitelist]),
    atom_concat('B_rule_',Policy,Id),
    capture(Id,sandbox,with_policy(Policy,
      (node_sandbox:sandbox_check_goal_with_source(actor,actor,p(X),'p(X) :- X is 4/2.'),var(X))),admitted_nonbinding,Row).
integration_case(Row) :- member(Policy,[blacklist,whitelist]),
    atom_concat('B_safe_',Policy,Id),
    capture(Id,sandbox,with_policy(Policy,
      (node_sandbox:sandbox_check_goal_with_source(actor,actor,p(X),'p("ab").'),var(X))),admitted_nonbinding,Row).
integration_case(Row) :- member(Policy,[blacklist,whitelist]),
    atom_concat('B_deny_',Policy,Id),
    capture(Id,sandbox,with_policy(Policy,
      node_sandbox:sandbox_check_goal_with_source(actor,actor,p,
        'p :- open(assessment_forbidden,write,S),close(S).')),admitted,Row).
integration_case(Row) :-
    capture('B_guarded_dcg',sandbox,with_policy(blacklist,
      node_execution_context:with_public_execution_profile(actor,
        iso_assessment:guarded_dcg(Tokens))),Tokens,Row).

private_source(Source,Goal) :-
    in_temporary_module(M,isolation:prepare_actor_module(M,iso_assessment,[]),
      (isolation:load_source_text(Source,M,assessment_source),call(M:Goal))).
static_copy(copied(A,B,Codes)) :-
    source_utils:predicates_to_source(iso_assessment,[copy_probe/2],Source),
    private_source(Source,copy_probe(pair(A,B),Codes)),var(A),A==B,Codes==[97,98].
dynamic_copy(copied(A,B,Codes)) :-
    source_utils:predicates_to_source(iso_assessment,[dynamic_copy_probe/2],Source),
    private_source(Source,dynamic_copy_probe(pair(A,B),Codes)),var(A),A==B,Codes==[97,98].
dynamic_listing(Text) :-
    in_temporary_module(M,isolation:prepare_actor_module(M,iso_assessment,[]),
      (isolation:load_source_text(':- dynamic p/1. p(a).',M,assessment_dynamic_listing),
       isolation:private_listing_predicate_clauses(M,p,1,Clauses),printable(Clauses,Text))).
constructed_source(copied(A,B,Codes)) :-
    source_utils:terms_to_source([p(pair(X,X),[97,98])],Source),var(X),
    private_source(Source,p(pair(A,B),Codes)),var(A),A==B,Codes==[97,98].
private_listing(Text) :-
    in_temporary_module(M,isolation:prepare_actor_module(M,iso_assessment,[]),
      (isolation:load_source_text('p(a).',M,assessment_listing),
       isolation:private_listing_predicate_clauses(M,p,1,Clauses),printable(Clauses,Text))).
with_policy(Policy,Goal) :-
    setup_call_cleanup((setting(node:sandbox,Old),set_setting(node:sandbox,Policy)),
                       call(Goal),set_setting(node:sandbox,Old)).
:- meta_predicate with_policy(+,0).
guarded_dcg(Tokens) :-
    wire_text:wire_text_to_term('phrase("ab",Tokens)',Goal),
    Goal=phrase(_,Tokens),isolation:prepared_goal(iso_assessment,Goal,Safe),call(iso_assessment:Safe).

actor_copy(Value) :-
    actors:self(Parent),
    scoped_actor(copy_worker(Parent),[src_predicates([copy_worker/1,copy_probe/2])],Value),
    Value=copied(A,B,Codes),var(A),A==B,Codes==[97,98].
scoped_actor(Goal,Options,Value) :-
    setup_call_cleanup(actors:spawn(iso_assessment:Goal,Pid,[monitor(true)|Options]),
      (actors:receive({assessment_reply(Pid,Value)->true;
                      down(Pid,Pid,Reason)->throw(early_actor_exit(Reason))},
                     [timeout(2),on_timeout(throw(missing_actor_reply))]),
       actors:receive({down(Pid,Pid,true)->true},
                     [timeout(2),on_timeout(throw(missing_actor_down))])),
      (catch(actors:exit(Pid,assessment_cleanup),_,true),
       catch(actors:demonitor(Pid,[flush]),_,true))).

old_worker(Q) :- thread_get_message(go),raw_flags(Value),thread_send_message(Q,old(Value)).
raw_flags(flags(ISO,HostQuotes,LanguageQuotes,Term)) :-
    current_prolog_flag(iso,ISO),current_prolog_flag(double_quotes,HostQuotes),
    text_config:text_double_quotes(LanguageQuotes),wire_text:wire_text_to_term('"ab"',Term).
inheritance_case(Old,Q,Row) :-
    capture('W01',inheritance,(thread_send_message(Old,go),thread_get_message(Q,old(Value),[timeout(2)])),Value,Row).
inheritance_case(_,_,Row) :-
    capture('W02',inheritance,
      setup_call_cleanup(message_queue_create(Q),
        (thread_create((iso_assessment:raw_flags(Value),thread_send_message(Q,fresh(Value))),Id,[]),
         thread_get_message(Q,fresh(Value),[timeout(2)]),thread_join(Id,true)),
        message_queue_destroy(Q)),Value,Row).
inheritance_case(_,_,Row) :-
    capture('W03',inheritance,actor_flags(Value),Value,Row).
actor_flags(Value) :-
    actors:self(Parent),
    Source='run(P) :- current_prolog_flag(iso,I),current_prolog_flag(double_quotes,D),read_term_from_atom(\'"ab"\',T,[]),self(Me),isolation:actor_module(Me,M),current_prolog_flag(M:double_quotes,MD),read_term_from_atom(\'"ab"\',Explicit,[module(M)]),Literal="ab",send(P,assessment_reply(Me,flags(I,D,T,MD,Literal,Explicit))).',
    scoped_actor(run(Parent),[src_text(Source)],Value).
