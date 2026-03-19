# bash2v: design notes

## Цель

Считай себя супер-профессионалом в bash-5.1 (с использованием башизмов), считай себя супер-профессионалом в Vlang v0.5.1+

Сделать транспилятор из Bash 5.1 в V `0.5.1+`, который:

- парсит Bash-скрипт в собственный AST;
- понижает AST в более простой IR с явной семантикой исполнения;
- генерирует V-код;
- использует `v_scr` как runtime для процессов, pipeline и orchestration;
- использует собственный слой `bashrt` для Bash-специфичных expansion, переменных и массивов.
- использует строковые значения как основной runtime-формат для scalar-переменных и interpolation fragments;
- использует `map[string]string` для associative arrays и shell-like string maps;
- не сводит весь runtime к `map[string]string`, потому что indexed arrays и quote-aware expansion требуют отдельных типов.

Ключевой принцип:

`v_scr` не должен превращаться в Bash-интерпретатор. Он остается execution/runtime-слоем. Bash-совместимость живет в `bash2v`.

## Базовая стратегия

Нужна четырехслойная архитектура:

1. `lex/parse`
   Превратить текст Bash в AST без потери структуры вложений.
2. `lowering`
   Свести shell-синтаксис к явным операциям: expand, split, substitute, exec, assign.
3. `runtime`
   Выполнить Bash-подобную семантику поверх V.
4. `codegen`
   Сгенерировать читаемый V, который вызывает `v_scr` и `bashrt`.

Цепочка:

`bash source -> tokens -> AST -> lowered IR -> generated V -> compiled V binary`

## Границы ответственности

### Что делает `v_scr`

- запуск процессов;
- pipeline и list orchestration;
- cwd, env, stdio;
- файловые и shell-like step helpers.

### Что делает `bashrt`

- переменные и области видимости;
- scalar/indexed/assoc arrays;
- parameter expansion;
- command substitution;
- word splitting;
- quote-aware assembly words;
- часть builtins, если они нужны именно ради Bash semantics.

### Что делает `codegen`

- не принимает синтаксические решения;
- не реализует expansion самостоятельно;
- только переводит IR в вызовы runtime API.

Это важное правило. Если codegen начнет встраивать shell semantics вручную, проект быстро станет хрупким.

## Рекомендуемая структура репозитория

```text
bash2v/
├── v.mod
├── README.md
├── thoughts.md
├── examples/
│   ├── basic.bash
│   ├── arrays.bash
│   ├── nested_subst.bash
│   ├── basic.out.v
│   └── arrays.out.v
├── cmd/
│   └── bash2v/
│       └── main.v
├── bash2v/
│   ├── cli/
│   │   └── cli.v
│   ├── lex/
│   │   ├── token.v
│   │   ├── lexer.v
│   │   ├── lexer_modes.v
│   │   └── lexer_test.v
│   ├── parse/
│   │   ├── parser.v
│   │   ├── parser_commands.v
│   │   ├── parser_words.v
│   │   ├── parser_expansions.v
│   │   └── parser_test.v
│   ├── ast/
│   │   ├── nodes.v
│   │   ├── commands.v
│   │   ├── words.v
│   │   └── print.v
│   ├── lower/
│   │   ├── ir.v
│   │   ├── lower_program.v
│   │   ├── lower_command.v
│   │   ├── lower_word.v
│   │   └── lower_test.v
│   ├── sema/
│   │   ├── symbols.v
│   │   ├── scopes.v
│   │   ├── kinds.v
│   │   └── sema_test.v
│   ├── codegen/
│   │   ├── gen_v.v
│   │   ├── gen_expr.v
│   │   ├── gen_stmt.v
│   │   ├── names.v
│   │   └── codegen_test.v
│   ├── bashrt/
│   │   ├── state.v
│   │   ├── value.v
│   │   ├── array_indexed.v
│   │   ├── array_assoc.v
│   │   ├── expand.v
│   │   ├── expand_param.v
│   │   ├── expand_word.v
│   │   ├── command_subst.v
│   │   ├── split.v
│   │   ├── pattern_replace.v
│   │   ├── case_ops.v
│   │   └── runtime_test.v
│   ├── emit/
│   │   ├── writer.v
│   │   └── format.v
│   └── support/
│       ├── errors.v
│       ├── span.v
│       └── result.v
└── tests/
    ├── fixtures/
    │   ├── expansions/
    │   ├── arrays/
    │   ├── nested/
    │   └── pipelines/
    ├── oracle/
    │   ├── oracle_runner.v
    │   ├── bash_runner.sh
    │   └── compare_test.v
    └── e2e/
        ├── transpile_test.v
        └── compile_run_test.v
```

## Ответственность каталогов

### `cmd/bash2v/`

Точка входа CLI:

- чтение файла;
- выбор режима `transpile`, `check`, `ast`, `ir`;
- запись `.v` результата;
- коды выхода и диагностика.

### `bash2v/lex/`

Лексер Bash. Он обязан быть stateful.

Нужные режимы:

- normal;
- single-quoted;
- double-quoted;
- parameter-expansion body;
- command-substitution body;
- arithmetic body;
- array subscript;
- comment;
- heredoc header и body, если это добавится позже.

Задача лексера:

- не потерять границы вложений;
- отдавать token со `span`;
- различать операторный `$`, `${`, `$(`, `$(("`, `))`, `)` и т.д.

Ориентироваться полезно на реальную семантику Bash 5.1 и при необходимости сверяться с C-исходниками `bash-5.1`, но не копировать их структуру механически.

Ошибка, которой надо избежать:

делать "плоский" lexer как для обычного языка. Для shell это почти всегда ломает nested expansions.

### `bash2v/parse/`

Парсер лучше разделить на два слоя:

1. command parser
   Парсит list, pipeline, simple command, assignment, subshell.
2. word/expansion parser
   Парсит внутреннюю структуру одного shell word.
3. parser должен понимать многострочные команды:
   уметь распознавать, где заканчивается `list` или `pipeline`, и корректно вести себя на многострочных строках с интерполяциями и вложениями.

Это критично, потому что основной уровень сложности Bash живет внутри words, а не в `cmd1 | cmd2`.

### `bash2v/ast/`

AST должен быть максимально близок к исходному Bash.

Нужные сущности верхнего уровня:

- `Program`
- `Stmt`
- `List`
- `Pipeline`
- `SimpleCommand`
- `Assignment`
- `Subshell`

Нужные сущности для words:

- `Word`
- `WordPart`
- `LiteralPart`
- `SingleQuotedPart`
- `DoubleQuotedPart`
- `ParamExpansion`
- `CommandSubstitution`
- `ArithmeticExpansion`

### `bash2v/sema/`

Это не полноценный typechecker, а слой статической классификации:

- scalar vs indexed array vs assoc array;
- известное/неизвестное имя переменной;
- возможная ошибка использования `arr[key]` для indexed array;
- неявные объявления;
- builtin names.

Этот слой нужен, чтобы codegen не гадал.

### `bash2v/lower/`

IR должен быть проще AST. AST сохраняет shell-синтаксис, IR должен делать shell-семантику явной.

Примеры IR-операций:

- `set_var(name, expr)`
- `set_indexed(name, index_expr, value_expr)`
- `set_assoc(name, key_expr, value_expr)`
- `expand_word(parts)`
- `command_subst(command_ir)`
- `exec_external(argv_exprs)`
- `run_pipeline(steps)`
- `run_list(stmts)`

Идея:

AST отвечает на вопрос "что написал пользователь".
IR отвечает на вопрос "что именно нужно выполнить".

### `bash2v/bashrt/`

Это самый важный runtime-модуль.

Он должен содержать:

- shell state;
- типы значений;
- expansion engine;
- command substitution engine;
- word splitting;
- array access helpers;
- substring/case/replace ops;
- quote-aware list of words.

### `bash2v/codegen/`

Codegen берет lowered IR и печатает V.

Требования:

- читаемый V;
- стабильные имена временных переменных;
- минимум скрытой магии;
- один и тот же IR всегда генерирует структурно одинаковый V.

### `tests/oracle/`

Главный источник уверенности.

Для каждого fixture:

1. запускаем исходный Bash под `bash 5.1`;
2. транспилируем в V;
3. компилируем;
4. запускаем бинарь;
5. сравниваем `stdout`, `stderr`, `exit status`, а для специальных тестов еще и snapshots runtime state.
6. результаты работы скрипта bash и транспилированного кода на V складываем рядышком, помечая кем создан stdout (.out), stderr (.err) и return code (.rc)

## AST: рекомендуемые типы

Ниже не финальный синтаксис V, а структура ответственности.

```v
pub struct Program {
    pub:
    stmts []Stmt
}

pub type Stmt
    = SimpleCommand
    | Pipeline
    | List
    | AssignmentStmt
    | Subshell

pub struct SimpleCommand {
    pub:
    assignments []Assignment
    words       []Word
}

pub struct Assignment {
    pub:
    name  string
    kind  AssignKind
    index ?Word
    value Word
}

pub enum AssignKind {
    scalar
    indexed
    assoc
}
```

Для word-подсистемы:

```v
pub struct Word {
    pub:
    parts []WordPart
}

pub type WordPart
    = LiteralPart
    | SingleQuotedPart
    | DoubleQuotedPart
    | ParamExpansion
    | CommandSubstitution
    | ArithmeticExpansion
```

Для `${...}` нужен отдельный тип операций:

```v
pub struct ParamExpansion {
    pub:
    name       string
    indirection bool
    op         ParamOp
}

pub type ParamOp
    = Noop
    | LowerAll
    | ReplaceAll
    | ReplaceOne
    | Length
    | DefaultValue
```

Если попытаться хранить `${VAR//a/b}` как "сырая строка внутри expansion", потом будет тяжело и в lowering, и в тестировании.

## Runtime state

Нужен единый mutable shell state.

```v
pub struct State {
mut:
    vars   map[string]Value
    env    map[string]string
    args   []string
    last_status int
}
```

`Value` должен быть tagged union:

```v
pub type Value
    = Scalar
    | IndexedArray
    | AssocArray

pub struct Scalar {
    pub:
    value string
}

pub struct IndexedArray {
mut:
    items map[int]string
    max_index int
}

pub struct AssocArray {
mut:
    items map[string]string
}
```

Почему не `[]string` для indexed arrays:

- в Bash массивы sparse;
- `arr[10]=x` не должен заполнять `0..9`;
- отрицательные индексы и длины потом проще добавлять поверх sparse representation;
- `${!arr[@]}` удобно реализовывать как ключи map с сортировкой.

## Parameter expansion: отдельная спецификация

Поддерживаемый ранний scope:

- `$VAR`
- `${VAR}`
- `${!VAR}`
- `${VAR,,}`
- `${VAR//a/b}`
- `${#VAR}`
- `${arr[1]}`
- `${map[key]}`
- `${!map[@]}`
- `${!arr[@]}`

Расширения следующего этапа, но не жесткий MVP:

- `${VAR^^}`
- `${VAR/a/b}`
- `${#arr[@]}`

### `${!VAR}`

Это indirect expansion.

Алгоритм:

1. взять значение переменной `VAR` как строку;
2. трактовать это значение как имя другой переменной;
3. вернуть значение второй переменной.

Это не то же самое, что `${!prefix*}` и `${!name[@]}`. Эти формы лучше оформить как отдельные AST/IR cases, не смешивать их в одну ветку.

### `${VAR,,}`

Это case modification.

На MVP достаточно поддержки:

- lower-all: `,,`

Поддержку upper-all `^^` лучше закладывать в shape AST/runtime сразу, но реализовывать уже после стабилизации основного MVP.

Реализация может жить в `case_ops.v`.

### `${VAR//a/b}`

Это pattern replacement, не просто string replace.

Здесь ключевой архитектурный выбор:

- MVP-совместимость: сначала поддержать literal replace;
- Bash-совместимость: затем добавить glob-like pattern replace.

Лучше сразу заложить API как pattern-based, даже если первая реализация будет покрывать literal/simple wildcard cases.

Например:

```v
pub fn replace_all(input string, pattern Pattern, replacement string) string
```

Тогда later upgrade не сломает public shape.

## Множественные вложения команд

Это один из двух самых сложных участков наряду с quote-aware word expansion.

Нужные примеры:

```bash
echo "$(printf '%s' "$(echo hi)")"
v=$(cmd1 "$(cmd2 "$(cmd3)")")
```

Правильная модель:

- `CommandSubstitution` это `WordPart`;
- внутри нее лежит полноценный AST команды;
- parser должен быть рекурсивным;
- runtime обязан уметь выполнить nested command tree;
- результат substitution должен обрезать trailing newlines по Bash rules.

Плохая модель:

- пытаться держать `$()` как сырой текст и потом разбирать отдельно строковыми хаками.

## Word expansion model

Bash сложен не столько из-за команд, сколько из-за "как собирается одно слово".

Нужна функция уровня runtime:

```v
pub fn expand_word(state State, word ast.Word) ![]WordValue
```

Где `WordValue` может быть:

```v
pub struct WordValue {
    pub:
    text   string
    quoted bool
}
```

Это нужно, чтобы потом word splitting применялся только к незакавыченным частям.

Рекомендуемая последовательность:

1. раскрыть `Word.parts` в список fragment-ов;
2. исполнить nested command substitutions;
3. применить parameter expansion;
4. собрать промежуточные значения с quote metadata;
5. выполнить word splitting;
6. вернуть final argv elements.

Если сразу схлопывать все в `string`, будет невозможно корректно смоделировать quoting.

## Lowered IR

AST слишком близок к source syntax. Нужен IR, который будет ближе к исполнению.

Пример:

Исходник:

```bash
name=World
echo "Hello $(printf '%s' "${name,,}")"
```

В IR это должно быть примерно:

1. `set_scalar("name", literal("World"))`
2. `tmp1 = expand_param(lower_all(var("name")))`
3. `tmp2 = command_subst(simple_command("printf", ["%s", tmp1]))`
4. `tmp3 = concat_quoted(["Hello ", tmp2])`
5. `exec_external("echo", [tmp3])`

Это уже легко кодогенерить и тестировать.

## Codegen strategy

Генерация V должна быть максимально прямолинейной.

Например:

```v
mut st := bashrt.new_state()
bashrt.set_scalar(mut st, 'name', 'World')
tmp1 := bashrt.lower_all(bashrt.get_scalar(st, 'name')!)
tmp2 := bashrt.cmd_subst(mut st, fn [tmp1] () !bashrt.ExecResult {
    return bashrt.exec_external(mut st, 'printf', ['%s', tmp1])
})!
tmp3 := bashrt.concat_quoted(['Hello ', tmp2])
bashrt.exec_external(mut st, 'echo', [tmp3])!
```

Это verbose, но:

- отлаживаемо;
- удобно сравнивать с IR;
- проще стабилизировать.

Красивость можно улучшать позже.

## Интеграция с `v_scr`

Рекомендуемая схема:

- `bashrt.exec_external(...)` внутри использует `v_scr.exec(...)`;
- `bashrt.run_pipeline(...)` внутри использует `v_scr.new_pipeline(...)`;
- `bashrt.run_list(...)` внутри использует `v_scr.new_list(...)`.

Важно:

- не генерировать `v_scr.sh("...")` для обычных команд;
- не скармливать shell-строку обратно shell;
- argv должны быть уже окончательно собраны runtime-слоем.

Иначе теряется смысл транспилятора.

## CLI режимы

Полезные команды:

- `bash2v transpile script.sh -o script.v`
- `bash2v check script.sh`
- `bash2v dump-ast script.sh`
- `bash2v dump-ir script.sh`
- `bash2v run script.sh`

`run` можно реализовать как:

1. transpile;
2. compile;
3. execute.

Но это уже вторично относительно parser/runtime.

## MVP scope

### Включить в MVP

- простые команды;
- assignments;
- pipelines;
- command substitution;
- `${VAR}`;
- `${!VAR}`;
- `${VAR,,}`;
- `${VAR//a/b}`;
- `${#VAR}`;
- indexed arrays;
- associative arrays;
- `${arr[idx]}`;
- `${map[key]}`;
- `${!arr[@]}` и `${!map[@]}` как keys enumeration.

### Включить в ближайший следующий этап после MVP

- `${VAR^^}`;
- `${VAR/a/b}`;
- `${#arr[@]}`;
- более полную pattern semantics для replacement;
- дополнительные builtins, если они потребуются для реальных fixture.

### Не брать в MVP

- shell functions;
- heredoc;
- process substitution;
- coprocess;
- traps;
- arithmetic for полноты Bash;
- `[[ ... ]]`, `(( ... ))`;
- brace expansion;
- full glob semantics everywhere;
- alias semantics.

Это нужно жестко зафиксировать, иначе проект размоется.

## Риски

### 1. Перепутать parsing и execution

Нельзя реализовывать expansion "на лету" прямо в parser.

### 2. Схлопнуть quoting слишком рано

Тогда сломаются массивы, nested substitutions и word splitting.

### 3. Делать indexed arrays как `[]string`

Это почти гарантированно приведет к несовместимости со sparse behavior.

### 4. Слишком рано генерировать `sh(...)`

Это даст illusion of progress, но фактически будет shell wrapper, а не transpiler.

### 5. Пытаться покрыть весь Bash

Нужно сфокусироваться на четком подмножестве.

## Тестовая стратегия

Тесты должны быть трех уровней.

### 1. Unit tests

Для:

- lexer;
- parser words;
- parameter expansion;
- arrays;
- replacement/case ops.

### 2. Lowering/codegen tests

Проверять snapshots:

- AST dump;
- IR dump;
- generated V.

### 3. Oracle tests

Fixture запускается и в `bash 5.1`, и в generated V binary.

Сравнивать:

- `stdout`;
- `stderr`;
- `exit code`.

Для array-heavy cases можно добавить специальные диагностики в fixture, чтобы печатать runtime state в нормализованном виде.

## Набор обязательных fixture

### Expansions

```bash
name=HELLO
echo "${name,,}"
```

```bash
x=target
target=ok
echo "${!x}"
```

```bash
v=abracadabra
echo "${v//a/X}"
```

### Nested command substitution

```bash
echo "$(printf '%s' "$(printf '%s' inner)")"
```

```bash
name=HELLO
echo "$(printf '%s' "${name,,}")"
```

### Indexed arrays

```bash
arr[0]=a
arr[5]=b
echo "${arr[0]}:${arr[5]}"
```

### Associative arrays

```bash
declare -A m
m[foo]=bar
m["a b"]=c
echo "${m[foo]}:${m["a b"]}"
```

### Keys expansion

```bash
declare -A m
m[x]=1
m[y]=2
printf '%s\n' "${!m[@]}"
```

Нужно сравнивать с учетом порядка. Если Bash не гарантирует удобный порядок, в test fixture надо сортировать вывод с обеих сторон.

## Порядок реализации

### Этап 1. Каркас проекта

- `v.mod`
- CLI skeleton
- `support/span.v`
- error model
- пустые модули

### Этап 2. Lexer

- tokens;
- spans;
- режимы;
- nested `${...}` и `$()`.

Цель этапа:

уметь без потери структуры токенизировать tricky shell input.

### Этап 3. Word parser

Сначала именно words, не full shell.

Цель этапа:

правильно парсить:

- literals;
- quoted strings;
- `${...}`;
- `$()`;
- array indexes внутри expansions.

### Этап 4. Command parser

- simple command;
- assignment;
- pipeline;
- list;
- subshell.

### Этап 5. Runtime state и values

- scalar;
- indexed;
- assoc;
- getters/setters.

### Этап 6. Expansion engine

- direct;
- indirect;
- lower-all;
- replace-all;
- array refs;
- keys refs.

### Этап 7. Lowering

Сделать IR и явную execution model.

### Этап 8. Codegen

- expr generation;
- stmt generation;
- stable temp names.

### Этап 9. `v_scr` integration

- external exec;
- pipeline;
- list orchestration.

### Этап 10. Oracle tests

- fixture harness;
- bash runner;
- generated V runner.

## Пример ответственности по файлам

### `bash2v/lex/token.v`

- `TokenKind`
- `Token`
- helper constructors

### `bash2v/lex/lexer.v`

- основной scanner
- dispatch по режимам

### `bash2v/parse/parser_words.v`

- `parse_word`
- `parse_word_part`
- `parse_param_expansion`
- `parse_command_substitution`

### `bash2v/parse/parser_commands.v`

- `parse_simple_command`
- `parse_pipeline`
- `parse_list`

### `bash2v/bashrt/value.v`

- `Value`
- `Scalar`
- `IndexedArray`
- `AssocArray`

### `bash2v/bashrt/expand_param.v`

- `${VAR}`
- `${!VAR}`
- `${VAR,,}`
- `${VAR//a/b}`
- `${#VAR}`

### `bash2v/bashrt/command_subst.v`

- execute nested IR/closure;
- collect stdout;
- trim trailing newlines.

### `bash2v/codegen/gen_expr.v`

- generation of value/word expressions;
- temporary variables;
- runtime helper calls.

## Decision log

### Решение 1

Не делать прямой `AST -> V`.

Причина:

без lowered IR будет трудно отделить shell syntax от execution semantics.

### Решение 2

`bashrt` обязателен как отдельный слой.

Причина:

`v_scr` не предназначен для полной Bash semantics, и это нормально.

### Решение 3

Arrays хранить как разные runtime types.

Причина:

scalar/indexed/assoc имеют разную семантику доступа и expansion.

### Решение 4

Quotes и word splitting сохранять до поздней стадии expansion.

Причина:

иначе корректно поддержать nested substitutions почти невозможно.

## Что можно сделать сразу после этого файла

1. Поднять каркас репозитория и `v.mod`.
2. Реализовать `support/span.v`, `lex/token.v`, `lex/lexer.v`.
3. Написать первые parser tests только для words.
4. Не трогать codegen, пока words и expansions не стабилизированы.

## MVP-критерий готовности

MVP можно считать рабочим, когда проходят такие сценарии:

1. `echo "$(printf '%s' "$(echo hi)")"`
2. `x=name; name=VALUE; echo "${!x}"`
3. `name=HELLO; echo "${name,,}"`
4. `v=abracadabra; echo "${v//a/X}"`
5. `arr[0]=a; arr[9]=b; echo "${arr[9]}"`
6. `declare -A m; m[foo]=bar; echo "${m[foo]}"`
7. pipeline из внешних команд компилируется в `v_scr` и дает тот же результат, что Bash.

## Финальная позиция

Проект реалистичен, если держать жесткий MVP.

Главный технический фокус:

- parser words/expansions;
- runtime state for arrays;
- command substitution;
- parameter expansion engine;
- oracle testing against Bash 5.1.

Если эти части сделать правильно, остальная часть проекта уже будет в основном инженерной сборкой вокруг них.
