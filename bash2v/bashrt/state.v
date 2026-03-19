module bashrt

pub struct State {
mut:
    vars        map[string]Value
    env         map[string]string
    args        []string
    last_status int
}

pub fn new_state() State {
    return State{
        vars: map[string]Value{}
        env: map[string]string{}
        args: []string{}
    }
}

pub fn set_scalar(mut state State, name string, value string) {
    state.vars[name] = Value(Scalar{
        value: value
    })
}

pub fn append_scalar(mut state State, name string, value string) {
    current := get_scalar(state, name)
    set_scalar(mut state, name, current + value)
}

pub fn declare_indexed(mut state State, name string) {
    state.vars[name] = Value(new_indexed_array())
}

pub fn declare_assoc(mut state State, name string) {
    state.vars[name] = Value(new_assoc_array())
}

pub fn set_indexed(mut state State, name string, index string, value string) {
    existing := state.vars[name] or { Value(new_indexed_array()) }
    mut arr := match existing {
        IndexedArray { Value(existing) }
        else { Value(new_indexed_array()) }
    }
    match mut arr {
        IndexedArray {
            idx := index.int()
            arr.items[idx] = value
            if idx > arr.max_index {
                arr.max_index = idx
            }
        }
        else {}
    }
    state.vars[name] = arr
}

pub fn set_indexed_values(mut state State, name string, values []string) {
    mut arr := new_indexed_array()
    for idx, value in values {
        arr.items[idx] = value
        arr.max_index = idx
    }
    state.vars[name] = Value(arr)
}

pub fn append_indexed_values(mut state State, name string, values []string) {
    existing := state.vars[name] or { Value(new_indexed_array()) }
    mut arr := match existing {
        IndexedArray { Value(existing) }
        else { Value(new_indexed_array()) }
    }
    match mut arr {
        IndexedArray {
            mut next_idx := arr.max_index + 1
            for value in values {
                arr.items[next_idx] = value
                arr.max_index = next_idx
                next_idx++
            }
        }
        else {}
    }
    state.vars[name] = arr
}

pub fn append_indexed_at(mut state State, name string, index string, value string) {
    current := get_indexed_or_assoc(state, name, index)
    set_indexed(mut state, name, index, current + value)
}

pub fn set_assoc(mut state State, name string, key string, value string) {
    existing := state.vars[name] or { Value(new_assoc_array()) }
    mut arr := match existing {
        AssocArray { Value(existing) }
        else { Value(new_assoc_array()) }
    }
    match mut arr {
        AssocArray {
            arr.items[key] = value
        }
        else {}
    }
    state.vars[name] = arr
}

pub fn append_assoc(mut state State, name string, key string, value string) {
    current := get_indexed_or_assoc(state, name, key)
    set_assoc(mut state, name, key, current + value)
}

pub fn join_parts(parts []string) string {
    return parts.join('')
}

pub fn get_scalar(state State, name string) string {
    if name in state.vars {
        value := state.vars[name] or { return '' }
        match value {
            Scalar {
                return value.value
            }
            IndexedArray {
                return indexed_array_to_string(value)
            }
            AssocArray {
                return assoc_array_to_string(value)
            }
        }
    }
    if name in state.env {
        return state.env[name]
    }
    return ''
}

pub fn get_indexed_or_assoc(state State, name string, key string) string {
    if name !in state.vars {
        return ''
    }
    value := state.vars[name] or { return '' }
    match value {
        IndexedArray {
            idx := key.int()
            return value.items[idx] or { '' }
        }
        AssocArray {
            return value.items[key] or { '' }
        }
        Scalar {
            return ''
        }
    }
}

pub fn enumerate_keys(state State, name string) !string {
    if name !in state.vars {
        return ''
    }
    value := state.vars[name] or { return '' }
    match value {
        IndexedArray {
            mut keys := []int{}
            for key, _ in value.items {
                keys << key
            }
            keys.sort()
            mut out := []string{}
            for key in keys {
                out << key.str()
            }
            return out.join(' ')
        }
        AssocArray {
            mut keys := []string{}
            for key, _ in value.items {
                keys << key
            }
            keys.sort()
            return keys.join(' ')
        }
        Scalar {
            return ''
        }
    }
}

pub fn count_items(state State, name string) !string {
    if name !in state.vars {
        return '0'
    }
    value := state.vars[name] or { return '0' }
    match value {
        IndexedArray {
            return value.items.len.str()
        }
        AssocArray {
            return value.items.len.str()
        }
        Scalar {
            return '0'
        }
    }
}

fn indexed_array_to_string(arr IndexedArray) string {
    mut keys := []int{}
    for key, _ in arr.items {
        keys << key
    }
    keys.sort()
    mut out := []string{}
    for key in keys {
        out << arr.items[key] or { '' }
    }
    return out.join(' ')
}

fn assoc_array_to_string(arr AssocArray) string {
    mut keys := []string{}
    for key, _ in arr.items {
        keys << key
    }
    keys.sort()
    mut out := []string{}
    for key in keys {
        out << arr.items[key] or { '' }
    }
    return out.join(' ')
}
