module ast

pub struct Word {
pub:
    parts []WordPart
}

pub struct LiteralPart {
pub:
    text string
}

pub struct SingleQuotedPart {
pub:
    text string
}

pub struct DoubleQuotedPart {
pub:
    parts []WordPart
}

pub struct ParamExpansion {
pub:
    name        string
    index       ?Word
    indirection bool
    enumerate_keys bool
    count_items bool
    op          ParamOp = Noop{}
}

pub struct CommandSubstitution {
pub:
    program Program
    source  string
}

pub struct ArithmeticExpansion {
pub:
    expr string
}

pub struct Noop {}

pub struct LowerAll {}

pub struct UpperAll {}

pub struct ReplaceOne {
pub:
    pattern     Word
    replacement Word
}

pub struct ReplaceAll {
pub:
    pattern     Word
    replacement Word
}

pub struct Length {}

pub struct DefaultValue {
pub:
    fallback Word
    assign   bool
}

pub struct AlternativeValue {
pub:
    alternate Word
}

pub struct RequiredValue {
pub:
    message Word
}

pub type ParamOp = Noop | LowerAll | UpperAll | ReplaceOne | ReplaceAll | Length | DefaultValue | AlternativeValue | RequiredValue

pub type WordPart = LiteralPart | SingleQuotedPart | DoubleQuotedPart | ParamExpansion | CommandSubstitution | ArithmeticExpansion
