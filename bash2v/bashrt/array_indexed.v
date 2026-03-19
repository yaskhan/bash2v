module bashrt

pub fn new_indexed_array() IndexedArray {
    return IndexedArray{
        items: map[int]string{}
        max_index: -1
    }
}
