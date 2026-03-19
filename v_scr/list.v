module v_scr

// List runs steps sequentially while accumulating shared stdout and stderr.
// Example: list := v_scr.new_list(v_scr.echo('a'), v_scr.echo('b')); _ = list
pub struct List {
pub:
    steps []Step
}

// new_list builds a reusable sequential group of steps.
// Example: list := v_scr.new_list(v_scr.echo('a'), v_scr.echo('b')); _ = list
pub fn new_list(steps ...Step) List {
    return List{
        steps: steps
    }
}

// exec_list is a convenience helper for constructing and running a list.
// Example: result := v_scr.exec_list(v_scr.echo('a'), v_scr.echo('b')) or { return }; _ = result
pub fn exec_list(steps ...Step) !RunResult {
    return new_list(...steps).exec()
}

// exec runs the list in a fresh Pipe.
// Example: result := v_scr.new_list(v_scr.echo('a'), v_scr.echo('b')).exec() or { return }; _ = result
pub fn (list List) exec() !RunResult {
    mut pipe := new_pipe()
    return list.run_into(mut pipe)
}

// call runs the list in a fresh Pipe with positional args preset.
// Example: result := v_scr.new_list(v_scr.echo('$1')).call('demo') or { return }; _ = result
pub fn (list List) call(args ...string) !RunResult {
    mut pipe := new_pipe()
    pipe.args = args.clone()
    return list.run_into(mut pipe)
}

// invoke wraps the list as a step and temporarily overrides positional args.
// Example: nested := v_scr.new_list(v_scr.echo('$1')).invoke('demo'); _ := nested
pub fn (list List) invoke(args ...string) Step {
    values := args.clone()
    return fn [list, values] (mut pipe Pipe) ! {
        result := run_sequence_with_args(mut pipe, list, values)!
        apply_result(mut pipe, result)
    }
}

// run_into executes the list inside an existing Pipe context.
// Example: mut pipe := v_scr.new_pipe(); result := v_scr.new_list(v_scr.echo('ok')).run_into(mut pipe) or { return }; _ = result
pub fn (list List) run_into(mut pipe Pipe) !RunResult {
    run_steps(mut pipe, list.steps, .list)!
    return pipe.result()
}
