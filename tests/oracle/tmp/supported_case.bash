target=name
name=HELLO
arr[3]=value
declare -A map
map[foo]=bar
echo "${!target} ${name,,} ${arr[3]} ${map[foo]} ${!map[@]}"