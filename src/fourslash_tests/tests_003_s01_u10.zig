const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestOutlineSpansBlockCommentsWithoutStatements" {
    const content =
        \\[|/*
        \\/ * Some text
        \\  */|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOutliningSpans(undefined);
}

test "TestDocumentHighlightJSDocTypedef" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: index.js
        \\/**
        \\ * @typedef {{
        \\ *   [|foo|]: string;
        \\ *   [|bar|]: number;
        \\ * }} Foo
        \\ */
        \\
        \\/** @type {Foo} */
        \\const x = {
        \\  [|foo|]: "",
        \\  [|bar|]: 42,
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

