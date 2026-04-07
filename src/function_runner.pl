:- module(function_runner, [execute_function/6]).

:- use_module(primitive_runner).

execute_function(Index, Args, Module, Memory, Returns, Status) :-
    setup_function(Index, Args, Module, Locals0, Instrs, ResultCount),
    run_function(Instrs, Module, Locals0, Memory, Stack1, Signal),
    handle_signal(Signal, ResultCount, Stack1, Returns, Status).

% Haalt de functie op en initialiseert locals
setup_function(Index, Args, Module, Locals0, Instrs, ResultCount) :-
    Module = module(_Start, _Data, Funcs),
    nth0(Index, Funcs, func(ArgCount, LocalCount, ResultCount, Instrs)),
    length(Args, ArgCount),
    init_locals(Args, LocalCount, Locals0).

% Voert de instructies uit met een lege startstack
run_function(Instrs, Module, Locals0, Memory, StackOut, Signal) :-
    Stack0 = [], % elke functie heeft zijn eigen lege stack om mee te werken omdat args en locals niet via stack worden doorgegeven
    exec_instructions(Instrs, Module, Locals0, _Locals, Stack0, StackOut, Memory, Signal).


% Verwerkt het eindsignaal van de uitvoering
handle_signal(trap, _ResultCount, _Stack, [], trap).

handle_signal(continue, ResultCount, Stack, Returns, finished) :-
    take_n(ResultCount, Stack, Returns).

handle_signal(returned, ResultCount, Stack, Returns, finished) :-
    take_n(ResultCount, Stack, Returns).

% zet locals op 0
init_locals(Args, LocalCount, Locals) :-
    zeros(LocalCount, ZeroLocals),
    append(Args, ZeroLocals, Locals).

zeros(0, []) :- !.
zeros(N, [0|T]) :-
    N > 0,
    N1 is N - 1,
    zeros(N1, T).

exec_instructions([], _Module, Locals, Locals, Stack, Stack, _Memory, continue). % geen instructions meer => result = continue


% voert 1 instructie uit en handelt step singal af (continue, ).
exec_instructions([Instr|Rest], Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, Signal) :-
    exec_instruction(Instr, Module, LocalsIn, Locals1, StackIn, Stack1, Memory, StepSignal),
    ( StepSignal = continue ->
        exec_instructions(Rest, Module, Locals1, LocalsOut, Stack1, StackOut, Memory, Signal)
    ; Signal = StepSignal,
      LocalsOut = Locals1,
      StackOut = Stack1
    ).


% alle verschillende mogelijke instructies die we moeten ondersteunen:

exec_instruction(i32_const(X), _Module, Locals, Locals, Stack, [X|Stack], _Memory, continue).
exec_instruction(i32_add, _Module, Locals, Locals, StackIn, StackOut, _Memory, Signal) :-
    binary_op(StackIn, StackOut, +, Signal).
exec_instruction(i32_sub, _Module, Locals, Locals, StackIn, StackOut, _Memory, Signal) :-
    binary_op(StackIn, StackOut, -, Signal).
exec_instruction(i32_mul, _Module, Locals, Locals, StackIn, StackOut, _Memory, Signal) :-
    binary_op(StackIn, StackOut, *, Signal).

% deling door nul → trap (stack minsten 2 waarden: 0 en A)
exec_instruction(i32_div_s, _Module, Locals, Locals, [0, A|Rest], [0, A|Rest], _Memory, trap).

% normale deling
exec_instruction(i32_div_s, _Module, Locals, Locals, [B, A|Rest], [Q|Rest], _Memory, continue) :-
    B =\= 0, % zou normaal niet mogen voorkomen met predicaat hierboven
    Q is A // B.

% geval dat stack minder dan 2 waarden heeft => trap
exec_instruction(i32_div_s, _Module, Locals, Locals, Stack, Stack, _Memory, trap).


exec_instruction(drop, _Module, Locals, Locals, [_|Rest], Rest, _Memory, continue).
exec_instruction(drop, _Module, Locals, Locals, Stack, Stack, _Memory, trap).

exec_instruction(nop, _Module, Locals, Locals, Stack, Stack, _Memory, continue).

exec_instruction(unreachable, _Module, Locals, Locals, Stack, Stack, _Memory, trap).



exec_instruction(local_get(N), _Module, Locals, Locals, Stack, [Value|Stack], _Memory, continue) :-
    nth0(N, Locals, Value), !.
% geen n'de local gevonden => trap
exec_instruction(local_get(_N), _Module, Locals, Locals, Stack, Stack, _Memory, trap).


exec_instruction(local_set(N), _Module, LocalsIn, LocalsOut, [Value|Stack], Stack, _Memory, continue) :-
    set_nth0(LocalsIn, N, Value, LocalsOut), !.
exec_instruction(local_set(_N), _Module, Locals, Locals, Stack, Stack, _Memory, trap).


%same als local_set maar dan met ongewijzigde stack
exec_instruction(local_tee(N), _Module, LocalsIn, LocalsOut, [Value|Stack], [Value|Stack], _Memory, continue) :- % exec_instruction(local_tee(N), _Module, LocalsIn, LocalsOut, [Value|Stack], [Value|Stack], _Memory, continue) :- exec_instruction(local_set(N), _Module, LocalsIn, LocalsOut, [Value, Value|Stack], Stack, _Memory, continue).
    set_nth0(LocalsIn, N, Value, LocalsOut), !.

exec_instruction(local_tee(_N), _Module, Locals, Locals, Stack, Stack, _Memory, trap).


% interne functie aanroepen (via index)
exec_instruction(call(Target), Module, Locals, Locals, StackIn, StackOut, Memory, Signal) :-
    integer(Target), !, % check ofdat het integer is => interne functie call
    call_internal(Target, Module, StackIn, StackOut, Memory, Signal).

% primitieve functie aanroepen (via naam: print, read_int...)
exec_instruction(call(Target), _Module, Locals, Locals, StackIn, StackOut, Memory, Signal) :-
    atom(Target), !, % check ofdat atom (print...) voor 'ingebouwde' functie oproep
    call_primitive(Target, StackIn, Memory, StackOut, Signal).

% ongeldige target → trap
exec_instruction(call(_Target), _Module, Locals, Locals, Stack, Stack, _Memory, trap).

exec_instruction(return, _Module, Locals, Locals, Stack, Stack, _Memory, returned).

exec_instruction(block(Instructions), Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, continue) :-
    exec_instructions(Instructions, Module, LocalsIn, Locals1, StackIn, Stack1, Memory, InnerSignal),
    handle_block_signal(InnerSignal, Locals1, Stack1, LocalsOut, StackOut, continue).

% exec_instruction(loop(Instructions), Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, Signal) :-
%     run_loop(Instructions, Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, Signal).

% exec_instruction(if(TrueBlock, FalseBlock), Module, LocalsIn, LocalsOut, [Cond|StackIn], StackOut, Memory, Signal) :-
%     ( Cond =\= 0 -> Block = TrueBlock ; Block = FalseBlock ),
%     exec_instructions(Block, Module, LocalsIn, Locals1, StackIn, Stack1, Memory, InnerSignal),
%     handle_block_signal(InnerSignal, Locals1, Stack1, LocalsOut, StackOut, Signal).
% exec_instruction(if(_TrueBlock, _FalseBlock), _Module, Locals, Locals, Stack, Stack, _Memory, trap).

exec_instruction(br(Value), _Module, Locals, Locals, Stack, Stack, _Memory, break(Value)) :-
    integer(Value),
    Value >= 0,
    !.
exec_instruction(br(_Value), _Module, Locals, Locals, Stack, Stack, _Memory, trap).

% exec_instruction(br_if(Value), _Module, Locals, Locals, [Cond|Stack], Stack, _Memory, Signal) :-
%     integer(Value),
%     Value >= 0,
%     ( Cond =\= 0 -> Signal = break(Value) ; Signal = continue ),
%     !.
% exec_instruction(br_if(_Value), _Module, Locals, Locals, Stack, Stack, _Memory, trap).

% normaal niet voorkomen omdat parser al zou moeten falen, maar voor zekerheid
exec_instruction(_Unsupported, _Module, Locals, Locals, Stack, Stack, _Memory, trap).


binary_op([B, A|Rest], [R|Rest], Op, continue) :-
    eval_binop(Op, A, B, R), !.

binary_op(Stack, Stack, _Op, trap). % als er al een trap gegenereerd werd => doe niets

eval_binop(+, A, B, R) :- R is A + B.
eval_binop(-, A, B, R) :- R is A - B.
eval_binop(*, A, B, R) :- R is A * B.

handle_block_signal(continue, Locals, Stack, Locals, Stack, continue).
handle_block_signal(returned, Locals, Stack, Locals, Stack, returned).
handle_block_signal(trap, Locals, Stack, Locals, Stack, trap).
handle_block_signal(break(0), Locals, Stack, Locals, Stack, continue).
handle_block_signal(break(N), Locals, Stack, Locals, Stack, break(N1)) :-
    N > 0,
    N1 is N - 1.

run_loop(Instructions, Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, Signal) :-
    exec_instructions(Instructions, Module, LocalsIn, Locals1, StackIn, Stack1, Memory, InnerSignal),
    handle_loop_signal(InnerSignal, Instructions, Module, Locals1, LocalsOut, Stack1, StackOut, Memory, Signal).

handle_loop_signal(continue, _Instructions, _Module, Locals, Locals, Stack, Stack, _Memory, continue).
handle_loop_signal(returned, _Instructions, _Module, Locals, Locals, Stack, Stack, _Memory, returned).
handle_loop_signal(trap, _Instructions, _Module, Locals, Locals, Stack, Stack, _Memory, trap).
handle_loop_signal(break(0), Instructions, Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, Signal) :-
    run_loop(Instructions, Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, Signal).
handle_loop_signal(break(N), _Instructions, _Module, Locals, Locals, Stack, Stack, _Memory, break(N1)) :-
    N > 0,
    N1 is N - 1.

call_internal(Index, Module, StackIn, StackOut, Memory, Signal) :-
    Module = module(_Start, _Data, Funcs),
    nth0(Index, Funcs, func(ArgCount, _Locals, _Results, _Instrs)),
    pop_n(ArgCount, StackIn, RawArgs, StackRest),
    reverse(RawArgs, Args),
    execute_function(Index, Args, Module, Memory, Returns, Status),
    ( Status = trap ->
        Signal = trap,
        StackOut = StackIn
    ; append_rev(Returns, StackRest, StackOut),
      Signal = continue
    ), !.
call_internal(_Index, _Module, Stack, Stack, _Memory, trap).

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
