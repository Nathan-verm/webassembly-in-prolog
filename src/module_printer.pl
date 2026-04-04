:- module(module_printer, [print_module/1, print_module/2]).

print_module(Module) :-
    print_module(current_output, Module).

print_module(Stream, module(Start, DataSegments, Functions)) :-
    format(Stream, '(module~n', []),
    format(Stream, '  (start ~w)~n', [Start]),
    print_data_segments(Stream, DataSegments),
    print_functions(Stream, Functions),
    format(Stream, ')~n', []).

print_data_segments(_Stream, []).
print_data_segments(Stream, [data(Address, Str)|Rest]) :-
    format(Stream, '  (data ~w "~s")~n', [Address, Str]),
    print_data_segments(Stream, Rest).

print_functions(_Stream, []).
print_functions(Stream, [Func|Rest]) :-
    print_function(Stream, Func),
    print_functions(Stream, Rest).

print_function(Stream, func(Args, Locals, Results, Instrs)) :-
    format(Stream, '  (func (args ~w) (locals ~w) (results ~w)~n', [Args, Locals, Results]),
    print_instructions(Stream, 4, Instrs),
    format(Stream, '  )~n', []).

print_instructions(_Stream, _Indent, []).
print_instructions(Stream, Indent, [Instr|Rest]) :-
    print_instruction(Stream, Indent, Instr),
    print_instructions(Stream, Indent, Rest).

print_instruction(Stream, Indent, i32_const(X)) :-
    indent(Stream, Indent),
    format(Stream, 'i32.const ~w~n', [X]).
print_instruction(Stream, Indent, local_get(N)) :-
    indent(Stream, Indent),
    format(Stream, 'local.get ~w~n', [N]).
print_instruction(Stream, Indent, local_set(N)) :-
    indent(Stream, Indent),
    format(Stream, 'local.set ~w~n', [N]).
print_instruction(Stream, Indent, local_tee(N)) :-
    indent(Stream, Indent),
    format(Stream, 'local.tee ~w~n', [N]).
print_instruction(Stream, Indent, call(Target)) :-
    indent(Stream, Indent),
    format(Stream, 'call ~w~n', [Target]).
print_instruction(Stream, Indent, br(N)) :-
    indent(Stream, Indent),
    format(Stream, 'br ~w~n', [N]).
print_instruction(Stream, Indent, br_if(N)) :-
    indent(Stream, Indent),
    format(Stream, 'br_if ~w~n', [N]).
print_instruction(Stream, Indent, block(Instrs)) :-
    indent(Stream, Indent),
    format(Stream, 'block~n', []),
    NextIndent is Indent + 2,
    print_instructions(Stream, NextIndent, Instrs),
    indent(Stream, Indent),
    format(Stream, 'end~n', []).
print_instruction(Stream, Indent, loop(Instrs)) :-
    indent(Stream, Indent),
    format(Stream, 'loop~n', []),
    NextIndent is Indent + 2,
    print_instructions(Stream, NextIndent, Instrs),
    indent(Stream, Indent),
    format(Stream, 'end~n', []).
print_instruction(Stream, Indent, if(TrueInstrs, FalseInstrs)) :-
    indent(Stream, Indent),
    format(Stream, 'if~n', []),
    NextIndent is Indent + 2,
    print_instructions(Stream, NextIndent, TrueInstrs),
    ( FalseInstrs = [] -> true
    ; indent(Stream, Indent),
      format(Stream, 'else~n', []),
      print_instructions(Stream, NextIndent, FalseInstrs)
    ),
    indent(Stream, Indent),
    format(Stream, 'end~n', []).
print_instruction(Stream, Indent, Instr) :-
    simple_instruction_name(Instr, Name),
    indent(Stream, Indent),
    format(Stream, '~w~n', [Name]).

simple_instruction_name(i32_add, 'i32.add').
simple_instruction_name(i32_sub, 'i32.sub').
simple_instruction_name(i32_mul, 'i32.mul').
simple_instruction_name(i32_div_s, 'i32.div_s').
simple_instruction_name(i32_lt_s, 'i32.lt_s').
simple_instruction_name(i32_le_s, 'i32.le_s').
simple_instruction_name(i32_gt_s, 'i32.gt_s').
simple_instruction_name(i32_ge_s, 'i32.ge_s').
simple_instruction_name(i32_eqz, 'i32.eqz').
simple_instruction_name(i32_eq, 'i32.eq').
simple_instruction_name(i32_ne, 'i32.ne').
simple_instruction_name(i32_and, 'i32.and').
simple_instruction_name(i32_or, 'i32.or').
simple_instruction_name(i32_xor, 'i32.xor').
simple_instruction_name(drop, 'drop').
simple_instruction_name(nop, 'nop').
simple_instruction_name(unreachable, 'unreachable').
simple_instruction_name(return, 'return').

indent(Stream, N) :-
    N > 0,
    !,
    format(Stream, '~*c', [N, 32]).
indent(_Stream, _N).
