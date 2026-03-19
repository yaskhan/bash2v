module bash2v

import bash2v.ast
import bash2v.codegen
import bash2v.lex
import bash2v.lower
import bash2v.parse

pub struct TranspileResult {
pub:
    program    ast.Program
    lowered    lower.ProgramIR
    generated  string
}

pub fn transpile_source(source string) !TranspileResult {
    tokens := lex.tokenize(source)
    mut parser := parse.new_parser(tokens)
    program := parser.parse_program()!
    lowered := lower.lower_program(program)!
    generated := codegen.generate(lowered)
    return TranspileResult{
        program: program
        lowered: lowered
        generated: generated
    }
}
