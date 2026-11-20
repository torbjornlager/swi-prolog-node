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
test(explicit_timeout_requires_number_before_source_or_dispatch,
     [forall((member(Kind,[rpc,promise]),member(Value,[_ ,none,infinite])))]) :-
    copy_term(Value,Before),
    aggregate_all(count,rpc:promise_state(_,_,_,_,_,_,_),CountBefore),
    catch(invoke(Kind,17,[src_uri('http://127.0.0.1:1/never'),timeout(Value)]),Error,true),
    assertion(nonvar(Error)),
    (var(Value) -> assertion(Error=error(instantiation_error,_))
    ; assertion(Error=error(type_error(number,Value),_))),
    assertion(Value=@=Before),
    aggregate_all(count,rpc:promise_state(_,_,_,_,_,_,_),CountAfter),
    assertion(CountBefore==CountAfter).
test(omitted_and_numeric_timeout_conventions) :-
    rpc:validate_client_options(rpc,[]),
    rpc:normalize_requested_timeout(none,none),
    rpc:validate_client_options(rpc,[timeout(-1),http_timeout(-1)]),
    rpc:rpc_http_options([http_timeout(-1)],HTTP),
    % http_deadline/1 is the internal whole-request deadline marker.
    assertion(HTTP==[http_deadline(0),timeout(0)]).
test(transport_projection) :-
    rpc:rpc_http_options([limit(1),src_text('p.'),once(true),timeout(2),
        http_timeout(3),request_header(x='one'),request_header(y="two"),
        authorization(bearer(token)),user_agent('agent')], HTTP),
    assertion(HTTP==[http_deadline(3),timeout(3),request_header(x='one'),request_header(y=two),
                     request_header(authorization='Bearer token'),user_agent('agent')]).
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

% The stateless endpoint is below the node URI's own path.
test(node_path_prefix_is_kept, [forall(member(Suffix-Path,
        ['/prefix/'-'/prefix/call','/prefix'-'/prefix/call','/'-'/call',''-'/call']))]) :-
    with_endpoint(URI, Requests,
        ( atom_concat(URI, Suffix, Node),
          once(rpc(Node, member(_, [a]), [])),
          thread_get_message(Requests, Request),
          memberchk(path(Seen), Request),
          assertion(Seen == Path) )).
% A whole-request deadline of zero or less is reached before any request.
test(nonpositive_http_timeout_makes_no_request, [forall(member(T,[0,-2]))]) :-
    with_endpoint(URI, Requests,
        ( catch(rpc(URI, true, [http_timeout(T)]), Error, true),
          assertion(Error = error(rpc_error(http_timeout),_)),
          promise(URI, true, Ref, [http_timeout(T)]),
          yield(Ref, Answer),
          assertion(Answer = error(error(rpc_error(http_timeout),_))),
          assertion(\+ thread_peek_message(Requests, _)) )).

:- end_tests(rpc_options).
