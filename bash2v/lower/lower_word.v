module lower

import bash2v.ast

pub fn lower_word(word ast.Word) !WordExpr {
    mut parts := []WordFragmentIR{}
    for part in word.parts {
        parts << lower_word_part(part)!
    }
    return WordExpr{
        parts: parts
    }
}

fn lower_word_part(part ast.WordPart) !WordFragmentIR {
    return match part {
        ast.LiteralPart {
            WordFragmentIR(LiteralFragmentIR{
                text: part.text
            })
        }
        ast.SingleQuotedPart {
            WordFragmentIR(LiteralFragmentIR{
                text: part.text
            })
        }
        ast.DoubleQuotedPart {
            mut out := []WordFragmentIR{}
            for inner in part.parts {
                out << lower_word_part(inner)!
            }
            WordFragmentIR(DoubleQuotedFragmentIR{
                parts: out
            })
        }
        ast.ParamExpansion {
            WordFragmentIR(ParamFragmentIR{
                name: part.name
                index: lower_optional_word(part.index)
                indirection: part.indirection
                enumerate_keys: part.enumerate_keys
                count_items: part.count_items
                op: lower_param_op(part.op)!
            })
        }
        ast.CommandSubstitution {
            WordFragmentIR(CommandSubstFragmentIR{
                source: part.source
                program: lower_program(part.program)!
            })
        }
        ast.ArithmeticExpansion {
            return error('arithmetic expansion lowering is not implemented yet')
        }
    }
}

fn lower_param_op(op ast.ParamOp) !ParamOpIR {
    return match op {
        ast.Noop {
            ParamOpIR(ParamOpNoneIR{})
        }
        ast.LowerAll {
            ParamOpIR(ParamOpLowerAllIR{})
        }
        ast.UpperAll {
            ParamOpIR(ParamOpUpperAllIR{})
        }
        ast.ReplaceOne {
            ParamOpIR(ParamOpReplaceOneIR{
                pattern: lower_word(op.pattern)!
                replacement: lower_word(op.replacement)!
            })
        }
        ast.ReplaceAll {
            ParamOpIR(ParamOpReplaceAllIR{
                pattern: lower_word(op.pattern)!
                replacement: lower_word(op.replacement)!
            })
        }
        ast.Length {
            ParamOpIR(ParamOpLengthIR{})
        }
        ast.DefaultValue {
            ParamOpIR(ParamOpDefaultValueIR{
                fallback: lower_word(op.fallback)!
                assign: op.assign
            })
        }
        ast.AlternativeValue {
            ParamOpIR(ParamOpAlternativeValueIR{
                alternate: lower_word(op.alternate)!
            })
        }
        ast.RequiredValue {
            ParamOpIR(ParamOpRequiredValueIR{
                message: lower_word(op.message)!
            })
        }
    }
}
