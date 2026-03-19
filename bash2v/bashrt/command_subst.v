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

pub type EvalStmt = EvalAssignment | EvalExec | EvalPipeline

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
    if result.status != 0 {
        exit(result.status)
    }
}

pub fn run_exec(mut state State, argv []string) ! {
    result := exec_external(mut state, argv)!
    emit_result(result)
}

pub fn run_pipeline_and_emit(mut state State, steps []ExecResult) ! {
    result := exec_pipeline(state, steps)!
    emit_result(result)
}

pub fn run_pipeline_words(mut state State, commands [][]string) ! {
    result := exec_pipeline_words(state, commands)!
    emit_result(result)
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
    }
}

fn eval_exec_capture(mut state State, stmt EvalExec) !ExecResult {
    for item in stmt.assignments {
        apply_eval_assignment(mut state, item)!
    }
    mut argv := []string{}
    for word in stmt.argv {
        argv << eval_word(mut state, word)!
    }
    return exec_external(mut state, argv)
}

fn eval_pipeline_capture(mut state State, stmt EvalPipeline) !ExecResult {
    mut commands := [][]string{}
    for item in stmt.steps {
        mut argv := []string{}
        for word in item.argv {
            argv << eval_word(mut state, word)!
        }
        commands << argv
    }
    return exec_pipeline_words(state, commands)
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
