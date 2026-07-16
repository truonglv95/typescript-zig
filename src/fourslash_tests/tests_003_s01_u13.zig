const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestQuickInfoOnGenericClass" {
    const content =
        \\class Contai/**/ner<T> {
        \\    x: T;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "class Container<T>", "");
}

test "TestUnclosedStringLiteralAutoformating" {
    const content =
        \\var x = /*1*/"asd/*2*/
        \\class Foo {
        \\    /**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "}");
    try f.VerifyCurrentLineContent(undefined, "}");
}

