module v_scr

enum StopKind {
    none
    return_only
    exit_all
}

// Pipe carries the mutable execution state shared by steps in a sequence.
// Example: mut pipe := v_scr.new_pipe(); _ = pipe
pub struct Pipe {
pub mut:
    stdin  []u8
    stdout []u8
    stderr []u8
    status int
    cwd    string
    env    map[string]string
    args   []string
    locals map[string]string
    trace  bool
    stopped bool
    stop_kind StopKind
}

// new_pipe creates an empty execution context with zero status and empty env.
// Example: pipe := v_scr.new_pipe(); _ = pipe
pub fn new_pipe() Pipe {
    return Pipe{
        status: 0
        env: map[string]string{}
        args: []string{}
        locals: map[string]string{}
        stopped: false
        stop_kind: .none
    }
}

// result snapshots the current pipe state into a RunResult value.
// Example: mut pipe := v_scr.new_pipe(); result := pipe.result(); _ = result
pub fn (p Pipe) result() RunResult {
    return RunResult{
        stdout: p.stdout.clone()
        stderr: p.stderr.clone()
        status: p.status
    }
}

fn (p Pipe) snapshot() Pipe {
    return Pipe{
        stdin: p.stdin.clone()
        stdout: p.stdout.clone()
        stderr: p.stderr.clone()
        status: p.status
        cwd: p.cwd
        env: p.env.clone()
        args: p.args.clone()
        locals: p.locals.clone()
        trace: p.trace
        stopped: p.stopped
        stop_kind: p.stop_kind
    }
}

fn apply_result(mut pipe Pipe, result RunResult) {
    pipe.stdout = result.stdout.clone()
    pipe.stderr = result.stderr.clone()
    pipe.status = result.status
}

fn active_stream(pipe Pipe) []u8 {
    if pipe.stdout.len > 0 {
        return pipe.stdout.clone()
    }
    return pipe.stdin.clone()
}
