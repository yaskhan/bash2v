module ast

pub type Stmt = SimpleCommand | Pipeline | AndOrList | List | AssignmentStmt | Subshell | IfStmt | WhileStmt | ForInStmt | BreakStmt | ContinueStmt

pub struct Program {
pub:
    stmts []Stmt
}
