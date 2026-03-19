module bashrt

pub struct Pattern {
pub:
    source string
}

pub fn replace_one(input string, pattern Pattern, replacement string) string {
    if pattern.source == '' {
        return input
    }
    if idx := input.index(pattern.source) {
        return input[..idx] + replacement + input[idx + pattern.source.len..]
    }
    return input
}

pub fn replace_all(input string, pattern Pattern, replacement string) string {
    return input.replace(pattern.source, replacement)
}
