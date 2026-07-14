# Plan: Port 194 remaining stubs in typescript-zig

> Cập nhật: 2026-07-15
> Tổng số stubs còn lại: **194** (trong checker.zig: 137, files khác: 57)
> Build status: 72/85 tests pass, 12 skipped, 1 pre-existing failure

## Phân tích hiện trạng

| File | Stubs | % of total |
|------|------:|-----------:|
| checker/checker.zig | 137 | 70.6% |
| checker/symbolaccessibility.zig | 14 | 7.2% |
| checker/jsx.zig | 13 | 6.7% |
| checker/nodecopy.zig | 6 | 3.1% |
| checker/relater.zig | 4 | 2.1% |
| checker/inference.zig | 4 | 2.1% |
| checker/emitresolver.zig | 4 | 2.1% |
| checker/utilities.zig | 3 | 1.5% |
| checker/symboltracker.zig | 3 | 1.5% |
| Other (6 files) | 6 | 3.1% |
| **Total** | **194** | **100%** |

### Phân loại theo stub type

| Stub type | Count | Mô tả |
|-----------|------:|-------|
| void_noop | 164 | Side-effect functions, body chỉ `_ = params` |
| false | 13 | Bool predicates trả false |
| zero | 12 | Trả 0 (SymbolIndex/NodeIndex/u32) |
| null | 5 | Trả null (optional types) |

### Phân loại theo chức năng

| Category | Count | Ưu tiên |
|----------|------:|---------|
| check* (validation/diagnostics) | 75 | P0-P2 |
| report* (error reporting) | 18 | P1-P2 |
| mark* (reference tracking) | 14 | P2 |
| resolve* (type/symbol resolution) | 7 | P0-P1 |
| write* (serialization) | 8 | P3 |
| JSX-related | 13 | P2 |
| Symbol accessibility | 14 | P2 |
| Type system init | 5 | P1 |
| Stack/context management | 12 | P1 |
| Unused checks | 8 | P2 |
| Other | 20 | P2-P3 |

---

## Priority breakdown

### P0 — Critical check paths (affects type checking correctness)
**28 stubs, ~600 LOC Zig estimated**

Các stub trực tiếp ảnh hưởng đến type checking — nếu không port, checker
sẽ không phát hiện lỗi type mismatch.

| # | Method | File:Line | Go LOC | Est Zig LOC | Dependencies |
|---|--------|-----------|-------:|------------:|--------------|
| 1 | `checkVariableLikeDeclaration` | checker.zig:~9500 | 158 | 140 | checkTypeAssignableTo, getWidenedTypeForVariableLikeDeclaration |
| 2 | `checkFunctionOrMethodDeclaration` | checker.zig:8291 | 120 | 100 | getSignatureFromDeclaration, checkReturnType |
| 3 | `checkClassLikeDeclaration` | checker.zig:8386 | 95 | 80 | checkClassMembers, resolveBaseTypes |
| 4 | `checkBreakOrContinueStatement` | checker.zig:16812 | 40 | 35 | getBreakOrContinueTarget |
| 5 | `checkThisType` | checker.zig:17253 | 30 | 25 | getThisType |
| 6 | `checkTypeQuery` | checker.zig:~17050 | 50 | 45 | getTypeFromTypeQueryNode |
| 7 | `checkTypeReferenceOrImport` | checker.zig:~17060 | 60 | 50 | getTypeFromTypeReference |
| 8 | `checkImportType` | checker.zig:17014 | 40 | 35 | getTypeFromImportTypeNode |
| 9 | `checkMissingDeclaration` | checker.zig:17067 | 20 | 15 | — |
| 10 | `checkGrammarStatementInAmbientContext` | checker.zig:16980 | 15 | 10 | — |
| 11 | `checkJSDocType` | checker.zig:17040 | 25 | 20 | getTypeFromTypeNode |
| 12 | `checkConstEnumAccess` | checker.zig:9370 | 30 | 25 | isConstEnumSymbol |
| 13 | `checkPropertyInitialization` | checker.zig:8533 | 80 | 70 | getSymbolOfDeclaration, getTypeOfSymbol |
| 14 | `checkAllCodePathsInNonVoidFunctionReturnOrThrow` | checker.zig:8320 | 90 | 80 | collectReturnTypes |
| 15 | `checkAsyncFunctionReturnType` | checker.zig:8209 | 35 | 30 | createPromiseReturnType |
| 16 | `checkDeferredNodes` | checker.zig:8164 | 25 | 20 | checkDeferredNode |
| 17 | `checkDeferredNode` | checker.zig:8169 | 30 | 25 | checkSourceElement |
| 18 | `checkNodeDeferred` | checker.zig:1726 | 20 | 15 | checkNode |
| 19 | `checkAssertionDeferred` | checker.zig:10598 | 25 | 20 | checkAssertion |
| 20 | `checkDeprecatedSignature` | checker.zig:9487 | 30 | 25 | isDeprecatedSymbol |
| 21 | `checkNullishCoalesceOperands` | checker.zig:10957 | 40 | 35 | checkNullishCoalesceOperandLeft |
| 22 | `checkNullishCoalesceOperandLeft` | checker.zig:10963 | 30 | 25 | getTypeFacts |
| 23 | `checkDeleteExpressionMustBeOptional` | checker.zig:10083 | 25 | 20 | isOptionalType |
| 24 | `checkTypeParameterListsIdentical` | checker.zig:8396 | 50 | 45 | getTypeParametersOfNode |
| 25 | `checkTypeNameIsReserved` | checker.zig:9131 | 20 | 15 | — |
| 26 | `checkObjectTypeForDuplicateDeclarations` | checker.zig:8269 | 45 | 40 | getPropertiesOfType |
| 27 | `checkClassOrInterfaceForDuplicateIndexSignatures` | checker.zig:8523 | 35 | 30 | getIndexInfosOfType |
| 28 | `checkTypeForDuplicateIndexSignatures` | checker.zig:8528 | 30 | 25 | getIndexInfosOfType |

### P1 — Type resolution & symbol resolution
**22 stubs, ~500 LOC Zig estimated**

| # | Method | File | Go LOC | Est Zig LOC | Notes |
|---|--------|------|-------:|------------:|-------|
| 1 | `resolveBaseTypesOfClass` | checker.zig | 90 | 80 | Port từ Go resolveBaseTypesOfClass |
| 2 | `resolveBaseTypesOfInterface` | checker.zig | 70 | 60 | Port từ Go resolveBaseTypesOfInterface |
| 3 | `resolveMappedTypeMembers` | checker.zig | 80 | 70 | Port từ Go resolveMappedTypeMembers |
| 4 | `resolveReverseMappedTypeMembers` | checker.zig | 60 | 50 | Port từ Go |
| 5 | `computeEnumMemberValues` | checker.zig:4354 | 40 | 35 | Đã port ở phiên trước nhưng file bị reset |
| 6 | `initializeChecker` | checker.zig | 200 | 180 | Init intrinsic types, caches |
| 7 | `initializeClosures` | checker.zig | 50 | 45 | Init closure types |
| 8 | `initializeIterationResolvers` | checker.zig | 40 | 35 | Init iteration type resolvers |
| 9 | `pushTypeResolution` | checker.zig | 25 | 20 | Type resolution stack |
| 10 | `popTypeResolution` | checker.zig:12732 | 20 | 15 | Pop from stack |
| 11 | `pushInferenceContext` | checker.zig | 30 | 25 | Inference context stack |
| 12 | `popInferenceContext` | checker.zig | 25 | 20 | Pop inference context |
| 13 | `pushActiveMapper` | checker.zig | 20 | 15 | Active mapper stack |
| 14 | `popActiveMapper` | checker.zig | 20 | 15 | Pop mapper |
| 15 | `pushContextualType` | checker.zig | 25 | 20 | Contextual type stack |
| 16 | `popContextualType` | checker.zig | 20 | 15 | Pop contextual type |
| 17 | `pushErrorFallbackNode` | checker.zig | 20 | 15 | Error fallback stack |
| 18 | `popErrorFallbackNode` | checker.zig | 20 | 15 | Pop fallback |
| 19 | `restoreErrorState` | checker.zig | 25 | 20 | Restore error state |
| 20 | `startRecoveryScope` | checker.zig | 20 | 15 | Flow recovery |
| 21 | `endRecoveryScope` | checker.zig | 20 | 15 | End recovery |
| 22 | `clearActiveMapperCaches` | checker.zig | 15 | 10 | Clear mapper cache |

### P2 — Diagnostics, reference tracking, unused checks
**67 stubs, ~900 LOC Zig estimated**

#### Report functions (18 stubs)
| # | Method | Go LOC | Notes |
|---|--------|-------:|-------|
| 1-18 | `reportError`, `reportCircularBaseType`, `reportCannotInvokePossiblyNullOrUndefinedError`, `reportObjectPossiblyNullOrUndefinedError`, `reportTruncationError`, `reportMergeSymbolError`, `reportNonDefaultExport`, `reportInferenceFallback`, `reportUnreliableMapperStub`, `reportUnusedBindingElements`, `reportUnusedImports`, `reportUnusedLocal`, `reportUnusedParameters`, `reportUnusedVariable`, `reportUnusedVariableDeclarations`, `reportUnusedVariables`, `reportErrorStub` | 15-40 each | Đa số gọi addDiagnostic với message tương ứng |

#### Mark functions (14 stubs)
| # | Method | Go LOC | Notes |
|---|--------|-------:|-------|
| 1-14 | `markAliasReferenced`, `markAliasSymbolAsReferenced`, `markDecoratorAliasReferenced`, `markDecoratorMedataDataTypeNodeAsReferenced`, `markEntityNameOrEntityExpressionAsReference`, `markExportAsReferenced`, `markExportAssignmentAliasReferenced`, `markExportSpecifierAliasReferenced`, `markIdentifierAliasReferenced`, `markImportEqualsAliasReferenced`, `markJsxAliasReferenced`, `markLinkedAliases`, `markNodeAssignments`, `markTypeNodeAsReferenced` | 10-30 each | Set flag trên symbol/links |

#### Check functions (diagnostic-only, 35 stubs)
| # | Method | Go LOC | Notes |
|---|--------|-------:|-------|
| 1-35 | `checkClassForStaticPropertyNameConflicts`, `checkClassNameCollisionWithObject`, `checkCollisionWithGlobalObjectInGeneratedCode`, `checkCollisionWithGlobalPromiseInGeneratedCode`, `checkCollisionWithRequireExportsInGeneratedCode`, `checkCollisionsForDeclarationName`, `checkDecorator`, `checkDecorators`, `checkExportSpecifier`, `checkExportsOnMergedDeclarations`, `checkExternalEmitHelpers`, `checkExternalModuleExports`, `checkFunctionExpressionOrObjectLiteralMethodDeferred`, `checkFunctionOrConstructorSymbol`, `checkFunctionOrConstructorSymbolWorker`, `checkGrammarNumericLiteral`, `checkImportAttributes`, `checkImportBinding`, `checkIndexConstraintForIndexSignature`, `checkJSDocComment`, `checkJSDocComments`, `checkJSDocTypeIsInJsFile`, `checkModuleAugmentationElement`, `checkModuleExportName`, `checkNotCanceled`, `checkReflectCollision`, `checkResolvedBlockScopedVariable`, `checkThisInStaticClassFieldInitializerInDecoratedClass`, `checkTypeParameterDeferred`, `checkUnusedClassMembers`, `checkUnusedIdentifiers`, `checkUnusedInferTypeParameter`, `checkUnusedLocalsAndParameters`, `checkUnusedRenamedBindingElements`, `checkUnusedTypeParameters`, `checkVarDeclaredNamesNotShadowed`, `checkWeakMapSetCollision` | 15-80 each | Validation + diagnostics |

### P3 — JSX, symbol accessibility, serialization
**77 stubs, ~700 LOC Zig estimated**

#### JSX (13 stubs in jsx.zig)
| # | Method | Go LOC | Notes |
|---|--------|-------:|-------|
| 1-13 | `checkApplicableSignatureForJsxCallLikeElement`, `checkJsxAttribute`, `checkJsxElementDeferred`, `checkJsxOpeningLikeElementOrOpeningFragment`, `checkJsxPreconditions`, `checkJsxSelfClosingElementDeferred`, `createSignatureForJSXIntrinsic`, `generateJsxChildren`, `getEffectiveFirstArgumentForJsxSignature`, `getJSXFragmentType`, `getJsxFactoryEntity`, `getSuggestedSymbolForNonexistentJSXAttribute`, `resolveJsxOpeningLikeElement` | 30-100 each | Full JSX type checking |

#### Symbol accessibility (14 stubs in symbolaccessibility.zig)
| # | Method | Go LOC | Notes |
|---|--------|-------:|-------|
| 1-14 | `canQualifySymbol`, `hasExternalModuleSymbol`, `isAccessible`, `isNamespaceReexportDeclaration`, `isPropertyOrMethodDeclarationSymbol`, `isUMDExportSymbol`, `needsQualification`, `someSymbolTableInScope`, `compareSymbolChainsWorker`, `getAliasForSymbolInContainer`, `getClassExpressionNameTable`, `getExternalModuleContainer`, `getFileSymbolIfFileSymbolExportEqualsContainer`, `getVariableDeclarationOfObjectLiteral` | 20-60 each | Symbol visibility for completions |

#### Serialization (8 stubs in nodecopy.zig)
| # | Method | Go LOC | Notes |
|---|--------|-------:|-------|
| 1-8 | `writeAlias`, `writeByte`, `writeInt`, `writeNode`, `writeNodeId`, `writeString`, `writeSymbol`, `writeType`, `writeTypes` | 10-20 each | Binary serialization for caching |

#### Other (42 stubs)
| Category | Count | Est LOC |
|----------|------:|--------:|
| `add*` (suggestions, helpers) | 5 | 50 |
| `assign*` (parameter types) | 4 | 80 |
| `get*` (JSX, module) | 7 | 100 |
| `has*` (predicates) | 3 | 20 |
| `is*` (predicates) | 4 | 30 |
| `merge*` (symbol merging) | 2 | 50 |
| `record*` (collision tracking) | 3 | 30 |
| `set*` (links, ranges) | 4 | 40 |
| `track*` (computed names, CJS) | 2 | 20 |
| Other utility | 8 | 80 |

---

## Porting order (dependency-based)

### Phase 1: Fix build errors (prerequisite)
**1-2 sessions, ~50 LOC**

Fix 11 compilation errors (duplicate struct members, doc comment issues,
unused variables) before porting stubs.

### Phase 2: P0 — Critical check paths
**3-4 sessions, ~600 LOC**

Port theo dependency order:
1. Stack/context management (push/popTypeResolution, push/popContextualType)
2. `checkDeferredNodes` + `checkDeferredNode` (unblocks deferred checking)
3. `checkVariableLikeDeclaration` (hub method, calls many helpers)
4. `checkFunctionOrMethodDeclaration` + `checkAsyncFunctionReturnType`
5. `checkClassLikeDeclaration` + `checkPropertyInitialization`
6. `checkBreakOrContinueStatement` + `checkThisType`
7. `checkTypeQuery` + `checkTypeReferenceOrImport` + `checkImportType`
8. `checkAllCodePathsInNonVoidFunctionReturnOrThrow`
9. Remaining check* stubs

### Phase 3: P1 — Type resolution & init
**2-3 sessions, ~500 LOC**

1. `initializeChecker` (init all intrinsic types + caches)
2. `resolveBaseTypesOfClass` + `resolveBaseTypesOfInterface`
3. `resolveMappedTypeMembers` + `resolveReverseMappedTypeMembers`
4. `computeEnumMemberValues` (re-port if lost)
5. Inference context stack (push/popInferenceContext)
6. Active mapper stack (push/popActiveMapper)
7. Error fallback stack (push/popErrorFallbackNode)
8. Recovery scope (start/endRecoveryScope)

### Phase 4: P2 — Diagnostics & reference tracking
**3-4 sessions, ~900 LOC**

1. `reportError` + all `report*` functions (18 stubs)
2. `mark*` reference tracking (14 stubs)
3. `check*` diagnostic-only functions (35 stubs)
4. Unused checks (`checkUnused*` series)

### Phase 5: P3 — JSX, symbol accessibility, serialization
**2-3 sessions, ~700 LOC**

1. JSX type checking (13 stubs in jsx.zig)
2. Symbol accessibility (14 stubs in symbolaccessibility.zig)
3. Serialization (8 stubs in nodecopy.zig)
4. Other utility stubs

---

## Ước tính tổng quan

| Phase | Sessions | LOC Zig | Stubs |
|-------|----------|--------:|------:|
| 1: Fix build | 1-2 | 50 | 0 |
| 2: P0 check paths | 3-4 | 600 | 28 |
| 3: P1 type resolution | 2-3 | 500 | 22 |
| 4: P2 diagnostics | 3-4 | 900 | 67 |
| 5: P3 JSX/symbol/serial | 2-3 | 700 | 77 |
| **Total** | **11-16** | **2750** | **194** |

## Lưu ý quan trọng

1. **File checker.zig bị reset**: Một số stub đã port trong phiên trước
   (như `computeEnumMemberValues`, `checkObjectLiteral`, `getWidenedTypeWithContext`)
   có thể đã bị mất do file reset. Cần verify lại trước khi port.

2. **Build errors cần fix trước**: 11 compilation errors hiện tại phải được
   fix trước khi port stubs mới, nếu không không thể verify build.

3. **Test coverage**: Sau mỗi phase, chạy `python3 -m ziglang build test`
   để verify 72/85 tests vẫn pass và không regression.

4. **Commit per stub group**: Mỗi nhóm stub liên quan nên được commit
   riêng để dễ rollback nếu có vấn đề.

5. **Go reference**: Luôn tham khảo Go implementation tại
   `submodule/typescript-go/internal/checker/checker.go` trước khi port.
