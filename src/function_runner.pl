:- module(function_runner, [execute_function/8]).

:- use_module(primitive_runner).
:- use_module(utilities).

execute_function(Index, Args, Module, Memory, Returns, Status, ContextIn, ContextOut) :-
    setup_function(Index, Args, Module, LocalsIn, Instrs, ResultCount),
    run_function(Instrs, Module, LocalsIn, Memory, Stack1, Signal, ContextIn, ContextOut),
    handle_function_signal(Signal, ResultCount, Stack1, Returns, Status).

% Haalt de functie op en initialiseert locals
setup_function(Index, Args, Module, LocalsIn, Instrs, ResultCount) :-
    Module = module(_Start, _Data, Funcs),
    nth0(Index, Funcs, func(ArgCount, LocalCount, ResultCount, Instrs)),
    length(Args, ArgCount),
    init_locals(Args, LocalCount, LocalsIn).

% Voert de instructies uit met een lege startstack
run_function(Instrs, Module, LocalsIn, Memory, StackOut, Signal, ContextIn, ContextOut) :-
    Stack0 = [], % elke functie heeft zijn eigen lege stack om mee te werken omdat args en locals niet via stack worden doorgegeven
    exec_instructions(Instrs, Module, LocalsIn, _Locals, Stack0, StackOut, Memory, Signal, ContextIn, ContextOut).


% Verwerkt het eindsignaal van de uitvoering
handle_function_signal(trap, _ResultCount, _Stack, [], trap).

% continue => func is finished, dus return
handle_function_signal(continue, ResultCount, Stack, Returns, finished) :-
    take_n(ResultCount, Stack, Returns).

% returned => func is finished
handle_function_signal(returned, ResultCount, Stack, Returns, finished) :-
    take_n(ResultCount, Stack, Returns).


% TODO dit wordt nooit opgeroepen for some reason
exec_instructions([], _Module, Locals, Locals, Stack, Stack, _Memory, continue, Context, Context). % geen instructions meer => result = continue

exec_instructions([Instr|Rest], Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut) :-
    exec_instruction(Instr, Module, LocalsIn, Locals1, StackIn, Stack1, Memory, StepSignal, ContextIn, ContextOutExecute),
    increment_instruction_counter(ContextOutExecute, IncrementedContext),
    continue_or_stop(StepSignal, Rest, Module, Locals1, LocalsOut, Stack1, StackOut, Memory, Signal, IncrementedContext, ContextOut).

increment_instruction_counter(analyse(MaxInstructions, CurrentCounter, Inputs, BadInputs), analyse(MaxInstructions, IncCurrentCounter, Inputs, BadInputs)) :-
    integer(CurrentCounter),
    IncCurrentCounter is CurrentCounter + 1.

increment_instruction_counter(analyse(MaxInstructions, CurrentCounter, Inputs, BadInputs, PathTrace), analyse(MaxInstructions, IncCurrentCounter, Inputs, BadInputs, PathTrace)) :-
    integer(CurrentCounter),
    IncCurrentCounter is CurrentCounter + 1.

% niets te incrementen in geval van run context
increment_instruction_counter(run, run).


record_branch_decision(analyse(MaxInstructions, Counter, Inputs, BadInputs, PathTraceIn), Decision, analyse(MaxInstructions, Counter, Inputs, BadInputs, [Decision|PathTraceIn])) :-
    !.
record_branch_decision(Context, _Decision, Context).



% als continue -> voer volgende instructie uit.
% TODO stop als we meer instructies hebben dan MaxInstructions.
continue_or_stop(continue, Rest, Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut) :-
    exec_instructions(Rest, Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut).

% stop als een instructie een instructie een step, return of branch ziet staan. Dan stoppen we hier de uitvoering en geven we deze signal door naar boven.
continue_or_stop(NotContinue, _Rest, _Module, Locals, Locals, Stack, Stack, _Memory, NotContinue, ContextIn, ContextOut) :-
    NotContinue \= continue,
    ContextOut = ContextIn.


handle_block_signal(continue, Locals, Stack, Locals, Stack, continue).
handle_block_signal(returned, Locals, Stack, Locals, Stack, returned).
handle_block_signal(trap, Locals, Stack, Locals, Stack, trap).
handle_block_signal(break(0), Locals, Stack, Locals, Stack, continue).
handle_block_signal(break(N), Locals, Stack, Locals, Stack, break(N1)) :-
    N > 0,
    N1 is N - 1.

run_loop(Instructions, Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut) :-
    exec_instructions(Instructions, Module, LocalsIn, Locals1, StackIn, Stack1, Memory, InnerSignal, ContextIn, ContextAfterBody),
    handle_loop_signal(InnerSignal, Instructions, Module, Locals1, LocalsOut, Stack1, StackOut, Memory, Signal, ContextAfterBody, ContextOut).

handle_loop_signal(continue, _Instructions, _Module, Locals, Locals, Stack, Stack, _Memory, continue, ContextIn, ContextOut) :-
    ContextOut = ContextIn.
handle_loop_signal(returned, _Instructions, _Module, Locals, Locals, Stack, Stack, _Memory, returned, ContextIn, ContextOut) :-
    ContextOut = ContextIn.
handle_loop_signal(trap, _Instructions, _Module, Locals, Locals, Stack, Stack, _Memory, trap, ContextIn, ContextOut) :-
    ContextOut = ContextIn.
handle_loop_signal(break(0), Instructions, Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut) :-
    run_loop(Instructions, Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut).
handle_loop_signal(break(N), _Instructions, _Module, Locals, Locals, Stack, Stack, _Memory, break(N1), ContextIn, ContextOut) :-
    N > 0,
    N1 is N - 1,
    ContextOut = ContextIn.


call_internal(Index, Module, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut) :-
    Module = module(_Start, _Data, Funcs),
    nth0(Index, Funcs, func(ArgCount, _Locals, _Results, _Instrs)),
    pop_n(ArgCount, StackIn, RawArgs, StackRest),
    reverse(RawArgs, Args),
    execute_function(Index, Args, Module, Memory, Returns, Status, ContextIn, ContextOut),
    prepare_to_return(Status, Returns, StackIn, StackRest, StackOut, Signal).

call_internal(_Index, _Module, Stack, Stack, _Memory, trap, _, _).

% trap => maakt niet uit wat we doen gewoon, trap teruggeven en stack behouden
prepare_to_return(trap, _Returns, StackIn, _StackRest, StackIn, trap).

prepare_to_return(Status, Returns, _StackIn, StackRest, StackOut, continue) :-
    Status \= trap,
    append_rev(Returns, StackRest, StackOut).



% alle verschillende mogelijke instructies die we moeten ondersteunen:

exec_instruction(i32_const(X), _Module, Locals, Locals, Stack, [X|Stack], _Memory, continue, Context, Context).
exec_instruction(i32_add, _Module, Locals, Locals, StackIn, StackOut, _Memory, Signal, Context, Context) :-
    binary_op(StackIn, StackOut, +, Signal).
exec_instruction(i32_sub, _Module, Locals, Locals, StackIn, StackOut, _Memory, Signal, Context, Context) :-
    binary_op(StackIn, StackOut, -, Signal).
exec_instruction(i32_mul, _Module, Locals, Locals, StackIn, StackOut, _Memory, Signal, Context, Context) :-
    binary_op(StackIn, StackOut, *, Signal).

% deling door nul → trap (stack minsten 2 waarden: 0 en A)
exec_instruction(i32_div_s, _Module, Locals, Locals, [0, A|Rest], [0, A|Rest], _Memory, trap, Context, Context).

% normale deling
exec_instruction(i32_div_s, _Module, Locals, Locals, [B, A|Rest], [Q|Rest], _Memory, continue, Context, Context) :-
    B =\= 0, % zou normaal niet mogen voorkomen met predicaat hierboven
    Q is A // B.

% geval dat stack minder dan 2 waarden heeft => trap
exec_instruction(i32_div_s, _Module, Locals, Locals, Stack, Stack, _Memory, trap, Context, Context).


exec_instruction(i32_lt_s, _Module, Locals, Locals, StackIn, StackOut, _Memory, Signal, Context, Context) :-
    binary_op(StackIn, StackOut, lt_s, Signal).

exec_instruction(i32_le_s, _Module, Locals, Locals, StackIn, StackOut, _Memory, Signal, Context, Context) :-
    binary_op(StackIn, StackOut, le_s, Signal).

exec_instruction(i32_gt_s, _Module, Locals, Locals, StackIn, StackOut, _Memory, Signal, Context, Context) :-
    binary_op(StackIn, StackOut, gt_s, Signal).

exec_instruction(i32_ge_s, _Module, Locals, Locals, StackIn, StackOut, _Memory, Signal, Context, Context) :-
    binary_op(StackIn, StackOut, ge_s, Signal).

exec_instruction(i32_eq, _Module, Locals, Locals, StackIn, StackOut, _Memory, Signal, Context, Context) :-
    binary_op(StackIn, StackOut, eq, Signal).

exec_instruction(i32_ne, _Module, Locals, Locals, StackIn, StackOut, _Memory, Signal, Context, Context) :-
    binary_op(StackIn, StackOut, ne, Signal).

exec_instruction(i32_and, _Module, Locals, Locals, StackIn, StackOut, _Memory, Signal, Context, Context) :-
    binary_op(StackIn, StackOut, i32_and, Signal).

exec_instruction(i32_or, _Module, Locals, Locals, StackIn, StackOut, _Memory, Signal, Context, Context) :-
    binary_op(StackIn, StackOut, i32_or, Signal).

exec_instruction(i32_xor, _Module, Locals, Locals, StackIn, StackOut, _Memory, Signal, Context, Context) :-
    binary_op(StackIn, StackOut, i32_xor, Signal).

% i32_eqz is unair: pop 1 waarde, push 1 of 0
exec_instruction(i32_eqz, _Module, Locals, Locals, [A|Rest], [R|Rest], _Memory, continue, Context, Context) :-
    ( A =:= 0 -> R = 1 ; R = 0 ).
exec_instruction(i32_eqz, _Module, Locals, Locals, Stack, Stack, _Memory, trap, Context, Context).


exec_instruction(drop, _Module, Locals, Locals, [_|Rest], Rest, _Memory, continue, Context, Context).
exec_instruction(drop, _Module, Locals, Locals, Stack, Stack, _Memory, trap, Context, Context).

exec_instruction(nop, _Module, Locals, Locals, Stack, Stack, _Memory, continue, Context, Context).

exec_instruction(unreachable, _Module, Locals, Locals, Stack, Stack, _Memory, trap, Context, Context) :-
    Context = analyse(_, _, _, _, _),
    !.
exec_instruction(unreachable, _Module, Locals, Locals, Stack, Stack, _Memory, trap, Context, Context).


exec_instruction(local_get(N), _Module, Locals, Locals, Stack, [Value|Stack], _Memory, continue, Context, Context) :-
    nth0(N, Locals, Value), !.
% geen n'de local gevonden => trap
exec_instruction(local_get(_N), _Module, Locals, Locals, Stack, Stack, _Memory, trap, Context, Context).


exec_instruction(local_set(N), _Module, LocalsIn, LocalsOut, [Value|Stack], Stack, _Memory, continue, Context, Context) :-
    set_nth0(LocalsIn, N, Value, LocalsOut), !.
exec_instruction(local_set(_N), _Module, Locals, Locals, Stack, Stack, _Memory, trap, Context, Context).


%same als local_set maar dan met ongewijzigde stack
exec_instruction(local_tee(N), _Module, LocalsIn, LocalsOut, [Value|Stack], [Value|Stack], _Memory, continue, Context, Context) :- % exec_instruction(local_tee(N), _Module, LocalsIn, LocalsOut, [Value|Stack], [Value|Stack], _Memory, continue) :- exec_instruction(local_set(N), _Module, LocalsIn, LocalsOut, [Value, Value|Stack], Stack, _Memory, continue).
    set_nth0(LocalsIn, N, Value, LocalsOut), !.

exec_instruction(local_tee(_N), _Module, Locals, Locals, Stack, Stack, _Memory, trap, Context, Context).


% interne functie aanroepen (via index)
exec_instruction(call(Target), Module, Locals, Locals, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut) :-
    integer(Target), !, % check ofdat het integer is => interne functie call
    call_internal(Target, Module, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut).

% primitieve functie aanroepen (via naam: print, read_int...)
exec_instruction(call(Target), _Module, Locals, Locals, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut) :-
    atom(Target), !, % check ofdat atom (print...) voor 'ingebouwde' functie oproep
    call_primitive(Target, StackIn, Memory, StackOut, Signal, ContextIn, ContextOut).

% ongeldige target → trap
exec_instruction(call(_Target), _Module, Locals, Locals, Stack, Stack, _Memory, trap, Context, Context).

exec_instruction(return, _Module, Locals, Locals, Stack, Stack, _Memory, returned, Context, Context).

% we gaan in een block, dus we moeten apart het signaal verwerken => break 1 geeft dan break 0 terug etc
exec_instruction(block(Instructions), Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut) :-
    exec_instructions(Instructions, Module, LocalsIn, Locals1, StackIn, Stack1, Memory, InnerSignal, ContextIn, ContextOut),
    handle_block_signal(InnerSignal, Locals1, Stack1, LocalsOut, StackOut, Signal).


exec_instruction(br(Value), _Module, Locals, Locals, Stack, Stack, _Memory, break(Value), Context, Context) :-
    integer(Value),
    Value >= 0,
    !.

exec_instruction(br(_Value), _Module, Locals, Locals, Stack, Stack, _Memory, trap, Context, Context).


% Conditie is onwaar (0) => voer FalseBlock uit
exec_instruction(if(_TrueBlock, FalseBlock), Module, LocalsIn, LocalsOut, [0|StackIn], StackOut, Memory, Signal, ContextIn, ContextOut) :-
    record_branch_decision(ContextIn, if_false, ContextWithDecision),
    exec_instructions(FalseBlock, Module, LocalsIn, Locals1, StackIn, Stack1, Memory, InnerSignal, ContextWithDecision, ContextOut),
    handle_block_signal(InnerSignal, Locals1, Stack1, LocalsOut, StackOut, Signal).

% Conditie is waar (niet 0) => voer TrueBlock uit
exec_instruction(if(TrueBlock, _FalseBlock), Module, LocalsIn, LocalsOut, [Cond|StackIn], StackOut, Memory, Signal, ContextIn, ContextOut) :-
    number(Cond),
    Cond =\= 0,
    record_branch_decision(ContextIn, if_true, ContextWithDecision),
    exec_instructions(TrueBlock, Module, LocalsIn, Locals1, StackIn, Stack1, Memory, InnerSignal, ContextWithDecision, ContextOut),
    handle_block_signal(InnerSignal, Locals1, Stack1, LocalsOut, StackOut, Signal).


% Lege stack => trap
exec_instruction(if(_TrueBlock, _FalseBlock), _Module, Locals, Locals, [], [], _Memory, trap, Context, Context).
exec_instruction(if(_TrueBlock, _FalseBlock), _Module, Locals, Locals, [Cond|Stack], [Cond|Stack], _Memory, trap, Context, Context) :-
    \+ number(Cond).


exec_instruction(br_if(Value), _Module, Locals, Locals, [Cond|Stack], Stack, _Memory, break(Value), ContextIn, ContextOut) :-
    integer(Value),
    Value >= 0,
    Cond =\= 0,
    record_branch_decision(ContextIn, br_if_true(Value), ContextOut).

% conditie is onwaar (0) => continue
exec_instruction(br_if(Value), _Module, Locals, Locals, [0|Stack], Stack, _Memory, continue, ContextIn, ContextOut) :-
    integer(Value),
    Value >= 0,
    record_branch_decision(ContextIn, br_if_false(Value), ContextOut).

% ongeldige waarde => trap
exec_instruction(br_if(Value), _Module, Locals, Locals, [Cond|Stack], [Cond|Stack], _Memory, trap, Context, Context) :-
    ( \+ integer(Value)
    ; Value < 0
    ; \+ number(Cond)
    ).
exec_instruction(br_if(_Value), _Module, Locals, Locals, [], [], _Memory, trap, Context, Context).


exec_instruction(loop(Instructions), Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut) :-
    run_loop(Instructions, Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut).


% normaal niet voorkomen omdat parser al zou moeten falen, maar voor zekerheid
exec_instruction(_Unsupported, _Module, Locals, Locals, Stack, Stack, _Memory, trap, Context, Context).



