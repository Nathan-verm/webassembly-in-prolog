# Opgave Project Logisch programmeren
In dit project zal je een analyse tool moeten schrijven die fouten kan opsporen in (vereenvoudigde) WebAssembly programma's. Hiervoor zullen jullie een eenvoudige WebAssembly interpreter moeten implementeren in Prolog.

## WebAssembly
WebAssembly is een stack gebaseerde taal. Elke instructie zal dus elementen van de stapel kunnen halen en elementen op de stapel kunnen plaatsen. We illustreren dit met het volgende programma dat bestaat uit 3 instructies.
```wasm
i32.const 3
i32.const 5
i32.add
```

|                | `i32.const 3` | `i32.const 5` | `i32.add` |
|----------------|---------------|---------------|-----------|
| stack[1]       |               | 5             |           |
| stack[0]       | 3             | 3             | 8         |

Dit programma zal eerst op de stapel de constante `3` pushen, dan zal de constante `5` gepusht worden. Daarna zal `i32.add` twee elementen van de stapel halen en deze bij elkaar optellen. Het resultaat zal opnieuw op de stack geplaatst worden. Uiteindelijk zal dus het getal `8` op de stapel overblijven. De interpreter en programma analyse in dit project moeten een bepaalde subset aan instructies ondersteunen. Deze worden beschreven in de [Instructies](#instructies) sectie.

## Features
Het project moet drie verschillende modi ondersteunen. Een modus om programma's uit te voeren, een modus om inputs op te sporen die resulteren in een fout en een derde modus die voor elk uitvoeringspad een set inputs zoekt om deze uit te kunnen voeren.

### Uitvoeren
De eerste modus van het programma is de gewone `run` modus. Deze zal het programma zelf gewoon uitvoeren zoals het is. Om deze modus te starten gebruik je het volgende commando:
```
./plwasm run <filename>
```
Om het programma te starten zal de interpreter de start functie oproepen die aangegeven wordt in het bestand, het programma start met een lege stapel. Je mag er van uit gaan dat de start functie geen argument heeft.

### Programma analyse
Naast het uitvoeren moet je project ook programma's kunnen analyseren om inputs te vinden die het programma doen crashen. Het doel is dus om alle mogelijke inputs af te gaan en een oplijsting terug te geven van welke inputs in een fout resulteren. Bijkomend willen we ook dat er per uitvoeringspad maar één set inputs wordt afgedrukt.

#### Voorbeeld:
Het onderstaande programma zal het getal `3` delen door een getal opgegeven door de gebruiker.
```wasm
i32.const 3    ;; Plaats 3 op de stapel
i32.const 0
i32.const 30   ;; Argument van read_int, getal kan maximaal 30 zijn.
call read_int  ;; Lees een getal van de gebruiker (max 30)
i32.div_s      ;; Deel 3 door dit getal
```
In een andere taal zou je dit misschien schrijven als het volgende:
```c
3 / read_int(0, 30);
```
Het is mogelijk om dit programma te doen crashen door als gebruiker `0` in te geven. Hierdoor zal het programma namelijk delen door `0`. Het doel van de analyse is om dit soort inputs die het programma doen crashen op te sporen. Een crash noemen we in WebAssembly ook wel een trap. De instructie `i32.div_s` kan dus resulteren in een trap.

#### Unreachable
Naast gewone instructies zoals de deling heeft WebAssembly ook andere instructies die kunnen resulteren in een trap. Zo heeft WebAssembly ook een instructie `unreachable` die altijd in een trap zal resulteren. Deze kan gebruikt worden voor het implementeren van assertions. Bijvoorbeeld stelt de onderstaande code (als assertion) dat de functie `read_int` een waarde groter of gelijk aan `10` zal teruggeven. Als de waarde kleiner dan `10` is wat met de instructie `i32.lt` (less than) kan bepaald worden dan zal namelijk de `unreachable` instructie uitgevoerd worden.

```wasm
i32.const 0
i32.const 30
call read_int
i32.const 10
i32.lt
if
    unreachable
end
```
In een andere taal zou je dit misschien schrijven als het volgende:
```c
if (read_int(0, 30) < 10) {
    // Fatal error
    exit(1);
}
```
Of met een assertion:
```c
assert(read_int(0, 30) >= 10);
```
Een mogelijke input die zal resulteren in een trap is hier dus `4` aangezien dit getal een mogelijke return waarde is van `read_int` die zich in dit geval tussen `0` en `30` moet bevinden. Aangezien we maar één enkele input die resulteert in een trap per uitvoeringspad willen is het ook voldoende om alleen `4` als output terug te geven, andere opties zoals `0`,`1`,`2`,`3`,`5`,`6`,`7`,`8`,`9` zijn ook geldige resultaten maar je analyse moet maar één van deze opties teruggeven.

Dit programma is het eerste voorbeeld waar meerdere uitvoeringspaden zijn, zo is er een pad waarbij de conditie van de `if` waar is, en een pad waarde conditie niet waar is. In totaal zijn er hier dus twee uitvoeringspaden. Eerder hadden we vermeld dat de analyse voor elk uitvoeringspad die in een trap zal resulteren één set inputs moet teruggeven om die trap te bereiken. Voor het ene uitvoeringspad heeft de analyse al `4` gevonden. Voor het andere uitvoeringspad waarbij de `if` conditie niet waar is kan je niet in een trap terechtkomen, voor dit uitvoeringspad zal de analyse dus geen inputs teruggeven.

#### Gebruik
Het uiteindelijke doel van het project is dat je een programma kan analyseren door het volgende commando uit te voeren.
```
./plwasm analyse <filename> [max instructions]
```
Voor het voorgaande programma met de assertion is dit een mogelijk resultaat (andere resultaten die `0`,`1`,`2`,`3`,`5`,`6`,`7`,`8`,`9` gebruiken zijn ook geldig):
```
Inputs: [4], State: trap
```
De output moet voor elk uitvoeringspad in het programma, een set teruggeven als die waarden in een trap kunnen resulteren. Dit betekent dat je voor een programma die crasht bij een waarde kleiner dan 10 maar 1 waarde, bijvoorbeeld `0` kan teruggeven aangezien de andere waarden `1,2,3,4,5,6,7,8,9` zich in hetzelfde uitvoeringspad bevinden en we maar 1 waarde per pad willen. De inputs worden teruggegeven in een lijst, hierbij is het eerste element de eerste ingelezen input, het tweede element de tweede ingelezen input enzoverder. Aangezien dit programma maar één input leest heeft de lijst hier dus slechts één element.

> [!NOTE]
> Probeer ook na te denken over hoe je dit efficiënt kan doen zodanig dat je niet teveel tijd spendeert aan het bezoeken van paden die je al bezocht hebt.

De analyse van oneindige programma's kan oneindig lang duren. Om deze programma's te analyseren vragen we dat je ook een optionele parameter ondersteund die het aantal instructies kan beperken. Als deze bijvoorbeeld `1000` is dan moet de analyse vanaf de start van het te analyseren programma maximaal `1000` instructies uitvoeren.

### Vinden van alle paden
Ten slotte willen we naast het opsporen van paden die resulteren in een trap, ook dat je inputs kan genereren om in eender welk uitvoeringspad terecht te komen. Bij een `if` statement wil je zo bijvoorbeeld waarden om zowel de `if` als de `else` branch uit te voeren.

Deze optie moet geactiveerd worden als je de `paths` optie gebruikt. Net zoals bij de analyse optie moet deze ook de max instructions parameter ondersteunen.
```
./plwasm paths <filename> [max instructions]
```
Voor het programma met de assertion die we eerder beschreven zal je in dit geval niet één set inputs maar twee teruggeven.
```
Inputs: [4], State: trap
Inputs: [13], State: finished
```
Hier zal de `4` er dus voor zorgen dat het pad `read_int(0, 30) < 10` uitgevoerd wordt terwijl de `13` het pad `read_int(0, 30) >= 10` zal uitvoeren.

## Instructies
We hebben ervoor gekozen een subset van WebAssembly te ondersteunen waarbij alleen maar met signed 32 bit integers gewerkt kan worden. Hieronder geven we een oplijsting van welke instructies je project moet kunnen gebruiken.

### Numerieke instructies
- `i32.const X` Plaats een constante `X` op de stapel.
- `i32.add` Neem twee elementen van de stapel en tel ze bij elkaar op, plaats het resultaat terug op de stapel.
- `i32.sub` Neem eerst `B` en dan `A` van de stapel, plaats dan het resultaat van `A - B` terug op de stapel.
- `i32.mul` Neem eerst `B` en dan `A` van de stapel, plaats dan het resultaat van  `A * B` terug op de stapel.
- `i32.div_s` Neem eerst `B` en dan `A` van de stapel, plaats dan het resultaat van  `A / B` terug op de stapel. Bij het delen door `0` zal deze instructie resulteren in een trap.
- `i32.lt_s` Neem eerst `B` en dan `A` van de stapel, en kijk dan als `A < B`, als dat het geval is plaats je `1` op de stapel, anders `0`.
- `i32.le_s` Neem eerst `B` en dan `A` van de stapel, en kijk dan als `A <= B`, als dat het geval is plaats je `1` op de stapel, anders `0`.
- `i32.gt_s` Neem eerst `B` en dan `A` van de stapel, en kijk dan als `A > B`, als dat het geval is plaats je `1` op de stapel, anders `0`.
- `i32.ge_s` Neem eerst `B` en dan `A` van de stapel, en kijk dan als `A >= B`, als dat het geval is plaats je `1` op de stapel, anders `0`.
- `i32.eqz` Neem het bovenste element van de stapel en kijk als dit element gelijk is aan `0`, plaats `1` op de stapel als dat zo is, anders `0`.
- `i32.eq` Neem de twee bovenste elementen van de stapel, als ze gelijk zijn plaats je `1` op de stapel, anders `0`.
- `i32.ne` Neem de twee bovenste elementen van de stapel, als ze niet gelijk zijn plaats je `1` op de stapel, anders `0`.
- `i32.and` Neem de twee bovenste elementen van de stapel en doe een bitwise and, het resultaat plaats je opnieuw op de stapel.
- `i32.or` Neem de twee bovenste elementen van de stapel en doe een bitwise or, het resultaat plaats je opnieuw op de stapel.
- `i32.xor` Neem de twee bovenste elementen van de stapel, en bereken de bitwise xor hiervan. Het resultaat plaats je opnieuw op de stapel.

### Lokale variabelen
- `local.get N` Haal de waarde van het N'de lokale variabele op en plaats dit op de stapel. Bij functies met argumenten tellen deze ook mee als lokale variabelen. Op deze manier zal `local.get 0` resulteren in het eerste argument. De andere lokale variabelen die komen na deze argumenten. Als de functie dus twee argumenten had dan zal `local.get 2` het eerste echte lokale variabele zijn die geen argument is.
- `local.set N` Gelijkaardig aan `local.get` alleen dat nu een waarde van de stapel genomen wordt om te schrijven naar het N'de lokale variabele. 
- `local.tee` Gelijkaardig aan `local.set` alleen dat de waarde boven op de stapel hetzelfde blijft na het uitvoeren van deze instructie. Op deze manier kan het lokale variabele nog verder gebruikt worden zonder het eerst opnieuw op de stapel te plaatsen met een `local.get` instructie.

### Control flow
- `call X` Met de call instructie kan de functie `X` opgeroepen worden. Bij het oproepen van deze functie zullen de argumenten van deze functie van de stapel genomen worden. Achteraf zal het resultaat terug op de stapel geplaatst worden. Er zijn twee soorten functies die je kan uitvoeren, functies binnen het programma zelf en [primitieve functies](#primitieve-functies). Functies binnen het programma zelf worden aangeroepen via een index, zo zal je de eerste functie in het bestand kunnen oproepen met `call 0`. Voor primitieve functies kan je de namen gebruiken, zo kan je de functie `print_int` oproepen met `call print_int`. 
- `block` Start een blok code, een blok moet beëindigd worden met een `end` instructie. Als gesprongen zal worden naar deze blok dan zal de code verdergaan na de `end` instructie. In dit geval spring je dus naar het einde.
- `loop` Gelijkaardig aan `block` start deze instructie een blok code die met `end` beëindigd moet worden. Anders dan bij `block` zal bij het springen naar deze blok code, de code verdergaan bij het begin.
- `if TrueBlock [else FalseBlock] end` Deze instructies werken zoals een gewone `if` uit andere programmeertalen, afhankelijk van de conditie zal het true of false blok uitgevoerd worden. Voor de conditie zal `if` de bovenste waarde van de stapel nemen. Als deze verschilt van `0` dan zal de code binnen het `if` blok uitgevoerd worden. Als dat niet het geval is zal het optionele `else` geval uitgevoerd worden. Als er geen `else` is dan zal de code gewoon verder gaan na de `end`. Net als de `block` instructie kan je ook naar een blok gemaakt door `if` springen, in dit geval zal altijd naar het einde `end` gesprongen worden net zoals bij `block`.
- `br X` Met deze instructie spring je naar een `block`, `loop` of `if` blok. De `X` zal bepalen hoe ver je sprint, zo springt `br 0` naar het binnenste blok en zal `br 1` springen naar het blok daar nog net buiten, `br 2` daar nog eens buiten.

  **Voorbeeld:**
  In het volgende programma zal `br 1` springen naar niet het blok direct rond de instructie maar naar het tweede blok. Omdat het een `block` instructie is zal de interpreter springen naar het einde. Hierdoor zal dit programma als resultaat `1` printen. Het printen van `0` zal overgeslagen worden.
  ```wasm
  block
    block
      br 1
    end
    i32.const 0
    call print_int
  end ;; br 1 zal naar hier springen
  i32.const 1
  call print_int
  ```
- `br_if X` Werkt net zoals `br` maar zal conditioneel springen. De instructie neemt de bovenste waarde van de stapel en gebruikt deze als conditie. Als de conditie verschilt van `0` dan zal de interpreter `X` blokken naar buiten springen. Als de conditie `0` is zal niet gesprongen worden.
- `return` Springt uit alle blokken en stopt de functie, als een functie `N` integers teruggeeft dan zullen de bovenste `N` op de stapel het resultaat zijn. Als een functie stopt zonder een `return` uit te voeren dan gelden dezelfde regels, de functie stopt en de bovenste `N` elementen zijn het resultaat.

### Misc
- `unreachable` Deze instructie zal in een trap resulteren.
- `drop` Deze instructie zal het bovenste element van de stapel nemen, verder gebeurt er niets.
- `nop` Deze instructie doet niets.

## Geheugen
Naast de stapel heeft elke module ook een blok geheugen, voor de eenvoudigheid kan deze alleen gebruikt worden om data zoals strings op te slaan. Deze strings kunnen dan later afgedrukt worden met de `print` functie. Het WebAssembly geheugen bestaat uit pages waarvan 1 page een blok is van 64 KiB of dus 65 536 bytes. In dit project bestaat het geheugen altijd uit 16 pages (in totaal dus 16 * 65 536 bytes), als je daar buiten zou lezen of schrijven dan krijg je een error. Standaard is het geheugen leeg en bevat het overal nul. Met de `(data <adres> <data>)` syntax die je zal moeten ondersteunen in de parser kan je in dit geheugen data plaatsen, bijvoorbeeld de string "abcd" op locatie `0`, `(data 0 "\97\98\99\100")`. Hierbij stellen we elk teken voor als een backslash met daarna de decimale ascii waarde. Met de `print` functie kan je deze string dan afdrukken met de volgende sequentie instructies:
```wasm
i32.const 0
call print
```

## Primitieve functies
Naast instructies moet je interpreter ook een reeks basis operaties ondersteunen, deze basis operaties zijn functies die niet binnen het programma zelf gedefinieerd zijn maar die aangeboden worden door de interpreter. Deze zijn onderverdeeld in twee categorieën, input en output primitieven. De input primitieven zijn de enige bron van non-determinisme en zullen in de analyse modus de inputs zijn waarnaar gezocht wordt. De analyse zal dus zoeken naar mogelijke waarden die deze primitieven zouden kunnen teruggeven die in een fout zal resulteren.

- `read_int(Minimum, Maximum)` Leest een integer in van de gebruiker, de waarde moet tussen het Minimum en Maximum (exclusief) liggen. Als de waarde niet binnen deze range valt dan zal de interpreter een nieuwe waarde vragen. Op deze manier zal er dus altijd een waarde binnen de opgegeven grenzen teruggeven worden. Dit is belangrijk omdat de programma analyse ook deze grenzen moet gebruiken om te weten welke waarden mogelijk zijn. Tijdens de analyse zal de gebruiker nooit zelf een waarde moeten opgeven, de analyse zal zelf waarden kiezen uit de opgegeven range.
- `rand_int(Minimum, Maximum)` Geeft een willekeurig getal terug tussen het Minimum en Maximum (exclusief). Net zoals `read_int` is deze primitieve verantwoordelijk voor het genereren van inputs in de analyse.
- `print_int(Value)` Drukt een getal Value af.
- `print(Address, Length)` Drukt een string af van lengte Length die in het geheugen op de plaats Address staat.
- `println(Address, Length)` Gelijkaardig aan `print` maar deze primitieve print ook een newline achter de string.

## Parser
De bestanden die je moet kunnen uitvoeren en analyseren hebben de volgende vorm. Dit formaat is een vereenvoudigde versie van het [tekstuele WebAssembly formaat](https://developer.mozilla.org/en-US/docs/WebAssembly/Guides/Understanding_the_text_format). Voor deze bestanden gebruiken we dan ook de bestandsextentie `pwat` (pseudo wat).

Een programma is opgebouwd uit een module. Deze module bevat enkele eigenschappen, de start functie die eerst opgeroepen bij de start van het programma en een optioneel data segment. Daarnaast bevat de module functies. Functies hebben elk een aantal argumenten, het aantal lokale variabelen en het aantal waarden die de functie zal teruggeven. Naast deze eigenschappen bevat elke functie ook een reeks instructies.

In het tekstuele formaat mogen er tussen een instructie en zijn argumenten (bijvoorbeeld `i32.const 3`, hierbij is `3` het argument) spaties staan. Hetzelfde geldt voor eigenschappen `(args 0)`. Daarnaast mogen er ook lege lijnen tussen instructies en mag er voor en na instructies ook spacing zijn. Daarnaast mag er ook commentaar achter instructies of op aparte lijnen geplaatst worden. Commentaar start met `;;`.

```wasm
(module 
    (start 1) 

    ;; String "abcd"
    (data 0 "\97\98\99\100")

    ;; Add function
    (func (args 2) (locals 0) (results 1)
        local.get 0 ;; Plaats het eerste argument op de stapel
        local.get 1 ;; Plaats het tweede argument op de stapel
        i32.add     ;; Neem twee elementen van de stapel, tel ze op en plaats het resultaat op de stapel.
    )

    ;; Main function
    (func (args 0) (locals 0) (results 0)
        ;; Print "abcd"
        i32.const 0
        i32.const 4
        call println

        ;; Add 3 and 5
        i32.const 3
        i32.const 5
        call 0
        ;; Print the result
        call print_int
    )
)
```

## Niet functionele eisen

Naast de basisfunctionaliteit vragen we enkele niet functionele eisen waar je project aan
dient te voldoen. Deze niet functionele eisen zijn even belangrijk als de functionele eisen
van het project.

- de code moet goed gedocumenteerd zijn, er moet commentaar geschreven bij de moeilijkere delen van je code. 
- je code moet getest zijn, dit wil zeggen dat je voor elke functionaliteit zelf een test schrijft zodat je zeker bent dat de basis functionaliteit werkt.
- je project moet testbaar zijn aan de hand van input/output.

## Verslag

We verwachten een bondig verslag die de algemene oplossingsstrategie van je project beschrijft. 
Voeg aan je verslag je code toe met lijnnummers zodat je in de uitleg van je verslag kan verwijzen naar de relevante delen van je code. Je bent zelf vrij hoe je dit verslag organiseert maar we verwachten op zijn minst de volgende onderdelen:

- Inleiding
- Werking interpreter
- Werking zoek systeem voor fouten en alle mogelijke uitvoeringspaden.
- Overzicht van je testen (Mag zeer kort zijn maar het moet duidelijk zijn hoe je het project test)
- Conclusie

## Mondelinge verdediging

Op het einde van het semester zal je ook jouw project mondeling moeten voorstellen.
De dag van de verdedigingen zal later worden meegedeeld.

# Indienen

Het indienen van het project gebeurd via **GitHub Classroom**.

## GitHub Classroom

Om te starten met het project, klik je op de invite link voor GitHub Classroom die je op Ufora kan vinden onder *Inhoud > Project*.
Vervolgens zal je jouw naam moeten kiezen uit de lijst van ingeschreven studenten.
Daarna krijg je een eigen fork van de opgave repository.

Als hiermee iets fout loopt, contacteer ons dan zo snel mogelijk.

> [!IMPORTANT]
> De laatste commit op de branch `main` van je fork op de deadline geldt als je indiening.

## Vorm

Je project moet volgende structuur hebben:

  - `src/` bevat alle broncode.
  - `tests/` alle testcode.
  - `documentatie/verslag.pdf` bevat de elektronische versie van je verslag. In
    deze map kun je ook eventueel extra bijlagen plaatsen.

Je directory structuur ziet er dus ongeveer zo uit:

```
    |
    |-- documentatie/
    |   -- verslag.pdf
    |-- src/
    |   -- je broncode
    `-- tests/
        -- je testcode
```

## Deadline

Het project moet ingediend zijn op 8/05/2026 om 20:00 CEST.

# Algemene richtlijnen

  - Schrijf efficiënte code, maar ga niet over-optimaliseren: **geef de
    voorkeur aan elegante, goed leesbare code**. Kies zinvolle namen
    voor predicaten en variabelen en voorzie voldoende commentaar.
  - Het project wordt gequoteerd op **10** van de 20 te behalen punten
    voor dit vak. Als de helft niet wordt behaald, is je eindscore het
    minimum van je examencijfer en je score op het project.
  - Dit is een individueel project en dient dus door jou persoonlijk
    gemaakt te worden. **Het is ten strengste verboden code uit te
    wisselen**, op welke manier dan ook. Het overnemen van code
    beschouwen we als fraude (van **beide** betrokken partijen) en zal
    in overeenstemming met het examenreglement behandeld worden. Het
    overnemen of aanpassen van code gevonden op internet is ook **niet
    toegelaten** en wordt gezien als fraude.
  - Vragen worden mogelijks **niet** meer beantwoord tijdens de laatste
    week voor de finale deadline.
- Zorg ervoor dat je project testbaar is aan de hand van input/output en voldoet aan enkele publieke unit-tests die we later beschikbaar zullen stellen.
  - Probeer zeker de programma's in de `examples` map, je mag in deze map ook zelf extra voorbeeld programma's toevoegen.

# Vragen

Als je vragen hebt over de opgave of problemen ondervindt, dan kun je je
vraag stellen via [mail](mailto:maarten.steevens@ugent.be).
Stuur geen screenshots van code, maar link naar de code in je GitHub repository.
Indien mogelijk/toepasbaar, vermeld ook een “[minimal breaking
example](https://stackoverflow.com/help/minimal-reproducible-example)”.
