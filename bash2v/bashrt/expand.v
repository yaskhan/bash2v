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

pub enum ParamArrayMode {
    none
    all_star
    all_at
}

pub struct ParamExpansion {
pub:
    name           string
    index          ?Word
    indirection    bool
    enumerate_keys bool
    count_items    bool
    array_mode     ParamArrayMode = .none
    op             ParamOp = ParamOpNone{}
}

pub struct CommandSubstFragment {
pub:
    source  string
    program EvalProgram
}

pub struct ArithmeticFragment {
pub:
    expr string
}

pub type WordFragment = LiteralFragment | DoubleQuotedFragment | ParamExpansion | CommandSubstFragment | ArithmeticFragment

pub struct WordValue {
pub:
    text   string
    quoted bool
}

struct ExpandedWord {
    parts []WordValue
}

pub fn eval_word(mut state State, word Word) !string {
    return eval_word_values(mut state, word)!.join(' ')
}

pub fn eval_word_values(mut state State, word Word) ![]string {
    return finalize_expanded_words(eval_fragments_words(mut state, word.fragments, false)!)
}

fn eval_fragments_words(mut state State, fragments []WordFragment, quoted bool) ![]ExpandedWord {
    mut acc := [ExpandedWord{}]
    for fragment in fragments {
        values := eval_fragment_words(mut state, fragment, quoted)!
        if values.len == 0 {
            return []ExpandedWord{}
        }
        mut next := []ExpandedWord{}
        for prefix in acc {
            for value in values {
                mut parts := prefix.parts.clone()
                parts << value.parts
                next << ExpandedWord{
                    parts: parts
                }
            }
        }
        acc = next.clone()
    }
    return acc
}

fn finalize_expanded_words(words []ExpandedWord) []string {
    mut out := []string{}
    for word in words {
        out << finalize_expanded_word(word)
    }
    return out
}

fn finalize_expanded_word(word ExpandedWord) []string {
    mut fields := []string{}
    mut current := ''
    mut has_current := false
    mut current_quoted := false

    for part in word.parts {
        if part.quoted {
            if !has_current {
                has_current = true
            }
            current += part.text
            current_quoted = true
            continue
        }

        mut start := 0
        for idx, ch in part.text {
            if ch !in [` `, `\t`, `\n`] {
                continue
            }
            if idx > start {
                if !has_current {
                    has_current = true
                }
                current += part.text[start..idx]
            }
            if has_current {
                if current != '' || current_quoted {
                    fields << current
                }
                current = ''
                has_current = false
                current_quoted = false
            }
            start = idx + 1
        }
        if start < part.text.len {
            if !has_current {
                has_current = true
            }
            current += part.text[start..]
        }
    }

    if has_current && (current != '' || current_quoted) {
        fields << current
    }
    return fields
}

fn eval_fragment_words(mut state State, fragment WordFragment, quoted bool) ![]ExpandedWord {
    return match fragment {
        LiteralFragment {
            [ExpandedWord{
                parts: [WordValue{
                    text: fragment.text
                    quoted: true
                }]
            }]
        }
        DoubleQuotedFragment {
            eval_fragments_words(mut state, fragment.parts, true)!
        }
        ParamExpansion {
            expand_param_words(mut state, fragment, quoted)!
        }
        CommandSubstFragment {
            [ExpandedWord{
                parts: [WordValue{
                    text: eval_command_subst(mut state, fragment)!
                    quoted: quoted
                }]
            }]
        }
        ArithmeticFragment {
            [ExpandedWord{
                parts: [WordValue{
                    text: eval_arithmetic(mut state, fragment.expr)!
                    quoted: quoted
                }]
            }]
        }
    }
}
