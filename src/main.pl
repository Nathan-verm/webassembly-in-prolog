#!/usr/bin/env swipl
:- use_module(runner).

main :-
    current_prolog_flag(argv, Argv),
    dispatch(Argv).

dispatch([run, File|_]) :-
    !,
    run_dispatch(File).

dispatch([analyse, File, MaxInstructions|_]) :-
    !,
    analyse_dispatch(File, MaxInstructions).

dispatch([paths, _File|_]) :-
    !,
    writeln('paths mode is nog niet geimplementeerd'),
    halt(1).

dispatch(_) :-
    writeln('Usage:'),
    writeln('  swipl -q -s src/main.pl -- run <file.pwat>'),
    writeln('  swipl -q -s src/main.pl -- analyse <file.pwat> <max_instructions>'),
    writeln('  swipl -q -s src/main.pl -- paths <file.pwat>'),
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


analyse_dispatch(File, MaxInstructionsRaw) :-
    parse_max_instructions(MaxInstructionsRaw, MaxInstructions),
    findall(Status-Inputs-BadInputs,
        (
            ContextIn = analyse(MaxInstructions, 0, [], []),
            analyse_file(File, ContextIn, analyse(_, _, Inputs, BadInputs), result(Status, _Returns))
        ),
        AllResults),
    findall(Input,
        (
            member(finished-[Input|_]-_, AllResults)
        ),
        GoodRaw),
    findall(Input,
        (
            member(trap-[Input|_]-_, AllResults)
        ),
        BadRaw),
    sort(GoodRaw, GoodInputs),
    sort(BadRaw, BadInputs),
    format('Good inputs: ~w~n', [GoodInputs]),
    format('Bad inputs: ~w~n', [BadInputs]),
    !.

analyse_dispatch(_File, MaxInstructionsRaw) :-
    format(user_error, 'ERROR: max_instructions moet een positief geheel getal zijn, kreeg: ~w~n', [MaxInstructionsRaw]),
    halt(1).

parse_max_instructions(MaxInstructionsRaw, MaxInstructions) :-
    catch(atom_number(MaxInstructionsRaw, MaxInstructions), _, fail),
    integer(MaxInstructions),
    MaxInstructions > 0.


:- initialization(main, main).