# Porting Status & Remaining Work

> Cập nhật: 2026-07-15
> Build check: ✅ Pass | Build test: ✅ Compiles | Tests: 72/85 pass

## Tổng quan

| Metric | Go | Zig | Coverage |
|--------|----|----:|---------:|
| Source files | 496 | 452 | 91% |
| Source LOC | 298,115 | 165,786 | **55%** |
| Test files | 4,444 | 43 | 1% |
| Test functions | ~15,500+ | 120 | <1% |

## Module Coverage Summary

### ✅ Complete (>85%) — 11 modules, 31K Go LOC
| Module | Go LOC | Zig LOC | Coverage |
|--------|-------:|--------:|---------:|
| parser | 9,071 | 8,531 | 94% |
| compiler | 5,658 | 4,837 | 85% |
| binder | 3,555 | 3,774 | 106% |
| diagnostics | 9,423 | 15,114 | 160% |
| tracing | 763 | 738 | 97% |
| testrunner | 889 | 1,116 | 126% |
| diagnosticwriter | 506 | 547 | 108% |
| sourcemap | 1,013 | 1,198 | 118% |
| outputpaths | 307 | 363 | 118% |
| evaluator | 168 | 202 | 120% |
| symlinks | 134 | 196 | 146% |

### ✅ Good (60-85%) — 10 modules, 107K Go LOC
| Module | Go LOC | Zig LOC | Coverage |
|--------|-------:|--------:|---------:|
| **checker** | 59,822 | 38,734 | **65%** |
| transformers | 24,323 | 17,761 | 73% |
| printer | 11,442 | 9,223 | 81% |
| tsoptions | 6,144 | 4,848 | 79% |
| module | 2,780 | 1,973 | 71% |
| packagejson | 662 | 536 | 81% |
| semver | 712 | 566 | 79% |
| jsnum | 584 | 431 | 74% |
| glob | 349 | 247 | 71% |
| json | 100 | 75 | 75% |

### ⚠️ Partial (30-60%) — 9 modules, 66K Go LOC
| Module | Go LOC | Zig LOC | Coverage | Gap |
|--------|-------:|--------:|---------:|-----|
| **lsp** | 21,008 | 8,167 | 39% | 13K LOC missing |
| **ast** | 20,847 | 10,852 | 52% | 10K LOC missing |
| testutil | 5,730 | 3,293 | 57% | 2.4K LOC missing |
| fswatch | 5,446 | 3,049 | 56% | 2.4K LOC missing |
| format | 4,291 | 2,557 | 60% | 1.7K LOC missing |
| scanner | 4,256 | 2,273 | 53% | 2K LOC missing |
| vfs | 3,131 | 1,351 | 43% | 1.8K LOC missing |
| bundled | 1,110 | 536 | 48% | 574 LOC missing |
| jsonrpc | 287 | 124 | 43% | 163 LOC missing |

### ❌ Critical gap (<30%) — 12 modules, 93K Go LOC
| Module | Go LOC | Zig LOC | Coverage | Priority |
|--------|-------:|--------:|---------:|----------|
| **ls** (language service) | 38,933 | 11,037 | 28% | P1 |
| **project** | 11,016 | 2,636 | 24% | P1 |
| **fourslash** | 9,770 | 2,808 | 29% | P2 |
| **execute** | 9,348 | 2,671 | 29% | P1 |
| **api** | 9,110 | 509 | 6% | P2 |
| **stringutil** | 5,573 | 518 | 9% | P1 |
| **core** | 2,669 | 328 | 12% | P1 |
| modulespecifiers | 2,280 | 681 | 30% | P2 |
| tspath | 1,435 | 403 | 28% | P1 |
| pseudochecker | 1,126 | 245 | 22% | P2 |
| collections | 840 | 15 | 2% | P1 |
| astnav | 783 | 113 | 14% | P2 |

### ❌ Missing (0%) — 2 modules
| Module | Go LOC | Notes |
|--------|-------:|-------|
| nativepath | 298 | Platform-specific path operations |
| pprof | 169 | Profiling (can skip) |

## Priority Work Items

### P0 — Fix test runner crash
- `compiler_runner_test` crashes during parsing
- Likely OOM or stack overflow from unbounded recursion
- Need to add recursion/depth limits

### P1 — Critical module gaps (affects core functionality)
1. **stringutil** (9% → target 80%) — 5K Go LOC, only 518 Zig
   - String manipulation utilities used everywhere
2. **core** (12% → target 80%) — 2.7K Go LOC, only 328 Zig
   - Core types, interfaces, utilities
3. **collections** (2% → target 80%) — 840 Go LOC, only 15 Zig
   - Data structures used by checker/binder
4. **tspath** (28% → target 80%) — 1.4K Go LOC, only 403 Zig
   - Path manipulation for module resolution
5. **project** (24% → target 60%) — 11K Go LOC, only 2.6K Zig
   - LSP project management
6. **execute** (29% → target 60%) — 9.3K Go LOC, only 2.7K Zig
   - Build/compile/watch pipeline
7. **ls** (28% → target 50%) — 39K Go LOC, only 11K Zig
   - Language service features (completions, hover, etc.)

### P2 — Important but non-blocking
1. **ast** (52% → target 80%) — 10K LOC gap
2. **scanner** (53% → target 80%) — 2K LOC gap
3. **vfs** (43% → target 70%) — 1.8K LOC gap
4. **lsp** (39% → target 60%) — 13K LOC gap
5. **fourslash** (29% → target 50%) — test framework
6. **api** (6% → target 40%) — public API
7. **pseudochecker** (22% → target 50%)
8. **astnav** (14% → target 50%)
9. **modulespecifiers** (30% → target 60%)

### P3 — Long-term
1. Port fourslash test framework (4,295 test files)
2. Port conformance test runner
3. Achieve >90% test pass rate
4. Port all remaining stubs in checker.zig (702 stubs)

## Checker Stubs Status

| Category | Count | Status |
|----------|------:|--------|
| Total stubs remaining | 702 | Most are language-service features |
| Stubs returning anyTypeIndex | 4 | Intentional (no better type available) |
| Stubs returning *anyopaque | ~600 | Language service / advanced features |
| Critical stubs ported | 150+ | P0-P2 complete |

## Bottom Line

**Core compiler pipeline works**: parse → bind → check → emit

**What works now:**
- ✅ Parser (94% coverage)
- ✅ Binder (106% coverage)
- ✅ Checker basic type checking (65% coverage, 150+ stubs ported)
- ✅ Printer/emitter (81% coverage)
- ✅ Transformers (73% coverage)
- ✅ Compiler pipeline (85% coverage)
- ✅ 72/85 unit tests pass

**What needs work:**
- ❌ 702 checker stubs (mostly language service)
- ❌ Test coverage (120 Zig tests vs 15,500+ Go tests)
- ❌ Language service (28% coverage)
- ❌ Project management (24% coverage)
- ❌ Execute/build pipeline (29% coverage)
- ❌ Utility modules (stringutil 9%, core 12%, collections 2%)
