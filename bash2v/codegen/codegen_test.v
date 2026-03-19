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
