module lex

fn test_new_lexer_starts_in_normal_mode() {
    lexer := new_lexer('echo hi')
    assert lexer.mode == .normal
}

fn test_tokenize_preserves_compound_expansion_delimiters() {
    tokens := tokenize(r'echo ${name,,} $(printf "%s" "$x")')
    kinds := tokens.map(it.kind)
    assert kinds[0] == .word
    assert kinds[2] == .dollar_brace_open
    assert kinds[6] == .dollar_paren_open
    assert tokens[3].text == 'name,,'
}

fn test_single_quotes_are_scanned_as_one_token() {
    tokens := tokenize("printf 'a b c'")
    assert tokens[2].kind == .single_quoted
    assert tokens[2].text == 'a b c'
}
