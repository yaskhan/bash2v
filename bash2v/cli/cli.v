module cli

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
    if args.len < 2 {
        return Config{
            mode: 'check'
        }
    }
    mut cfg := Config{
        mode: args[1]
    }
    mut i := 2
    for i < args.len {
        arg := args[i]
        if arg == '--bundle-runtime' {
            cfg = Config{
                ...cfg
                bundle_runtime: true
            }
            i++
            continue
        }
        if arg == '-o' && i + 1 < args.len {
            cfg = Config{
                ...cfg
                output: args[i + 1]
            }
            i += 2
            continue
        }
        if cfg.input == '' {
            cfg = Config{
                ...cfg
                input: arg
            }
        }
        i++
    }
    return cfg
}

fn run_transpile(cfg Config) !int {
    if cfg.input == '' {
        return error('transpile mode requires an input script')
    }
    if cfg.output == '' {
        return error('transpile mode requires -o <file>')
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
    run_result := os.execute('cd ${os.getwd()} && v run ${generated_path}')
    if run_result.output != '' {
        print(run_result.output)
    }
    return run_result.exit_code
}
