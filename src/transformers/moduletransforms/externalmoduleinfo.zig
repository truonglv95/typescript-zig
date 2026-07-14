const std = @import("std");

//! External module info collector.
//!
//! Port of `internal/transformers/moduletransforms/externalmoduleinfo.go` (390 LOC).
//!
//! Collects information about a source file's imports, exports, and
//! re-exports for use by the CommonJS and ES module transformers.

const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const ast_utils = @import("../../ast/ast_utils.zig");

/// Information about a module's external imports and exports.
/// Port of Go's `externalModuleInfo`.
pub const ExternalModuleInfo = struct {
    /// ImportDeclaration | ImportEqualsDeclaration | ExportDeclaration.
    /// imports and re-exports of other external modules.
    external_imports: std.ArrayListUnmanaged(ast_gen.NodeIndex) = .empty,
    /// Maps local names to their associated export specifiers (excludes re-exports).
    export_specifiers: std.StringHashMapUnmanaged(std.ArrayListUnmanaged(ast_gen.NodeIndex)) = .empty,
    /// all exported names in the module (both local and re-exported).
    exported_names: std.ArrayListUnmanaged(ast_gen.NodeIndex) = .empty,
    /// all of the top-level exported function declarations.
    exported_functions: std.ArrayListUnmanaged(ast_gen.NodeIndex) = .empty,
    /// an `export=` / `module.exports=` declaration if one was present.
    export_equals: ast_gen.NodeIndex = 0,
    /// whether this module contains `export *`.
    has_export_stars_to_export_values: bool = false,

    pub fn deinit(self: *ExternalModuleInfo, allocator: std.mem.Allocator) void {
        self.external_imports.deinit(allocator);
        var iter = self.export_specifiers.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit(allocator);
        }
        self.export_specifiers.deinit(allocator);
        self.exported_names.deinit(allocator);
        self.exported_functions.deinit(allocator);
    }
};

/// Collects external module info from a source file.
/// Port of Go's `collectExternalModuleInfo`.
///
/// Walks the source file's statements looking for:
/// - ImportDeclaration (import "mod", import x from "mod", etc.)
/// - ImportEqualsDeclaration (import x = require("mod"))
/// - ExportDeclaration (export { x }, export * from "mod")
/// - ExportAssignment (export = ...)
pub fn collectExternalModuleInfo(
    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    source_file: ast_gen.NodeIndex,
) ExternalModuleInfo {
    var info = ExternalModuleInfo{};
    if (source_file == 0) return info;

    const sf_data = tree.getNode(source_file);
    if (sf_data != .SourceFile) return info;

    const statements_list = sf_data.SourceFile.Statements;
    if (statements_list == 0) return info;

    for (tree.getNodeList(statements_list)) |stmt| {
        const kind = tree.getNodeKind(stmt);
        switch (kind) {
            .ImportDeclaration => {
                info.external_imports.append(allocator, stmt) catch {};
            },
            .ImportEqualsDeclaration => {
                // Check if it's `import x = require("mod")` (external module reference)
                const imp_eq = tree.getNode(stmt).ImportEqualsDeclaration;
                const module_ref_kind = tree.getNodeKind(imp_eq.ModuleReference);
                if (module_ref_kind == .ExternalModuleReference) {
                    info.external_imports.append(allocator, stmt) catch {};
                }
            },
            .ExportDeclaration => {
                const exp_decl = tree.getNode(stmt).ExportDeclaration;
                // If it has a module specifier, it's a re-export.
                if (exp_decl.ModuleSpecifier != null and exp_decl.ModuleSpecifier.? != 0) {
                    info.external_imports.append(allocator, stmt) catch {};
                }
                // Check for export * (has no named exports but has module specifier).
                if (exp_decl.ModuleSpecifier != null and exp_decl.ModuleSpecifier.? != 0) {
                    if (exp_decl.ExportClause == 0) {
                        info.has_export_stars_to_export_values = true;
                    }
                }
            },
            .ExportAssignment => {
                const exp_assign = tree.getNode(stmt).ExportAssignment;
                if (exp_assign.IsExportEquals) {
                    info.export_equals = stmt;
                }
            },
            else => {},
        }
    }

    return info;
}
