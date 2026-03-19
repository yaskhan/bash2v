module codegen

import bash2v.lower

pub fn gen_stmt(stmt lower.StmtIR) string {
    return match stmt {
        lower.SetVarIR { gen_set(stmt) }
        lower.ExecIR { gen_exec(stmt) }
        lower.PipelineIR { gen_pipeline(stmt) }
        lower.IfIR { gen_if(stmt) }
        lower.WhileIR { gen_while(stmt) }
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

fn gen_if(stmt lower.IfIR) string {
    mut lines := []string{}
    lines << 'if bashrt.eval_program_status(mut st, ${gen_eval_program(stmt.condition)})! == 0 {'
    for item in stmt.then_body.stmts {
        lines << indent_block(gen_stmt(item), '\t')
    }
    if stmt.else_body.stmts.len > 0 {
        lines << '} else {'
        for item in stmt.else_body.stmts {
            lines << indent_block(gen_stmt(item), '\t')
        }
    }
    lines << '}'
    return lines.join('\n')
}

fn gen_while(stmt lower.WhileIR) string {
    mut lines := []string{}
    lines << 'for {'
    lines << '\tif bashrt.eval_program_status(mut st, ${gen_eval_program(stmt.condition)})! != 0 {'
    lines << '\t\tbreak'
    lines << '\t}'
    for item in stmt.body.stmts {
        lines << indent_block(gen_stmt(item), '\t')
    }
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
    lines << 'for ${iter_name} in bashrt.eval_words_to_argv(mut st, [${items.join(", ")}])! {'
    lines << "\tbashrt.set_scalar(mut st, '${stmt.name}', ${iter_name})"
    for item in stmt.body.stmts {
        lines << indent_block(gen_stmt(item), '\t')
    }
    lines << '}'
    return lines.join('\n')
}

fn indent_block(input string, prefix string) string {
    mut lines := []string{}
    for line in input.split('\n') {
        lines << prefix + line
    }
    return lines.join('\n')
}
