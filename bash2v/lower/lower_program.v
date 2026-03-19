module lower

import bash2v.ast

pub fn lower_program(program ast.Program) !ProgramIR {
    mut stmts := []StmtIR{}
    for stmt in program.stmts {
        stmts << lower_stmt(stmt)!
    }
    return ProgramIR{
        stmts: stmts
    }
}
