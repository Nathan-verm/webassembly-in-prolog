:- use_module(parser).

main :-
    current_prolog_flag(argv, Argv),
    run(Argv).

run([File|_]) :-
    parse(File, Module),
    writeln("Parsed module:"),
    portray_clause(Module).

run([]) :-
    writeln("Usage: swipl main.pl <file.pwat>"),
    halt(1).

:- initialization(main, main).