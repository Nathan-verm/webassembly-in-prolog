:- begin_tests(runner_analyse).

:- use_module('../src/runner').
:- use_module('../src/parser').
:- use_module('../src/memory_initializer').
:- use_module('../src/function_runner').
:- use_module(library(plunit)).

analyse_produces_result(File, MaxInstructions) :-
    parse(File, _Module), !,
    ContextIn = analyse(MaxInstructions, 0, [], [], []),
    analyse_file(File, ContextIn, analyse(_, _, _Inputs, _, _), result(_Status, _)), !.

analyse_first_result(File, MaxInstructions, Status-Inputs) :-
    parse(File, _Module), !,
    ContextIn = analyse(MaxInstructions, 0, [], [], []),
    analyse_file(File, ContextIn, analyse(_, _, Inputs, _, _), result(Status, _)), !.

analyse_has_status(File, MaxInstructions, TargetStatus) :-
    parse(File, _Module), !,
    ContextIn = analyse(MaxInstructions, 0, [], [], []),
    analyse_file(File, ContextIn, analyse(_, _, _Inputs, _, _), result(Status, _)),
    Status = TargetStatus, !.
write_test_file(File, Content) :-
    open(File, write, Stream),
    write(Stream, Content),
    close(Stream).


% Eenvoudig rekenen

test(analyse_simple_produces_result) :-
    TempFile = '/tmp/analyse_simple.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 1)
            i32.const 10
            i32.const 5
            i32.add
          )
        )'),
    assertion(analyse_produces_result(TempFile, 100)).


% Unreachable
test(analyse_unreachable_traps) :-
    TempFile = '/tmp/analyse_unreachable.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 0)
            unreachable
          )
        )'),
    assertion(analyse_has_status(TempFile, 100, trap)).


% Read_int
test(analyse_read_produces_paths) :-
    TempFile = '/tmp/analyse_read.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 0)
            i32.const 0
            i32.const 10
            call read_int
            drop
          )
        )'),
    assertion(analyse_produces_result(TempFile, 100)).


% Deling
test(analyse_division_paths) :-
    TempFile = '/tmp/analyse_div.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 0)
            i32.const 10
            i32.const 0
            i32.const 10
            call read_int
            i32.div_s
            drop
          )
        )'),
    assertion(analyse_produces_result(TempFile, 100)).


% If vertakkingen
test(analyse_if_produces_branches) :-
    TempFile = '/tmp/analyse_if.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 1) (results 0)
            i32.const 0
            i32.const 10
            call read_int
            local.set 0
            
            local.get 0
            i32.const 5
            i32.lt_s
            if
              nop
            else
              nop
            end
          )
        )'),
    assertion(analyse_produces_result(TempFile, 100)).


% Meerdere reads
test(analyse_multiple_reads) :-
    TempFile = '/tmp/analyse_multi_read.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 2) (results 0)
            i32.const 0
            i32.const 5
            call read_int
            local.set 0
            
            i32.const 0
            i32.const 5
            call read_int
            local.set 1
            
            local.get 0
            local.get 1
            i32.eq
            if
              nop
            else
              nop
            end
          )
        )'),
    assertion(analyse_produces_result(TempFile, 100)).


% Conditionele trap
test(analyse_conditional_trap) :-
    TempFile = '/tmp/analyse_cond_trap.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 1) (results 0)
            i32.const 0
            i32.const 10
            call read_int
            local.set 0
            
            local.get 0
            i32.const 7
            i32.eq
            if
              unreachable
            end
          )
        )'),
    assertion(analyse_produces_result(TempFile, 100)).


% Lus met limiet
test(analyse_loop_with_limit) :-
    TempFile = '/tmp/analyse_loop.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 1) (results 0)
            i32.const 0
            local.set 0
            
            loop
              local.get 0
              i32.const 1
              i32.add
              local.set 0
              
              local.get 0
              i32.const 5
              i32.lt_s
              br_if 0
            end
          )
        )'),
    assertion(analyse_produces_result(TempFile, 50)).


% Geneste voorwaarden
test(analyse_nested_conditions) :-
    TempFile = '/tmp/analyse_nested.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 2) (results 0)
            i32.const 0
            i32.const 10
            call read_int
            local.set 0
            
            local.get 0
            i32.const 5
            i32.lt_s
            if
              i32.const 0
              i32.const 10
              call read_int
              local.set 1
              
              local.get 1
              i32.const 7
              i32.gt_s
              if
                nop
              else
                unreachable
              end
            else
              nop
            end
          )
        )'),
    assertion(analyse_produces_result(TempFile, 100)).


% Result structuur
test(analyse_result_structure) :-
    TempFile = '/tmp/analyse_result.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 1)
            i32.const 42
          )
        )'),
    analyse_first_result(TempFile, 100, _-_).

:- end_tests(runner_analyse).
