module bashrt

pub fn expand_param(mut state State, param ParamExpansion) !string {
    return expand_param_values(mut state, param, false)!.join(' ')
}

pub fn expand_param_values(mut state State, param ParamExpansion, quoted bool) ![]string {
    if param.count_items && param.op is ParamOpLength {
        return [count_items(state, param.name)!]
    }
    if param.op is ParamOpDefaultValue {
        return [expand_default_value(mut state, param, param.op)!]
    }
    if param.op is ParamOpAlternativeValue {
        return [expand_alternative_value(mut state, param, param.op)!]
    }
    if param.op is ParamOpRequiredValue {
        return [expand_required_value(mut state, param, param.op)!]
    }
    if param.array_mode != .none {
        values := resolve_param_array_values(state, param)!
        if param.array_mode == .all_star {
            joined := values.join(' ')
            if quoted {
                return [joined]
            }
            return split_fields(joined)
        }
        if quoted {
            return values
        }
        return values
    }
    mut value := resolve_param_value(mut state, param)!
    value = apply_param_op(mut state, value, param.op)!
    return [value]
}

fn resolve_param_value(mut state State, param ParamExpansion) !string {
    if param.count_items {
        return count_items(state, param.name)!
    }
    if param.enumerate_keys {
        return enumerate_keys(state, param.name)!
    }

    if param.indirection {
        target_name := get_scalar(state, param.name)
        if target_name == '' {
            return ''
        }
        if idx_word := param.index {
            index := eval_word(mut state, idx_word)!
            return get_indexed_or_assoc(state, target_name, index)
        }
        return get_scalar(state, target_name)
    }

    if idx_word := param.index {
        index := eval_word(mut state, idx_word)!
        return get_indexed_or_assoc(state, param.name, index)
    }

    return get_scalar(state, param.name)
}

fn resolve_param_array_values(state State, param ParamExpansion) ![]string {
    if param.name !in state.vars {
        return []string{}
    }
    value := state.vars[param.name] or { return []string{} }
    match value {
        IndexedArray {
            mut keys := []int{}
            for key, _ in value.items {
                keys << key
            }
            keys.sort()
            mut out := []string{}
            for key in keys {
                out << value.items[key] or { '' }
            }
            return out
        }
        AssocArray {
            mut keys := []string{}
            for key, _ in value.items {
                keys << key
            }
            keys.sort()
            mut out := []string{}
            for key in keys {
                out << value.items[key] or { '' }
            }
            return out
        }
        Scalar {
            return [value.value]
        }
    }
}

fn apply_param_op(mut state State, input string, op ParamOp) !string {
    return match op {
        ParamOpNone {
            input
        }
        ParamOpLowerAll {
            lower_all(input)
        }
        ParamOpUpperAll {
            upper_all(input)
        }
        ParamOpReplaceOne {
            pattern := eval_word(mut state, op.pattern)!
            replacement := eval_word(mut state, op.replacement)!
            replace_one(input, Pattern{
                source: pattern
            }, replacement)
        }
        ParamOpReplaceAll {
            pattern := eval_word(mut state, op.pattern)!
            replacement := eval_word(mut state, op.replacement)!
            replace_all(input, Pattern{
                source: pattern
            }, replacement)
        }
        ParamOpLength {
            input.len.str()
        }
        ParamOpDefaultValue {
            input
        }
        ParamOpAlternativeValue {
            input
        }
        ParamOpRequiredValue {
            input
        }
    }
}

fn split_fields(input string) []string {
    mut fields := []string{}
    mut start := -1
    for idx, ch in input {
        if ch in [` `, `\t`, `\n`] {
            if start >= 0 {
                fields << input[start..idx]
                start = -1
            }
            continue
        }
        if start < 0 {
            start = idx
        }
    }
    if start >= 0 {
        fields << input[start..]
    }
    return fields
}

fn expand_default_value(mut state State, param ParamExpansion, op ParamOpDefaultValue) !string {
    exists, value := resolve_param_slot(mut state, param)!
    if exists && value != '' {
        return value
    }
    fallback := eval_word(mut state, op.fallback)!
    if op.assign {
        assign_param_value(mut state, param, fallback)!
    }
    return fallback
}

fn expand_alternative_value(mut state State, param ParamExpansion, op ParamOpAlternativeValue) !string {
    exists, value := resolve_param_slot(mut state, param)!
    if exists && value != '' {
        return eval_word(mut state, op.alternate)!
    }
    return ''
}

fn expand_required_value(mut state State, param ParamExpansion, op ParamOpRequiredValue) !string {
    exists, value := resolve_param_slot(mut state, param)!
    if exists && value != '' {
        return value
    }
    message := eval_word(mut state, op.message)!
    if message == '' {
        return error('${param.name}: parameter is null or not set')
    }
    return error(message)
}

fn resolve_param_slot(mut state State, param ParamExpansion) !(bool, string) {
    if param.indirection {
        target_name := get_scalar(state, param.name)
        if target_name == '' {
            return false, ''
        }
        if idx_word := param.index {
            index := eval_word(mut state, idx_word)!
            return lookup_indexed_or_assoc(state, target_name, index)
        }
        return lookup_named_value(state, target_name)
    }

    if idx_word := param.index {
        index := eval_word(mut state, idx_word)!
        return lookup_indexed_or_assoc(state, param.name, index)
    }

    return lookup_named_value(state, param.name)
}

fn lookup_named_value(state State, name string) (bool, string) {
    if name in state.vars {
        value := state.vars[name] or { return false, '' }
        match value {
            Scalar {
                return true, value.value
            }
            IndexedArray {
                return value.items.len > 0, indexed_array_to_string(value)
            }
            AssocArray {
                return value.items.len > 0, assoc_array_to_string(value)
            }
        }
    }
    if name in state.env {
        return true, state.env[name]
    }
    return false, ''
}

fn lookup_indexed_or_assoc(state State, name string, key string) (bool, string) {
    if name !in state.vars {
        return false, ''
    }
    value := state.vars[name] or { return false, '' }
    match value {
        IndexedArray {
            idx := key.int()
            if idx in value.items {
                return true, value.items[idx] or { '' }
            }
            return false, ''
        }
        AssocArray {
            if key in value.items {
                return true, value.items[key] or { '' }
            }
            return false, ''
        }
        Scalar {
            return true, value.value
        }
    }
}

fn assign_param_value(mut state State, param ParamExpansion, value string) ! {
    if param.indirection {
        return
    }
    if idx_word := param.index {
        index := eval_word(mut state, idx_word)!
        if param.name in state.vars {
            existing := state.vars[param.name] or { Value(new_indexed_array()) }
            match existing {
                IndexedArray {
                    set_indexed(mut state, param.name, index, value)
                }
                AssocArray {
                    set_assoc(mut state, param.name, index, value)
                }
                Scalar {
                    set_scalar(mut state, param.name, value)
                }
            }
            return
        }
        if is_decimal_key(index) {
            set_indexed(mut state, param.name, index, value)
        } else {
            set_assoc(mut state, param.name, index, value)
        }
        return
    }
    set_scalar(mut state, param.name, value)
}

fn is_decimal_key(input string) bool {
    if input.len == 0 {
        return false
    }
    for ch in input {
        if ch < `0` || ch > `9` {
            return false
        }
    }
    return true
}
