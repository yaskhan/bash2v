module ast

pub fn (program Program) str() string {
    return 'Program{stmts: ${program.stmts.len}}'
}

pub fn program_debug(program Program) string {
    mut parts := []string{}
    for stmt in program.stmts {
        parts << stmt_debug(stmt)
    }
    return parts.join(' ; ')
}

pub fn stmt_debug(stmt Stmt) string {
    return match stmt {
        SimpleCommand {
            simple_command_debug(stmt)
        }
        Pipeline {
            mut steps := []string{}
            for step in stmt.steps {
                steps << stmt_debug(step)
            }
            'pipeline(${steps.join(" | ")})'
        }
        AndOrList {
            mut out := stmt_debug(stmt.first)
            for item in stmt.items {
                op := match item.op {
                    .and_if { '&&' }
                    .or_if { '||' }
                }
                out += ' ${op} ${stmt_debug(item.stmt)}'
            }
            'andor(${out})'
        }
        List {
            mut items := []string{}
            for item in stmt.items {
                items << stmt_debug(item)
            }
            'list(${items.join(" ; ")})'
        }
        AssignmentStmt {
            mut items := []string{}
            for item in stmt.assignments {
                items << assignment_debug(item)
            }
            'assign(${items.join(", ")})'
        }
        Subshell {
            mut items := []string{}
            for item in stmt.body {
                items << stmt_debug(item)
            }
            'subshell(${items.join(" ; ")})'
        }
        IfStmt {
            mut cond := []string{}
            for item in stmt.condition {
                cond << stmt_debug(item)
            }
            mut then_body := []string{}
            for item in stmt.then_body {
                then_body << stmt_debug(item)
            }
            mut out := 'if(${cond.join(" ; ")} => ${then_body.join(" ; ")})'
            if stmt.else_body.len > 0 {
                mut else_body := []string{}
                for item in stmt.else_body {
                    else_body << stmt_debug(item)
                }
                out += ' else (${else_body.join(" ; ")})'
            }
            out
        }
        WhileStmt {
            mut cond := []string{}
            for item in stmt.condition {
                cond << stmt_debug(item)
            }
            mut body := []string{}
            for item in stmt.body {
                body << stmt_debug(item)
            }
            'while(${cond.join(" ; ")} => ${body.join(" ; ")})'
        }
        ForInStmt {
            mut items := []string{}
            for item in stmt.items {
                items << word_debug(item)
            }
            mut body := []string{}
            for item in stmt.body {
                body << stmt_debug(item)
            }
            'for(${stmt.name} in ${items.join(" ")} => ${body.join(" ; ")})'
        }
        BreakStmt {
            'break'
        }
        ContinueStmt {
            'continue'
        }
    }
}

pub fn simple_command_debug(cmd SimpleCommand) string {
    mut parts := []string{}
    if cmd.assignments.len > 0 {
        mut assignments := []string{}
        for item in cmd.assignments {
            assignments << assignment_debug(item)
        }
        parts << 'assign=[${assignments.join(", ")}]'
    }
    if cmd.words.len > 0 {
        mut words := []string{}
        for word in cmd.words {
            words << word_debug(word)
        }
        parts << 'words=[${words.join(", ")}]'
    }
    return 'cmd(${parts.join("; ")})'
}

pub fn assignment_debug(item Assignment) string {
    mut parts := []string{}
    parts << item.name
    if idx := item.index {
        parts << '[${word_debug(idx)}]'
    }
    if item.append {
        parts << '+='
    } else {
        parts << '='
    }
    if item.compound {
        mut items := []string{}
        for word in item.items {
            items << word_debug(word)
        }
        parts << '(${items.join(" ")})'
    } else {
        parts << word_debug(item.value)
    }
    return parts.join('')
}

pub fn word_debug(word Word) string {
    mut parts := []string{}
    for part in word.parts {
        parts << word_part_debug(part)
    }
    return parts.join(' + ')
}

pub fn word_part_debug(part WordPart) string {
    return match part {
        LiteralPart {
            'lit(${part.text})'
        }
        SingleQuotedPart {
            "sq(${part.text})"
        }
        DoubleQuotedPart {
            mut inner := []string{}
            for item in part.parts {
                inner << word_part_debug(item)
            }
            'dq(${inner.join(" + ")})'
        }
        ParamExpansion {
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
                attrs << 'index=${word_debug(idx)}'
            }
            attrs << 'op=${param_op_debug(part.op)}'
            'param(${part.name}; ${attrs.join("; ")})'
        }
        CommandSubstitution {
            'cmd(${part.source})'
        }
        ArithmeticExpansion {
            'arith(${part.expr})'
        }
    }
}

pub fn param_op_debug(op ParamOp) string {
    return match op {
        Noop {
            'noop'
        }
        LowerAll {
            'lower_all'
        }
        UpperAll {
            'upper_all'
        }
        ReplaceOne {
            'replace_one(${word_debug(op.pattern)} -> ${word_debug(op.replacement)})'
        }
        ReplaceAll {
            'replace_all(${word_debug(op.pattern)} -> ${word_debug(op.replacement)})'
        }
        Length {
            'length'
        }
        DefaultValue {
            if op.assign {
                'default_assign(${word_debug(op.fallback)})'
            } else {
                'default(${word_debug(op.fallback)})'
            }
        }
        AlternativeValue {
            'alternate(${word_debug(op.alternate)})'
        }
        RequiredValue {
            'required(${word_debug(op.message)})'
        }
    }
}
