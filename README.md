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
