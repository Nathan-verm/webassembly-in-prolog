:- begin_tests(cli_modes).

:- use_module(library(process)).
:- use_module(library(readutil)).

run_cli(Args, Lines) :-
    process_create(path(swipl),
        ['-q', '-s', '../src/main.pl', '--' | Args],
        [stdout(pipe(Out)), process(PID)]),
    read_string(Out, _, Output),
    close(Out),
    process_wait(PID, Status),
    assertion(Status == exit(0)),
    split_string(Output, "\n", "\n \t", RawLines),
    exclude(=(""), RawLines, Lines).

run_cli_with_input(Args, Input, Lines) :-
    process_create(path(swipl),
        ['-q', '-s', '../src/main.pl', '--' | Args],
        [stdin(pipe(In)), stdout(pipe(Out)), process(PID)]),
    format(In, '~s', [Input]),
    close(In),
    read_string(Out, _, Output),
    close(Out),
    process_wait(PID, Status),
    assertion(Status == exit(0)),
    split_string(Output, "\n", "\n \t", RawLines),
    exclude(=(""), RawLines, Lines).


test(analyse_if_else_high_limit_trap_paths) :-
    run_cli(['analyse', '../examples/test_if_else.pwat', '200'], Lines),
    assertion(Lines == [
        "Inputs: [5], State: trap",
        "Inputs: [1,1], State: trap"
    ]).


test(paths_if_else_high_limit_all_paths) :-
    run_cli(['paths', '../examples/test_if_else.pwat', '200'], Lines),
    assertion(Lines == [
        "Inputs: [5], State: trap",
        "Inputs: [1,1], State: trap",
        "Inputs: [1,6], State: finished"
    ]).


test(paths_if_else_low_limit_truncated_execution) :-
    run_cli(['paths', '../examples/test_if_else.pwat', '1'], Lines),
    assertion(Lines == [
        "Inputs: [], State: finished"
    ]).


test(analyse_if_else_low_limit_no_trap_paths) :-
    run_cli(['analyse', '../examples/test_if_else.pwat', '1'], Lines),
    assertion(Lines == []).


test(run_more_paths_finished_state) :-
    run_cli_with_input(['run', '../examples/test_more_paths.pwat'], "1\n7\n1\n", Lines),
    assertion(member("State: finished", Lines)),
    assertion(member("Returns: []", Lines)).


test(run_more_paths_trap_state) :-
    run_cli_with_input(['run', '../examples/test_more_paths.pwat'], "4\n3\n", Lines),
    assertion(member("State: trap", Lines)),
    assertion(member("Returns: []", Lines)).


test(analyse_more_paths_high_limit_trap_paths) :-
    run_cli(['analyse', '../examples/test_more_paths.pwat', '300'], Lines),
    assertion(Lines == [
        "Inputs: [4,3], State: trap",
        "Inputs: [1,1], State: trap",
        "Inputs: [1,7,3], State: trap"
    ]).


test(paths_more_paths_high_limit_all_paths) :-
    run_cli(['paths', '../examples/test_more_paths.pwat', '300'], Lines),
    assertion(Lines == [
        "Inputs: [4,3], State: trap",
        "Inputs: [4,1], State: finished",
        "Inputs: [1,1], State: trap",
        "Inputs: [1,7,1], State: finished",
        "Inputs: [1,7,3], State: trap"
    ]).

:- end_tests(cli_modes).
