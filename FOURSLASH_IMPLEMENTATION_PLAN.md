# Fourslash Test Framework Implementation Plan

## Current Status
- **Total functions**: 143
- **Real implementations**: 11 (7.7%)
- **Stub no-ops**: 132 (92.3%)
- **Total test calls**: 4,653 — 4,210 (90.5%) hit stubs

## Implementation Plan (8 Phases)

### Phase 1: Core Infrastructure (11 stubs, 1,634 calls)
**Mục tiêu**: Marker tracking + position management — nền tảng cho mọi verify function.

| Function | Calls | Mô tả |
|----------|-------|-------|
| GoToMarker | 1,589 | Di chuyển caret đến marker position (/**/) |
| GoToEOF | 19 | Di chuyển đến cuối file |
| GoToBOF | 14 | Di chuyển đến đầu file |
| GoToPosition | 6 | Di chuyển đến position tuyệt đối |
| Markers | 3 | Lấy tất cả marker positions |
| MarkerNames | 2 | Lấy tên markers |
| Ranges | 1 | Lấy range markers |
| goToMarker | 0 | Internal setter |
| goToPosition | 0 | Internal setter |
| MarkerByName | 0 | Lấy marker theo tên |
| getRangesInFile | 0 | Lấy ranges trong file |

**Dependencies**: FourslashTest struct cần có `caretPosition: u32` và `markers: HashMap`.

### Phase 2: Text Editing (12 stubs, 379 calls)
**Mục tiêu**: Edit file content — cần cho test edit scenarios.

| Function | Calls | Mô tả |
|----------|-------|-------|
| Insert | 267 | Insert text tại caret |
| InsertLine | 35 | Insert dòng mới |
| DeleteAtCaret | 29 | Xóa ký tự tại caret |
| ReplaceLine | 26 | Thay thế dòng hiện tại |
| Backspace | 18 | Xóa ký tự trước caret |
| Paste | 4 | Paste text |
| Replace | 0 | Thay thế text range |
| replaceWorker | 0 | Internal replace |
| typeText | 0 | Type text char by char |
| editContent | 0 | Edit file content |
| applyTextEdits | 0 | Apply text edits |
| editScriptAndUpdateMarkers | 0 | Edit + update markers |

**Dependencies**: Phase 1 (caret position), file content management.

### Phase 3: Verification — Output (3 stubs, 869 calls)
**Mục tiêu**: Verify output content — quan trọng nhất để kiểm tra emit/format.

| Function | Calls | Mô tả |
|----------|-------|-------|
| VerifyCurrentLineContent | 774 | Verify dòng hiện tại matches expected |
| VerifyCurrentFileContent | 95 | Verify toàn bộ file content |
| VerifyIndentation | 0 | Verify indentation |

**Dependencies**: Phase 1 (position), Phase 2 (editing), emit/format engine.

### Phase 4: Verification — Completions (8 stubs, 88 calls)
**Mục tiêu**: Completion list verification.

| Function | Calls | Mô tả |
|----------|-------|-------|
| VerifyCompletions | 88 | Verify completion list |
| GetCompletions | 0 | Get completion list |
| getCompletions | 0 | Internal getter |
| verifyCompletionsWorker | 0 | Internal worker |
| verifyCompletionsItems | 0 | Verify items |
| verifyCompletionsAreExactly | 0 | Verify exact match |
| verifyCompletionItem | 0 | Verify single item |
| ResolveCompletionItem | 0 | Resolve item |

**Dependencies**: Phase 1 (position), LS completion engine.

### Phase 5: Verification — Hover/QuickInfo (5 stubs, 236 calls)
**Mục tiêu**: Hover info verification.

| Function | Calls | Mô tả |
|----------|-------|-------|
| VerifyBaselineHover | 137 | Verify hover baseline |
| VerifyQuickInfoIs | 64 | Verify quick info text |
| VerifyQuickInfoExists | 24 | Verify quick info exists |
| VerifyNotQuickInfoExists | 11 | Verify no quick info |
| VerifyQuickInfoAt | 0 | Verify at position |

**Dependencies**: Phase 1 (position), LS hover engine.

### Phase 6: Verification — Code Actions (9 stubs, 643 calls)
**Mục tiêu**: Code fix + format verification.

| Function | Calls | Mô tả |
|----------|-------|-------|
| VerifyImportFixAtPosition | 182 | Verify import fix |
| FormatDocument | 166 | Format document |
| VerifyCodeFix | 155 | Verify code fix result |
| VerifyRangeAfterCodeFix | 71 | Verify range after fix |
| VerifyCodeFixAvailable | 25 | Verify fix available |
| FormatSelection | 23 | Format selection |
| VerifyCodeFixAll | 21 | Verify fix all |
| VerifyCodeFixNotAvailable | 0 | Verify no fix |
| VerifyOrganizeImports | 0 | Verify organize imports |

**Dependencies**: Phase 1 (position), Phase 3 (content verify), code fix engine.

### Phase 7: Verification — Navigation (1 stub, 0 calls)
**Mục tiêu**: Go-to navigation verification.

| Function | Calls | Mô tả |
|----------|-------|-------|
| VerifyBaselineGoToImplementation | 0 | Verify go to implementation |

**Dependencies**: Phase 1 (position), LS navigation engine.

### Phase 8: Verification — Other (11 stubs, 430 calls)
**Mục tiêu**: Miscellaneous verification.

| Function | Calls | Mô tả |
|----------|-------|-------|
| MarkTestAsStradaServer | 148 | Mark as Strada server |
| VerifyBaselineDocumentSymbol | 84 | Verify document symbols |
| VerifyBaselineSelectionRanges | 34 | Verify selection ranges |
| VerifyBaselineSignatureHelp | 30 | Verify signature help |
| VerifySuggestionDiagnostics | 20 | Verify suggestion diagnostics |
| VerifyRenameSucceeded | 18 | Verify rename |
| VerifyNonSuggestionDiagnostics | 8 | Verify non-suggestion diagnostics |
| VerifyBaselineCallHierarchy | 0 | Verify call hierarchy |
| VerifyRename | 0 | Verify rename result |
| VerifyDiagnostics | 0 | Verify diagnostics |

**Dependencies**: All previous phases.

## Priority Order (by impact)
1. **Phase 1** — Core Infrastructure (1,634 calls) → unlocks position tracking
2. **Phase 3** — Output Verification (869 calls) → unlocks content checking
3. **Phase 6** — Code Actions (643 calls) → unlocks code fix testing
4. **Phase 8** — Other (430 calls) → unlocks misc verification
5. **Phase 2** — Text Editing (379 calls) → unlocks edit scenarios
6. **Phase 5** — Hover/QuickInfo (236 calls) → unlocks hover testing
7. **Phase 4** — Completions (88 calls) → unlocks completion testing
8. **Phase 7** — Navigation (0 calls) → low priority

## Expected Impact
- After Phase 1: 1,634 calls become real (35% of total)
- After Phase 1+3: 2,503 calls become real (54% of total)
- After Phase 1+3+6: 3,146 calls become real (68% of total)
- After Phase 1+3+6+8: 3,576 calls become real (77% of total)
- After Phase 1+3+6+8+2: 3,955 calls become real (85% of total)
