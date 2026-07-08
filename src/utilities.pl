:- module(utilities, [set_nth0/4, pop_n/4, append_rev/3, take_n/3, binary_op/4, eval_binop/4, zeros/2, init_locals/3]).

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

zeros(0, []) :- !.
zeros(N, [0|T]) :-
    N > 0,
    N1 is N - 1,
    zeros(N1, T).

% set locals to 0
init_locals(Args, LocalCount, Locals) :-
    zeros(LocalCount, ZeroLocals),
    append(Args, ZeroLocals, Locals).


binary_op([B, A|Rest], [R|Rest], Op, continue) :-
    eval_binop(Op, A, B, R), !.

binary_op(Stack, Stack, _Op, invalid). % stack too small => invalid program

eval_binop(+, A, B, R) :- R is A + B.
eval_binop(-, A, B, R) :- R is A - B.
eval_binop(*, A, B, R) :- R is A * B.
eval_binop(lt_s,  A, B, R) :- ( A  <  B -> R = 1 ; R = 0 ).
eval_binop(le_s,  A, B, R) :- ( A  =< B -> R = 1 ; R = 0 ).
eval_binop(gt_s,  A, B, R) :- ( A  >  B -> R = 1 ; R = 0 ).
eval_binop(ge_s,  A, B, R) :- ( A  >= B -> R = 1 ; R = 0 ).
eval_binop(eq,    A, B, R) :- ( A =:= B -> R = 1 ; R = 0 ).
eval_binop(ne,    A, B, R) :- ( A =\= B -> R = 1 ; R = 0 ).
eval_binop(i32_and, A, B, R) :- R is A /\ B.
eval_binop(i32_or,  A, B, R) :- R is A \/ B.
eval_binop(i32_xor, A, B, R) :- R is A xor B.
