module ast

pub type Stmt = SimpleCommand | Pipeline | List | AssignmentStmt | Subshell | IfStmt | WhileStmt | ForInStmt

pub struct Program {
pub:
    stmts []Stmt
}
