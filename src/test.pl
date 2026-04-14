#!/usr/bin/env swipl
apen(nathan).
apen(renaud).
apen(flo).

main :-
    findall(X, apen(X), AllApes), 
    writeln(AllApes).

:- initialization(main, main).