const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestQuickInfoForJSDocWithUnresolvedHttpLinks" {
    const content =
        \\// @checkJs: true
        \\// @filename: quickInfoForJSDocWithHttpLinks.js
        \\/** @see {@link https://hva} */
        \\var /*5*/see2 = true
        \\
        \\/** {@link https://hvaD} */
        \\var /*6*/see3 = true
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestGetDeclarationDiagnostics" {
    const content =
        \\// @strict: false
        \\// @declaration: true
        \\// @outFile: true
        \\// @Filename: inputFile1.ts
        \\namespace m {
        \\   export function foo() {
        \\       class C implements I { private a; }
        \\       interface I { }
        \\       return C;
        \\   }
        \\} /*1*/
        \\// @Filename: input2.ts
        \\var x = "hello world"; /*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 0);
}

