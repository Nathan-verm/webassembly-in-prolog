In deze directory zullen we enkele voorbeeld programma's plaatsen.

# `hoger_lager.pwat`
Een hoger/lager applicatie waar je een willekeurig getal moet raden.

Voorbeeld output:
```
swipl src/main.pl run hoger_lager.pwat
Geef een getal in:
|: 50.
hoger
|: 75.
lager
|: 62.
lager
|: 55.
correct
```

# `test*.pwat`
## `test1a.pwat`
Voorbeeld output paths:
```
swipl src/main.pl paths "examples/test1a.pwat"
Inputs: [0], State: finished
Inputs: [10], State: finished
```
Voorbeeld output analyse:
```
swipl src/main.pl analyse "examples/test1a.pwat"
```

## `test1b.pwat`
Voorbeeld output paths:
```
swipl src/main.pl paths "examples/test1b.pwat"
Inputs: [0], State: finished
Inputs: [10], State: trap
```
Voorbeeld output analyse:
```
swipl src/main.pl analyse "examples/test1b.pwat"
Inputs: [10], State: trap
```

## `test2a.pwat`
Voorbeeld output paths:
```
swipl src/main.pl paths "examples/test2a.pwat"
Inputs: [0,0], State: finished
Inputs: [10,0], State: finished
Inputs: [0,10], State: finished
Inputs: [10,10], State: finished
```
