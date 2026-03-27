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

fn test_generated_v_can_run_condition_builtins() {
    result := transpile_and_run('generated_conditions.v', r'test 5 -gt 3
[ foo = foo ]
[[ -n bar ]]
[[ alpha < beta ]]
echo ok')
    assert result.exit_code == 0
    assert result.output == 'ok\n'
}

fn test_generated_v_false_condition_exits_nonzero() {
    result := transpile_and_run('generated_condition_false.v', r'[[ -z bar ]]')
    assert result.exit_code != 0
}

fn test_generated_v_can_run_if_statement() {
    result := transpile_and_run('generated_if.v', r'if test 5 -gt 3; then
echo yes
else
echo no
fi
if [[ -z bar ]]; then
echo no
else
echo ok
fi')
    assert result.exit_code == 0
    assert result.output == 'yes\nok\n'
}

fn test_generated_v_can_run_if_statement_with_elif() {
    result := transpile_and_run('generated_if_elif.v', r'x=2
if [ "$x" -eq 1 ]; then
echo one
elif [ "$x" -eq 2 ]; then
echo two
else
echo other
fi')
    assert result.exit_code == 0
    assert result.output == 'two\n'
}

fn test_generated_v_can_run_while_statement() {
    result := transpile_and_run('generated_while.v', r'i=0
while [ "$i" -lt 3 ]; do
i=$((i + 1))
echo "$i"
done')
    assert result.exit_code == 0
    assert result.output == '1\n2\n3\n'
}

fn test_generated_v_can_run_break_and_continue() {
    result := transpile_and_run('generated_break_continue.v', r'i=0
while true; do
i=$((i + 1))
if [ "$i" -eq 2 ]; then
continue
fi
echo "$i"
if [ "$i" -eq 3 ]; then
break
fi
done')
    assert result.exit_code == 0
    assert result.output == '1\n3\n'
}

fn test_generated_v_can_run_for_in_statement() {
    result := transpile_and_run('generated_for_in.v', r'for item in one "two words" three; do
echo "$item"
done')
    assert result.exit_code == 0
    assert result.output == 'one\ntwo words\nthree\n'
}

fn test_generated_v_can_run_for_in_with_unquoted_array_all_star() {
    result := transpile_and_run('generated_for_in_array_star.v', r'arr=( i1 i2 "i3 i4" )
for i in ${arr[*]}; do
echo "i=$i"
done')
    assert result.exit_code == 0
    assert result.output == 'i=i1\ni=i2\ni=i3\ni=i4\n'
}

fn test_generated_v_can_run_field_splitting_for_unquoted_scalar_and_command_substitution() {
    result := transpile_and_run('generated_field_splitting.v', r'value="one two"
printf "<%s>\n" $value "$value"
printf "<%s>\n" $(echo alpha beta)
printf "<%s>\n" "$(echo alpha beta)"')
    assert result.exit_code == 0
    assert result.output == '<one>\n<two>\n<one two>\n<alpha>\n<beta>\n<alpha beta>\n'
}

fn test_generated_v_can_run_and_or_short_circuit_lists() {
    result := transpile_and_run('generated_and_or.v', r'false && echo no
false || echo yes
true && echo ok
true || echo no
if false || true; then
echo cond
fi')
    assert result.exit_code == 0
    assert result.output == 'yes\nok\ncond\n'
}

fn test_generated_v_can_run_case_statement() {
    result := transpile_and_run('generated_case.v', r'name=foo.txt
case "$name" in
*.log)
echo log
;;
foo.txt|bar.txt)
echo hit
;;
*)
echo other
;;
esac
case z in
foo)
echo no
;;
esac
echo after')
    assert result.exit_code == 0
    assert result.output == 'hit\nafter\n'
}

fn test_generated_v_can_run_plain_dollar_expansion() {
    result := transpile_and_run('generated_plain_dollar.v', r'name=world
value=42
echo $name "$value"')
    assert result.exit_code == 0
    assert result.output == 'world 42\n'
}

fn test_generated_v_can_run_quoted_array_all_items_expansions() {
    result := transpile_and_run('generated_array_all_items.v', r'arr=()
arr+=( item1 item2 "word3 word4" )
printf "<%s>\n" "${arr[*]}"
printf "<%s>\n" "${arr[@]}"')
    assert result.exit_code == 0
    assert result.output == '<item1 item2 word3 word4>\n<item1>\n<item2>\n<word3 word4>\n'
}

fn test_generated_v_can_run_single_quotes_inside_double_quotes_around_array_index() {
    source := "arr2=()\narr2+=( aaa )\necho \"'" + r'${arr2[0]}' + "'\"\n"
    result := transpile_and_run('generated_array_quote_wrap.v', source)
    assert result.exit_code == 0
    assert result.output == "'aaa'\n"
}

fn transpile_and_run(filename string, source string) os.Result {
    cwd := os.getwd()
    tmp_dir := os.join_path(cwd, 'tests', 'e2e', 'tmp')
    os.mkdir_all(tmp_dir) or { panic(err) }

    generated_path := os.join_path(tmp_dir, filename)
    transpiled := bash2v.transpile_source(source) or { panic(err) }
    os.write_file(generated_path, transpiled.generated) or { panic(err) }
    v_exe := os.getenv('VEXE')
    if v_exe == '' {
        return os.execute('v run tests/e2e/tmp/${filename}')
    }
    return os.execute('${v_exe} run tests/e2e/tmp/${filename}')
}
