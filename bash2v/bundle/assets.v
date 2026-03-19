module bundle

import os

struct BundledFile {
	path    string
	content string
}

const bundled_runtime_files = [
	BundledFile{
		path: 'bash2v/bash2v.v'
		content: $embed_file('../bash2v.v').to_string()
	},
	BundledFile{
		path: 'bash2v/ast/commands.v'
		content: $embed_file('../ast/commands.v').to_string()
	},
	BundledFile{
		path: 'bash2v/ast/nodes.v'
		content: $embed_file('../ast/nodes.v').to_string()
	},
	BundledFile{
		path: 'bash2v/ast/print.v'
		content: $embed_file('../ast/print.v').to_string()
	},
	BundledFile{
		path: 'bash2v/ast/words.v'
		content: $embed_file('../ast/words.v').to_string()
	},
	BundledFile{
		path: 'bash2v/lower/ir.v'
		content: $embed_file('../lower/ir.v').to_string()
	},
	BundledFile{
		path: 'bash2v/lower/lower_command.v'
		content: $embed_file('../lower/lower_command.v').to_string()
	},
	BundledFile{
		path: 'bash2v/lower/lower_program.v'
		content: $embed_file('../lower/lower_program.v').to_string()
	},
	BundledFile{
		path: 'bash2v/lower/lower_word.v'
		content: $embed_file('../lower/lower_word.v').to_string()
	},
	BundledFile{
		path: 'bash2v/bashrt/arithmetic.v'
		content: $embed_file('../bashrt/arithmetic.v').to_string()
	},
	BundledFile{
		path: 'bash2v/bashrt/array_assoc.v'
		content: $embed_file('../bashrt/array_assoc.v').to_string()
	},
	BundledFile{
		path: 'bash2v/bashrt/array_indexed.v'
		content: $embed_file('../bashrt/array_indexed.v').to_string()
	},
	BundledFile{
		path: 'bash2v/bashrt/case_ops.v'
		content: $embed_file('../bashrt/case_ops.v').to_string()
	},
	BundledFile{
		path: 'bash2v/bashrt/command_subst.v'
		content: $embed_file('../bashrt/command_subst.v').to_string()
	},
	BundledFile{
		path: 'bash2v/bashrt/condition.v'
		content: $embed_file('../bashrt/condition.v').to_string()
	},
	BundledFile{
		path: 'bash2v/bashrt/expand.v'
		content: $embed_file('../bashrt/expand.v').to_string()
	},
	BundledFile{
		path: 'bash2v/bashrt/expand_param.v'
		content: $embed_file('../bashrt/expand_param.v').to_string()
	},
	BundledFile{
		path: 'bash2v/bashrt/expand_word.v'
		content: $embed_file('../bashrt/expand_word.v').to_string()
	},
	BundledFile{
		path: 'bash2v/bashrt/pattern_replace.v'
		content: $embed_file('../bashrt/pattern_replace.v').to_string()
	},
	BundledFile{
		path: 'bash2v/bashrt/split.v'
		content: $embed_file('../bashrt/split.v').to_string()
	},
	BundledFile{
		path: 'bash2v/bashrt/state.v'
		content: $embed_file('../bashrt/state.v').to_string()
	},
	BundledFile{
		path: 'bash2v/bashrt/value.v'
		content: $embed_file('../bashrt/value.v').to_string()
	},
	BundledFile{
		path: 'v_scr/builtins.v'
		content: $embed_file('../../v_scr/builtins.v').to_string()
	},
	BundledFile{
		path: 'v_scr/expand.v'
		content: $embed_file('../../v_scr/expand.v').to_string()
	},
	BundledFile{
		path: 'v_scr/filters.v'
		content: $embed_file('../../v_scr/filters.v').to_string()
	},
	BundledFile{
		path: 'v_scr/internal.v'
		content: $embed_file('../../v_scr/internal.v').to_string()
	},
	BundledFile{
		path: 'v_scr/list.v'
		content: $embed_file('../../v_scr/list.v').to_string()
	},
	BundledFile{
		path: 'v_scr/logic.v'
		content: $embed_file('../../v_scr/logic.v').to_string()
	},
	BundledFile{
		path: 'v_scr/pipe.v'
		content: $embed_file('../../v_scr/pipe.v').to_string()
	},
	BundledFile{
		path: 'v_scr/pipeline.v'
		content: $embed_file('../../v_scr/pipeline.v').to_string()
	},
	BundledFile{
		path: 'v_scr/process.v'
		content: $embed_file('../../v_scr/process.v').to_string()
	},
	BundledFile{
		path: 'v_scr/result.v'
		content: $embed_file('../../v_scr/result.v').to_string()
	},
	BundledFile{
		path: 'v_scr/sinks.v'
		content: $embed_file('../../v_scr/sinks.v').to_string()
	},
	BundledFile{
		path: 'v_scr/sources.v'
		content: $embed_file('../../v_scr/sources.v').to_string()
	},
	BundledFile{
		path: 'v_scr/step.v'
		content: $embed_file('../../v_scr/step.v').to_string()
	},
]

const bundle_vmod = "Module {\n\tname: 'bash2v_bundle'\n\tdescription: 'Self-contained transpiled Bash runtime bundle.'\n\tversion: '0.1.0'\n}\n"

pub fn write_runtime_bundle(output_dir string) ! {
	os.mkdir_all(output_dir)!
	for file in bundled_runtime_files {
		target_path := os.join_path(output_dir, file.path)
		os.mkdir_all(os.dir(target_path))!
		os.write_file(target_path, file.content)!
	}
	os.write_file(os.join_path(output_dir, 'v.mod'), bundle_vmod)!
}
