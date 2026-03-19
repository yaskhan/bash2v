module v_scr

import os

// mkdir creates a step that ensures a directory exists.
// Example: _ := v_scr.mkdir('/tmp/demo', 0o755)
pub fn mkdir(path string, mode u32) Step {
    return fn [path, mode] (mut pipe Pipe) ! {
        _ = mode
        os.mkdir_all(expand(path, pipe))!
        pipe.status = 0
    }
}

// rm_file creates a step that removes a file if it exists.
// Example: _ := v_scr.rm_file('/tmp/demo.txt')
pub fn rm_file(path string) Step {
    return rm(path)
}

// rm_dir creates a step that removes a directory tree if it exists.
// Example: _ := v_scr.rm_dir('/tmp/demo-dir')
pub fn rm_dir(path string) Step {
    return rmdir('-r', path)
}

// rm removes files and optionally directories with `-r`, while `-f` ignores missing paths and `-q` suppresses stderr.
// Example: _ := v_scr.rm('-f', '/tmp/demo.txt')
pub fn rm(args ...string) Step {
    values := args.clone()
    return fn [values] (mut pipe Pipe) ! {
        config := parse_rm_args(values, pipe)
        if config.paths.len == 0 {
            set_rm_failure(mut pipe, config.quiet, 'rm: missing operand')
            return
        }
        mut status := 0
        for raw_path in config.paths {
            path := expand(raw_path, pipe)
            if !os.exists(path) {
                if config.force {
                    continue
                }
                status = 1
                append_rm_error(mut pipe, config.quiet, 'rm: cannot remove `${path}`: No such file or directory')
                continue
            }
            if os.is_dir(path) {
                if !config.recursive {
                    status = 1
                    append_rm_error(mut pipe, config.quiet, 'rm: cannot remove `${path}`: Is a directory')
                    continue
                }
                os.rmdir_all(path) or {
                    status = 1
                    append_rm_error(mut pipe, config.quiet, 'rm: cannot remove `${path}`: ${err.msg()}')
                }
                continue
            }
            os.rm(path) or {
                status = 1
                append_rm_error(mut pipe, config.quiet, 'rm: cannot remove `${path}`: ${err.msg()}')
            }
        }
        pipe.status = status
    }
}

// rmdir removes directories, using `-r` for recursive deletion, `-f` to ignore missing paths, and `-q` to suppress stderr.
// Example: _ := v_scr.rmdir('-r', '-f', '/tmp/demo-dir')
pub fn rmdir(args ...string) Step {
    values := args.clone()
    return fn [values] (mut pipe Pipe) ! {
        config := parse_rm_args(values, pipe)
        if config.paths.len == 0 {
            set_rm_failure(mut pipe, config.quiet, 'rmdir: missing operand')
            return
        }
        mut status := 0
        for raw_path in config.paths {
            path := expand(raw_path, pipe)
            if !os.exists(path) {
                if config.force {
                    continue
                }
                status = 1
                append_rm_error(mut pipe, config.quiet, 'rmdir: failed to remove `${path}`: No such file or directory')
                continue
            }
            if !os.is_dir(path) {
                status = 1
                append_rm_error(mut pipe, config.quiet, 'rmdir: failed to remove `${path}`: Not a directory')
                continue
            }
            if config.recursive {
                os.rmdir_all(path) or {
                    status = 1
                    append_rm_error(mut pipe, config.quiet, 'rmdir: failed to remove `${path}`: ${err.msg()}')
                }
            } else {
                os.rmdir(path) or {
                    status = 1
                    append_rm_error(mut pipe, config.quiet, 'rmdir: failed to remove `${path}`: ${err.msg()}')
                }
            }
        }
        pipe.status = status
    }
}

// touch creates a step that creates an empty file when it does not exist.
// Example: _ := v_scr.touch('/tmp/demo.txt')
pub fn touch(path string) Step {
    return fn [path] (mut pipe Pipe) ! {
        expanded := expand(path, pipe)
        if !os.exists(expanded) {
            os.write_file(expanded, '')!
        }
        pipe.status = 0
    }
}

// chmod creates a step that changes file permissions.
// Example: _ := v_scr.chmod('/tmp/demo.txt', 0o644)
pub fn chmod(path string, mode u32) Step {
    return fn [path, mode] (mut pipe Pipe) ! {
        os.chmod(expand(path, pipe), int(mode))!
        pipe.status = 0
    }
}

// test_filepath_exists creates a step that succeeds when the path exists.
// Example: _ := v_scr.test_filepath_exists('/tmp/demo.txt')
pub fn test_filepath_exists(path string) Step {
    return fn [path] (mut pipe Pipe) ! {
        expanded := expand(path, pipe)
        exists := os.exists(expanded)
        pipe.stdout = expanded.bytes()
        pipe.status = if exists { 0 } else { 1 }
    }
}

// exists is a short alias for test_filepath_exists.
// Example: _ := v_scr.exists('/tmp/demo.txt')
pub fn exists(path string) Step {
    return test_filepath_exists(path)
}

// test_empty creates a step that succeeds when the active stream is empty.
// Example: _ := v_scr.test_empty()
pub fn test_empty() Step {
    return fn (mut pipe Pipe) ! {
        pipe.status = if active_stream(pipe).len == 0 { 0 } else { 1 }
    }
}

// empty is a short alias for test_empty.
// Example: _ := v_scr.empty()
pub fn empty() Step {
    return test_empty()
}

// test_not_empty creates a step that succeeds when the active stream is not empty.
// Example: _ := v_scr.test_not_empty()
pub fn test_not_empty() Step {
    return fn (mut pipe Pipe) ! {
        pipe.status = if active_stream(pipe).len > 0 { 0 } else { 1 }
    }
}

// non_empty is a short alias for test_not_empty.
// Example: _ := v_scr.non_empty()
pub fn non_empty() Step {
    return test_not_empty()
}

struct RmConfig {
mut:
    recursive bool
    force     bool
    quiet     bool
    paths     []string
}

fn parse_rm_args(args []string, pipe Pipe) RmConfig {
    mut config := RmConfig{
        paths: []string{}
    }
    for arg in args {
        expanded := expand(arg, pipe)
        if is_rm_flag(expanded) {
            apply_rm_flag(mut config, expanded)
            continue
        }
        config.paths << expanded
    }
    return config
}

fn is_rm_flag(arg string) bool {
    return arg.len > 1 && arg[0] == `-`
}

fn apply_rm_flag(mut config RmConfig, arg string) {
    for ch in arg[1..] {
        match ch {
            `r` { config.recursive = true }
            `f` { config.force = true }
            `q` { config.quiet = true }
            else {}
        }
    }
}

fn set_rm_failure(mut pipe Pipe, quiet bool, message string) {
    append_rm_error(mut pipe, quiet, message)
    pipe.status = 1
}

fn append_rm_error(mut pipe Pipe, quiet bool, message string) {
    if quiet {
        return
    }
    if pipe.stderr.len > 0 {
        pipe.stderr << '\n'.bytes()
    }
    pipe.stderr << message.bytes()
}
