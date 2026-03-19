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
