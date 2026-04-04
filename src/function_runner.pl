:- module(function_runner, [execute_function/7]).

:- use_module(primitive_runner).

execute_function(Index, Args, Module, MemoryIn, MemoryOut, Returns, Status) :-
    Module = module(_Start, _Data, Funcs),
    nth0(Index, Funcs, func(ArgCount, LocalCount, ResultCount, Instrs)),
    length(Args, ArgCount),
    init_locals(Args, LocalCount, Locals0),
    Stack0 = [],
    exec_instructions(Instrs, Module, Locals0, Stack0, MemoryIn, Memory1, Locals1, Stack1, Signal),
    ( Signal = trap ->
        Status = trap,
        Returns = [],
        MemoryOut = Memory1
    ; Signal = continue ->
        Status = finished,
        take_n(ResultCount, Stack1, Returns),
        MemoryOut = Memory1,
        _ = Locals1
    ; Signal = returned ->
        Status = finished,
        take_n(ResultCount, Stack1, Returns),
        MemoryOut = Memory1,
        _ = Locals1
    ).

init_locals(Args, LocalCount, Locals) :-
    zeros(LocalCount, ZeroLocals),
    append(Args, ZeroLocals, Locals).

zeros(0, []) :- !.
zeros(N, [0|T]) :-
    N > 0,
    N1 is N - 1,
    zeros(N1, T).

exec_instructions([], _Module, Locals, Stack, Memory, Memory, Locals, Stack, continue).
exec_instructions([Instr|Rest], Module, LocalsIn, StackIn, MemoryIn, MemoryOut, LocalsOut, StackOut, Signal) :-
    exec_instruction(Instr, Module, LocalsIn, StackIn, MemoryIn, Locals1, Stack1, Memory1, StepSignal),
    ( StepSignal = continue ->
        exec_instructions(Rest, Module, Locals1, Stack1, Memory1, MemoryOut, LocalsOut, StackOut, Signal)
    ; Signal = StepSignal,
      LocalsOut = Locals1,
      StackOut = Stack1,
      MemoryOut = Memory1
    ).

exec_instruction(i32_const(X), _Module, Locals, Stack, Memory, Locals, [X|Stack], Memory, continue).
exec_instruction(i32_add, _Module, Locals, StackIn, Memory, Locals, StackOut, Memory, Signal) :-
    binary_op(StackIn, StackOut, +, Signal).
exec_instruction(i32_sub, _Module, Locals, StackIn, Memory, Locals, StackOut, Memory, Signal) :-
    binary_op(StackIn, StackOut, -, Signal).
exec_instruction(i32_mul, _Module, Locals, StackIn, Memory, Locals, StackOut, Memory, Signal) :-
    binary_op(StackIn, StackOut, *, Signal).
exec_instruction(i32_div_s, _Module, Locals, [B, A|Rest], Memory, Locals, StackOut, Memory, Signal) :-
    ( B =:= 0 ->
        Signal = trap,
        StackOut = [B, A|Rest]
    ; Q is A // B,
      StackOut = [Q|Rest],
      Signal = continue
    ).
exec_instruction(i32_div_s, _Module, Locals, Stack, Memory, Locals, Stack, Memory, trap).

exec_instruction(drop, _Module, Locals, [_|Rest], Memory, Locals, Rest, Memory, continue).
exec_instruction(drop, _Module, Locals, Stack, Memory, Locals, Stack, Memory, trap).
exec_instruction(nop, _Module, Locals, Stack, Memory, Locals, Stack, Memory, continue).
exec_instruction(unreachable, _Module, Locals, Stack, Memory, Locals, Stack, Memory, trap).

exec_instruction(local_get(N), _Module, Locals, Stack, Memory, Locals, [Value|Stack], Memory, continue) :-
    nth0(N, Locals, Value), !.
exec_instruction(local_get(_N), _Module, Locals, Stack, Memory, Locals, Stack, Memory, trap).

exec_instruction(local_set(N), _Module, LocalsIn, [Value|Stack], Memory, LocalsOut, Stack, Memory, continue) :-
    set_nth0(LocalsIn, N, Value, LocalsOut), !.
exec_instruction(local_set(_N), _Module, Locals, Stack, Memory, Locals, Stack, Memory, trap).

exec_instruction(local_tee(N), _Module, LocalsIn, [Value|Stack], Memory, LocalsOut, [Value|Stack], Memory, continue) :-
    set_nth0(LocalsIn, N, Value, LocalsOut), !.
exec_instruction(local_tee(_N), _Module, Locals, Stack, Memory, Locals, Stack, Memory, trap).

exec_instruction(call(Target), Module, Locals, StackIn, MemoryIn, Locals, StackOut, MemoryOut, Signal) :-
    ( integer(Target) ->
        call_internal(Target, Module, StackIn, MemoryIn, StackOut, MemoryOut, Signal)
    ; atom(Target) ->
        call_primitive(Target, StackIn, MemoryIn, StackOut, MemoryOut, Signal)
    ; Signal = trap,
      StackOut = StackIn,
      MemoryOut = MemoryIn
    ).

exec_instruction(return, _Module, Locals, Stack, Memory, Locals, Stack, Memory, returned).

exec_instruction(_Unsupported, _Module, Locals, Stack, Memory, Locals, Stack, Memory, trap).

binary_op([B, A|Rest], [R|Rest], Op, continue) :-
    eval_binop(Op, A, B, R), !.
binary_op(Stack, Stack, _Op, trap).

eval_binop(+, A, B, R) :- R is A + B.
eval_binop(-, A, B, R) :- R is A - B.
eval_binop(*, A, B, R) :- R is A * B.

call_internal(Index, Module, StackIn, MemoryIn, StackOut, MemoryOut, Signal) :-
    Module = module(_Start, _Data, Funcs),
    nth0(Index, Funcs, func(ArgCount, _Locals, _Results, _Instrs)),
    pop_n(ArgCount, StackIn, RawArgs, StackRest),
    reverse(RawArgs, Args),
    execute_function(Index, Args, Module, MemoryIn, MemoryOut, Returns, Status),
    ( Status = trap ->
        Signal = trap,
        StackOut = StackIn
    ; append_rev(Returns, StackRest, StackOut),
      Signal = continue
    ), !.
call_internal(_Index, _Module, Stack, Memory, Stack, Memory, trap).

set_nth0([_|T], 0, Value, [Value|T]) :- !.
set_nth0([H|T], N, Value, [H|T1]) :-
    N > 0,
    N1 is N - 1,
    set_nth0(T, N1, Value, T1).

pop_n(0, Stack, [], Stack) :- !.
pop_n(N, [H|T], [H|Rest], StackRest) :-
    N > 0,
    N1 is N - 1,
    pop_n(N1, T, Rest, StackRest).

append_rev([], Tail, Tail).
append_rev([H|T], Tail, Out) :-
    append_rev(T, Tail, Out1),
    Out = [H|Out1].

take_n(0, _Stack, []) :- !.
take_n(N, [H|T], [H|Rest]) :-
    N > 0,
    N1 is N - 1,
    take_n(N1, T, Rest).
