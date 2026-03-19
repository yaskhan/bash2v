module main

import bash2v.bashrt

fn main() {
	mut st := bashrt.new_state()
	bashrt.set_indexed_values(mut st, 'arr', [bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'i1' })] })!, bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'i2' })] })!, bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.DoubleQuotedFragment{ parts: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'i3' }), bashrt.WordFragment(bashrt.LiteralFragment{ text: ' ' }), bashrt.WordFragment(bashrt.LiteralFragment{ text: 'i4' })] })] })!])
	{
		mut bash2v_for_ran := false
		for bash2v_item_i in bashrt.eval_words_to_argv(mut st, [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.ParamExpansion{ name: 'arr', index: none, indirection: false, enumerate_keys: false, count_items: false, array_mode: bashrt.ParamArrayMode.all_star, op: bashrt.ParamOp(bashrt.ParamOpNone{}) })] }])! {
			bash2v_for_ran = true
			bashrt.set_last_status(mut st, 0)
			bashrt.set_scalar(mut st, 'i', bash2v_item_i)
			bashrt.run_exec_words(mut st, [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'echo' })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.DoubleQuotedFragment{ parts: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'i' }), bashrt.WordFragment(bashrt.LiteralFragment{ text: '=' }), bashrt.WordFragment(bashrt.ParamExpansion{ name: 'i', index: none, indirection: false, enumerate_keys: false, count_items: false, array_mode: bashrt.ParamArrayMode.none, op: bashrt.ParamOp(bashrt.ParamOpNone{}) })] })] }])!
		}
		if !bash2v_for_ran {
			bashrt.set_last_status(mut st, 0)
		}
	}
	bashrt.exit_with_last_status(st)
}
