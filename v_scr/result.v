module v_scr

import strconv

// RunResult is the immutable output of executing a sequence.
// Example: result := v_scr.exec_pipeline(v_scr.echo('42')) or { return }; _ = result
pub struct RunResult {
pub:
    stdout []u8
    stderr []u8
    status int
}

// bytes returns stdout as raw bytes.
// Example: result := v_scr.exec_pipeline(v_scr.echo('hi')) or { return }; _ = result.bytes()
pub fn (result RunResult) bytes() []u8 {
    return result.stdout.clone()
}

// string returns stdout as a string.
// Example: result := v_scr.exec_pipeline(v_scr.echo('hi')) or { return }; _ = result.string()
pub fn (result RunResult) string() string {
    return result.stdout.bytestr()
}

// stderr_string returns stderr as a string.
// Example: result := v_scr.exec_pipeline(v_scr.stderr()) or { return }; _ = result.stderr_string()
pub fn (result RunResult) stderr_string() string {
    return result.stderr.bytestr()
}

// stderr_bytes returns stderr as raw bytes.
// Example: result := v_scr.exec_pipeline(v_scr.stderr()) or { return }; _ = result.stderr_bytes()
pub fn (result RunResult) stderr_bytes() []u8 {
    return result.stderr.clone()
}

// trimmed_string returns stdout trimmed of leading and trailing whitespace.
// Example: result := v_scr.exec_pipeline(v_scr.echo('  hi  '), v_scr.trim_whitespace()) or { return }; _ = result.trimmed_string()
pub fn (result RunResult) trimmed_string() string {
    return result.string().trim_space()
}

// strings splits trimmed stdout into lines.
// Example: result := v_scr.exec_pipeline(v_scr.echo('a\\nb')) or { return }; _ = result.strings()
pub fn (result RunResult) strings() []string {
    text := result.trimmed_string()
    if text == '' {
        return []string{}
    }
    return text.split_into_lines()
}

// stderr_strings splits trimmed stderr into lines.
// Example: result := v_scr.exec_pipeline(v_scr.echo('warn'), v_scr.stderr()) or { return }; _ = result.stderr_strings()
pub fn (result RunResult) stderr_strings() []string {
    text := result.stderr_string().trim_space()
    if text == '' {
        return []string{}
    }
    return text.split_into_lines()
}

// parse_int parses trimmed stdout as an integer.
// Example: result := v_scr.exec_pipeline(v_scr.echo('42')) or { return }; _ := result.parse_int() or { return }
pub fn (result RunResult) parse_int() !int {
    return strconv.atoi(result.trimmed_string())
}

// okay reports whether the exit status is zero.
// Example: result := v_scr.exec_pipeline(v_scr.echo('ok')) or { return }; _ = result.okay()
pub fn (result RunResult) okay() bool {
    return result.status == 0
}

// status_code returns the final exit status.
// Example: result := v_scr.exec_pipeline(v_scr.echo('ok')) or { return }; _ = result.status_code()
pub fn (result RunResult) status_code() int {
    return result.status
}
