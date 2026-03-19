module e2e

import os
import bash2v.cli

fn test_transpile_writes_generated_v_file() {
    tmp_dir := os.join_path(os.vtmp_dir(), 'bash2v-e2e')
    os.mkdir_all(tmp_dir) or { panic(err) }

    input_path := os.join_path(tmp_dir, 'input.bash')
    output_path := os.join_path(tmp_dir, 'output.v')

    os.write_file(input_path, r'name=World
echo "${name,,}"
') or { panic(err) }
    exit_code := cli.run(['bash2v', 'transpile', input_path, '-o', output_path]) or { panic(err) }
    generated := os.read_file(output_path) or { panic(err) }

    assert exit_code == 0
    assert generated.contains('module main')
    assert generated.contains('import bash2v.bashrt')
    assert generated.contains("bashrt.set_scalar(mut st, 'name'")
    assert generated.contains('bashrt.eval_word(mut st, bashrt.Word')
}

fn test_cli_run_executes_script() {
    tmp_dir := os.join_path('/home/margo/dev/bash2v', 'tests', 'e2e', 'tmp')
    os.mkdir_all(tmp_dir) or { panic(err) }

    input_path := os.join_path(tmp_dir, 'cli_run_input.bash')
    os.write_file(input_path, 'echo hello-from-cli\n') or { panic(err) }

    result := os.execute('cd /home/margo/dev/bash2v && v run cmd/bash2v run ${input_path}')
    assert result.exit_code == 0
    assert result.output == 'hello-from-cli\n'
}
