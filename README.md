# bash2v

`bash2v` is a Bash 5.1 to V transpiler targeting V `0.5.1+`.

The project is built around:

- a Bash-oriented lexer and parser;
- a lowered IR that makes execution semantics explicit;
- a dedicated `bashrt` runtime for Bash expansion and arrays;
- `v_scr` as the process and orchestration backend.

The repository is currently in scaffold stage.

## Build

To build the `bash2v` binary from the repository root:

```bash
mkdir -p bin
v -prod -o ./bin/bash2v ./cmd/bash2v
```

Without `-prod`, a debug build is:

```bash
v -o ./bin/bash2v ./cmd/bash2v
```

Note: in this repository the path `./bash2v` is already occupied by the source module directory `./bash2v/`, so the practical binary path here is `./bin/bash2v`.

## Transpile And Run

Given a Bash script `b.sh`, transpile it into `b.v` like this:

```bash
./bin/bash2v transpile ./b.sh -o ./b.v
```

Then run the generated V program from the repository root:

```bash
v run ./b.v
```

This has been verified end to end on the current tree:

```bash
./bin/bash2v transpile ./examples/basic.bash -o ./examples/basic.generated.v
v run ./examples/basic.generated.v
```

Expected output:

```text
hello
```

## Requirements

To make `v run b.v` work successfully in the current repository layout, you need:

- the V compiler installed and available as `v`
- to run `v run` from the repository root

You do not need to install extra libraries with `v install` for this repository checkout, because:

- the generated file imports `bash2v.bashrt`, which is provided by this repository
- the runtime imports `v_scr`, and this repository already vendors `./v_scr/`

In other words, for a normal checkout of this repository the minimal workflow is:

```bash
mkdir -p bin
v -prod -o ./bin/bash2v ./cmd/bash2v
./bin/bash2v transpile ./b.sh -o ./b.v
v run ./b.v
```

## Running Outside This Repository

If you move only the `bash2v` binary to another server, then:

- for `hello.sh -> hello.v` you only need that binary
- for `v run ./hello.v` you also need the runtime modules available to V

The simplest portable workflow is `--bundle-runtime`:

```bash
./bash2v transpile --bundle-runtime ./hello.sh -o ./out/hello.v
cd ./out
v run ./hello.v
```

`--bundle-runtime` writes these files next to the generated output:

- `./out/bash2v/...`
- `./out/v_scr/...`
- `./out/v.mod`

This mode is intended exactly for the case where you copied a single transpiler binary to another machine and want the generated `hello.v` to compile there without a full source checkout.

On that other server you need:

- the `bash2v` binary
- the V compiler installed as `v`
- any external system commands that the original Bash script itself calls, for example `grep`, `sed`, `awk`, `curl`

If you move `b.v` somewhere else and run it outside this repository root, V will also need to be able to resolve these imports:

- `bash2v.bashrt`
- `v_scr`

So outside this checkout you must either:

- keep running from a directory where `./bash2v/` and `./v_scr/` are visible to V, or
- install/copy these modules into your V module search path before running `v run b.v`

If you do not use `--bundle-runtime`, then you must provide `bash2v.bashrt` and `v_scr` yourself.

## Direct Execution

If you do not need the intermediate `b.v` file, the CLI can also transpile and execute a Bash script directly:

```bash
./bin/bash2v run ./b.sh
```
