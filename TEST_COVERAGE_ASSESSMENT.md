# Test Coverage Assessment: Go vs Zig

> Cập nhật: 2026-07-15
> Trạng thái: Build check ✅ | Build test compiles ✅ | Tests run but crash during parsing

## 1. Go Test Inventory

| Module | Go test files | Test functions (est.) | Status in Zig |
|--------|-------------:|---------------------:|---------------|
| fourslash | 4,295 | ~15,000+ | ❌ Not ported (requires fourslash framework) |
| project | 27 | ~100+ | ❌ Not ported |
| lsp | 15 | ~50+ | ✅ Partially ported (server tests) |
| vfs | 10 | ~40+ | ✅ Partially ported (cachedvfs, trackingvfs) |
| ls | 9 | ~40+ | ✅ Partially ported (autoimport, lsutil) |
| tsoptions | 8 | ~30+ | ❌ Not ported |
| fswatch | 8 | ~30+ | ✅ Partially ported (walkdir) |
| execute | 8 | ~30+ | ✅ Partially ported (graph) |
| api | 7 | ~25+ | ❌ Not ported |
| format | 5 | ~20+ | ✅ Partially ported (rules) |
| checker | 3 | ~50+ | ✅ Ported (checker.zig tests) |
| parser | 3 | ~30+ | ✅ Ported (parser_test.zig) |
| tspath | 4 | ~15+ | ❌ Not ported |
| Other | ~40 | ~100+ | Mixed |
| **Total** | **~4,444** | **~15,500+** | **~120 Zig tests** |

## 2. Zig Test Inventory

### Tests by module (120 total)

| Module | Tests | Status |
|--------|------:|--------|
| lsp/lspwatcher | 14 | ✅ Pass |
| ls/autoimport | 11+4+4+3 = 22 | ⚠️ Some fail |
| compiler/program | 9 | ✅ Pass |
| modulespecifiers | 6 | ✅ Pass |
| lsp/server_* | 5+4+3+2+2+2 = 18 | ✅ Pass |
| testrunner | 4+2 = 6 | ⚠️ Crash |
| lsp/protocol_session | 4 | ⚠️ 1 fail |
| compiler/commandline | 4 | ✅ Pass |
| root.zig | 3 | ✅ Pass |
| lsp/dynamic_queue | 3 | ✅ Pass |
| lsp/document_store | 3 | ✅ Pass |
| ls/lsconv | 3 | ✅ Pass |
| checker/checker | 3 | ⚠️ 1 fail |
| baseline | 2 | ✅ Pass |
| lsp/transport | 2 | ✅ Pass |
| lsp/stack_sanitizer | 2 | ✅ Pass |
| Other (20+ files) | ~30 | Mixed |

### Test results (last known)
- **72/85 tests pass** (84.7%)
- **12 skipped** (submodule not available)
- **1 failed** (checker infers merged JS this-property)
- **Test runner crashes** during compiler_runner_test (parsing many .ts files)

## 3. Coverage Gap Analysis

### Critical gaps (affect type checking correctness)

| Feature | Go test coverage | Zig test coverage | Priority |
|---------|-----------------|-------------------|----------|
| Variable type checking | ✅ Extensive | ✅ 7 tests | Done |
| Binary expressions | ✅ Extensive | ✅ 4 tests | Done |
| Function calls | ✅ Extensive | ✅ 3 tests | Done |
| Arrow functions | ✅ Extensive | ✅ 2 tests | Done |
| Type aliases | ✅ Extensive | ✅ 2 tests | Done |
| Interface properties | ✅ Extensive | ✅ 2 tests | Done |
| Class properties/methods | ✅ Extensive | ✅ 4 tests | Done |
| Enum types | ✅ Extensive | ✅ 5 tests | Done |
| Array types | ✅ Extensive | ✅ 2 tests | Done |
| Tuple types | ✅ Extensive | ✅ 1 test | Done |
| Union types | ✅ Extensive | ✅ 1 test | Done |
| Object literals | ✅ Extensive | ✅ 1 test | Done |
| **Generics** | ✅ Extensive | ❌ 0 tests | P0 |
| **Conditional types** | ✅ Extensive | ❌ 0 tests | P1 |
| **Mapped types** | ✅ Extensive | ❌ 0 tests | P1 |
| **Template literals** | ✅ Extensive | ❌ 0 tests | P2 |
| **Decorators** | ✅ Extensive | ❌ 0 tests | P2 |
| **JSX** | ✅ Extensive | ❌ 0 tests | P2 |
| **Modules/imports** | ✅ Extensive | ❌ 0 tests | P1 |
| **Async/await** | ✅ Extensive | ❌ 0 tests | P1 |
| **Flow analysis** | ✅ Extensive | ❌ 0 tests | P1 |
| **Fourslash** | ✅ 4,295 files | ❌ 0 tests | P3 |

### Test infrastructure gaps

| Component | Go | Zig | Status |
|-----------|----|----|--------|
| Test case parser | ✅ | ✅ | Ported |
| Compiler runner | ✅ | ✅ | Ported (crashes) |
| Baseline comparison | ✅ | ✅ | Ported |
| Fourslash framework | ✅ | ❌ | Not ported |
| Conformance test runner | ✅ | ❌ | Not ported |

## 4. Recommendations

### Immediate (fix test runner crash)
1. Debug why `compiler_runner_test` crashes during parsing
2. Likely cause: OOM or stack overflow from unbounded recursion
3. Fix: add recursion limits or statement count limits

### Short-term (add critical test coverage)
1. Add generic type tests (TypeParameter, TypeReference with args)
2. Add module/import resolution tests
3. Add async/await type tests
4. Add flow analysis tests (narrowing, truthiness)

### Medium-term (port test infrastructure)
1. Port fourslash test framework (enables 4,295 test files)
2. Port conformance test runner
3. Port project-level test framework

### Long-term (full parity)
1. Port all 4,444 Go test files
2. Achieve >90% conformance test pass rate
3. Enable CI pipeline with test baselines
