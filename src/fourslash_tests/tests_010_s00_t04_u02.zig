const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestGetOccurrencesOfAnonymousFunction2" {
    const content =
        \\//global foo definition
        \\function foo() {}
        \\
        \\(function f/*local*/oo(): number {
        \\    return foo(); // local foo reference
        \\})
        \\//global foo references
        \\fo/*global*/o();
        \\var f = foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , "local", "global");
}

test "TestGoToDefinitionOverloadsInMultiplePropertyAccesses" {
    const content =
        \\namespace A {
        \\    export namespace B {
        \\        export function f(value: number): void;
        \\        export function /*1*/f(value: string): void;
        \\        export function f(value: number | string) {}
        \\    }
        \\}
        \\A.B.[|/*2*/f|]("");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "2");
}

