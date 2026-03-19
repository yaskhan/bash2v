module main

import bash2v.bashrt

fn main() {
	mut st := bashrt.new_state()
	{
		mut bash2v_for_ran := false
		for bash2v_item_item in bashrt.eval_words_to_argv(mut st, [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'one' })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.DoubleQuotedFragment{ parts: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'two' }), bashrt.WordFragment(bashrt.LiteralFragment{ text: ' ' }), bashrt.WordFragment(bashrt.LiteralFragment{ text: 'words' })] })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'three' })] }])! {
			bash2v_for_ran = true
			bashrt.set_last_status(mut st, 0)
			bashrt.set_scalar(mut st, 'item', bash2v_item_item)
			bashrt.run_exec_words(mut st, [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'echo' })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.DoubleQuotedFragment{ parts: [bashrt.WordFragment(bashrt.ParamExpansion{ name: 'item', index: none, indirection: false, enumerate_keys: false, count_items: false, array_mode: bashrt.ParamArrayMode.none, op: bashrt.ParamOp(bashrt.ParamOpNone{}) })] })] }])!
		}
		if !bash2v_for_ran {
			bashrt.set_last_status(mut st, 0)
		}
	}
	bashrt.exit_with_last_status(st)
}
