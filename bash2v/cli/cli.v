module cli

import flag
import os
import bash2v
import bash2v.ast
import bash2v.bundle
import bash2v.lower
import bash2v.support

pub struct Config {
pub:
    mode           string
    input          string
    output         string
    bundle_runtime bool
}

pub fn run(args []string) !int {
    cfg := parse_args(args)!
    match cfg.mode {
        'transpile' {
            return run_transpile(cfg)
        }
        'check' {
            return run_check(cfg)
        }
        'dump-ast', 'ast' {
            return run_dump_ast(cfg)
        }
        'dump-ir', 'ir' {
            return run_dump_ir(cfg)
        }
        'run' {
            return run_execute(cfg)
        }
        else {
            return error('unsupported mode: ${cfg.mode}')
        }
    }
}

fn parse_args(args []string) !Config {
    mut fp := flag.new_flag_parser(args)
    fp.skip_executable()
    fp.application('bash2v')
    fp.arguments_description('<script>')

    transpile_mode := fp.bool('transpile', `t`, false, 'transpile the input script to V',
        flag.FlagConfig{})
    check_mode := fp.bool('check', `c`, false, 'parse and lower the input script without writing output',
        flag.FlagConfig{})
    ast_mode := fp.bool('ast', `a`, false, 'print the parsed AST', flag.FlagConfig{})
    ir_mode := fp.bool('ir', `i`, false, 'print the lowered IR', flag.FlagConfig{})
    run_mode := fp.bool('run', `r`, false, 'transpile and execute the input script', flag.FlagConfig{})
    bundle_runtime := fp.bool('bundle-runtime', `b`, false,
        'write bundled runtime files next to the transpiled output', flag.FlagConfig{})
    output := fp.string('output', `o`, '', 'write generated V to this file', flag.FlagConfig{
        val_desc: '<file>'
    })
    remaining := fp.finalize()!

    mode := resolve_mode(transpile_mode, check_mode, ast_mode, ir_mode, run_mode)!
    if remaining.len == 0 {
        return error('${mode} mode requires an input script')
    }
    if remaining.len > 1 {
        return error('expected exactly one input script')
    }

    mut cfg := Config{
        mode: mode
        input: remaining[0]
        output: output
        bundle_runtime: bundle_runtime
    }

    if cfg.mode == 'transpile' && cfg.output == '' {
        cfg = Config{
            ...cfg
            output: default_output_path(cfg.input)
        }
    }

    return cfg
}

fn resolve_mode(transpile_mode bool, check_mode bool, ast_mode bool, ir_mode bool, run_mode bool) !string {
    mut modes := []string{}
    if transpile_mode {
        modes << 'transpile'
    }
    if check_mode {
        modes << 'check'
    }
    if ast_mode {
        modes << 'ast'
    }
    if ir_mode {
        modes << 'ir'
    }
    if run_mode {
        modes << 'run'
    }
    if modes.len > 1 {
        return error('expected at most one mode flag')
    }
    if modes.len == 0 {
        return 'transpile'
    }
    return modes[0]
}

fn default_output_path(input string) string {
    if input.ends_with('.bash') {
        return input[..input.len - 5] + '.v'
    }
    if input.ends_with('.sh') {
        return input[..input.len - 3] + '.v'
    }
    return input + '.v'
}

fn run_transpile(cfg Config) !int {
    if cfg.input == '' {
        return error('transpile mode requires an input script')
    }
    output_dir := os.dir(cfg.output)
    if output_dir != '' && output_dir != '.' {
        os.mkdir_all(output_dir)!
    }
    source := os.read_file(cfg.input)!
    result := bash2v.transpile_source(source)!
    os.write_file(cfg.output, result.generated)!
    if cfg.bundle_runtime {
        bundle_root := if output_dir == '' { '.' } else { output_dir }
        bundle.write_runtime_bundle(bundle_root)!
    }
    return 0
}

fn run_check(cfg Config) !int {
    if cfg.input == '' {
        return error('check mode requires an input script')
    }
    source := os.read_file(cfg.input)!
    _ := bash2v.transpile_source(source)!
    _ = support.Diagnostic{
        level: .info
        message: 'check mode passed'
    }
    return 0
}

fn run_dump_ast(cfg Config) !int {
    if cfg.input == '' {
        return error('dump-ast mode requires an input script')
    }
    source := os.read_file(cfg.input)!
    result := bash2v.transpile_source(source)!
    println(ast.program_debug(result.program))
    return 0
}

fn run_dump_ir(cfg Config) !int {
    if cfg.input == '' {
        return error('dump-ir mode requires an input script')
    }
    source := os.read_file(cfg.input)!
    result := bash2v.transpile_source(source)!
    println(lower.program_ir_debug(result.lowered))
    return 0
}

fn run_execute(cfg Config) !int {
    if cfg.input == '' {
        return error('run mode requires an input script')
    }
    source := os.read_file(cfg.input)!
    result := bash2v.transpile_source(source)!
    tmp_dir := os.join_path(os.vtmp_dir(), 'bash2v-run')
    os.mkdir_all(tmp_dir)!
    generated_path := os.join_path(tmp_dir, 'generated_run.v')
    os.write_file(generated_path, result.generated)!
    vexe := os.getenv('VEXE')
    v_cmd := if vexe != '' { vexe } else { 'v' }
    run_result := os.execute('cd ${os.getwd()} && ${v_cmd} run ${generated_path}')
    if run_result.output != '' {
        print(run_result.output)
    }
    return run_result.exit_code
}
