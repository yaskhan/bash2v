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

fn test_bash_and_transpiled_match_for_if_statement_with_elif() {
    source := r'x=2
if [ "$x" -eq 1 ]; then
echo one
elif [ "$x" -eq 2 ]; then
echo two
else
echo other
fi'

    bash_result := run_bash_source('if_elif_case', source) or { panic(err) }
    transpiled_result := run_transpiled_source('if_elif_case', source) or { panic(err) }

    assert bash_result.status == 0
    assert transpiled_result.status == 0
    assert transpiled_result.stdout == bash_result.stdout
}

fn test_bash_and_transpiled_match_for_while_statement() {
    source := r'i=0
while [ "$i" -lt 3 ]; do
i=$((i + 1))
echo "$i"
done'

    bash_result := run_bash_source('while_case', source) or { panic(err) }
    transpiled_result := run_transpiled_source('while_case', source) or { panic(err) }

    assert bash_result.status == 0
    assert transpiled_result.status == 0
    assert transpiled_result.stdout == bash_result.stdout
}

fn test_bash_and_transpiled_match_for_break_and_continue() {
    source := r'i=0
while true; do
i=$((i + 1))
if [ "$i" -eq 2 ]; then
continue
fi
echo "$i"
if [ "$i" -eq 3 ]; then
break
fi
done'

    bash_result := run_bash_source('break_continue_case', source) or { panic(err) }
    transpiled_result := run_transpiled_source('break_continue_case', source) or { panic(err) }

    assert bash_result.status == 0
    assert transpiled_result.status == 0
    assert transpiled_result.stdout == bash_result.stdout
}

fn test_bash_and_transpiled_match_for_for_in_statement() {
    source := r'for item in one "two words" three; do
echo "$item"
done'

    bash_result := run_bash_source('for_in_case', source) or { panic(err) }
    transpiled_result := run_transpiled_source('for_in_case', source) or { panic(err) }

    assert bash_result.status == 0
    assert transpiled_result.status == 0
    assert transpiled_result.stdout == bash_result.stdout
}

fn test_bash_and_transpiled_match_for_for_in_with_unquoted_array_all_star() {
    source := r'arr=( i1 i2 "i3 i4" )
for i in ${arr[*]}; do
echo "i=$i"
done'

    bash_result := run_bash_source('for_in_array_star_case', source) or { panic(err) }
    transpiled_result := run_transpiled_source('for_in_array_star_case', source) or { panic(err) }

    assert bash_result.status == 0
    assert transpiled_result.status == 0
    assert transpiled_result.stdout == bash_result.stdout
}

fn test_bash_and_transpiled_match_for_plain_dollar_expansion() {
    source := r'name=world
value=42
echo $name "$value"'

    bash_result := run_bash_source('plain_dollar_case', source) or { panic(err) }
    transpiled_result := run_transpiled_source('plain_dollar_case', source) or { panic(err) }

    assert bash_result.status == 0
    assert transpiled_result.status == 0
    assert transpiled_result.stdout == bash_result.stdout
}

fn test_bash_and_transpiled_match_for_quoted_array_all_items_expansions() {
    source := r'arr=()
arr+=( item1 item2 "word3 word4" )
printf "<%s>\n" "${arr[*]}"
printf "<%s>\n" "${arr[@]}"'

    bash_result := run_bash_source('array_all_items_case', source) or { panic(err) }
    transpiled_result := run_transpiled_source('array_all_items_case', source) or { panic(err) }

    assert bash_result.status == 0
    assert transpiled_result.status == 0
    assert transpiled_result.stdout == bash_result.stdout
}

fn test_bash_and_transpiled_match_for_single_quotes_inside_double_quotes_around_array_index() {
    source := "arr2=()\narr2+=( aaa )\necho \"'" + r'${arr2[0]}' + "'\"\n"

    bash_result := run_bash_source('array_quote_wrap_case', source) or { panic(err) }
    transpiled_result := run_transpiled_source('array_quote_wrap_case', source) or { panic(err) }

    assert bash_result.status == 0
    assert transpiled_result.status == 0
    assert transpiled_result.stdout == bash_result.stdout
}
