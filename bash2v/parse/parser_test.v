module parse

import bash2v.lex
import bash2v.ast

fn test_new_parser_has_zero_position() {
    parser := new_parser([lex.eof_token()])
    assert parser.pos == 0
}

fn test_parse_word_with_simple_literal() {
    mut parser := new_parser(lex.tokenize('hello'))
    word := parser.parse_word() or { panic(err) }
    assert ast.word_debug(word) == 'lit(hello)'
}

fn test_parse_word_with_single_and_double_quotes() {
    mut parser := new_parser(lex.tokenize(r'"hello ${name}"'))
    word := parser.parse_word() or { panic(err) }
    assert ast.word_debug(word) == 'dq(lit(hello) + lit( ) + param(name; op=noop))'
}

fn test_parse_param_expansion_replace_all() {
    mut parser := new_parser(lex.tokenize(r'${value//a/b}'))
    word := parser.parse_word() or { panic(err) }
    assert ast.word_debug(word) == 'param(value; op=replace_all(lit(a) -> lit(b)))'
}

fn test_parse_param_expansion_index_and_keys() {
    mut parser1 := new_parser(lex.tokenize(r'${arr[1]}'))
    word1 := parser1.parse_word() or { panic(err) }
    assert ast.word_debug(word1) == 'param(arr; index=lit(1); op=noop)'

    mut parser2 := new_parser(lex.tokenize(r'${!map[@]}'))
    word2 := parser2.parse_word() or { panic(err) }
    assert ast.word_debug(word2) == 'param(map; keys; op=noop)'

    mut parser3 := new_parser(lex.tokenize(r'${#arr[@]}'))
    word3 := parser3.parse_word() or { panic(err) }
    assert ast.word_debug(word3) == 'param(arr; count_items; op=length)'
}

fn test_parse_param_expansion_arithmetic_index() {
    mut parser := new_parser(lex.tokenize(r'${arr[$((i + 1))]}'))
    word := parser.parse_word() or { panic(err) }
    assert ast.word_debug(word) == 'param(arr; index=arith(i + 1); op=noop)'
}

fn test_parse_param_expansion_default_value_and_assign() {
    mut parser1 := new_parser(lex.tokenize(r'${name:-fallback}'))
    word1 := parser1.parse_word() or { panic(err) }
    assert ast.word_debug(word1) == 'param(name; op=default(lit(fallback)))'

    mut parser2 := new_parser(lex.tokenize(r'${name:=fallback}'))
    word2 := parser2.parse_word() or { panic(err) }
    assert ast.word_debug(word2) == 'param(name; op=default_assign(lit(fallback)))'
}

fn test_parse_param_expansion_alternate_and_required() {
    mut parser1 := new_parser(lex.tokenize(r'${name:+alt}'))
    word1 := parser1.parse_word() or { panic(err) }
    assert ast.word_debug(word1) == 'param(name; op=alternate(lit(alt)))'

    mut parser2 := new_parser(lex.tokenize(r'${name:?missing name}'))
    word2 := parser2.parse_word() or { panic(err) }
    assert ast.word_debug(word2) == 'param(name; op=required(lit(missing name)))'
}

fn test_parse_nested_command_substitution_keeps_source() {
    mut parser := new_parser(lex.tokenize(r'$(printf "%s" "$(echo hi)")'))
    word := parser.parse_word() or { panic(err) }
    assert ast.word_debug(word) == 'cmd(printf "%s" "$(echo hi)")'
}

fn test_parse_arithmetic_expansion_keeps_expression() {
    mut parser := new_parser(lex.tokenize(r'$((1 + x * (2 + 3)))'))
    word := parser.parse_word() or { panic(err) }
    assert ast.word_debug(word) == 'arith(1 + x * (2 + 3))'
}

fn test_parse_program_simple_command() {
    mut parser := new_parser(lex.tokenize('echo hello'))
    program := parser.parse_program() or { panic(err) }
    assert ast.program_debug(program) == 'cmd(words=[lit(echo), lit(hello)])'
}

fn test_parse_program_assignment_only_statement() {
    mut parser := new_parser(lex.tokenize('name=World'))
    program := parser.parse_program() or { panic(err) }
    assert ast.program_debug(program) == 'assign(name=lit(World))'
}

fn test_parse_program_command_with_leading_assignment() {
    mut parser := new_parser(lex.tokenize(r'name=World echo "${name,,}"'))
    program := parser.parse_program() or { panic(err) }
    assert ast.program_debug(program) == 'cmd(assign=[name=lit(World)]; words=[lit(echo), dq(param(name; op=lower_all))])'
}

fn test_parse_program_pipeline() {
    mut parser := new_parser(lex.tokenize('echo hello | grep h'))
    program := parser.parse_program() or { panic(err) }
    assert ast.program_debug(program) == 'pipeline(cmd(words=[lit(echo), lit(hello)]) | cmd(words=[lit(grep), lit(h)]))'
}

fn test_parse_program_indexed_and_assoc_assignments() {
    mut parser := new_parser(lex.tokenize("arr[3]=value\nmap[foo]=bar"))
    program := parser.parse_program() or { panic(err) }
    assert ast.program_debug(program) == 'list(assign(arr[lit(3)]=lit(value)) ; assign(map[lit(foo)]=lit(bar)))'
    if program.stmts[0] is ast.List {
        stmt_list := program.stmts[0] as ast.List
        if stmt_list.items[0] is ast.AssignmentStmt {
            stmt0 := stmt_list.items[0] as ast.AssignmentStmt
            assert stmt0.assignments[0].kind == .indexed
        } else {
            assert false
        }
        if stmt_list.items[1] is ast.AssignmentStmt {
            stmt1 := stmt_list.items[1] as ast.AssignmentStmt
            assert stmt1.assignments[0].kind == .assoc
        } else {
            assert false
        }
    } else {
        assert false
    }
}

fn test_parse_append_assignments() {
    mut parser := new_parser(lex.tokenize('VAR1+=asdasd\nARR1+=( item1 "it5 ooo" )\nARR2=()'))
    program := parser.parse_program() or { panic(err) }
    assert ast.program_debug(program) == 'list(assign(VAR1+=lit(asdasd)) ; assign(ARR1+=(lit(item1) dq(lit(it5) + lit( ) + lit(ooo)))) ; assign(ARR2=()))'
    if program.stmts[0] is ast.List {
        stmt_list := program.stmts[0] as ast.List
        if stmt_list.items[0] is ast.AssignmentStmt {
            stmt0 := stmt_list.items[0] as ast.AssignmentStmt
            assert stmt0.assignments[0].append == true
            assert stmt0.assignments[0].compound == false
        } else {
            assert false
        }
        if stmt_list.items[1] is ast.AssignmentStmt {
            stmt1 := stmt_list.items[1] as ast.AssignmentStmt
            assert stmt1.assignments[0].append == true
            assert stmt1.assignments[0].compound == true
            assert stmt1.assignments[0].kind == .indexed
        } else {
            assert false
        }
        if stmt_list.items[2] is ast.AssignmentStmt {
            stmt2 := stmt_list.items[2] as ast.AssignmentStmt
            assert stmt2.assignments[0].append == false
            assert stmt2.assignments[0].compound == true
            assert stmt2.assignments[0].kind == .indexed
        } else {
            assert false
        }
    } else {
        assert false
    }
}

fn test_parse_assignment_with_arithmetic_index() {
    mut parser := new_parser(lex.tokenize(r'arr[$((i + 1))]=value'))
    program := parser.parse_program() or { panic(err) }
    assert ast.program_debug(program) == 'assign(arr[arith(i + 1)]=lit(value))'
    if program.stmts[0] is ast.AssignmentStmt {
        stmt := program.stmts[0] as ast.AssignmentStmt
        assert stmt.assignments[0].kind == .indexed
    } else {
        assert false
    }
}

fn test_parse_if_statement_with_else() {
    mut parser := new_parser(lex.tokenize('if test 5 -gt 3; then echo yes; else echo no; fi'))
    program := parser.parse_program() or { panic(err) }
    assert ast.program_debug(program) == 'if(cmd(words=[lit(test), lit(5), lit(-gt), lit(3)]) => cmd(words=[lit(echo), lit(yes)])) else (cmd(words=[lit(echo), lit(no)]))'
}

fn test_parse_while_statement() {
    mut parser := new_parser(lex.tokenize(r'while [ "${i}" -lt 3 ]; do i=$((i + 1)); echo "${i}"; done'))
    program := parser.parse_program() or { panic(err) }
    assert ast.program_debug(program) == 'while(cmd(words=[lit([), dq(param(i; op=noop)), lit(-lt), lit(3), lit(])]) => assign(i=arith(i + 1)) ; cmd(words=[lit(echo), dq(param(i; op=noop))]))'
}

fn test_parse_for_in_statement() {
    mut parser := new_parser(lex.tokenize(r'for item in one "two words" three; do echo "${item}"; done'))
    program := parser.parse_program() or { panic(err) }
    assert ast.program_debug(program) == 'for(item in lit(one) dq(lit(two) + lit( ) + lit(words)) lit(three) => cmd(words=[lit(echo), dq(param(item; op=noop))]))'
}
