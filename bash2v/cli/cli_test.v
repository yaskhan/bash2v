module cli

fn test_parse_args_defaults_to_transpile_mode() {
    cfg := parse_args(['bash2v', 'script.sh']) or { panic(err) }

    assert cfg.mode == 'transpile'
    assert cfg.input == 'script.sh'
    assert cfg.output == 'script.v'
}

fn test_parse_args_replaces_bash_extension_for_default_output() {
    cfg := parse_args(['bash2v', 'script.bash']) or { panic(err) }

    assert cfg.output == 'script.v'
}

fn test_parse_args_appends_v_when_input_has_no_shell_extension() {
    cfg := parse_args(['bash2v', 'script']) or { panic(err) }

    assert cfg.output == 'script.v'
}

fn test_parse_args_supports_short_mode_flags() {
    check_cfg := parse_args(['bash2v', '-c', 'script.sh']) or { panic(err) }
    ast_cfg := parse_args(['bash2v', '-a', 'script.sh']) or { panic(err) }
    ir_cfg := parse_args(['bash2v', '-i', 'script.sh']) or { panic(err) }
    run_cfg := parse_args(['bash2v', '-r', 'script.sh']) or { panic(err) }
    transpile_cfg := parse_args(['bash2v', '-t', 'script.sh']) or { panic(err) }

    assert check_cfg.mode == 'check'
    assert ast_cfg.mode == 'ast'
    assert ir_cfg.mode == 'ir'
    assert run_cfg.mode == 'run'
    assert transpile_cfg.mode == 'transpile'
}

fn test_parse_args_rejects_multiple_mode_flags() {
    _ := parse_args(['bash2v', '-t', '-r', 'script.sh']) or {
        assert err.msg() == 'expected at most one mode flag'
        return
    }
    panic('expected parse_args to fail for multiple mode flags')
}

fn test_parse_args_keeps_explicit_output_and_bundle_runtime() {
    cfg := parse_args(['bash2v', '-t', '--bundle-runtime', 'script.sh', '-o', 'out/result.v']) or {
        panic(err)
    }

    assert cfg.mode == 'transpile'
    assert cfg.output == 'out/result.v'
    assert cfg.bundle_runtime == true
}
