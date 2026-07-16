const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestFindAllRefsInClassExpression" {
    const content =
        \\interface I { /*0*/boom(): void; }
        \\new class C implements I {
        \\   /*1*/boom(){}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "0", "1");
}

test "TestGoToDefinitionOverriddenMember4" {
    const content =
        \\// @noImplicitOverride: true
        \\class Foo {
        \\    /*2*/m() {}
        \\}
        \\function f () {
        \\    return class extends Foo {
        \\        [|/*1*/override|] m() {}
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

