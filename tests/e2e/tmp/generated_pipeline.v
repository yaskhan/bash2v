module main

import bash2v.bashrt

fn main() {
	mut st := bashrt.new_state()
	bashrt.run_pipeline_words(mut st, [[bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'printf' })] })!, bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: '%s\\n' })] })!, bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'alpha' })] })!, bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'beta' })] })!], [bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'grep' })] })!, bashrt.eval_word(mut st, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'beta' })] })!]])!
}
