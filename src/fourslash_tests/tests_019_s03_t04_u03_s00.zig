const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestStringPropertyNames1" {
    const content =
        \\export interface Album {
        \\   "artist": number;
        \\}
        \\var a: Album;
        \\var /**/x = a['artist'];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "var x: number", "");
}

