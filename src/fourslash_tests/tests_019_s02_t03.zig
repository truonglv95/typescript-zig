const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestSignatureHelpTaggedTemplatesNegatives1" {
    const content =
        \\function f(templateStrings, x, y, z) { return 10; }
        \\function g(templateStrings, x, y, z) { return ""; }
        \\
        \\/*1*/f/*2*/ /*3*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyNoSignatureHelpForMarkers(undefined, f.MarkerNames());
}

test "TestImportNameCodeFix_jsExtension" {
    const content =
        \\// @moduleResolution: bundler
        \\// @noLib: true
        \\// @jsx: preserve
        \\// @Filename: /a.ts
        \\export function a() {}
        \\// @Filename: /b.ts
        \\export function b() {}
        \\// @Filename: /c.tsx
        \\export function c() {}
        \\// @Filename: /c.ts
        \\import * as g from "global"; // Global imports skipped
        \\import { a } from "./a.js";
        \\import { a as a2 } from "./a"; // Ignored, only the first relative import is considered
        \\b; c;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/c.ts");
    try f.VerifyCodeFixAll(undefined, .{
        .FixID = "fixMissingImport",
        .NewFileContent = "import * as g from \"global\"; // Global imports skipped\nimport { a } from \"./a.js\";\nimport { a as a2 } from \"./a\"; // null, only the first relative import is considered\nimport { b } from \"./b.js\";\nimport { c } from \"./c.jsx\";\nb; c;",
    });
}

test "TestCompletionListInstanceProtectedMembers" {
    const content =
        \\class Base {
        \\    private privateMethod() { }
        \\    private privateProperty;
        \\
        \\    protected protectedMethod() { }
        \\    protected protectedProperty;
        \\
        \\    public publicMethod() { }
        \\    public publicProperty;
        \\
        \\    protected protectedOverriddenMethod() { }
        \\    protected protectedOverriddenProperty;
        \\
        \\    test() {
        \\        this./*1*/;
        \\
        \\        var b: Base;
        \\        var c: C1;
        \\
        \\        b./*2*/;
        \\        c./*3*/;
        \\    }
        \\}
        \\
        \\class C1 extends Base {
        \\    protected  protectedOverriddenMethod() { }
        \\    protected  protectedOverriddenProperty;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "2"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "privateMethod",
//                 "privateProperty",
//                 "protectedMethod",
//                 "protectedProperty",
//                 "publicMethod",
//                 "publicProperty",
//                 "protectedOverriddenMethod",
//                 "protectedOverriddenProperty",
//                 "test",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "privateMethod",
//                 "privateProperty",
//                 "protectedMethod",
//                 "protectedProperty",
//                 "publicMethod",
//                 "publicProperty",
//                 "test",
//             },
//         },
//     });
}

test "TestGoToDefinitionTypeOnlyImport" {
    const content =
        \\// @Filename: /a.ts
        \\enum /*1*/SyntaxKind { SourceFile }
        \\export type { SyntaxKind }
        \\// @Filename: /b.ts
        \\ export type { SyntaxKind } from './a';
        \\// @Filename: /c.ts
        \\import type { SyntaxKind } from './b';
        \\let kind: [|/*2*/SyntaxKind|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "2");
}

test "TestImportNameCodeFix_require" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: foo.js
        \\module.exports = function foo() {}
        \\// @Filename: utils.js
        \\function util1() {}
        \\function util2() {}
        \\module.exports = { util1, util2 };
        \\// @Filename: blah.js
        \\export default class Blah {}
        \\// @Filename: index.js
        \\foo();
        \\util1();
        \\util2();
        \\new Blah;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "index.js");
    try f.VerifyCodeFixAll(undefined, .{
        .FixID = "fixMissingImport",
        .NewFileContent = "const { default: Blah } = require(\"./blah\");\nconst foo = require(\"./foo\");\nconst { util1, util2 } = require(\"./utils\");\n\nfoo();\nutil1();\nutil2();\nnew Blah;",
    });
}

test "TestAutoImportRootDirs" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "module": "commonjs",
        \\        "rootDirs": [".", "./some/other/root"]
        \\    }
        \\}
        \\// @Filename: /some/other/root/types.ts
        \\export type Something = {};
        \\// @Filename: /index.ts
        \\const s: Something/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"./types"}, null );
}

test "TestJsdocLink2" {
    const content =
        \\// @Filename: jsdocLink2.ts
        \\class C {
        \\}
        \\// @Filename: script.ts
        \\/**
        \\ * {@link C}
        \\ * @wat Makes a {@link C}. A default one.
        \\ * {@link C()}
        \\ * {@link C|postfix text}
        \\ * {@link unformatted postfix text}
        \\ * @see {@link C} its great
        \\ */
        \\function /**/CC() {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestRenameModuleToVar" {
    const content =
        \\interface IMod {
        \\    y: number;
        \\}
        \\declare module/**/ X: IMod;// {
        \\//    export var y: numb;
        \\var y: number;
        \\namespace Y {
        \\    var z = y + 5;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Backspace(undefined, 6);
    _ = f.Insert(undefined, "var");
    try f.VerifyNoErrors(undefined);
}

test "TestImportNameCodeFix_typeUsedAsValue" {
    const content =
        \\// @Filename: /a.ts
        \\export class ReadonlyArray<T> {}
        \\// @Filename: /b.ts
        \\[|new ReadonlyArray<string>();|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { ReadonlyArray } from \"./a\";\n\nnew ReadonlyArray<string>();",
    }, null );
}

test "TestCodeFixMissingTypeAnnotationOnExports50_generics_with_default" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @lib: es2015
        \\let x: Iterator<number>;
        \\export const y = x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add annotation of type 'Iterator<number>'",
        .NewFileContent = "let x: Iterator<number>;\nexport const y: Iterator<number> = x;",
        .Index = 0,
    });
}

