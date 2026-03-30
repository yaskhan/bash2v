## 2024-03-29 - [Optimization of finalize_expanded_word with strings.Builder]
**Learning:** String concatenation in a loop (like word fragment expansion) in V is an $O(n^2)$ operation due to immutable strings. Using `strings.Builder` provides significant speedups ($~28\%$ measured in this case) and is a best practice for performance-critical hot paths.
**Action:** Always prefer `strings.Builder` over string concatenation (`+` or `+=`) inside loops in V.

## 2024-03-29 - [Test Suite Portability]
**Learning:** Hardcoded absolute paths (e.g., `/home/margo/dev/bash2v`) in test files prevent tests from running correctly in different environments or containers.
**Action:** Use `os.getwd()` or `os.real_path('.')` to resolve the project root dynamically in tests.
