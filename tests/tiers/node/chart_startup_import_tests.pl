:- module(test_chart_startup_imports, [worker/1]).
:- use_module('../../../prolog/web_prolog.pl').
:- use_module(library(plunit)).
:- use_module(library(process)).
:- use_module(library(readutil)).

% Each child starts with a cold SGML autoload state. Cancelling the first
% chart must not poison parser imports used by a subsequent chart.
:- begin_tests(chart_startup_imports).
test(cold_start_cancel_then_parse, [forall(between(1,12,N)), timeout(12)]) :-
    module_property(test_chart_startup_imports, file(File)),
    current_prolog_flag(executable, Executable),
    format(atom(Goal), 'test_chart_startup_imports:worker(~d)', [N]),
    setup_call_cleanup(
        process_create(Executable, ['-q','-s',File,'-g',Goal,'-t',halt],
                       [process(P),stdout(pipe(Out)),stderr(pipe(Err))]),
        ( process_wait(P, Status, [timeout(8)]),
          ( Status == timeout -> process_kill(P, kill), process_wait(P, _) ; true ),
          read_string(Out, _, Stdout), read_string(Err, _, Stderr),
          ( Status == exit(0) -> true
          ; throw(error(chart_startup_child(N,Status,Stdout,Stderr),_)) )
        ),
        ( close(Out), close(Err) )).
:- end_tests(chart_startup_imports).

worker(N) :-
    XML = '<statechart version="0.2" initial="s"><state id="s"><go on="probe(To)">send(To,chart_ready)</go></state></statechart>',
    statechart_spawn(First, [src_text(XML),trace(false),monitor(true),link(false)]),
    ( 0 is N mod 2 -> sleep(0) ; true ),
    exit(First, startup_cancel),
    receive({down(First,First,Reason) -> Reason == startup_cancel},
            [timeout(3),on_timeout(throw(missing_cancelled_chart))]),
    self(Self),
    setup_call_cleanup(
        statechart_spawn(Next, [src_text(XML),trace(false),monitor(true),link(false)]),
        ( send(Next, probe(Self)),
          receive({chart_ready -> true},
                  [timeout(3),on_timeout(throw(parser_poisoned_after_cancel))]),
          statechart_halt(Next, true),
          receive({down(Next,Next,true) -> true},
                  [timeout(3),on_timeout(throw(missing_followup_chart))])
        ),
        exit(Next, kill)).
