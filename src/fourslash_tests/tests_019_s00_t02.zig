const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestFormatOnSemiColonAfterBreak" {
    const content =
        \\for (var a in b) {
        \\break/**/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, ";");
    _ = f.VerifyCurrentLineContent(undefined, "    break;");
}

test "TestGoToDefinitionImportedNames8" {
    const content =
        \\// @allowjs: true
        \\// @Filename: b.js
        \\import { [|/*classAliasDefinition*/Class|] } from "./a";
        \\// @Filename: a.js
        \\class /*classDefinition*/Class {
        \\    private f;
        \\}
        \\ export { Class };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "classAliasDefinition");
}

test "TestCallSignatureHelp" {
    const content =
        \\interface C {
        \\   (): number;
        \\}
        \\var c: C;
        \\c(/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifySignatureHelp(undefined, .{.Text = "c(): number"});
}

test "TestCallHierarchyConstNamedClassExpression" {
    const content =
        \\function foo() {
        \\    new Bar();
        \\}
        \\
        \\const /**/Bar = class {
        \\    constructor() {
        \\        baz();
        \\    }
        \\}
        \\
        \\function baz() {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyBaselineCallHierarchy(undefined);
}

test "TestRenameModuleExportsProperties2" {
    const content =
        \\[|class [|{| "contextRangeIndex": 0 |}A|] {}|]
        \\module.exports = { B: [|A|] }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[2]);
}

test "TestReferencesForMergedDeclarations" {
    const content =
        \\/*1*/interface /*2*/Foo {
        \\}
        \\
        \\/*3*/module /*4*/Foo {
        \\    export interface Bar { }
        \\}
        \\
        \\/*5*/function /*6*/Foo(): void {
        \\}
        \\
        \\var f1: /*7*/Foo.Bar;
        \\var f2: /*8*/Foo;
        \\/*9*/Foo.bind(this);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8", "9");
}

test "TestGoToDefinitionShorthandProperty05" {
    const content =
        \\interface Foo {
        \\    /*3*/foo(): void
        \\}
        \\const /*2*/foo = 1;
        \\let x: Foo = {
        \\    [|f/*1*/oo|]
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestCompletionsImport_umdModules3_script" {
    const content =
        \\// @filename: /package.json
        \\{ "dependencies": { "@types/classnames": "*" } }
        \\// @filename: /tsconfig.json
        \\{ "compilerOptions": { "module": "es2015", "types": ["*"] }}
        \\// @filename: /node_modules/@types/classnames/package.json
        \\{ "name": "@types/classnames", "types": "index.d.ts" }
        \\// @filename: /node_modules/@types/classnames/index.d.ts
        \\declare const classNames: () => string;
        \\export = classNames;
        \\export as namespace classNames;
        \\// @filename: /SomeReactComponent.tsx
        \\
        \\const el1 = <div className={class/*1*/}>foo</div>
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =               "classNames",
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestGetJavaScriptQuickInfo6" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\/** @type {function(this:number)} */
        \\function f() { /**/this }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "number", "");
}

test "TestGoToTypeDefinitionPrimitives" {
    const content =
        \\// @Filename: module1.ts
        \\var w: {a: number};
        \\var x = "string";
        \\var y: number | string;
        \\var z; // any
        \\// @Filename: module2.ts
        \\w./*reference1*/a;
        \\/*reference2*/x;
        \\/*reference3*/y;
        \\/*reference4*/y;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToTypeDefinition(undefined, "reference1", "reference2", "reference3", "reference4");
}

