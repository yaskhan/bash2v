module sema

pub struct Scope {
mut:
    symbols map[string]Symbol
}

pub fn new_scope() Scope {
    return Scope{
        symbols: map[string]Symbol{}
    }
}
