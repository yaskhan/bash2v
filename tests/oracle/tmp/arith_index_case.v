module main

import bash2v.bashrt

fn main() {
	mut st := bashrt.new_state()
	bashrt.set_scalar(mut st, 'i', bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: '1' })] })!)
	bashrt.set_scalar(mut st, 'i', bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.ArithmeticFragment{ expr: 'i + 1' })] })!)
	bashrt.set_indexed(mut st, 'arr', bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.ArithmeticFragment{ expr: 'i + 1' })] })!, bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.ArithmeticFragment{ expr: 'i + 4' })] })!)
	bashrt.run_exec_words(mut st, [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'echo' })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.DoubleQuotedFragment{ parts: [bashrt.WordFragment(bashrt.ParamExpansion{ name: 'i', index: none, indirection: false, enumerate_keys: false, count_items: false, array_mode: bashrt.ParamArrayMode.none, op: bashrt.ParamOp(bashrt.ParamOpNone{}) }), bashrt.WordFragment(bashrt.LiteralFragment{ text: '|' }), bashrt.WordFragment(bashrt.ParamExpansion{ name: 'arr', index: bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.ArithmeticFragment{ expr: 'i + 1' })] }, indirection: false, enumerate_keys: false, count_items: false, array_mode: bashrt.ParamArrayMode.none, op: bashrt.ParamOp(bashrt.ParamOpNone{}) })] })] }])!
	bashrt.exit_with_last_status(st)
}
