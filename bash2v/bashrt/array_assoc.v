module bashrt

pub fn new_assoc_array() AssocArray {
    return AssocArray{
        items: map[string]string{}
    }
}
