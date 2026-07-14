## 2025-03-19 - Optimization of `indent_block` with `strings.Builder`
**Learning:** In V, repeatedly using string concatenation (`+`) or `split`/`join` on large strings in loops causes $O(N^2)$ or $O(N)$ allocations that can be avoided by using `strings.Builder`. Pre-allocating the builder's capacity further improves performance by minimizing buffer reallocations.
**Action:** Prefer `strings.Builder` for all string construction in loops or complex string transformations, and pre-calculate required capacity when possible.

## 2025-03-19 - Portability of test suites
**Learning:** Hardcoded absolute paths in test files (e.g., `/home/margo/dev/bash2v`) break CI/CD pipelines and external environment testing.
**Action:** Use `os.getwd()` or relative paths in test scripts to ensure they remain functional across different environments.
