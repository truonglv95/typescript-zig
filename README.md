# typescript-zig

A port of [microsoft/typescript-go](https://github.com/microsoft/typescript-go)
to [Zig](https://ziglang.org/), preserving the original Data-Oriented Design
(DOD) philosophy while taking advantage of Zig's comptime, manual memory
management, and zero-runtime-overhead abstractions.

> **Status:** Early-stage port. The pipeline `scanner → parser → binder →
> checker → printer → transformers` is wired up for simple cases, but many
> type-checker and language-service features are still stubbed. See
> [Port progress](#port-progress) below for details.

## Repository layout

```
typescript-zig/
├── build.zig            # Build script: libtsc.so + tsc + tsc-check + LSP server
├── build.zig.zon        # Package manifest (zero external dependencies)
├── cmd/
│   └── lsp/main.zig     # Standalone LSP server entry point
├── src/
│   ├── root.zig         # Root module — re-exports all packages + C ABI
│   ├── main.zig         # `tsc` CLI entry point
│   ├── sys.zig          # OS-backed System implementation
│   ├── api/capi.zig     # C ABI exports for Go CGO interop (libtsc.so)
│   ├── scanner/         # Tokenizer (TypeScript/JS/JSX)
│   ├── parser/          # Recursive-descent parser
│   ├── ast/             # DOD AST: MultiArrayList(NodeData), Symbol, Kind
│   ├── binder/          # Symbol binder + name/reference resolver
│   ├── checker/         # Type checker (largest module — partially ported)
│   ├── printer/         # Pretty-printer / emitter + NodeFactory
│   ├── transformers/    # TS/ES/module/JSX/declaration transformers
│   ├── compiler/        # Program, CompilerHost, Emitter, file loading
│   ├── execute/         # CLI driver (tsc --build/--watch — partial)
│   ├── core/            # CompilerOptions, TextRange, enums, arena
│   ├── diagnostics/     # Diagnostic message catalog (generated)
│   ├── tspath/          # Path manipulation utilities
│   ├── tsoptions/       # tsconfig.json + CLI option parsing
│   ├── module/          # Module resolution (node, bundler, classic)
│   ├── ls/              # Language Service (completions, hover, refs — partial)
│   ├── lsp/             # LSP server + protocol types (generated)
│   ├── project/         # LSP project model (session, snapshot FS — partial)
│   ├── vfs/             # Virtual filesystem abstraction (partial)
│   ├── fswatch/         # Cross-platform file watcher (partial)
│   ├── format/          # Code formatter
│   ├── bundled/         # Embedded lib.*.d.ts files (108 files)
│   └── ...              # stringutil, jsnum, semver, sourcemap, etc.
└── submodule/
    └── typescript-go/   # Git submodule — upstream Go source (reference)
```

## Building

Requires **Zig 0.16.0** or later.

```sh
# Semantic check only (fast, no codegen)
zig build check

# Build all artifacts: libtsc.so, tsc, tsc-check, typescript-zig-language-server
zig build

# Run unit tests
zig build test

# Run the tsc CLI
zig build run -- hello.ts
# or directly:
./zig-out/bin/tsc hello.ts
```

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `TYPESCRIPT_ZIG_LIB_PATH` | (install dir) | Path to the `lib.*.d.ts` directory. Override for dev workflows. |

## Artifacts

| Artifact | Type | Purpose |
|---|---|---|
| `libtsc.so` | Dynamic lib (C ABI) | Embed in Go projects via CGO — exposes `zig_ts_parse`, `zig_ts_parse_and_check`, etc. |
| `tsc` | Executable | CLI compiler (`tsc hello.ts`, `tsc -p tsconfig.json`, `tsc --build`) |
| `tsc-check` | Executable | Semantic check only (no codegen) |
| `typescript-zig-language-server` | Executable | LSP language server (`--stdio`) |

## Port progress

Updated 2026-07-13. LOC ratios are approximate; "real fn %" counts functions
with non-stub bodies (excluding `@panic`, `unreachable`, discard-only).

### Core compiler pipeline

| Module | Go LOC | Zig LOC | %LOC | Real fn % | Notes |
|---|---:|---:|---:|---:|---|
| `binder` | 3,555 | 3,774 | 106% | 82% | ✅ Ready |
| `parser` | 9,071 | 8,455 | 93% | 63% | ✅ Ready |
| `compiler` | 5,658 | 5,024 | 89% | 86% | ✅ Working (program.zig has own file loader) |
| `printer` | 11,442 | 9,163 | 80% | 83% | ✅ Near-complete |
| `module` | 2,780 | 1,973 | 71% | 77% | ✅ OK |
| `transformers` | 24,323 | 16,533 | 68% | ~75% | ⚠️ Missing moduletransforms/commonjs + estransforms helpers |
| `tsoptions` | 6,144 | 4,171 | 68% | 39% | ⚠️ Missing 7 decls files |
| `checker` | 59,797 | 36,381 | 61% | **45%** | 🔴 Top-30 methods: only 9/30 have real bodies |
| `scanner` | 4,256 | 1,970 | 46% | 41% | 🔴 Missing regexp.go (1,076 LOC) |
| `ast` | 20,847 | 10,794 | 52% | 15%* | ⚠️ `ast_generated` + `utilities` need more work |

### Infrastructure

| Module | Go LOC | Zig LOC | %LOC | Notes |
|---|---:|---:|---:|---|
| `sourcemap` | 1,396 | 1,198 | 86% | ✅ OK |
| `format` | 4,955 | 2,557 | 52% | ⚠️ Partial |
| `fswatch` | 5,446 | 3,012 | 55% | ⚠️ walkdir_unix/windows stub |
| `vfs` | 3,131 | 324 | 10% | 🔴 Only osvfs + vfsmatch |
| `execute` | 9,348 | 924 | 10% | 🔴 Missing build/, incremental/, watchmanager/, tsc/ |
| `api` | 9,110 | 509 | 6% | 🔴 Only C ABI; no RPC session |

### Language service & LSP

| Module | Go LOC | Zig LOC | %LOC | Notes |
|---|---:|---:|---:|---|
| `ls/autoimport` | 5,353 | 3,717 | 69% | ✅ Bright spot |
| `ls/completions` | 6,295 | 405 | 6% | 🔴 Only 8/180 fns ported |
| `ls/findallreferences` | 2,654 | 1,102 | 41% | 🔴 9 empty stubs (addReference no-op) |
| `lsp/server` | 1,883 | 1,244 | 66% | ✅ 52/52 handle* methods wired |
| `lsp/lsproto` | 17,262 | 3,950 | 23% | 🔴 463/715 types, 0 serialization funcs |
| `project` | 11,016 | 2,636 | 24% | 🔴 Missing session, checkerpool, ata/ |

### Generated files

| File | Status |
|---|---|
| `ast/ast_generated.zig` | ⚠️ Partial (1,719 LOC vs Go 10,047) |
| `diagnostics/diagnostics_generated.zig` | ✅ Complete (15,101 LOC) |
| `lsp/lsproto/lsp_generated.zig` | 🔴 Subset (3,950 vs Go 17,262 LOC; 0 serialization) |
| `bundled/embed_generated.zig` | ✅ Complete (108 lib files) |

## Architecture notes

### Data-Oriented Design (DOD)

The AST and type system use structure-of-arrays layout for cache efficiency:

```zig
pub const Ast = struct {
    nodes: std.MultiArrayList(NodeData),  // tagged union per Kind
    parents: []u32,
    positions: []TextRange,
    extraData: std.ArrayListUnmanaged(u8),
    localSymbols: std.StringHashMapUnmanaged(SymbolIndex),
    // ...
};

pub const NodeIndex = u32;
pub const SymbolIndex = u32;
pub const TypeIndex = u32;
```

Indices (not pointers) are used for cross-references — this enables cheap
copying, stable references across reallocations, and simpler memory management.

### File loading

`compiler/program.zig` contains its own file-loading implementation
(`Program.load`, `Program.loadFile`, `loadDefaultLibraries`,
`loadConfiguredTypes`, `loadWildcardTypePackages`) that does NOT depend on
the Go-style `fileLoader` struct. This is the path used by the `tsc` CLI.

The Go-side `internal/compiler/fileloader.go` (791 LOC) has a different
structure that we will eventually port when implementing `tsc --build` with
project references (Phase 2 of the port roadmap).

### C ABI

`src/api/capi.zig` exports a small C ABI for embedding in Go projects via
CGO. This allows using the Zig parser/checker as a drop-in replacement for
the Go parser/checker in `libtsc.so`:

```c
int32_t zig_ts_parse_and_check(const char* source, size_t length, bool is_jsx);
```

## Testing

```sh
# Run all unit tests
zig build test
```

Current test coverage is thin — 117 test declarations across 25 files,
concentrated in `lsp/autoimport`, `lsutil`, and `testrunner`. The checker,
parser, binder, and transformers have almost no unit tests; baseline testing
from `tests/baselines/reference/` is not yet wired up.

## Contributing

### Port conventions

1. **One file per PR.** Port one Go file → one Zig file at a time.
2. **Keep DOD layout.** Use `MultiArrayList` and index types (`u32`), not
   pointers.
3. **Stub first, fill later.** When adding a new function, keep the signature
   exact and return a default value. Commit as "stub", then a follow-up PR
   fills the body.
4. **Mark stubs clearly.** Use `// STUB:` comment for unimplemented logic.
   Use `catch @panic("OOM")` only for genuine allocation failures.
5. **Test with baselines.** Each method ported should have at least one
   baseline test case from `submodule/typescript-go/tests/cases/conformance/`
   passing.

### Submodule sync

The `submodule/typescript-go` submodule tracks `microsoft/typescript-go` main.
A daily CI job (`submodule-sync.yml`) opens a PR to sync. Always run
`zig build && zig build test` after syncing — upstream API changes can break
the port.

### Generating code

| Generator | Command | Output |
|---|---|---|
| LSP types | `cd src/lsp/lsproto/_generate && node --experimental-strip-types generate.mts` | `src/lsp/lsproto/lsp_generated.zig` |
| Bundled libs | `cd src/bundled && zig run generate.zig` | `src/bundled/embed_generated.zig` |

## Roadmap

See `PORT_PLAN.md` for the detailed 5-phase port plan (14 months estimated).

| Phase | Weeks | Goal |
|---|---|---|
| 0 — Unblock | 1–4 | `tsc hello.ts` runs end-to-end; CI green |
| 1 — Core Compiler | 5–20 | 80% conformance test pass |
| 2 — VFS + Execute + Incremental | 21–28 | `tsc --build`, `--watch`, `.tsbuildinfo` |
| 3 — Language Service | 29–40 | LSP completions/hover/find-refs/rename |
| 4 — Project Service + API | 41–48 | Multi-project LSP + RPC API server |
| 5 — Polish + Parity | 49–56 | 95% conformance pass, v1.0.0 release |

## License

Same license as upstream `microsoft/typescript-go` (Apache 2.0).
