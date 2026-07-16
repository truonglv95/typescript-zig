const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestFindAllRefsOfConstructor_multipleFiles" {
    const content =
        \\// @Filename: f.ts
        \\class A {
        \\    /*aCtr*/constructor(s: string) {}
        \\}
        \\class B extends A { }
        \\export { A, B };
        \\// @Filename: a.ts
        \\import { A as A1 } from "./f";
        \\const a1 = new A1("a1");
        \\export default class extends A1 { }
        \\export { B as B1 } from "./f";
        \\// @Filename: b.ts
        \\import B, { B1 } from "./a";
        \\const d = new B("b");
        \\const d1 = new B1("b1");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    // try f.VerifyBaselineFindAllReferences(undefined, "aCtr");
}

test "TestIsDefinitionSingleImport" {
    const content =
        \\// @filename: a.ts
        \\export function /*1*/f() {}
        \\// @filename: b.ts
        \\import { /*2*/f } from "./a";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestSmartSelection_bindingPatterns" {
    const content =
        \\const { /*1*/x, y: /*2*/a, .../*3*/zs = {} } = {};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSelectionRanges(undefined);
}

test "TestFindAllRefsForUMDModuleAlias1" {
    const content =
        \\// @Filename: 0.d.ts
        \\export function doThing(): string;
        \\export function doTheOtherThing(): void;
        \\/*1*/export as namespace /*2*/myLib;
        \\// @Filename: 1.ts
        \\/// <reference path="0.d.ts" />
        \\/*3*/myLib.doThing();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestRenameForDefaultExport05" {
    const content =
        \\// @Filename: foo.ts
        \\export default class DefaultExportedClass {
        \\}
        \\/*
        \\ *  Commenting DefaultExportedClass
        \\ */
        \\
        \\var x: /**/[|DefaultExportedClass|];
        \\
        \\var y = new DefaultExportedClass;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyRenameSucceeded(undefined, null );
}

test "TestCodeFixMissingTypeAnnotationOnExports15" {
    const content =
        \\// @stableTypeOrdering: true
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\function foo() {
        \\    return { x: 1, y: 1 } as const;
        \\}
        \\export const { x, y = 0 } = foo();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Extract binding expressions to variable",
        .NewFileContent = "function foo() {\n    return { x: 1, y: 1 } as const;\n}\nconst dest = foo();\nexport const x: 1 = dest.x;\nconst temp = dest.y;\nexport const y: 0 | 1 = temp === undefined ? 0 : dest.y;",
        .Index = 0,
    });
}

test "TestGetEditsForFileRename_tsconfig_include_add" {
    const content =
        \\// @Filename: /src/tsconfig.json
        \\{
        \\    "include": ["dir"],
        \\}
        \\// @Filename: /src/dir/a.ts
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyWillRenameFilesEdits(undefined, "/src/dir/a.ts", "/src/newDir/b.ts", .{
//         .@"/src/tsconfig.json" = "{\n    \"include\": [\"dir\", \"newDir/b.ts\"],\n}",
//     }, null );
}

test "TestCompletionsJsPropertyAssignment" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\/** @type {{ p: "x" | "y" }} */
        \\const x = { p: "x"  };
        \\x.p = "[|/**/|]";
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
//             .Exact = &.{
//                 &.{
//                     .Label = "x",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "x",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "y",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "y",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestFailureToImplementClass" {
    const content =
        \\interface IExec {
        \\    exec: (filename: string, cmdLine: string) => boolean;
        \\}
        \\class /*1*/NodeExec/*2*/ implements IExec { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyErrorExistsBetweenMarkers(undefined, "1", "2");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestCompletionListAfterRegularExpressionLiteral02" {
    const content =
        \\let v = 100;
        \\let x = /absidey//**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "", null);
}

