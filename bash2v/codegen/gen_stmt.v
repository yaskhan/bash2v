module codegen

import strings
import bash2v.lower

pub fn gen_stmt(stmt lower.StmtIR) string {
    return match stmt {
        lower.SetVarIR { gen_set(stmt) }
        lower.ExecIR { gen_exec(stmt) }
        lower.PipelineIR { gen_pipeline(stmt) }
        lower.AndOrIR { gen_and_or(stmt) }
        lower.IfIR { gen_if(stmt) }
        lower.WhileIR { gen_while(stmt) }
        lower.CaseIR { gen_case(stmt) }
        lower.ForInIR { gen_for_in(stmt) }
        lower.BreakIR { 'break' }
        lower.ContinueIR { 'continue' }
    }
}

fn gen_set(stmt lower.SetVarIR) string {
    if stmt.compound {
        mut items := []string{}
        for item in stmt.items {
            items << gen_word_expr(item)
        }
        return match stmt.kind {
            .indexed {
                if stmt.append {
                    "bashrt.append_indexed_values(mut st, '${stmt.name}', [${items.join(", ")}])"
                } else {
                    "bashrt.set_indexed_values(mut st, '${stmt.name}', [${items.join(", ")}])"
                }
            }
            .scalar, .assoc {
                "panic('unsupported compound assignment for ${stmt.name}')"
            }
        }
    }
    value := gen_word_expr(stmt.expr)
    return match stmt.kind {
        .scalar {
            if stmt.append {
                "bashrt.append_scalar(mut st, '${stmt.name}', ${value})"
            } else {
                "bashrt.set_scalar(mut st, '${stmt.name}', ${value})"
            }
        }
        .indexed {
            idx := if index := stmt.index {
                gen_word_expr(index)
            } else {
                "''"
            }
            if stmt.append {
                if stmt.index != none {
                    "bashrt.append_indexed_at(mut st, '${stmt.name}', ${idx}, ${value})"
                } else {
                    "bashrt.append_indexed_values(mut st, '${stmt.name}', [${value}])"
                }
            } else {
                "bashrt.set_indexed(mut st, '${stmt.name}', ${idx}, ${value})"
            }
        }
        .assoc {
            idx := if index := stmt.index {
                gen_word_expr(index)
            } else {
                "''"
            }
            if stmt.append {
                "bashrt.append_assoc(mut st, '${stmt.name}', ${idx}, ${value})"
            } else {
                "bashrt.set_assoc(mut st, '${stmt.name}', ${idx}, ${value})"
            }
        }
    }
}

fn gen_exec(stmt lower.ExecIR) string {
    mut lines := []string{}
    for item in stmt.assignments {
        lines << gen_set(item)
    }
    mut argv := []string{}
    for item in stmt.argv {
        argv << gen_word_value(item)
    }
    if argv.len > 0 {
        lines << 'bashrt.run_exec_words(mut st, [${argv.join(", ")}])!'
    }
    return lines.join('\n\t')
}

fn gen_pipeline(stmt lower.PipelineIR) string {
    mut steps := []string{}
    for item in stmt.steps {
        mut argv := []string{}
        for word in item.argv {
            argv << gen_word_value(word)
        }
        steps << '[${argv.join(", ")}]'
    }
    return 'bashrt.run_pipeline_word_parts(mut st, [${steps.join(", ")}])!'
}

fn gen_and_or(stmt lower.AndOrIR) string {
    return 'bashrt.run_and_or(mut st, ${gen_eval_and_or(stmt)})!'
}

fn gen_if(stmt lower.IfIR) string {
    mut lines := []string{}
    lines << '{'
    lines << '\tif bashrt.eval_program_condition(mut st, ${gen_eval_program(stmt.condition)})! == 0 {'
    lines << '\t\tbashrt.set_last_status(mut st, 0)'
    for item in stmt.then_body.stmts {
        lines << indent_block(gen_stmt(item), '\t\t')
    }
    if stmt.else_body.stmts.len > 0 {
        lines << '\t} else {'
        lines << '\t\tbashrt.set_last_status(mut st, 0)'
        for item in stmt.else_body.stmts {
            lines << indent_block(gen_stmt(item), '\t\t')
        }
    } else {
        lines << '\t} else {'
        lines << '\t\tbashrt.set_last_status(mut st, 0)'
    }
    lines << '\t}'
    lines << '}'
    return lines.join('\n')
}

fn gen_while(stmt lower.WhileIR) string {
    mut lines := []string{}
    lines << '{'
    lines << '\tmut bash2v_while_ran := false'
    lines << '\tfor {'
    lines << '\t\tif bashrt.eval_program_condition(mut st, ${gen_eval_program(stmt.condition)})! != 0 {'
    lines << '\t\t\tbreak'
    lines << '\t\t}'
    lines << '\t\tbash2v_while_ran = true'
    lines << '\t\tbashrt.set_last_status(mut st, 0)'
    for item in stmt.body.stmts {
        lines << indent_block(gen_stmt(item), '\t\t')
    }
    lines << '\t}'
    lines << '\tif !bash2v_while_ran {'
    lines << '\t\tbashrt.set_last_status(mut st, 0)'
    lines << '\t}'
    lines << '}'
    return lines.join('\n')
}

fn gen_for_in(stmt lower.ForInIR) string {
    mut items := []string{}
    for item in stmt.items {
        items << gen_word_value(item)
    }
    iter_name := 'bash2v_item_${stmt.name}'
    mut lines := []string{}
    lines << '{'
    lines << '\tmut bash2v_for_ran := false'
    lines << '\tfor ${iter_name} in bashrt.eval_words_to_argv(mut st, [${items.join(", ")}])! {'
    lines << '\t\tbash2v_for_ran = true'
    lines << '\t\tbashrt.set_last_status(mut st, 0)'
    lines << "\t\tbashrt.set_scalar(mut st, '${stmt.name}', ${iter_name})"
    for item in stmt.body.stmts {
        lines << indent_block(gen_stmt(item), '\t\t')
    }
    lines << '\t}'
    lines << '\tif !bash2v_for_ran {'
    lines << '\t\tbashrt.set_last_status(mut st, 0)'
    lines << '\t}'
    lines << '}'
    return lines.join('\n')
}

fn gen_case(stmt lower.CaseIR) string {
    subject_name := 'bash2v_case_subject'
    matched_name := 'bash2v_case_matched'
    mut lines := []string{}
    lines << '{'
    lines << '\t${subject_name} := ${gen_word_expr(stmt.subject)}'
    lines << '\tmut ${matched_name} := false'
    for idx, arm in stmt.arms {
        mut checks := []string{}
        for pattern in arm.patterns {
            checks << 'bashrt.case_match(${subject_name}, ${gen_word_expr(pattern)})'
        }
        prefix := if idx == 0 { '\tif' } else { '\telse if' }
        lines << '${prefix} !${matched_name} && (${checks.join(" || ")}) {'
        lines << '\t\t${matched_name} = true'
        lines << '\t\tbashrt.set_last_status(mut st, 0)'
        for item in arm.body.stmts {
            lines << indent_block(gen_stmt(item), '\t\t')
        }
        lines << '\t}'
    }
    lines << '\tif !${matched_name} {'
    lines << '\t\tbashrt.set_last_status(mut st, 0)'
    lines << '\t}'
    lines << '}'
    return lines.join('\n')
}

fn indent_block(input string, prefix string) string {
    if input == '' {
        return ''
    }
    mut sb := strings.new_builder(input.len + (input.count('\n') + 1) * prefix.len)
    mut start := 0
    for i := 0; i < input.len; i++ {
        if input[i] == `\n` {
            sb.write_string(prefix)
            sb.write_string(input[start..i + 1])
            start = i + 1
        }
    }
    if start < input.len {
        sb.write_string(prefix)
        sb.write_string(input[start..])
    }
    return sb.str()
}
