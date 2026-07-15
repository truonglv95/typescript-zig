const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCodeFixMissingTypeAnnotationOnExports43_expando_functions_5" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @lib: es2019
        \\// @Filename: /code.ts
        \\function foo(): void {}
        \\// x already exists, so do not generate code for 'x'
        \\foo.x = 1;
        \\foo.y = 1;
        \\namespace foo {
        \\  export let x = 42;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Annotate types of properties expando function in a namespace",
        .NewFileContent = "function foo(): void {}\ndeclare namespace foo {\n    export var y: number;\n}\n// x already exists, so do not generate code for 'x'\nfoo.x = 1;\nfoo.y = 1;\nnamespace foo {\n  export let x = 42;\n}",
        .Index = 0,
    });
}

test "TestGoToDefinitionSwitchCase1" {
    const content =
        \\switch (null ) {
        \\  [|/*start*/case|] null: break;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "start");
}

test "TestQuickInfoJsDocAlias" {
    const content =
        \\// @filename: /a.d.ts
        \\/** docs - type T */
        \\export type T = () => void;
        \\/**
        \\ * docs - const A: T
        \\ */
        \\export declare const A: T;
        \\// @filename: /b.ts
        \\import { A } from "./a";
        \\A/**/()
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestSemanticClassification2" {
    const content =
        \\interface /*0*/Thing {
        \\    toExponential(): number;
        \\}
        \\
        \\var Thing = 0;
        \\Thing.toExponential();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "interface.declaration", .Text = "Thing"},
//         .{.Type = "method.declaration", .Text = "toExponential"},
//         .{.Type = "variable.declaration", .Text = "Thing"},
//         .{.Type = "variable", .Text = "Thing"},
//         .{.Type = "method.defaultLibrary", .Text = "toExponential"},
//     });
}

test "TestGoToDefinitionJsModuleExports" {
    const content =
        \\// @allowJs: true
        \\// @Filename: foo.js
        \\x./*def*/test = () => { }
        \\x.[|/*ref*/test|]();
        \\x./*defFn*/test3 = function () { }
        \\x.[|/*refFn*/test3|]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "ref", "refFn");
}

test "TestFindReferencesAcrossMultipleProjects" {
    const content =
        \\//@Filename: a.ts
        \\/*1*/var /*2*/x: number;
        \\//@Filename: b.ts
        \\/// <reference path="a.ts" />
        \\/*3*/x++;
        \\//@Filename: c.ts
        \\/// <reference path="a.ts" />
        \\/*4*/x++;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestSignatureHelpSimpleFunctionCall" {
    const content =
        \\// Simple function test
        \\function functionCall(str: string, num: number) {
        \\}
        \\functionCall(/*functionCall1*/);
        \\functionCall("", /*functionCall2*/1);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "functionCall1");
    // f.VerifySignatureHelp(undefined, .{.Text = "functionCall(str: string, num: number): void", .ParameterName = "str", .ParameterSpan = "str: string"});
    _ = f.GoToMarker(undefined, "functionCall2");
    // f.VerifySignatureHelp(undefined, .{.Text = "functionCall(str: string, num: number): void", .ParameterName = "num", .ParameterSpan = "num: number"});
}

test "TestCompletionListAfterFunction3" {
    const content =
        \\// Outside the function expression
        \\var x1 = (a: number) => { }/*1*/;
        \\
        \\var x2 = (b: number) => {/*2*/ };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Excludes = &.{
//                 "a",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "b",
//             },
//         },
//     });
}

test "TestDocumentHighlightsInvalidModifierLocations" {
    const content =
        \\class C {
        \\    m([|readonly|] p) {}
        \\}
        \\function f([|readonly|] p) {}
        \\
        \\class D {
        \\    m([|public|] p) {}
        \\}
        \\function g([|public|] p) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestImportCompletionsPackageJsonExportsSpecifierEndsInTs" {
    const content =
        \\// @module: node18
        \\// @Filename: /node_modules/pkg/package.json
        \\{
        \\    "name": "pkg",
        \\    "version": "1.0.0",
        \\    "exports": {
        \\      "./something.ts": "./a.js"
        \\    }
        \\ }
        \\// @Filename: /node_modules/pkg/a.d.ts
        \\export function foo(): void;
        \\// @Filename: /package.json
        \\{
        \\    "dependencies": {
        \\       "pkg": "*"
        \\    }
        \\ }
        \\// @Filename: /index.ts
        \\import {} from "pkg//*1*/";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "something.ts",
//             },
//         },
//     });
}

