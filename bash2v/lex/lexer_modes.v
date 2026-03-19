module lex

pub enum LexerMode {
    normal
    single_quoted
    double_quoted
    parameter_expansion
    command_substitution
    arithmetic
    array_subscript
    comment
}
