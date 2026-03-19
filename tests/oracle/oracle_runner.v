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
    tmp_dir := os.join_path('/home/margo/dev/bash2v', 'tests', 'oracle', 'tmp')
    os.mkdir_all(tmp_dir)!
    script_path := os.join_path(tmp_dir, '${filename}.bash')
    stdout_path := os.join_path(tmp_dir, '${filename}.bash.out')
    stderr_path := os.join_path(tmp_dir, '${filename}.bash.err')
    os.write_file(script_path, source)!
    result := os.execute('cd /home/margo/dev/bash2v && bash ${script_path} > ${stdout_path} 2> ${stderr_path}')
    return OracleResult{
        stdout: os.read_file(stdout_path) or { '' }
        stderr: os.read_file(stderr_path) or { '' }
        status: result.exit_code
    }
}

pub fn run_transpiled_source(filename string, source string) !OracleResult {
    tmp_dir := os.join_path('/home/margo/dev/bash2v', 'tests', 'oracle', 'tmp')
    os.mkdir_all(tmp_dir)!
    generated_path := os.join_path(tmp_dir, '${filename}.v')
    stdout_path := os.join_path(tmp_dir, '${filename}.v.out')
    stderr_path := os.join_path(tmp_dir, '${filename}.v.err')
    transpiled := bash2v.transpile_source(source)!
    os.write_file(generated_path, transpiled.generated)!
    result := os.execute('cd /home/margo/dev/bash2v && v run ${generated_path} > ${stdout_path} 2> ${stderr_path}')
    return OracleResult{
        stdout: os.read_file(stdout_path) or { '' }
        stderr: os.read_file(stderr_path) or { '' }
        status: result.exit_code
    }
}
