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

pub enum ParamArrayModeIR {
    none
    all_star
    all_at
}

pub struct ParamFragmentIR {
pub:
    name           string
    index          ?WordExpr
    indirection    bool
    enumerate_keys bool
    count_items    bool
    array_mode     ParamArrayModeIR = .none
    op             ParamOpIR = ParamOpNoneIR{}
}

pub struct CommandSubstFragmentIR {
pub:
    source  string
    program ProgramIR
}

pub struct ArithmeticFragmentIR {
pub:
    expr string
}

pub type WordFragmentIR = LiteralFragmentIR | DoubleQuotedFragmentIR | ParamFragmentIR | CommandSubstFragmentIR | ArithmeticFragmentIR

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

pub enum LogicalOpIR {
    and_if
    or_if
}

pub struct AndOrArmIR {
pub:
    op      LogicalOpIR
    program ProgramIR
}

pub struct AndOrIR {
pub:
    first ProgramIR
    items []AndOrArmIR
}

pub struct IfIR {
pub:
    condition ProgramIR
    then_body ProgramIR
    else_body ProgramIR
}

pub struct WhileIR {
pub:
    condition ProgramIR
    body      ProgramIR
}

pub struct CaseArmIR {
pub:
    patterns []WordExpr
    body     ProgramIR
}

pub struct CaseIR {
pub:
    subject WordExpr
    arms    []CaseArmIR
}

pub struct ForInIR {
pub:
    name  string
    items []WordExpr
    body  ProgramIR
}

pub struct BreakIR {}

pub struct ContinueIR {}

pub type StmtIR = SetVarIR | ExecIR | PipelineIR | AndOrIR | IfIR | WhileIR | CaseIR | ForInIR | BreakIR | ContinueIR

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
            match part.array_mode {
                .all_star {
                    attrs << 'array=*'
                }
                .all_at {
                    attrs << 'array=@'
                }
                .none {}
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
        ArithmeticFragmentIR {
            'arith(${part.expr})'
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
        AndOrIR {
            mut out := [program_ir_debug(stmt.first)]
            for item in stmt.items {
                op := match item.op {
                    .and_if { '&&' }
                    .or_if { '||' }
                }
                out << ' ${op} ${program_ir_debug(item.program)}'
            }
            'andor(${out.join("")})'
        }
        IfIR {
            mut cond := []string{}
            for item in stmt.condition.stmts {
                cond << stmt_ir_debug(item)
            }
            mut then_body := []string{}
            for item in stmt.then_body.stmts {
                then_body << stmt_ir_debug(item)
            }
            mut out := 'if(${cond.join(" ; ")} => ${then_body.join(" ; ")})'
            if stmt.else_body.stmts.len > 0 {
                mut else_body := []string{}
                for item in stmt.else_body.stmts {
                    else_body << stmt_ir_debug(item)
                }
                out += ' else (${else_body.join(" ; ")})'
            }
            out
        }
        WhileIR {
            mut cond := []string{}
            for item in stmt.condition.stmts {
                cond << stmt_ir_debug(item)
            }
            mut body := []string{}
            for item in stmt.body.stmts {
                body << stmt_ir_debug(item)
            }
            'while(${cond.join(" ; ")} => ${body.join(" ; ")})'
        }
        CaseIR {
            mut arms := []string{}
            for arm in stmt.arms {
                mut patterns := []string{}
                for pattern in arm.patterns {
                    patterns << word_expr_debug(pattern)
                }
                mut body := []string{}
                for item in arm.body.stmts {
                    body << stmt_ir_debug(item)
                }
                arms << '${patterns.join(" | ")} => ${body.join(" ; ")}'
            }
            'case(${word_expr_debug(stmt.subject)} => ${arms.join(" ; ")})'
        }
        ForInIR {
            mut items := []string{}
            for item in stmt.items {
                items << word_expr_debug(item)
            }
            mut body := []string{}
            for item in stmt.body.stmts {
                body << stmt_ir_debug(item)
            }
            'for(${stmt.name} in ${items.join(" ")} => ${body.join(" ; ")})'
        }
        BreakIR {
            'break'
        }
        ContinueIR {
            'continue'
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
