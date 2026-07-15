// Wrapper entry point for fourslash tests.
// Located at src/ level so that test files in src/fourslash_tests/ can use
// `@import("../fourslash/fourslash.zig")` without going outside the module path.
comptime {
    _ = @import("fourslash_tests/test_root.zig");
}
