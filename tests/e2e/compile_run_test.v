module e2e

import os
import bash2v

fn test_generated_v_can_run_simple_echo_script() {
    result := transpile_and_run('generated_echo.v', 'echo hello')
    assert result.exit_code == 0
    assert result.output == 'hello\n'
}

fn test_generated_v_can_run_pipeline_script() {
    result := transpile_and_run('generated_pipeline.v', "printf '%s\\n' alpha beta | grep beta")
    assert result.exit_code == 0
    assert result.output == 'beta\n'
}

fn test_generated_v_can_run_nested_command_substitution() {
    result := transpile_and_run('generated_nested.v', r'echo "$(printf "%s" "$(echo hi)")"')
    assert result.exit_code == 0
    assert result.output == 'hi\n'
}

fn test_generated_v_can_run_indexed_and_assoc_arrays() {
    result := transpile_and_run('generated_arrays.v', r'arr[3]=value
arr[9]=other
declare -A map
map[foo]=bar
map[zoo]=qux
echo "${arr[3]} ${map[foo]} ${!map[@]} ${#arr[@]} ${#map[@]}"')
    assert result.exit_code == 0
    assert result.output == 'value bar foo zoo 2 2\n'
}

fn test_generated_v_can_run_complex_parameter_expansion() {
    result := transpile_and_run('generated_expansion.v', r'target=name
name=HELLO
value=abracadabra
echo "${!target} ${name,,} ${value//a/X} ${#name}"')
    assert result.exit_code == 0
    assert result.output == 'HELLO hello XbrXcXdXbrX 5\n'
}

fn test_generated_v_can_run_default_value_expansion() {
    result := transpile_and_run('generated_default_value.v', r'present=hello
echo "${missing:-fallback} ${present:-other}"
echo "${created:=world} ${created}"')
    assert result.exit_code == 0
    assert result.output == 'fallback hello\nworld world\n'
}

fn test_generated_v_can_run_alternative_value_expansion() {
    result := transpile_and_run('generated_alternative_value.v', r'present=hello
empty=
echo "${present:+alt}|${missing:+no}|${empty:+skip}"')
    assert result.exit_code == 0
    assert result.output == 'alt||\n'
}

fn test_generated_v_required_value_expansion_fails() {
    result := transpile_and_run('generated_required_value.v', r'echo "${missing:?required-name}"')
    assert result.exit_code != 0
    assert result.output.contains('required-name')
}

fn test_generated_v_can_run_append_assignments() {
    result := transpile_and_run('generated_append_assignments.v', r'VAR1=qweqwe
VAR1+="asdasd"
ARR1=()
ARR1+=( item1 item2 )
ARR1+=( it4 "it5 ooo" )
echo "${VAR1}|${ARR1[0]}|${ARR1[1]}|${ARR1[2]}|${ARR1[3]}|${#ARR1[@]}"')
    assert result.exit_code == 0
    assert result.output == 'qweqweasdasd|item1|item2|it4|it5 ooo|4\n'
}

fn test_generated_v_can_run_arithmetic_expansion() {
    result := transpile_and_run('generated_arithmetic.v', r'x=5
y=2
echo "$((1 + 2 * 3))|$((x + y * 4))|$((-(x - 2)))"')
    assert result.exit_code == 0
    assert result.output == '7|13|-3\n'
}

fn test_generated_v_can_run_arithmetic_assignment_and_indexing() {
    result := transpile_and_run('generated_arithmetic_indexing.v', r'i=1
i=$((i + 1))
arr[$((i + 1))]=$((i + 4))
echo "${i}|${arr[$((i + 1))]}"')
    assert result.exit_code == 0
    assert result.output == '2|6\n'
}

fn transpile_and_run(filename string, source string) os.Result {
    tmp_dir := os.join_path('/home/margo/dev/bash2v', 'tests', 'e2e', 'tmp')
    os.mkdir_all(tmp_dir) or { panic(err) }

    generated_path := os.join_path(tmp_dir, filename)
    transpiled := bash2v.transpile_source(source) or { panic(err) }
    os.write_file(generated_path, transpiled.generated) or { panic(err) }
    return os.execute('cd /home/margo/dev/bash2v && v run tests/e2e/tmp/${filename}')
}
