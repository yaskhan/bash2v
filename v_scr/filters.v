module v_scr

import os
import regex
import regex.pcre

struct GrepPConfig {
mut:
	pattern     string
	files       []string
	invert      bool
	number      bool
	ignore_case bool
	count       bool
	quiet       bool
}

// trim_whitespace creates a step that trims leading and trailing whitespace.
// Example: _ := v_scr.trim_whitespace()
pub fn trim_whitespace() Step {
	return fn (mut pipe Pipe) ! {
		pipe.stdout = pipe.stdin.bytestr().trim_space().bytes()
		pipe.status = 0
	}
}

// count_lines creates a step that counts input lines.
// Example: _ := v_scr.count_lines()
pub fn count_lines() Step {
	return fn (mut pipe Pipe) ! {
		text := pipe.stdin.bytestr()
		count := if text == '' { 0 } else { text.split_into_lines().len }
		pipe.stdout = count.str().bytes()
		pipe.status = 0
	}
}

// count_words creates a step that counts whitespace-delimited words.
// Example: _ := v_scr.count_words()
pub fn count_words() Step {
	return fn (mut pipe Pipe) ! {
		count := pipe.stdin.bytestr().fields().len
		pipe.stdout = count.str().bytes()
		pipe.status = 0
	}
}

// grep creates a substring filter over the current stream.
// Example: _ := v_scr.grep('error') or { panic(err) }
pub fn grep(pattern string) !Step {
	return fn [pattern] (mut pipe Pipe) ! {
		lines := pipe.stdin.bytestr().split_into_lines()
		mut matched := []string{}
		for line in lines {
			if line.contains(pattern) {
				matched << line
			}
		}
		pipe.stdout = matched.join('\n').bytes()
		pipe.status = if matched.len > 0 { 0 } else { 1 }
	}
}

// grep_v creates an inverted substring filter over the current stream.
// Example: _ := v_scr.grep_v('debug') or { panic(err) }
pub fn grep_v(pattern string) !Step {
	return fn [pattern] (mut pipe Pipe) ! {
		lines := pipe.stdin.bytestr().split_into_lines()
		mut matched := []string{}
		for line in lines {
			if !line.contains(pattern) {
				matched << line
			}
		}
		pipe.stdout = matched.join('\n').bytes()
		pipe.status = if matched.len > 0 { 0 } else { 1 }
	}
}

// grep_r creates a lightweight regex filter over the current stream.
// Example: _ := v_scr.grep_r('^warn') or { panic(err) }
pub fn grep_r(pattern string) !Step {
	mut re := regex.regex_opt(pattern)!
	return fn [mut re] (mut pipe Pipe) ! {
		lines := pipe.stdin.bytestr().split_into_lines()
		mut matched := []string{}
		for line in lines {
			if re.matches_string(line) {
				matched << line
			}
		}
		pipe.stdout = matched.join('\n').bytes()
		pipe.status = if matched.len > 0 { 0 } else { 1 }
	}
}

// grep_r_v creates an inverted lightweight regex filter over the current stream.
// Example: _ := v_scr.grep_r_v('^debug') or { panic(err) }
pub fn grep_r_v(pattern string) !Step {
	mut re := regex.regex_opt(pattern)!
	return fn [mut re] (mut pipe Pipe) ! {
		lines := pipe.stdin.bytestr().split_into_lines()
		mut matched := []string{}
		for line in lines {
			if !re.matches_string(line) {
				matched << line
			}
		}
		pipe.stdout = matched.join('\n').bytes()
		pipe.status = if matched.len > 0 { 0 } else { 1 }
	}
}

// grep_p creates a shell-like PCRE grep with flags and optional file arguments.
// Example: _ := v_scr.grep_p('-in', '^warn', 'app.log') or { panic(err) }
pub fn grep_p(args ...string) !Step {
	values := args.clone()
	config := parse_grep_p_args(values)!
	mut pattern := config.pattern
	if config.ignore_case {
		pattern = '(?i)${pattern}'
	}
	re := pcre.new_regex(pattern, 0)!
	return fn [config, re] (mut pipe Pipe) ! {
		mut lines := []string{}
		mut line_labels := []string{}
		mut found := false
		mut matches := []string{}
		mut match_count := 0

		if config.files.len == 0 {
			stdin_lines := active_stream(pipe).bytestr().split_into_lines()
			for idx, line in stdin_lines {
				lines << line
				line_labels << format_grep_p_label('', idx + 1, config.number, false)
			}
		} else {
			multi_file := config.files.len > 1
			for file in config.files {
				expanded_file := expand(file, pipe)
				file_lines := os.read_file(expanded_file)!.split_into_lines()
				for idx, line in file_lines {
					lines << line
					line_labels << format_grep_p_label(expanded_file, idx + 1, config.number, multi_file)
				}
			}
		}

		for idx, line in lines {
			matched := grep_p_line_matches(re, line)
			include := if config.invert { !matched } else { matched }
			if !include {
				continue
			}
			found = true
			match_count++
			if config.quiet {
				break
			}
			if config.count {
				continue
			}
			label := line_labels[idx]
			if label == '' {
				matches << line
			} else {
				matches << '${label}${line}'
			}
		}

		if config.quiet {
			pipe.stdout = []u8{}
			pipe.status = if found { 0 } else { 1 }
			return
		}
		if config.count {
			pipe.stdout = match_count.str().bytes()
			pipe.status = if found { 0 } else { 1 }
			return
		}
		pipe.stdout = matches.join('\n').bytes()
		pipe.status = if found { 0 } else { 1 }
	}
}

// grep_p_v creates an inverted shell-like PCRE grep.
// Example: _ := v_scr.grep_p_v('^debug', 'app.log') or { panic(err) }
pub fn grep_p_v(args ...string) !Step {
	mut values := ['-v']
	values << args.clone()
	return grep_p(...values)
}

// sed creates a step that delegates to the external `sed` command.
// Example: _ := v_scr.sed('s/a/A/g') or { panic(err) }
pub fn sed(args ...string) !Step {
    values := args.clone()
    if values.len == 0 {
        return error('sed() expects at least one sed argument')
    }
    return fn [values] (mut pipe Pipe) ! {
        run_process(mut pipe, 'sed', values)!
    }
}

// sed_r creates a GNU sed step with `-r` enabled.
// Example: _ := v_scr.sed_r('s/(a+)/A/g') or { panic(err) }
pub fn sed_r(args ...string) !Step {
    mut values := ['-r']
    values << args.clone()
    return sed(...values)
}

// sed_r_z creates a GNU sed step with `-r -z` enabled.
// Example: _ := v_scr.sed_r_z('s/a/A/g') or { panic(err) }
pub fn sed_r_z(args ...string) !Step {
    mut values := ['-r', '-z']
    values << args.clone()
    return sed(...values)
}

// head creates a step that keeps the first n input lines, or all but the last abs(n) lines when n is negative.
// Example: _ := v_scr.head(5)
pub fn head(n int) Step {
    return fn [n] (mut pipe Pipe) ! {
        lines := pipe.stdin.bytestr().split_into_lines()
        if n >= 0 {
            limit := if n < lines.len { n } else { lines.len }
            pipe.stdout = lines[..limit].join('\n').bytes()
            pipe.status = 0
            return
        }
        exclude := imin(-n, lines.len)
        pipe.stdout = lines[..lines.len - exclude].join('\n').bytes()
        pipe.status = 0
    }
}

// tail creates a step that keeps the last n input lines, or skips the first abs(n) lines when n is negative.
// Example: _ := v_scr.tail(5)
pub fn tail(n int) Step {
    return fn [n] (mut pipe Pipe) ! {
        lines := pipe.stdin.bytestr().split_into_lines()
        if n >= 0 {
            start := if n < lines.len { lines.len - n } else { 0 }
            pipe.stdout = lines[start..].join('\n').bytes()
            pipe.status = 0
            return
        }
        skip := imin(-n, lines.len)
        pipe.stdout = lines[skip..].join('\n').bytes()
        pipe.status = 0
    }
}

// uniq creates a step that removes duplicate lines while preserving order.
// Example: _ := v_scr.uniq()
pub fn uniq() Step {
    return fn (mut pipe Pipe) ! {
        lines := pipe.stdin.bytestr().split_into_lines()
        mut seen := map[string]bool{}
        mut output := []string{}
        for line in lines {
            if line in seen {
                continue
            }
            seen[line] = true
            output << line
        }
        pipe.stdout = output.join('\n').bytes()
        pipe.status = 0
    }
}

// sort creates a step that sorts lines in ascending order.
// Example: _ := v_scr.sort()
pub fn sort() Step {
    return fn (mut pipe Pipe) ! {
        mut lines := pipe.stdin.bytestr().split_into_lines()
        lines.sort()
        pipe.stdout = lines.join('\n').bytes()
        pipe.status = 0
    }
}

// rsort creates a step that sorts lines in descending order.
// Example: _ := v_scr.rsort()
pub fn rsort() Step {
    return fn (mut pipe Pipe) ! {
        mut lines := pipe.stdin.bytestr().split_into_lines()
        lines.sort()
        lines.reverse_in_place()
        pipe.stdout = lines.join('\n').bytes()
        pipe.status = 0
    }
}

// basename creates a step that maps each input line to its base path component.
// Example: _ := v_scr.basename()
pub fn basename() Step {
    return fn (mut pipe Pipe) ! {
        lines := pipe.stdin.bytestr().split_into_lines()
        mut output := []string{}
        for line in lines {
            output << os.base(line)
        }
        pipe.stdout = output.join('\n').bytes()
        pipe.status = 0
    }
}

// dirname creates a step that maps each input line to its directory component.
// Example: _ := v_scr.dirname()
pub fn dirname() Step {
    return fn (mut pipe Pipe) ! {
        lines := pipe.stdin.bytestr().split_into_lines()
        mut output := []string{}
        for line in lines {
            output << os.dir(line)
        }
        pipe.stdout = output.join('\n').bytes()
        pipe.status = 0
    }
}

// strip_extension creates a step that removes the final file extension from each line.
// Example: _ := v_scr.strip_extension()
pub fn strip_extension() Step {
    return fn (mut pipe Pipe) ! {
        lines := pipe.stdin.bytestr().split_into_lines()
        mut output := []string{}
        for line in lines {
            output << replace_extension(line, '')
        }
        pipe.stdout = output.join('\n').bytes()
        pipe.status = 0
    }
}

// swap_extensions creates a step that replaces one extension with another.
// Example: _ := v_scr.swap_extensions('.txt', '.md')
pub fn swap_extensions(old_ext string, new_ext string) Step {
    return fn [old_ext, new_ext] (mut pipe Pipe) ! {
        lines := pipe.stdin.bytestr().split_into_lines()
        mut output := []string{}
        for line in lines {
            if line.ends_with(old_ext) {
                output << line[..line.len - old_ext.len] + new_ext
            } else {
                output << replace_extension(line, new_ext)
            }
        }
        pipe.stdout = output.join('\n').bytes()
        pipe.status = 0
    }
}

fn replace_extension(path string, replacement string) string {
    file_name := os.file_name(path)
    idx := file_name.last_index('.') or { -1 }
    if idx <= 0 {
        if replacement == '' {
            return path
        }
        return path + replacement
    }
    base_name := file_name[..idx]
    dir_name := os.dir(path)
    new_name := base_name + replacement
    return if dir_name == '.' { new_name } else { os.join_path(dir_name, new_name) }
}

fn parse_grep_p_args(args []string) !GrepPConfig {
	if args.len == 0 {
		return error('grep_p() expects at least a pattern')
	}
	mut config := GrepPConfig{
		files: []string{}
	}
	mut pattern_found := false
	for arg in args {
		if !pattern_found && is_grep_p_flag(arg) {
			apply_grep_p_flag(mut config, arg)!
			continue
		}
		if !pattern_found {
			config.pattern = arg
			pattern_found = true
			continue
		}
		config.files << arg
	}
	if config.pattern == '' {
		return error('grep_p() expects a pattern')
	}
	return config
}

fn is_grep_p_flag(arg string) bool {
	return arg.len > 1 && arg[0] == `-`
}

fn apply_grep_p_flag(mut config GrepPConfig, arg string) ! {
	if arg == '--' {
		return error('grep_p(): `--` is not supported yet')
	}
	for ch in arg[1..] {
		match ch {
			`v` { config.invert = true }
			`n` { config.number = true }
			`i` { config.ignore_case = true }
			`c` { config.count = true }
			`q` { config.quiet = true }
			else { return error('grep_p(): unsupported flag `-${ch.ascii_str()}`') }
		}
	}
}

fn format_grep_p_label(file string, line_no int, with_number bool, with_file bool) string {
	mut parts := []string{}
	if with_file {
		parts << file
	}
	if with_number {
		parts << line_no.str()
	}
	if parts.len == 0 {
		return ''
	}
	return parts.join(':') + ':'
}

fn grep_p_line_matches(re pcre.Regex, line string) bool {
	re.find(line) or { return false }
	return true
}

fn imin(a int, b int) int {
	return if a < b { a } else { b }
}
