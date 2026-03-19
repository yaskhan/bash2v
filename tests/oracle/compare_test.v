module oracle

fn test_oracle_result_default_status() {
    result := OracleResult{}
    assert result.status == 0
}

fn test_bash_and_transpiled_match_for_supported_script() {
    source := r'target=name
name=HELLO
arr[3]=value
arr[9]=other
declare -A map
map[foo]=bar
map[zoo]=qux
echo "${!target} ${name,,} ${arr[3]} ${map[foo]} ${#arr[@]} ${#map[@]} ${name:+yes}"'

    bash_result := run_bash_source('supported_case', source) or { panic(err) }
    transpiled_result := run_transpiled_source('supported_case', source) or { panic(err) }

    assert bash_result.status == 0
    assert transpiled_result.status == 0
    assert transpiled_result.stdout == bash_result.stdout
}

fn test_bash_and_transpiled_both_fail_for_required_value() {
    source := r'echo "${missing:?required-name}"'

    bash_result := run_bash_source('required_case', source) or { panic(err) }
    transpiled_result := run_transpiled_source('required_case', source) or { panic(err) }

    assert bash_result.status != 0
    assert transpiled_result.status != 0
    assert bash_result.stdout == ''
    assert transpiled_result.stdout == ''
    assert bash_result.stderr.contains('required-name')
    assert transpiled_result.stderr.contains('required-name')
}

fn test_bash_and_transpiled_match_for_append_assignments() {
    source := r'VAR1=qweqwe
VAR1+="asdasd"
ARR1=()
ARR1+=( item1 item2 )
ARR1+=( it4 "it5 ooo" )
echo "${VAR1}|${ARR1[0]}|${ARR1[1]}|${ARR1[2]}|${ARR1[3]}|${#ARR1[@]}"'

    bash_result := run_bash_source('append_case', source) or { panic(err) }
    transpiled_result := run_transpiled_source('append_case', source) or { panic(err) }

    assert bash_result.status == 0
    assert transpiled_result.status == 0
    assert transpiled_result.stdout == bash_result.stdout
}

fn test_bash_and_transpiled_match_for_arithmetic_expansion() {
    source := r'x=5
y=2
echo "$((1 + 2 * 3))|$((x + y * 4))|$((-(x - 2)))"'

    bash_result := run_bash_source('arithmetic_case', source) or { panic(err) }
    transpiled_result := run_transpiled_source('arithmetic_case', source) or { panic(err) }

    assert bash_result.status == 0
    assert transpiled_result.status == 0
    assert transpiled_result.stdout == bash_result.stdout
}

fn test_bash_and_transpiled_match_for_arithmetic_assignment_and_indexing() {
    source := r'i=1
i=$((i + 1))
arr[$((i + 1))]=$((i + 4))
echo "${i}|${arr[$((i + 1))]}"'

    bash_result := run_bash_source('arith_index_case', source) or { panic(err) }
    transpiled_result := run_transpiled_source('arith_index_case', source) or { panic(err) }

    assert bash_result.status == 0
    assert transpiled_result.status == 0
    assert transpiled_result.stdout == bash_result.stdout
}

fn test_bash_and_transpiled_match_for_condition_builtins() {
    source := r'test 5 -gt 3
[ foo = foo ]
[[ -n bar ]]
[[ alpha < beta ]]
echo ok'

    bash_result := run_bash_source('condition_case', source) or { panic(err) }
    transpiled_result := run_transpiled_source('condition_case', source) or { panic(err) }

    assert bash_result.status == 0
    assert transpiled_result.status == 0
    assert transpiled_result.stdout == bash_result.stdout
}

fn test_bash_and_transpiled_match_for_false_condition() {
    source := r'[[ -z bar ]]'

    bash_result := run_bash_source('condition_false_case', source) or { panic(err) }
    transpiled_result := run_transpiled_source('condition_false_case', source) or { panic(err) }

    assert bash_result.status == 1
    assert transpiled_result.status == 1
    assert bash_result.stdout == ''
    assert transpiled_result.stdout == ''
}

fn test_bash_and_transpiled_match_for_if_statement() {
    source := r'if test 5 -gt 3; then
echo yes
else
echo no
fi
if [[ -z bar ]]; then
echo no
else
echo ok
fi'

    bash_result := run_bash_source('if_case', source) or { panic(err) }
    transpiled_result := run_transpiled_source('if_case', source) or { panic(err) }

    assert bash_result.status == 0
    assert transpiled_result.status == 0
    assert transpiled_result.stdout == bash_result.stdout
}

fn test_bash_and_transpiled_match_for_while_statement() {
    source := r'i=0
while [ "${i}" -lt 3 ]; do
i=$((i + 1))
echo "${i}"
done'

    bash_result := run_bash_source('while_case', source) or { panic(err) }
    transpiled_result := run_transpiled_source('while_case', source) or { panic(err) }

    assert bash_result.status == 0
    assert transpiled_result.status == 0
    assert transpiled_result.stdout == bash_result.stdout
}

fn test_bash_and_transpiled_match_for_for_in_statement() {
    source := r'for item in one "two words" three; do
echo "${item}"
done'

    bash_result := run_bash_source('for_in_case', source) or { panic(err) }
    transpiled_result := run_transpiled_source('for_in_case', source) or { panic(err) }

    assert bash_result.status == 0
    assert transpiled_result.status == 0
    assert transpiled_result.stdout == bash_result.stdout
}
