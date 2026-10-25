% Native-library boundaries are explicit; the host libraries keep strings.
:- module(test_portable_text_boundaries, []).
:- use_module('../../../prolog/web_prolog/node.pl', []).
:- use_module('../../../prolog/web_prolog/text_config.pl').
:- use_module('../../../prolog/web_prolog/wire_text.pl').
:- use_module('../../../prolog/web_prolog/source_utils.pl', []).
:- use_module(library(http/json)).
:- use_module(library(plunit)).

selected_text(Native, Term) :-
    (text_double_quotes(chars) -> string_chars(Native,Term);Term=Native).

:- begin_tests(portable_text_boundaries).
test(json_envelope_keeps_native_strings) :-
    atom_json_dict('{"value":"ab😀"}',Dict,[]),
    assertion(string(Dict.value)),assertion(Dict.value=="ab😀"),
    string_chars(Dict.value,Chars),assertion(Chars==[a,b,'😀']).
test(json_embedded_prolog_uses_selected_reader) :-
    atom_json_dict('{"input":"\\\"ab\\\""}',Dict,[]),
    assertion(string(Dict.input)),
    node_ws:ws_read_term(input,Dict.input,Term),
    test_portable_text_boundaries:selected_text("ab",Expected),assertion(Term==Expected).
test(format_result_explicit_conversion,
     [forall(member(Chars,[[],[a,b],['😀'],[e,'́'],['"','\\'],['👩','‍','💻']]))]) :-
    system:format(string(Native),'~s',[Chars]),assertion(string(Native)),
    string_chars(Native,Restored),assertion(Restored==Chars),
    term_to_wire_text(pair(Restored,X,X),Wire),wire_text_to_term(Wire,pair(Reply,A,B)),
    assertion(Reply==Chars),assertion(A==B),assertion(var(A)).
test(stream_result_preserves_codes_vs_chars) :-
    setup_call_cleanup(open_string("a😀",S),read_string(S,_,Native),close(S)),
    assertion(string(Native)),string_codes(Native,Codes),string_chars(Native,Chars),
    assertion(Codes==[97,128512]),assertion(Chars==[a,'😀']),
    term_to_wire_text(pair(Codes,Chars),Wire),wire_text_to_term(Wire,pair(C2,H2)),
    assertion(C2==Codes),assertion(H2==Chars).
test(source_text_boundary_accepts_chars_and_preserves_numeric_data) :-
    source_utils:text_to_string([p,'(',x,')','.'],Native),assertion(Native=="p(x)."),
    source_utils:terms_to_source([p([97,98]),q([a,b]),same(X,X)],Source),
    assertion(string(Source)),assertion(var(X)),
    setup_call_cleanup(open_string(Source,S),
      (read_term(S,p(N),[]),read_term(S,q(H),[]),read_term(S,same(A,B),[])),close(S)),
    assertion(N==[97,98]),assertion(H==[a,b]),assertion(A==B),assertion(var(A)).
test(json_term_roundtrip_preserves_portable_terms_and_sharing) :-
    term_to_wire_text(row([a,b],'😀',[97,98],X,X),Wire),
    atom_json_dict(JSON,_{term:Wire},[]),atom_json_dict(JSON,Back,[]),
    assertion(string(Back.term)),wire_text_to_term(Back.term,row(Chars,Scalar,Codes,A,B)),
    assertion(Chars==[a,b]),assertion(Scalar=='😀'),assertion(Codes==[97,98]),
    assertion(A==B),assertion(var(A)).
test(native_string_identity_is_not_a_portable_wire_claim) :-
    system:format(string(Native),'~w',[ab]),assertion(string(Native)),
    term_to_wire_text(Native,Wire),wire_text_to_term(Wire,Read),
    (text_double_quotes(chars) -> assertion(Read==[a,b]),assertion(Read\==Native)
    ; assertion(Read==Native)),
    string_chars(Native,Portable),term_to_wire_text(Portable,SafeWire),
    wire_text_to_term(SafeWire,PortableCopy),assertion(PortableCopy==[a,b]).
test(host_error_context_does_not_break_http_error_serialization) :-
    Error=error(error(syntax_error(test),string("native diagnostic",0))),
    with_output_to(string(Output),node_response:respond_with_answer(prolog,Error)),
    assertion(sub_string(Output,_,_,_,"error(error(syntax_error(test)")),
    assertion(sub_string(Output,_,_,_,"native diagnostic")),
    assertion(\+sub_string(Output,_,_,_,"500 Internal server error")).
test(host_error_context_on_actor_transport) :-
    node_ws:answer_term_text(error(42,error(test,context(native,"diagnostic"))),Wire),
    wire_text_to_term(Wire,error(test,context(native,Text))),
    test_portable_text_boundaries:selected_text("diagnostic",Expected),assertion(Text==Expected).
:- end_tests(portable_text_boundaries).
