module main

import bash2v.bashrt

fn main() {
	mut st := bashrt.new_state()
	bashrt.set_scalar(mut st, 'present', bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'hello' })] })!)
	bashrt.run_exec(mut st, [bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'echo' })] })!, bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.DoubleQuotedFragment{ parts: [bashrt.WordFragment(bashrt.ParamExpansion{ name: 'missing', index: none, indirection: false, enumerate_keys: false, count_items: false, op: bashrt.ParamOp(bashrt.ParamOpDefaultValue{ fallback: bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'fallback' })] }, assign: false }) }), bashrt.WordFragment(bashrt.LiteralFragment{ text: ' ' }), bashrt.WordFragment(bashrt.ParamExpansion{ name: 'present', index: none, indirection: false, enumerate_keys: false, count_items: false, op: bashrt.ParamOp(bashrt.ParamOpDefaultValue{ fallback: bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'other' })] }, assign: false }) })] })] })!])!
	bashrt.run_exec(mut st, [bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'echo' })] })!, bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.DoubleQuotedFragment{ parts: [bashrt.WordFragment(bashrt.ParamExpansion{ name: 'created', index: none, indirection: false, enumerate_keys: false, count_items: false, op: bashrt.ParamOp(bashrt.ParamOpDefaultValue{ fallback: bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'world' })] }, assign: true }) }), bashrt.WordFragment(bashrt.LiteralFragment{ text: ' ' }), bashrt.WordFragment(bashrt.ParamExpansion{ name: 'created', index: none, indirection: false, enumerate_keys: false, count_items: false, op: bashrt.ParamOp(bashrt.ParamOpNone{}) })] })] })!])!
}
