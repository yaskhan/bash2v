module ast

pub enum AssignKind {
    scalar
    indexed
    assoc
}

pub struct Assignment {
pub:
    name     string
    kind     AssignKind = .scalar
    index    ?Word
    append   bool
    compound bool
    value    Word
    items    []Word
}

pub struct AssignmentStmt {
pub:
    assignments []Assignment
}

pub struct SimpleCommand {
pub:
    assignments []Assignment
    words       []Word
}

pub struct Pipeline {
pub:
    steps []Stmt
}

pub struct List {
pub:
    items []Stmt
}

pub struct Subshell {
pub:
    body []Stmt
}

pub struct IfStmt {
pub:
    condition []Stmt
    then_body []Stmt
    else_body []Stmt
}

pub struct WhileStmt {
pub:
    condition []Stmt
    body      []Stmt
}

pub struct ForInStmt {
pub:
    name  string
    items []Word
    body  []Stmt
}
