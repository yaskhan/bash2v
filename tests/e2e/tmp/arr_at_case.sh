arr=()
arr+=( item1 item2 "word3 word4" )
echo "ECHO:"
echo "${arr[@]}"
printf "PRINTF:\n"
printf "<>\n" "${arr[@]}"
