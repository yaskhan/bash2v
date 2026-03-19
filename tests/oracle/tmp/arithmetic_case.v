module main

import bash2v.bashrt

fn main() {
	mut st := bashrt.new_state()
	bashrt.set_scalar(mut st, 'x', bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: '5' })] })!)
	bashrt.set_scalar(mut st, 'y', bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: '2' })] })!)
	bashrt.run_exec_words(mut st, [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'echo' })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.DoubleQuotedFragment{ parts: [bashrt.WordFragment(bashrt.ArithmeticFragment{ expr: '1 + 2 * 3' }), bashrt.WordFragment(bashrt.LiteralFragment{ text: '|' }), bashrt.WordFragment(bashrt.ArithmeticFragment{ expr: 'x + y * 4' }), bashrt.WordFragment(bashrt.LiteralFragment{ text: '|' }), bashrt.WordFragment(bashrt.ArithmeticFragment{ expr: '-(x - 2)' })] })] }])!
	bashrt.exit_with_last_status(st)
}
