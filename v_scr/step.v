module v_scr

// Step is a single executable unit that mutates the current Pipe state.
// Example: step := v_scr.echo('hello'); _ := step
pub type Step = fn (mut Pipe) !

// Sequence is a reusable ordered collection of steps such as Pipeline or List.
// Example: sequence := v_scr.new_pipeline(v_scr.echo('hello')); _ := sequence
pub interface Sequence {
    exec() !RunResult
    run_into(mut pipe Pipe) !RunResult
}
