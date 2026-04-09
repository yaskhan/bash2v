module parse

import bash2v.ast
import bash2v.support

pub fn (mut parser Parser) parse_word() !ast.Word {
    mut parts := []ast.WordPart{}
    for !parser.done() {
        tok := parser.current()
        if parser.word_boundary(tok) || tok.kind in [.paren_close, .brace_close] {
            break
        }
        parts << parser.parse_word_part()!
    }
    return ast.Word{
        parts: parts
    }
}

pub fn (mut parser Parser) parse_word_part() !ast.WordPart {
    tok := parser.current()
    return match tok.kind {
        .word {
            parser.advance()
            ast.WordPart(ast.LiteralPart{
                text: tok.text
            })
        }
        .single_quoted {
            parser.advance()
            ast.WordPart(ast.SingleQuotedPart{
                text: tok.text
            })
        }
        .whitespace, .newline {
            parser.advance()
            ast.WordPart(ast.LiteralPart{
                text: tok.text
            })
        }
        .double_quote {
            ast.WordPart(parser.parse_double_quoted_part()!)
        }
        .dollar_brace_open {
            ast.WordPart(parser.parse_param_expansion()!)
        }
        .dollar_paren_open {
            if parser.peek(1).kind == .paren_open {
                ast.WordPart(parser.parse_arithmetic_expansion()!)
            } else {
                ast.WordPart(parser.parse_command_substitution()!)
            }
        }
        .dollar {
            parser.parse_plain_dollar_part()
        }
        .paren_open, .paren_close, .brace_open, .brace_close, .bracket_open, .bracket_close, .pipe, .pipe_pipe, .amp, .amp_amp, .semicolon, .equals {
            parser.advance()
            ast.WordPart(ast.LiteralPart{
                text: tok.text
            })
        }
        else {
            return support.new_error('unexpected token in word: ${tok.kind} ("${tok.text}")', tok.span)
        }
    }
}

fn (mut parser Parser) parse_double_quoted_part() !ast.DoubleQuotedPart {
    parser.expect(.double_quote)!
    mut parts := []ast.WordPart{}
    for !parser.done() {
        tok := parser.current()
        if tok.kind == .double_quote {
            parser.advance()
            return ast.DoubleQuotedPart{
                parts: parts
            }
        }
        if tok.kind == .eof {
            return support.new_error('unterminated double-quoted string', tok.span)
        }
        parts << parser.parse_double_quoted_inner_part()!
    }
    return ast.DoubleQuotedPart{
        parts: parts
    }
}

fn (mut parser Parser) parse_double_quoted_inner_part() !ast.WordPart {
    tok := parser.current()
    return match tok.kind {
        .word, .whitespace, .newline, .single_quoted, .paren_open, .paren_close, .brace_open, .brace_close, .bracket_open, .bracket_close, .pipe, .pipe_pipe, .amp, .amp_amp, .semicolon, .equals {
            parser.advance()
            ast.WordPart(ast.LiteralPart{
                text: tok.text
            })
        }
        .dollar_brace_open {
            ast.WordPart(parser.parse_param_expansion()!)
        }
        .dollar_paren_open {
            if parser.peek(1).kind == .paren_open {
                ast.WordPart(parser.parse_arithmetic_expansion()!)
            } else {
                ast.WordPart(parser.parse_command_substitution()!)
            }
        }
        .dollar {
            parser.parse_plain_dollar_part()
        }
        else {
            return support.new_error('unexpected token in double-quoted string: ${tok.kind}', tok.span)
        }
    }
}

fn (mut parser Parser) parse_plain_dollar_part() !ast.WordPart {
    parser.expect(.dollar)!
    next := parser.current()
    if next.kind == .word && is_valid_name(next.text) {
        parser.advance()
        return ast.WordPart(ast.ParamExpansion{
            name: next.text
        })
    }
    return ast.WordPart(ast.LiteralPart{
        text: '$'
    })
}
