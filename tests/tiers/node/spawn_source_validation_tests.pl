:- module(test_spawn_source_validation, []).
:- use_module('../../../prolog/web_prolog/node.pl', []).
:- use_module('../../../prolog/web_prolog/node_sandbox.pl', []).
:- use_module('../../../prolog/web_prolog/node_execution_context.pl').
:- use_module('../../../prolog/web_prolog/actors.pl').
:- use_module(library(http/thread_httpd)).
:- use_module(library(socket)).
:- use_module(library(settings)).
:- use_module(library(plunit)).

:- meta_predicate with_source(-,-,0), with_mode(+,0).
:- thread_local restricted_origins/1.
:- multifile source_utils:load_uri_allowed_origins/1.
source_utils:load_uri_allowed_origins(Origins) :-
    test_spawn_source_validation:restricted_origins(Origins).

with_mode(Mode,Goal) :-
    setup_call_cleanup((setting(node:sandbox,Saved),set_setting(node:sandbox,Mode)),
                      Goal,set_setting(node:sandbox,Saved)).
with_source(URI,Requests,Goal) :-
    setup_call_cleanup(message_queue_create(Requests),
      setup_call_cleanup(
        (tcp_socket(Socket),tcp_bind(Socket,ip(127,0,0,1):Port),tcp_listen(Socket,16),
         http_server(test_spawn_source_validation:source_reply(Requests),
                     [tcp_socket(Socket),port(Port),workers(1)])),
        (format(atom(URI),'http://127.0.0.1:~w',[Port]),Goal),
        http_stop_server(Port,[])),
      message_queue_destroy(Requests)).
source_reply(Queue,Request) :-
    memberchk(path(Path),Request),thread_send_message(Queue,fetched(Path)),
    source_body(Path,Source),format('Content-type: text/plain; charset=UTF-8~n~n'),
    format('~s',[Source]).
source_body('/safe',"uri_probe(ok).\n").
source_body('/first',"first_uri(first).\n").
source_body('/second',"second_uri(second).\n").
source_body('/unsafe',"uri_bad :- open(missing,read,_).\n").
source_body('/directive',":- initialization(true).\nuri_probe(ok).\n").
url(Base,Path,URL) :- atom_concat(Base,Path,URL).
zero_fetches(Queue) :- assertion(\+ thread_get_message(Queue,_,[timeout(0)])).
checked(Goal) :- node_sandbox:sandbox_check_goal_in_module(actor,test_spawn_source_validation,Goal).

:- begin_tests(spawn_source_validation).

test(invalid_options_never_fetch,
     [forall((member(Mode,[blacklist,whitelist]),
              member(Invalid,[unknown(probe),link(maybe),monitor(1),node(42)])))]) :-
    with_mode(Mode,with_source(Base,Q,
      (test_spawn_source_validation:url(Base,'/safe',URI),
       catch(test_spawn_source_validation:checked(spawn(true,Pid,[src_uri(URI),Invalid])),E,true),
       assertion(nonvar(E)),assertion(var(Pid)),
       (Invalid=unknown(_)->assertion(E=error(domain_error(spawn_option,Invalid),_))
       ;assertion(E=error(type_error(_,_),_))),
       test_spawn_source_validation:zero_fetches(Q)))).

test(invalid_later_duplicate_never_fetches,
     [forall(member(Mode,[blacklist,whitelist]))]) :-
    with_mode(Mode,with_source(Base,Q,
      (test_spawn_source_validation:url(Base,'/safe',URI),
       catch(test_spawn_source_validation:checked(spawn(true,_,[src_uri(URI),monitor(true),monitor(maybe)])),E,true),
       assertion(nonvar(E)),assertion(E=error(type_error(boolean,maybe),_)),
       test_spawn_source_validation:zero_fetches(Q)))).

test(improper_ground_list_never_fetches,
     [forall(member(Mode,[blacklist,whitelist]))]) :-
    with_mode(Mode,with_source(Base,Q,
      (test_spawn_source_validation:url(Base,'/safe',URI),
       catch(test_spawn_source_validation:checked(spawn(true,_,[src_uri(URI)|bad])),E,true),
       assertion(nonvar(E)),assertion(E=error(type_error(list,_),_)),
       test_spawn_source_validation:zero_fetches(Q)))).

test(valid_literal_source_still_checked,
     [forall(member(Mode,[blacklist,whitelist]))]) :-
    with_mode(Mode,with_source(Base,Q,
      (test_spawn_source_validation:url(Base,'/safe',URI),
       test_spawn_source_validation:checked(spawn(uri_probe(ok),_,[src_uri(URI)])),
       assertion(thread_get_message(Q,fetched('/safe'),[timeout(0)]))))).

test(deferred_boolean_and_sharing,
     [forall(member(Mode,[blacklist,whitelist]))]) :-
    with_mode(Mode,with_source(Base,Q,
      (test_spawn_source_validation:url(Base,'/safe',URI),self(Parent),
       Options=[src_uri(URI),monitor(Bool)],Goal=(uri_probe(Value),Parent!uri_result(Value,Shared,Shared)),
       test_spawn_source_validation:checked(spawn(Goal,Pid,Options)),
       assertion(var(Bool)),assertion(var(Value)),assertion(var(Shared)),assertion(var(Pid)),
       test_spawn_source_validation:zero_fetches(Q),Bool=true,
       with_public_execution_profile(actor,spawn(Goal,Pid,Options)),
       receive({uri_result(Got,A,B)->true},[timeout(2),on_timeout(fail)]),
       assertion(Got==ok),assertion(var(A)),assertion(A==B),
       assertion(var(Value)),assertion(var(Shared)),
       receive({down(Pid,Pid,true)->true},[timeout(2),on_timeout(fail)]),
       assertion(thread_get_message(Q,fetched('/safe'),[timeout(0)]))))).

test(deferred_option_entry_is_not_instantiated,
     [forall(member(Mode,[blacklist,whitelist]))]) :-
    with_mode(Mode,with_source(Base,Q,
      (test_spawn_source_validation:url(Base,'/safe',URI),Options=[Option,src_uri(URI)],
       test_spawn_source_validation:checked(spawn(true,Pid,Options)),
       assertion(var(Option)),test_spawn_source_validation:zero_fetches(Q),
       Option=monitor(true),with_public_execution_profile(actor,spawn(true,Pid,Options)),
       receive({down(Pid,Pid,true)->true},[timeout(2),on_timeout(fail)]),
       assertion(thread_get_message(Q,fetched('/safe'),[timeout(0)]))))).

test(unknown_value_raises_at_runtime_without_fetch,
     [forall(member(Mode,[blacklist,whitelist]))]) :-
    with_mode(Mode,with_source(Base,Q,
      (test_spawn_source_validation:url(Base,'/safe',URI),Options=[src_uri(URI),monitor(Bool)],
       test_spawn_source_validation:checked(spawn(true,Pid,Options)),
       assertion(var(Bool)),
       catch(with_public_execution_profile(actor,spawn(true,Pid,Options)),E,true),
       assertion(nonvar(E)),assertion(E=error(instantiation_error,_)),
       assertion(var(Bool)),assertion(var(Pid)),test_spawn_source_validation:zero_fetches(Q)))).

test(source_order_and_clause_sharing,
     [forall(member(Mode,[blacklist,whitelist]))]) :-
    with_mode(Mode,with_source(Base,Q,
      (test_spawn_source_validation:url(Base,'/first',First),test_spawn_source_validation:url(Base,'/second',Second),
       self(Parent),Options=[src_uri(First),src_list([shared_uri(X,X)]),src_uri(Second),monitor(true)],
       Goal=(first_uri(FirstValue),second_uri(SecondValue),Rows=[FirstValue,SecondValue],shared_uri(A,B),Parent!ordered_result(Rows,A,B)),
       test_spawn_source_validation:checked(spawn(Goal,Pid,Options)),assertion(var(X)),
       test_spawn_source_validation:zero_fetches(Q),
       with_public_execution_profile(actor,spawn(Goal,Pid,Options)),
       receive({ordered_result(Got,C,D)->true},[timeout(2),on_timeout(fail)]),
       assertion(Got==[first,second]),assertion(var(C)),assertion(C==D),assertion(var(X)),
       receive({down(Pid,Pid,true)->true},[timeout(2),on_timeout(fail)]),
       assertion(thread_get_message(Q,fetched('/first'),[timeout(0)])),
       assertion(thread_get_message(Q,fetched('/second'),[timeout(0)]))))).

test(unsafe_source_remains_rejected,
     [forall((member(Mode,[blacklist,whitelist]),member(Path,['/unsafe','/directive'])))]) :-
    with_mode(Mode,with_source(Base,Q,
      (test_spawn_source_validation:url(Base,Path,URI),
       (Path=='/unsafe'->Goal=uri_bad;Goal=true),
       catch(test_spawn_source_validation:checked(spawn(Goal,_,[src_uri(URI)])),E,true),
       assertion(nonvar(E)),assertion(E=error(permission_error(_,_,_),_)),
       assertion(thread_get_message(Q,fetched(Path),[timeout(0)]))))).

test(origin_restriction_remains_before_fetch,
     [forall(member(Mode,[blacklist,whitelist]))]) :-
    with_mode(Mode,with_source(Base,Q,
      (test_spawn_source_validation:url(Base,'/safe',URI),
       setup_call_cleanup(assertz(test_spawn_source_validation:restricted_origins(['https://not-this-origin.invalid'])),
         catch(test_spawn_source_validation:checked(spawn(true,_,[src_uri(URI)])),E,true),
         retractall(test_spawn_source_validation:restricted_origins(_))),
       assertion(nonvar(E)),assertion(E=error(permission_error(load,source_uri,_),_)),
       test_spawn_source_validation:zero_fetches(Q)))).

test(size_limit_remains_enforced,
     [forall(member(Mode,[blacklist,whitelist]))]) :-
    with_mode(Mode,with_source(Base,Q,
      (test_spawn_source_validation:url(Base,'/safe',URI),
       setup_call_cleanup((setting(node_input_limits:max_load_text_bytes,Saved),set_setting(node_input_limits:max_load_text_bytes,8)),
         catch(test_spawn_source_validation:checked(spawn(true,_,[src_uri(URI)])),E,true),
         set_setting(node_input_limits:max_load_text_bytes,Saved)),
       assertion(nonvar(E)),assertion(E=error(request_size_exceeded(src_uri,_,8),_)),
       assertion(thread_get_message(Q,fetched('/safe'),[timeout(0)]))))).

test(deferred_values_do_not_hide_forbidden_goal,
     [forall(member(Mode,[blacklist,whitelist]))]) :-
    with_mode(Mode,with_source(Base,Q,
      (test_spawn_source_validation:url(Base,'/safe',URI),Options=[monitor(Bool),src_uri(URI)],
       catch(test_spawn_source_validation:checked(spawn(open(missing,read,_),_,Options)),E,true),
       assertion(nonvar(E)),assertion(E=error(permission_error(call,sandboxed,_),_)),
       assertion(var(Bool)),test_spawn_source_validation:zero_fetches(Q)))).

test(deferred_source_is_checked_before_activation,
     [forall(member(Mode,[blacklist,whitelist]))]) :-
    with_mode(Mode,with_source(Base,Q,
      (test_spawn_source_validation:url(Base,'/unsafe',URI),Options=[src_uri(URI),monitor(Bool)],
       test_spawn_source_validation:checked(spawn(uri_bad,Pid,Options)),
       assertion(var(Bool)),test_spawn_source_validation:zero_fetches(Q),Bool=true,
       catch(with_public_execution_profile(actor,spawn(uri_bad,Pid,Options)),E,true),
       assertion(nonvar(E)),assertion(E=error(permission_error(call,sandboxed,_),_)),
       assertion(var(Pid)),assertion(thread_get_message(Q,fetched('/unsafe'),[timeout(0)]))))).

:- end_tests(spawn_source_validation).
