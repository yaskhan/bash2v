module v_scr

import os

// expand resolves shell-like variables against the current pipe context.
// Example: _ = v_scr.expand(r'$HOME', v_scr.new_pipe())
pub fn expand(input string, pipe Pipe) string {
    mut result := []u8{cap: input.len}
    mut i := 0
    for i < input.len {
        if input[i] != `$` {
            result << input[i]
            i++
            continue
        }
        if i + 1 >= input.len {
            result << `$`
            break
        }
        next := input[i + 1]
        if next == `{` {
            end := find_closing_brace(input, i + 2)
            if end == -1 {
                result << `$`
                i++
                continue
            }
            expr := input[i + 2..end]
            value := resolve_braced(expr, pipe)
            result << value.bytes()
            i = end + 1
            continue
        }
        if next == `*` {
            result << pipe.args.join(' ').bytes()
            i += 2
            continue
        }
        if next == `#` {
            result << pipe.args.len.str().bytes()
            i += 2
            continue
        }
        if is_digit(next) {
            idx := next - `0`
            result << resolve_arg(idx, pipe).bytes()
            i += 2
            continue
        }
        if is_var_start(next) {
            mut end := i + 1
            for end < input.len && is_var_char(input[end]) {
                end++
            }
            name := input[i + 1..end]
            result << resolve_name(name, pipe).bytes()
            i = end
            continue
        }
        result << `$`
        i++
    }
    return result.bytestr()
}

// expand_all resolves shell-like variables for every string in a slice.
// Example: _ = v_scr.expand_all([r'$HOME'], v_scr.new_pipe())
pub fn expand_all(values []string, pipe Pipe) []string {
    mut expanded := []string{cap: values.len}
    for value in values {
        expanded << expand(value, pipe)
    }
    return expanded
}

// set_args creates a step that replaces positional args for the current sequence.
// Example: _ := v_scr.set_args('one', 'two')
pub fn set_args(args ...string) Step {
    values := args.clone()
    return fn [values] (mut pipe Pipe) ! {
        pipe.args = expand_all(values, pipe)
        pipe.status = 0
    }
}

// args is a short alias for set_args.
// Example: _ := v_scr.args('one', 'two')
pub fn args(args ...string) Step {
    return set_args(...args)
}

// set_env_var creates a step that sets or updates an environment variable.
// Example: _ := v_scr.set_env_var('APP_ENV', 'dev')
pub fn set_env_var(name string, value string) Step {
    return fn [name, value] (mut pipe Pipe) ! {
        pipe.env[name] = expand(value, pipe)
        pipe.status = 0
    }
}

// env is a short alias for set_env_var.
// Example: _ := v_scr.env('APP_ENV', 'dev')
pub fn env(name string, value string) Step {
    return set_env_var(name, value)
}

// unset_env_var creates a step that removes an environment variable override.
// Example: _ := v_scr.unset_env_var('APP_ENV')
pub fn unset_env_var(name string) Step {
    return fn [name] (mut pipe Pipe) ! {
        pipe.env.delete(name)
        pipe.status = 0
    }
}

// set_local creates a step that sets a local shell-like variable.
// Example: _ := v_scr.set_local('name', 'demo')
pub fn set_local(name string, value string) Step {
    return fn [name, value] (mut pipe Pipe) ! {
        pipe.locals[name] = expand(value, pipe)
        pipe.status = 0
    }
}

// local_ is a short alias for set_local.
// Example: _ := v_scr.local_('name', 'demo')
pub fn local_(name string, value string) Step {
    return set_local(name, value)
}

// unset_local creates a step that removes a local shell-like variable.
// Example: _ := v_scr.unset_local('name')
pub fn unset_local(name string) Step {
    return fn [name] (mut pipe Pipe) ! {
        pipe.locals.delete(name)
        pipe.status = 0
    }
}

// set_cwd creates a step that changes the working directory for later process steps.
// Example: _ := v_scr.set_cwd('/tmp')
pub fn set_cwd(path string) Step {
    return fn [path] (mut pipe Pipe) ! {
        pipe.cwd = expand(path, pipe)
        pipe.status = 0
    }
}

// cd is a short alias for set_cwd.
// Example: _ := v_scr.cd('/tmp')
pub fn cd(path string) Step {
    return set_cwd(path)
}

// set_trace creates a step that enables or disables lightweight process tracing.
// Example: _ := v_scr.set_trace(true)
pub fn set_trace(enabled bool) Step {
    return fn [enabled] (mut pipe Pipe) ! {
        pipe.trace = enabled
        pipe.status = 0
    }
}

// unset_trace creates a step that disables lightweight process tracing.
// Example: _ := v_scr.unset_trace()
pub fn unset_trace() Step {
    return set_trace(false)
}

fn merged_environment(pipe Pipe) map[string]string {
    mut envs := os.environ()
    for key, value in pipe.env {
        envs[key] = value
    }
    return envs
}

fn resolve_braced(expr string, pipe Pipe) string {
    if expr.len > 1 && expr[0] == `!` {
        target := resolve_name(expr[1..], pipe)
        return resolve_name(target, pipe)
    }
    return resolve_name(expr, pipe)
}

fn resolve_name(name string, pipe Pipe) string {
    if name in pipe.locals {
        return pipe.locals[name]
    }
    if name == '*' {
        return pipe.args.join(' ')
    }
    if name == '#' {
        return pipe.args.len.str()
    }
    if name.len == 1 && is_digit(name[0]) {
        return resolve_arg(name[0] - `0`, pipe)
    }
    if name in pipe.env {
        return pipe.env[name]
    }
    return ''
}

fn resolve_arg(index u8, pipe Pipe) string {
    if index == 0 {
        return ''
    }
    if int(index) > pipe.args.len {
        return ''
    }
    return pipe.args[int(index) - 1]
}

fn find_closing_brace(input string, start int) int {
    for i := start; i < input.len; i++ {
        if input[i] == `}` {
            return i
        }
    }
    return -1
}

fn is_digit(ch u8) bool {
    return ch >= `0` && ch <= `9`
}

fn is_var_start(ch u8) bool {
    return is_alpha(ch) || ch == `_`
}

fn is_var_char(ch u8) bool {
    return is_alpha(ch) || is_digit(ch) || ch == `_`
}

fn is_alpha(ch u8) bool {
    return (ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`)
}
