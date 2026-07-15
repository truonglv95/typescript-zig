const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestImportNameCodeFixDefaultExport3" {
    const content =
        \\// @Filename: /foo-bar/index.ts
        \\export default 0;
        \\// @Filename: /b.ts
        \\[|foo/**/Bar|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import fooBar from \"./foo-bar\";\n\nfooBar",
    }, null );
}

test "TestImportStatementCompletions4" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\import Foo /*a*/
        \\
        \\function fromBar() {}
        \\// @Filename: /b.jsx
        \\import Foo /*b*/
        \\
        \\function fromBar() {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"a", "b"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =    "from",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

