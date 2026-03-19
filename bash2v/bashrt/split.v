module bashrt

pub fn split_words(input string) []string {
    if input == '' {
        return []string{}
    }
    return input.split(' ')
}
