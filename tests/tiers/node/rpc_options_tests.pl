:- module(test_rpc_options, []).

:- use_module('../../../prolog/web_prolog/rpc.pl').
:- use_module(library(http/thread_httpd)).
:- use_module(library(plunit)).

:- meta_predicate with_endpoint(-,-,0), with_answer(-,0).

with_endpoint(URI, Requests, Goal) :-
    setup_call_cleanup(message_queue_create(Requests),
        setup_call_cleanup(
            http_server(reply(Requests), [port(Port),workers(1)]),
            (format(atom(URI),'http://localhost:~w',[Port]), Goal),
            http_stop_server(Port, [])),
        message_queue_destroy(Requests)).

reply(Requests, Request) :-
    thread_send_message(Requests, Request),
    format('Content-type: application/x-prolog~n~nsuccess([v(a),v(b)],false).~n').

with_answer(Ref, Goal) :-
    setup_call_cleanup(
        (rpc:make_reference(Ref),
         rpc:promise_queue_key(Ref, Key),
         with_mutex(promise_lifecycle,rpc:new_promise_state(Key,_)),
         rpc:deliver_promise_answer(Key,failure)),
        Goal,
        rpc:promise_cleanup(Ref)).

invoke(rpc, URI, Options) :- rpc(URI,true,Options).
invoke(promise, URI, Options) :- promise(URI,true,_,Options).
invoke(yield, _, Options) :- yield(123,_,Options).

option_domain(rpc, rpc_option).
option_domain(promise, promise_option).
option_domain(yield, yield_option).

:- begin_tests(rpc_options).

test(unknown_before_uri_or_wait, [forall(member(Kind,[rpc,promise,yield]))]) :-
    option_domain(Kind, Domain),
    catch(invoke(Kind, 17, [timout(1)]), Error, true),
    assertion(Error = error(domain_error(Domain,timout(1)),context(_,_))).
test(malformed_option_arity, [forall(member(Option,[once,once(true,false),42]))]) :-
    catch(rpc(17,true,[Option]), Error, true),
    assertion(Error = error(domain_error(rpc_option,Option),_)).
test(non_list, [forall(member(Kind,[rpc,promise,yield]))]) :-
    catch(invoke(Kind,17,bad), Error, true),
    assertion(Error = error(type_error(list,bad),_)).
test(partial_list, [forall(member(Kind,[rpc,promise,yield]))]) :-
    catch(invoke(Kind,17,[once(true)|Tail]), Error, true),
    assertion(Error = error(instantiation_error,_)), assertion(var(Tail)).
test(variable_option_not_instantiated, [forall(member(Kind,[rpc,promise,yield]))]) :-
    catch(invoke(Kind,17,[Option]), Error, true),
    assertion(Error = error(instantiation_error,_)), assertion(var(Option)).
test(wrong_operation, [forall(member(Kind-Option,
    [rpc-template(_),rpc-offset(0),rpc-on_timeout(true),
     promise-on_timeout(true),yield-limit(1),yield-http_timeout(1),yield-src_text('')]))]) :-
    option_domain(Kind, Domain),
    catch(invoke(Kind,17,[Option]), Error, true),
    assertion(Error = error(domain_error(Domain,Option),_)).
test(no_arbitrary_http_passthrough,
     [forall(member(Option,[status_code(_),method(post),post(atom(body)),deadline(0)]))]) :-
    catch(rpc(17,true,[Option]), Error, true),
    assertion(Error = error(domain_error(rpc_option,Option),_)).
test(bad_values_before_source_fetch,
     [forall(member(Option,[limit(0),once(maybe),timeout(bad),http_timeout(bad),
                          src_text(17),src_list(bad),src_uri(17),
                          src_predicates([p]),src_predicates([p/(-1)]),
                          request_header(bad),request_header(x=_),
                          authorization(digest(u,p)),authorization(bearer(_)),
                          user_agent(17)]))]) :-
    catch(rpc(17,true,[src_uri('http://127.0.0.1:1/never'),Option]), Error, true),
    assertion(nonvar(Error)), assertion(Error = error(_,context(rpc:rpc/3,_))).
test(bad_promise_offset, [throws(error(type_error(nonneg,-1),_))]) :-
    promise(17,true,_,[offset(-1)]).
test(promise_validation_does_not_allocate) :-
    aggregate_all(count,rpc:promise_state(_,_,_,_,_,_,_),Before),
    catch(promise(17,true,Ref,[src_uri('http://127.0.0.1:1/never'),typo(1)]),Error,true),
    assertion(Error = error(domain_error(promise_option,typo(1)),_)),
    assertion(var(Ref)),
    aggregate_all(count,rpc:promise_state(_,_,_,_,_,_,_),After), assertion(Before==After).
test(template_sharing_and_source_repetition) :-
    Options=[template(f(X,X)),src_text('p(a).'),src_text("p(b)."),src_list([q(X)])],
    rpc:validate_client_options(promise,Options),
    assertion(var(X)), Options=[template(f(A,B))|_], assertion(A==B).
test(native_source_text_representations,
     [forall(member(Text,['p.',"p.",[112,46],[p,'.']]))]) :-
    rpc:validate_client_options(rpc,[src_text(Text)]).
test(numeric_timeout_conventions) :-
    rpc:validate_client_options(rpc,[timeout(-1),http_timeout(-1)]),
    catch(rpc:validate_client_options(rpc,[timeout(Unspecified)]),Error,true),
    assertion(Error=error(instantiation_error,_)),assertion(var(Unspecified)),
    catch(rpc:validate_client_options(rpc,[timeout(none)]),NoneError,true),
    assertion(NoneError=error(type_error(number,none),_)),
    rpc:rpc_http_options([http_timeout(-1)],HTTP), assertion(HTTP==[timeout(0)]).
test(transport_projection) :-
    rpc:rpc_http_options([limit(1),src_text('p.'),once(true),timeout(2),
        http_timeout(3),request_header(x='one'),request_header(y="two"),
        authorization(bearer(token)),user_agent('agent')], HTTP),
    assertion(HTTP==[timeout(3),request_header(x='one'),request_header(y=two),
                     request_header(authorization='Bearer token'),user_agent('agent')]).
test(http_field_aliases_and_case_first_wins) :-
    Options=[request_header('X-Test'=[f,i,r,s,t]),request_header('x-test'=later),
             authorization(bearer(first)),request_header('AUTHORIZATION'=later),
             request_header('User-Agent'=first),user_agent(later)],
    rpc:validate_client_options(rpc,Options),rpc:rpc_http_options(Options,HTTP),
    assertion(HTTP==[request_header('x-test'=first),
        request_header(authorization='Bearer first'),user_agent(first)]).
test(http_unicode_projection) :-
    rpc:rpc_http_options([request_header(x='狐狸'),authorization(basic('räv','päss'))],HTTP),
    atom_codes(Bytes,[231,139,144,231,139,184]),
    assertion(HTTP==[request_header(x=Bytes),request_header(authorization='Basic csOkdjpww6Rzcw==')]).
test(node_uri_path_prefix_is_preserved) :-
    with_endpoint(Base,Requests,
      (atom_concat(Base,'/prefix/',URI),
       findall(X,rpc(URI,p(X),[http_timeout(1)]),[a,b]),
       thread_get_message(Requests,Request),assertion(memberchk(path('/prefix/call'),Request)),
       promise(URI,p(Y),Ref,[template(v(Y)),http_timeout(1)]),
       yield(Ref,success([v(a),v(b)],false)),assertion(var(Y)),
       thread_get_message(Requests,PromiseRequest),assertion(memberchk(path('/prefix/call'),PromiseRequest)))).

test(rpc_http_headers_and_nondeterminism) :-
    with_endpoint(URI,Requests,
        (findall(X,rpc(URI,p(X),[limit(2),once(true),http_timeout(2),
            request_header('X-First'=one),request_header('X-Second'="two"),
            authorization(bearer(token)),user_agent('option-test')]),Xs),
         assertion(Xs==[a,b]),
         thread_get_message(Requests,Request,[timeout(2)]),
         assertion(memberchk(x_first(one),Request)),
         assertion(memberchk(x_second(two),Request)),
         assertion(memberchk(authorization('Bearer token'),Request)),
         assertion(memberchk(user_agent('option-test'),Request)))).
test(promise_http_headers_and_collection) :-
    with_endpoint(URI,Requests,
        (promise(URI,p(X),Ref,[template(X),offset(1),http_timeout(2),
                             authorization(basic(user,"password"))]),
         yield(Ref,Answer,[timeout(2)]), assertion(Answer==success([v(a),v(b)],false)),
         assertion(var(X)),
         thread_get_message(Requests,Request,[timeout(2)]),
         assertion(memberchk(authorization('Basic dXNlcjpwYXNzd29yZA=='),Request)))).
test(duplicate_ordinary_options_keep_first) :-
    with_endpoint(URI,Requests,
        (findall(X,rpc(URI,p(X),[limit(2),limit(3)]),Xs),assertion(Xs==[a,b]),
         thread_get_message(Requests,Request,[timeout(2)]),
         memberchk(search(Search),Request), assertion(memberchk(limit='2',Search)))).
test(invalid_yield_preserves_ready_answer) :-
    with_answer(Ref,
        (catch(yield(Ref,_,[on_timeout(17)]),Error,true),
         assertion(Error = error(type_error(callable,17),_)), yield(Ref,failure))).
test(invalid_yield_never_runs_callback) :-
    with_answer(Ref,
        (catch(yield(Ref,_,[on_timeout(throw(should_not_run)),timeout(bad)]),Error,true),
         assertion(Error = error(type_error(number,bad),_)), yield(Ref,failure))).
test(callback_variables_not_instantiated) :-
    rpc:validate_client_options(yield,[on_timeout(Answer=timeout)]), assertion(var(Answer)).

:- end_tests(rpc_options).
