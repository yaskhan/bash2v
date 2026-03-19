module emit

import strings

pub struct Writer {
mut:
    buf strings.Builder
}

pub fn new_writer(capacity int) Writer {
    return Writer{
        buf: strings.new_builder(capacity)
    }
}

pub fn (mut writer Writer) writeln(line string) {
    writer.buf.writeln(line)
}

pub fn (writer Writer) str() string {
    return writer.buf.str()
}
