#!/usr/bin/env swipl
:- use_module(runner).

main :-
    current_prolog_flag(argv, Argv),
    dispatch(Argv).

dispatch([run, File|_]) :-
    run_file(File, result(Status, Returns)),
    format('State: ~w~n', [Status]),
    format('Returns: ~w~n', [Returns]).

dispatch([analyse, _File|_]) :-
    writeln('analyse mode is nog niet geimplementeerd'),
    halt(1).

dispatch([paths, _File|_]) :-
    writeln('paths mode is nog niet geimplementeerd'),
    halt(1).

dispatch(_) :-
    writeln('Usage: swipl -q -s src/main.pl -- <run|analyse|paths> <file.pwat>'),
    halt(1).

:- initialization(main, main).