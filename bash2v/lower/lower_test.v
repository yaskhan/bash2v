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
