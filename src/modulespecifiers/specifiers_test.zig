const std = @import("std");
const testing = std.testing;
const specifiers = @import("specifiers.zig");
const util = @import("util.zig");

test "GetEachFileNameOfModule" {
    // Stub
}

test "GetEachFileNameOfModuleWithSymlinks" {
    // Stub
}

test "ContainsNodeModules" {
    try testing.expect(specifiers.containsNodeModules("/project/node_modules/foo/index.js"));
    try testing.expect(!specifiers.containsNodeModules("/project/src/index.js"));
}

test "ContainsIgnoredPath" {
    // We didn't export containsIgnoredPath in util/specifiers directly, it was local in go
}

test "TryGetRealFileNameForNonJSDeclarationFileName" {
    const allocator = testing.allocator;
    if (try util.tryGetRealFileNameForNonJSDeclarationFileName(allocator, "foo.d.json.ts")) |res| {
        try testing.expectEqualStrings("foo.json", res);
        allocator.free(res);
    }
}

test "TryGetModuleNameFromExportsOrImports" {
    // Stub
}
