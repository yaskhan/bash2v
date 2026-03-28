## 2025-05-15 - [Optimize string concatenation in finalize_expanded_word]
**Learning:** String concatenation using `+=` in the `finalize_expanded_word` function (a hot path for shell expansion) leads to $O(N^2)$ performance issues when processing words with many fragments or long unquoted parts.
**Action:** Use `strings.Builder` for building fields during word expansion and finalization in the runtime. Always use `strings.Builder` or `append` to an array followed by `.join()` for string construction in loops.
