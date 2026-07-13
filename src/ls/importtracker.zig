const std = @import("std");

//! Import tracker — finds all import/export references across files.
//!
//! Port of `internal/ls/importTracker.go` (767 LOC).
//!
//! Used by find-all-references and rename to track how a symbol is
//! imported and exported across the project. The tracker:
//! 1. Builds a map of all direct imports (which file imports what module)
//! 2. For a given export symbol, finds all files that import it
//! 3. Returns import locations + single references + indirect users

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const symbol = @import("../ast/symbol.zig");
const checker = @import("../checker/checker.zig");

/// Import or export kind.
pub const ImpExpKind = enum(i32) {
    Unknown,
    Import,
    Export,
};

/// Export kind — how a symbol is exported from a module.
pub const ExportKind = enum(u8) {
    Named = 0,
    Default = 1,
    ExportEquals = 2,
    UMD = 3,
    Module = 4,
};

/// Info about an export — which module exports it and how.
pub const ExportInfo = struct {
    exporting_module_symbol: ast_gen.SymbolIndex = 0,
    export_kind: ExportKind = .Named,
};

/// An import/export symbol with its kind and export info.
pub const ImportExportSymbol = struct {
    kind: ImpExpKind = .Unknown,
    symbol: ast_gen.SymbolIndex = 0,
    export_info: ?ExportInfo = null,
};

/// A location and its associated import symbol.
pub const LocationAndSymbol = struct {
    import_location: ast_gen.NodeIndex = 0,
    import_symbol: ast_gen.SymbolIndex = 0,
};

/// Result of tracking imports for a symbol.
pub const ImportsResult = struct {
    /// Import locations that reference the symbol.
    import_searches: std.ArrayListUnmanaged(LocationAndSymbol) = .empty,
    /// Single references (not part of an import statement).
    single_references: std.ArrayListUnmanaged(ast_gen.NodeIndex) = .empty,
    /// Files that indirectly use the symbol (via re-exports).
    indirect_users: std.ArrayListUnmanaged(ast_gen.NodeIndex) = .empty,
};

/// Module reference kind.
pub const ModuleReferenceKind = enum(i32) {
    Import,
    Reference,
    Implicit,
};

/// A reference to a module — either via import, <reference>, or implicit.
pub const ModuleReference = struct {
    kind: ModuleReferenceKind = .Import,
    /// For import and implicit kinds (StringLiteralLike).
    literal: ast_gen.NodeIndex = 0,
    /// The file that references the module.
    referencing_file: ast_gen.NodeIndex = 0,
    /// For reference kind (FileReference).
    ref: ast_gen.NodeIndex = 0,
};

/// Import tracker function type.
pub const ImportTracker = *const fn (
    export_symbol: ast_gen.SymbolIndex,
    export_info: ?ExportInfo,
    is_for_rename: bool,
) *ImportsResult;

/// Creates an import tracker for the given source files.
/// Port of Go's `createImportTracker`.
///
/// Full implementation requires:
/// 1. Build a map of all direct imports (file -> modules it imports)
/// 2. For each export symbol, find all files that import it
/// 3. Return import locations + single references
///
/// TODO(phase3.2): wire full implementation with compiler.Program.
pub fn createImportTrackerStub() ImportTracker {
    return stubTracker;
}

fn stubTracker(
    export_symbol: ast_gen.SymbolIndex,
    export_info: ?ExportInfo,
    is_for_rename: bool,
) *ImportsResult {
    _ = export_symbol;
    _ = export_info;
    _ = is_for_rename;
    // Return empty result.
    const result = std.heap.page_allocator.create(ImportsResult) catch unreachable;
    result.* = .{};
    return result;
}
