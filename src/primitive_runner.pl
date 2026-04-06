:- module(primitive_runner, [call_primitive/5]).

:- use_module(library(readutil)).
:- use_module(library(random)).
:- use_module(memory_initializer).


call_primitive(Name, StackIn, Memory, StackOut, Signal) :-
    primitive_arity(Name, Arity),
    pop_n(Arity, StackIn, RawArgs, StackRest),
    reverse(RawArgs, Args),
    run_primitive(Name, Args, Memory, PrimitiveReturns, PrimitiveStatus),
    ( PrimitiveStatus = trap ->
        Signal = trap,
        StackOut = StackIn
    ; append_rev(PrimitiveReturns, StackRest, StackOut),
      Signal = continue
    ), !.
call_primitive(_Name, Stack, _Memory, Stack, trap).

primitive_arity(read_int, 2).
primitive_arity(rand_int, 2).
primitive_arity(print_int, 1).
primitive_arity(print, 2).
primitive_arity(println, 2).

run_primitive(read_int, [Min, Max], _Memory, [Value], finished) :-
    read_int_between(Min, Max, Value).
run_primitive(rand_int, [Min, Max], _Memory, [Value], finished) :-
    Low is Min + 1,
    High is Max - 1,
    ( Low =< High ->
        random_between(Low, High, Value)
    ; Value = Min
    ).

run_primitive(print_int, [Value], _Memory, [], finished) :-
    writeln(Value).
run_primitive(print, [Address, Length], Memory, [], finished) :-
    memory_slice(Memory, Address, Length, Codes),
    format('~s', [Codes]).
run_primitive(println, [Address, Length], Memory, [], finished) :-
    memory_slice(Memory, Address, Length, Codes),
    format('~s~n', [Codes]).
run_primitive(_Name, _Args, _Memory, [], trap).

read_int_between(Min, Max, Value) :-
    writeln('Geef een getal in:'),
    repeat,
    read_line_to_string(user_input, Line),
    catch(number_string(N, Line), _, fail),
    N > Min,
    N < Max,
    Value = N,
    !.

pop_n(0, Stack, [], Stack) :- !.
pop_n(N, [H|T], [H|Rest], StackRest) :-
    N > 0,
    N1 is N - 1,
    pop_n(N1, T, Rest, StackRest).

append_rev([], Tail, Tail).
append_rev([H|T], Tail, Out) :-
    append_rev(T, Tail, Out1),
    Out = [H|Out1].
