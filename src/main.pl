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
    findall(Status-Inputs-PathTrace,
        (
            ContextIn = analyse(MaxInstructions, 0, [], [], []),
            analyse_file(File, ContextIn, analyse(_, _, Inputs, _, PathTrace), result(Status, _Returns))
        ),
        AllResults),
    findall(PathTrace-Path,
        (
            member(trap-Inputs-PathTraceRev, AllResults),
            reverse(PathTraceRev, PathTrace),
            reverse(Inputs, Path)
        ),
        TrapCandidates),
    prefer_decision_paths(TrapCandidates, FilteredTrapCandidates),
    keysort(FilteredTrapCandidates, SortedTrapCandidates),
    keep_first_input_per_path(SortedTrapCandidates, UniqueTrapInputs),
    print_trap_paths(UniqueTrapInputs),
    !.

analyse_dispatch(_File, MaxInstructionsRaw) :-
    format(user_error, 'ERROR: max_instructions moet een positief geheel getal zijn, kreeg: ~w~n', [MaxInstructionsRaw]),
    halt(1).

parse_max_instructions(MaxInstructionsRaw, MaxInstructions) :-
    catch(atom_number(MaxInstructionsRaw, MaxInstructions), _, fail),
    integer(MaxInstructions),
    MaxInstructions > 0.

keep_first_input_per_path([], []).
keep_first_input_per_path([Path-Inputs|Rest], [Inputs|Out]) :-
    skip_same_path(Path, Rest, Remaining),
    keep_first_input_per_path(Remaining, Out).

skip_same_path(_Path, [], []).
skip_same_path(Path, [Path-_|Rest], Remaining) :-
    !,
    skip_same_path(Path, Rest, Remaining).
skip_same_path(_Path, Rest, Rest).

print_trap_paths([]).
print_trap_paths([Inputs|Rest]) :-
    format('Inputs: ~w, State: trap~n', [Inputs]),
    print_trap_paths(Rest).

prefer_decision_paths(TrapCandidates, FilteredTrapCandidates) :-
    ( has_non_empty_path(TrapCandidates) ->
        exclude(is_empty_path_candidate, TrapCandidates, FilteredTrapCandidates)
    ;
        FilteredTrapCandidates = TrapCandidates
    ).

has_non_empty_path([Path-_|_]) :-
    Path \= [],
    !.
has_non_empty_path([_|Rest]) :-
    has_non_empty_path(Rest).

is_empty_path_candidate([]-_).


:- initialization(main, main).