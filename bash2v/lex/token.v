module lex

import bash2v.support

pub enum TokenKind {
    eof
    invalid
    newline
    whitespace
    word
    single_quoted
    comment
    dollar
    dollar_brace_open
    dollar_paren_open
    double_quote
    paren_open
    paren_close
    brace_open
    brace_close
    bracket_open
    bracket_close
    pipe
    amp_amp
    pipe_pipe
    amp
    semicolon
    equals
}

pub struct Token {
pub:
    kind TokenKind
    text string
    span support.Span
}

pub fn eof_token() Token {
    return Token{
        kind: .eof
        span: support.zero_span()
    }
}

pub fn invalid_token(text string, span support.Span) Token {
    return Token{
        kind: .invalid
        text: text
        span: span
    }
}
