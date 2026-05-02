:- begin_tests(runner_run).

:- use_module('../src/runner').
:- use_module('../src/parser').
:- use_module('../src/memory_initializer').
:- use_module('../src/function_runner').
:- use_module(library(plunit)).

write_test_file(File, Content) :-
    open(File, write, Stream),
    write(Stream, Content),
    close(Stream).

test_run_silent(File, result(Status, Returns)) :-
    parse(File, Module), !,
    Module = module(Start, DataSegments, _Funcs),
    build_memory(DataSegments, Memory),
    execute_function(Start, [], Module, Memory, Returns, Status, run, run), !.

% Blokken en branch
test(primitive_add) :-
    test_run_silent('../examples/test_block.pwat', result(Status, Returns)),
    assertion(Status == finished),
    assertion(Returns == [10]).  % breaks before 20 and add operations

% Aftrekken
test(primitive_subtract) :-
    TempFile = '/tmp/test_sub.pwat',
    write_test_file(TempFile, 
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 1)
            i32.const 20
            i32.const 8
            i32.sub
          )
        )'),
    test_run_silent(TempFile, result(Status, Returns)),
    assertion(Status == finished),
    assertion(Returns == [12]).  % 20 - 8 = 12

% Vermenigvuldigen
test(primitive_multiply) :-
    TempFile = '/tmp/test_mul.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 1)
            i32.const 6
            i32.const 7
            i32.mul
          )
        )'),
    test_run_silent(TempFile, result(Status, Returns)),
    assertion(Status == finished),
    assertion(Returns == [42]).  % 6 * 7 = 42


% Delen
test(primitive_divide) :-
    TempFile = '/tmp/test_div.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 1)
            i32.const 30
            i32.const 5
            i32.div_s
          )
        )'),
    test_run_silent(TempFile, result(Status, Returns)),
    assertion(Status == finished),
    assertion(Returns == [6]).  % 30 / 5 = 6


% Lokale variabelen
test(local_variables) :-
    TempFile = '/tmp/test_locals.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 2) (results 2)
            ;; Set local 0 = 15
            i32.const 15
            local.set 0
            
            ;; Set local 1 = 25
            i32.const 25
            local.set 1
            
            ;; Get and return both
            local.get 0
            local.get 1
          )
        )'),
    test_run_silent(TempFile, result(Status, Returns)),
    assertion(Status == finished),
    assertion(Returns == [25, 15]).  % Stack is LIFO: last pushed first


% Basis lus
test(loop_basic) :-
    test_run_silent('../examples/test_loop.pwat', result(Status, Returns)),
    assertion(Status == finished),
    assertion(Returns == [100]).  % Should loop until local becomes 100


% Teller in lus
test(loop_counter) :-
    TempFile = '/tmp/test_loop_counter.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 1) (results 1)
            ;; local 0 = 0 (counter)
            i32.const 0
            local.set 0
            
            loop
              ;; Increment counter
              local.get 0
              i32.const 1
              i32.add
              local.set 0
              
              ;; Continue if counter < 5
              local.get 0
              i32.const 5
              i32.lt_s
              br_if 0
            end
            
            ;; Return counter
            local.get 0
          )
        )'),
    test_run_silent(TempFile, result(Status, Returns)),
    assertion(Status == finished),
    assertion(Returns == [5]).


% If waar
test(conditional_if_true) :-
    TempFile = '/tmp/test_if_true.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 1)
            ;; if 10 > 5
            i32.const 10
            i32.const 5
            i32.gt_s
            if
              i32.const 100
            end
          )
        )'),
    test_run_silent(TempFile, result(Status, Returns)),
    assertion(Status == finished),
    assertion(Returns == [100]).


% If/else waar
test(conditional_if_else_true) :-
    TempFile = '/tmp/test_if_else_var.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 1)
            ;; if 3 < 5 (true)
            i32.const 3
            i32.const 5
            i32.lt_s
            if
              i32.const 200
            else
              i32.const 300
            end
          )
        )'),
    test_run_silent(TempFile, result(Status, Returns)),
    assertion(Status == finished),
    assertion(Returns == [200]).


% If/else onwaar
test(conditional_if_else_false) :-
    TempFile = '/tmp/test_if_else_false.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 1)
            ;; if 10 < 5 (false)
            i32.const 10
            i32.const 5
            i32.lt_s
            if
              i32.const 500
            else
              i32.const 600
            end
          )
        )'),
    test_run_silent(TempFile, result(Status, Returns)),
    assertion(Status == finished),
    assertion(Returns == [600]).


% Return
test(early_return) :-
    test_run_silent('../examples/test_return.pwat', result(Status, Returns)),
    assertion(Status == finished),
    assertion(Returns == [50, 40, 30, 20, 10]).  % Stack is LIFO


% Optellen
test(simple_add) :-
    TempFile = '/tmp/test_simple_add.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 1)
            i32.const 3
            i32.const 5
            i32.add
          )
        )'),
    test_run_silent(TempFile, result(Status, Returns)),
    assertion(Status == finished),
    assertion(Returns == [8]).  % 3 + 5 = 8


% Kleiner dan
test(compare_less_than_true) :-
    TempFile = '/tmp/test_lt.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 1)
            i32.const 3
            i32.const 5
            i32.lt_s
          )
        )'),
    test_run_silent(TempFile, result(Status, Returns)),
    assertion(Status == finished),
    assertion(Returns == [1]).


% Groter dan
test(compare_greater_than_false) :-
    TempFile = '/tmp/test_gt.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 1)
            i32.const 3
            i32.const 5
            i32.gt_s
          )
        )'),
    test_run_silent(TempFile, result(Status, Returns)),
    assertion(Status == finished),
    assertion(Returns == [0]).


% Gelijk
test(compare_equal_true) :-
    TempFile = '/tmp/test_eq.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 1)
            i32.const 42
            i32.const 42
            i32.eq
          )
        )'),
    test_run_silent(TempFile, result(Status, Returns)),
    assertion(Status == finished),
    assertion(Returns == [1]).


% Complexe rekenkunde
test(complex_arithmetic) :-
    TempFile = '/tmp/test_complex.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 1)
            ;; (10 + 5) * 2 = 30
            i32.const 10
            i32.const 5
            i32.add
            i32.const 2
            i32.mul
          )
        )'),
    test_run_silent(TempFile, result(Status, Returns)),
    assertion(Status == finished),
    assertion(Returns == [30]).


% Meerdere return values
test(multiple_returns) :-
    TempFile = '/tmp/test_multi_return.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 3)
            i32.const 1
            i32.const 2
            i32.const 3
          )
        )'),
    test_run_silent(TempFile, result(Status, Returns)),
    assertion(Status == finished),
    assertion(Returns == [3, 2, 1]).  % Stack is LIFO


% Meerdere waardes op stack
test(stack_multiple_values) :-
    TempFile = '/tmp/test_stack.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 4)
            i32.const 10
            i32.const 20
            i32.const 30
            i32.const 40
          )
        )'),
    test_run_silent(TempFile, result(Status, Returns)),
    assertion(Status == finished),
    assertion(Returns == [40, 30, 20, 10]).  % Stack is LIFO


% Geneste lus
test(nested_loop_and_block) :-
    TempFile = '/tmp/test_nested_loop.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 1) (results 1)
            i32.const 0
            local.set 0
            
            block
              loop
                ;; Increment
                local.get 0
                i32.const 1
                i32.add
                local.set 0
                
                ;; Break if >= 3
                local.get 0
                i32.const 3
                i32.ge_s
                br_if 1
                
                ;; Otherwise continue loop
                br 0
              end
            end
            
            local.get 0
          )
        )'),
    test_run_silent(TempFile, result(Status, Returns)),
    assertion(Status == finished),
    assertion(Returns == [3]).


% Negatieve getallen
test(negative_numbers) :-
    TempFile = '/tmp/test_negative.pwat',
    write_test_file(TempFile,
        '(module
          (start 0)
          (func (args 0) (locals 0) (results 1)
            i32.const -10
            i32.const 2
            i32.mul
          )
        )'),
    test_run_silent(TempFile, result(Status, Returns)),
    assertion(Status == finished),
    assertion(Returns == [-20]).

:- end_tests(runner_run).
