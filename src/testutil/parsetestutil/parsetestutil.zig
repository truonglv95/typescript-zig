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

const visit_each_child = @import("../../ast/visit_each_child.zig");
const visitor = @import("../../ast/visitor.zig");

pub fn markSyntheticRecursive(tree: *ast.NodeTree, node: ast.NodeIndex) void {
    const VisitCtx = struct {
        tree: *ast.NodeTree,
        fn visit(ctx: ?*anyopaque, v: *visitor.NodeVisitor, n: ast.NodeIndex) ast.NodeIndex {
            if (n != 0) {
                const self: *@This() = @ptrCast(@alignCast(ctx));
                self.tree.positions.items[n] = .{ .pos = 0, .end = 0 };
                return visit_each_child.visitEachChild(v, n);
            }
            return n;
        }
    };

    var ctx = VisitCtx{ .tree = tree };
    var v = visitor.NodeVisitor.init(
        tree.allocator,
        tree,
        &ctx,
        VisitCtx.visit,
        .{}, // hooks
    );
    _ = v.visitNode(node);
}
