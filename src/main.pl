#!/usr/bin/env swipl
:- use_module(runner).
:- use_module(parser).

:- discontiguous analyse_dispatch/2.

main :-
    current_prolog_flag(argv, Argv),
    dispatch(Argv).

% parsing of arguments and dispatch of different commands

dispatch([run, File|_]) :-
    validate_pwat_file(File),
    !,
    run_dispatch(File).

dispatch([analyse, File, MaxInstructions|_]) :-
    validate_pwat_file(File),
    !,
    analyse_dispatch(File, MaxInstructions).

dispatch([analyse, File|_]) :-
    validate_pwat_file(File),
    !,
    analyse_dispatch(File, 1000).

dispatch([paths, File, MaxInstructions|_]) :-
    validate_pwat_file(File),
    !,
    paths_dispatch(File, MaxInstructions).

dispatch([paths, File|_]) :-
    validate_pwat_file(File),
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


% run command

run_dispatch(File) :-
    run_file(File, result(Status, Returns)),
    !,
    print_run_result(Status, Returns),
    halt_for_run_status(Status).

run_dispatch(File) :-
    format(user_error, 'ERROR: execution of ~w failed~n', [File]),
    halt(1).

print_run_result(Status, Returns) :-
    format('State: ~w~n', [Status]),
    format('Returns: ~w~n', [Returns]).

halt_for_run_status(trap) :-
    halt(2).
halt_for_run_status(invalid) :-
    format(user_error, 'ERROR: invalid program~n', []),
    halt(1).
halt_for_run_status(finished).


% analyse command

analyse_dispatch(File, MaxInstructionsRaw) :-
    parse_max_instructions(MaxInstructionsRaw, MaxInstructions),
    !,
    collect_all_results(File, MaxInstructions, AllResults), % execute the file and get all possible traces (used by both analyse and paths) AllResults: Status - Inputs - PathTrace
    abort_if_invalid(AllResults), % if somewhere a path leads to an invalid execution => stop analyse with exit code 1
    collect_trap_candidates(AllResults, TrapCandidates), % keep only traces that lead to a trap
    collect_finished_path_traces(AllResults, FinishedPathTraces), % keep only traces that are fully executed
    filter_trap_candidates(FinishedPathTraces, TrapCandidates, FilteredCandidates), % for analyse we only want paths that result in a trap
    sort_and_deduplicate_traps(FilteredCandidates, UniqueInputs), % there are many duplicate traces, in the output we want only 1 for each (and sort) 
    print_trap_paths(UniqueInputs).


analyse_dispatch(_File, MaxInstructionsRaw) :-
    format(user_error, 'ERROR: max_instructions must be a positive integer, got: ~w~n', [MaxInstructionsRaw]),
    halt(1).


collect_trap_candidates(AllResults, TrapCandidates) :-
    include(is_trap_result, AllResults, TrapResults),
    maplist(convert_trap_to_candidate, TrapResults, TrapCandidates).

is_trap_result(trap-_-_).

convert_trap_to_candidate(trap-Inputs-PathTraceRev, trap_candidate(PathTrace, Path)) :-
    reverse(PathTraceRev, PathTrace),
    reverse(Inputs, Path).

collect_finished_path_traces(AllResults, FinishedPathTraces) :-
    include(is_finished_result, AllResults, FinishedResults),
    maplist(convert_finished_to_trace, FinishedResults, FinishedPathTraces).

is_finished_result(finished-_-_).

convert_finished_to_trace(finished-_-PathTraceRev, PathTrace) :-
    reverse(PathTraceRev, PathTrace).

filter_trap_candidates(_FinishedPathTraces, TrapCandidates, FilteredCandidates) :-
    prefer_complete_trap_paths(TrapCandidates, Complete),
    prefer_decision_paths(Complete, FilteredCandidates).

sort_and_deduplicate_traps(Candidates, UniqueInputs) :-
    maplist(trap_candidate_to_sort_pair, Candidates, Pairs),
    keysort(Pairs, SortedPairs), % built-in predicate that sorts lexicographically
    maplist(sort_pair_to_trap_candidate, SortedPairs, Sorted),
    keep_first_input_per_path(Sorted, UniqueInputs).

trap_candidate_to_sort_pair(trap_candidate(Path, Inputs), Path-trap_candidate(Path, Inputs)).
sort_pair_to_trap_candidate(_-Candidate, Candidate).


% paths command

paths_dispatch(File, MaxInstructionsRaw) :-
    parse_max_instructions(MaxInstructionsRaw, MaxInstructions),
    !,
    collect_all_results(File, MaxInstructions, AllResults),
    abort_if_invalid(AllResults),
    collect_path_candidates(AllResults, RawCandidates), % convert AllResults (Status-Inputs-PathTraceRev) to path_candidate(PathTrace, Status, Path)
    sort_and_deduplicate_paths(RawCandidates, UniqueResults),
    print_path_results(UniqueResults).

paths_dispatch(_File, MaxInstructionsRaw) :-
    format(user_error, 'ERROR: max_instructions must be a positive integer, got: ~w~n', [MaxInstructionsRaw]),
    halt(1).

collect_path_candidates(AllResults, Candidates) :-
    include(is_path_result, AllResults, PathResults),
    maplist(convert_path_to_candidate, PathResults, Candidates).

is_path_result(_Status-_-_).

convert_path_to_candidate(Status-Inputs-PathTraceRev, path_candidate(PathTrace, Status, Path)) :-
    reverse(PathTraceRev, PathTrace),
    reverse(Inputs, Path).


sort_and_deduplicate_paths(Candidates, UniqueResults) :-
    maplist(path_candidate_to_sort_pair, Candidates, Pairs), % convert to be able to sort
    keysort(Pairs, SortedPairs),  % sorting
    maplist(sort_pair_to_path_candidate, SortedPairs, Sorted), % back to original form
    keep_first_result_per_key(Sorted, UniqueResults). % keep only first result

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
    ContextIn = analyse(MaxInstructions, 0, [], []),
    analyse_file(File, ContextIn, analyse(_, _, Inputs, PathTrace), result(Status, _Returns)).


% check if there is an invalid entry in AllResults
abort_if_invalid(AllResults) :-
    member(invalid-_-_, AllResults),
    !,
    format(user_error, 'ERROR: invalid program~n', []),
    halt(1).

abort_if_invalid(_).


% this and the following predicate rule basically do double work
parse_max_instructions(MaxInstructionsRaw, MaxInstructions) :-
    integer(MaxInstructionsRaw),
    MaxInstructions = MaxInstructionsRaw,
    MaxInstructions > 0.

parse_max_instructions(MaxInstructionsRaw, MaxInstructions) :-
    \+ integer(MaxInstructionsRaw),

    % this does: try conversion of atom to number, if that fails then fail.
    catch(atom_number(MaxInstructionsRaw, MaxInstructions), _, fail), % catch does: catch(Goal, Error, Handler) => if goal fails then do Handler
    integer(MaxInstructions),
    MaxInstructions > 0.

% filtering of traps

prefer_complete_trap_paths(TrapCandidates, CompleteTrapCandidates) :-
    exclude(has_longer_trap_extension(TrapCandidates), TrapCandidates, CompleteTrapCandidates).

has_longer_trap_extension(TrapCandidates, trap_candidate(Path, _)) :-
    member(trap_candidate(OtherPath, _), TrapCandidates),
    strict_prefix(Path, OtherPath).

% if there is a path with decision: throw away the non-decision paths
prefer_decision_paths(TrapCandidates, FilteredTrapCandidates) :-
    has_non_empty_trap_path(TrapCandidates),
    !,
    exclude(is_empty_trap_candidate, TrapCandidates, FilteredTrapCandidates).

% only non-decision paths => keep them all
prefer_decision_paths(TrapCandidates, TrapCandidates).


has_non_empty_trap_path([trap_candidate(Path, _)|_]) :-
    Path \= [],
    !.
has_non_empty_trap_path([_|Rest]) :-
    has_non_empty_trap_path(Rest).

is_empty_trap_candidate(trap_candidate([], _)).

% remove duplicates

% suppose the path is [taken, taken], then we take only the first inputs that satisfy this
keep_first_input_per_path([], []).
keep_first_input_per_path([trap_candidate(Path, Inputs)|Rest], [Inputs|Out]) :-
    skip_same_trap_path(Path, Rest, Remaining), % keep 1 path with corresponding inputs
    keep_first_input_per_path(Remaining, Out). % do this recursively for the other paths

skip_same_trap_path(_Path, [], []).
skip_same_trap_path(Path, [trap_candidate(Path, _)|Rest], Remaining) :-
    !,
    skip_same_trap_path(Path, Rest, Remaining).
skip_same_trap_path(_Path, Rest, Rest).

% keep only 1 combination of PathTrace and Status per PathTrace and status
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

% no exact match => keep and stop
% this works because everything is 'sorted'
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


% Validation of .pwat files
validate_pwat_file(File) :-
    parse(File, _).

validate_pwat_file(File) :-
    format(user_error, 'ERROR: parsing of ~w failed~n', [File]),
    halt(1).


:- initialization(main, main).