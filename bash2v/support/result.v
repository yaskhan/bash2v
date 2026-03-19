module support

pub enum DiagnosticLevel {
    info
    warning
    error
}

pub struct Diagnostic {
pub:
    level   DiagnosticLevel
    message string
    span    Span = zero_span()
}

pub struct CheckResult {
pub:
    diagnostics []Diagnostic
}

pub fn (result CheckResult) has_errors() bool {
    for item in result.diagnostics {
        if item.level == .error {
            return true
        }
    }
    return false
}
