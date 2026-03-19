module codegen

import strings
import bash2v.lower

pub fn generate(program lower.ProgramIR) string {
    mut out := strings.new_builder(512)
    out.writeln('module main')
    out.writeln('')
    out.writeln('import bash2v.bashrt')
    out.writeln('')
    out.writeln('fn main() {')
    out.writeln('\tmut st := bashrt.new_state()')
    for stmt in program.stmts {
        out.writeln('\t${gen_stmt(stmt)}')
    }
    out.writeln('}')
    return out.str()
}
