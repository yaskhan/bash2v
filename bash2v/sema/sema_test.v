module sema

fn test_new_scope_starts_empty() {
    scope := new_scope()
    assert scope.symbols.len == 0
}
