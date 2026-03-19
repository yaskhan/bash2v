module codegen

import bash2v.lower

pub fn gen_word_expr(expr lower.WordExpr) string {
    return 'bashrt.eval_word(mut st, ${gen_word_value(expr)})!'
}

fn gen_word_value(expr lower.WordExpr) string {
    mut parts := []string{}
    for part in expr.parts {
        parts << gen_word_fragment(part)
    }
    return 'bashrt.Word{ fragments: [${parts.join(", ")}] }'
}

fn gen_word_fragment(part lower.WordFragmentIR) string {
    return match part {
        lower.LiteralFragmentIR {
            "bashrt.WordFragment(bashrt.LiteralFragment{ text: ${quote_v_string(part.text)} })"
        }
        lower.DoubleQuotedFragmentIR {
            mut inner := []string{}
            for item in part.parts {
                inner << gen_word_fragment(item)
            }
            "bashrt.WordFragment(bashrt.DoubleQuotedFragment{ parts: [${inner.join(", ")}] })"
        }
        lower.ParamFragmentIR {
            "bashrt.WordFragment(${gen_param_fragment(part)})"
        }
        lower.CommandSubstFragmentIR {
            "bashrt.WordFragment(bashrt.CommandSubstFragment{ source: ${quote_v_string(part.source)}, program: ${gen_eval_program(part.program)} })"
        }
        lower.ArithmeticFragmentIR {
            "bashrt.WordFragment(bashrt.ArithmeticFragment{ expr: ${quote_v_string(part.expr)} })"
        }
    }
}

fn gen_param_fragment(part lower.ParamFragmentIR) string {
    index_expr := if index := part.index {
        'bashrt.Word{ fragments: [${gen_word_expr_parts(index)}] }'
    } else {
        'none'
    }
    array_mode := match part.array_mode {
        .none { 'bashrt.ParamArrayMode.none' }
        .all_star { 'bashrt.ParamArrayMode.all_star' }
        .all_at { 'bashrt.ParamArrayMode.all_at' }
    }
    return 'bashrt.ParamExpansion{ name: ${quote_v_string(part.name)}, index: ${index_expr}, indirection: ${part.indirection}, enumerate_keys: ${part.enumerate_keys}, count_items: ${part.count_items}, array_mode: ${array_mode}, op: ${gen_param_op(part.op)} }'
}

fn gen_word_expr_parts(expr lower.WordExpr) string {
    mut parts := []string{}
    for part in expr.parts {
        parts << gen_word_fragment(part)
    }
    return parts.join(", ")
}

fn gen_param_op(op lower.ParamOpIR) string {
    return match op {
        lower.ParamOpNoneIR {
            'bashrt.ParamOp(bashrt.ParamOpNone{})'
        }
        lower.ParamOpLowerAllIR {
            'bashrt.ParamOp(bashrt.ParamOpLowerAll{})'
        }
        lower.ParamOpUpperAllIR {
            'bashrt.ParamOp(bashrt.ParamOpUpperAll{})'
        }
        lower.ParamOpReplaceOneIR {
            'bashrt.ParamOp(bashrt.ParamOpReplaceOne{ pattern: bashrt.Word{ fragments: [${gen_word_expr_parts(op.pattern)}] }, replacement: bashrt.Word{ fragments: [${gen_word_expr_parts(op.replacement)}] } })'
        }
        lower.ParamOpReplaceAllIR {
            'bashrt.ParamOp(bashrt.ParamOpReplaceAll{ pattern: bashrt.Word{ fragments: [${gen_word_expr_parts(op.pattern)}] }, replacement: bashrt.Word{ fragments: [${gen_word_expr_parts(op.replacement)}] } })'
        }
        lower.ParamOpLengthIR {
            'bashrt.ParamOp(bashrt.ParamOpLength{})'
        }
        lower.ParamOpDefaultValueIR {
            'bashrt.ParamOp(bashrt.ParamOpDefaultValue{ fallback: bashrt.Word{ fragments: [${gen_word_expr_parts(op.fallback)}] }, assign: ${op.assign} })'
        }
        lower.ParamOpAlternativeValueIR {
            'bashrt.ParamOp(bashrt.ParamOpAlternativeValue{ alternate: bashrt.Word{ fragments: [${gen_word_expr_parts(op.alternate)}] } })'
        }
        lower.ParamOpRequiredValueIR {
            'bashrt.ParamOp(bashrt.ParamOpRequiredValue{ message: bashrt.Word{ fragments: [${gen_word_expr_parts(op.message)}] } })'
        }
    }
}

fn gen_eval_program(program lower.ProgramIR) string {
    mut stmts := []string{}
    for stmt in program.stmts {
        stmts << gen_eval_stmt(stmt)
    }
    return 'bashrt.EvalProgram{ stmts: [${stmts.join(", ")}] }'
}

fn gen_eval_stmt(stmt lower.StmtIR) string {
    return match stmt {
        lower.SetVarIR {
            'bashrt.EvalStmt(${gen_eval_assignment(stmt)})'
        }
        lower.ExecIR {
            'bashrt.EvalStmt(${gen_eval_exec(stmt)})'
        }
        lower.PipelineIR {
            'bashrt.EvalStmt(${gen_eval_pipeline(stmt)})'
        }
        lower.AndOrIR {
            'bashrt.EvalStmt(${gen_eval_and_or(stmt)})'
        }
        lower.IfIR {
            panic('if statements are not supported inside EvalProgram')
        }
        lower.WhileIR {
            panic('while statements are not supported inside EvalProgram')
        }
        lower.ForInIR {
            panic('for statements are not supported inside EvalProgram')
        }
        lower.BreakIR {
            panic('break statements are not supported inside EvalProgram')
        }
        lower.ContinueIR {
            panic('continue statements are not supported inside EvalProgram')
        }
    }
}

fn gen_eval_assignment(stmt lower.SetVarIR) string {
    kind := match stmt.kind {
        .scalar { 'bashrt.EvalValueKind.scalar' }
        .indexed { 'bashrt.EvalValueKind.indexed' }
        .assoc { 'bashrt.EvalValueKind.assoc' }
    }
    index_expr := if index := stmt.index {
        'bashrt.Word{ fragments: [${gen_word_expr_parts(index)}] }'
    } else {
        'none'
    }
    mut items := []string{}
    for item in stmt.items {
        items << 'bashrt.Word{ fragments: [${gen_word_expr_parts(item)}] }'
    }
    return 'bashrt.EvalAssignment{ name: ${quote_v_string(stmt.name)}, kind: ${kind}, index: ${index_expr}, append: ${stmt.append}, compound: ${stmt.compound}, expr: bashrt.Word{ fragments: [${gen_word_expr_parts(stmt.expr)}] }, items: [${items.join(", ")}] }'
}

fn gen_eval_exec(stmt lower.ExecIR) string {
    mut assignments := []string{}
    for item in stmt.assignments {
        assignments << gen_eval_assignment(item)
    }
    mut argv := []string{}
    for item in stmt.argv {
        argv << gen_word_value(item)
    }
    return 'bashrt.EvalExec{ assignments: [${assignments.join(", ")}], argv: [${argv.join(", ")}] }'
}

fn gen_eval_pipeline(stmt lower.PipelineIR) string {
    mut steps := []string{}
    for item in stmt.steps {
        steps << gen_eval_exec(item)
    }
    return 'bashrt.EvalPipeline{ steps: [${steps.join(", ")}] }'
}

fn gen_eval_and_or(stmt lower.AndOrIR) string {
    mut items := []string{}
    for item in stmt.items {
        op := match item.op {
            .and_if { 'bashrt.EvalLogicalOp.and_if' }
            .or_if { 'bashrt.EvalLogicalOp.or_if' }
        }
        items << 'bashrt.EvalAndOrArm{ op: ${op}, program: ${gen_eval_program(item.program)} }'
    }
    return 'bashrt.EvalAndOr{ first: ${gen_eval_program(stmt.first)}, items: [${items.join(", ")}] }'
}

fn quote_v_string(input string) string {
    escaped := input.replace('\\', '\\\\').replace("'", "\\'")
    return "'${escaped}'"
}
