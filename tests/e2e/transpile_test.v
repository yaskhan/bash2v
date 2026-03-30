module e2e

import os
import bash2v.cli

fn test_transpile_writes_generated_v_file() {
    tmp_dir := os.join_path(os.vtmp_dir(), 'bash2v-e2e')
    os.mkdir_all(tmp_dir) or { panic(err) }

    input_path := os.join_path(tmp_dir, 'input.bash')
    output_path := os.join_path(tmp_dir, 'input.v')

    os.write_file(input_path, r'name=World
echo "${name,,}"
') or { panic(err) }
    exit_code := cli.run(['bash2v', input_path]) or { panic(err) }
    generated := os.read_file(output_path) or { panic(err) }

    assert exit_code == 0
    assert generated.contains('module main')
    assert generated.contains('import bash2v.bashrt')
    assert generated.contains("bashrt.set_scalar(mut st, 'name'")
    assert generated.contains('bashrt.eval_word(mut st, bashrt.Word')
}

fn test_transpile_with_bundle_runtime_writes_self_contained_bundle() {
    tmp_dir := os.join_path(os.vtmp_dir(), 'bash2v-bundle-e2e')
    if os.exists(tmp_dir) {
        os.rmdir_all(tmp_dir) or { panic(err) }
    }
    os.mkdir_all(tmp_dir) or { panic(err) }

    input_path := os.join_path(tmp_dir, 'hello.sh')
    output_path := os.join_path(tmp_dir, 'hello.v')

    os.write_file(input_path, 'echo hello-bundled\n') or { panic(err) }
    exit_code := cli.run(['bash2v', '-t', '-b', input_path]) or {
        panic(err)
    }

    assert exit_code == 0
    assert os.exists(output_path)
    assert os.exists(os.join_path(tmp_dir, 'v.mod'))
    assert os.exists(os.join_path(tmp_dir, 'bash2v', 'bashrt', 'state.v'))
    assert os.exists(os.join_path(tmp_dir, 'v_scr', 'pipeline.v'))

    mut proc := os.new_process('v')
    proc.set_args(['run', './hello.v'])
    proc.set_work_folder(tmp_dir)
    proc.set_redirect_stdio()
    proc.run()
    proc.wait()
    result := os.Result{
        exit_code: proc.code
        output: proc.stdout_slurp()
    }
    proc.close()
    assert result.exit_code == 0
    assert result.output == 'hello-bundled\n'
}

fn test_cli_run_executes_script() {
    base_dir := os.getwd()
    tmp_dir := os.join_path(base_dir, 'tests', 'e2e', 'tmp')
    os.mkdir_all(tmp_dir) or { panic(err) }

    input_path := os.join_path(tmp_dir, 'cli_run_input.bash')
    os.write_file(input_path, 'echo hello-from-cli\n') or { panic(err) }

    mut process := os.new_process('v')
    process.set_args(['run', 'cmd/bash2v', '-r', input_path])
    process.set_work_folder(os.getwd())
    process.set_redirect_stdio()
    process.run()
    process.wait()
    result := os.Result{
        exit_code: process.code
        output: process.stdout_slurp()
    }
    process.close()
    assert result.exit_code == 0
    assert result.output == 'hello-from-cli\n'
}
