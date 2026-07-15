const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestFindAllRefsIndexedAccessTypes" {
    const content =
        \\interface I {
        \\    /*1*/0: number;
        \\    /*2*/s: string;
        \\}
        \\interface J {
        \\    a: I[/*3*/0],
        \\    b: I["/*4*/s"],
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestFindAllReferencesFromLinkTagReference3" {
    const content =
        \\// @filename: a.ts
        \\interface Foo {
        \\    foo: E.Foo;
        \\}
        \\// @Filename: b.ts
        \\enum E {
        \\    /** {@link /**/Foo} */
        \\    Foo
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "");
}

