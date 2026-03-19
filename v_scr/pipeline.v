module v_scr

// Pipeline connects stdout of each step to stdin of the next one.
// Example: pipeline := v_scr.new_pipeline(v_scr.echo('a\\nb'), v_scr.count_lines()); _ = pipeline
pub struct Pipeline {
pub:
    steps []Step
}

// new_pipeline builds a reusable streaming sequence.
// Example: pipeline := v_scr.new_pipeline(v_scr.echo('a\\nb'), v_scr.count_lines()); _ = pipeline
pub fn new_pipeline(steps ...Step) Pipeline {
    return Pipeline{
        steps: steps
    }
}

// exec_pipeline is a convenience helper for constructing and running a pipeline.
// Example: result := v_scr.exec_pipeline(v_scr.echo('a\\nb'), v_scr.count_lines()) or { return }; _ = result
pub fn exec_pipeline(steps ...Step) !RunResult {
    return new_pipeline(...steps).exec()
}

// exec runs the pipeline in a fresh Pipe.
// Example: result := v_scr.new_pipeline(v_scr.echo('a\\nb'), v_scr.count_lines()).exec() or { return }; _ = result
pub fn (pipeline Pipeline) exec() !RunResult {
    mut pipe := new_pipe()
    return pipeline.run_into(mut pipe)
}

// call runs the pipeline in a fresh Pipe with positional args preset.
// Example: result := v_scr.new_pipeline(v_scr.echo('$1')).call('demo') or { return }; _ = result
pub fn (pipeline Pipeline) call(args ...string) !RunResult {
    mut pipe := new_pipe()
    pipe.args = args.clone()
    return pipeline.run_into(mut pipe)
}

// invoke wraps the pipeline as a step and temporarily overrides positional args.
// Example: nested := v_scr.new_pipeline(v_scr.echo('$1')).invoke('demo'); _ := nested
pub fn (pipeline Pipeline) invoke(args ...string) Step {
    values := args.clone()
    return fn [pipeline, values] (mut pipe Pipe) ! {
        result := run_sequence_with_args(mut pipe, pipeline, values)!
        apply_result(mut pipe, result)
    }
}

// run_into executes the pipeline inside an existing Pipe context.
// Example: mut pipe := v_scr.new_pipe(); result := v_scr.new_pipeline(v_scr.echo('ok')).run_into(mut pipe) or { return }; _ = result
pub fn (pipeline Pipeline) run_into(mut pipe Pipe) !RunResult {
    run_steps(mut pipe, pipeline.steps, .pipeline)!
    return pipe.result()
}
