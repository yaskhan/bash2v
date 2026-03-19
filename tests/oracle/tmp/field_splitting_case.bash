value="one two"
printf "<%s>\n" $value "$value"
printf "<%s>\n" $(echo alpha beta)
printf "<%s>\n" "$(echo alpha beta)"