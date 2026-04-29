:- begin_tests(runner_paths).

:- use_module('../src/runner').
:- use_module('../src/parser').
:- use_module('../src/memory_initializer').
:- use_module('../src/function_runner').
:- use_module(library(plunit)).

% Helper: Check if paths produces at least one result
paths_produces_result(File, MaxInstructions) :-
    parse(File, _Module), !,
    ContextIn = analyse(MaxInstructions, 0, [], [], []),
    analyse_file(File, ContextIn, analyse(_, _, _Inputs, _, _PathTrace), result(_Status, _)), !.

% Helper: Get first paths result
paths_first_result(File, MaxInstructions, Status-Inputs) :-
    parse(File, _Module), !,
    ContextIn = analyse(MaxInstructions, 0, [], [], []),
    analyse_file(File, ContextIn, analyse(_, _, Inputs, _, _PathTrace), result(Status, _)), !.

% Helper: Check if paths finds specific status
paths_has_status(File, MaxInstructions, TargetStatus) :-
    parse(File, _Module), !,
    ContextIn = analyse(MaxInstructions, 0, [], [], []),
    analyse_file(File, ContextIn, analyse(_, _, _Inputs, _, _PathTrace), result(Status, _)),
    Status = TargetStatus, !.

% Helper: Count unique paths by collecting all Status values
paths_count_statuses(File, MaxInstructions, Count) :-
    parse(File, _Module), !,
    findall(Status,
        (
            ContextIn = analyse(MaxInstructions, 0, [], [], []),
            analyse_file(File, ContextIn, analyse(_, _, _Inputs, _, _PathTrace), result(Status, _))
        ),
        AllStatuses),
    length(AllStatuses, Count).

% Helper: Write test file
write_test_file(File, Content) :-
    open(File, write, Stream),
    write(Stream, Content),
    close(Stream).

% =============================================================================
% TEST 1: Simple program - single path
% =============================================================================
test(paths_simple_single_path) :-
    TempFile = '/tmp/paths_simple.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 1)
            i32.const 42
          )
        )'),
    assertion(paths_produces_result(TempFile, 100)).

% =============================================================================
% TEST 2: Unreachable - always trap path
% =============================================================================
test(paths_unreachable) :-
    TempFile = '/tmp/paths_unreachable.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 0)
            unreachable
          )
        )'),
    assertion(paths_has_status(TempFile, 100, trap)).

% =============================================================================
% TEST 3: If creates two paths
% =============================================================================
test(paths_if_creates_branches) :-
    TempFile = '/tmp/paths_if_branch.pwat',
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
    paths_count_statuses(TempFile, 100, Count),
    assertion(Count > 1).

% =============================================================================
% TEST 4: Multiple if statements - exponential paths
% =============================================================================
test(paths_multiple_ifs) :-
    TempFile = '/tmp/paths_multi_ifs.pwat',
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
            i32.const 2
            i32.lt_s
            if
              local.get 1
              i32.const 2
              i32.lt_s
              if
                nop
              else
                nop
              end
            else
              nop
            end
          )
        )'),
    paths_count_statuses(TempFile, 100, Count),
    assertion(Count >= 3).  % At least 3 different paths

% =============================================================================
% TEST 5: Read int produces multiple paths
% =============================================================================
test(paths_read_int_paths) :-
    TempFile = '/tmp/paths_read.pwat',
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
    assertion(paths_produces_result(TempFile, 100)).

% =============================================================================
% TEST 6: Trap and finished paths mixed
% =============================================================================
test(paths_mixed_trap_finished) :-
    TempFile = '/tmp/paths_mixed.pwat',
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
              unreachable
            else
              nop
            end
          )
        )'),
    assertion(paths_has_status(TempFile, 100, finished)).

% =============================================================================
% TEST 7: Division with controlled inputs
% =============================================================================
test(paths_division_paths) :-
    TempFile = '/tmp/paths_division.pwat',
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
    paths_count_statuses(TempFile, 100, Count),
    assertion(Count > 1).

% =============================================================================
% TEST 8: Loop with paths
% =============================================================================
test(paths_loop) :-
    TempFile = '/tmp/paths_loop.pwat',
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
    assertion(paths_produces_result(TempFile, 100)).

% =============================================================================
% TEST 9: Result structure has status and inputs
% =============================================================================
test(paths_result_structure) :-
    TempFile = '/tmp/paths_struct.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 1)
            i32.const 99
          )
        )'),
    paths_first_result(TempFile, 100, _-_).

% =============================================================================
% TEST 10: Nested conditions create complex paths
% =============================================================================
test(paths_nested_conditions) :-
    TempFile = '/tmp/paths_nested.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 3) (results 0)
            i32.const 0
            i32.const 5
            call read_int
            local.set 0
            
            local.get 0
            i32.const 2
            i32.lt_s
            if
              i32.const 0
              i32.const 5
              call read_int
              local.set 1
              
              local.get 1
              i32.const 2
              i32.lt_s
              if
                i32.const 0
                i32.const 5
                call read_int
                local.set 2
                
                local.get 2
                i32.const 2
                i32.lt_s
                if
                  unreachable
                else
                  nop
                end
              else
                nop
              end
            else
              nop
            end
          )
        )'),
    paths_count_statuses(TempFile, 100, Count),
    assertion(Count >= 5).

:- end_tests(runner_paths).
