module parse

import bash2v.ast
import bash2v.lex

pub fn (mut parser Parser) parse_simple_command() !ast.SimpleCommand {
    mut assignments := []ast.Assignment{}
    mut words := []ast.Word{}

    parser.skip_inline_layout()
    for !parser.done() {
        parser.skip_inline_layout()
        tok := parser.current()
        if parser.command_boundary(tok) {
            break
        }
        if assignment := parser.try_parse_assignment() {
            assignments << assignment
            continue
        }
        word := parser.parse_word()!
        if word.parts.len == 0 {
            break
        }
        words << word
    }

    return ast.SimpleCommand{
        assignments: assignments
        words: words
    }
}

pub fn (mut parser Parser) parse_pipeline() !ast.Pipeline {
    mut steps := []ast.Stmt{}
    first := parser.parse_command_stmt()!
    steps << first

    for !parser.done() {
        parser.skip_inline_layout()
        if parser.current().kind != .pipe {
            break
        }
        parser.advance()
        parser.skip_inline_layout()
        steps << parser.parse_command_stmt()!
    }

    return ast.Pipeline{
        steps: steps
    }
}

pub fn (mut parser Parser) parse_list() !ast.List {
    mut items := []ast.Stmt{}
    pipeline := parser.parse_pipeline()!
    if pipeline.steps.len == 1 {
        items << pipeline.steps[0]
    } else {
        items << ast.Stmt(pipeline)
    }

    for !parser.done() {
        parser.skip_inline_layout()
        if parser.current().kind !in [.semicolon, .newline] {
            break
        }
        parser.skip_statement_separators()
        if parser.done() || parser.current().kind == .paren_close {
            break
        }
        next_pipeline := parser.parse_pipeline()!
        if next_pipeline.steps.len == 1 {
            items << next_pipeline.steps[0]
        } else {
            items << ast.Stmt(next_pipeline)
        }
    }

    return ast.List{
        items: items
    }
}

fn (mut parser Parser) parse_command_stmt() !ast.Stmt {
    if parser.current_word_is('if') {
        return ast.Stmt(parser.parse_if_stmt()!)
    }
    if parser.current_word_is('while') {
        return ast.Stmt(parser.parse_while_stmt()!)
    }
    if parser.current_word_is('for') {
        return ast.Stmt(parser.parse_for_in_stmt()!)
    }
    cmd := parser.parse_simple_command()!
    if cmd.words.len == 0 && cmd.assignments.len > 0 {
        return ast.Stmt(ast.AssignmentStmt{
            assignments: cmd.assignments
        })
    }
    return ast.Stmt(cmd)
}

fn (mut parser Parser) try_parse_assignment() ?ast.Assignment {
    start := parser.pos
    if parser.current().kind != .word {
        return none
    }
    name_token := parser.current()
    mut name := name_token.text
    mut append := false
    if name.ends_with('+') {
        stripped := name[..name.len - 1]
        if !is_valid_name(stripped) {
            return none
        }
        name = stripped
        append = true
    } else if !is_valid_name(name) {
        return none
    }

    mut kind := ast.AssignKind.scalar
    mut index := ?ast.Word(none)
    parser.advance()

    if parser.current().kind == .bracket_open {
        parser.advance()
        mut index_tokens := []lex.Token{}
        for !parser.done() && parser.current().kind != .bracket_close {
            index_tokens << parser.advance()
        }
        if parser.done() || parser.current().kind != .bracket_close {
            parser.pos = start
            return none
        }
        parser.advance()
        index = parse_index_tokens(index_tokens)
        if idx := index {
            kind = if is_indexed_subscript_word(idx) {
                ast.AssignKind.indexed
            } else {
                ast.AssignKind.assoc
            }
        }
    }

    if parser.current().kind == .word && parser.current().text == '+' {
        append = true
        parser.advance()
    }

    if parser.current().kind != .equals {
        parser.pos = start
        return none
    }
    parser.advance()

    mut compound := false
    mut value := ast.Word{}
    mut items := []ast.Word{}

    if parser.current().kind == .paren_open {
        if index != none {
            parser.pos = start
            return none
        }
        compound = true
        kind = ast.AssignKind.indexed
        items = parser.parse_compound_assignment_words() or {
            parser.pos = start
            return none
        }
    } else {
        value = if parser.command_boundary(parser.current()) {
            ast.Word{}
        } else {
            parser.parse_word() or {
                parser.pos = start
                return none
            }
        }
    }

    return ast.Assignment{
        name: name
        kind: kind
        index: index
        append: append
        compound: compound
        value: value
        items: items
    }
}

fn (mut parser Parser) parse_compound_assignment_words() ![]ast.Word {
    parser.expect(.paren_open)!
    mut items := []ast.Word{}
    for !parser.done() {
        parser.skip_layout()
        if parser.current().kind == .paren_close {
            parser.advance()
            return items
        }
        word := parser.parse_word()!
        if word.parts.len == 0 {
            return error('expected word in compound assignment')
        }
        items << word
    }
    return error('unterminated compound assignment')
}

fn parse_index_tokens(tokens []lex.Token) ast.Word {
    mut nested := new_parser(tokens.clone())
    word := nested.parse_word() or {
        return ast.Word{}
    }
    return word
}

fn is_indexed_subscript_word(word ast.Word) bool {
    if is_numeric_index_word(word) {
        return true
    }
    if word.parts.len == 1 {
        match word.parts[0] {
            ast.ArithmeticExpansion {
                return true
            }
            else {}
        }
    }
    return false
}

fn is_numeric_index_word(word ast.Word) bool {
    if word.parts.len == 0 {
        return false
    }
    mut text := ''
    for part in word.parts {
        match part {
            ast.LiteralPart {
                text += part.text
            }
            ast.SingleQuotedPart {
                text += part.text
            }
            else {
                return false
            }
        }
    }
    if text == '' {
        return false
    }
    for ch in text {
        if ch < `0` || ch > `9` {
            return false
        }
    }
    return true
}

fn is_valid_name(name string) bool {
    if name.len == 0 {
        return false
    }
    if !is_name_start(name[0]) {
        return false
    }
    for ch in name[1..] {
        if !is_name_continue(ch) {
            return false
        }
    }
    return true
}

fn is_name_start(ch u8) bool {
    return ch == `_` || (ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`)
}

fn is_name_continue(ch u8) bool {
    return is_name_start(ch) || (ch >= `0` && ch <= `9`)
}
