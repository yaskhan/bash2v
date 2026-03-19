module parse

import bash2v.ast

fn (mut parser Parser) parse_if_stmt() !ast.IfStmt {
    parser.expect_word('if')!
    condition := parser.parse_stmt_sequence_until(['then'])!
    parser.expect_word('then')!
    then_body := parser.parse_stmt_sequence_until(['else', 'fi'])!
    mut else_body := []ast.Stmt{}
    if parser.current_word_is('else') {
        parser.expect_word('else')!
        else_body = parser.parse_stmt_sequence_until(['fi'])!
    }
    parser.expect_word('fi')!
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

fn (mut parser Parser) parse_stmt_sequence_until(stop_words []string) ![]ast.Stmt {
    mut stmts := []ast.Stmt{}
    for !parser.done() {
        parser.skip_statement_separators()
        if parser.done() || parser.current_is_stop_word(stop_words) || parser.current().kind == .paren_close {
            break
        }
        pipeline := parser.parse_pipeline()!
        if pipeline.steps.len == 1 {
            stmts << pipeline.steps[0]
        } else {
            stmts << ast.Stmt(pipeline)
        }
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
