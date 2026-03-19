module main

import bash2v.bashrt

fn main() {
	mut st := bashrt.new_state()
	bashrt.run_exec_words(mut st, [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'echo' })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'hello' })] }])!
	bashrt.exit_with_last_status(st)
}
