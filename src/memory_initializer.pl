:- module(memory_initializer, [build_memory/2]).

% Memory => [adress(StartAddress, String)]

build_memory([], []).
build_memory(DataSegments, Memory) :-
    build_memory_helper(DataSegments, [], Segments),
    sort(Segments, Memory).

build_memory_helper([], Acc, Acc).
build_memory_helper([data(Address, RawStr)|Rest], Acc, Memory) :-
    string_chars(RawStr, Chars), % => string_chars("abc", [97, 98, 99])
    extract_codes(Chars, Codes),
    string_codes(DecodedStr, Codes),
    build_memory_helper(Rest, [adress(Address, DecodedStr)|Acc], Memory).


extract_codes([], []).

% match on backslash
extract_codes(['\\'|Rest], [Code|Codes]) :-
    take_digit_chars(Rest, DigitChars, Tail),
    number_chars(Code, DigitChars),
    extract_codes(Tail, Codes).

% no match on backslash
extract_codes([C|Rest], [Code|Codes]) :-
    C \= '\\',
    char_code(C, Code),
    extract_codes(Rest, Codes).


take_digit_chars([C|Rest], [C|Digits], Tail) :- % take_digit_chars(['1', '2', '3', '\\'], ['1', '2', '3'], ['\\'])
    char_type(C, digit),
    !,
    take_digit_chars(Rest, Digits, Tail).
take_digit_chars(Rest, [], Rest).