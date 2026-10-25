:- module(text_config, [text_double_quotes/1, configure_text_module/1]).

/** <module> Experimental language text configuration

Selected once when this module loads. Only disposable processes should set
WP_EXPERIMENTAL_TEXT=portable-text-0.2. Host implementation/library modules
retain native strings; Web Prolog readers and generated language modules use
chars in that configuration. There is deliberately no live-node switch.
*/
:- dynamic selected_double_quotes/1.
:- initialization(select_text_configuration).

select_text_configuration :-
    ( getenv('WP_EXPERIMENTAL_TEXT', Value), Value \== ''
    -> ( Value == 'portable-text-0.2' -> Mode = chars
       ; throw(error(domain_error(experimental_text_configuration, Value), _)) )
    ; Mode = string
    ),
    assertz(selected_double_quotes(Mode)).

text_double_quotes(Mode) :- selected_double_quotes(Mode).

configure_text_module(Module) :-
    text_double_quotes(Mode),
    set_prolog_flag(Module:double_quotes, Mode).
