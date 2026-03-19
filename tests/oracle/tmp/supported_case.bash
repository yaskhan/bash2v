target=name
name=HELLO
arr[3]=value
arr[9]=other
declare -A map
map[foo]=bar
map[zoo]=qux
echo "${!target} ${name,,} ${arr[3]} ${map[foo]} ${#arr[@]} ${#map[@]}"