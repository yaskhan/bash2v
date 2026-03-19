module bashrt

pub type Value = Scalar | IndexedArray | AssocArray

pub struct Scalar {
pub:
    value string
}

pub struct IndexedArray {
mut:
    items     map[int]string
    max_index int
}

pub struct AssocArray {
mut:
    items map[string]string
}
