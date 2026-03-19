module v_scr

import os

type OutputTarget = os.File | string

enum RedirectStream {
	stdout
	stderr
}

enum ResolvedTargetKind {
	stdout
	stderr
	file
	devnull
}

struct ResolvedTarget {
	kind ResolvedTargetKind
	path string
}

// stdout creates a step that prints the active stream, overwrites a file, discards to `/dev/null`,
// or redirects to stderr when passed `os.stderr()`.
// Example: _ := v_scr.stdout('/tmp/demo.txt')
pub fn stdout(args ...OutputTarget) Step {
	targets := args.clone()
	return fn [targets] (mut pipe Pipe) ! {
		data := active_stream(pipe)
		target := resolve_output_target(targets, .stdout, pipe)!
		apply_redirect(mut pipe, data, .stdout, target, false)!
		pipe.status = 0
	}
}

// stdout_a creates a step that appends the active stream to a file.
// Example: _ := v_scr.stdout_a('/tmp/demo.txt')
pub fn stdout_a(path string) Step {
	return fn [path] (mut pipe Pipe) ! {
		data := active_stream(pipe)
		target := resolve_output_target([OutputTarget(path)], .stdout, pipe)!
		apply_redirect(mut pipe, data, .stdout, target, true)!
		pipe.status = 0
	}
}

// to_stdout is a compatibility alias for stdout().
// Example: _ := v_scr.to_stdout()
pub fn to_stdout() Step {
	return stdout()
}

// stderr creates a step that prints the active stream to stderr, overwrites a file,
// discards to `/dev/null`, or redirects to stdout when passed `os.stdout()`.
// Example: _ := v_scr.stderr('/tmp/demo.err')
pub fn stderr(args ...OutputTarget) Step {
	targets := args.clone()
	return fn [targets] (mut pipe Pipe) ! {
		data := active_stream(pipe)
		target := resolve_output_target(targets, .stderr, pipe)!
		apply_redirect(mut pipe, data, .stderr, target, false)!
		pipe.status = 0
	}
}

// stderr_a creates a step that appends the active stream to a file while retaining stderr capture.
// Example: _ := v_scr.stderr_a('/tmp/demo.err')
pub fn stderr_a(path string) Step {
	return fn [path] (mut pipe Pipe) ! {
		data := active_stream(pipe)
		target := resolve_output_target([OutputTarget(path)], .stderr, pipe)!
		apply_redirect(mut pipe, data, .stderr, target, true)!
		pipe.status = 0
	}
}

// to_stderr is a compatibility alias for stderr().
// Example: _ := v_scr.to_stderr()
pub fn to_stderr() Step {
	return stderr()
}

// write_to_file creates a step that writes the active stream to a file.
// Example: _ := v_scr.write_to_file('/tmp/demo.txt')
pub fn write_to_file(path string) Step {
	return fn [path] (mut pipe Pipe) ! {
		os.write_file(expand(path, pipe), active_stream(pipe).bytestr())!
		pipe.status = 0
	}
}

// to_file is a short alias for write_to_file.
// Example: _ := v_scr.to_file('/tmp/demo.txt')
pub fn to_file(path string) Step {
	return write_to_file(path)
}

// to_f is a short alias for write_to_file.
// Example: _ := v_scr.to_f('/tmp/demo.txt')
pub fn to_f(path string) Step {
	return write_to_file(path)
}

// append_to_file creates a step that appends the active stream to a file.
// Example: _ := v_scr.append_to_file('/tmp/demo.txt')
pub fn append_to_file(path string) Step {
	return fn [path] (mut pipe Pipe) ! {
		expanded := expand(path, pipe)
		existing := os.read_file(expanded) or { '' }
		os.write_file(expanded, existing + active_stream(pipe).bytestr())!
		pipe.status = 0
	}
}

// append_file is a short alias for append_to_file.
// Example: _ := v_scr.append_file('/tmp/demo.txt')
pub fn append_file(path string) Step {
	return append_to_file(path)
}

// append_f is a short alias for append_to_file.
// Example: _ := v_scr.append_f('/tmp/demo.txt')
pub fn append_f(path string) Step {
	return append_to_file(path)
}

// return_ stops the current sequence with the provided status.
// Example: _ := v_scr.return_(1)
pub fn return_(status int) Step {
	return fn [status] (mut pipe Pipe) ! {
		pipe.status = status
		pipe.stopped = true
		pipe.stop_kind = .return_only
	}
}

// exit_ stops the outer sequence with the provided status.
// Example: _ := v_scr.exit_(1)
pub fn exit_(status int) Step {
	return fn [status] (mut pipe Pipe) ! {
		pipe.status = status
		pipe.stopped = true
		pipe.stop_kind = .exit_all
	}
}

fn resolve_output_target(args []OutputTarget, default_kind ResolvedTargetKind, pipe Pipe) !ResolvedTarget {
	if args.len == 0 {
		return ResolvedTarget{
			kind: default_kind
		}
	}
	if args.len > 1 {
		return error('output helpers expect at most one explicit target')
	}
	target := args[0]
	match target {
		string {
			expanded := expand(target, pipe)
			if expanded == '' {
				return ResolvedTarget{
					kind: default_kind
				}
			}
			if expanded == os.path_devnull {
				return ResolvedTarget{
					kind: .devnull
				}
			}
			return ResolvedTarget{
				kind: .file
				path: expanded
			}
		}
		os.File {
			if target.fd == os.stdout().fd {
				return ResolvedTarget{
					kind: .stdout
				}
			}
			if target.fd == os.stderr().fd {
				return ResolvedTarget{
					kind: .stderr
				}
			}
			return error('only os.stdout() and os.stderr() are supported as stream targets')
		}
	}
}

fn apply_redirect(mut pipe Pipe, data []u8, source RedirectStream, target ResolvedTarget, append bool) ! {
	match source {
		.stdout {
			match target.kind {
				.stdout {
					print(data.bytestr())
				}
				.stderr {
					eprint(data.bytestr())
					pipe.stderr << data
					pipe.stdout = []u8{}
				}
				.file {
					write_stream_to_file(target.path, data, append)!
				}
				.devnull {
					pipe.stdout = []u8{}
				}
			}
		}
		.stderr {
			match target.kind {
				.stdout {
					print(data.bytestr())
					pipe.stdout = data.clone()
				}
				.stderr {
					eprint(data.bytestr())
					pipe.stderr << data
					pipe.stdout = []u8{}
				}
				.file {
					write_stream_to_file(target.path, data, append)!
					pipe.stderr << data
					pipe.stdout = []u8{}
				}
				.devnull {
					pipe.stdout = []u8{}
				}
			}
		}
	}
}

fn write_stream_to_file(path string, data []u8, append bool) ! {
	if append {
		existing := os.read_file(path) or { '' }
		os.write_file(path, existing + data.bytestr())!
		return
	}
	os.write_file(path, data.bytestr())!
}
