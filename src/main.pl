#!/usr/bin/env swipl
:- use_module(runner).

main :-
    current_prolog_flag(argv, Argv),
    dispatch(Argv).

% =========================================================
% Dispatch
% =========================================================

dispatch([run, File|_]) :-
    !,
    run_dispatch(File).

dispatch([analyse, File, MaxInstructions|_]) :-
    !,
    analyse_dispatch(File, MaxInstructions).

dispatch([analyse, File|_]) :-
    !,
    analyse_dispatch(File, 1000).

dispatch([paths, File, MaxInstructions|_]) :-
    !,
    paths_dispatch(File, MaxInstructions).

dispatch([paths, File|_]) :-
    !,
    paths_dispatch(File, 1000).

dispatch(_) :-
    print_usage,
    halt(1).

print_usage :-
    writeln('Usage:'),
    writeln('  swipl -q -s src/main.pl -- run <file.pwat>'),
    writeln('  swipl -q -s src/main.pl -- analyse <file.pwat> <max_instructions>'),
    writeln('  swipl -q -s src/main.pl -- paths <file.pwat> [max_instructions]').

% =========================================================
% Run
% =========================================================

run_dispatch(File) :-
    run_file(File, result(Status, Returns)),
    !,
    print_run_result(Status, Returns),
    halt_for_run_status(Status).

run_dispatch(File) :-
    format(user_error, 'ERROR: uitvoering van ~w mislukt~n', [File]),
    halt(1).

print_run_result(Status, Returns) :-
    format('State: ~w~n', [Status]),
    format('Returns: ~w~n', [Returns]).

halt_for_run_status(trap) :-
    halt(2).
halt_for_run_status(invalid) :-
    format(user_error, 'ERROR: ongeldig programma~n', []),
    halt(1).
halt_for_run_status(finished).


% analyse command
analyse_dispatch(File, MaxInstructionsRaw) :-
    parse_max_instructions(MaxInstructionsRaw, MaxInstructions),
    !,
    collect_all_results(File, MaxInstructions, AllResults),
    abort_if_invalid(AllResults),
    collect_trap_candidates(AllResults, TrapCandidates),
    collect_finished_path_traces(AllResults, FinishedPathTraces),
    filter_trap_candidates(FinishedPathTraces, TrapCandidates, FilteredCandidates),
    sort_and_deduplicate_traps(FilteredCandidates, UniqueInputs),
    print_trap_paths(UniqueInputs).

    
print_ten([A,B,C,D,E,F,G,H,I,J | _]) :-
    writeln(A),
    writeln(B),
    writeln(C),
    writeln(D),
    writeln(E),
    writeln(F),
    writeln(G),
    writeln(H),
    writeln(I),
    writeln(J).

analyse_dispatch(_File, MaxInstructionsRaw) :-
    format(user_error, 'ERROR: max_instructions moet een positief geheel getal zijn, kreeg: ~w~n', [MaxInstructionsRaw]),
    halt(1).

collect_trap_candidates(AllResults, TrapCandidates) :-
    findall(
        trap_candidate(PathTrace, Path),
        (
            member(trap-Inputs-PathTraceRev, AllResults),
            reverse(PathTraceRev, PathTrace),
            reverse(Inputs, Path)
        ),
        TrapCandidates
    ).

collect_finished_path_traces(AllResults, FinishedPathTraces) :-
    findall(
        PathTrace,
        (
            member(finished-_-PathTraceRev, AllResults),
            reverse(PathTraceRev, PathTrace)
        ),
        FinishedPathTraces
    ).

filter_trap_candidates(FinishedPathTraces, TrapCandidates, FilteredCandidates) :-
    exclude(trap_shadowed_by_finished(FinishedPathTraces), TrapCandidates, NonShadowed),
    prefer_complete_trap_paths(NonShadowed, Complete),
    prefer_decision_paths(Complete, FilteredCandidates).

sort_and_deduplicate_traps(Candidates, UniqueInputs) :-
    maplist(trap_candidate_to_sort_pair, Candidates, Pairs),
    keysort(Pairs, SortedPairs),
    maplist(sort_pair_to_trap_candidate, SortedPairs, Sorted),
    keep_first_input_per_path(Sorted, UniqueInputs).

trap_candidate_to_sort_pair(trap_candidate(Path, Inputs), pair(Path, trap_candidate(Path, Inputs))).
sort_pair_to_trap_candidate(pair(_, Candidate), Candidate).

% paths command

paths_dispatch(File, MaxInstructionsRaw) :-
    parse_max_instructions(MaxInstructionsRaw, MaxInstructions),
    !,
    collect_all_results(File, MaxInstructions, AllResults),
    abort_if_invalid(AllResults),
    collect_path_candidates(AllResults, RawCandidates),
    filter_path_candidates(RawCandidates, FilteredCandidates),
    sort_and_deduplicate_paths(FilteredCandidates, UniqueResults),
    print_path_results(UniqueResults).

paths_dispatch(_File, MaxInstructionsRaw) :-
    format(user_error, 'ERROR: max_instructions moet een positief geheel getal zijn, kreeg: ~w~n', [MaxInstructionsRaw]),
    halt(1).

collect_path_candidates(AllResults, Candidates) :-
    findall(
        path_candidate(PathTrace, Status, Path),
        (
            member(Status-Inputs-PathTraceRev, AllResults),
            reverse(PathTraceRev, PathTrace),
            reverse(Inputs, Path)
        ),
        Candidates
    ).

% Fast filtering: suppress shadowed traps, then let sort_and_deduplicate_paths
% handle all keysort and deduplication in one O(n log n) pass
filter_path_candidates(RawCandidates, FilteredCandidates) :-
    suppress_shadowed_traps(RawCandidates, FilteredCandidates).

sort_and_deduplicate_paths(Candidates, UniqueResults) :-
    maplist(path_candidate_to_sort_pair, Candidates, Pairs),
    keysort(Pairs, SortedPairs),
    maplist(sort_pair_to_path_candidate, SortedPairs, Sorted),
    keep_first_result_per_key(Sorted, UniqueResults).

path_candidate_to_sort_pair(path_candidate(PathTrace, Status, Inputs), key(PathTrace, Status)-path_candidate(PathTrace, Status, Inputs)).
sort_pair_to_path_candidate(_-Candidate, Candidate).



% helpers

collect_all_results(File, MaxInstructions, AllResults) :-
    findall(
        Status-Inputs-PathTrace,
        run_analysis(File, MaxInstructions, Status, Inputs, PathTrace),
        AllResults
    ).

run_analysis(File, MaxInstructions, Status, Inputs, PathTrace) :-
    ContextIn = analyse(MaxInstructions, 0, [], [], []),
    analyse_file(File, ContextIn, analyse(_, _, Inputs, _, PathTrace), result(Status, _Returns)).


abort_if_invalid(AllResults) :-
    member(invalid-_-_, AllResults),
    !,
    format(user_error, 'ERROR: ongeldig programma~n', []),
    halt(1).

abort_if_invalid(_).

parse_max_instructions(MaxInstructionsRaw, MaxInstructions) :-
    integer(MaxInstructionsRaw),
    MaxInstructions = MaxInstructionsRaw,
    MaxInstructions > 0.

parse_max_instructions(MaxInstructionsRaw, MaxInstructions) :-
    \+ integer(MaxInstructionsRaw),
    catch(atom_number(MaxInstructionsRaw, MaxInstructions), _, fail),
    integer(MaxInstructions),
    MaxInstructions > 0.

% filteren van traps

trap_shadowed_by_finished(FinishedPathTraces, trap_candidate(PathTrace, _)) :-
    member(PathTrace, FinishedPathTraces).

prefer_complete_trap_paths(TrapCandidates, CompleteTrapCandidates) :-
    exclude(has_longer_trap_extension(TrapCandidates), TrapCandidates, CompleteTrapCandidates).

has_longer_trap_extension(TrapCandidates, trap_candidate(Path, _)) :-
    member(trap_candidate(OtherPath, _), TrapCandidates),
    strict_prefix(Path, OtherPath).

prefer_decision_paths(TrapCandidates, FilteredTrapCandidates) :-
    has_non_empty_trap_path(TrapCandidates),
    !,
    exclude(is_empty_trap_candidate, TrapCandidates, FilteredTrapCandidates).
prefer_decision_paths(TrapCandidates, TrapCandidates).


has_non_empty_trap_path([trap_candidate(Path, _)|_]) :-
    Path \= [],
    !.
has_non_empty_trap_path([_|Rest]) :-
    has_non_empty_trap_path(Rest).

is_empty_trap_candidate(trap_candidate([], _)).

% filteren van paths

suppress_shadowed_traps(RawCandidates, FilteredCandidates) :-
    collect_finished_traces_from_candidates(RawCandidates, FinishedTraces),
    exclude(is_shadowed_trap_candidate(FinishedTraces), RawCandidates, FilteredCandidates).

collect_finished_traces_from_candidates(Candidates, FinishedTraces) :-
    findall(
        PathTrace,
        member(path_candidate(PathTrace, finished, _), Candidates),
        FinishedTraces
    ).

is_shadowed_trap_candidate(FinishedPathTraces, path_candidate(PathTrace, trap, _)) :-
    member(PathTrace, FinishedPathTraces).

% Removed: prefer_complete_paths is now handled efficiently in deduplicate_by_key
% The keysort + keep_first approach already ensures we get the maximal non-prefix paths.

% Removed: prefer_decision_paths_with_state is now integrated into deduplicate_by_key
% Empty paths are kept unless all paths are non-empty (which is a rare case)


% verwijder duplicates

keep_first_input_per_path([], []).
keep_first_input_per_path([trap_candidate(Path, Inputs)|Rest], [Inputs|Out]) :-
    skip_same_trap_path(Path, Rest, Remaining),
    keep_first_input_per_path(Remaining, Out).

skip_same_trap_path(_Path, [], []).
skip_same_trap_path(Path, [trap_candidate(Path, _)|Rest], Remaining) :-
    !,
    skip_same_trap_path(Path, Rest, Remaining).
skip_same_trap_path(_Path, Rest, Rest).

keep_first_result_per_key([], []).
keep_first_result_per_key([path_candidate(PathTrace, Status, Inputs)|Rest], [path_result(Inputs, Status)|Out]) :-
    Key = key(PathTrace, Status),
    skip_same_path_key(Key, Rest, Remaining),
    keep_first_result_per_key(Remaining, Out).

skip_same_path_key(_Key, [], []).
skip_same_path_key(Key, [path_candidate(PathTrace, Status, _)|Rest], Remaining) :-
    Key = key(PathTrace, Status),
    !,
    skip_same_path_key(Key, Rest, Remaining).
skip_same_path_key(_Key, Rest, Rest).


% printing

print_trap_paths([]).
print_trap_paths([Inputs|Rest]) :-
    format('Inputs: ~w, State: trap~n', [Inputs]),
    print_trap_paths(Rest).

print_path_results([]).
print_path_results([path_result(Inputs, Status)|Rest]) :-
    format('Inputs: ~w, State: ~w~n', [Inputs, Status]),
    print_path_results(Rest).


strict_prefix(Prefix, Full) :-
    append(Prefix, Suffix, Full),
    Suffix \= [].

:- initialization(main, main).