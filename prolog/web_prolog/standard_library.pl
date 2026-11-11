:- module(standard_library, [maplist/2, maplist/3, maplist/4, maplist/5, maplist/6, maplist/7, maplist/8, foldl/4, foldl/5, foldl/6, countall/2]).
:- use_module(library(apply), []).
:- use_module(library(aggregate), [aggregate_all/3]).
:- use_module(library(error), [must_be/2]).
% Check the original closure only when the library invokes it.
:- meta_predicate maplist(1,?).
maplist(Closure,A1) :-
    apply:maplist(standard_library:checked(Closure),A1).
:- meta_predicate maplist(2,?,?).
maplist(Closure,A1,A2) :-
    apply:maplist(standard_library:checked(Closure),A1,A2).
:- meta_predicate maplist(3,?,?,?).
maplist(Closure,A1,A2,A3) :-
    apply:maplist(standard_library:checked(Closure),A1,A2,A3).
:- meta_predicate maplist(4,?,?,?,?).
maplist(Closure,A1,A2,A3,A4) :-
    apply:maplist(standard_library:checked(Closure),A1,A2,A3,A4).
:- meta_predicate maplist(5,?,?,?,?,?).
maplist(_, [],[],[],[],[]).
maplist(Closure,[H1|T1],[H2|T2],[H3|T3],[H4|T4],[H5|T5]) :-
    checked(Closure,H1,H2,H3,H4,H5),
    maplist(Closure,T1,T2,T3,T4,T5).
:- meta_predicate maplist(6,?,?,?,?,?,?).
maplist(_, [],[],[],[],[],[]).
maplist(Closure,[H1|T1],[H2|T2],[H3|T3],[H4|T4],[H5|T5],[H6|T6]) :-
    checked(Closure,H1,H2,H3,H4,H5,H6),
    maplist(Closure,T1,T2,T3,T4,T5,T6).
:- meta_predicate maplist(7,?,?,?,?,?,?,?).
maplist(_, [],[],[],[],[],[],[]).
maplist(Closure,[H1|T1],[H2|T2],[H3|T3],[H4|T4],[H5|T5],[H6|T6],[H7|T7]) :-
    checked(Closure,H1,H2,H3,H4,H5,H6,H7),
    maplist(Closure,T1,T2,T3,T4,T5,T6,T7).
:- meta_predicate foldl(3,?,?,?).
foldl(Closure,A1,A2,A3) :-
    apply:foldl(standard_library:checked(Closure),A1,A2,A3).
:- meta_predicate foldl(4,?,?,?,?).
foldl(Closure,A1,A2,A3,A4) :-
    apply:foldl(standard_library:checked(Closure),A1,A2,A3,A4).
:- meta_predicate foldl(5,?,?,?,?,?).
foldl(Closure,A1,A2,A3,A4,A5) :-
    apply:foldl(standard_library:checked(Closure),A1,A2,A3,A4,A5).
:- meta_predicate countall(0,?).
countall(Goal, Count) :- aggregate_all(count, Goal, Actual), Count = Actual.

checked(Closure,A1) :-
    strip_module(Closure, _, Plain), must_be(callable, Plain),
    call(Closure,A1).
checked(Closure,A1,A2) :-
    strip_module(Closure, _, Plain), must_be(callable, Plain),
    call(Closure,A1,A2).
checked(Closure,A1,A2,A3) :-
    strip_module(Closure, _, Plain), must_be(callable, Plain),
    call(Closure,A1,A2,A3).
checked(Closure,A1,A2,A3,A4) :-
    strip_module(Closure, _, Plain), must_be(callable, Plain),
    call(Closure,A1,A2,A3,A4).
checked(Closure,A1,A2,A3,A4,A5) :-
    strip_module(Closure, _, Plain), must_be(callable, Plain),
    call(Closure,A1,A2,A3,A4,A5).
checked(Closure,A1,A2,A3,A4,A5,A6) :-
    strip_module(Closure, _, Plain), must_be(callable, Plain),
    call(Closure,A1,A2,A3,A4,A5,A6).
checked(Closure,A1,A2,A3,A4,A5,A6,A7) :-
    strip_module(Closure, _, Plain), must_be(callable, Plain),
    call(Closure,A1,A2,A3,A4,A5,A6,A7).
