module v_scr

import os

// exec creates a step that runs an external command with expanded args.
// Example: _ := v_scr.exec('printf', '%s', 'hello')
pub fn exec(cmd string, args ...string) Step {
    values := args.clone()
    return fn [cmd, values] (mut pipe Pipe) ! {
        run_process(mut pipe, cmd, values)!
    }
}

// sh creates a step that runs a shell command line after expansion.
// Example: _ := v_scr.sh('printf "%s" "hello"')
pub fn sh(line string) Step {
    return fn [line] (mut pipe Pipe) ! {
        expanded := expand(line, pipe)
        $if windows {
            run_process(mut pipe, 'cmd.exe', ['/c', expanded])!
        } $else {
            shell := os.getenv('SHELL')
            shell_cmd := if shell == '' { '/bin/sh' } else { shell }
            run_process(mut pipe, shell_cmd, ['-c', expanded])!
        }
    }
}

fn run_process(mut pipe Pipe, cmd string, args []string) ! {
    expanded_cmd := expand(cmd, pipe)
    expanded_args := expand_all(args, pipe)
    executable := resolve_executable(expanded_cmd) or {
        pipe.stdout = []u8{}
        pipe.stderr = 'command not found: ${expanded_cmd}'.bytes()
        pipe.status = 127
        return
    }
    mut process := os.new_process(executable)
    process.set_args(expanded_args)
    if pipe.cwd != '' {
        process.set_work_folder(expand(pipe.cwd, pipe))
    }
    if pipe.env.len > 0 {
        process.set_environment(merged_environment(pipe))
    }
    process.set_redirect_stdio()
    if pipe.trace {
        eprintln('v_scr exec: ${expanded_cmd} ${expanded_args.join(" ")}')
    }
    process.run()
    input_data := active_stream(pipe)
    if input_data.len > 0 {
        process.stdin_write(input_data.bytestr())
    }
    close_process_stdin(mut process)
    process.wait()
    pipe.stdout = process.stdout_slurp().bytes()
    pipe.stderr = process.stderr_slurp().bytes()
    pipe.status = process.code
    process.close()
}

fn resolve_executable(cmd string) !string {
    if cmd.contains(os.path_separator.str()) || os.is_abs_path(cmd) {
        return cmd
    }
    return os.find_abs_path_of_executable(cmd)
}

fn close_process_stdin(mut process os.Process) {
    $if windows {
        return
    } $else {
        stdin_index := int(os.ChildProcessPipeKind.stdin)
        if process.stdio_fd[stdin_index] > 0 {
            os.fd_close(process.stdio_fd[stdin_index])
            process.stdio_fd[stdin_index] = 0
        }
    }
}
