# plwasm — WebAssembly analysis tool in Prolog

`plwasm` is a small interpreter and static-analysis tool for a **simplified
subset of WebAssembly**, written in [SWI-Prolog](https://www.swi-prolog.org/).

WebAssembly is a stack-based language: every instruction pops values from the
stack and pushes new ones. `plwasm` reads programs written in a textual
`.pwat` format and can do three things with them:

| Mode       | What it does                                                            |
|------------|-------------------------------------------------------------------------|
| `run`      | Executes the program normally, the way a real interpreter would.       |
| `analyse`  | Searches for input combinations that cause the program to **trap**.    |
| `paths`    | Searches for input combinations that reach **every** execution path.  |

Because it is written in Prolog, symbolic execution comes almost for free:
backtracking over the possible return values of `read_int` and over branch
conditions is used to explore the program's execution tree.

## Table of contents

- [plwasm — WebAssembly analysis tool in Prolog](#plwasm--webassembly-analysis-tool-in-prolog)
  - [Table of contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Quick start](#quick-start)
  - [The three modes](#the-three-modes)
    - [run](#run)
    - [analyse](#analyse)
    - [paths](#paths)
    - [Exit codes](#exit-codes)
  - [The `.pwat` file format](#the-pwat-file-format)
    - [Module structure](#module-structure)
    - [Supported instructions](#supported-instructions)
    - [Primitives](#primitives)
  - [Examples](#examples)
  - [Project layout](#project-layout)
  - [Architecture](#architecture)
  - [Testing](#testing)
  - [Documentation](#documentation)

## Prerequisites

- **SWI-Prolog** (`swipl`) must be on your `PATH`. On Debian/Ubuntu:

  ```bash
  sudo apt install swi-prolog
  ```

- A Unix-like shell (the `plwasm` launcher is a bash script).

## Quick start

The repository ships a thin launcher called `plwasm`:

```bash
./plwasm <mode> <file.pwat> [max_instructions]
```

which is just a wrapper around:

```bash
swipl -q -s src/main.pl -- <mode> <file.pwat> [max_instructions]
```

Try it on one of the bundled examples:

```bash
./plwasm run examples/hoger_lager.pwat
./plwasm analyse examples/test1b.pwat
./plwasm paths  examples/test_more_paths.pwat 5000
```

## The three modes

All modes take a `.pwat` file as input. `analyse` and `paths` additionally
accept an optional `max_instructions` argument that limits how many
instructions a single execution is allowed to run (defaults to `1000`). This
keeps analysis of non-terminating programs finite.

### run

```bash
./plwasm run <file.pwat>
```

Executes the program starting from the function declared with `(start N)`,
with an empty stack. Any `read_int` call waits for you to type a number on
stdin.

Output:

```
State: finished
Returns: [...]
```

### analyse

```bash
./plwasm analyse <file.pwat> [max_instructions]
```

Explores every execution path and prints, **for each path that traps**, one set
of inputs that triggers it. Inputs are listed in the order they are read; the
first element is the first `read_int`/`rand_int` result, etc.

Example output:

```
Inputs: [4], State: trap
Inputs: [1,1], State: trap
```

Programs that contain an *invalid* execution (e.g. a stack underflow) cause
the whole analysis to abort with exit code 1.

### paths

```bash
./plwasm paths <file.pwat> [max_instructions]
```

Like `analyse`, but it reports **one set of inputs per distinct execution
path**, regardless of whether that path traps or finishes normally. This is
useful to see both branches of every `if` and every iteration of a `loop`.

Example output:

```
Inputs: [5], State: trap
Inputs: [1,1], State: trap
Inputs: [1,6], State: finished
```

### Exit codes

| Code | Meaning                                                                            |
|------|------------------------------------------------------------------------------------|
| `0`  | The program ran / analysed successfully.                                           |
| `1`  | The program is **invalid** — parsing failed, a stack underflow happened, or the `max_instructions` value was malformed. |
| `2`  | In `run` mode only: the program **trapped** (e.g. `i32.div_s` by zero, `unreachable`). `analyse` and `paths` continue past traps instead of stopping. |

## The `.pwat` file format

A `.pwat` file is an S-expression describing a module. The grammar is parsed
with Prolog Definite Clause Grammars (see `src/parser.pl`).

### Module structure

```
(module
    (start <function-index>)
    (data <address> "<bytes>")   ;; zero or more
    (func (args N) (locals N) (results N)
        <instruction> ...         ;; one or more
    )
    ...                          ;; zero or more extra functions
)
```

- `(start N)` — index of the function to run first (0-based, into the order the
  `func` blocks appear). It is assumed to take no arguments.
- `(data addr "bytes")` — initialises linear memory at `addr`. Bytes can be
  written literally, or as `\`-prefixed decimal codes, e.g. `"\71\101\108\108\111"`
  encodes `"Hello"`.
- `(func ...)` — a function. Functions are called by index (the order in which
  they appear in the module) using `call <index>`.

Whitespace and `;; ...` line comments are ignored, so very compact files are
allowed (see `examples/test_whitespace.pwat`).

### Supported instructions

| Category      | Instructions |
|---------------|--------------|
| Constants     | `i32.const N` |
| Arithmetic    | `i32.add`, `i32.sub`, `i32.mul`, `i32.div_s` (traps on division by zero) |
| Comparison    | `i32.lt_s`, `i32.le_s`, `i32.gt_s`, `i32.ge_s`, `i32.eq`, `i32.ne` |
| Bitwise       | `i32.and`, `i32.or`, `i32.xor` |
| Unary         | `i32.eqz` (push 1 if top is 0, else 0) |
| Locals        | `local.get N`, `local.set N`, `local.tee N` |
| Calls         | `call <index>` (user function), `call <primitive>` (built-in) |
| Control flow  | `block ... end`, `loop ... end`, `if ... else ... end`, `br N`, `br_if N`, `return` |
| Misc          | `drop`, `nop`, `unreachable` (always traps) |

`if` may be written without an `else` branch; the missing branch is treated as
empty. `br` and `br_if` use WebAssembly-style label indices: `br 0` breaks out
of the innermost enclosing `block`, while inside a `loop` it jumps back to the
top of the loop.

### Primitives

These are "functions" called by name rather than by index:

| Primitive    | Arity | Effect |
|--------------|-------|--------|
| `read_int`   | 2     | Pops `(min, max)`; in `run` mode reads a number from stdin strictly between `min` and `max`; in analysis mode non-deterministically yields every integer in `(min, max)`. |
| `rand_int`   | 2     | Pops `(min, max)`; returns a random integer in `[min, max)`. |
| `print_int`  | 1     | Pops one value and prints it (in `run` mode only). |
| `print`      | 2     | Pops `(address, length)` and prints that slice of linear memory. |
| `println`    | 2     | Like `print` followed by a newline. |

During `analyse`/`paths` the I/O primitives are silenced so the analysis stays
pure; only `read_int` actively influences the explored paths (its results become
the "inputs" reported in the output).

## Examples

The `examples/` directory contains a growing collection of programs:

| File                         | Demonstrates |
|------------------------------|--------------|
| `hoger_lager.pwat`           | A higher/lower guessing game with loops, `br`, and memory strings. |
| `steen_papier_schaar.pwat`   | Rock-paper-scissors using `read_int`, `rand_int` and nested `if`. |
| `game_of_life.pwat`          | A 5×5 Conway's Game of Life, heavy on locals and memory. |
| `final_boss.pwat`            | A demo combining arithmetic, comparison, bitwise ops, locals, blocks and loops. |
| `test_block.pwat`            | `block` + `br` early exit. |
| `test_if_br.pwat`            | `if` combined with `br_if`. |
| `test_if_else.pwat`          | Nested `if`/`else` with traps on branches. |
| `test_loop.pwat`, `test_loop_br.pwat` | A counting `loop` using `br_if`. |
| `test_return.pwat`          | Early `return` from a function. |
| `test_more_paths.pwat`       | A program with 5 distinct execution paths (3 trap, 2 finished). |
| `test_whitespace.pwat`       | The same loop program but with all whitespace/comments stripped, to stress the parser. |
| `test1a.pwat` / `test1b.pwat`| Minimal one-input programs; `test1b` traps on `unreachable`. |
| `test2a.pwat`                | A loop that reads input twice. |
| `inst_mem_func/test1..8.pwat`| Focused tests for instructions, memory and function calls. |
| `demo/game_of_life.pwat`     | Demo copy of the Game of Life used by the autograder. |

See `examples/README.md` for sample invocations and expected output.

## Project layout

```
.
├── plwasm                 # bash launcher: swipl -q -s src/main.pl -- "$@"
├── src/
│   ├── main.pl            # CLI: argument parsing and dispatch for run/analyse/paths
│   ├── parser.pl          # DCG-based parser for the .pwat format
│   ├── runner.pl           # public entry points: run_file/2, run_module/2, analyse_file/4
│   ├── function_runner.pl # the interpreter: executes functions and instructions
│   ├── primitive_runner.pl# built-in primitives: read_int, print, etc.
│   ├── memory_initializer.pl# builds linear memory from (data ...) segments
│   ├── utilities.pl        # small helpers: stack/local manipulation, binary ops
│   └── test.pl
├── examples/              # sample .pwat programs (see examples/README.md)
├── tests/                 # plunit test suites + a run.sh helper
├── documentatie/          # LaTeX verslag (Dutch) + compiled PDF
├── docker-test.sh         # convenience: docker run the autograder image
└── .github/workflows/     # GitHub Classroom autograding workflow
```

## Architecture

The tool is split into small, single-purpose modules:

1. **`parser.pl`** turns a `.pwat` file into a Prolog term
   `module(Start, Data, Funcs)` where `Funcs` is a list of
   `func(ArgCount, LocalCount, ResultCount, Instructions)`. Parsing uses a DCG
   with separate rules per instruction.

2. **`memory_initializer.pl`** converts the `(data ...)` segments into a list
   of `address(Start, String)` entries, decoding the `\NNN` byte escapes.

3. **`runner.pl`** is the thin public API. `run_file/2` parses and runs a file;
   `analyse_file/4` parses it and explores it symbolically.

4. **`function_runner.pl`** is the heart of the interpreter. `exec_instruction/10`
   has one clause per supported instruction and threads through:
   - the current stack,
   - the local variables,
   - linear memory,
   - a **signal** (`continue`, `returned`, `break(N)`, `trap`, `invalid`),
   - an **execution context** that is either `run` (no bookkeeping) or
     `analyse(Max, Counter, Inputs, PathTrace)`.

   The analysis context records the inputs read so far and a *path trace* (the
   sequence of branch decisions taken). When execution finishes, Prolog
   backtracks over every alternative `read_int` value and every `if` branch,
   producing one solution per reachable path.

5. **`primitive_runner.pl`** implements the built-ins. The clever bit is
   `read_int`/analyse: instead of reading stdin it uses `between(Lower, Upper,
   Value)` so that successive choice-points yield each possible input. Side
   effects like `print`/`println`/`print_int` are skipped during analysis.

6. **`main.pl`** parses the command line, calls `runner`, post-processes the
   list of `Status-Inputs-PathTrace` solutions collected with `findall/3`, and
   prints them. For `analyse` it keeps only the trap paths, deduplicates by path
   trace (so each path is reported once) and sorts lexicographically. For
   `paths` it keeps one result per `(PathTrace, Status)` pair.

## Testing

A [plunit](https://www.swi-prolog.org/pldoc/doc_for?object=section(%27packages/plunit.html%27))
test suite lives in `tests/`:

| File                  | Covers |
|-----------------------|--------|
| `test_parsing.pl`     | Parser output on representative `.pwat` files. |
| `test_run.pl`        | Concrete execution results for arithmetic, branches, loops, calls, etc. |
| `test_analyse.pl`    | That `analyse` finds the expected trap inputs. |
| `test_paths.pl`      | That `paths` enumerates the expected set of paths. |
| `test_cli_modes.pl`  | End-to-end CLI output for `analyse` and `paths`. |
| `test_exit_code.pl`  | Exit codes 0 / 1 / 2 for finished / invalid / trap. |

Run the whole suite with:

```bash
./tests/run.sh
```

which is just:

```bash
for file in tests/*.pl; do
    swipl -q -s "$file" -g run_tests -t halt
done
```

Or run a single suite, e.g.:

```bash
swipl -q -s tests/test_run.pl -g run_tests -t halt
```

## Documentation

A more detailed (Dutch) report describing the design decisions, the
interpreter semantics and the analysis strategy is available in
[`documentation/verslag.pdf`](documentatie/verslag.pdf) (source:
`documentation/verslag.tex`).