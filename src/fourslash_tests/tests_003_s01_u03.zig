const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestJsdocTypedefTagServices" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\/**
        \\ * Doc comment
        \\ * [|@typedef /*def*/[|{| "contextRangeIndex": 0 |}Product|]
        \\ * @property {string} title
        \\ |]*/
        \\/**
        \\ * @type {[|/*use*/Product|]}
        \\ */
        \\const product = null;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "use", "type Product = {\n    title: string;\n}", "Doc comment");
    // try f.VerifyBaselineFindAllReferences(undefined, "use", "def");
    // try f.VerifyBaselineRename(undefined, null , ToAny(f.Ranges()[1:]));
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()[1:]));
    // try f.VerifyBaselineGoToDefinition(undefined, true, "use");
}

test "TestRenameNamespace" {
    const content =
        \\namespace /**/NS {
        \\    export const enum E {
        \\        A = 'a'
        \\    }
        \\}
        \\
        \\const a: NS.E = NS.E.A;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , "");
}

