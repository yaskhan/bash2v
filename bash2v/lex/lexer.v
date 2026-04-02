module lex

import bash2v.support

pub struct Lexer {
pub:
    source string
mut:
    pos      int
    mode     LexerMode = .normal
    position support.Position = support.zero_position()
}

pub fn new_lexer(source string) Lexer {
    return Lexer{
        source: source
    }
}

pub fn tokenize(source string) []Token {
    mut lexer := new_lexer(source)
    mut tokens := []Token{}
    for {
        tok := lexer.next_token()
        tokens << tok
        if tok.kind == .eof {
            break
        }
    }
    return tokens
}

pub fn (mut lexer Lexer) next_token() Token {
    if lexer.pos >= lexer.source.len {
        return Token{
            kind: .eof
            span: support.new_span(lexer.position, lexer.position)
        }
    }
    ch := lexer.peek(0)
    if ch == `\n` {
        return lexer.scan_newline()
    }
    if is_horizontal_space(ch) {
        return lexer.scan_whitespace()
    }
    if ch == `'` && lexer.mode != .double_quoted {
        return lexer.scan_single_quoted()
    }
    if ch == `"` {
        return lexer.scan_one(.double_quote, 1)
    }
    if ch == `$` && lexer.peek(1) == `{` {
        return lexer.scan_one(.dollar_brace_open, 2)
    }
    if ch == `$` && lexer.peek(1) == `(` {
        return lexer.scan_one(.dollar_paren_open, 2)
    }
    if ch == `&` && lexer.peek(1) == `&` {
        return lexer.scan_one(.amp_amp, 2)
    }
    if ch == `|` && lexer.peek(1) == `|` {
        return lexer.scan_one(.pipe_pipe, 2)
    }
    if ch == `#` && (lexer.pos == 0 || is_horizontal_space(lexer.peek(-1)) || lexer.peek(-1) == `\n`) {
        return lexer.scan_comment()
    }
    return match ch {
        `$` { lexer.scan_one(.dollar, 1) }
        `(` { lexer.scan_one(.paren_open, 1) }
        `)` { lexer.scan_one(.paren_close, 1) }
        `{` { lexer.scan_one(.brace_open, 1) }
        `}` { lexer.scan_one(.brace_close, 1) }
        `[` { lexer.scan_one(.bracket_open, 1) }
        `]` { lexer.scan_one(.bracket_close, 1) }
        `|` { lexer.scan_one(.pipe, 1) }
        `&` { lexer.scan_one(.amp, 1) }
        `;` { lexer.scan_one(.semicolon, 1) }
        `=` { lexer.scan_one(.equals, 1) }
        else { lexer.scan_word() }
    }
}

fn (lexer Lexer) peek(offset int) u8 {
    idx := lexer.pos + offset
    if idx < 0 || idx >= lexer.source.len {
        return 0
    }
    return lexer.source[idx]
}

fn (mut lexer Lexer) scan_newline() Token {
    return lexer.scan_one(.newline, 1)
}

fn (mut lexer Lexer) scan_comment() Token {
    start_idx := lexer.pos
    start_pos := lexer.position
    for lexer.pos < lexer.source.len && lexer.peek(0) != `\n` {
        lexer.bump()
    }
    return Token{
        kind: .comment
        text: lexer.source[start_idx..lexer.pos]
        span: support.new_span(start_pos, lexer.position)
    }
}

fn (mut lexer Lexer) scan_whitespace() Token {
    start_idx := lexer.pos
    start_pos := lexer.position
    for lexer.pos < lexer.source.len && is_horizontal_space(lexer.peek(0)) {
        lexer.bump()
    }
    return Token{
        kind: .whitespace
        text: lexer.source[start_idx..lexer.pos]
        span: support.new_span(start_pos, lexer.position)
    }
}

fn (mut lexer Lexer) scan_single_quoted() Token {
    start_pos := lexer.position
    start_idx := lexer.pos
    lexer.bump()
    content_start := lexer.pos
    for lexer.pos < lexer.source.len {
        if lexer.peek(0) == `'` {
            text := lexer.source[content_start..lexer.pos]
            lexer.bump()
            return Token{
                kind: .single_quoted
                text: text
                span: support.new_span(start_pos, lexer.position)
            }
        }
        lexer.bump()
    }
    return invalid_token(lexer.source[start_idx..lexer.pos], support.new_span(start_pos, lexer.position))
}

fn (mut lexer Lexer) scan_word() Token {
    start_idx := lexer.pos
    start_pos := lexer.position
    for lexer.pos < lexer.source.len {
        ch := lexer.peek(0)
        if lexer.is_word_boundary(ch) {
            break
        }
        lexer.bump()
    }
    return Token{
        kind: .word
        text: lexer.source[start_idx..lexer.pos]
        span: support.new_span(start_pos, lexer.position)
    }
}

fn (mut lexer Lexer) scan_one(kind TokenKind, width int) Token {
    start_idx := lexer.pos
    start_pos := lexer.position
    for _ in 0 .. width {
        lexer.bump()
    }
    if kind == .double_quote {
        lexer.mode = if lexer.mode == .double_quoted { .normal } else { .double_quoted }
    }
    return Token{
        kind: kind
        text: lexer.source[start_idx..lexer.pos]
        span: support.new_span(start_pos, lexer.position)
    }
}

fn (mut lexer Lexer) bump() {
    if lexer.pos >= lexer.source.len {
        return
    }
    ch := lexer.source[lexer.pos]
    lexer.pos++
    lexer.position = support.advance_position(lexer.position, ch)
}

fn is_horizontal_space(ch u8) bool {
    return ch == ` ` || ch == `\t` || ch == `\r`
}

fn is_word_boundary(ch u8) bool {
    return ch == 0
        || ch == `\n`
        || is_horizontal_space(ch)
        || ch == `'`
        || ch == `"`
        || ch == `$`
        || ch == `(`
        || ch == `)`
        || ch == `{`
        || ch == `}`
        || ch == `[`
        || ch == `]`
        || ch == `|`
        || ch == `&`
        || ch == `;`
        || ch == `=`
}

fn (lexer Lexer) is_word_boundary(ch u8) bool {
    if lexer.mode == .double_quoted && ch == `'` {
        return false
    }
    return is_word_boundary(ch)
}
