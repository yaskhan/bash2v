module ast

pub type Stmt = SimpleCommand | Pipeline | List | AssignmentStmt | Subshell

pub struct Program {
pub:
    stmts []Stmt
}
