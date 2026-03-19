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

fn test_plain_dollar_variable_is_split_into_dollar_and_word() {
    tokens := tokenize(r'echo $name "$value"')
    assert tokens[2].kind == .dollar
    assert tokens[3].kind == .word
    assert tokens[3].text == 'name'
}

fn test_logical_operator_tokens_are_scanned() {
    tokens := tokenize('true && false || echo hi')
    kinds := tokens.map(it.kind)
    assert kinds.contains(.amp_amp)
    assert kinds.contains(.pipe_pipe)
}

fn test_single_quote_inside_double_quotes_is_literal_text() {
    source := "\"" + "'" + r'${arr[0]}' + "'" + "\""
    tokens := tokenize(source)
    assert tokens[0].kind == .double_quote
    assert tokens[1].kind == .word
    assert tokens[1].text == "'"
    assert tokens[2].kind == .dollar_brace_open
    assert tokens[8].kind == .word
    assert tokens[8].text == "'"
    assert tokens[9].kind == .double_quote
}
