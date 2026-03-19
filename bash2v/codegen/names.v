module codegen

pub struct NameGenerator {
mut:
    next_id int
}

pub fn new_name_generator() NameGenerator {
    return NameGenerator{}
}

pub fn (mut gen NameGenerator) next(prefix string) string {
    name := '${prefix}${gen.next_id}'
    gen.next_id++
    return name
}
