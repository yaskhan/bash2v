module main

import bash2v.bashrt

fn main() {
	mut st := bashrt.new_state()
	bashrt.set_scalar(mut st, 'present', bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'hello' })] })!)
	bashrt.set_scalar(mut st, 'empty', bashrt.eval_word(mut st, bashrt.Word{ fragments: [] })!)
	bashrt.run_exec_words(mut st, [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'echo' })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.DoubleQuotedFragment{ parts: [bashrt.WordFragment(bashrt.ParamExpansion{ name: 'present', index: none, indirection: false, enumerate_keys: false, count_items: false, array_mode: bashrt.ParamArrayMode.none, op: bashrt.ParamOp(bashrt.ParamOpAlternativeValue{ alternate: bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'alt' })] } }) }), bashrt.WordFragment(bashrt.LiteralFragment{ text: '|' }), bashrt.WordFragment(bashrt.ParamExpansion{ name: 'missing', index: none, indirection: false, enumerate_keys: false, count_items: false, array_mode: bashrt.ParamArrayMode.none, op: bashrt.ParamOp(bashrt.ParamOpAlternativeValue{ alternate: bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'no' })] } }) }), bashrt.WordFragment(bashrt.LiteralFragment{ text: '|' }), bashrt.WordFragment(bashrt.ParamExpansion{ name: 'empty', index: none, indirection: false, enumerate_keys: false, count_items: false, array_mode: bashrt.ParamArrayMode.none, op: bashrt.ParamOp(bashrt.ParamOpAlternativeValue{ alternate: bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'skip' })] } }) })] })] }])!
	bashrt.exit_with_last_status(st)
}
