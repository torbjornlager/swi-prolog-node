:- module(node_http_identity, [with_http_identity/2, current_http_visitor/1,
    current_query_owner/1, with_query_owner/2]).

/** <module> Anonymous HTTP query capabilities

Opt-in visitor identities are signed, stateless, host-only cookies. Native RPC
clients use a fresh 256-bit X-Web-Prolog-Query-Owner capability per conversation.
Neither form authenticates a user or grants capabilities. Missing identity never
selects another request's continuation. The owner is separate from actor/promise
lifetime accounts, which remain request-scoped for anonymous HTTP.
*/
:- use_module(library(crypto)).
:- use_module(library(settings)).
:- use_module(node_runtime_state, [current_node_port/1, current_node_value/2]).
:- meta_predicate with_http_identity(+,0), with_query_owner(+,0).
:- thread_local http_visitor/1, query_owner/1.
:- dynamic cookie_secret/1.
:- setting(anonymous_visitors, boolean, false,
           'Issue independent anonymous HTTP identities and bind query continuations to them').

current_http_visitor(Id) :- http_visitor(Id).
current_query_owner(Id) :- query_owner(Id).
with_query_owner(Id, Goal) :-
    setup_call_cleanup(asserta(query_owner(Id),Ref), Goal, erase(Ref)).

with_http_identity(Request, Goal) :-
    ( setting(anonymous_visitors, true), identity_route(Request)
    -> request_visitor(Request, Id),
       setup_call_cleanup(asserta(http_visitor(Id),Ref), Goal, erase(Ref))
    ; call(Goal)).

identity_route(Request) :-
    memberchk(path(Path),Request),
    (memberchk(Path,['/call','/node_info']); sub_atom(Path,0,9,_,'/toplevel')).

request_visitor(Request, Id) :-
    findall(V,(member(H,Request), H=..[Name,V],
        memberchk(Name,[x_web_prolog_query_owner,'x-web-prolog-query-owner'])),Headers),
    ( Headers=[Token], valid_nonce(Token)
    -> visitor_id(Token,Id)
    ; Headers \== []
    -> throw(http_reply(bad_request('Invalid query owner header')))
    ; cookie_name(Name,Secure),
      ( memberchk(cookie(Cookies),Request), memberchk(Name=Cookie,Cookies),
        valid_cookie(Cookie,Nonce)
      -> visitor_id(Nonce,Id)
      ; fresh_nonce(Nonce), visitor_id(Nonce,Id),
        get_time(Now), Expiry is floor(Now)+86400,
        format(atom(Data),'~d.~w',[Expiry,Nonce]), sign_cookie(Data,Mac),
        format('Set-Cookie: ~w=~w.~w; Path=/; Max-Age=86400; HttpOnly; SameSite=Lax~w~n',
               [Name,Data,Mac,Secure]))).

cookie_name('__Host-wp_visitor','; Secure') :-
    current_node_value(url,URL), sub_atom(URL,0,6,_,'https:'), !.
cookie_name(wp_visitor,'').

fresh_nonce(Nonce) :- crypto_n_random_bytes(32,Bytes), hex_bytes(Nonce,Bytes).
valid_nonce(Token) :- atom(Token), atom_length(Token,64), atom_codes(Token,Codes),
    maplist(hex_code,Codes).
hex_code(C) :- between(0'0,0'9,C), !.
hex_code(C) :- between(0'a,0'f,C).

valid_cookie(Cookie,Nonce) :-
    atom(Cookie), atomic_list_concat([ExpiryText,Nonce,Mac],'.',Cookie),
    valid_nonce(Nonce), valid_nonce(Mac), catch(atom_number(ExpiryText,Expiry),_,fail),
    integer(Expiry), get_time(Now), Expiry>Now, Expiry=<Now+86400,
    atomic_list_concat([ExpiryText,Nonce],'.',Data), sign_cookie(Data,Expected),
    atom_codes(Mac,A),atom_codes(Expected,B), same_mac(A,B,0).
same_mac([],[],0).
same_mac([A|As],[B|Bs],Diff) :- Next is Diff \/ (A xor B), same_mac(As,Bs,Next).

sign_cookie(Data,Mac) :-
    with_mutex(http_visitor_secret,
        (cookie_secret(Key)->true;fresh_nonce(Key),assertz(cookie_secret(Key)))),
    (current_node_port(Port)->true;Port=global),
    format(atom(Bound),'~w:~w',[Port,Data]),
    crypto_data_hash(Bound,Mac,[algorithm(sha256),hmac(Key)]).

% Principal ids may be logged or returned as metadata; never disclose the
% bearer nonce there. Hashing is one-way and the raw header is hashed again.
visitor_id(Token,Id) :- crypto_data_hash(Token,Hash,[algorithm(sha256)]),atom_string(Hash,Id).
