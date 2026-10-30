:- module(test_portable_text, []).
:- use_module('../../../prolog/web_prolog/node.pl', []).
:- use_module('../../../prolog/web_prolog/text_config.pl').
:- use_module('../../../prolog/web_prolog/wire_text.pl').
:- use_module('../../../prolog/web_prolog/isolation.pl', []).
:- use_module('../../../prolog/web_prolog/source_utils.pl', []).
:- use_module('portable_text_boundary_tests.pl', []).
:- use_module(library(plunit)).
:- use_module(library(modules)).

expected(Text, Value) :-
    text_double_quotes(Mode),
    (Mode == chars -> string_chars(Text, Value); Value = Text).
read_expected(Text, Term) :- expected(Text, Expected), assertion(Term == Expected).

:- begin_tests(portable_text_configuration).
test(standard_language_uses_character_lists) :-
    assertion(text_double_quotes(chars)),
    wire_text_to_term('"abc"',Chars),assertion(Chars==[a,b,c]),
    wire_text_to_term('""',Empty),assertion(Empty==[]),
    wire_text_to_term('"hé😀"',Unicode),assertion(Unicode==[h,é,'😀']),
    assertion(\+ string(Chars)).
test(host_modules_keep_native_strings) :- assertion(string("abc")).
test(wire,[forall(member(Text,["abc","","😀","é","👩‍💻","a\\b\"c"]))]) :-
    with_output_to(atom(Wire),write_term(Text,[quoted(true)])), wire_text_to_term(Wire, Term),
    test_portable_text:read_expected(Text,Term).
test(http_goal_and_template) :-
    node_call_context:parse_goal_template('X="ab"','X',Goal,Template,_),
    Goal = (X=Value), assertion(X == Template), test_portable_text:read_expected("ab",Value).
test(http_options_sharing) :-
    node_call_context:parse_call_options_context('X="ab"','[template(X),limit(1),format(prolog)]',Goal,Template,_,_,_,_,_),
    Goal=(X=Value), assertion(X == Template), test_portable_text:read_expected("ab",Value).
test(websocket_input) :-
    node_ws:ws_read_term(input,'"ab"',Term), test_portable_text:read_expected("ab",Term).
test(http_input) :-
    node_session:read_period_terminated_term('"ab".',Term),test_portable_text:read_expected("ab",Term).
test(input_suffix_rejected,[throws(error(syntax_error(unexpected_input_after_full_stop),_))]) :-
    node_session:read_period_terminated_term('"ab". true.',_).
test(spawn_option_reader) :-
    node_isotope_options:parse_spawn_options_atom('[src_list([p("ab")])]',[src_list([p(Text)])]),
    test_portable_text:read_expected("ab",Text).
test(private_source) :-
    in_temporary_module(M,true,(text_config:configure_text_module(M),
      isolation:load_source_text('p("ab").',M,portable_private),
      M:p(Text),test_portable_text:read_expected("ab",Text))).
test(constructed_source_preserves_numbers_and_sharing) :-
    source_utils:terms_to_source([p([97,98]),same(X,X)],Source),assertion(var(X)),
    in_temporary_module(M,true,(text_config:configure_text_module(M),
      isolation:load_source_text(Source,M,portable_constructed),
      M:p(Numbers),assertion(Numbers == [97,98]),M:same(A,B),assertion(A==B),assertion(var(A)))).
test(shared_database_and_reload) :-
    node:set_node_shared_db('portable_shared("ab").'),
    node:call_current_shared_db(portable_shared(First)),test_portable_text:read_expected("ab",First),
    node:set_node_shared_db('portable_shared("😀").'),
    node:call_current_shared_db(portable_shared(Second)),test_portable_text:read_expected("😀",Second).
test(statechart_expression_reader) :-
    statechart_model:my_atom_to_term('X="ab"',X=Text,Bindings),
    assertion(Bindings == ['X'=X]),test_portable_text:read_expected("ab",Text).
test(shared_database_visible_in_actor) :-
    node:set_node_shared_db('portable_shared("ab").'),
    actors:self(Parent),
    actors:spawn((portable_shared(Text),send(Parent,portable_shared_reply(Text))),Pid,[monitor(true)]),
    actors:receive({portable_shared_reply(Reply)->true},[timeout(2),on_timeout(fail)]),
    actors:receive({down(Pid,Pid,true)->true},[timeout(2),on_timeout(fail)]),
    test_portable_text:read_expected("ab",Reply).
test(native_text_boundary) :-
    source_utils:text_to_string([a,b],String),assertion(String=="ab").
test(no_implicit_numeric_conversion_on_wire) :-
    term_to_wire_text(pair([97,98],X,X),Wire),wire_text_to_term(Wire,pair(N,A,B)),
    assertion(N==[97,98]),assertion(A==B),assertion(var(A)).
test(character_list_format_guard,
     [throws(error(permission_error(use,format_specifier,'~@'),_))]) :-
    actor_io_template:reject_format_call_specifier(['~','@']).
test(generated_character_list_format_guard,
     [throws(error(permission_error(use,format_specifier,'~@'),_))]) :-
    actor_io_support:actor_io_prelude_text(Source),
    in_temporary_module(M,text_config:configure_text_module(M),
      (isolation:load_source_text(Source,M,portable_generated),M:format(['~','@'],[true]))).
test(character_list_sandbox_format_guard,
     [throws(error(permission_error(use,format_specifier,'~@'),_))]) :-
    node_sandbox:reject_format_call_specifier(['~','@']).
test(character_list_prompt) :-
    node_response:prompt_to_json_string([h,i],Prompt),
    (text_double_quotes(chars) -> assertion(Prompt == "hi") ; assertion(Prompt == "[h,i]")).
test(remote_source_native_boundary) :-
    distribution:remote_spawn_options([src_text("p(1).")],user,[src_text(Text)]),
    (text_double_quotes(chars) -> assertion(Text == 'p(1).') ; assertion(Text == "p(1)." )).
test(native_library_return_explicit_conversion) :-
    system:format(string(Native),'~w',[abc]),assertion(string(Native)),
    string_chars(Native,Chars),assertion(Chars==[a,b,c]),
    term_to_wire_text(pair(Chars),Wire),wire_text_to_term(Wire,pair(Reply)),assertion(Reply==Chars).
:- end_tests(portable_text_configuration).
