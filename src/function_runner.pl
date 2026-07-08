:- module(function_runner, [execute_function/8]).

:- use_module(primitive_runner).
:- use_module(utilities).

execute_function(Index, Args, Module, Memory, Returns, Status, ContextIn, ContextOut) :-
    setup_function(Index, Args, Module, LocalsIn, Instrs, ResultCount),
    run_function(Instrs, Module, LocalsIn, Memory, Stack1, Signal, ContextIn, ContextOut),
    handle_function_signal(Signal, ResultCount, Stack1, Returns, Status).

% Fetches the function and initializes locals
setup_function(Index, Args, Module, LocalsIn, Instrs, ResultCount) :-
    Module = module(_Start, _Data, Funcs),
    nth0(Index, Funcs, func(ArgCount, LocalCount, ResultCount, Instrs)),
    length(Args, ArgCount),
    init_locals(Args, LocalCount, LocalsIn).

% Executes the instructions with an empty start stack
run_function(Instrs, Module, LocalsIn, Memory, StackOut, Signal, ContextIn, ContextOut) :-
    Stack0 = [], % each function has its own empty stack to work with because args and locals are not passed via stack
    exec_instructions(Instrs, Module, LocalsIn, _Locals, Stack0, StackOut, Memory, Signal, ContextIn, ContextOut).


% Processes the final signal of the execution
handle_function_signal(trap, _ResultCount, _Stack, [], trap).
handle_function_signal(invalid, _ResultCount, _Stack, [], invalid).

% continue => func is finished, so return
handle_function_signal(continue, ResultCount, Stack, Returns, finished) :-
    stack_has_n(Stack, ResultCount),
    take_n(ResultCount, Stack, Returns),
    !.

% not enough values on the stack => invalid
handle_function_signal(continue, _ResultCount, _Stack, [], invalid).

% returned => func is finished
handle_function_signal(returned, ResultCount, Stack, Returns, finished) :-
    stack_has_n(Stack, ResultCount),
    take_n(ResultCount, Stack, Returns),
    !.
handle_function_signal(returned, _ResultCount, _Stack, [], invalid).

stack_has_n(_Stack, 0) :- !.
stack_has_n([_|Rest], N) :-
    N > 0,
    N1 is N - 1,
    stack_has_n(Rest, N1).


% TODO this is never called for some reason
exec_instructions([], _Module, Locals, Locals, Stack, Stack, _Memory, continue, Context, Context). % no more instructions => result = continue

exec_instructions([Instr|Rest], Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut) :-
    exec_instruction(Instr, Module, LocalsIn, Locals1, StackIn, Stack1, Memory, StepSignal, ContextIn, ContextOutExecute),
    increment_instruction_counter(ContextOutExecute, IncrementedContext),
    continue_or_stop(StepSignal, Rest, Module, Locals1, LocalsOut, Stack1, StackOut, Memory, Signal, IncrementedContext, ContextOut).

increment_instruction_counter(analyse(MaxInstructions, CurrentCounter, Inputs), analyse(MaxInstructions, IncCurrentCounter, Inputs)) :-
    integer(CurrentCounter),
    IncCurrentCounter is CurrentCounter + 1.

increment_instruction_counter(analyse(MaxInstructions, CurrentCounter, Inputs, PathTrace), analyse(MaxInstructions, IncCurrentCounter, Inputs, PathTrace)) :-
    integer(CurrentCounter),
    IncCurrentCounter is CurrentCounter + 1.

% nothing to increment in case of run context
increment_instruction_counter(run, run).


record_branch_decision(analyse(MaxInstructions, Counter, Inputs, PathTraceIn), Decision, analyse(MaxInstructions, Counter, Inputs, [Decision|PathTraceIn])) :-
    !.
record_branch_decision(Context, _Decision, Context).



% if continue -> execute next instruction.
% TODO stop if we have more instructions than MaxInstructions.
continue_or_stop(continue, Rest, Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut) :-
    ( instruction_limit_reached(ContextIn) ->
        LocalsOut = LocalsIn,
        StackOut = StackIn,
        Signal = continue,
        ContextOut = ContextIn
        % we execute no more instructions here, so stop
    ;
        exec_instructions(Rest, Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut)
    ).

% stop if an instruction sees a step, return or branch. Then we stop the execution here and pass this signal up.
continue_or_stop(NotContinue, _Rest, _Module, Locals, Locals, Stack, Stack, _Memory, NotContinue, ContextIn, ContextOut) :-
    NotContinue \= continue,
    ContextOut = ContextIn.

instruction_limit_reached(analyse(MaxInstructions, CurrentCounter, _Inputs)) :-
    integer(MaxInstructions),
    integer(CurrentCounter),
    CurrentCounter >= MaxInstructions,
    !.

% duplicate
instruction_limit_reached(analyse(MaxInstructions, CurrentCounter, _Inputs, _PathTrace)) :-
    integer(MaxInstructions),
    integer(CurrentCounter),
    CurrentCounter >= MaxInstructions,
    !.

% needed for run context that have no limit
instruction_limit_reached(_Context) :-
    fail.


handle_block_signal(continue, Locals, Stack, Locals, Stack, continue).
handle_block_signal(returned, Locals, Stack, Locals, Stack, returned).
handle_block_signal(trap, Locals, Stack, Locals, Stack, trap).
handle_block_signal(invalid, Locals, Stack, Locals, Stack, invalid).
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
handle_loop_signal(invalid, _Instructions, _Module, Locals, Locals, Stack, Stack, _Memory, invalid, ContextIn, ContextOut) :-
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
    stack_has_n(StackIn, ArgCount),
    pop_n(ArgCount, StackIn, RawArgs, StackRest),
    reverse(RawArgs, Args),
    execute_function(Index, Args, Module, Memory, Returns, Status, ContextIn, ContextOut),
    prepare_to_return(Status, Returns, StackIn, StackRest, StackOut, Signal),
    !.

% check if call can be made, if not set status to invalid
call_internal(Index, Module, Stack, Stack, _Memory, invalid, Context, Context) :-
    Module = module(_Start, _Data, Funcs),
    ( 
        \+ nth0(Index, Funcs, _) %check if this index exists
    ;
        nth0(Index, Funcs, func(ArgCount, _Locals, _Results, _Instrs)),
        \+ stack_has_n(Stack, ArgCount)
    ).

call_internal(_Index, _Module, Stack, Stack, _Memory, invalid, Context, Context).

% trap => doesn't matter what we do, just return trap and keep stack
prepare_to_return(trap, _Returns, StackIn, _StackRest, StackIn, trap).
prepare_to_return(invalid, _Returns, StackIn, _StackRest, StackIn, invalid).

prepare_to_return(Status, Returns, _StackIn, StackRest, StackOut, continue) :-
    Status \= trap,
    append_rev(Returns, StackRest, StackOut).



% all different possible instructions that we must support:

exec_instruction(i32_const(X), _Module, Locals, Locals, Stack, [X|Stack], _Memory, continue, Context, Context).
exec_instruction(i32_add, _Module, Locals, Locals, StackIn, StackOut, _Memory, Signal, Context, Context) :-
    binary_op(StackIn, StackOut, +, Signal).
exec_instruction(i32_sub, _Module, Locals, Locals, StackIn, StackOut, _Memory, Signal, Context, Context) :-
    binary_op(StackIn, StackOut, -, Signal).
exec_instruction(i32_mul, _Module, Locals, Locals, StackIn, StackOut, _Memory, Signal, Context, Context) :-
    binary_op(StackIn, StackOut, *, Signal).

% division by zero trap (stack at least 2 values: 0 and A)
exec_instruction(i32_div_s, _Module, Locals, Locals, [0, A|Rest], [0, A|Rest], _Memory, trap, Context, Context).

% normal division
exec_instruction(i32_div_s, _Module, Locals, Locals, [B, A|Rest], [Q|Rest], _Memory, continue, Context, Context) :-
    B =\= 0, % should normally not occur with predicate above
    Q is A // B,
    !.

% case that stack has fewer than 2 values => trap
exec_instruction(i32_div_s, _Module, Locals, Locals, Stack, Stack, _Memory, invalid, Context, Context).


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

% i32_eqz is unary: pop 1 value, push 1 or 0
exec_instruction(i32_eqz, _Module, Locals, Locals, [A|Rest], [R|Rest], _Memory, continue, Context, Context) :-
    number(A),
    ( A =:= 0 -> R = 1 ; R = 0 ),
    !.
exec_instruction(i32_eqz, _Module, Locals, Locals, [], [], _Memory, invalid, Context, Context).
exec_instruction(i32_eqz, _Module, Locals, Locals, [A|Rest], [A|Rest], _Memory, invalid, Context, Context) :-
    \+ number(A).


exec_instruction(drop, _Module, Locals, Locals, [_|Rest], Rest, _Memory, continue, Context, Context) :-
    !.
exec_instruction(drop, _Module, Locals, Locals, [], [], _Memory, invalid, Context, Context).

exec_instruction(nop, _Module, Locals, Locals, Stack, Stack, _Memory, continue, Context, Context).

exec_instruction(unreachable, _Module, Locals, Locals, Stack, Stack, _Memory, trap, Context, Context) :-
    Context = analyse(_, _, _, _), !.

exec_instruction(unreachable, _Module, Locals, Locals, Stack, Stack, _Memory, trap, Context, Context).


exec_instruction(local_get(N), _Module, Locals, Locals, Stack, [Value|Stack], _Memory, continue, Context, Context) :-
    nth0(N, Locals, Value), !.
% no n'th local found => trap
exec_instruction(local_get(_N), _Module, Locals, Locals, Stack, Stack, _Memory, invalid, Context, Context).


exec_instruction(local_set(N), _Module, LocalsIn, LocalsOut, [Value|Stack], Stack, _Memory, continue, Context, Context) :-
    set_nth0(LocalsIn, N, Value, LocalsOut), !.
exec_instruction(local_set(_N), _Module, Locals, Locals, Stack, Stack, _Memory, invalid, Context, Context).


%same as local_set but with unmodified stack
exec_instruction(local_tee(N), _Module, LocalsIn, LocalsOut, [Value|Stack], [Value|Stack], _Memory, continue, Context, Context) :- % exec_instruction(local_tee(N), _Module, LocalsIn, LocalsOut, [Value|Stack], [Value|Stack], _Memory, continue) :- exec_instruction(local_set(N), _Module, LocalsIn, LocalsOut, [Value, Value|Stack], Stack, _Memory, continue).
    set_nth0(LocalsIn, N, Value, LocalsOut), !.

exec_instruction(local_tee(_N), _Module, Locals, Locals, Stack, Stack, _Memory, invalid, Context, Context).


% internal function call (via index)
exec_instruction(call(Target), Module, Locals, Locals, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut) :-
    integer(Target), !, % check if it is integer => internal function call
    call_internal(Target, Module, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut).

% primitive function call (via name: print, read_int...)
exec_instruction(call(Target), _Module, Locals, Locals, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut) :-
    atom(Target), !, % check if atom (print...) for 'built-in' function call
    call_primitive(Target, StackIn, Memory, StackOut, Signal, ContextIn, ContextOut).

% invalid target → trap
exec_instruction(call(_Target), _Module, Locals, Locals, Stack, Stack, _Memory, invalid, Context, Context).

exec_instruction(return, _Module, Locals, Locals, Stack, Stack, _Memory, returned, Context, Context).

% we go into a block, so we must process the signal separately => break 1 then gives break 0 back etc
exec_instruction(block(Instructions), Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut) :-
    exec_instructions(Instructions, Module, LocalsIn, Locals1, StackIn, Stack1, Memory, InnerSignal, ContextIn, ContextOut),
    handle_block_signal(InnerSignal, Locals1, Stack1, LocalsOut, StackOut, Signal).


exec_instruction(br(Value), _Module, Locals, Locals, Stack, Stack, _Memory, break(Value), Context, Context) :-
    integer(Value),
    Value >= 0,
    !.

exec_instruction(br(_Value), _Module, Locals, Locals, Stack, Stack, _Memory, invalid, Context, Context).


% Condition is false (0) => execute FalseBlock
exec_instruction(if(_TrueBlock, FalseBlock), Module, LocalsIn, LocalsOut, [0|StackIn], StackOut, Memory, Signal, ContextIn, ContextOut) :-
    record_branch_decision(ContextIn, if_false, ContextWithDecision),
    exec_instructions(FalseBlock, Module, LocalsIn, Locals1, StackIn, Stack1, Memory, InnerSignal, ContextWithDecision, ContextOut),
    handle_block_signal(InnerSignal, Locals1, Stack1, LocalsOut, StackOut, Signal).

% Condition is true (not 0) => execute TrueBlock
exec_instruction(if(TrueBlock, _FalseBlock), Module, LocalsIn, LocalsOut, [Cond|StackIn], StackOut, Memory, Signal, ContextIn, ContextOut) :-
    number(Cond),
    Cond =\= 0,
    record_branch_decision(ContextIn, if_true, ContextWithDecision),
    exec_instructions(TrueBlock, Module, LocalsIn, Locals1, StackIn, Stack1, Memory, InnerSignal, ContextWithDecision, ContextOut),
    handle_block_signal(InnerSignal, Locals1, Stack1, LocalsOut, StackOut, Signal).


% Empty stack => trap
exec_instruction(if(_TrueBlock, _FalseBlock), _Module, Locals, Locals, [], [], _Memory, invalid, Context, Context).
exec_instruction(if(_TrueBlock, _FalseBlock), _Module, Locals, Locals, [Cond|Stack], [Cond|Stack], _Memory, invalid, Context, Context) :-
    \+ number(Cond).


exec_instruction(br_if(Value), _Module, Locals, Locals, [Cond|Stack], Stack, _Memory, break(Value), ContextIn, ContextOut) :-
    integer(Value),
    Value >= 0,
    Cond =\= 0,
    record_branch_decision(ContextIn, br_if_true(Value), ContextOut).

% condition is false (0) => continue
exec_instruction(br_if(Value), _Module, Locals, Locals, [0|Stack], Stack, _Memory, continue, ContextIn, ContextOut) :-
    integer(Value),
    Value >= 0,
    record_branch_decision(ContextIn, br_if_false(Value), ContextOut).

% invalid value => trap
exec_instruction(br_if(Value), _Module, Locals, Locals, [Cond|Stack], [Cond|Stack], _Memory, invalid, Context, Context) :-
    ( \+ integer(Value)
    ; Value < 0
    ; \+ number(Cond)
    ).
exec_instruction(br_if(_Value), _Module, Locals, Locals, [], [], _Memory, invalid, Context, Context).


exec_instruction(loop(Instructions), Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut) :-
    run_loop(Instructions, Module, LocalsIn, LocalsOut, StackIn, StackOut, Memory, Signal, ContextIn, ContextOut).


% normally not occurring because parser should already fail, but for safety
exec_instruction(Unsupported, _Module, Locals, Locals, Stack, Stack, _Memory, invalid, Context, Context) :-
    \+ supported_instruction(Unsupported).

supported_instruction(i32_const(_)).
supported_instruction(i32_add).
supported_instruction(i32_sub).
supported_instruction(i32_mul).
supported_instruction(i32_div_s).
supported_instruction(i32_lt_s).
supported_instruction(i32_le_s).
supported_instruction(i32_gt_s).
supported_instruction(i32_ge_s).
supported_instruction(i32_eqz).
supported_instruction(i32_eq).
supported_instruction(i32_ne).
supported_instruction(i32_and).
supported_instruction(i32_or).
supported_instruction(i32_xor).
supported_instruction(drop).
supported_instruction(nop).
supported_instruction(unreachable).
supported_instruction(local_get(_)).
supported_instruction(local_set(_)).
supported_instruction(local_tee(_)).
supported_instruction(call(_)).
supported_instruction(return).
supported_instruction(block(_)).
supported_instruction(loop(_)).
supported_instruction(if(_, _)).
supported_instruction(br(_)).
supported_instruction(br_if(_)).



