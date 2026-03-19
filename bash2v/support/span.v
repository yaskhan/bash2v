module support

pub struct Position {
pub:
    offset int
    line   int
    column int
}

pub struct Span {
pub:
    start Position
    end   Position
}

pub fn zero_position() Position {
    return Position{
        line: 1
        column: 1
    }
}

pub fn zero_span() Span {
    pos := zero_position()
    return Span{
        start: pos
        end: pos
    }
}

pub fn advance_position(pos Position, ch u8) Position {
    if ch == `\n` {
        return Position{
            offset: pos.offset + 1
            line: pos.line + 1
            column: 1
        }
    }
    return Position{
        offset: pos.offset + 1
        line: pos.line
        column: pos.column + 1
    }
}

pub fn new_span(start Position, end Position) Span {
    return Span{
        start: start
        end: end
    }
}
