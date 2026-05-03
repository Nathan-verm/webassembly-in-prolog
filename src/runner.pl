:- module(runner, [run_file/2, run_module/2, analyse_file/4]).

:- use_module(parser).
:- use_module(memory_initializer).
:- use_module(function_runner).


run_file(File, Result) :-
    parse(File, Module),
    run_module(Module, Result).

run_module(Module, result(Status, Returns)) :-
    Module = module(Start, DataSegments, _Funcs),
    build_memory(DataSegments, Memory),
    execute_function(Start, [], Module, Memory, Returns, Status, run, run).


analyse_file(File, ContextIn, ContextOut, Result) :-
    once(parse(File, Module)),
    analyse_module(Module, ContextIn, ContextOut, Result).

analyse_module(Module, ContextIn, ContextOut, result(Status, Returns)) :-
    Module = module(Start, DataSegments, _Funcs),
    build_memory(DataSegments, Memory),
    execute_function(Start, [], Module, Memory, Returns, Status, ContextIn, ContextOut).





