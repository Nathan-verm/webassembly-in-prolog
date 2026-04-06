:- module(memory_initializer, [build_memory/2, memory_slice/4]).

build_memory([], []).
build_memory(DataSegments, Memory) :-
    build_memory_helper(DataSegments, [], Pairs),
    sort(Pairs, Memory).

build_memory_heper([], Acc, Acc).
build_memory_helper([data(Address, Str)|Rest], Acc, Memory) :-
    string_codes(Str, Codes),
    place_codes(Address, Codes, Acc, Acc1),
    build_memory_helper(Rest, Acc1, Memory).

place_codes(_Address, [], Acc, Acc).
place_codes(Address, [C|T], Acc, Out) :-
    Address1 is Address + 1,
    place_codes(Address1, T, [byte(Address, C)|Acc], Out).

memory_slice(_Memory, _Address, Length, []) :-
    Length =< 0,
    !.
memory_slice(Memory, Address, Length, [C|T]) :-
    Length > 0,
    ( member(byte(Address, C0), Memory) -> C = C0 ; C = 0 ),
    Address1 is Address + 1,
    Length1 is Length - 1,
    memory_slice(Memory, Address1, Length1, T).
