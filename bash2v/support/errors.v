module support

pub struct Bash2vError {
    Error
pub:
    message string
    span    Span
}

pub fn new_error(message string, span Span) IError {
    return Bash2vError{
        message: message
        span: span
    }
}

pub fn (err Bash2vError) msg() string {
    return err.message
}
