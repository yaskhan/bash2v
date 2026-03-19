module main

import bash2v.bashrt

fn main() {
	mut st := bashrt.new_state()
	bashrt.run_pipeline_word_parts(mut st, [[bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'printf' })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: '%s\\n' })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'alpha' })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'beta' })] }], [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'grep' })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'beta' })] }]])!
	bashrt.exit_with_last_status(st)
}
