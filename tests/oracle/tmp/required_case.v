module main

import bash2v.bashrt

fn main() {
	mut st := bashrt.new_state()
	bashrt.run_exec_words(mut st, [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'echo' })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.DoubleQuotedFragment{ parts: [bashrt.WordFragment(bashrt.ParamExpansion{ name: 'missing', index: none, indirection: false, enumerate_keys: false, count_items: false, array_mode: bashrt.ParamArrayMode.none, op: bashrt.ParamOp(bashrt.ParamOpRequiredValue{ message: bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'required-name' })] } }) })] })] }])!
	bashrt.exit_with_last_status(st)
}
