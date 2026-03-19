module lower

pub enum ValueKind {
    scalar
    indexed
    assoc
}

pub struct LiteralFragmentIR {
pub:
    text string
}

pub struct DoubleQuotedFragmentIR {
pub:
    parts []WordFragmentIR
}

pub struct ParamOpNoneIR {}

pub struct ParamOpLowerAllIR {}

pub struct ParamOpUpperAllIR {}

pub struct ParamOpReplaceOneIR {
pub:
    pattern     WordExpr
    replacement WordExpr
}

pub struct ParamOpReplaceAllIR {
pub:
    pattern     WordExpr
    replacement WordExpr
}

pub struct ParamOpLengthIR {}

pub struct ParamOpDefaultValueIR {
pub:
    fallback WordExpr
    assign   bool
}

pub struct ParamOpAlternativeValueIR {
pub:
    alternate WordExpr
}

pub struct ParamOpRequiredValueIR {
pub:
    message WordExpr
}

pub type ParamOpIR = ParamOpNoneIR | ParamOpLowerAllIR | ParamOpUpperAllIR | ParamOpReplaceOneIR | ParamOpReplaceAllIR | ParamOpLengthIR | ParamOpDefaultValueIR | ParamOpAlternativeValueIR | ParamOpRequiredValueIR

pub struct ParamFragmentIR {
pub:
    name           string
    index          ?WordExpr
    indirection    bool
    enumerate_keys bool
    count_items    bool
    op             ParamOpIR = ParamOpNoneIR{}
}

pub struct CommandSubstFragmentIR {
pub:
    source  string
    program ProgramIR
}

pub type WordFragmentIR = LiteralFragmentIR | DoubleQuotedFragmentIR | ParamFragmentIR | CommandSubstFragmentIR

pub struct WordExpr {
pub:
    parts []WordFragmentIR
}

pub struct SetVarIR {
pub:
    name     string
    expr     WordExpr
    items    []WordExpr
    kind     ValueKind = .scalar
    index    ?WordExpr
    append   bool
    compound bool
}

pub struct ExecIR {
pub:
    assignments []SetVarIR
    argv         []WordExpr
}

pub struct PipelineIR {
pub:
    steps []ExecIR
}

pub type StmtIR = SetVarIR | ExecIR | PipelineIR

pub struct ProgramIR {
pub:
    stmts []StmtIR
}

pub fn word_expr_debug(expr WordExpr) string {
    mut parts := []string{}
    for part in expr.parts {
        parts << word_fragment_debug(part)
    }
    return parts.join(' + ')
}

pub fn word_fragment_debug(part WordFragmentIR) string {
    return match part {
        LiteralFragmentIR {
            'lit(${part.text})'
        }
        DoubleQuotedFragmentIR {
            mut items := []string{}
            for item in part.parts {
                items << word_fragment_debug(item)
            }
            'dq(${items.join(" + ")})'
        }
        ParamFragmentIR {
            mut attrs := []string{}
            if part.indirection {
                attrs << 'indirect'
            }
            if part.enumerate_keys {
                attrs << 'keys'
            }
            if part.count_items {
                attrs << 'count_items'
            }
            if idx := part.index {
                attrs << 'index=${word_expr_debug(idx)}'
            }
            attrs << 'op=${param_op_ir_debug(part.op)}'
            'param(${part.name}; ${attrs.join("; ")})'
        }
        CommandSubstFragmentIR {
            'cmd(${part.source})'
        }
    }
}

pub fn param_op_ir_debug(op ParamOpIR) string {
    return match op {
        ParamOpNoneIR {
            'noop'
        }
        ParamOpLowerAllIR {
            'lower_all'
        }
        ParamOpUpperAllIR {
            'upper_all'
        }
        ParamOpReplaceOneIR {
            'replace_one(${word_expr_debug(op.pattern)} -> ${word_expr_debug(op.replacement)})'
        }
        ParamOpReplaceAllIR {
            'replace_all(${word_expr_debug(op.pattern)} -> ${word_expr_debug(op.replacement)})'
        }
        ParamOpLengthIR {
            'length'
        }
        ParamOpDefaultValueIR {
            if op.assign {
                'default_assign(${word_expr_debug(op.fallback)})'
            } else {
                'default(${word_expr_debug(op.fallback)})'
            }
        }
        ParamOpAlternativeValueIR {
            'alternate(${word_expr_debug(op.alternate)})'
        }
        ParamOpRequiredValueIR {
            'required(${word_expr_debug(op.message)})'
        }
    }
}

pub fn stmt_ir_debug(stmt StmtIR) string {
    return match stmt {
        SetVarIR {
            mut left := stmt.name
            if idx := stmt.index {
                left += '[${word_expr_debug(idx)}]'
            }
            op := if stmt.append { '+=' } else { '=' }
            right := if stmt.compound {
                mut items := []string{}
                for item in stmt.items {
                    items << word_expr_debug(item)
                }
                '(${items.join(" ")})'
            } else {
                word_expr_debug(stmt.expr)
            }
            'set(${left}${op}${right}; kind=${stmt.kind})'
        }
        ExecIR {
            mut parts := []string{}
            if stmt.assignments.len > 0 {
                mut assigns := []string{}
                for item in stmt.assignments {
                    assigns << stmt_ir_debug(StmtIR(item))
                }
                parts << 'assign=[${assigns.join(", ")}]'
            }
            mut argv := []string{}
            for item in stmt.argv {
                argv << word_expr_debug(item)
            }
            parts << 'argv=[${argv.join(", ")}]'
            'exec(${parts.join("; ")})'
        }
        PipelineIR {
            mut steps := []string{}
            for item in stmt.steps {
                steps << stmt_ir_debug(StmtIR(item))
            }
            'pipeline(${steps.join(" | ")})'
        }
    }
}

pub fn program_ir_debug(program ProgramIR) string {
    mut stmts := []string{}
    for stmt in program.stmts {
        stmts << stmt_ir_debug(stmt)
    }
    return stmts.join(' ; ')
}
