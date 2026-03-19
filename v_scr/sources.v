module v_scr

import os

// echo creates a step that writes expanded text to the current output stream.
// Example: _ := v_scr.echo('hello')
pub fn echo(input string) Step {
    return fn [input] (mut pipe Pipe) ! {
        pipe.stdout = expand(input, pipe).bytes()
        pipe.status = 0
    }
}

// echo_args creates a step that joins positional args with spaces.
// Example: _ := v_scr.echo_args()
pub fn echo_args() Step {
    return fn (mut pipe Pipe) ! {
        pipe.stdout = pipe.args.join(' ').bytes()
        pipe.status = 0
    }
}

// cat creates a step that reads a file, or forwards stdin when no path is given.
// Example: _ := v_scr.cat('/tmp/demo.txt')
pub fn cat(args ...string) Step {
    values := args.clone()
    return fn [values] (mut pipe Pipe) ! {
        path := if values.len > 0 { expand(values[0], pipe) } else { '' }
        if path == '' {
            pipe.stdout = pipe.stdin.clone()
            pipe.status = 0
            return
        }
        contents := os.read_file(path)!
        pipe.stdout = contents.bytes()
        pipe.status = 0
    }
}

// cat_file is a compatibility alias for cat(path).
// Example: _ := v_scr.cat_file('/tmp/demo.txt')
pub fn cat_file(path string) Step {
    return cat(path)
}

// cat_stdin creates a step that forwards stdin into stdout.
// Example: _ := v_scr.cat_stdin()
pub fn cat_stdin() Step {
    return cat()
}

// from_file is a short alias for cat_file.
// Example: _ := v_scr.from_file('/tmp/demo.txt')
pub fn from_file(path string) Step {
    return cat(path)
}

// from_f is a short alias for cat_file.
// Example: _ := v_scr.from_f('/tmp/demo.txt')
pub fn from_f(path string) Step {
    return cat(path)
}

// which creates a step that resolves an executable from PATH.
// Example: _ := v_scr.which('v')
pub fn which(cmd string) Step {
    return fn [cmd] (mut pipe Pipe) ! {
        expanded := expand(cmd, pipe)
        resolved := os.find_abs_path_of_executable(expanded) or {
            pipe.stdout = []u8{}
            pipe.stderr = 'command not found: ${expanded}'.bytes()
            pipe.status = 1
            return
        }
        pipe.stdout = resolved.bytes()
        pipe.status = 0
    }
}

// list_files creates a step that lists directory entries separated by newlines.
// Example: _ := v_scr.list_files('.')
pub fn list_files(args ...string) Step {
    values := args.clone()
    return fn [values] (mut pipe Pipe) ! {
        expanded := if values.len > 0 { expand(values[0], pipe) } else { '.' }
        mut files := os.ls(expanded)!
        files.sort()
        pipe.stdout = files.join('\n').bytes()
        pipe.status = 0
    }
}

// ls is a short alias for list_files.
// Example: _ := v_scr.ls('.')
pub fn ls(args ...string) Step {
    return list_files(...args)
}

// ls_l delegates to the external `ls -l` command for long-format output.
// Example: _ := v_scr.ls_l('.')
pub fn ls_l(args ...string) Step {
    path := if args.len > 0 { args[0] } else { '.' }
    return exec('ls', '-l', path)
}

// pwd creates a step that prints the current working directory context.
// Example: _ := v_scr.pwd()
pub fn pwd() Step {
    return fn (mut pipe Pipe) ! {
        cwd := if pipe.cwd != '' { pipe.cwd } else { os.getwd() }
        pipe.stdout = cwd.bytes()
        pipe.status = 0
    }
}
