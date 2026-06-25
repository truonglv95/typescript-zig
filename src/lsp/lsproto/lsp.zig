const std = @import("std");
const lsproto = @import("lsp_generated.zig");

// In Zig we use []const u8 for DocumentUri
pub const DocumentUri = []const u8;

pub fn getFileName(uri: DocumentUri, allocator: std.mem.Allocator) ![]const u8 {
    // Basic file:// stripping for now.
    const prefix = "file://";
    if (std.mem.startsWith(u8, uri, prefix)) {
        return uri[prefix.len..];
    }
    return try allocator.dupe(u8, uri);
}

pub fn getClientCapabilities() lsproto.ClientCapabilities {
    // Just return a default one, since Zig doesn't have context.Context easily.
    // In a real server, it would be part of the Server state.
    return .{};
}

pub const CodeActionKindSourceRemoveUnusedImports: []const u8 = "source.removeUnusedImports";
pub const CodeActionKindSourceSortImports: []const u8 = "source.sortImports";
