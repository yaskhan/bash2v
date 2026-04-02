module parse

import bash2v.ast

fn (mut parser Parser) parse_if_stmt() !ast.IfStmt {
    parser.expect_word('if')!
    return parser.parse_if_tail()!
}

fn (mut parser Parser) parse_elif_stmt() !ast.IfStmt {
    parser.expect_word('elif')!
    return parser.parse_if_tail()!
}

fn (mut parser Parser) parse_if_tail() !ast.IfStmt {
    condition := parser.parse_stmt_sequence_until(['then'])!
    parser.expect_word('then')!
    then_body := parser.parse_stmt_sequence_until(['else', 'elif', 'fi'])!
    mut else_body := []ast.Stmt{}
    mut nested_elif := false
    if parser.current_word_is('else') {
        parser.expect_word('else')!
        else_body = parser.parse_stmt_sequence_until(['fi'])!
    } else if parser.current_word_is('elif') {
        nested_elif = true
        else_body = [ast.Stmt(parser.parse_elif_stmt()!)]
    }
    if !nested_elif {
        parser.expect_word('fi')!
    }
    return ast.IfStmt{
        condition: condition
        then_body: then_body
        else_body: else_body
    }
}

fn (mut parser Parser) parse_while_stmt() !ast.WhileStmt {
    parser.expect_word('while')!
    condition := parser.parse_stmt_sequence_until(['do'])!
    parser.expect_word('do')!
    body := parser.parse_stmt_sequence_until(['done'])!
    parser.expect_word('done')!
    return ast.WhileStmt{
        condition: condition
        body: body
    }
}

fn (mut parser Parser) parse_case_stmt() !ast.CaseStmt {
    parser.expect_word('case')!
    parser.skip_inline_layout()
    subject := parser.parse_word()!
    parser.skip_statement_separators()
    parser.expect_word('in')!
    mut arms := []ast.CaseArm{}
    for !parser.done() {
        parser.skip_statement_separators()
        if parser.current_word_is('esac') {
            break
        }
        arms << parser.parse_case_arm()!
    }
    parser.expect_word('esac')!
    return ast.CaseStmt{
        subject: subject
        arms: arms
    }
}

fn (mut parser Parser) parse_case_arm() !ast.CaseArm {
    parser.skip_statement_separators()
    if parser.current().kind == .paren_open {
        parser.advance()
    }
    mut patterns := []ast.Word{}
    for !parser.done() {
        parser.skip_inline_layout()
        pattern := parser.parse_word()!
        if pattern.parts.len == 0 {
            return error('expected case pattern')
        }
        patterns << pattern
        parser.skip_inline_layout()
        if parser.current().kind == .pipe {
            parser.advance()
            continue
        }
        break
    }
    parser.expect(.paren_close)!
    body := parser.parse_case_body()!
    if parser.current_is_double_semicolon() {
        parser.advance()
        parser.advance()
    }
    return ast.CaseArm{
        patterns: patterns
        body: body
    }
}

fn (mut parser Parser) parse_case_body() ![]ast.Stmt {
    mut stmts := []ast.Stmt{}
    for !parser.done() {
        parser.skip_inline_layout()
        if parser.case_body_boundary_ahead() {
            break
        }
        if parser.current().kind in [.newline, .semicolon] {
            parser.advance()
            continue
        }
        stmts << parser.parse_and_or()!
    }
    return stmts
}

fn (mut parser Parser) parse_for_in_stmt() !ast.ForInStmt {
    parser.expect_word('for')!
    parser.skip_inline_layout()
    name_tok := parser.current()
    if name_tok.kind != .word {
        return error('expected loop variable')
    }
    name := name_tok.text
    parser.advance()
    parser.skip_statement_separators()
    parser.expect_word('in')!
    mut items := []ast.Word{}
    for !parser.done() {
        parser.skip_inline_layout()
        if parser.current_is_stop_word(['do']) {
            break
        }
        if parser.current().kind in [.semicolon, .newline] {
            parser.skip_statement_separators()
            if parser.current_is_stop_word(['do']) {
                break
            }
            continue
        }
        word := parser.parse_word()!
        if word.parts.len == 0 {
            break
        }
        items << word
    }
    parser.skip_statement_separators()
    parser.expect_word('do')!
    body := parser.parse_stmt_sequence_until(['done'])!
    parser.expect_word('done')!
    return ast.ForInStmt{
        name: name
        items: items
        body: body
    }
}

fn (mut parser Parser) parse_break_stmt() !ast.BreakStmt {
    parser.expect_word('break')!
    return ast.BreakStmt{}
}

fn (mut parser Parser) parse_continue_stmt() !ast.ContinueStmt {
    parser.expect_word('continue')!
    return ast.ContinueStmt{}
}

fn (mut parser Parser) parse_stmt_sequence_until(stop_words []string) ![]ast.Stmt {
    mut stmts := []ast.Stmt{}
    for !parser.done() {
        parser.skip_statement_separators()
        if parser.done() || parser.current_is_stop_word(stop_words) || parser.current().kind == .paren_close {
            break
        }
        stmts << parser.parse_and_or()!
        parser.skip_statement_separators()
    }
    return stmts
}

fn (mut parser Parser) expect_word(expected string) ! {
    tok := parser.current()
    if tok.kind != .word || tok.text != expected {
        return error('expected ${expected}')
    }
    parser.advance()
}

fn (parser Parser) current_word_is(expected string) bool {
    tok := parser.current()
    return tok.kind == .word && tok.text == expected
}

fn (parser Parser) current_is_stop_word(stop_words []string) bool {
    tok := parser.current()
    if tok.kind != .word {
        return false
    }
    return tok.text in stop_words
}

fn (parser Parser) current_is_double_semicolon() bool {
    return parser.current().kind == .semicolon && parser.peek(1).kind == .semicolon
}

fn (parser Parser) case_body_boundary_ahead() bool {
    mut offset := 0
    for {
        tok := parser.peek(offset)
        if tok.kind == .whitespace || tok.kind == .newline {
            offset++
            continue
        }
        if tok.kind == .eof { break }
        return (tok.kind == .semicolon && parser.peek(offset + 1).kind == .semicolon)
            || (tok.kind == .word && tok.text == 'esac')
    }
    return false
}
