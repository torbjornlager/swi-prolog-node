:- module(text_config, [text_double_quotes/1, configure_text_module/1]).

/** <module> Portable language text configuration

Double-quoted Web Prolog literals are lists of one-character atoms by default.
Public readers and generated language modules share that convention. Host
implementation/library modules retain native strings at explicit boundaries.
The former WP_EXPERIMENTAL_TEXT=portable-text-0.2 opt-in remains accepted for
existing launchers; it is no longer needed. Selection is fixed at startup.
*/
:- dynamic selected_double_quotes/1.
:- initialization(select_text_configuration).

select_text_configuration :-
    ( getenv('WP_EXPERIMENTAL_TEXT', Value), Value \== ''
    -> ( Value == 'portable-text-0.2' -> Mode = chars
       ; throw(error(domain_error(experimental_text_configuration, Value), _)) )
    ; Mode = chars
    ),
    assertz(selected_double_quotes(Mode)).

text_double_quotes(Mode) :- selected_double_quotes(Mode).

configure_text_module(Module) :-
    text_double_quotes(Mode),
    set_prolog_flag(Module:double_quotes, Mode).
