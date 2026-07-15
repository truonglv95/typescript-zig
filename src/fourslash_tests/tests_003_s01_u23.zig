const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestNavigationBarFunctionLikePropertyAssignments" {
    const content =
        \\var functions = {
        \\    a: 0,
        \\    b: function () { },
        \\    c: function x() { },
        \\    d: () => { },
        \\    e: y(),
        \\    f() { }
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestQuickInfoDisplayPartsLiteralLikeNames01" {
    const content =
        \\class C {
        \\    public /*1*/1() { }
        \\    private /*2*/Infinity() { }
        \\    protected /*3*/NaN() { }
        \\    static /*4*/"stringLiteralName"() { }
        \\    method() {
        \\        this[/*5*/1]();
        \\        this[/*6*/"1"]();
        \\        this./*7*/Infinity();
        \\        this[/*8*/"Infinity"]();
        \\        this./*9*/NaN();
        \\        C./*10*/stringLiteralName();
        \\    }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

