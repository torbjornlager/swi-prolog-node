:- module(example_text_audit,[main/0]).
:- use_module(library(http/json)).
:- use_module(library(readutil)).
:- op(800,xfx,!).
:- op(200,xfx,@).
:- op(1000,xfy,if).

main :-
    current_prolog_flag(argv,[Manifest]),
    setup_call_cleanup(open(Manifest,read,S),json_read_dict(S,Config),close(S)),
    maplist(scan_file,Config.files,Reports),json_write_dict(current_output,Reports,[width(0)]),nl.
scan_file(Path,Report) :-
    catch(setup_call_cleanup(open(Path,read,S,[encoding(utf8)]),scan_terms(S,Terms),close(S)),
          Error,Terms=error(Error)),
    (Terms=error(E) -> message_to_string(E,Text),Report=_{path:Path,status:error,error:Text}
    ; length(Terms,Count),findall(A,(member(T,Terms),flag(T,F),term_to_atom(F,A)),Fs),sort(Fs,Flags),
      findall(1,(member(T,Terms),sub_term(Sub,T),string(Sub)),Strings),length(Strings,N),
      Report=_{path:Path,status:parsed,terms:Count,string_literals:N,flags:Flags}).
scan_terms(S,Terms) :-
    read_term(S,T,[module(example_text_audit),double_quotes(string)]),
    (T==end_of_file -> Terms=[] ; Terms=[T|Ts],scan_terms(S,Ts)).
flag(T,native_string_api(Name/Arity)) :-
    sub_term(C,T),nonvar(C),compound(C),functor(C,Name,Arity),
    memberchk(Name,[string,string_length,string_lower,string_upper,string_chars,string_codes,
                    split_string,sub_string,atom_string,read_string]).
flag(T,native_string_type_requirement) :- sub_term(C,T),nonvar(C),C=must_be(string,_).
flag(T,format_text_input) :- sub_term(C,T),nonvar(C),C=format(F,_),string(F).
flag(T,source_text_input) :- sub_term(C,T),nonvar(C),C=src_text(F),string(F).
flag(T,quoted_uri_option) :- sub_term(C,T),nonvar(C),
    (C=src_uri(F);C=node(F)),string(F).
flag((_ --> Body),numeric_dcg_terminal) :- numeric_terminal(Body).
numeric_terminal(L) :- is_list(L),L\==[],maplist(integer,L).
numeric_terminal((A,B)) :- (numeric_terminal(A);numeric_terminal(B)).
numeric_terminal((A;B)) :- (numeric_terminal(A);numeric_terminal(B)).
