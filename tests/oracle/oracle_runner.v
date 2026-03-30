module oracle

import os
import bash2v

pub struct OracleResult {
pub:
    stdout string
    stderr string
    status int
}

pub fn run_bash_source(filename string, source string) !OracleResult {
    tmp_dir := os.join_path('/app', 'tests', 'oracle', 'tmp')
    os.mkdir_all(tmp_dir)!
    script_path := os.join_path(tmp_dir, '${filename}.bash')
    stdout_path := os.join_path(tmp_dir, '${filename}.bash.out')
    stderr_path := os.join_path(tmp_dir, '${filename}.bash.err')
    os.write_file(script_path, source)!
    mut process := os.new_process('bash')
    process.set_args([script_path])
    process.set_work_folder(os.getwd())
    process.set_redirect_stdio()
    process.run()
    process.wait()
    stdout := process.stdout_slurp()
    stderr := process.stderr_slurp()
    exit_code := process.code
    process.close()
    return OracleResult{
        stdout: stdout
        stderr: stderr
        status: exit_code
    }
}

pub fn run_transpiled_source(filename string, source string) !OracleResult {
    tmp_dir := os.join_path('/app', 'tests', 'oracle', 'tmp')
    os.mkdir_all(tmp_dir)!
    generated_path := os.join_path(tmp_dir, '${filename}.v')
    stdout_path := os.join_path(tmp_dir, '${filename}.v.out')
    stderr_path := os.join_path(tmp_dir, '${filename}.v.err')
    transpiled := bash2v.transpile_source(source)!
    os.write_file(generated_path, transpiled.generated)!
    mut process := os.new_process('v')
    process.set_args(['run', generated_path])
    process.set_work_folder(os.getwd())
    process.set_redirect_stdio()
    process.run()
    process.wait()
    stdout := process.stdout_slurp()
    stderr := process.stderr_slurp()
    exit_code := process.code
    process.close()
    return OracleResult{
        stdout: stdout
        stderr: stderr
        status: exit_code
    }
}
