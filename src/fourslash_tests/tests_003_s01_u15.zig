const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestGetOccurrencesConst01" {
    const content =
        \\[|const|] enum E1 {
        \\    v1,
        \\    v2
        \\}
        \\
        \\/*2*/const c = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
    // try f.VerifyBaselineDocumentHighlights(undefined, null , "2");
}

test "TestCallHierarchyDecorator" {
    const content =
        \\// @experimentalDecorators: true
        \\@bar
        \\class Foo {
        \\}
        \\
        \\function /**/bar() {
        \\    baz();
        \\}
        \\
        \\function baz() {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifyBaselineCallHierarchy(undefined);
}

