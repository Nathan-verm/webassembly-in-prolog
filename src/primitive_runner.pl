:- module(primitive_runner, [call_primitive/5]).

:- use_module(library(readutil)).
:- use_module(library(random)).
:- use_module(memory_initializer).



call_primitive(Name, StackIn, Memory, StackOut, Signal) :-
    primitive_arity(Name, Arity),
    pop_n(Arity, StackIn, RawArgs, StackRest),
    reverse(RawArgs, Args),
    run_primitive(Name, Args, Memory, PrimitiveReturns, PrimitiveStatus),
    handle_primitive_result(PrimitiveStatus, PrimitiveReturns, StackIn, StackRest, StackOut, Signal),
    !.

call_primitive(_Name, Stack, _Memory, Stack, trap).

% if trap has been made
handle_primitive_result(trap, _Returns, StackIn, _StackRest, StackIn, trap).

% if succes => continue
handle_primitive_result(continue, Returns, _StackIn, StackRest, StackOut, continue) :-
    append_rev(Returns, StackRest, StackOut).

primitive_arity(read_int, 2).
primitive_arity(rand_int, 2).
primitive_arity(print_int, 1).
primitive_arity(print, 2).
primitive_arity(println, 2).

% run_primitive(InstructionName, ArgsList, Memory, ReturnList, Status) status => finished, continue, trap

run_primitive(print, [Address, Length], Memory, [], continue) :-
    memory_slice(Memory, Address, Length, Codes),
    format('~s', [Codes]).

run_primitive(println, Args, Memory, [], continue) :-
    run_primitive(print, Args, Memory, [], continue),
    writeln("").

run_primitive(print_int, [Value], _Memory, [], continue) :-
    writeln(Value).

run_primitive(read_int, [Min, Max], _Memory, [Value], continue) :-
    read_int_between(Min, Max, Value).

run_primitive(rand_int, [Min, Max], _Memory, [Value], continue) :-
    MaxMinOne is Max - 1,
    random_between(Min, MaxMinOne, Value).

% should not be possible because parser should already fail but just in case
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


memory_slice(_Memory, _Address, Length, []) :-
    Length =< 0,
    !.
memory_slice(Memory, Address, Length, [C|T]) :-
    Length > 0,
    ( code_at_address(Memory, Address, C0) -> C = C0 ; C = 0 ),
    Address1 is Address + 1,
    Length1 is Length - 1,
    memory_slice(Memory, Address1, Length1, T).



code_at_address(Memory, Address, Code) :-
    member(adress(Start, Str), Memory),
    string_codes(Str, Codes),
    Offset is Address - Start,
    Offset >= 0,
    nth0(Offset, Codes, Code),
    !.