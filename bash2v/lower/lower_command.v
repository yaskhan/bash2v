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
            ast.Pipeline, ast.List, ast.Subshell {
                return error('nested pipeline/list/subshell lowering is not implemented for pipeline steps')
            }
        }
    }
    return PipelineIR{
        steps: steps
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
