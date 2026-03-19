module parse

import bash2v.ast
import bash2v.lex
import bash2v.support

pub fn (mut parser Parser) parse_param_expansion() !ast.ParamExpansion {
    open := parser.expect(.dollar_brace_open)!
    mut depth := 1
    mut raw := []string{}
    for !parser.done() {
        tok := parser.advance()
        match tok.kind {
            .dollar_brace_open {
                depth++
                raw << tok.text
            }
            .brace_close {
                depth--
                if depth == 0 {
                    return parse_param_body(raw.join(''))
                }
                raw << tok.text
            }
            .eof {
                return support.new_error('unterminated parameter expansion', open.span)
            }
            else {
                raw << tok.text
            }
        }
    }
    return support.new_error('unterminated parameter expansion', open.span)
}

pub fn (mut parser Parser) parse_command_substitution() !ast.CommandSubstitution {
    open := parser.expect(.dollar_paren_open)!
    mut depth := 1
    mut raw := []string{}
    for !parser.done() {
        tok := parser.advance()
        match tok.kind {
            .dollar_paren_open {
                depth++
                raw << tok.text
            }
            .paren_open {
                depth++
                raw << tok.text
            }
            .paren_close {
                depth--
                if depth == 0 {
                    source := raw.join('')
                    inner_tokens := lex.tokenize(source)
                    mut inner_parser := new_parser(inner_tokens)
                    program := inner_parser.parse_program() or { ast.Program{} }
                    return ast.CommandSubstitution{
                        program: program
                        source: source
                    }
                }
                raw << tok.text
            }
            .eof {
                return support.new_error('unterminated command substitution', open.span)
            }
            else {
                raw << tok.text
            }
        }
    }
    return support.new_error('unterminated command substitution', open.span)
}

pub fn (mut parser Parser) parse_arithmetic_expansion() !ast.ArithmeticExpansion {
    open := parser.expect(.dollar_paren_open)!
    parser.expect(.paren_open)!
    mut depth := 1
    mut raw := []string{}
    for !parser.done() {
        tok := parser.advance()
        match tok.kind {
            .paren_open {
                depth++
                raw << tok.text
            }
            .paren_close {
                if depth == 1 {
                    parser.expect(.paren_close) or {
                        return support.new_error('unterminated arithmetic expansion', open.span)
                    }
                    return ast.ArithmeticExpansion{
                        expr: raw.join('')
                    }
                }
                depth--
                raw << tok.text
            }
            .eof {
                return support.new_error('unterminated arithmetic expansion', open.span)
            }
            else {
                raw << tok.text
            }
        }
    }
    return support.new_error('unterminated arithmetic expansion', open.span)
}

fn parse_param_body(raw string) !ast.ParamExpansion {
    mut body := raw
    mut length := false
    mut enumerate_keys := false
    mut count_items := false
    mut indirection := false
    mut op := ast.ParamOp(ast.Noop{})

    if body.starts_with('#') {
        length = true
        body = body[1..]
    }

    if body.starts_with('!') && (body.ends_with('[@]') || body.ends_with('[*]')) {
        enumerate_keys = true
        body = body[1..body.len - 3]
    } else if body.starts_with('!') {
        indirection = true
        body = body[1..]
    }

    if length && (body.ends_with('[@]') || body.ends_with('[*]')) {
        count_items = true
        body = body[..body.len - 3]
    }

    if idx := body.index_after(':=', 0) {
        left := body[..idx]
        fallback := body[idx + 2..]
        op = ast.ParamOp(ast.DefaultValue{
            fallback: literal_word(fallback)
            assign: true
        })
        body = left
    } else if idx := body.index_after(':-', 0) {
        left := body[..idx]
        fallback := body[idx + 2..]
        op = ast.ParamOp(ast.DefaultValue{
            fallback: literal_word(fallback)
        })
        body = left
    } else if idx := body.index_after(':+', 0) {
        left := body[..idx]
        alternate := body[idx + 2..]
        op = ast.ParamOp(ast.AlternativeValue{
            alternate: literal_word(alternate)
        })
        body = left
    } else if idx := body.index_after(':?', 0) {
        left := body[..idx]
        message := body[idx + 2..]
        op = ast.ParamOp(ast.RequiredValue{
            message: literal_word(message)
        })
        body = left
    } else if body.ends_with(',,') {
        op = ast.ParamOp(ast.LowerAll{})
        body = body[..body.len - 2]
    } else if body.ends_with('^^') {
        op = ast.ParamOp(ast.UpperAll{})
        body = body[..body.len - 2]
    } else if idx := body.index_after('//', 0) {
        left := body[..idx]
        right := body[idx + 2..]
        pattern, replacement := split_replacement(right)
        op = ast.ParamOp(ast.ReplaceAll{
            pattern: literal_word(pattern)
            replacement: literal_word(replacement)
        })
        body = left
    } else if idx := body.index_after('/', 0) {
        left := body[..idx]
        right := body[idx + 1..]
        pattern, replacement := split_replacement(right)
        op = ast.ParamOp(ast.ReplaceOne{
            pattern: literal_word(pattern)
            replacement: literal_word(replacement)
        })
        body = left
    }

    mut name := body
    mut index := ?ast.Word(none)
    if open_idx := body.index('[') {
        if body.ends_with(']') && open_idx < body.len - 1 {
            name = body[..open_idx]
            index_text := body[open_idx + 1..body.len - 1]
            index = parse_raw_word(index_text)
        }
    }

    if name == '' {
        return error('parameter expansion requires a name')
    }
    if length {
        op = ast.ParamOp(ast.Length{})
    }
    return ast.ParamExpansion{
        name: name
        index: index
        indirection: indirection
        enumerate_keys: enumerate_keys
        count_items: count_items
        op: op
    }
}

fn split_replacement(input string) (string, string) {
    if idx := input.index('/') {
        return input[..idx], input[idx + 1..]
    }
    return input, ''
}

fn literal_word(text string) ast.Word {
    return ast.Word{
        parts: [
            ast.WordPart(ast.LiteralPart{
                text: text
            }),
        ]
    }
}

fn parse_raw_word(text string) ast.Word {
    mut nested := new_parser(lex.tokenize(text))
    return nested.parse_word() or { literal_word(text) }
}
