module lower

import bash2v.ast
import bash2v.lex
import bash2v.parse

fn test_lower_empty_program_returns_empty_ir() {
    program_ir := ProgramIR{}
    assert program_ir.stmts.len == 0
}

fn test_lower_assignment_and_command() {
    mut parser := parse.new_parser(lex.tokenize(r'name=World echo "${name,,}"'))
    program := parser.parse_program() or { panic(err) }
    program_ir := lower_program(program) or { panic(err) }
    assert program_ir_debug(program_ir) == 'exec(assign=[set(name=lit(World); kind=scalar)]; argv=[lit(echo), dq(param(name; op=lower_all))])'
}

fn test_lower_pipeline() {
    mut parser := parse.new_parser(lex.tokenize('echo hello | grep h'))
    program := parser.parse_program() or { panic(err) }
    program_ir := lower_program(program) or { panic(err) }
    assert program_ir_debug(program_ir) == 'pipeline(exec(argv=[lit(echo), lit(hello)]) | exec(argv=[lit(grep), lit(h)]))'
}

fn test_lower_and_or_list() {
    mut parser := parse.new_parser(lex.tokenize('false && echo no || echo yes'))
    program := parser.parse_program() or { panic(err) }
    program_ir := lower_program(program) or { panic(err) }
    assert program_ir_debug(program_ir) == 'andor(exec(argv=[lit(false)]) && exec(argv=[lit(echo), lit(no)]) || exec(argv=[lit(echo), lit(yes)]))'
}

fn test_lower_assignment_statement() {
    stmt := ast.Stmt(ast.AssignmentStmt{
        assignments: [
            ast.Assignment{
                name: 'x'
                value: ast.Word{
                    parts: [
                        ast.WordPart(ast.LiteralPart{
                            text: '1'
                        }),
                    ]
                }
            },
        ]
    })
    lowered := lower_stmt(stmt) or { panic(err) }
    assert lowered.len == 1
    assert stmt_ir_debug(lowered[0]) == 'set(x=lit(1); kind=scalar)'
}

fn test_lower_assoc_assignment_statement() {
    stmt := ast.Stmt(ast.AssignmentStmt{
        assignments: [
            ast.Assignment{
                name: 'map'
                kind: .assoc
                index: ast.Word{
                    parts: [ast.WordPart(ast.LiteralPart{ text: 'foo' })]
                }
                value: ast.Word{
                    parts: [ast.WordPart(ast.LiteralPart{ text: 'bar' })]
                }
            },
        ]
    })
    lowered := lower_stmt(stmt) or { panic(err) }
    assert lowered.len == 1
    assert stmt_ir_debug(lowered[0]) == 'set(map[lit(foo)]=lit(bar); kind=assoc)'
}

fn test_lower_append_assignments() {
    mut parser := parse.new_parser(lex.tokenize('VAR1+=asdasd\nARR1+=( item1 "it5 ooo" )\nARR2=()'))
    program := parser.parse_program() or { panic(err) }
    program_ir := lower_program(program) or { panic(err) }
    assert program_ir_debug(program_ir) == 'set(VAR1+=lit(asdasd); kind=scalar) ; set(ARR1+=(lit(item1) dq(lit(it5) + lit( ) + lit(ooo))); kind=indexed) ; set(ARR2=(); kind=indexed)'
}

fn test_lower_arithmetic_expansion() {
    mut parser := parse.new_parser(lex.tokenize(r'echo "$((1 + x * 3))"'))
    program := parser.parse_program() or { panic(err) }
    program_ir := lower_program(program) or { panic(err) }
    assert program_ir_debug(program_ir) == 'exec(argv=[lit(echo), dq(arith(1 + x * 3))])'
}

fn test_lower_assignment_with_arithmetic_index_and_rhs() {
    mut parser := parse.new_parser(lex.tokenize(r'i=1
arr[$((i + 1))]=$((i + 4))
echo "${arr[$((i + 1))]}"'))
    program := parser.parse_program() or { panic(err) }
    program_ir := lower_program(program) or { panic(err) }
    assert program_ir_debug(program_ir) == 'set(i=lit(1); kind=scalar) ; set(arr[arith(i + 1)]=arith(i + 4); kind=indexed) ; exec(argv=[lit(echo), dq(param(arr; index=arith(i + 1); op=noop))])'
}

fn test_lower_array_all_items_expansions() {
    mut parser := parse.new_parser(lex.tokenize(r'echo "${arr[*]}" "${arr[@]}"'))
    program := parser.parse_program() or { panic(err) }
    program_ir := lower_program(program) or { panic(err) }
    assert program_ir_debug(program_ir) == 'exec(argv=[lit(echo), dq(param(arr; array=*; op=noop)), dq(param(arr; array=@; op=noop))])'
}

fn test_lower_double_quoted_single_quotes_around_array_index() {
    source := "echo \"'" + r'${arr[0]}' + "'\""
    mut parser := parse.new_parser(lex.tokenize(source))
    program := parser.parse_program() or { panic(err) }
    program_ir := lower_program(program) or { panic(err) }
    assert program_ir_debug(program_ir) == "exec(argv=[lit(echo), dq(lit(') + param(arr; index=lit(0); op=noop) + lit('))])"
}

fn test_lower_if_statement() {
    mut parser := parse.new_parser(lex.tokenize('if test 5 -gt 3; then echo yes; else echo no; fi'))
    program := parser.parse_program() or { panic(err) }
    program_ir := lower_program(program) or { panic(err) }
    assert program_ir_debug(program_ir) == 'if(exec(argv=[lit(test), lit(5), lit(-gt), lit(3)]) => exec(argv=[lit(echo), lit(yes)])) else (exec(argv=[lit(echo), lit(no)]))'
}

fn test_lower_if_statement_with_elif() {
    mut parser := parse.new_parser(lex.tokenize('if test 1 -eq 2; then echo no; elif test 2 -eq 2; then echo yes; else echo other; fi'))
    program := parser.parse_program() or { panic(err) }
    program_ir := lower_program(program) or { panic(err) }
    assert program_ir_debug(program_ir) == 'if(exec(argv=[lit(test), lit(1), lit(-eq), lit(2)]) => exec(argv=[lit(echo), lit(no)])) else (if(exec(argv=[lit(test), lit(2), lit(-eq), lit(2)]) => exec(argv=[lit(echo), lit(yes)])) else (exec(argv=[lit(echo), lit(other)])))'
}

fn test_lower_while_statement() {
    mut parser := parse.new_parser(lex.tokenize(r'while [ "$i" -lt 3 ]; do i=$((i + 1)); echo "$i"; done'))
    program := parser.parse_program() or { panic(err) }
    program_ir := lower_program(program) or { panic(err) }
    assert program_ir_debug(program_ir) == 'while(exec(argv=[lit([), dq(param(i; op=noop)), lit(-lt), lit(3), lit(])]) => set(i=arith(i + 1); kind=scalar) ; exec(argv=[lit(echo), dq(param(i; op=noop))]))'
}

fn test_lower_for_in_statement() {
    mut parser := parse.new_parser(lex.tokenize(r'for item in one "two words" three; do echo "$item"; done'))
    program := parser.parse_program() or { panic(err) }
    program_ir := lower_program(program) or { panic(err) }
    assert program_ir_debug(program_ir) == 'for(item in lit(one) dq(lit(two) + lit( ) + lit(words)) lit(three) => exec(argv=[lit(echo), dq(param(item; op=noop))]))'
}

fn test_lower_break_and_continue_statements() {
    mut parser := parse.new_parser(lex.tokenize('while true; do continue; break; done'))
    program := parser.parse_program() or { panic(err) }
    program_ir := lower_program(program) or { panic(err) }
    assert program_ir_debug(program_ir) == 'while(exec(argv=[lit(true)]) => continue ; break)'
}

fn test_lower_default_value_expansion() {
    mut parser := parse.new_parser(lex.tokenize(r'echo "${name:=fallback}" "${name:-other}"'))
    program := parser.parse_program() or { panic(err) }
    program_ir := lower_program(program) or { panic(err) }
    assert program_ir_debug(program_ir) == 'exec(argv=[lit(echo), dq(param(name; op=default_assign(lit(fallback)))), dq(param(name; op=default(lit(other))))])'
}

fn test_lower_alternate_and_required_expansion() {
    mut parser := parse.new_parser(lex.tokenize(r'echo "${name:+alt}" "${name:?missing}"'))
    program := parser.parse_program() or { panic(err) }
    program_ir := lower_program(program) or { panic(err) }
    assert program_ir_debug(program_ir) == 'exec(argv=[lit(echo), dq(param(name; op=alternate(lit(alt)))), dq(param(name; op=required(lit(missing))))])'
}
