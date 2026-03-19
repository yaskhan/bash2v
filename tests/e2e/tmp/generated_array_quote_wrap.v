module main

import bash2v.bashrt

fn main() {
	mut st := bashrt.new_state()
	bashrt.set_indexed_values(mut st, 'arr2', [])
	bashrt.append_indexed_values(mut st, 'arr2', [bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'aaa' })] })!])
	bashrt.run_exec_words(mut st, [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'echo' })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.DoubleQuotedFragment{ parts: [bashrt.WordFragment(bashrt.LiteralFragment{ text: '\'' }), bashrt.WordFragment(bashrt.ParamExpansion{ name: 'arr2', index: bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: '0' })] }, indirection: false, enumerate_keys: false, count_items: false, array_mode: bashrt.ParamArrayMode.none, op: bashrt.ParamOp(bashrt.ParamOpNone{}) }), bashrt.WordFragment(bashrt.LiteralFragment{ text: '\'' })] })] }])!
	bashrt.exit_with_last_status(st)
}
