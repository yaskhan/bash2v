module bashrt

fn test_new_state_starts_empty() {
    state := new_state()
    assert state.args.len == 0
}

fn test_eval_word_with_scalar_and_case_ops() {
    mut state := new_state()
    set_scalar(mut state, 'name', 'HELLO')
    value := eval_word(mut state, Word{
        fragments: [
            WordFragment(ParamExpansion{
                name: 'name'
                op: ParamOp(ParamOpLowerAll{})
            }),
        ]
    }) or { panic(err) }
    assert value == 'hello'
}

fn test_eval_word_with_indexed_and_assoc_lookup() {
    mut state := new_state()
    set_indexed(mut state, 'arr', '3', 'value')
    set_assoc(mut state, 'map', 'foo', 'bar')

    indexed := eval_word(mut state, Word{
        fragments: [
            WordFragment(ParamExpansion{
                name: 'arr'
                index: Word{
                    fragments: [
                        WordFragment(LiteralFragment{
                            text: '3'
                        }),
                    ]
                }
            }),
        ]
    }) or { panic(err) }
    assoc := eval_word(mut state, Word{
        fragments: [
            WordFragment(ParamExpansion{
                name: 'map'
                index: Word{
                    fragments: [
                        WordFragment(LiteralFragment{
                            text: 'foo'
                        }),
                    ]
                }
            }),
        ]
    }) or { panic(err) }

    assert indexed == 'value'
    assert assoc == 'bar'
}

fn test_eval_word_with_indirection_and_replace_all() {
    mut state := new_state()
    set_scalar(mut state, 'ptr', 'name')
    set_scalar(mut state, 'name', 'abracadabra')
    value := eval_word(mut state, Word{
        fragments: [
            WordFragment(ParamExpansion{
                name: 'ptr'
                indirection: true
                op: ParamOp(ParamOpReplaceAll{
                    pattern: Word{
                        fragments: [WordFragment(LiteralFragment{ text: 'a' })]
                    }
                    replacement: Word{
                        fragments: [WordFragment(LiteralFragment{ text: 'X' })]
                    }
                })
            }),
        ]
    }) or { panic(err) }
    assert value == 'XbrXcXdXbrX'
}

fn test_eval_word_with_key_enumeration_and_length() {
    mut state := new_state()
    set_assoc(mut state, 'map', 'y', '2')
    set_assoc(mut state, 'map', 'x', '1')
    keys := eval_word(mut state, Word{
        fragments: [
            WordFragment(ParamExpansion{
                name: 'map'
                enumerate_keys: true
            }),
        ]
    }) or { panic(err) }
    length := eval_word(mut state, Word{
        fragments: [
            WordFragment(ParamExpansion{
                name: 'keys'
                op: ParamOp(ParamOpLength{})
            }),
        ]
    }) or { panic(err) }
    assert keys == 'x y'
    assert length == '0'
}

fn test_eval_word_with_array_item_count() {
    mut state := new_state()
    set_indexed(mut state, 'arr', '3', 'value')
    set_indexed(mut state, 'arr', '9', 'other')
    set_assoc(mut state, 'map', 'x', '1')
    set_assoc(mut state, 'map', 'y', '2')

    arr_count := eval_word(mut state, Word{
        fragments: [
            WordFragment(ParamExpansion{
                name: 'arr'
                count_items: true
                op: ParamOp(ParamOpLength{})
            }),
        ]
    }) or { panic(err) }
    map_count := eval_word(mut state, Word{
        fragments: [
            WordFragment(ParamExpansion{
                name: 'map'
                count_items: true
                op: ParamOp(ParamOpLength{})
            }),
        ]
    }) or { panic(err) }

    assert arr_count == '2'
    assert map_count == '2'
}

fn test_eval_word_with_command_substitution_captures_stdout() {
    mut state := new_state()
    value := eval_word(mut state, Word{
        fragments: [
            WordFragment(CommandSubstFragment{
                source: 'echo hello'
                program: EvalProgram{
                    stmts: [
                        EvalStmt(EvalExec{
                            argv: [
                                Word{
                                    fragments: [WordFragment(LiteralFragment{ text: 'echo' })]
                                },
                                Word{
                                    fragments: [WordFragment(LiteralFragment{ text: 'hello' })]
                                },
                            ]
                        }),
                    ]
                }
            }),
        ]
    }) or { panic(err) }
    assert value == 'hello'
}

fn test_eval_word_with_default_value_and_assign() {
    mut state := new_state()
    set_scalar(mut state, 'present', 'value')

    fallback := eval_word(mut state, Word{
        fragments: [
            WordFragment(ParamExpansion{
                name: 'missing'
                op: ParamOp(ParamOpDefaultValue{
                    fallback: Word{
                        fragments: [WordFragment(LiteralFragment{ text: 'fallback' })]
                    }
                })
            }),
        ]
    }) or { panic(err) }
    assigned := eval_word(mut state, Word{
        fragments: [
            WordFragment(ParamExpansion{
                name: 'created'
                op: ParamOp(ParamOpDefaultValue{
                    fallback: Word{
                        fragments: [WordFragment(LiteralFragment{ text: 'hello' })]
                    }
                    assign: true
                })
            }),
        ]
    }) or { panic(err) }
    present := eval_word(mut state, Word{
        fragments: [
            WordFragment(ParamExpansion{
                name: 'present'
                op: ParamOp(ParamOpDefaultValue{
                    fallback: Word{
                        fragments: [WordFragment(LiteralFragment{ text: 'other' })]
                    }
                })
            }),
        ]
    }) or { panic(err) }

    assert fallback == 'fallback'
    assert assigned == 'hello'
    assert present == 'value'
    assert get_scalar(state, 'created') == 'hello'
}

fn test_eval_word_with_alternative_value() {
    mut state := new_state()
    set_scalar(mut state, 'present', 'hello')
    set_scalar(mut state, 'empty', '')

    present := eval_word(mut state, Word{
        fragments: [
            WordFragment(ParamExpansion{
                name: 'present'
                op: ParamOp(ParamOpAlternativeValue{
                    alternate: Word{
                        fragments: [WordFragment(LiteralFragment{ text: 'alt' })]
                    }
                })
            }),
        ]
    }) or { panic(err) }
    missing := eval_word(mut state, Word{
        fragments: [
            WordFragment(ParamExpansion{
                name: 'missing'
                op: ParamOp(ParamOpAlternativeValue{
                    alternate: Word{
                        fragments: [WordFragment(LiteralFragment{ text: 'alt' })]
                    }
                })
            }),
        ]
    }) or { panic(err) }
    empty := eval_word(mut state, Word{
        fragments: [
            WordFragment(ParamExpansion{
                name: 'empty'
                op: ParamOp(ParamOpAlternativeValue{
                    alternate: Word{
                        fragments: [WordFragment(LiteralFragment{ text: 'alt' })]
                    }
                })
            }),
        ]
    }) or { panic(err) }

    assert present == 'alt'
    assert missing == ''
    assert empty == ''
}

fn test_eval_word_with_required_value_errors() {
    mut state := new_state()
    set_scalar(mut state, 'present', 'hello')

    present := eval_word(mut state, Word{
        fragments: [
            WordFragment(ParamExpansion{
                name: 'present'
                op: ParamOp(ParamOpRequiredValue{
                    message: Word{
                        fragments: [WordFragment(LiteralFragment{ text: 'required' })]
                    }
                })
            }),
        ]
    }) or { panic(err) }
    assert present == 'hello'

    eval_word(mut state, Word{
        fragments: [
            WordFragment(ParamExpansion{
                name: 'missing'
                op: ParamOp(ParamOpRequiredValue{
                    message: Word{
                        fragments: [WordFragment(LiteralFragment{ text: 'required-name' })]
                    }
                })
            }),
        ]
    }) or {
        assert err.msg() == 'required-name'
        return
    }
    assert false
}

fn test_append_scalar_and_indexed_values() {
    mut state := new_state()
    set_scalar(mut state, 'VAR1', 'qweqwe')
    append_scalar(mut state, 'VAR1', 'asdasd')
    set_indexed_values(mut state, 'ARR1', []string{})
    append_indexed_values(mut state, 'ARR1', ['item1', 'item2'])
    append_indexed_values(mut state, 'ARR1', ['it4', 'it5 ooo'])

    assert get_scalar(state, 'VAR1') == 'qweqweasdasd'
    assert get_indexed_or_assoc(state, 'ARR1', '0') == 'item1'
    assert get_indexed_or_assoc(state, 'ARR1', '1') == 'item2'
    assert get_indexed_or_assoc(state, 'ARR1', '2') == 'it4'
    assert get_indexed_or_assoc(state, 'ARR1', '3') == 'it5 ooo'
    assert count_items(state, 'ARR1') or { panic(err) } == '4'
}

fn test_eval_word_with_arithmetic_expansion() {
    mut state := new_state()
    set_scalar(mut state, 'x', '5')
    value := eval_word(mut state, Word{
        fragments: [
            WordFragment(ArithmeticFragment{
                expr: '1 + x * (2 + 3)'
            }),
        ]
    }) or { panic(err) }
    assert value == '26'
}

fn test_exec_condition_builtin_variants() {
    mut state := new_state()
    result1 := exec_external(mut state, ['test', '5', '-gt', '3']) or { panic(err) }
    result2 := exec_external(mut state, ['[', 'foo', '=', 'foo', ']']) or { panic(err) }
    result3 := exec_external(mut state, ['[[', '-n', 'bar', ']]']) or { panic(err) }
    result4 := exec_external(mut state, ['[[', '-z', 'bar', ']]']) or { panic(err) }

    assert result1.status == 0
    assert result2.status == 0
    assert result3.status == 0
    assert result4.status == 1
}
