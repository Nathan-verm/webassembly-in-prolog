:- module(runner, [run_file/2, run_module/2]).

:- use_module(parser).
:- use_module(memory_initializer).
:- use_module(function_runner).


run_file(File, Result) :-
    parse(File, Module),
    writeln(Module),
    run_module(Module, Result).


run_module(Module, result(Status, Returns)) :-
    Module = module(Start, DataSegments, _Funcs),
    build_memory(DataSegments, Memory),
    execute_function(Start, [], Module, Memory, Returns, Status).



