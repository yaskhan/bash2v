module parse

import bash2v.ast
import bash2v.lex
import bash2v.support

pub struct Parser {
pub:
    tokens []lex.Token
mut:
    pos int
}

pub fn new_parser(tokens []lex.Token) Parser {
    return Parser{
        tokens: tokens
    }
}

pub fn (mut parser Parser) parse_program() !ast.Program {
    mut stmts := []ast.Stmt{}
    for !parser.done() {
        parser.skip_statement_separators()
        if parser.done() {
            break
        }
        list := parser.parse_list()!
        if list.items.len == 1 {
            stmts << list.items[0]
        } else if list.items.len > 1 {
            stmts << ast.Stmt(list)
        }
        parser.skip_statement_separators()
    }
    return ast.Program{
        stmts: stmts
    }
}

fn (parser Parser) done() bool {
    return parser.pos >= parser.tokens.len || parser.current().kind == .eof
}

fn (parser Parser) current() lex.Token {
    if parser.pos >= parser.tokens.len {
        return lex.eof_token()
    }
    return parser.tokens[parser.pos]
}

fn (parser Parser) peek(offset int) lex.Token {
    idx := parser.pos + offset
    if idx < 0 || idx >= parser.tokens.len {
        return lex.eof_token()
    }
    return parser.tokens[idx]
}

fn (mut parser Parser) advance() lex.Token {
    tok := parser.current()
    if parser.pos < parser.tokens.len {
        parser.pos++
    }
    return tok
}

fn (mut parser Parser) skip_layout() {
    for !parser.done() {
        tok := parser.current()
        if tok.kind !in [.whitespace, .newline] {
            break
        }
        parser.advance()
    }
}

fn (mut parser Parser) skip_inline_layout() {
    for !parser.done() && parser.current().kind == .whitespace {
        parser.advance()
    }
}

fn (mut parser Parser) skip_statement_separators() {
    for !parser.done() {
        tok := parser.current()
        if tok.kind !in [.whitespace, .newline, .semicolon] {
            break
        }
        parser.advance()
    }
}

fn (mut parser Parser) expect(kind lex.TokenKind) !lex.Token {
    tok := parser.current()
    if tok.kind != kind {
        return support.new_error('expected ${kind}, got ${tok.kind}', tok.span)
    }
    return parser.advance()
}

fn (parser Parser) word_boundary(tok lex.Token) bool {
    return tok.kind in [.eof, .newline, .whitespace, .pipe, .pipe_pipe, .amp, .amp_amp, .semicolon]
}

fn (parser Parser) command_boundary(tok lex.Token) bool {
    return tok.kind in [.eof, .newline, .semicolon, .pipe, .pipe_pipe, .amp, .amp_amp, .paren_close]
}
