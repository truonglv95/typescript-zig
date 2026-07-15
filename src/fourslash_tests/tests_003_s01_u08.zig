const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestFormatAsyncKeyword" {
    const content =
        \\/*1*/let x = async         () => 1;
        \\/*2*/let y = async() => 1;
        \\/*3*/let z = async    function   () { return 1; };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "let x = async () => 1;");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "let y = async () => 1;");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "let z = async function() { return 1; };");
}

test "TestFindAllRefsImportEqualsJsonFile" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @resolveJsonModule: true
        \\// @module: commonjs
        \\// @Filename: /a.ts
        \\import /*0*/j = require("/*1*/./j.json");
        \\/*2*/j;
        \\// @Filename: /b.js
        \\const /*3*/j = require("/*4*/./j.json");
        \\/*5*/j;
        \\// @Filename: /j.json
        \\/*6*/{ "x": 0 }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyBaselineFindAllReferences(undefined, "0", "2", "1", "4", "3", "5", "6");
}

