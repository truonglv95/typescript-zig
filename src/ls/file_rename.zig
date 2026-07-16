const std = @import("std");

//! File rename support — finds all references that need updating on rename.
//!
//! Port of `internal/ls/file_rename.go` (382 LOC).
//!
//! When a file is renamed, this module finds all import/export specifiers
//! that reference the old file name and generates text edits to update them.

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const languageservice = @import("languageservice.zig");
const change = @import("change/tracker.zig");
const tspath = @import("../tspath/tspath.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const compiler = @import("../compiler/program.zig");
const scanner = @import("../scanner/scanner.zig");

/// A file edit (path + text changes).
pub const FileEdit = struct {
    file_name: []const u8,
    edits: []const TextEdit,

    pub const TextEdit = struct { start: u32, end: u32, new_text: []const u8 };
};

/// Result of a file rename — all edits needed across the project.
pub const FileRenameResult = struct {
    file_edits: []const FileEdit,
};

/// Provides edits for renaming a file.
/// Port of Go's `ProvideFileRenameEdits`.
pub fn provideFileRenameEdits(
    ls: *languageservice.LanguageService,
    old_file_name: []const u8,
    new_file_name: []const u8,
) !FileRenameResult {

    const program = ls.getProgram();
    var allocator = ls.allocator;
    
    // Tracker collects all edits
    var tracker = change.Tracker.init(allocator, program, ls.converters.*);
    defer tracker.deinit();

    // 1. Find all files that import the old file & Update import specifiers
    const allFiles = program.units.items;
    for (allFiles) |unit| {
        const tree = unit.tree();
        const fileName = tree.SourceFile.fileName;
        const sourceFileNode = tree.getNode(tree.source_file);

        // Simple iteration over imports
        for (tree.statements.items) |stmt| {
            if (ast_utils.isAnyImportSyntax(tree, stmt)) {
                const specifier = ast_utils.tryGetImportFromModuleSpecifier(tree, stmt);
                if (specifier != 0) {
                    const text = ast_utils.getTextOfNode(tree, specifier);
                    var actual_text = text;
                    if (actual_text.len >= 2 and (actual_text[0] == '"' or actual_text[0] == '\'')) {
                        actual_text = actual_text[1 .. actual_text.len - 1];
                    }
                    if (tspath.isExternalModuleNameRelative(actual_text)) {
                        const old_dir = tspath.getDirectoryPath(allocator, fileName) catch continue;
                        defer allocator.free(old_dir);

                        const old_absolute = tspath.combinePaths(allocator, old_dir, &[_][]const u8{actual_text}) catch continue;
                        defer allocator.free(old_absolute);

                        const old_absolute_norm = tspath.normalizePath(allocator, old_absolute) catch continue;
                        defer allocator.free(old_absolute_norm);

                        const cmp_opts = tspath.ComparePathsOptions{ .useCaseSensitiveFileNames = ls.useCaseSensitiveFileNames() };

                        var new_absolute = old_absolute_norm;
                        var to_free: ?[]const u8 = null;
                        defer if (to_free) |f| allocator.free(f);

                        if (tspath.comparePaths(old_absolute_norm, old_file_name, cmp_opts) == 0) {
                            new_absolute = new_file_name;
                        } else if ((tspath.startsWithDirectory(allocator, old_absolute_norm, old_file_name, ls.useCaseSensitiveFileNames()) catch false)) {
                            const rest = old_absolute_norm[old_file_name.len..];
                            new_absolute = std.fmt.allocPrint(allocator, "{s}{s}", .{new_file_name, rest}) catch continue;
                            to_free = new_absolute;
                        } else {
                            const old_file_name_no_ext = tspath.removeFileExtension(old_file_name);
                            if (tspath.comparePaths(old_absolute_norm, old_file_name_no_ext, cmp_opts) == 0) {
                                new_absolute = tspath.removeFileExtension(new_file_name);
                            } else if ((tspath.startsWithDirectory(allocator, old_absolute_norm, old_file_name_no_ext, ls.useCaseSensitiveFileNames()) catch false)) {
                                const rest = old_absolute_norm[old_file_name_no_ext.len..];
                                const new_file_name_no_ext = tspath.removeFileExtension(new_file_name);
                                new_absolute = std.fmt.allocPrint(allocator, "{s}{s}", .{new_file_name_no_ext, rest}) catch continue;
                                to_free = new_absolute;
                            }
                        }

                        var new_import_from_path = fileName;
                        if (tspath.comparePaths(fileName, old_file_name, cmp_opts) == 0) {
                            new_import_from_path = new_file_name;
                        }

                        const new_import_dir = tspath.getDirectoryPath(allocator, new_import_from_path) catch continue;
                        defer allocator.free(new_import_dir);

                        const relative = tspath.getRelativePathFromDirectory(allocator, new_import_dir, new_absolute, cmp_opts) catch continue;
                        defer allocator.free(relative);

                        const updated = tspath.ensurePathIsNonModuleName(allocator, relative) catch continue;
                        defer allocator.free(updated);

                        if (!std.mem.eql(u8, actual_text, updated)) {
                            const range = ast_utils.getTextRangeOfNode(tree, specifier);
                            tracker.replaceRangeWithText(sourceFileNode, .{
                                .pos = range.start + 1,
                                .end = range.end - 1,
                            }, updated) catch {};
                        }
                    }
                }
            }
        }
    }

    // Convert tracker changes to FileRenameResult
    var fileEdits = std.ArrayList(FileEdit).init(allocator);
    for (tracker.changes.items) |c| {
        var edits = std.ArrayList(FileEdit.TextEdit).init(allocator);
        for (c.edits.items) |e| {
            try edits.append(.{ .start = e.range.pos, .end = e.range.end, .new_text = e.newText });
        }
        try fileEdits.append(.{
            .file_name = c.fileName,
            .edits = try edits.toOwnedSlice(),
        });
    }

    return FileRenameResult{ .file_edits = try fileEdits.toOwnedSlice() };
}
