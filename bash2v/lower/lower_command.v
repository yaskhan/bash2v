module lower

import bash2v.ast

pub fn lower_stmt(stmt ast.Stmt) ![]StmtIR {
    match stmt {
        ast.SimpleCommand {
            return [StmtIR(lower_simple_command(stmt))]
        }
        ast.Pipeline {
            return [StmtIR(lower_pipeline(stmt)!)]
        }
        ast.AndOrList {
            return [StmtIR(lower_and_or(stmt)!)]
        }
        ast.List {
            mut out := []StmtIR{}
            for item in stmt.items {
                out << lower_stmt(item)!
            }
            return out
        }
        ast.AssignmentStmt {
            mut out := []StmtIR{}
            for item in stmt.assignments {
                out << StmtIR(lower_assignment(item)!)
            }
            return out
        }
        ast.Subshell {
            return error('subshell lowering is not implemented yet')
        }
        ast.IfStmt {
            return [StmtIR(lower_if_stmt(stmt)!)]
        }
        ast.WhileStmt {
            return [StmtIR(lower_while_stmt(stmt)!)]
        }
        ast.ForInStmt {
            return [StmtIR(lower_for_in_stmt(stmt)!)]
        }
        ast.BreakStmt {
            return [StmtIR(BreakIR{})]
        }
        ast.ContinueStmt {
            return [StmtIR(ContinueIR{})]
        }
    }
}

fn lower_simple_command(cmd ast.SimpleCommand) ExecIR {
    mut assignments := []SetVarIR{}
    for item in cmd.assignments {
        assignments << lower_assignment(item) or { continue }
    }

    mut argv := []WordExpr{}
    for word in cmd.words {
        argv << lower_word(word) or { WordExpr{} }
    }

    return ExecIR{
        assignments: assignments
        argv: argv
    }
}

fn lower_pipeline(pipeline ast.Pipeline) !PipelineIR {
    mut steps := []ExecIR{}
    for step in pipeline.steps {
        match step {
            ast.SimpleCommand {
                steps << lower_simple_command(step)
            }
            ast.AssignmentStmt {
                return error('assignment-only statements are not valid pipeline steps')
            }
            ast.Pipeline, ast.AndOrList, ast.List, ast.Subshell {
                return error('nested pipeline/list/subshell lowering is not implemented for pipeline steps')
            }
            ast.IfStmt {
                return error('if statements are not valid pipeline steps')
            }
            ast.WhileStmt {
                return error('while statements are not valid pipeline steps')
            }
            ast.ForInStmt {
                return error('for statements are not valid pipeline steps')
            }
            ast.BreakStmt {
                return error('break statements are not valid pipeline steps')
            }
            ast.ContinueStmt {
                return error('continue statements are not valid pipeline steps')
            }
        }
    }
    return PipelineIR{
        steps: steps
    }
}

fn lower_and_or(stmt ast.AndOrList) !AndOrIR {
    mut items := []AndOrArmIR{}
    for item in stmt.items {
        items << AndOrArmIR{
            op: match item.op {
                .and_if { LogicalOpIR.and_if }
                .or_if { LogicalOpIR.or_if }
            }
            program: lower_stmt_block([item.stmt])!
        }
    }
    return AndOrIR{
        first: lower_stmt_block([stmt.first])!
        items: items
    }
}

fn lower_if_stmt(stmt ast.IfStmt) !IfIR {
    return IfIR{
        condition: lower_stmt_block(stmt.condition)!
        then_body: lower_stmt_block(stmt.then_body)!
        else_body: lower_stmt_block(stmt.else_body)!
    }
}

fn lower_while_stmt(stmt ast.WhileStmt) !WhileIR {
    return WhileIR{
        condition: lower_stmt_block(stmt.condition)!
        body: lower_stmt_block(stmt.body)!
    }
}

fn lower_for_in_stmt(stmt ast.ForInStmt) !ForInIR {
    mut items := []WordExpr{}
    for item in stmt.items {
        items << lower_word(item)!
    }
    return ForInIR{
        name: stmt.name
        items: items
        body: lower_stmt_block(stmt.body)!
    }
}

fn lower_stmt_block(stmts []ast.Stmt) !ProgramIR {
    mut out := []StmtIR{}
    for stmt in stmts {
        out << lower_stmt(stmt)!
    }
    return ProgramIR{
        stmts: out
    }
}

fn lower_assignment(item ast.Assignment) !SetVarIR {
    kind := match item.kind {
        .scalar { ValueKind.scalar }
        .indexed { ValueKind.indexed }
        .assoc { ValueKind.assoc }
    }
    mut items := []WordExpr{}
    for word in item.items {
        items << lower_word(word)!
    }
    return SetVarIR{
        name: item.name
        expr: lower_word(item.value)!
        items: items
        kind: kind
        index: lower_optional_word(item.index)
        append: item.append
        compound: item.compound
    }
}

fn lower_optional_word(word ?ast.Word) ?WordExpr {
    if value := word {
        return lower_word(value) or { return none }
    }
    return none
}
