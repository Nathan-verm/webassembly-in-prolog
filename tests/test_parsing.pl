:- begin_tests(parser).

:- use_module('../src/parser').

test(parse_block_with_data_and_br) :-
    parse('../examples/test_block.pwat', Module),
    assertion(Module ==
        module(0,
            [data(0, "\\97"), data(1, "\\97\\98")],
            [func(0,0,1,[
                block([
                    i32_const(10),
                    br(0),
                    i32_const(20),
                    i32_add
                ])
            ])]
        )
    ).


test(parse_return_program) :-
    parse('../examples/test_return.pwat', Module),
    assertion(Module ==
        module(0, [], [
            func(0,0,5,[
                i32_const(10),
                i32_const(20),
                i32_const(30),
                i32_const(40),
                i32_const(50),
                return,
                i32_const(999)
            ])
        ])
    ).


test(parse_if_with_br_if_in_block) :-
    parse('../examples/test_if_br.pwat', module(Start, Data, [Func])),
    assertion(Start == 0),
    assertion(Data == [data(0, "\\97"), data(1, "\\97\\98")]),
    assertion(Func = func(0,1,1,Instrs)),
    assertion(member(block([i32_const(10), local_set(0), br_if(0), i32_const(20), local_set(0)]), Instrs)),
    assertion(member(local_get(0), Instrs)).


test(parse_loop_with_nested_br_if) :-
    parse('../examples/test_loop.pwat', module(0, _Data, [func(0,1,1,Instrs)])),
    assertion(member(local_set(0), Instrs)),
    assertion(member(loop(LoopInstrs), Instrs)),
    assertion(member(br_if(0), LoopInstrs)),
    assertion(member(i32_lt_s, LoopInstrs)).

:- end_tests(parser).