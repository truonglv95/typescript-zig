const std = @import("std");
const ast = @import("../../ast/ast.zig");
const core = @import("../../core/core.zig");
const diagnosticwriter = @import("../../diagnosticwriter/diagnosticwriter.zig");
const parser = @import("../../parser/parser.zig");
const tspath = @import("../../tspath/tspath.zig");

pub fn parseTypeScript(allocator: std.mem.Allocator, text: []const u8, jsx: bool) !*ast.SourceFile {
    const fileName = if (jsx) "/main.tsx" else "/main.ts";
    const file = try parser.parseSourceFile(allocator, .{
        .fileName = fileName,
        .path = fileName,
    }, text, core.getScriptKindFromFileName(fileName));
    return file;
}

pub fn checkDiagnostics(file: *ast.SourceFile) !void {
    if (file.diagnostics.len > 0) {
        std.debug.print("Diagnostics found\n", .{});
        return error.DiagnosticsFound;
    }
}

pub fn checkDiagnosticsMessage(file: *ast.SourceFile, message: []const u8) !void {
    if (file.diagnostics.len > 0) {
        std.debug.print("{s}\n", .{message});
        return error.DiagnosticsFound;
    }
}

pub fn markSyntheticRecursive(tree: *ast.NodeTree, node: ast.NodeIndex) void {
    _ = tree;
    _ = node;
    // TODO: Implement using DoD visitor for AST indices
}
