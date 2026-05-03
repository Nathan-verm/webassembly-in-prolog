:- begin_tests(exit_codes).

:- use_module(library(process)).

write_test_file(File, Content) :-
    open(File, write, Stream),
    write(Stream, Content),
    close(Stream).

run_cli_exit(Args, ExitStatus) :-
    process_create(path(swipl),
        ['-q', '-s', '../src/main.pl', '--' | Args],
        [stdout(pipe(Out)), stderr(pipe(Err)), process(PID)]),
    read_string(Out, _, _),
    read_string(Err, _, _),
    close(Out),
    close(Err),
    process_wait(PID, ExitStatus).


test(run_exit_finished_is_zero) :-
    TempFile = '/tmp/test_exit_finished.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 1)
            i32.const 2
            i32.const 3
            i32.add
          )
        )'),
    run_cli_exit(['run', TempFile], Status),
    assertion(Status == exit(0)).


test(run_exit_trap_is_two) :-
    TempFile = '/tmp/test_exit_trap.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 1)
            i32.const 1
            i32.const 0
            i32.div_s
          )
        )'),
    run_cli_exit(['run', TempFile], Status),
    assertion(Status == exit(2)).

:- end_tests(exit_codes).
