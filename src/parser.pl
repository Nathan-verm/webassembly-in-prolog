:- module(parser, [parse/2]).

:- use_module(library(readutil)).

:- discontiguous parser:instruction/3.




% Entry point
parse(File, Module) :-
    read_file_to_string(File, String, []),
    string_codes(String, Codes), % convert naar een lijst van ascii chars
    once(phrase(module(Module), Codes)).


% Whitespace includes comments
ws --> space, ws.
ws --> comment, ws.
ws --> [].

space --> [C], { char_type(C, space) }.

comment --> ";;", comment_chars.
comment_chars --> [C], { C \= 10 }, comment_chars.
comment_chars --> [].


% Module

% Start => integer dat zegt welke functie eerst opgeroepen moet worden
% Data is een lijst van data(Address, str) waarbij str de rauwe strings zijn "\12\44\222" etc
% Funcs zijn een lijst van functies
module(module(Start, Data, Funcs)) -->
    ws, "(", "module", ws,
    start(Start),
    data_segments(Data),
    functions(Funcs),
    ws, ")", ws.

start(N) --> "(", "start", ws, integer(N), ")", ws.


% Data segments

data_segments([D|T]) --> data_segment(D), data_segments(T).
data_segments([]) --> [].

data_segment(data(Address, Str)) -->
    "(", "data", ws, integer(Address), ws, string_literal(Str), ")", ws.


% Functions

functions([F|T]) --> function(F), functions(T).
functions([]) --> [].

% aantal args, aantal locals, aantal resultaten, en lijst van instructies in die functie
function(func(Args, Locals, Results, Instrs)) -->
    "(", "func", ws,
    args(Args),
    locals(Locals),
    results(Results),
    instructions(Instrs),
    ")", ws.

args(N) --> "(", "args", ws, integer(N), ")", ws.
locals(N) --> "(", "locals", ws, integer(N), ")", ws.
results(N) --> "(", "results", ws, integer(N), ")", ws.


% Instructions

instructions([I|T]) --> instruction(I), instructions(T).
instructions([]) --> [].

% Numeric instructions
instruction(i32_const(X)) --> "i32.const", ws, integer(X), ws.
instruction(i32_add) --> "i32.add", ws.
instruction(i32_sub) --> "i32.sub", ws.
instruction(i32_mul) --> "i32.mul", ws.
instruction(i32_div_s) --> "i32.div_s", ws.
instruction(i32_lt_s) --> "i32.lt_s", ws.
instruction(i32_le_s) --> "i32.le_s", ws.
instruction(i32_gt_s) --> "i32.gt_s", ws.
instruction(i32_ge_s) --> "i32.ge_s", ws.
instruction(i32_eqz) --> "i32.eqz", ws.
instruction(i32_eq) --> "i32.eq", ws.
instruction(i32_ne) --> "i32.ne", ws.
instruction(i32_and) --> "i32.and", ws.
instruction(i32_or) --> "i32.or", ws.
instruction(i32_xor) --> "i32.xor", ws.

% Locals
instruction(local_get(N)) --> "local.get", ws, integer(N), ws.
instruction(local_set(N)) --> "local.set", ws, integer(N), ws.
instruction(local_tee(N)) --> "local.tee", ws, integer(N), ws.

% Calls
instruction(call(X)) --> "call", ws, (integer(X) ; primitive(X)), ws.
primitive(read_int) --> "read_int".
primitive(rand_int) --> "rand_int".
primitive(print_int) --> "print_int".
primitive(print) --> "print".
primitive(println) --> "println".

% Control / blocks
instruction(block(Instrs)) --> "block", ws, block_instructions(Instrs), "end", ws.
instruction(loop(Instrs)) --> "loop", ws, block_instructions(Instrs), "end", ws.
instruction(if(TrueBlock, FalseBlock)) -->
    "if", ws, block_instructions(TrueBlock),
    ( "else", ws, block_instructions(FalseBlock) ; { FalseBlock = [] } ), % de ; operator is de of operator, we testen dus op een else tak, als die er niet is dan zeggen we gewoon lege else
    "end", ws.

% Nested blocks
block_instructions([I|T]) --> instruction(I), block_instructions(T).
block_instructions([]) --> [].

% Branching
instruction(br(N)) --> "br", ws, integer(N), ws.
instruction(br_if(N)) --> "br_if", ws, integer(N), ws.
instruction(return) --> "return", ws.

% Misc
instruction(drop) --> "drop", ws.
instruction(nop) --> "nop", ws.
instruction(unreachable) --> "unreachable", ws.


% Integers (including negative numbers)

integer(N) --> optional_sign(Sign), digits(Ds), { append(Sign, Ds, AllCodes), number_codes(N, AllCodes) }.

optional_sign([45]) --> [45], !.  % 45 is ASCII voor '-'
optional_sign([]) --> [].

% minstens 1 digit
digits([D|T]) --> [D], { char_type(D,digit) }, digits_rest(T). % {} voert gewoon prolog code uit maar consumed geen chars
% nul of meer digits nadien
digits_rest([D|T]) --> [D], { char_type(D,digit) }, digits_rest(T).
digits_rest([]) --> [].


% Strings

% Bewaar de inhoud tussen quotes letterlijk als string, zonder escape-conversie.
string_literal(Str) -->
    [34], % is ascii voor "
    raw_string_codes(Codes),
    [34],
    { string_codes(Str, Codes) }.

raw_string_codes([C|T]) --> [C], { C =\= 34 }, raw_string_codes(T).
raw_string_codes([]) --> [].