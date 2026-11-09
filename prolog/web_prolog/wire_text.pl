:- module(wire_text, [
    check_portable_wire_term/1,
    term_to_wire_text/2,        % @Term, -Atom
    terms_to_wire_texts/2,      % @Terms, -Atoms
    wire_text_to_term/2,        % +Text, -Term
    wire_read_options/1         % -Options
]).

:- use_module(text_config, [text_double_quotes/1]).

/** <module> Canonical Term Text

The one normative way of writing a term as text when it crosses a node
boundary (Semantic Contracts D5): goals and templates sent by rpc/2-3 and
promise/3-4, actor messages and options sent to other nodes, and answers in
`format=prolog` responses and node-to-node toplevel events.

The text is

  - quoted, so atom and portable term syntax is unambiguous;
  - operator-independent (`ignore_ops(true)`), so it does not depend on the
    operator tables of either node;
  - written without portray hooks, so it does not depend on the sender's
    hooks;
  - written without `numbervars`, so a term '$VAR'(N) stays that term;
  - written with explicit variable names, so terms written together share
    their variables when they are read back together.

It is read with the portable character-list language convention. Native SWI
string identity is not a portable wire guarantee; library boundaries convert
text explicitly. A conformance suite
compares the decoded terms, not this text; the text is how this node meets
the contract.
*/

%!  term_to_wire_text(@Term, -Atom) is det.
term_to_wire_text(Term, Atom) :-
    terms_to_wire_texts([Term], [Atom]).

%!  terms_to_wire_texts(@Terms:list, -Atoms:list) is det.
%
%   Write each term in Terms.  A variable that occurs in several of them
%   gets the same name in each text, so reading the texts together, for
%   example as `(Goal)+(Template)`, restores the sharing.
terms_to_wire_texts(Terms, Atoms) :-
    maplist(check_portable_wire_term, Terms),
    term_variables(Terms, Vars),
    wire_variable_names(Vars, 1, Names),
    maplist(write_wire_text(Names), Terms, Atoms).

% These host values either change meaning on a peer or cannot be parsed.
% Callers enforce their own cycle policy; never descend into a rational tree.
check_portable_wire_term(Term) :-
    (   acyclic_term(Term),
        sub_term(Sub, Term),
        ambiguous_wire_subterm(Sub)
    ->  throw(error(representation_error(portable_term), _))
    ;   true
    ).

ambiguous_wire_subterm(Sub) :-
    (   Sub == '[]'
    ;   compound(Sub),
        compound_name_arity(Sub, Name, Arity),
        (Arity == 0 ; Name == '.', Arity == 2)
    ).

write_wire_text(Names, Term, Atom) :-
    with_output_to(atom(Atom),
                   write_term(Term, [ quoted(true),
                                      ignore_ops(true),
                                      portray(false),
                                      numbervars(false),
                                      variable_names(Names)
                                    ])).

wire_variable_names([], _, []).
wire_variable_names([Var|Vars], N, [Name=Var|Names]) :-
    format(atom(Name), '_~d', [N]),
    N1 is N + 1,
    wire_variable_names(Vars, N1, Names).

%!  wire_read_options(-Options) is det.
%
%   Reader options for term text received from another node or a client.
wire_read_options([double_quotes(TextMode)]) :-
    text_double_quotes(TextMode).

%!  wire_text_to_term(+Text, -Term) is det.
wire_text_to_term(Text, Term) :-
    wire_read_options(Options),
    term_string(Term, Text, Options).
