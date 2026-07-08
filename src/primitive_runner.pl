:- module(primitive_runner, [call_primitive/7]).

:- use_module(library(readutil)).
:- use_module(library(random)).
:- use_module(memory_initializer).
:- use_module(utilities).



call_primitive(Name, StackIn, Memory, StackOut, Signal, ContextIn, ContextOut) :-
    primitive_arity(Name, Arity),
    stack_has_n(StackIn, Arity),
    pop_n(Arity, StackIn, RawArgs, StackRest),
    reverse(RawArgs, Args),
    run_primitive(Name, Args, Memory, PrimitiveReturns, PrimitiveStatus, ContextIn, ContextOut),
    handle_primitive_result(PrimitiveStatus, PrimitiveReturns, StackIn, StackRest, StackOut, Signal).

call_primitive(Name, Stack, _Memory, Stack, invalid, Context, Context) :-
    primitive_arity(Name, Arity),
    \+ stack_has_n(Stack, Arity).

call_primitive(Name, Stack, _Memory, Stack, invalid, Context, Context) :-
    \+ primitive_arity(Name, _).

% if trap has been made
handle_primitive_result(trap, _Returns, StackIn, _StackRest, StackIn, trap).
handle_primitive_result(invalid, _Returns, StackIn, _StackRest, StackIn, invalid).

% if success => continue
handle_primitive_result(continue, Returns, _StackIn, StackRest, StackOut, continue) :-
    append_rev(Returns, StackRest, StackOut).

stack_has_n(_Stack, 0) :- !.
stack_has_n([_|Rest], N) :-
    N > 0,
    N1 is N - 1,
    stack_has_n(Rest, N1).

primitive_arity(read_int, 2).
primitive_arity(rand_int, 2).
primitive_arity(print_int, 1).
primitive_arity(print, 2).
primitive_arity(println, 2).

% run_primitive(InstructionName, ArgsList, Memory, ReturnList, Status) status => finished, continue, trap

% if context is run => just print
run_primitive(print, [Address, Length], Memory, [], continue, run, run) :-
    memory_slice(Memory, Address, Length, Codes),
    format('~s', [Codes]), !.

% if context is analyse => don't print
run_primitive(print, [_Address, _Length], _Memory, [], continue, analyse(_, _, _, _), _).

run_primitive(println, Args, Memory, [], continue, run, run) :-
    run_primitive(print, Args, Memory, [], continue, run, run),
    writeln(""), !.

run_primitive(println, [_Address, _Length], _Memory, [], continue, analyse(_, _, _, _), _).


run_primitive(print_int, [Value], _Memory, [], continue, run, run) :-
    writeln(Value), !.


run_primitive(print_int, _, _Memory, [], continue, analyse(_, _, _, _), analyse(_, _, _, _)).



run_primitive(read_int, [Min, Max], _Memory, [Value], continue, run, run) :-
    read_int_between(Min, Max, Value), !.

% here is the clue of the analyse function
run_primitive(read_int, [Min, Max], _Memory, [Value], continue, analyse(MaxInstructionsIn, CounterIn, InputsIn, PathTrace), analyse(MaxInstructionsIn, CounterIn, InputsOut, PathTrace)) :-
    Lower is Min + 1,
    Upper is Max - 1,
    Lower =< Upper,
    between(Lower, Upper, Value),
    InputsOut = [Value|InputsIn].

run_primitive(rand_int, [Min, Max], _Memory, [Value], continue, Context, Context) :-
    MaxMinOne is Max - 1,
    random_between(Min, MaxMinOne, Value), 
    !.

% should not be possible because parser should already fail but just in case
run_primitive(Name, _Args, _Memory, [], invalid, Context, Context) :-
    \+ primitive_arity(Name, _).


read_int_between(Min, Max, Value) :-
    repeat,
    read_line_to_string(user_input, Line),
    catch(number_string(N, Line), _, fail),
    N > Min,
    N < Max,
    Value = N,
    !.


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