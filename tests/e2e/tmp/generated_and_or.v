module main

import bash2v.bashrt

fn main() {
	mut st := bashrt.new_state()
	bashrt.run_and_or(mut st, bashrt.EvalAndOr{ first: bashrt.EvalProgram{ stmts: [bashrt.EvalStmt(bashrt.EvalExec{ assignments: [], argv: [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'false' })] }] })] }, items: [bashrt.EvalAndOrArm{ op: bashrt.EvalLogicalOp.and_if, program: bashrt.EvalProgram{ stmts: [bashrt.EvalStmt(bashrt.EvalExec{ assignments: [], argv: [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'echo' })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'no' })] }] })] } }] })!
	bashrt.run_and_or(mut st, bashrt.EvalAndOr{ first: bashrt.EvalProgram{ stmts: [bashrt.EvalStmt(bashrt.EvalExec{ assignments: [], argv: [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'false' })] }] })] }, items: [bashrt.EvalAndOrArm{ op: bashrt.EvalLogicalOp.or_if, program: bashrt.EvalProgram{ stmts: [bashrt.EvalStmt(bashrt.EvalExec{ assignments: [], argv: [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'echo' })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'yes' })] }] })] } }] })!
	bashrt.run_and_or(mut st, bashrt.EvalAndOr{ first: bashrt.EvalProgram{ stmts: [bashrt.EvalStmt(bashrt.EvalExec{ assignments: [], argv: [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'true' })] }] })] }, items: [bashrt.EvalAndOrArm{ op: bashrt.EvalLogicalOp.and_if, program: bashrt.EvalProgram{ stmts: [bashrt.EvalStmt(bashrt.EvalExec{ assignments: [], argv: [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'echo' })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'ok' })] }] })] } }] })!
	bashrt.run_and_or(mut st, bashrt.EvalAndOr{ first: bashrt.EvalProgram{ stmts: [bashrt.EvalStmt(bashrt.EvalExec{ assignments: [], argv: [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'true' })] }] })] }, items: [bashrt.EvalAndOrArm{ op: bashrt.EvalLogicalOp.or_if, program: bashrt.EvalProgram{ stmts: [bashrt.EvalStmt(bashrt.EvalExec{ assignments: [], argv: [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'echo' })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'no' })] }] })] } }] })!
	{
		if bashrt.eval_program_condition(mut st, bashrt.EvalProgram{ stmts: [bashrt.EvalStmt(bashrt.EvalAndOr{ first: bashrt.EvalProgram{ stmts: [bashrt.EvalStmt(bashrt.EvalExec{ assignments: [], argv: [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'false' })] }] })] }, items: [bashrt.EvalAndOrArm{ op: bashrt.EvalLogicalOp.or_if, program: bashrt.EvalProgram{ stmts: [bashrt.EvalStmt(bashrt.EvalExec{ assignments: [], argv: [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'true' })] }] })] } }] })] })! == 0 {
			bashrt.set_last_status(mut st, 0)
			bashrt.run_exec_words(mut st, [bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'echo' })] }, bashrt.Word{ fragments: [bashrt.WordFragment(bashrt.LiteralFragment{ text: 'cond' })] }])!
		} else {
			bashrt.set_last_status(mut st, 0)
		}
	}
	bashrt.exit_with_last_status(st)
}
