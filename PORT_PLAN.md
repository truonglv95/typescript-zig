# Port Plan: typescript-go → typescript-zig

> 5-phase plan to reach 100% parity with `microsoft/typescript-go`.
> Estimated 56 weeks (14 months) with 1–2 devs full-time.

## Principles

1. **DOD 1:1**: `Ast = MultiArrayList(NodeData)`, `NodeIndex = u32`,
   `SymbolIndex = u32`, `TypeIndex = u32`. Already correct — keep it.
2. **One file per PR**: each PR ports one Go file → one Zig file, with a
   baseline test case from `tests/cases/conformance/`.
3. **Stub first, fill later**: keep signatures exact; return default for
   stubs. Commit "stub", then a follow-up PR fills the body. Keep
   `zig build` green at every commit.
4. **Submodule sync**: every 2 weeks, `cd submodule/typescript-go && git pull`
   to catch upstream API drift.
5. **Test-driven**: each ported method must have ≥1 baseline test passing.
6. **Generators before manual port**: port `_scripts/generate-*.ts` to Zig
   comptime before porting `*_generated.go` manually.

---

## Phase 0 — Unblock (Weeks 1–4)

**Goal:** `tsc hello.ts` runs end-to-end on Linux/macOS. CI green.

| Task | File(s) | LOC | Status |
|---|---|---:|---|
| 0.1 Install Zig 0.16+ in dev env | — | — | ✅ |
| 0.2 Fix `src/sys.zig` hardcode cwd → `std.process.getCwd` | `src/sys.zig` | +90 | ✅ |
| 0.3 Cleanup duplicate `lsp/lsproto/_generate/lsp_generated.zig` | delete | -3,959 | ✅ |
| 0.4 Delete dead `compiler/fileloader.zig` + `projectreferenceparser.zig` (broken imports, not used) | delete | -448 | ✅ |
| 0.5 Fix `generate.mts` output path typo (`.go` → `.zig`) | `_generate/generate.mts` | +5 | ✅ |
| 0.6 Verify `zig build` + `zig build test` pass | — | — | ⏳ |
| 0.7 Smoke test `tsc hello.ts` emits `hello.js` | — | — | ⏳ |
| 0.8 Setup CI: GitHub Actions (Linux + macOS) | `.github/workflows/ci.yml` | +60 | ✅ |
| 0.9 Setup submodule sync CI (daily PR) | `.github/workflows/submodule-sync.yml` | +50 | ✅ |
| 0.10 Write README.md with port progress table | `README.md` | +200 | ✅ |
| 0.11 Write PORT_PLAN.md (this file) | `PORT_PLAN.md` | +400 | ✅ |
| 0.12 Wire testrunner: run 1 conformance case | `src/testrunner/runner.zig` | +200 | ⏳ |

**Definition of Done Phase 0:**
- `zig build` succeeds on Linux + macOS
- `zig build test` passes all existing tests
- `./zig-out/bin/tsc test.ts` runs and either emits `test.js` or prints diagnostics
- CI is green on `main`

---

## Phase 1 — Core Compiler (Weeks 5–20, ~16 weeks)

**Goal:** Type-check + emit JS correct for 80% of conformance test cases.

### Phase 1.1 — Complete the checker (8 weeks)

The checker is the largest module (Go: 59,797 LOC, Zig: 36,381 LOC, 45% real fns).
`checker.go` alone is 31,926 LOC.

| Task | Go file | Priority methods |
|---|---|---|
| 1.1.1 | `checker.go` | Port top-30 largest methods: `checkFunctionOrConstructorSymbolWorker` (231 LOC), `getESDecoratorCallSignature` (177), `checkVariableLikeDeclaration` (158), `checkKindsOfPropertyMemberOverrides` (155), `resolveCall` (113), `inferTypeArguments` (106), `resolveCallExpression` (103), `checkClassLikeDeclaration` (99), `initializeChecker` (89), ... |
| 1.1.2 | `jsx.go` → `jsx.zig` (1,482 → 420, 10%) | Full JSX type checking |
| 1.1.3 | `nodebuilderimpl.go` → `nodebuilderimpl.zig` (3,585 → 1,236, 33%) | Build type AST for hover/decl emit |
| 1.1.4 | `nodebuilder_hover.go` → `nodebuilder_hover.zig` (597 → 131, 6%) | Hover info for LSP |
| 1.1.5 | `symbolaccessibility.go` → `symbolaccessibility.zig` (876 → 394, 24%) | Export visibility |
| 1.1.6 | `grammarchecks.go` → `grammarchecks.zig` (2,202 → 787, 29%) | Grammar diagnostics |
| 1.1.7 | `services.go` → `services.zig` (1,140 → 485, 44%) | Public checker API |
| 1.1.8 | `nodecopy.go` → `nodecopy.zig` (900 → 204, 32%) | Type cloning |
| 1.1.9 | `tracer.go` → `tracer.zig` (366 → 434, 21% real) | Perf tracing |
| 1.1.10 | `symboltracker.go` → `symboltracker.zig` (129 → 101, 14%) | Symbol tracking |

**DoD 1.1:** `zig build test` passes 80% of `tests/cases/conformance/types/`.

### Phase 1.2 — Complete scanner + parser (2 weeks)

| Task | File | LOC |
|---|---|---:|
| 1.2.1 | `scanner/regexp.go` → `scanner/regexp.zig` | +1,076 |
| 1.2.2 | Fix remaining 3 parser TODOs | +50 |

### Phase 1.3 — Complete transformers (4 weeks)

| Task | File | LOC |
|---|---|---:|
| 1.3.1 | `moduletransforms/commonjs.zig` (508 → ~2,200) | +1,700 |
| 1.3.2 | `moduletransforms/externalmoduleinfo.go` + `impliedmodule.go` + `utilities.go` | +800 |
| 1.3.3 | 10 estransforms helpers (forawait, namedevaluation, optionalchain, utilities, exponentiation, logicalassignment, nullishcoalescing, optionalcatch, classthis, definitions) | +2,282 |
| 1.3.4 | `jsxtransforms.zig` completion (424 → 1,209) | +785 |

### Phase 1.4 — Complete printer + tsoptions + module (2 weeks)

| Task | File | LOC |
|---|---|---:|
| 1.4.1 | `printer/emitcontext.zig` + `utilities.zig` fill | +400 |
| 1.4.2 | 7 missing `tsoptions/` files (declscompiler, showconfig, declsbuild, declswatch, declstypeacquisition, namemap, parsedbuildcommandline) | +1,840 |
| 1.4.3 | Generate `stringutil/js_case_generated.zig` (comptime generator) | +3,496 |

**DoD Phase 1:** 80% conformance pass. `tsc` compiles a large TS project
(e.g., `submodule/typescript-go/_submodules/typescript/src/compiler/checker.ts`).

---

## Phase 2 — VFS + Execute + Incremental (Weeks 21–28, ~8 weeks)

**Goal:** `tsc --build`, `tsc --watch`, `.tsbuildinfo` work.

| Task | File(s) | LOC |
|---|---|---:|
| 2.1 | `vfs/cachedvfs.zig` | +500 |
| 2.2 | `vfs/wrapvfs.zig` | +400 |
| 2.3 | `vfs/iovfs.zig` | +300 |
| 2.4 | `vfs/internal/` (FileInfo, etc.) | +200 |
| 2.5 | `vfs/vfsmock.zig` + `vfstest.zig` | +400 |
| 2.6 | `vfs/vfsmatch.zig` add methods | +200 |
| 2.7 | Extend VTable 7 → 25 methods | +100 |
| 2.8 | `execute/build/` (6 files: build, builder, host, solutionerror, ...) | +1,898 |
| 2.9 | `execute/incremental/` (11 files: incremental, host, reader, writer, ...) | +3,394 |
| 2.10 | `execute/watchmanager/` (2 files: watchbackend, watch) | +459 |
| 2.11 | Refactor `execute/tsc.zig` from custom 711 LOC → 1:1 port of Go `tsc.go` | refactor |
| 2.12 | `execute/watcher.zig` fill 5 TODOs | +370 |
| 2.13 | `fswatch/walkdir_unix.zig` + `walkdir_windows.zig` | +210 |
| 2.14 | `fswatch/fanotify_linux.zig` + `fsevents_darwin.zig` completion | +500 |

**DoD Phase 2:** `tsc --build` on composite project references + `tsc --watch`
rebuilds on file change, both Linux/macOS.

---

## Phase 3 — Language Service (Weeks 29–40, ~12 weeks)

**Goal:** LSP server runs with VS Code; completions/hover/find-refs/rename work.

### Phase 3.1 — Completions + hover (4 weeks)

| Task | File | LOC |
|---|---|---:|
| 3.1.1 | `ls/completions.zig` full port (405 → 6,295) | +5,890 |
| 3.1.2 | `ls/string_completions.zig` (97 → 2,211) | +2,114 |
| 3.1.3 | `ls/utilities.go` (1,404) → `ls/utilities.zig` | +1,404 |
| 3.1.4 | `ls/jsdoc.go` + `jsdoc_snippet.go` | +755 |
| 3.1.5 | `ls/importTracker.go` | +767 |
| 3.1.6 | `ls/displaypartswriter.go` | +217 |

### Phase 3.2 — Find-refs + rename + code actions (4 weeks)

| Task | File | LOC |
|---|---|---:|
| 3.2.1 | Fix 9 empty stubs in `ls/findallreferences.zig` (esp. `State.addReference`) | +400 |
| 3.2.2 | `ls/sourcedefinition.go` → `sourcedefinition.zig` | +707 |
| 3.2.3 | `ls/change/` subdir (3 files) | +1,423 |
| 3.2.4 | 4 `codeactions_*.go` files | +2,605 |
| 3.2.5 | `ls/crossproject.go` | +421 |
| 3.2.6 | `ls/file_rename.go` | +382 |
| 3.2.7 | `ls/codelens.go`, `autoinsert.go`, `linkedediting.go`, `source_map.go`, `format.go` | +728 |

### Phase 3.3 — LS auxiliary features (2 weeks)

| Task | File | LOC |
|---|---|---:|
| 3.3.1 | `ls/callhierarchy.zig` (62 → ~900) | +840 |
| 3.3.2 | `ls/inlay_hints.zig` (43 → ~750) | +700 |
| 3.3.3 | `ls/organizeimports.zig` (26 → ~600) | +570 |
| 3.3.4 | `ls/semantictokens.zig` (26 → ~500) | +475 |
| 3.3.5 | `ls/documenthighlights.zig` (45 → ~700) | +655 |
| 3.3.6 | `ls/symbols.zig` fix 6 stubs | +300 |
| 3.3.7 | `ls/lsutil/*` completion | +1,000 |

### Phase 3.4 — LSP protocol + transport (2 weeks)

| Task | File | LOC |
|---|---|---:|
| 3.4.1 | Re-implement `_scripts/lsp/lsproto/generate.ts` in Zig comptime → full `lsp_generated.zig` (715 types + 790 funcs) | +13,000 |
| 3.4.2 | Write `lsp/lsproto/structcodec.zig` (comptime reflection) equivalent to Go `structcodec.go` | +300 |
| 3.4.3 | Attach `jsonParse`/`jsonStringify` to lsp_generated structs | +200 |
| 3.4.4 | Refactor `protocol_session.zig` from ad-hoc `std.json.Value` → type-safe structcodec | refactor |

**DoD Phase 3:** `typescript-zig-language-server` runs with VS Code extension;
completions + hover + find-refs + rename work on a large TS project.

---

## Phase 4 — Project Service + API Server (Weeks 41–48, ~8 weeks)

**Goal:** Multi-project LSP + API server for editor integration.

### Phase 4.1 — Project model (4 weeks)

| Task | File | LOC |
|---|---|---:|
| 4.1.1 | `project/session.go` → `project/session.zig` (1,640 missing) | +1,640 |
| 4.1.2 | `project/projectcollectionbuilder.go` | +1,162 |
| 4.1.3 | `project/checkerpool.go` | +436 |
| 4.1.4 | `project/configfileregistrybuilder.go` | +733 |
| 4.1.5 | `project/ata/` (4 files) | +1,337 |
| 4.1.6 | `project/dirty/` (8 files) | +738 |
| 4.1.7 | `project/logging/` (3 files) | +332 |
| 4.1.8 | `project/background/` (1 file) | +52 |
| 4.1.9 | Fill `project/project.zig` 4 stubs | +200 |

### Phase 4.2 — API server (4 weeks)

| Task | File | LOC |
|---|---|---:|
| 4.2.1 | `api/session.go` → `api/session.zig` (103 handlers) | +3,210 |
| 4.2.2 | `api/proto.go` → `api/proto.zig` | +1,225 |
| 4.2.3 | `api/encoder/` (5 msgpack codec files) | +3,140 |
| 4.2.4 | `api/conn.go` + `conn_async.go` + `conn_sync.go` | +715 |
| 4.2.5 | `api/transport.go` + `transport_*.go` | +300 |
| 4.2.6 | `api/protocol_*.go` (jsonrpc + msgpack) | +398 |
| 4.2.7 | `api/callbackfs.go` | +226 |
| 4.2.8 | `api/server.go` + `timing.go` | +260 |
| 4.2.9 | **Decision:** keep `capi.zig` alongside RPC, or remove? Recommend keep for `libtsc.so` embedded use. | decision |

**DoD Phase 4:** `typescript-zig-language-server --api` runs; `tsgo --api`
protocol-compatible with typescript-go.

---

## Phase 5 — Polish + Test + Parity (Weeks 49–56, ~8 weeks)

**Goal:** 100% parity, full tests, production-ready.

| Task | LOC |
|---|---:|
| 5.1 Wire `fourslash/tests/gen/` 3,796 test cases into `src/fourslash/` runner | +infra |
| 5.2 Wire `tests/baselines/reference/` into `src/testutil/tsbaseline/` | +infra |
| 5.3 Achieve ≥95% pass rate on conformance tests | validation |
| 5.4 Achieve ≥90% pass rate on fourslash tests | validation |
| 5.5 Port `internal/execute/tsctests/` (12,076 LOC) — compiler integration tests | +12,076 |
| 5.6 Perf benchmark vs typescript-go: parse/check/emit large file (target ≤1.5x) | validation |
| 5.7 Memory benchmark vs typescript-go (target ≤1.2x) | validation |
| 5.8 Profile + optimize hot paths (checker, scanner) | tuning |
| 5.9 Docs: CONTRIBUTING.md, ARCHITECTURE.md | +1,000 |
| 5.10 Release v1.0.0 with Linux/macOS/Windows binaries | release |

---

## Risks & Mitigations

| # | Risk | Mitigation |
|---|---|---|
| 1 | `checker.go` is 31,926 LOC — too large for one PR | Split into 8–10 PRs by topic: expressions, declarations, types, signatures, classes, modules, JSX, JSDoc, inference, relations |
| 2 | Code generators for `ast_generated`/`lsp_generated`/`js_case_generated` need custom builds | Write Zig comptime generators early in Phase 1 |
| 3 | `catch @panic("OOM")` idiom scattered — hard to distinguish real stubs | Audit markers: standardize `// STUB:` (return default) vs `// OOM:` (catch unreachable) |
| 4 | Upstream typescript-go moves fast | Sync every 2 weeks; CI test after each sync |
| 5 | No Zig CI → easy regression | Setup GitHub Actions in Phase 0 (done) |
| 6 | `comptime reflection` for `structcodec.zig` is complex | Reference `std.json.parseFromSlice` + comptime `@typeInfo` |
| 7 | LSP generated 13,000 LOC addition | If accepting ad-hoc parse (current state), can skip 3.4.1–3.4.3 — trade-off type safety |
| 8 | Multi-threading (CheckerPool, async API) — Zig concurrency differs from Go goroutines | Decide early: `std.Thread` + thread pool, or drop multi-thread support in Phases 1–3 |
| 9 | C ABI compatibility with Go CGO | Keep `libtsc.so` exports stable, version the API |
| 10 | Fourslash test framework 5,815 LOC harness | Port harness first, then wire 3,796 test cases |

---

## Execution priority summary

```
Phase 0 (Weeks 1–4):    Unblock — sys.zig, cleanup, CI, README, testrunner
Phase 1 (Weeks 5–20):   Core Compiler — checker (8w) + scanner/parser (2w) + transformers (4w) + printer/tsoptions (2w)
Phase 2 (Weeks 21–28):  VFS + Execute + Incremental — tsc --build/--watch
Phase 3 (Weeks 29–40):  Language Service — completions/hover/find-refs/rename/codeactions + LSP protocol
Phase 4 (Weeks 41–48):  Project Service + API Server — multi-project LSP + RPC
Phase 5 (Weeks 49–56):  Polish + Test + Parity — 95% conformance pass, release v1.0
```

**Total estimate: 56 weeks (14 months)** with 1–2 devs full-time.

Reducible to 9–10 months if:
- Drop API server (Phase 4.2) → save 4 weeks
- Skip fourslash 3,796 cases (Phase 5.4) → save 2 weeks
- Accept LSP ad-hoc parse (skip Phase 3.4) → save 2 weeks
