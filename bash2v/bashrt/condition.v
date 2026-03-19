module bashrt

pub fn exec_condition(argv []string) ExecResult {
    if argv.len == 0 {
        return ExecResult{}
    }
    cmd := argv[0]
    mut args := argv[1..].clone()
    if cmd == '[' {
        if args.len == 0 || args[args.len - 1] != ']' {
            return ExecResult{
                stderr: '[: missing ]\n'
                status: 2
            }
        }
        args = args[..args.len - 1].clone()
    } else if cmd == '[[' {
        if args.len == 0 || args[args.len - 1] != ']]' {
            return ExecResult{
                stderr: '[[ : missing ]]\n'
                status: 2
            }
        }
        args = args[..args.len - 1].clone()
    }

    ok := eval_condition_expr(args) or {
        return ExecResult{
            stderr: err.msg() + '\n'
            status: 2
        }
    }
    return ExecResult{
        status: if ok { 0 } else { 1 }
    }
}

fn eval_condition_expr(args []string) !bool {
    if args.len == 0 {
        return false
    }
    if args[0] == '!' {
        return !eval_condition_expr(args[1..])!
    }
    if args.len == 1 {
        return args[0] != ''
    }
    if args.len == 2 {
        return match args[0] {
            '-n' { args[1] != '' }
            '-z' { args[1] == '' }
            else { error('unsupported unary test operator: ${args[0]}') }
        }
    }
    if args.len != 3 {
        return error('unsupported test expression')
    }

    left := args[0]
    op := args[1]
    right := args[2]
    return match op {
        '=', '==' { left == right }
        '!=' { left != right }
        '<' { left < right }
        '>' { left > right }
        '-eq' { parse_test_int(left)! == parse_test_int(right)! }
        '-ne' { parse_test_int(left)! != parse_test_int(right)! }
        '-gt' { parse_test_int(left)! > parse_test_int(right)! }
        '-ge' { parse_test_int(left)! >= parse_test_int(right)! }
        '-lt' { parse_test_int(left)! < parse_test_int(right)! }
        '-le' { parse_test_int(left)! <= parse_test_int(right)! }
        else { error('unsupported binary test operator: ${op}') }
    }
}

fn parse_test_int(input string) !int {
    if input.len == 0 {
        return error('integer expression expected')
    }
    mut start := 0
    if input[0] in [`+`, `-`] {
        if input.len == 1 {
            return error('integer expression expected')
        }
        start = 1
    }
    for ch in input[start..] {
        if ch < `0` || ch > `9` {
            return error('integer expression expected')
        }
    }
    return input.int()
}
