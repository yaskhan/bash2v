arr=()
arr+=( item1 item2 "word3 word4" )
printf "<%s>\n" "${arr[*]}"
printf "<%s>\n" "${arr[@]}"