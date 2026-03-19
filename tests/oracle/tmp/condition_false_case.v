module main

import bash2v.bashrt

fn main() {
	mut st := bashrt.new_state()
	bashrt.run_exec_words(mut st, [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: '[' }), bashrt.WordFragment(bashrt.LiteralFragment{ text: '[' })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: '-z' })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'bar' })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: ']' }), bashrt.WordFragment(bashrt.LiteralFragment{ text: ']' })] }])!
	bashrt.exit_with_last_status(st)
}
