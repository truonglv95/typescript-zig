const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestRenameDestructuringDeclarationInFor" {
    const content =
        \\interface I {
        \\    [|[|{| "contextRangeIndex": 0 |}property1|]: number;|]
        \\    property2: string;
        \\}
        \\var elems: I[];
        \\
        \\var p2: number, property1: number;
        \\for ([|let { [|{| "contextRangeIndex": 2 |}property1|]: p2 } = elems[0]|]; p2 < 100; p2++) {
        \\}
        \\for ([|let { [|{| "contextRangeIndex": 4 |}property1|] } = elems[0]|]; p2 < 100; p2++) {
        \\    [|property1|] = p2;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[3], f.Ranges()[5], f.Ranges()[6]);
}

