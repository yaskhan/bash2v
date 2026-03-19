module v_scr

enum SequenceMode {
    pipeline
    list
}

fn run_steps(mut pipe Pipe, steps []Step, mode SequenceMode) ! {
    mut stdout_accum := if mode == .list { pipe.stdout.clone() } else { []u8{} }
    mut stderr_accum := pipe.stderr.clone()
    if mode == .list {
        pipe.stdout = []u8{}
    }
    pipe.stderr = []u8{}
    for index, step in steps {
        if pipe.stopped {
            break
        }
        if mode == .pipeline && index > 0 {
            pipe.stdin = pipe.stdout.clone()
            pipe.stdout = []u8{}
        }
        step(mut pipe)!
        if pipe.stderr.len > 0 {
            stderr_accum << pipe.stderr.clone()
            pipe.stderr = []u8{}
        }
        if mode == .list && pipe.stdout.len > 0 {
            stdout_accum << pipe.stdout.clone()
            pipe.stdout = []u8{}
        }
        if pipe.stopped {
            break
        }
    }
    if mode == .list {
        pipe.stdout = stdout_accum
    }
    pipe.stderr = stderr_accum
}

fn run_sequence_with_args(mut pipe Pipe, sequence Sequence, args []string) !RunResult {
    expanded_args := expand_all(args, pipe)
    saved_args := pipe.args.clone()
    saved_stopped := pipe.stopped
    saved_stop_kind := pipe.stop_kind
    defer {
        pipe.args = saved_args
        if pipe.stop_kind == .return_only {
            pipe.stopped = saved_stopped
            pipe.stop_kind = saved_stop_kind
        }
    }
    pipe.args = expanded_args
    return sequence.run_into(mut pipe)
}
