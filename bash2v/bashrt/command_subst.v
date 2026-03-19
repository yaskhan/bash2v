module bashrt

import bash2v.lower
import v_scr

pub struct ExecResult {
pub:
    stdout string
    stderr string
    status int
}

pub enum EvalValueKind {
    scalar
    indexed
    assoc
}

pub struct EvalAssignment {
pub:
    name     string
    kind     EvalValueKind = .scalar
    index    ?Word
    append   bool
    compound bool
    expr     Word
    items    []Word
}

pub struct EvalExec {
pub:
    assignments []EvalAssignment
    argv         []Word
}

pub struct EvalPipeline {
pub:
    steps []EvalExec
}

pub enum EvalLogicalOp {
    and_if
    or_if
}

pub struct EvalAndOrArm {
pub:
    op      EvalLogicalOp
    program EvalProgram
}

pub struct EvalAndOr {
pub:
    first EvalProgram
    items []EvalAndOrArm
}

pub type EvalStmt = EvalAssignment | EvalExec | EvalPipeline | EvalAndOr

pub struct EvalProgram {
pub:
    stmts []EvalStmt
}

pub fn cmd_subst(_mut_state &State, _program lower.ProgramIR) !string {
    return ''
}

pub fn eval_command_subst(mut state State, fragment CommandSubstFragment) !string {
    result := eval_program_capture(mut state, fragment.program)!
    return trim_command_subst(result.stdout)
}

pub fn exec_external(mut state State, argv []string) !ExecResult {
    if argv.len == 0 {
        return ExecResult{}
    }
    if argv[0] == 'declare' {
        return exec_declare(mut state, argv[1..])
    }
    if argv[0] in ['test', '[', '[['] {
        return exec_condition(argv)
    }
    if argv[0] == 'true' {
        return ExecResult{}
    }
    if argv[0] == 'false' {
        return ExecResult{
            status: 1
        }
    }
    cmd := argv[0]
    args := argv[1..]
    mut pipe := v_scr.new_pipe()
    pipe.env = state.env.clone()
    result := v_scr.new_pipeline(
        v_scr.exec(cmd, ...args),
    ).run_into(mut pipe)!
    return ExecResult{
        stdout: result.string()
        stderr: result.stderr_string()
        status: result.status_code()
    }
}

pub fn exec_pipeline_words(state State, commands [][]string) !ExecResult {
    if commands.len == 0 {
        return ExecResult{}
    }
    mut steps := []v_scr.Step{}
    for argv in commands {
        if argv.len == 0 {
            continue
        }
        steps << v_scr.exec(argv[0], ...argv[1..])
    }
    mut pipe := v_scr.new_pipe()
    pipe.env = state.env.clone()
    result := v_scr.new_pipeline(...steps).run_into(mut pipe)!
    return ExecResult{
        stdout: result.string()
        stderr: result.stderr_string()
        status: result.status_code()
    }
}

pub fn exec_pipeline(_mut_state &State, steps []ExecResult) !ExecResult {
    if steps.len == 0 {
        return ExecResult{}
    }
    return steps[steps.len - 1]
}

pub fn emit_result(result ExecResult) {
    if result.stdout != '' {
        print(result.stdout)
    }
    if result.stderr != '' {
        eprint(result.stderr)
    }
}

pub fn run_exec(mut state State, argv []string) ! {
    result := exec_external(mut state, argv)!
    state.last_status = result.status
    emit_result(result)
}

pub fn eval_words_to_argv(mut state State, words []Word) ![]string {
    mut argv := []string{}
    for word in words {
        argv << eval_word_values(mut state, word)!
    }
    return argv
}

pub fn run_exec_words(mut state State, words []Word) ! {
    argv := eval_words_to_argv(mut state, words)!
    result := exec_external(mut state, argv)!
    state.last_status = result.status
    emit_result(result)
}

pub fn run_pipeline_and_emit(mut state State, steps []ExecResult) ! {
    result := exec_pipeline(state, steps)!
    state.last_status = result.status
    emit_result(result)
}

pub fn run_pipeline_words(mut state State, commands [][]string) ! {
    result := exec_pipeline_words(state, commands)!
    state.last_status = result.status
    emit_result(result)
}

pub fn run_pipeline_word_parts(mut state State, commands [][]Word) ! {
    mut expanded := [][]string{}
    for command in commands {
        expanded << eval_words_to_argv(mut state, command)!
    }
    result := exec_pipeline_words(state, expanded)!
    state.last_status = result.status
    emit_result(result)
}

pub fn run_and_or(mut state State, stmt EvalAndOr) ! {
    result := eval_and_or_capture(mut state, stmt)!
    state.last_status = result.status
    emit_result(result)
}

pub fn exit_with_last_status(state State) {
    if state.last_status != 0 {
        exit(state.last_status)
    }
}

pub fn eval_program_status(mut state State, program EvalProgram) !int {
    result := eval_program_capture(mut state, program)!
    if result.stdout != '' {
        print(result.stdout)
    }
    if result.stderr != '' {
        eprint(result.stderr)
    }
    state.last_status = result.status
    return result.status
}

pub fn eval_program_condition(mut state State, program EvalProgram) !int {
    result := eval_program_capture(mut state, program)!
    if result.stdout != '' {
        print(result.stdout)
    }
    if result.stderr != '' {
        eprint(result.stderr)
    }
    return result.status
}

pub fn set_last_status(mut state State, status int) {
    state.last_status = status
}

fn eval_program_capture(mut state State, program EvalProgram) !ExecResult {
    mut stdout := []string{}
    mut stderr := []string{}
    mut status := 0
    for stmt in program.stmts {
        result := eval_stmt_capture(mut state, stmt)!
        if result.stdout != '' {
            stdout << result.stdout
        }
        if result.stderr != '' {
            stderr << result.stderr
        }
        status = result.status
    }
    return ExecResult{
        stdout: stdout.join('')
        stderr: stderr.join('')
        status: status
    }
}

fn eval_stmt_capture(mut state State, stmt EvalStmt) !ExecResult {
    return match stmt {
        EvalAssignment {
            apply_eval_assignment(mut state, stmt)!
            ExecResult{}
        }
        EvalExec {
            eval_exec_capture(mut state, stmt)!
        }
        EvalPipeline {
            eval_pipeline_capture(mut state, stmt)!
        }
        EvalAndOr {
            eval_and_or_capture(mut state, stmt)!
        }
    }
}

fn eval_exec_capture(mut state State, stmt EvalExec) !ExecResult {
    for item in stmt.assignments {
        apply_eval_assignment(mut state, item)!
    }
    argv := eval_words_to_argv(mut state, stmt.argv)!
    return exec_external(mut state, argv)
}

fn eval_pipeline_capture(mut state State, stmt EvalPipeline) !ExecResult {
    mut commands := [][]string{}
    for item in stmt.steps {
        commands << eval_words_to_argv(mut state, item.argv)!
    }
    return exec_pipeline_words(state, commands)
}

fn eval_and_or_capture(mut state State, stmt EvalAndOr) !ExecResult {
    mut current := eval_program_capture(mut state, stmt.first)!
    mut stdout := []string{}
    mut stderr := []string{}
    if current.stdout != '' {
        stdout << current.stdout
    }
    if current.stderr != '' {
        stderr << current.stderr
    }
    for item in stmt.items {
        should_run := match item.op {
            .and_if { current.status == 0 }
            .or_if { current.status != 0 }
        }
        if !should_run {
            continue
        }
        current = eval_program_capture(mut state, item.program)!
        if current.stdout != '' {
            stdout << current.stdout
        }
        if current.stderr != '' {
            stderr << current.stderr
        }
    }
    return ExecResult{
        stdout: stdout.join('')
        stderr: stderr.join('')
        status: current.status
    }
}

fn apply_eval_assignment(mut state State, stmt EvalAssignment) ! {
    if stmt.compound {
        mut values := []string{}
        for item in stmt.items {
            values << eval_word(mut state, item)!
        }
        match stmt.kind {
            .indexed {
                if stmt.append {
                    append_indexed_values(mut state, stmt.name, values)
                } else {
                    set_indexed_values(mut state, stmt.name, values)
                }
                return
            }
            .scalar, .assoc {
                return error('unsupported compound assignment for ${stmt.name}')
            }
        }
    }
    value := eval_word(mut state, stmt.expr)!
    match stmt.kind {
        .scalar {
            if stmt.append {
                append_scalar(mut state, stmt.name, value)
            } else {
                set_scalar(mut state, stmt.name, value)
            }
        }
        .indexed {
            index := if idx_word := stmt.index {
                eval_word(mut state, idx_word)!
            } else {
                ''
            }
            if stmt.append {
                if stmt.index != none {
                    append_indexed_at(mut state, stmt.name, index, value)
                } else {
                    append_indexed_values(mut state, stmt.name, [value])
                }
            } else {
                set_indexed(mut state, stmt.name, index, value)
            }
        }
        .assoc {
            index := if idx_word := stmt.index {
                eval_word(mut state, idx_word)!
            } else {
                ''
            }
            if stmt.append {
                append_assoc(mut state, stmt.name, index, value)
            } else {
                set_assoc(mut state, stmt.name, index, value)
            }
        }
    }
}

fn trim_command_subst(input string) string {
    mut out := input
    for out.ends_with('\n') {
        out = out[..out.len - 1]
    }
    return out
}

fn exec_declare(mut state State, args []string) ExecResult {
    if args.len >= 2 && args[0] == '-A' {
        declare_assoc(mut state, args[1])
        return ExecResult{}
    }
    if args.len >= 2 && args[0] == '-a' {
        declare_indexed(mut state, args[1])
        return ExecResult{}
    }
    return ExecResult{}
}
