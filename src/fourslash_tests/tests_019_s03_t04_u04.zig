const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionPropertyShorthandForObjectLiteral5" {
    const content =
        \\// @module: esnext
        \\// @Filename: /a.ts
        \\export const exportedConstant = 0;
        \\// @Filename: /b.ts
        \\const foo = 'foo'
        \\const obj = { exp/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "exportedConstant",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./a",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
}

test "TestCompletionsImport_require_addToExisting" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\const x = 0;
        \\function f() {}
        \\module.exports = { x, f };
        \\// @Filename: /b.js
        \\const { f } = require("./a");
        \\
        \\x/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "x",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./a",
//                         },
//                     },
//                     .Detail =              undefined("(alias) const x: 0\nimport x"),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "x",
//         .Source =      "./a",
//         .Description = "Update import from \"./a\"",
//         .NewFileContent = undefined("const { f, x } = require(\"./a\");\n\nx"),
//     });
}

