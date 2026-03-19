module main

import os
import bash2v.cli

fn main() {
    exit_code := cli.run(os.args) or {
        eprintln(err.msg())
        exit(1)
    }
    exit(exit_code)
}
