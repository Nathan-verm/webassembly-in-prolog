:- begin_tests(parser).

:- use_module('../src/parser').

test(simple_module) :-
    parse('../examples/test1.pwat', Module),
    assertion(Module == module(0, [], [func(0,0,0,[])])).


test(simple_add) :-
    parse('../examples/test2.pwat', Module),
    assertion(Module ==
        module(0, [], [
            func(0,0,0,[i32_const(3), i32_const(5), i32_add])
        ])
    ).


test(local_get) :-
    parse('../examples/test3.pwat', Module),
    assertion(Module ==
        module(0, [], [
            func(1,0,0,[local_get(0)])
        ])
    ).


test(multiple_functions) :-
    parse('../examples/test4.pwat', Module),
    assertion(Module ==
        module(1, [], [
            func(2,0,1,[local_get(0),local_get(1),i32_add]),
            func(0,0,0,[i32_const(10)])
        ])
    ).

:- end_tests(parser).