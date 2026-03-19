module codegen

import bash2v.lex
import bash2v.lower
import bash2v.parse

fn test_name_generator_is_stable() {
    mut gen := new_name_generator()
    assert gen.next('tmp') == 'tmp0'
    assert gen.next('tmp') == 'tmp1'
}

fn test_generate_includes_runtime_calls() {
    mut parser := parse.new_parser(lex.tokenize(r'name=World echo "${name,,}"'))
    program := parser.parse_program() or { panic(err) }
    lowered := lower.lower_program(program) or { panic(err) }
    generated := generate(lowered)
    assert generated.contains('import bash2v.bashrt')
    assert generated.contains("bashrt.set_scalar(mut st, 'name'")
    assert generated.contains('bashrt.eval_word(mut st, bashrt.Word')
    assert generated.contains('bashrt.run_exec(mut st, [')
}

fn test_generate_pipeline_uses_exec_pipeline() {
    mut parser := parse.new_parser(lex.tokenize('echo hello | grep h'))
    program := parser.parse_program() or { panic(err) }
    lowered := lower.lower_program(program) or { panic(err) }
    generated := generate(lowered)
    assert generated.contains('bashrt.run_pipeline_words(mut st, [')
    assert generated.contains('[bashrt.eval_word(mut st, bashrt.Word')
}

fn test_generate_default_value_expansion() {
    mut parser := parse.new_parser(lex.tokenize(r'echo "${name:=fallback}"'))
    program := parser.parse_program() or { panic(err) }
    lowered := lower.lower_program(program) or { panic(err) }
    generated := generate(lowered)
    assert generated.contains('bashrt.ParamOp(bashrt.ParamOpDefaultValue{')
    assert generated.contains('assign: true')
}

fn test_generate_alternate_and_required_expansion() {
    mut parser := parse.new_parser(lex.tokenize(r'echo "${name:+alt}" "${name:?missing}"'))
    program := parser.parse_program() or { panic(err) }
    lowered := lower.lower_program(program) or { panic(err) }
    generated := generate(lowered)
    assert generated.contains('bashrt.ParamOp(bashrt.ParamOpAlternativeValue{')
    assert generated.contains('bashrt.ParamOp(bashrt.ParamOpRequiredValue{')
}

fn test_generate_append_assignments() {
    mut parser := parse.new_parser(lex.tokenize('VAR1+=asdasd\nARR1+=( item1 "it5 ooo" )'))
    program := parser.parse_program() or { panic(err) }
    lowered := lower.lower_program(program) or { panic(err) }
    generated := generate(lowered)
    assert generated.contains("bashrt.append_scalar(mut st, 'VAR1'")
    assert generated.contains("bashrt.append_indexed_values(mut st, 'ARR1'")
}

fn test_generate_arithmetic_expansion() {
    mut parser := parse.new_parser(lex.tokenize(r'echo "$((1 + x * 3))"'))
    program := parser.parse_program() or { panic(err) }
    lowered := lower.lower_program(program) or { panic(err) }
    generated := generate(lowered)
    assert generated.contains('bashrt.ArithmeticFragment{ expr:')
}

fn test_generate_if_statement() {
    mut parser := parse.new_parser(lex.tokenize('if test 5 -gt 3; then echo yes; else echo no; fi'))
    program := parser.parse_program() or { panic(err) }
    lowered := lower.lower_program(program) or { panic(err) }
    generated := generate(lowered)
    assert generated.contains('if bashrt.eval_program_status(mut st, bashrt.EvalProgram')
    assert generated.contains("bashrt.run_exec(mut st, [bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'echo' })] })!, bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'yes' })] })!])!")
}

fn test_generate_while_statement() {
    mut parser := parse.new_parser(lex.tokenize(r'while [ "${i}" -lt 3 ]; do i=$((i + 1)); echo "${i}"; done'))
    program := parser.parse_program() or { panic(err) }
    lowered := lower.lower_program(program) or { panic(err) }
    generated := generate(lowered)
    assert generated.contains('for {')
    assert generated.contains('if bashrt.eval_program_status(mut st, bashrt.EvalProgram')
    assert generated.contains("bashrt.set_scalar(mut st, 'i'")
}

fn test_generate_for_in_statement() {
    mut parser := parse.new_parser(lex.tokenize(r'for item in one "two words" three; do echo "${item}"; done'))
    program := parser.parse_program() or { panic(err) }
    lowered := lower.lower_program(program) or { panic(err) }
    generated := generate(lowered)
    assert generated.contains('for bash2v_item_item in [')
    assert generated.contains("bashrt.set_scalar(mut st, 'item', bash2v_item_item)")
}
