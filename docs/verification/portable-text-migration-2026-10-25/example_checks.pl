% Read-only example checks. No provider/network service is called.
:- module(test_text_examples, []).
:- consult('../../../load.pl').
:- use_module('../../../tests/tiers/node/node_tests.pl', []).
:- use_module('../../../prolog/web_prolog/text_config.pl').
:- use_module('../../../prolog/web_prolog/isolation.pl', []).
:- use_module(library(plunit)).
:- use_module(library(readutil)).
:- use_module(library(http/json)).
:- use_module(library(modules)).
:- use_module(library(http/websocket)).
:- use_module(library(time)).
:- use_module('../../../prolog/web_prolog/wire_text.pl').

root(Root) :- getenv('WP_AUDIT_DEMONSTRATOR_ROOT',Root),Root\==''.
source(Rel,Text) :- root(Root),directory_file_path(Root,Rel,File),read_file_to_string(File,Text,[]).
selected(Text,Value) :- (text_double_quotes(chars)->string_chars(Text,Value);Value=Text).

example_input(Id,Goal) :-
    source_file(test_text_examples:example_input(_,_),Here),file_directory_name(Here,Dir),
    directory_file_path(Dir,'example-check-inputs.json',File),
    setup_call_cleanup(open(File,read,S),json_read_dict(S,Rows),close(S)),
    member(Row,Rows),atom_string(Id,Row.id),!,
    string_concat("?- ",WithStop,Row.text),
    normalize_query_fragment(WithStop,Goal).

% The HTTP parameter is a query fragment; the UI prefix and final full stop
% are framing, not part of that parameter. Keep the enclosed query unchanged.
normalize_query_fragment(Text,Goal) :-
    string_codes(Text,Codes),reverse(Codes,Rev),
    drop_space(Rev,Trimmed),Trimmed=[0'.|Rest],reverse(Rest,Body),string_codes(Goal,Body).
drop_space([C|Cs],Rest) :- code_type(C,space),!,drop_space(Cs,Rest).
drop_space(Rest,Rest).

public_example(Id,Template,Expected) :-
    example_input(Id,Goal),
    test_node:with_node_server_options([profile(actor),auth(open),sandbox(blacklist)],URI,
      test_text_examples:setup_call_cleanup(test_node:ws_open(URI,WS),
        call_with_time_limit(7,
          (test_node:ws_send_json(WS,json{command:transport_hello,version:1,answer_terms:true}),
           test_node:ws_receive_json(WS,Welcome),get_dict(type,Welcome,WelcomeType),assertion(WelcomeType=="transport_welcome"),
           test_node:ws_send_json(WS,json{command:toplevel_spawn,options:"[session(true)]"}),
           test_node:ws_receive_json(WS,Spawned),get_dict(type,Spawned,SpawnType),assertion(SpawnType=="spawned"),get_dict(pid,Spawned,Pid),
           atomic_list_concat(['[template(',Template,'),format(prolog),limit(2)]'],Options),
           test_node:ws_send_json(WS,json{command:toplevel_call,pid:Pid,goal:Goal,options:Options}),
           receive_answer(WS,Pid,30,Reply),
           get_dict(type,Reply,ReplyType),assertion(ReplyType=="success"),
           get_dict(term,Reply,Term),wire_text_to_term(Term,Rows),
           assertion(Rows==[Expected]),get_dict(more,Reply,More),assertion(More==false))),
        catch(ws_close(WS,1000,done),_,true))).

receive_answer(_,_,0,_) :- throw(example_event_limit).
receive_answer(WS,Pid,N,Reply) :-
    test_node:ws_receive_json(WS,Event),get_dict(type,Event,Type),
    (memberchk(Type,["success","failure","error"]),get_dict(pid,Event,Pid)
    -> Reply=Event
    ; memberchk(Type,["output","down"])
    -> Left is N-1,receive_answer(WS,Pid,Left,Reply)
    ; throw(unexpected_example_event(Event))).

:- begin_tests(portable_text_example_checks).
test(tutorial_receive_format) :-
    test_text_examples:public_example('mpc-receive-clauses','true',true).
test(tutorial_guard_format) :-
    test_text_examples:public_example('mpc-guard','true',true).
test(tutorial_timeout_format) :-
    test_text_examples:public_example('mpc-timeout','true',true).
test(tutorial_private_source_price) :-
    test_text_examples:public_example('shadow-private-price','Price',90.0).
test(tutorial_private_source_list) :-
    test_text_examples:public_example('shadow-private-list','Prices',[widget-80]).
test(word_list_grammar) :-
    source('examples/actors/02 grammar.pl',Source),
    in_temporary_module(M,isolation:prepare_actor_module(M,user,[]),
      (isolation:load_source_text(Source,M,example_grammar),
       findall(Tree,M:phrase(s(Tree),[john,sees,a,man,with,a,telescope]),Trees),
       length(Trees,Count),assertion(Count==2))).
test(shared_db_common_and_n3_overlay) :-
    source('Deployment/shared_db_common.pl',Common),
    source('Deployment/shared_db_actor_common.pl',Actors),
    source('Deployment/shared_db_n3.pl',Overlay),
    atomics_to_string([Common,Actors,Overlay],"\n",Source),
    test_node:with_node_server_options([load_shared_db_text(Source)],URI,
      (test_node:call_url(URI,'(price(widget,P),ancestor_descendant(tom,sally),shared_fact(F))',
                         'P-F',0,2,'',none,URL),
       test_node:read_answer(URL,Answer),assertion(Answer==success([100-n3_shared_db],false)))).
test(model_example_rejects_charlist_at_native_guard) :-
    source('examples/actors/21 model-actor.pl',Source),
    in_temporary_module(M,isolation:prepare_actor_module(M,user,[]),
      (isolation:load_source_text(Source,M,example_model),
       M:chat_exchange([h,i],[],Result,History),
       assertion(Result==error(invalid_prompt)),assertion(History==[]))).
test(model_service_validation_only) :-
    root(Root),directory_file_path(Root,'examples/services/model_service.pl',File),
    use_module(File,[]),
    assertion(model_service:message_text("hi",500,2)),
    assertion(\+ model_service:message_text([h,i],500,_)).
test(jev_service_validation_only) :-
    root(Root),directory_file_path(Root,'examples/services/jev_service.pl',File),
    use_module(File,[]),
    assertion(jev_service:valid_text("hi")),assertion(\+jev_service:valid_text([h,i])).
:- end_tests(portable_text_example_checks).
