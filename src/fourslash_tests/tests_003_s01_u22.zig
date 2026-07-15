const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestImportStatementCompletions_pnpm1" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{ "compilerOptions": { "module": "commonjs", "types": ["*"], "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/node_modules/.pnpm/@types+react@17.0.7/node_modules/@types/react/index.d.ts
        \\export declare function Component(): void;
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\[|import Com/**/|]
        \\// @link: /home/src/workspaces/project/node_modules/.pnpm/@types+react@17.0.7/node_modules/@types/react -> /home/src/workspaces/project/node_modules/@types/react
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "Component",
//                     .InsertText = undefined("import { Component$1 } from \"react\";"),
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "react",
//                         },
//                     },
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "Component",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestCodeFixClassImplementDefaultClass" {
    const content =
        \\interface I { x: number; }
        \\export default class implements I {[| |]}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "interface I { x: number; }\nexport default class implements I {\n    x: number;\n}",
        .Index = 0,
    });
}

