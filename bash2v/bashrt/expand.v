module bashrt

pub struct Word {
pub:
    fragments []WordFragment
}

pub struct LiteralFragment {
pub:
    text string
}

pub struct DoubleQuotedFragment {
pub:
    parts []WordFragment
}

pub struct ParamOpNone {}

pub struct ParamOpLowerAll {}

pub struct ParamOpUpperAll {}

pub struct ParamOpReplaceOne {
pub:
    pattern     Word
    replacement Word
}

pub struct ParamOpReplaceAll {
pub:
    pattern     Word
    replacement Word
}

pub struct ParamOpLength {}

pub struct ParamOpDefaultValue {
pub:
    fallback Word
    assign   bool
}

pub struct ParamOpAlternativeValue {
pub:
    alternate Word
}

pub struct ParamOpRequiredValue {
pub:
    message Word
}

pub type ParamOp = ParamOpNone | ParamOpLowerAll | ParamOpUpperAll | ParamOpReplaceOne | ParamOpReplaceAll | ParamOpLength | ParamOpDefaultValue | ParamOpAlternativeValue | ParamOpRequiredValue

pub struct ParamExpansion {
pub:
    name           string
    index          ?Word
    indirection    bool
    enumerate_keys bool
    count_items    bool
    op             ParamOp = ParamOpNone{}
}

pub struct CommandSubstFragment {
pub:
    source  string
    program EvalProgram
}

pub type WordFragment = LiteralFragment | DoubleQuotedFragment | ParamExpansion | CommandSubstFragment

pub struct WordValue {
pub:
    text   string
    quoted bool
}

pub fn eval_word(mut state State, word Word) !string {
    mut out := []string{}
    for fragment in word.fragments {
        out << eval_fragment(mut state, fragment)!
    }
    return out.join('')
}

fn eval_fragment(mut state State, fragment WordFragment) !string {
    return match fragment {
        LiteralFragment {
            fragment.text
        }
        DoubleQuotedFragment {
            eval_word(mut state, Word{
                fragments: fragment.parts
            })!
        }
        ParamExpansion {
            expand_param(mut state, fragment)!
        }
        CommandSubstFragment {
            eval_command_subst(mut state, fragment)!
        }
    }
}
