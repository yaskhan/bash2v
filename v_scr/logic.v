module v_scr

// pipe builds an inline nested Pipeline step.
// Example: _ := v_scr.pipe(v_scr.echo('a\\nb'), v_scr.count_lines())
pub fn pipe(steps ...Step) Step {
    return run_pipeline(new_pipeline(...steps))
}

// group builds an inline nested List step.
// Example: _ := v_scr.group(v_scr.echo('a'), v_scr.echo('b'))
pub fn group(steps ...Step) Step {
    return run_list(new_list(...steps))
}

// run_pipeline wraps a Pipeline so it can be used as a Step.
// Example: _ := v_scr.run_pipeline(v_scr.new_pipeline(v_scr.echo('a\\nb'), v_scr.count_lines()))
pub fn run_pipeline(pipeline Pipeline) Step {
    return fn [pipeline] (mut pipe Pipe) ! {
        result := pipeline.run_into(mut pipe)!
        apply_result(mut pipe, result)
    }
}

// run_list wraps a List so it can be used as a Step.
// Example: _ := v_scr.run_list(v_scr.new_list(v_scr.echo('a'), v_scr.echo('b')))
pub fn run_list(list List) Step {
    return fn [list] (mut pipe Pipe) ! {
        result := list.run_into(mut pipe)!
        apply_result(mut pipe, result)
    }
}

// and_ runs a sequence only when the current status is zero.
// Example: _ := v_scr.and_(v_scr.new_list(v_scr.echo('ok')))
pub fn and_(sequence Sequence) Step {
    return fn [sequence] (mut pipe Pipe) ! {
        if pipe.status != 0 {
            return
        }
        result := sequence.run_into(mut pipe)!
        apply_result(mut pipe, result)
    }
}

// or_ runs a sequence only when the current status is non-zero.
// Example: _ := v_scr.or_(v_scr.new_list(v_scr.echo('fallback')))
pub fn or_(sequence Sequence) Step {
    return fn [sequence] (mut pipe Pipe) ! {
        if pipe.status == 0 {
            return
        }
        result := sequence.run_into(mut pipe)!
        apply_result(mut pipe, result)
    }
}

// if_ runs a sequence when the probe step succeeds with zero status.
// Example: _ := v_scr.if_(v_scr.non_empty(), v_scr.new_list(v_scr.echo('has input')))
pub fn if_(expr Step, body Sequence) Step {
    return fn [expr, body] (mut pipe Pipe) ! {
        mut probe := pipe.snapshot()
        expr(mut probe)!
        if probe.status == 0 {
            result := body.run_into(mut pipe)!
            apply_result(mut pipe, result)
            return
        }
        pipe.status = probe.status
    }
}

// if_else runs one of two sequences based on the probe step status.
// Example: _ := v_scr.if_else(v_scr.non_empty(), v_scr.new_list(v_scr.echo('yes')), v_scr.new_list(v_scr.echo('no')))
pub fn if_else(expr Step, body Sequence, else_body Sequence) Step {
    return fn [expr, body, else_body] (mut pipe Pipe) ! {
        mut probe := pipe.snapshot()
        expr(mut probe)!
        result := if probe.status == 0 { body.run_into(mut pipe)! } else { else_body.run_into(mut pipe)! }
        apply_result(mut pipe, result)
    }
}
