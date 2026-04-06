#!/usr/bin/env swipl
:- use_module(runner).

main :-
    current_prolog_flag(argv, Argv),
    dispatch(Argv).

dispatch([run, File|_]) :-
    !,
    run_dispatch(File).

dispatch([analyse, _File|_]) :-
    !,
    writeln('analyse mode is nog niet geimplementeerd'),
    halt(1).

dispatch([paths, _File|_]) :-
    !,
    writeln('paths mode is nog niet geimplementeerd'),
    halt(1).

dispatch(_) :-
    writeln('Usage: swipl -q -s src/main.pl -- <run|analyse|paths> <file.pwat>'),
    halt(1).

% succesgeval
run_dispatch(File) :-
    run_file(File, result(Status, Returns)),
    !,
    format('State: ~w~n', [Status]),
    format('Returns: ~w~n', [Returns]).

% foutgeval
run_dispatch(File) :-
    format(user_error, 'ERROR: uitvoering van ~w mislukt~n', [File]),
    halt(1).

:- initialization(main, main).