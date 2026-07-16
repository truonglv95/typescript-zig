const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestIncrementalJsDocAdjustsLengthsRight" {
    const content =
        \\// @noLib: true
        \\
        \\/**
        \\ * Pad 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "th\n@");
}

test "TestAutoImportProvider6" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{ "compilerOptions": { "module": "commonjs", "lib": ["es2019"], "types": ["*"] } }
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{ "dependencies": { "antd": "*", "react": "*" } }
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/react/index.d.ts
        \\export declare function Component(): void;
        \\// @Filename: /home/src/workspaces/project/node_modules/antd/index.d.ts
        \\import "react";
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\Component/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =               "Component",
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "react",
//                         },
//                     },
//                     .SortText = undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
}

test "TestRenamePrivateMethod" {
    const content =
        \\class Foo {
        \\   [|[|{| "contextRangeIndex": 0 |}#foo|]() { }|]
        \\   callFoo() {
        \\       return this.[|#foo|]();
        \\   }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , ToAny(f.GetRangesByText().Get("#foo")));
}

test "TestSmartSelection_JSDocTags13" {
    const content =
        \\let a;
        \\let b: {
        \\    /** Comment */ /*1*/p0: number
        \\    /** Comment */ /*2*/p1: number
        \\    /** Comment */ /*3*/p2: number
        \\};
        \\let c;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSelectionRanges(undefined);
}

test "TestGoToDefinitionModifiers" {
    const content =
        \\// @Filename: /a.ts
        \\/*export*/export class A/*A*/ {
        \\
        \\    /*private*/private z/*z*/: string;
        \\
        \\    /*readonly*/readonly x/*x*/: string;
        \\
        \\    /*async*/async a/*a*/() {  }
        \\
        \\    /*override*/override b/*b*/() {}
        \\
        \\    /*public1*/public/*public2*/ as/*multipleModifiers*/ync c/*c*/() { }
        \\}
        \\
        \\exp/*exportFunction*/ort function foo/*foo*/() { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "export", "A", "private", "z", "readonly", "x", "async", "a", "override", "b", "public1", "public2", "multipleModifiers", "c", "exportFunction", "foo");
}

test "TestFormatSpaceAfterImplementsExtends" {
    const content =
        \\class C1 implements Array<string>{
        \\}
        \\
        \\class C2 implements Number{
        \\}
        \\
        \\class C3 extends Array<string>{
        \\}
        \\
        \\class C4 extends Number{
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "class C1 implements Array<string> {\n}\n\nclass C2 implements Number {\n}\n\nclass C3 extends Array<string> {\n}\n\nclass C4 extends Number {\n}");
}

test "TestReferencesForStringLiteralPropertyNames5" {
    const content =
        \\var x = { "/*1*/someProperty": 0 }
        \\x["/*2*/someProperty"] = 3;
        \\x.someProperty = 5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestImportNameCodeFix_avoidRelativeNodeModules" {
    const content =
        \\// @Filename: /a/index.d.ts
        \\// @Symlink: /b/node_modules/a/index.d.ts
        \\// @Symlink: /c/node_modules/a/index.d.ts
        \\export const a: number;
        \\// @Filename: /b/index.ts
        \\// @Symlink: /c/node_modules/b/index.d.ts
        \\import { a } from 'a'
        \\export const b: number;
        \\// @Filename: /c/a_user.ts
        \\import { a } from "a";
        \\// @Filename: /c/foo.ts
        \\[|import { b } from "b";
        \\a;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/c/foo.ts");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { a } from \"a\";\nimport { b } from \"b\";\na;",
    }, null );
}

test "TestQuickinfoVerbosityIndexedAccessType" {
    const content =
        \\interface T2 {
        \\    "string key": string;
        \\    "number key": number;
        \\    "any key": string | number | symbol;
        \\}
        \\type K2 = "string key" | "any key";
        \\function fn2<T extends T2>(obj: T, key: keyof T) {
        \\    const value/*v1*/: T[K2] = undefined as any;
        \\}
        \\function fn3<K extends keyof T2>(obj: T2, key: K) {
        \\    const value/*v2*/: T2[K] = undefined as any;;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"v1" = .{0, 1}, .@"v2" = .{0, 1}});
}

test "TestImportNameCodeFixDefaultExport4" {
    const content =
        \\// @Filename: /foo.ts
        \\const a = () => {};
        \\export default a;
        \\// @Filename: /test.ts
        \\[|foo|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/test.ts");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import foo from \"./foo\";\n\nfoo",
    }, null );
}

test "TestReferencesForImports" {
    const content =
        \\declare module "jquery" {
        \\    function $(s: string): any;
        \\    export = $;
        \\}
        \\/*1*/import /*2*/$ = require("jquery");
        \\/*3*/$("a");
        \\/*4*/import /*5*/$ = require("jquery");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5");
}

test "TestImportNameCodeFixUMDGlobal1" {
    const content =
        \\// @AllowSyntheticDefaultImports: false
        \\// @Module: esnext
        \\// @Filename: a/f1.ts
        \\[|import { bar } from "./foo";
        \\
        \\export function test() { };
        \\bar1/*0*/.bar();|]
        \\// @Filename: a/foo.d.ts
        \\export declare function bar(): number;
        \\export as namespace bar1; 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import * as bar1 from \"./foo\";\nimport { bar } from \"./foo\";\n\nexport function test() { };\nbar1.bar();",
    }, null );
}

test "TestSignatureHelpAtEOF" {
    const content =
        \\function Foo(arg1: string, arg2: string) {
        \\}
        \\
        \\Foo(/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifySignatureHelp(undefined, .{.Text = "Foo(arg1: string, arg2: string): void", .ParameterCount = 2, .ParameterName = "arg1", .ParameterSpan = "arg1: string"});
}

test "TestFunctionProperty" {
    const content =
        \\var a = {
        \\    x(a: number) { }
        \\};
        \\
        \\var b = {
        \\    x: function (a: number) { }
        \\};
        \\
        \\var c = {
        \\    x: (a: number) => { }
        \\};
        \\a.x(/*signatureA*/1);
        \\b.x(/*signatureB*/1);
        \\c.x(/*signatureC*/1);
        \\a./*completionA*/;
        \\b./*completionB*/;
        \\c./*completionC*/;
        \\a./*quickInfoA*/x;
        \\b./*quickInfoB*/x;
        \\c./*quickInfoC*/x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "signatureA");
    // try f.VerifySignatureHelp(undefined, .{.Text = "x(a: number): void"});
    _ = f.GoToMarker(undefined, "signatureB");
    // try f.VerifySignatureHelp(undefined, .{.Text = "x(a: number): void"});
    _ = f.GoToMarker(undefined, "signatureC");
    // try f.VerifySignatureHelp(undefined, .{.Text = "x(a: number): void"});
    // f.VerifyCompletions(undefined, "completionA", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "x",
//                     .Detail = undefined("(method) x(a: number): void"),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"completionB", "completionC"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "x",
//                     .Detail = undefined("(property) x: (a: number) => void"),
//                 },
//             },
//         },
//     });
    try f.VerifyQuickInfoAt(undefined, "quickInfoA", "(method) x(a: number): void", "");
    try f.VerifyQuickInfoAt(undefined, "quickInfoB", "(property) x: (a: number) => void", "");
    try f.VerifyQuickInfoAt(undefined, "quickInfoC", "(property) x: (a: number) => void", "");
}

test "TestGetOccurrencesLoopBreakContinue5" {
    const content =
        \\var arr = [1, 2, 3, 4];
        \\label1: for (var n in arr) {
        \\    break;
        \\    continue;
        \\    break label1;
        \\    continue label1;
        \\
        \\    label2: for (var i = 0; i < arr[n]; i++) {
        \\        break label1;
        \\        continue label1;
        \\
        \\        break;
        \\        continue;
        \\        break label2;
        \\        continue label2;
        \\
        \\        function foo() {
        \\            label3: while (true) {
        \\                break;
        \\                continue;
        \\                break label3;
        \\                continue label3;
        \\
        \\                // these cross function boundaries
        \\                break label1;
        \\                continue label1;
        \\                break label2;
        \\                continue label2;
        \\
        \\                label4: do {
        \\                    break;
        \\                    continue;
        \\                    break label4;
        \\                    continue label4;
        \\
        \\                    break label3;
        \\                    continue label3;
        \\
        \\                    switch (10) {
        \\                        case 1:
        \\                        case 2:
        \\                            break;
        \\                            break label4;
        \\                        default:
        \\                            continue;
        \\                    }
        \\
        \\                    // these cross function boundaries
        \\                    break label1;
        \\                    continue label1;
        \\                    break label2;
        \\                    continue label2;
        \\                    () => { break; }
        \\                } while (true)
        \\            }
        \\        }
        \\    }
        \\}
        \\
        \\label5: [|while|] (true) [|br/**/eak|] label5;
        \\
        \\label7: while (true) continue label5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestRename01" {
    const content =
        \\// @lib: es5
        \\///<reference path="./Bar.ts" />
        \\[|function [|{| "contextRangeIndex": 0 |}Bar|]() {
        \\    // This is a reference to [|Bar|] in a comment.
        \\    "this is a reference to [|Bar|] in a string"
        \\}|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1]);
}

test "TestFormatRemoveNewLineAfterOpenBrace" {
    const content =
        \\function foo()
        \\{
        \\}
        \\if (true)
        \\{
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "function foo() {\n}\nif (true) {\n}");
}

test "TestJsdocDeprecated_suggestion15" {
    const content =
        \\// @module: esnext
        \\// @filename: /a.ts
        \\export const a = 1;
        \\export const b = 1;
        \\// @filename: /b.ts
        \\export {
        \\    /** @deprecated a is deprecated */
        \\    a
        \\} from "./a";
        \\// @filename: /c.ts
        \\export {
        \\    a
        \\} from "./b";
        \\// @filename: /d.ts
        \\import { [|a|] } from "./c";
        \\[|a|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/d.ts");
    // try f.VerifySuggestionDiagnostics(undefined, []*.{
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'a' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[0].LSRange,
//         },
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'a' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[1].LSRange,
//         },
//     });
}

test "TestGetJavaScriptCompletions18" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: file.js
        \\/**
        \\  * @param {number} a
        \\  * @param {string} b
        \\*/
        \\exports.foo = function(a, b) {
        \\    a/*a*/;
        \\    b/*b*/
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "a");
    _ = f.Insert(undefined, ".");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "toFixed",
//                     .Kind =  undefined(lsproto.CompletionItemKindMethod),
//                 },
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "b");
    _ = f.Insert(undefined, ".");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "substring",
//                     .Kind =  undefined(lsproto.CompletionItemKindMethod),
//                 },
//             },
//         },
//     });
}

test "TestCompletionListInObjectLiteralPropertyAssignment" {
    const content =
        \\var foo;
        \\interface I {
        \\    metadata: string;
        \\    wat: string;
        \\}
        \\var x: I = {
        \\    metadata: "/*1*/
        \\}
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
//             .Exact = &.{},
//         },
//     });
}

test "TestCodeFixMissingTypeAnnotationOnExports42_static_readonly_class_symbol" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @lib: es2019
        \\// @Filename: /code.ts
        \\class A {
        \\    static readonly p1 = Symbol();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add annotation of type 'unique symbol'",
        .NewFileContent = "class A {\n    static readonly p1: unique symbol = Symbol();\n}",
        .Index = 0,
    });
}

test "TestGoToDefinitionOverriddenMember7" {
    const content =
        \\// @noImplicitOverride: true
        \\class Foo {
        \\    [|/*1*/override|] m() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestFindAllReferencesJsDocTypeLiteral" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: foo.js
        \\/**
        \\ * @param {object} o - very important!
        \\ * @param {string} o.x - a thing, its ok
        \\ * @param {number} o.y - another thing
        \\ * @param {Object} o.nested - very nested
        \\ * @param {boolean} o.nested./*1*/great - much greatness
        \\ * @param {number} o.nested.times - twice? probably!??
        \\ */
        \\ function f(o) { return o.nested./*2*/great; }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestCompletionsPropertiesWithPromiseUnionType" {
    const content =
        \\// @strict: true
        \\type MyType = {
        \\  foo: string;
        \\};
        \\function fakeTest(cb: () => MyType | Promise<MyType>) {}
        \\fakeTest(() => {
        \\  return {
        \\    /*a*/
        \\  };
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"a"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "foo",
//                     .Kind =  undefined(lsproto.CompletionItemKindField),
//                 },
//             },
//         },
//     });
}

test "TestReferencesForGlobalsInExternalModule" {
    const content =
        \\/*1*/var /*2*/topLevelVar = 2;
        \\var topLevelVar2 = /*3*/topLevelVar;
        \\
        \\/*4*/class /*5*/topLevelClass { }
        \\var c = new /*6*/topLevelClass();
        \\
        \\/*7*/interface /*8*/topLevelInterface { }
        \\var i: /*9*/topLevelInterface;
        \\
        \\/*10*/module /*11*/topLevelModule {
        \\    export var x;
        \\}
        \\var x = /*12*/topLevelModule.x;
        \\
        \\export = x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12");
}

test "TestCodeFixMissingTypeAnnotationOnExports51_slightly_more_complex_generics_with_default" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\export interface Foo<T, U = T[]> {}
        \\export function foo(x: Foo<string>) {
        \\    return x;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add return type 'Foo<string>'",
        .NewFileContent = "export interface Foo<T, U = T[]> {}\nexport function foo(x: Foo<string>): Foo<string> {\n    return x;\n}",
        .Index = 0,
    });
}

test "TestCodeFixClassImplementClassPropertyModifiers" {
    const content =
        \\// @strict: false
        \\abstract class A {
        \\    abstract x: number;
        \\    private y: number;
        \\    protected z: number;
        \\    public w: number;
        \\    public useY() { this.y; }
        \\}
        \\
        \\class C implements A {[| |]}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'A'",
        .NewFileContent = "abstract class A {\n    abstract x: number;\n    private y: number;\n    protected z: number;\n    public w: number;\n    public useY() { this.y; }\n}\n\nclass C implements A {\n    x: number;\n    protected z: number;\n    public w: number;\n    public useY(): void {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestCodeFixCorrectReturnValue6" {
    const content =
        \\function Foo (): undefined {
        \\    undefined
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestQuickInfoMappedTypeMethods" {
    const content =
        \\type M = { [K in 'one']: any };
        \\const x: M = {
        \\  /**/one() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "(property) one: any", "");
}

test "TestIncrementalParsingDynamicImport3" {
    const content =
        \\// @lib: es2015
        \\// @Filename: ./foo.ts
        \\export function bar() { return 1; }
        \\// @Filename: ./0.ts
        \\var x = import/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 0);
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "(");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestCodeFixClassImplementInterfaceIndexSignaturesString" {
    const content =
        \\interface I<X> {
        \\    [Ƚ: string]: X;
        \\}
        \\
        \\class C implements I<number> {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I<number>'",
        .NewFileContent = "interface I<X> {\n    [Ƚ: string]: X;\n}\n\nclass C implements I<number> {\n    [Ƚ: string]: number;\n}",
        .Index = 0,
    });
}

test "TestFindAllRefsExportDefaultClassConstructor" {
    const content =
        \\export default class {
        \\    /*1*/constructor() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestImportNameCodeFixNewImportFromAtTypesScopedPackage" {
    const content =
        \\[|f1/*0*/();|]
        \\// @Filename: node_modules/@types/myLib__scoped/index.d.ts
        \\export function f1() {}
        \\export var v1 = 5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from \"@myLib/scoped\";\n\nf1();",
    }, null );
}

test "TestRenameParameterPropertyDeclaration2" {
    const content =
        \\class Foo {
        \\    constructor([|public [|{| "contextRangeIndex": 0 |}publicParam|]: number|]) {
        \\        let publicParam = [|publicParam|];
        \\        this.[|publicParam|] += 10;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "publicParam");
}

test "TestSignatureHelpCallExpressionJs" {
    const content =
        \\// @strict: false
        \\// @checkJs: true
        \\// @allowJs: true
        \\// @Filename: main.js
        \\function allOptional() { arguments; }
        \\allOptional(/*1*/);
        \\allOptional(1, 2, 3);
        \\function someOptional(x, y) { arguments; }
        \\someOptional(/*2*/);
        \\someOptional(1, 2, 3);
        \\someOptional(); // no error here; x and y are optional in JS
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "allOptional(...args: any[]): void", .ParameterCount = 1, .ParameterName = "args", .ParameterSpan = "...args: any[]", .IsVariadic = true, .IsVariadicSet = true});
    _ = f.GoToMarker(undefined, "2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "someOptional(x: any, y: any, ...args: any[]): void", .ParameterCount = 3, .ParameterName = "x", .ParameterSpan = "x: any", .IsVariadic = true, .IsVariadicSet = true});
}

test "TestFunctionOverloadCount" {
    const content =
        \\class C1 {
        \\    public attr(): string;
        \\    public attr(i: number): string;
        \\    public attr(i: number, x: boolean): string;
        \\    public attr(i?: any, x?: any) {
        \\        return "hi";
        \\    }
        \\}
        \\var i = new C1;
        \\i.attr(/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 3});
}

test "TestNavigationBarItemsSymbols4" {
    const content =
        \\// @checkJs: true
        \\// @allowJs: true
        \\// @target: es6
        \\// @Filename: file.js
        \\const _sym = Symbol("_sym");
        \\class MyClass {
        \\    constructor() {
        \\        // Dynamic assignment properties can't show up in navigation,
        \\        // as they're not syntactic members
        \\        // Additonally, late bound members are always filtered out, besides
        \\        this[_sym] = "ok";
        \\    }
        \\
        \\    method() {
        \\        this[_sym] = "yep";
        \\        const x = this[_sym];
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCompletionInsideObjectLiteralExpressionWithInstantiatedClassType" {
    const content =
        \\class C1 {
        \\    public a: string;
        \\    protected b: string;
        \\    private c: string;
        \\
        \\    constructor(a: string, b = "", c = "") {
        \\        this.a = a;
        \\        this.b = b;
        \\        this.c = c;
        \\    }
        \\}
        \\class C2 {
        \\    public a: string;
        \\    constructor(a: string) {
        \\        this.a = a;
        \\    }
        \\}
        \\function f1(foo: C1 | C2 | { d: number }) {}
        \\f1({ /*1*/ });
        \\function f2(foo: C1 | C2) {}
        \\f2({ /*2*/ });
        \\
        \\function f3(foo: C2) {}
        \\f3({ /*3*/ });
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
//             .Exact = &.{
//                 "a",
//                 "d",
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
//             .Exact = &.{
//                 "a",
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
//             .Exact = &.{
//                 "a",
//             },
//         },
//     });
}

test "TestQuickinfoVerbosityLibType" {
    const content =
        \\// @lib: es5
        \\interface Apple {
        \\    color: string;
        \\    size: number;
        \\}
        \\function f(): Promise<Apple> {
        \\    return Promise.resolve({ color: "red", size: 5 });
        \\}
        \\const g/*g*/ = f;
        \\const u/*u*/: Map<string, Apple> = new Map;
        \\type Foo<T> = Promise/*p*/<T>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"g" = .{0, 1}, .@"u" = .{0, 1}, .@"p" = .{0}});
}

test "TestCompletionInJsDocQualifiedNames" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /node_modules/foo/index.d.ts
        \\/** tee */
        \\export type T = number;
        \\// @Filename: /a.js
        \\import * as Foo from "foo";
        \\/** @type {Foo./**/} */
        \\const x = 0;
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
//                     .Label =  "T",
//                     .Detail = undefined("type T = number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "tee",
//                         },
//                     },
//                     .Kind = undefined(lsproto.CompletionItemKindClass),
//                 },
//             },
//         },
//     });
}

test "TestSignatureHelp_contextual" {
    const content =
        \\interface I {
        \\    m(n: number, s: string): void;
        \\    m2: () => void;
        \\}
        \\declare function takesObj(i: I): void;
        \\takesObj({ m: (/*takesObj0*/) });
        \\takesObj({ m(/*takesObj1*/) });
        \\takesObj({ m: function(/*takesObj2*/) });
        \\takesObj({ m2: (/*takesObj3*/) });
        \\
        \\declare function takesCb(cb: (n: number, s: string, b: boolean) => void): void;
        \\takesCb((/*contextualParameter1*/));
        \\takesCb((/*contextualParameter1b*/) => {});
        \\takesCb((n, /*contextualParameter2*/));
        \\takesCb((n, s, /*contextualParameter3*/));
        \\takesCb((n,/*contextualParameter3_2*/ s, b));
        \\takesCb((n, s, b, /*contextualParameter4*/));
        \\
        \\type Cb = () => void;
        \\const cb: Cb = (/*contextualTypeAlias*/)
        \\
        \\const cb2: () => void = (/*contextualFunctionType*/)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "takesObj0");
    // try f.VerifySignatureHelp(undefined, .{.Text = "m(n: number, s: string): void", .ParameterCount = 2, .ParameterName = "n", .ParameterSpan = "n: number"});
    _ = f.GoToMarker(undefined, "takesObj1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "m(n: number, s: string): void", .ParameterCount = 2, .ParameterName = "n", .ParameterSpan = "n: number"});
    _ = f.GoToMarker(undefined, "takesObj2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "m(n: number, s: string): void", .ParameterCount = 2, .ParameterName = "n", .ParameterSpan = "n: number"});
    _ = f.GoToMarker(undefined, "takesObj3");
    // try f.VerifySignatureHelp(undefined, .{.Text = "m2(): void", .ParameterCount = 0});
    _ = f.GoToMarker(undefined, "contextualParameter1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "cb(n: number, s: string, b: boolean): void", .ParameterCount = 3, .ParameterName = "n", .ParameterSpan = "n: number"});
    _ = f.GoToMarker(undefined, "contextualParameter1b");
    // try f.VerifySignatureHelp(undefined, .{.Text = "cb(n: number, s: string, b: boolean): void", .ParameterCount = 3, .ParameterName = "n", .ParameterSpan = "n: number"});
    _ = f.GoToMarker(undefined, "contextualParameter2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "cb(n: number, s: string, b: boolean): void", .ParameterCount = 3, .ParameterName = "s", .ParameterSpan = "s: string"});
    _ = f.GoToMarker(undefined, "contextualParameter3");
    // try f.VerifySignatureHelp(undefined, .{.Text = "cb(n: number, s: string, b: boolean): void", .ParameterCount = 3, .ParameterName = "b", .ParameterSpan = "b: boolean"});
    _ = f.GoToMarker(undefined, "contextualParameter3_2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "cb(n: number, s: string, b: boolean): void", .ParameterCount = 3, .ParameterName = "s", .ParameterSpan = "s: string"});
    _ = f.GoToMarker(undefined, "contextualParameter4");
    // try f.VerifySignatureHelp(undefined, .{.Text = "cb(n: number, s: string, b: boolean): void", .ParameterCount = 3});
    _ = f.GoToMarker(undefined, "contextualTypeAlias");
    // try f.VerifySignatureHelp(undefined, .{.Text = "Cb(): void", .ParameterCount = 0});
    _ = f.GoToMarker(undefined, "contextualFunctionType");
    // try f.VerifySignatureHelp(undefined, .{.Text = "cb2(): void", .ParameterCount = 0});
}

test "TestReturnTypeOfGenericFunction1" {
    const content =
        \\interface WrappedArray<T> {
        \\    map<U>(iterator: (value: T) => U, context?: any): U[];
        \\}
        \\var x: WrappedArray<string>;
        \\var /**/y = x.map(s => s.length);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "var y: number[]", "");
}

test "TestCompletionListInUnclosedFunction11" {
    const content =
        \\interface MyType {
        \\}
        \\
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string = "hello", c: typeof x = "hello") {
        \\        var v = (p: /*1*/
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
//             .Includes = &.{
//                 "MyType",
//             },
//         },
//     });
}

test "TestFindAllRefsOfConstructor" {
    const content =
        \\class A {
        \\    /*aCtr*/constructor(s: string) {}
        \\}
        \\class B extends A { }
        \\class C extends B {
        \\    /*cCtr*/constructor() {
        \\        super("");
        \\    }
        \\}
        \\class D extends B { }
        \\class E implements A { }
        \\const a = new A("a");
        \\const b = new B("b");
        \\const c = new C();
        \\const d = new D("d");
        \\const e = new E();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    // try f.VerifyBaselineFindAllReferences(undefined, "aCtr", "cCtr");
}

test "TestCompletionsImport_augmentation" {
    const content =
        \\// @Filename: /a.ts
        \\export const foo = 0;
        \\// @Filename: /bar.ts
        \\export {};
        \\declare module "./a" {
        \\    export const bar = 0;
        \\}
        \\// @Filename: /user.ts
        \\/**/
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
//                     .Label =  "foo",
//                     .Detail = undefined("const foo: 0"),
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./a",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//                 &.{
//                     .Label =  "bar",
//                     .Detail = undefined("const bar: 0"),
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

test "TestRenameLabel1" {
    const content =
        \\foo: {
        \\    break /**/foo;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , "");
}

test "TestCompletionTypeofExpressions" {
    const content =
        \\const x = "str";
        \\function test(arg: typeof x./*1*/) {}
        \\function test1(arg: typeof (x./*2*/)) {}
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
//             .Includes = &.{
//                 "length",
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
//                 "length",
//             },
//         },
//     });
}

test "TestNavigationItemsExportEqualsExpression" {
    const content =
        \\export = function () {}
        \\export = function () {
        \\    return class Foo {
        \\    }
        \\}
        \\
        \\export = () => ""
        \\export = () => {
        \\    return class Foo {
        \\    }
        \\}
        \\
        \\export = function f1() {}
        \\export = function f2() {
        \\    return class Foo {
        \\    }
        \\}
        \\
        \\const abc = 12;
        \\export = abc;
        \\export = class AB {}
        \\export = {
        \\    a: 1,
        \\    b: 1,
        \\    c: {
        \\        d: 1
        \\    }
        \\}
        \\
        \\function foo(props: { x: number; y: number }) {}
        \\export = foo({ x: 1, y: 1 });
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestReferencesInConfiguredProject" {
    const content =
        \\// @Filename: /home/src/workspaces/project/referencesForGlobals_1.ts
        \\class /*0*/globalClass {
        \\    public f() { }
        \\}
        \\// @Filename: /home/src/workspaces/project/referencesForGlobals_2.ts
        \\var c = /*1*/globalClass();
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{ "files": ["referencesForGlobals_1.ts", "referencesForGlobals_2.ts"], "compilerOptions": { "lib": ["es5"] } }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestAutoImportProvider_referencesCrash" {
    const content =
        \\// @Filename: /home/src/workspaces/project/a/package.json
        \\{}
        \\// @Filename: /home/src/workspaces/project/a/tsconfig.json
        \\{ "compilerOptions": { "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/a/index.ts
        \\class A {}
        \\// @Filename: /home/src/workspaces/project/a/index.d.ts
        \\declare class A {
        \\}
        \\//# sourceMappingURL=index.d.ts.map
        \\// @Filename: /home/src/workspaces/project/a/index.d.ts.map
        \\{"version":3,"file":"index.d.ts","sourceRoot":"","sources":["index.ts"],"names":[],"mappings":"AAAA,OAAO,OAAO,CAAC;CAAG"}
        \\// @Filename: /home/src/workspaces/project/b/tsconfig.json
        \\{
        \\  "compilerOptions": { "disableSourceOfProjectReferenceRedirect": true, "lib": ["es5"] },
        \\  "references": [{ "path": "../a" }]
        \\}
        \\// @Filename: /home/src/workspaces/project/b/b.ts
        \\/// <reference path="../a/index.d.ts" />
        \\new A/**/();
        \\// @Filename: /home/src/workspaces/project/c/package.json
        \\{ "dependencies": { "a": "*" } }
        \\// @Filename: /home/src/workspaces/project/c/tsconfig.json
        \\{ "compilerOptions": { "lib": ["es5"] }, "references" [{ "path": "../a" }] }
        \\// @Filename: /home/src/workspaces/project/c/index.ts
        \\export {};
        \\// @link: /home/src/workspaces/project/a -> /home/src/workspaces/project/c/node_modules/a
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToFile(undefined, "/home/src/workspaces/project/c/index.ts");
    // try f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestSemanticClassificationInstantiatedModuleWithVariableOfSameName1" {
    const content =
        \\module /*0*/M {
        \\    export interface /*1*/I {
        \\    }
        \\    var x = 10;
        \\}
        \\
        \\var /*2*/M = {
        \\    foo: 10,
        \\    bar: 20
        \\}
        \\
        \\var v: /*3*/M./*4*/I;
        \\
        \\var x = /*5*/M;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "namespace.declaration", .Text = "M"},
//         .{.Type = "interface.declaration", .Text = "I"},
//         .{.Type = "variable.declaration.local", .Text = "x"},
//         .{.Type = "variable.declaration", .Text = "M"},
//         .{.Type = "property.declaration", .Text = "foo"},
//         .{.Type = "property.declaration", .Text = "bar"},
//         .{.Type = "variable.declaration", .Text = "v"},
//         .{.Type = "namespace", .Text = "M"},
//         .{.Type = "interface", .Text = "I"},
//         .{.Type = "variable.declaration", .Text = "x"},
//         .{.Type = "namespace", .Text = "M"},
//     });
}

test "TestFindAllRefsObjectBindingElementPropertyName10" {
    const content =
        \\interface Recursive {
        \\    /*1*/next?: Recursive;
        \\    value: any;
        \\}
        \\
        \\function f (/*2*/{ /*3*/next: { /*4*/next: x} }: Recursive) {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestAutoImportSortCaseSensitivity2" {
    const content =
        \\// @Filename: /a.ts
        \\export interface HasBar { bar: number }
        \\export function hasBar(x: unknown): x is HasBar { return x && typeof x.bar === "number" }
        \\export function foo() {}
        \\export type __String = string;
        \\// @Filename: /b.ts
        \\import { __String, HasBar, hasBar } from "./a";
        \\f/**/;
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
//                     .Label = "foo",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./a",
//                         },
//                     },
//                     .Detail =              undefined("function foo(): void"),
//                     .Kind =                undefined(lsproto.CompletionItemKindFunction),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "foo",
//         .Source =      "./a",
//         .Description = "Update import from \"./a\"",
//         .NewFileContent = undefined("import { __String, foo, HasBar, hasBar } from \"./a\";\nf;"),
//     });
}

test "TestProtoVarVisibleWithOuterScopeUnderscoreProto" {
    const content =
        \\// outer
        \\var ___proto__ = 10;
        \\function foo() {
        \\    var __proto__ = "hello";
        \\    /**/
        \\}
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
//                     .Label =  "__proto__",
//                     .Detail = undefined("(local var) __proto__: string"),
//                 },
//                 &.{
//                     .Label =  "___proto__",
//                     .Detail = undefined("var ___proto__: number"),
//                 },
//             },
//         },
//     });
}

test "TestGetEditsForFileRename" {
    const content =
        \\// @Filename: /a.ts
        \\/// <reference path="./src/old.ts" />
        \\import old from "./src/old";
        \\// @Filename: /src/a.ts
        \\/// <reference path="./old.ts" />
        \\import old from "./old";
        \\// @Filename: /src/foo/a.ts
        \\/// <reference path="../old.ts" />
        \\import old from "../old";
        \\// @Filename: /unrelated.ts
        \\import { x } from "././src/./foo/./a";
        \\// @Filename: /src/old.ts
        \\export default 0;
        \\// @Filename: /tsconfig.json
        \\{ "files": ["a.ts", "src/a.ts", "src/foo/a.ts", "src/old.ts"] }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyWillRenameFilesEdits(undefined, "/src/old.ts", "/src/new.ts", .{
//         .@"/a.ts" = "/// <reference path=\"./src/new.ts\" />\nimport old from \"./src/new\";",
//         .@"/src/a.ts" = "/// <reference path=\"./new.ts\" />\nimport old from \"./new\";",
//         .@"/src/foo/a.ts" = "/// <reference path=\"../new.ts\" />\nimport old from \"../new\";",
//         .@"/tsconfig.json" = "{ \"files\": [\"a.ts\", \"src/a.ts\", \"src/foo/a.ts\", \"src/new.ts\"] }",
//     }, null );
}

test "TestGoToImplementationNamespace_04" {
    const content =
        \\namespace Foo {
        \\    export interface Bar {
        \\        hello(): void;
        \\    }
        \\
        \\    class [|BarImpl|] implements Bar {
        \\        hello() {}
        \\    }
        \\}
        \\
        \\class [|Baz|] implements Foo.Bar {
        \\    hello() {}
        \\}
        \\
        \\var someVar1 : Foo.Bar = [|{ hello: () => {/**1*/} }|];
        \\
        \\var someVar2 = <Foo.Bar> [|{ hello: () => {/**2*/} }|];
        \\
        \\function whatever(x: Foo.Ba/*reference*/r) {
        \\
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "reference");
}

test "TestUnusedClassInNamespace3" {
    const content =
        \\// @noUnusedLocals: true
        \\// @noUnusedParameters:true
        \\ [| namespace Validation {
        \\    class c1 {
        \\
        \\    }
        \\
        \\    export class c2 {
        \\
        \\    }
        \\
        \\    class c3 extends c1 {
        \\
        \\    }
        \\} |]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "namespace Validation {\n    class c1 {\n    }\n\n    export class c2 {\n    }\n}", false, 0, 0);
}

test "TestFindAllReferencesImportMeta" {
    const content =
        \\// Haha that's so meta!
        \\
        \\let x = import.meta/**/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestGoToDefinitionExternalModuleName5" {
    const content =
        \\// @Filename: a.ts
        \\declare module /*2*/[|"external/*1*/"|] {
        \\    class Foo { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestOrganizeImportsType1" {
    const content =
        \\// @allowSyntheticDefaultImports: true
        \\// @moduleResolution: bundler
        \\// @noUnusedLocals: true
        \\// @target: es2018
        \\import { A } from "foo";
        \\import { type B } from "foo";
        \\import { C } from "foo";
        \\import { type E } from "foo";
        \\import { D } from "foo";
        \\
        \\console.log(A, B, C, D, E);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "import { A, C, D, type B, type E } from \"foo\";\n\nconsole.log(A, B, C, D, E);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
    // try f.VerifyOrganizeImports(undefined,
//         "import { A, type B, C, D, type E } from \"foo\";\n\nconsole.log(A, B, C, D, E);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderInline,
//         },
//     );
    // try f.VerifyOrganizeImports(undefined,
//         "import { type B, type E, A, C, D } from \"foo\";\n\nconsole.log(A, B, C, D, E);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderFirst,
//         },
//     );
    // try f.VerifyOrganizeImports(undefined,
//         "import { A, C, D, type B, type E } from \"foo\";\n\nconsole.log(A, B, C, D, E);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderLast,
//         },
//     );
}

test "TestImportNameCodeFixNewImportAmbient0" {
    const content =
        \\[|f1/*0*/();|]
        \\// @Filename: ambientModule.ts
        \\declare module "ambient-module" {
        \\   export function f1();
        \\   export var v1;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from \"ambient-module\";\n\nf1();",
    }, null );
}

test "TestCodeFixInferFromUsageRestParam3" {
    const content =
        \\// @noImplicitAny: true
        \\function f(a: number, [|...rest |]){
        \\    a;
        \\    rest.push(22);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "...rest: number[]", false, 0, 0);
}

test "TestCompletionsImport_umdModules2_moduleExports" {
    const content =
        \\// @filename: /package.json
        \\{ "dependencies": { "@types/classnames": "*" } }
        \\// @filename: /tsconfig.json
        \\{ "compilerOptions": { "types": ["*"] } }
        \\// @filename: /node_modules/@types/classnames/package.json
        \\{ "name": "@types/classnames", "types": "index.d.ts" }
        \\// @filename: /node_modules/@types/classnames/index.d.ts
        \\declare const classNames: () => string;
        \\export = classNames;
        \\export as namespace classNames;
        \\// @filename: /SomeReactComponent.tsx
        \\import * as React from 'react';
        \\
        \\const el1 = <div className={class/*1*/}>foo</div>;
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
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "classnames",
//                         },
//                     },
//                     .SortText = undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
}

test "TestReferencesForIllegalAssignment" {
    const content =
        \\f/*1*/oo = fo/*2*/o;
        \\var /*bar*/bar = function () { };
        \\bar = bar + 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "bar");
}

test "TestCompletionsImport_shadowedByLocal" {
    const content =
        \\// @noLib: true
        \\// @Filename: /a.ts
        \\export const foo = 0;
        \\// @Filename: /b.ts
        \\const foo = 1;
        \\fo/**/
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
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     &.{
//                         .Label =  "foo",
//                         .Detail = undefined("const foo: 1"),
//                     },
//                 }, true,
//             ),
//         },
//     });
}

test "TestJsDocSee_rename1" {
    const content =
        \\[|interface [|{| "contextRangeIndex": 0 |}A|] {}|]
        \\/**
        \\ * @see {[|A|]}
        \\ */
        \\declare const a: [|A|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , ToAny(f.Ranges()[1:]));
}

test "TestRenameJsPropertyAssignment" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\function bar() {
        \\}
        \\[|bar.[|{| "contextRangeIndex": 0 |}foo|] = "foo";|]
        \\console.log(bar.[|foo|]);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "foo");
}

test "TestCodeFixAddMissingAttributes5" {
    const content =
        \\// @jsx: preserve
        \\// @filename: foo.tsx
        \\interface P {
        \\    a: number;
        \\    b: string;
        \\    c: number[];
        \\    d: any;
        \\}
        \\
        \\const A = ({ a, b, c, d }: P) =>
        \\    <div>{a}{b}{c}{d}</div>;
        \\
        \\const Bar = () =>
        \\    [|<A a={100} b={""} c={[]} d={undefined}></A>|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined, "fixMissingAttributes");
}

test "TestFindAllRefsPrivateNameMethods" {
    const content =
        \\class C {
        \\    /*1*/#foo(){ }
        \\    constructor() {
        \\        this./*2*/#foo();
        \\    }
        \\}
        \\class D extends C {
        \\    constructor() {
        \\        super()
        \\        this.#foo = 20;
        \\    }
        \\}
        \\class E {
        \\    /*3*/#foo(){ }
        \\    constructor() {
        \\        this./*4*/#foo();
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestGoToDefinitionFunctionOverloads" {
    const content =
        \\function [|/*functionOverload1*/functionOverload|](value: number);
        \\function /*functionOverload2*/functionOverload(value: string);
        \\function /*functionOverloadDefinition*/functionOverload() {}
        \\
        \\[|/*functionOverloadReference1*/functionOverload|](123);
        \\[|/*functionOverloadReference2*/functionOverload|]("123");
        \\[|/*brokenOverload*/functionOverload|]({});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "functionOverloadReference1", "functionOverloadReference2", "brokenOverload", "functionOverload1");
}

test "TestOrganizeImports7" {
    const content =
        \\import * as something from "path"; /**
        \\ * some comment here
        \\ * and there
        \\ */
        \\import * as somethingElse from "anotherpath";
        \\
        \\something;
        \\somethingElse;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "import * as somethingElse from \"anotherpath\";\nimport * as something from \"path\"; /**\n * some comment here\n * and there\n */\n\nsomething;\nsomethingElse;",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestCodeFixAddMissingFunctionDeclaration19" {
    const content =
        \\declare function f(x: number): any;
        \\f(foo);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined, "fixMissingFunctionDeclaration");
}

test "TestGetJavaScriptCompletions11" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\/** @type {number|string} */
        \\var v;
        \\v./**/
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
//                     .Label = "toExponential",
//                     .Kind =  undefined(lsproto.CompletionItemKindMethod),
//                 },
//                 &.{
//                     .Label = "charCodeAt",
//                     .Kind =  undefined(lsproto.CompletionItemKindMethod),
//                 },
//             },
//         },
//     });
}

test "TestCompletionListPrivateNamesAccessors" {
    const content =
        \\class Foo {
        \\   get #x() { return 1 };
        \\   set #x(value: number) { };
        \\   y() {};
        \\}
        \\class Bar extends Foo {
        \\   get #z() { return 1 };
        \\   set #z(value: number) { };
        \\   t() {};
        \\   l;
        \\   constructor() {
        \\       this./*1*/
        \\       class Baz {
        \\           get #z() { return 1 };
        \\           set #z(value: number) { };
        \\           get #u() { return 1 };
        \\           set #u(value: number) { };
        \\           v() {};
        \\           k;
        \\           constructor() {
        \\               this./*2*/
        \\               new Bar()./*3*/
        \\           }
        \\       }
        \\   }
        \\}
        \\
        \\new Foo()./*4*/
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
//             .Unsorted = &.{
//                 "#z",
//                 "t",
//                 "l",
//                 "y",
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
//             .Unsorted = &.{
//                 "#z",
//                 "#u",
//                 "v",
//                 "k",
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
//                 "#z",
//                 "t",
//                 "l",
//                 "y",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "4", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "y",
//             },
//         },
//     });
}

test "TestCompletionListInMiddleOfIdentifierInArrowFunction01" {
    const content =
        \\xyz => x/*1*/y
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
//             .Includes = &.{
//                 "xyz",
//             },
//         },
//     });
}

test "TestCodeFixAddMissingParam15" {
    const content =
        \\function f(a: number, b: number) {}
        \\f();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined, "addMissingParam");
}

test "TestExportEqualsInterfaceA" {
    const content =
        \\// @Filename: exportEqualsInterface_A.ts
        \\interface A {
        \\    p1: number;
        \\}
        \\export = A;
        \\/**/
        \\var i: I1;
        \\var n: number = i.p1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "import I1 = require(\"exportEqualsInterface_A\");");
}

test "TestRenameNamespaceImport" {
    const content =
        \\// @Filename: /home/src/workspaces/project/lib/tsconfig.json
        \\{ "compilerOptions": { "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/lib/index.ts
        \\const unrelatedLocalVariable = 123;
        \\export const someExportedVariable = unrelatedLocalVariable;
        \\// @Filename: /home/src/workspaces/project/src/tsconfig.json
        \\{ "compilerOptions": { "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/src/index.ts
        \\import * as /*i*/lib from '../lib/index';
        \\lib.someExportedVariable;
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{ "compilerOptions": { "lib": ["es5"] } }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToFile(undefined, "/home/src/workspaces/project/lib/index.ts");
    _ = f.GoToFile(undefined, "/home/src/workspaces/project/src/index.ts");
    // try f.VerifyBaselineRename(undefined, null , "i");
}

test "TestCompletionInFunctionLikeBody_includesPrimitiveTypes" {
    const content =
        \\class Foo<T> { }
        \\class Bar { }
        \\function includesTypes() {
        \\    new Foo</*1*/
        \\}
        \\function excludesTypes1() {
        \\    new Bar</*2*/
        \\}
        \\function excludesTypes2() {
        \\    1</*3*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "string",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//                 &.{
//                     .Label =    "String",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"2", "3"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Excludes = &.{
//                 "string",
//             },
//         },
//     });
}

test "TestTsxCompletionOnClosingTagWithoutJSX2" {
    const content =
        \\//@Filename: file.tsx
        \\var x1 = <div>
        \\   <h1> Hello world </ /*2*/>
        \\   </ /*1*/>
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
//             .Exact = &.{
//                 "div",
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
//             .Exact = &.{
//                 "h1",
//             },
//         },
//     });
}

test "TestImportCompletions_importsMap3" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "nodenext",
        \\    "lib": ["es5"],
        \\    "rootDir": "src",
        \\    "outDir": "dist"
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{
        \\  "type": "module",
        \\  "imports": {
        \\    "#internal/": "./dist/internal/"
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/src/internal/foo.ts
        \\export function something(name: string) {}
        \\// @Filename: /home/src/workspaces/project/src/a.ts
        \\import {} from "/*1*/";
        \\import {} from "#internal//*2*/";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyCompletions(undefined, &.{"1"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "#internal",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"2"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "foo.js",
//             },
//         },
//     });
}

test "TestCommentsOverloadsFourslash" {
    const content =
        \\/** this is signature 1*/
        \\function /*1*/f1(/**param a*/a: number): number;
        \\function /*2*/f1(b: string): number;
        \\function /*3*/f1(aOrb: any) {
        \\    return 10;
        \\}
        \\f/*4q*/1(/*4*/"hello");
        \\f/*o4q*/1(/*o4*/10);
        \\function /*5*/f2(/**param a*/a: number): number;
        \\/** this is signature 2*/
        \\function /*6*/f2(b: string): number;
        \\/** this is f2 var comment*/
        \\function /*7*/f2(aOrb: any) {
        \\    return 10;
        \\}
        \\f/*8q*/2(/*8*/"hello");
        \\f/*o8q*/2(/*o8*/10);
        \\function /*9*/f3(a: number): number;
        \\function /*10*/f3(b: string): number;
        \\function /*11*/f3(aOrb: any) {
        \\    return 10;
        \\}
        \\f/*12q*/3(/*12*/"hello");
        \\f/*o12q*/3(/*o12*/10);
        \\/** this is signature 4 - with number parameter*/
        \\function /*13*/f4(/**param a*/a: number): number;
        \\/** this is signature 4 - with string parameter*/
        \\function /*14*/f4(b: string): number;
        \\function /*15*/f4(aOrb: any) {
        \\    return 10;
        \\}
        \\f/*16q*/4(/*16*/"hello");
        \\f/*o16q*/4(/*o16*/10);
        \\/*17*/
        \\interface i1 {
        \\    /**this signature 1*/
        \\    (/**param a*/ a: number): number;
        \\    /**this is signature 2*/
        \\    (b: string): number;
        \\    /** foo 1*/
        \\    foo(a: number): number;
        \\    /** foo 2*/
        \\    foo(b: string): number;
        \\    foo2(a: number): number;
        \\    /** foo2 2*/
        \\    foo2(b: string): number;
        \\    foo3(a: number): number;
        \\    foo3(b: string): number;
        \\    /** foo4 1*/
        \\    foo4(a: number): number;
        \\    foo4(b: string): number;
        \\    /** new 1*/
        \\    new (a: string);
        \\    new (b: number);
        \\}
        \\var i1_i: i1;
        \\interface i2 {
        \\    new (a: string);
        \\    /** new 2*/
        \\    new (b: number);
        \\    (a: number): number;
        \\    /**this is signature 2*/
        \\    (b: string): number;
        \\}
        \\var i2_i: i2;
        \\interface i3 {
        \\    /** new 1*/
        \\    new (a: string);
        \\    /** new 2*/
        \\    new (b: number);
        \\    /**this is signature 1*/
        \\    (a: number): number;
        \\    (b: string): number;
        \\}
        \\var i3_i: i3;
        \\interface i4 {
        \\    new (a: string);
        \\    new (b: number);
        \\    (a: number): number;
        \\    (b: string): number;
        \\}
        \\var i4_i: i4;
        \\new /*18*/i1/*19q*/_i(/*19*/10);
        \\new i/*20q*/1_i(/*20*/"Hello");
        \\i/*21q*/1_i(/*21*/10);
        \\i/*22q*/1_i(/*22*/"hello");
        \\i1_i./*23*/f/*24q*/oo(/*24*/10);
        \\i1_i.f/*25q*/oo(/*25*/"hello");
        \\i1_i.fo/*26q*/o2(/*26*/10);
        \\i1_i.fo/*27q*/o2(/*27*/"hello");
        \\i1_i.fo/*28q*/o3(/*28*/10);
        \\i1_i.fo/*29q*/o3(/*29*/"hello");
        \\i1_i.fo/*30q*/o4(/*30*/10);
        \\i1_i.fo/*31q*/o4(/*31*/"hello");
        \\new i2/*32q*/_i(/*32*/10);
        \\new i2/*33q*/_i(/*33*/"Hello");
        \\i/*34q*/2_i(/*34*/10);
        \\i2/*35q*/_i(/*35*/"hello");
        \\new i/*36q*/3_i(/*36*/10);
        \\new i3/*37q*/_i(/*37*/"Hello");
        \\i3/*38q*/_i(/*38*/10);
        \\i3/*39q*/_i(/*39*/"hello");
        \\new i4/*40q*/_i(/*40*/10);
        \\new i/*41q*/4_i(/*41*/"Hello");
        \\i4/*42q*/_i(/*42*/10);
        \\i4/*43q*/_i(/*43*/"hello");
        \\class c {
        \\    public /*93*/prop1(a: number): number;
        \\    public /*94*/prop1(b: string): number;
        \\    public /*95*/prop1(aorb: any) {
        \\        return 10;
        \\    }
        \\    /** prop2 1*/
        \\    public /*96*/prop2(a: number): number;
        \\    public /*97*/prop2(b: string): number;
        \\    public /*98*/prop2(aorb: any) {
        \\        return 10;
        \\    }
        \\    public /*99*/prop3(a: number): number;
        \\    /** prop3 2*/
        \\    public /*100*/prop3(b: string): number;
        \\    public /*101*/prop3(aorb: any) {
        \\        return 10;
        \\    }
        \\    /** prop4 1*/
        \\    public /*102*/prop4(a: number): number;
        \\    /** prop4 2*/
        \\    public /*103*/prop4(b: string): number;
        \\    public /*104*/prop4(aorb: any) {
        \\        return 10;
        \\    }
        \\    /** prop5 1*/
        \\    public /*105*/prop5(a: number): number;
        \\    /** prop5 2*/
        \\    public /*106*/prop5(b: string): number;
        \\    /** Prop5 implementaion*/
        \\    public /*107*/prop5(aorb: any) {
        \\        return 10;
        \\    }
        \\}
        \\class c1 {
        \\    /*78*/constructor(a: number);
        \\    /*79*/constructor(b: string);
        \\    /*80*/constructor(aorb: any) {
        \\    }
        \\}
        \\class c2 {
        \\    /** c2 1*/
        \\    /*81*/constructor(a: number);
        \\    /*82*/constructor(b: string);
        \\    /*83*/constructor(aorb: any) {
        \\    }
        \\}
        \\class c3 {
        \\    /*84*/constructor(a: number);
        \\    /** c3 2*/
        \\    /*85*/constructor(b: string);
        \\    /*86*/constructor(aorb: any) {
        \\    }
        \\}
        \\class c4 {
        \\    /** c4 1*/
        \\    /*87*/constructor(a: number);
        \\    /** c4 2*/
        \\    /*88*/constructor(b: string);
        \\    /*89*/constructor(aorb: any) {
        \\    }
        \\}
        \\class c5 {
        \\    /** c5 1*/
        \\    /*90*/constructor(a: number);
        \\    /** c5 2*/
        \\    /*91*/constructor(b: string);
        \\    /** c5 implementation*/
        \\    /*92*/constructor(aorb: any) {
        \\    }
        \\}
        \\var c_i = new c();
        \\c_i./*44*/pro/*45q*/p1(/*45*/10);
        \\c_i.pr/*46q*/op1(/*46*/"hello");
        \\c_i.pr/*47q*/op2(/*47*/10);
        \\c_i.pr/*48q*/op2(/*48*/"hello");
        \\c_i.pro/*49q*/p3(/*49*/10);
        \\c_i.pr/*50q*/op3(/*50*/"hello");
        \\c_i.pr/*51q*/op4(/*51*/10);
        \\c_i.pr/*52q*/op4(/*52*/"hello");
        \\c_i.pr/*53q*/op5(/*53*/10);
        \\c_i.pr/*54q*/op5(/*54*/"hello");
        \\var c1/*66*/_i_1 = new c/*55q*/1(/*55*/10);
        \\var c1_i_2 = new c/*56q*/1(/*56*/"hello");
        \\var c2_i_1 = new c/*57q*/2(/*57*/10);
        \\var c/*67*/2_i_2 = new c/*58q*/2(/*58*/"hello");
        \\var c3_i_1 = new c/*59q*/3(/*59*/10);
        \\var c/*68*/3_i_2 = new c/*60q*/3(/*60*/"hello");
        \\var c4/*69*/_i_1 = new c/*61q*/4(/*61*/10);
        \\var c4_i_2 = new c/*62q*/4(/*62*/"hello");
        \\var c/*70*/5_i_1 = new c/*63q*/5(/*63*/10);
        \\var c5_i_2 = new c/*64q*/5(/*64*/"hello");
        \\/** This is multiOverload F1 1*/
        \\function multiOverload(a: number): string;
        \\/** This is multiOverload F1 2*/
        \\function multiOverload(b: string): string;
        \\/** This is multiOverload F1 3*/
        \\function multiOverload(c: boolean): string;
        \\/** This is multiOverload Implementation */
        \\function multiOverload(d): string {
        \\    return "Hello";
        \\}
        \\multiOverl/*71*/oad(10);
        \\multiOverl/*72*/oad("hello");
        \\multiOverl/*73*/oad(true);
        \\/** This is ambient F1 1*/
        \\declare function ambientF1(a: number): string;
        \\/** This is ambient F1 2*/
        \\declare function ambientF1(b: string): string;
        \\/** This is ambient F1 3*/
        \\declare function ambientF1(c: boolean): boolean;
        \\/*65*/
        \\ambient/*74*/F1(10);
        \\ambient/*75*/F1("hello");
        \\ambient/*76*/F1(true);
        \\function foo(a/*77*/a: i3) {
        \\}
        \\foo(null);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "function f1(a: number): number (+1 overload)", "this is signature 1");
    try f.VerifyQuickInfoAt(undefined, "2", "function f1(b: string): number (+1 overload)", "this is signature 1");
    try f.VerifyQuickInfoAt(undefined, "3", "function f1(a: number): number (+1 overload)", "this is signature 1");
    try f.VerifyQuickInfoAt(undefined, "4q", "function f1(b: string): number (+1 overload)", "this is signature 1");
    try f.VerifyQuickInfoAt(undefined, "o4q", "function f1(a: number): number (+1 overload)", "this is signature 1");
    _ = f.GoToMarker(undefined, "4");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    _ = f.GoToMarker(undefined, "o4");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "this is signature 1", .ParameterDocComment = "param a", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "5", "function f2(a: number): number (+1 overload)", "");
    try f.VerifyQuickInfoAt(undefined, "6", "function f2(b: string): number (+1 overload)", "this is signature 2");
    try f.VerifyQuickInfoAt(undefined, "7", "function f2(a: number): number (+1 overload)", "");
    try f.VerifyQuickInfoAt(undefined, "8q", "function f2(b: string): number (+1 overload)", "this is signature 2");
    try f.VerifyQuickInfoAt(undefined, "o8q", "function f2(a: number): number (+1 overload)", "");
    _ = f.GoToMarker(undefined, "8");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "this is signature 2", .OverloadsCount = 2});
    _ = f.GoToMarker(undefined, "o8");
    // try f.VerifySignatureHelp(undefined, .{.ParameterDocComment = "param a", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "9", "function f3(a: number): number (+1 overload)", "");
    try f.VerifyQuickInfoAt(undefined, "10", "function f3(b: string): number (+1 overload)", "");
    try f.VerifyQuickInfoAt(undefined, "11", "function f3(a: number): number (+1 overload)", "");
    try f.VerifyQuickInfoAt(undefined, "12q", "function f3(b: string): number (+1 overload)", "");
    try f.VerifyQuickInfoAt(undefined, "o12q", "function f3(a: number): number (+1 overload)", "");
    _ = f.GoToMarker(undefined, "12");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    _ = f.GoToMarker(undefined, "o12");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "13", "function f4(a: number): number (+1 overload)", "this is signature 4 - with number parameter");
    try f.VerifyQuickInfoAt(undefined, "14", "function f4(b: string): number (+1 overload)", "this is signature 4 - with string parameter");
    try f.VerifyQuickInfoAt(undefined, "15", "function f4(a: number): number (+1 overload)", "this is signature 4 - with number parameter");
    try f.VerifyQuickInfoAt(undefined, "16q", "function f4(b: string): number (+1 overload)", "this is signature 4 - with string parameter");
    try f.VerifyQuickInfoAt(undefined, "o16q", "function f4(a: number): number (+1 overload)", "this is signature 4 - with number parameter");
    _ = f.GoToMarker(undefined, "16");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "this is signature 4 - with string parameter", .OverloadsCount = 2});
    _ = f.GoToMarker(undefined, "o16");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "this is signature 4 - with number parameter", .ParameterDocComment = "param a", .OverloadsCount = 2});
    // f.VerifyCompletions(undefined, "17", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "f1",
//                     .Detail = undefined("function f1(a: number): number (+1 overload)"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "this is signature 1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "f2",
//                     .Detail = undefined("function f2(a: number): number (+1 overload)"),
//                 },
//                 &.{
//                     .Label =  "f3",
//                     .Detail = undefined("function f3(a: number): number (+1 overload)"),
//                 },
//                 &.{
//                     .Label =  "f4",
//                     .Detail = undefined("function f4(a: number): number (+1 overload)"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "this is signature 4 - with number parameter",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "18", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "i1_i",
//                     .Detail = undefined("var i1_i: i1\nnew (b: number) => any (+1 overload)"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "new 1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i2_i",
//                     .Detail = undefined("var i2_i: i2\nnew (a: string) => any (+1 overload)"),
//                 },
//                 &.{
//                     .Label =  "i3_i",
//                     .Detail = undefined("var i3_i: i3\nnew (a: string) => any (+1 overload)"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "new 1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i4_i",
//                     .Detail = undefined("var i4_i: i4\nnew (a: string) => any (+1 overload)"),
//                 },
//             },
//             .Excludes = &.{
//                 "i1",
//                 "i2",
//                 "i3",
//                 "i4",
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "19");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "19q", "var i1_i: i1\nnew (b: number) => any (+1 overload)", "new 1");
    _ = f.GoToMarker(undefined, "20");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "new 1", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "20q", "var i1_i: i1\nnew (a: string) => any (+1 overload)", "new 1");
    _ = f.GoToMarker(undefined, "21");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "this signature 1", .ParameterDocComment = "param a", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "21q", "var i1_i: i1\n(a: number) => number (+1 overload)", "this signature 1");
    _ = f.GoToMarker(undefined, "22");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "this is signature 2", .OverloadsCount = 2});
    _ = f.GoToMarker(undefined, "22q");
    try f.VerifyQuickInfoAt(undefined, "22q", "var i1_i: i1\n(b: string) => number (+1 overload)", "this is signature 2");
    // f.VerifyCompletions(undefined, "23", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "foo",
//                     .Detail = undefined("(method) i1.foo(a: number): number (+1 overload)"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "foo 1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "foo2",
//                     .Detail = undefined("(method) i1.foo2(a: number): number (+1 overload)"),
//                 },
//                 &.{
//                     .Label =  "foo3",
//                     .Detail = undefined("(method) i1.foo3(a: number): number (+1 overload)"),
//                 },
//                 &.{
//                     .Label =  "foo4",
//                     .Detail = undefined("(method) i1.foo4(a: number): number (+1 overload)"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "foo4 1",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "24");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "foo 1", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "24q", "(method) i1.foo(a: number): number (+1 overload)", "foo 1");
    _ = f.GoToMarker(undefined, "25");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "foo 2", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "25q", "(method) i1.foo(b: string): number (+1 overload)", "foo 2");
    _ = f.GoToMarker(undefined, "26");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "26q", "(method) i1.foo2(a: number): number (+1 overload)", "");
    _ = f.GoToMarker(undefined, "27");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "foo2 2", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "27q", "(method) i1.foo2(b: string): number (+1 overload)", "foo2 2");
    _ = f.GoToMarker(undefined, "28");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "28q", "(method) i1.foo3(a: number): number (+1 overload)", "");
    _ = f.GoToMarker(undefined, "29");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "29q", "(method) i1.foo3(b: string): number (+1 overload)", "");
    _ = f.GoToMarker(undefined, "30");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "foo4 1", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "30q", "(method) i1.foo4(a: number): number (+1 overload)", "foo4 1");
    _ = f.GoToMarker(undefined, "31");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "31q", "(method) i1.foo4(b: string): number (+1 overload)", "foo4 1");
    _ = f.GoToMarker(undefined, "32");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "new 2", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "32q", "var i2_i: i2\nnew (b: number) => any (+1 overload)", "new 2");
    _ = f.GoToMarker(undefined, "33");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "33q", "var i2_i: i2\nnew (a: string) => any (+1 overload)", "");
    _ = f.GoToMarker(undefined, "34");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "34q", "var i2_i: i2\n(a: number) => number (+1 overload)", "");
    _ = f.GoToMarker(undefined, "35");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "this is signature 2", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "35q", "var i2_i: i2\n(b: string) => number (+1 overload)", "this is signature 2");
    _ = f.GoToMarker(undefined, "36");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "new 2", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "36q", "var i3_i: i3\nnew (b: number) => any (+1 overload)", "new 2");
    _ = f.GoToMarker(undefined, "37");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "new 1", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "37q", "var i3_i: i3\nnew (a: string) => any (+1 overload)", "new 1");
    _ = f.GoToMarker(undefined, "38");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "this is signature 1", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "38q", "var i3_i: i3\n(a: number) => number (+1 overload)", "this is signature 1");
    _ = f.GoToMarker(undefined, "39");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "39q", "var i3_i: i3\n(b: string) => number (+1 overload)", "this is signature 1");
    _ = f.GoToMarker(undefined, "40");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "40q", "var i4_i: i4\nnew (b: number) => any (+1 overload)", "");
    _ = f.GoToMarker(undefined, "41");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "41q", "var i4_i: i4\nnew (a: string) => any (+1 overload)", "");
    _ = f.GoToMarker(undefined, "42");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "42q", "var i4_i: i4\n(a: number) => number (+1 overload)", "");
    _ = f.GoToMarker(undefined, "43");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "43q", "var i4_i: i4\n(b: string) => number (+1 overload)", "");
    // f.VerifyCompletions(undefined, "44", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "prop1",
//                     .Detail = undefined("(method) c.prop1(a: number): number (+1 overload)"),
//                 },
//                 &.{
//                     .Label =  "prop2",
//                     .Detail = undefined("(method) c.prop2(a: number): number (+1 overload)"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "prop2 1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "prop3",
//                     .Detail = undefined("(method) c.prop3(a: number): number (+1 overload)"),
//                 },
//                 &.{
//                     .Label =  "prop4",
//                     .Detail = undefined("(method) c.prop4(a: number): number (+1 overload)"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "prop4 1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "prop5",
//                     .Detail = undefined("(method) c.prop5(a: number): number (+1 overload)"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "prop5 1",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "45");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "45q", "(method) c.prop1(a: number): number (+1 overload)", "");
    _ = f.GoToMarker(undefined, "46");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "46q", "(method) c.prop1(b: string): number (+1 overload)", "");
    _ = f.GoToMarker(undefined, "47");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "prop2 1", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "47q", "(method) c.prop2(a: number): number (+1 overload)", "prop2 1");
    _ = f.GoToMarker(undefined, "48");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "48q", "(method) c.prop2(b: string): number (+1 overload)", "prop2 1");
    _ = f.GoToMarker(undefined, "49");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "49q", "(method) c.prop3(a: number): number (+1 overload)", "");
    _ = f.GoToMarker(undefined, "50");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "prop3 2", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "50q", "(method) c.prop3(b: string): number (+1 overload)", "prop3 2");
    _ = f.GoToMarker(undefined, "51");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "prop4 1", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "51q", "(method) c.prop4(a: number): number (+1 overload)", "prop4 1");
    _ = f.GoToMarker(undefined, "52");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "prop4 2", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "52q", "(method) c.prop4(b: string): number (+1 overload)", "prop4 2");
    _ = f.GoToMarker(undefined, "53");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "prop5 1", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "53q", "(method) c.prop5(a: number): number (+1 overload)", "prop5 1");
    _ = f.GoToMarker(undefined, "54");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "prop5 2", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "54q", "(method) c.prop5(b: string): number (+1 overload)", "prop5 2");
    _ = f.GoToMarker(undefined, "55");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "55q", "constructor c1(a: number): c1 (+1 overload)", "");
    _ = f.GoToMarker(undefined, "56");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "56q", "constructor c1(b: string): c1 (+1 overload)", "");
    _ = f.GoToMarker(undefined, "57");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "c2 1", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "57q", "constructor c2(a: number): c2 (+1 overload)", "c2 1");
    _ = f.GoToMarker(undefined, "58");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "58q", "constructor c2(b: string): c2 (+1 overload)", "c2 1");
    _ = f.GoToMarker(undefined, "59");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "59q", "constructor c3(a: number): c3 (+1 overload)", "");
    _ = f.GoToMarker(undefined, "60");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "c3 2", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "60q", "constructor c3(b: string): c3 (+1 overload)", "c3 2");
    _ = f.GoToMarker(undefined, "61");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "c4 1", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "61q", "constructor c4(a: number): c4 (+1 overload)", "c4 1");
    _ = f.GoToMarker(undefined, "62");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "c4 2", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "62q", "constructor c4(b: string): c4 (+1 overload)", "c4 2");
    _ = f.GoToMarker(undefined, "63");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "c5 1", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "63q", "constructor c5(a: number): c5 (+1 overload)", "c5 1");
    _ = f.GoToMarker(undefined, "64");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "c5 2", .OverloadsCount = 2});
    try f.VerifyQuickInfoAt(undefined, "64q", "constructor c5(b: string): c5 (+1 overload)", "c5 2");
    // f.VerifyCompletions(undefined, "65", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "c",
//                     .Detail = undefined("class c"),
//                 },
//                 &.{
//                     .Label =  "c1",
//                     .Detail = undefined("class c1"),
//                 },
//                 &.{
//                     .Label =  "c2",
//                     .Detail = undefined("class c2"),
//                 },
//                 &.{
//                     .Label =  "c3",
//                     .Detail = undefined("class c3"),
//                 },
//                 &.{
//                     .Label =  "c4",
//                     .Detail = undefined("class c4"),
//                 },
//                 &.{
//                     .Label =  "c5",
//                     .Detail = undefined("class c5"),
//                 },
//                 &.{
//                     .Label =  "c_i",
//                     .Detail = undefined("var c_i: c"),
//                 },
//                 &.{
//                     .Label =  "c1_i_1",
//                     .Detail = undefined("var c1_i_1: c1"),
//                 },
//                 &.{
//                     .Label =  "c2_i_1",
//                     .Detail = undefined("var c2_i_1: c2"),
//                 },
//                 &.{
//                     .Label =  "c3_i_1",
//                     .Detail = undefined("var c3_i_1: c3"),
//                 },
//                 &.{
//                     .Label =  "c4_i_1",
//                     .Detail = undefined("var c4_i_1: c4"),
//                 },
//                 &.{
//                     .Label =  "c5_i_1",
//                     .Detail = undefined("var c5_i_1: c5"),
//                 },
//                 &.{
//                     .Label =  "c1_i_2",
//                     .Detail = undefined("var c1_i_2: c1"),
//                 },
//                 &.{
//                     .Label =  "c2_i_2",
//                     .Detail = undefined("var c2_i_2: c2"),
//                 },
//                 &.{
//                     .Label =  "c3_i_2",
//                     .Detail = undefined("var c3_i_2: c3"),
//                 },
//                 &.{
//                     .Label =  "c4_i_2",
//                     .Detail = undefined("var c4_i_2: c4"),
//                 },
//                 &.{
//                     .Label =  "c5_i_2",
//                     .Detail = undefined("var c5_i_2: c5"),
//                 },
//                 &.{
//                     .Label =  "multiOverload",
//                     .Detail = undefined("function multiOverload(a: number): string (+2 overloads)"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "This is multiOverload F1 1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "ambientF1",
//                     .Detail = undefined("function ambientF1(a: number): string (+2 overloads)"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "This is ambient F1 1",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    try f.VerifyQuickInfoAt(undefined, "66", "var c1_i_1: c1", "");
    try f.VerifyQuickInfoAt(undefined, "67", "var c2_i_2: c2", "");
    try f.VerifyQuickInfoAt(undefined, "68", "var c3_i_2: c3", "");
    try f.VerifyQuickInfoAt(undefined, "69", "var c4_i_1: c4", "");
    try f.VerifyQuickInfoAt(undefined, "70", "var c5_i_1: c5", "");
    try f.VerifyQuickInfoAt(undefined, "71", "function multiOverload(a: number): string (+2 overloads)", "This is multiOverload F1 1");
    try f.VerifyQuickInfoAt(undefined, "72", "function multiOverload(b: string): string (+2 overloads)", "This is multiOverload F1 2");
    try f.VerifyQuickInfoAt(undefined, "73", "function multiOverload(c: boolean): string (+2 overloads)", "This is multiOverload F1 3");
    try f.VerifyQuickInfoAt(undefined, "74", "function ambientF1(a: number): string (+2 overloads)", "This is ambient F1 1");
    try f.VerifyQuickInfoAt(undefined, "75", "function ambientF1(b: string): string (+2 overloads)", "This is ambient F1 2");
    try f.VerifyQuickInfoAt(undefined, "76", "function ambientF1(c: boolean): boolean (+2 overloads)", "This is ambient F1 3");
    try f.VerifyQuickInfoAt(undefined, "77", "(parameter) aa: i3", "");
    try f.VerifyQuickInfoAt(undefined, "78", "constructor c1(a: number): c1 (+1 overload)", "");
    try f.VerifyQuickInfoAt(undefined, "79", "constructor c1(b: string): c1 (+1 overload)", "");
    try f.VerifyQuickInfoAt(undefined, "80", "constructor c1(a: number): c1 (+1 overload)", "");
    try f.VerifyQuickInfoAt(undefined, "81", "constructor c2(a: number): c2 (+1 overload)", "c2 1");
    try f.VerifyQuickInfoAt(undefined, "82", "constructor c2(b: string): c2 (+1 overload)", "c2 1");
    try f.VerifyQuickInfoAt(undefined, "83", "constructor c2(a: number): c2 (+1 overload)", "c2 1");
    try f.VerifyQuickInfoAt(undefined, "84", "constructor c3(a: number): c3 (+1 overload)", "");
    try f.VerifyQuickInfoAt(undefined, "85", "constructor c3(b: string): c3 (+1 overload)", "c3 2");
    try f.VerifyQuickInfoAt(undefined, "86", "constructor c3(a: number): c3 (+1 overload)", "");
    try f.VerifyQuickInfoAt(undefined, "87", "constructor c4(a: number): c4 (+1 overload)", "c4 1");
    try f.VerifyQuickInfoAt(undefined, "88", "constructor c4(b: string): c4 (+1 overload)", "c4 2");
    try f.VerifyQuickInfoAt(undefined, "89", "constructor c4(a: number): c4 (+1 overload)", "c4 1");
    try f.VerifyQuickInfoAt(undefined, "90", "constructor c5(a: number): c5 (+1 overload)", "c5 1");
    try f.VerifyQuickInfoAt(undefined, "91", "constructor c5(b: string): c5 (+1 overload)", "c5 2");
    try f.VerifyQuickInfoAt(undefined, "92", "constructor c5(a: number): c5 (+1 overload)", "c5 1");
    try f.VerifyQuickInfoAt(undefined, "93", "(method) c.prop1(a: number): number (+1 overload)", "");
    try f.VerifyQuickInfoAt(undefined, "94", "(method) c.prop1(b: string): number (+1 overload)", "");
    try f.VerifyQuickInfoAt(undefined, "95", "(method) c.prop1(a: number): number (+1 overload)", "");
    try f.VerifyQuickInfoAt(undefined, "96", "(method) c.prop2(a: number): number (+1 overload)", "prop2 1");
    try f.VerifyQuickInfoAt(undefined, "97", "(method) c.prop2(b: string): number (+1 overload)", "prop2 1");
    try f.VerifyQuickInfoAt(undefined, "98", "(method) c.prop2(a: number): number (+1 overload)", "prop2 1");
    try f.VerifyQuickInfoAt(undefined, "99", "(method) c.prop3(a: number): number (+1 overload)", "");
    try f.VerifyQuickInfoAt(undefined, "100", "(method) c.prop3(b: string): number (+1 overload)", "prop3 2");
    try f.VerifyQuickInfoAt(undefined, "101", "(method) c.prop3(a: number): number (+1 overload)", "");
    try f.VerifyQuickInfoAt(undefined, "102", "(method) c.prop4(a: number): number (+1 overload)", "prop4 1");
    try f.VerifyQuickInfoAt(undefined, "103", "(method) c.prop4(b: string): number (+1 overload)", "prop4 2");
    try f.VerifyQuickInfoAt(undefined, "104", "(method) c.prop4(a: number): number (+1 overload)", "prop4 1");
    try f.VerifyQuickInfoAt(undefined, "105", "(method) c.prop5(a: number): number (+1 overload)", "prop5 1");
    try f.VerifyQuickInfoAt(undefined, "106", "(method) c.prop5(b: string): number (+1 overload)", "prop5 2");
    try f.VerifyQuickInfoAt(undefined, "107", "(method) c.prop5(a: number): number (+1 overload)", "prop5 1");
}

test "TestGoToDefinitionJsDocImportTag2" {
    const content =
        \\// @allowJS: true
        \\// @checkJs: true
        \\// @Filename: /b.ts
        \\/*2*/export interface A { }
        \\// @Filename: /a.js
        \\/**
        \\ * @import { A } [|from/*1*/|]       "./b"
        \\ */
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestSmartSelection_punctuationPriority" {
    const content =
        \\console/**/.log();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSelectionRanges(undefined);
}

test "TestIndirectJsRequireRename" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /bin/serverless.js
        \\require('../lib/classes/Error').log/**/Warning(
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestGoToImplementationLocal_00" {
    const content =
        \\he/*function_call*/llo();
        \\function [|hello|]() {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "function_call");
}

test "TestQuickInfoForGenericPrototypeMember" {
    const content =
        \\class C<T> {
        \\   foo(x: T) { }
        \\}
        \\var x = new /*1*/C<any>();
        \\var y = C.proto/*2*/type;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "constructor C<any>(): C<any>", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(property) C<T>.prototype: C<any>", "");
}

test "TestImportNameCodeFix_jsx5" {
    const content =
        \\// @lib: es5
        \\// @jsx: react
        \\// @module: esnext
        \\// @esModuleInterop: true
        \\// @moduleResolution: bundler
        \\// @Filename: /node_modules/react/index.d.ts
        \\export = React;
        \\export as namespace React;
        \\declare namespace React {
        \\    class Component {}
        \\}
        \\// @Filename: /node_modules/react-native/index.d.ts
        \\import * as React from "react";
        \\export class Text extends React.Component {};
        \\// @Filename: /a.tsx
        \\import React from "react";
        \\<[|Text|] />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.tsx");
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add import from \"react-native\"",
        .NewFileContent = "import React from \"react\";\nimport { Text } from \"react-native\";\n<Text />;",
        .Index = 0,
    });
}

test "TestGoToTypeDefinitionModifiers" {
    const content =
        \\// @lib: es5
        \\// @Filename: /a.ts
        \\/*export*/export class A/*A*/ {
        \\
        \\    /*private*/private z/*z*/: string;
        \\
        \\    /*private2*/private y/*y*/: A;
        \\
        \\    /*readonly*/readonly x/*x*/: string;
        \\
        \\    /*async*/async a/*a*/() {  }
        \\
        \\    /*override*/override b/*b*/() {}
        \\
        \\    /*public1*/public/*public2*/ as/*multipleModifiers*/ync c/*c*/() { }
        \\}
        \\
        \\exp/*exportFunction*/ort function foo/*foo*/() { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToTypeDefinition(undefined, "export", "A", "private", "z", "private2", "y", "readonly", "x", "async", "a", "override", "b", "public1", "public2", "multipleModifiers", "c", "exportFunction", "foo");
}

test "TestReferencesToNonPropertyNameStringLiteral" {
    const content =
        \\// @lib: es5
        \\const str: string = "hello/*1*/";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestRenameFunctionParameter2" {
    const content =
        \\/**
        \\ * @param {number} p
        \\ */
        \\const foo = function foo(p/**/) {
        \\    return p;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , "");
}

test "TestInlayHintsFunctionParameterTypes4" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /a.js
        \\class Foo {
        \\    #value = 0;
        \\    get foo() { return this.#value; }
        \\    /**
        \\     * @param {number} value
        \\     */
        \\    set foo(value) { this.#value = value; }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayFunctionParameterTypeHints = core.TSTrue}});
}

test "TestImportNameCodeFix_barrelExport5" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{ "type": "module" }
        \\// @Filename: /foo/a.ts
        \\export const A = 0;
        \\// @Filename: /foo/b.ts
        \\export {};
        \\A/*sibling*/
        \\// @Filename: /foo/index.ts
        \\export * from "./a.js";
        \\export * from "./b.js";
        \\// @Filename: /index.ts
        \\export * from "./foo/index.js";
        \\export * from "./src/index.js";
        \\// @Filename: /src/a.ts
        \\export {};
        \\A/*parent*/
        \\// @Filename: /src/index.ts
        \\export * from "./a.js";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "sibling", &.{"./a.js", "./index.js", "../index.js"}, null );
    // try f.VerifyImportFixModuleSpecifiers(undefined, "parent", &.{"../foo/a.js", "../foo/index.js", "../index.js"}, null );
}

test "TestImportTypeCompletions5" {
    const content =
        \\// @allowSyntheticDefaultImports: false
        \\// @esModuleInterop: false
        \\// @module: commonjs
        \\// @Filename: /foo.ts
        \\interface Foo { };
        \\export = Foo;
        \\// @Filename: /bar.ts
        \\ [|import type f/**/|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/bar.ts");
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "Foo",
//                     .InsertText = undefined("import type Foo = require(\"./foo\");"),
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./foo",
//                         },
//                     },
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "Foo",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestQuickInfoFromContextualUnionType2" {
    const content =
        \\// @strict: true
        \\function test1(arg: { prop: "foo" }) {}
        \\test1({ /*1*/prop: "bar" });
        \\
        \\function test2(arg: { prop: "foo" } | undefined) {}
        \\test2({ /*2*/prop: "bar" });
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(property) prop: \"foo\"", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(property) prop: \"foo\"", "");
}

test "TestGetOccurrencesSetAndGet" {
    const content =
        \\class Foo {
        \\    [|set|] bar(b: any) {
        \\    }
        \\
        \\    public [|get|] bar(): any {
        \\        return undefined;
        \\    }
        \\
        \\    public set set(s: any) {
        \\    }
        \\
        \\    public get set(): any {
        \\        return undefined;
        \\    }
        \\
        \\    public set get(g: any) {
        \\    }
        \\
        \\    public get get(): any {
        \\        return undefined;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestFormattingOfMultilineBlockConstructs" {
    const content =
        \\namespace InternalModule/*1*/
        \\{
        \\}
        \\interface MyInterface/*2*/
        \\{
        \\}
        \\enum E/*3*/
        \\{
        \\}
        \\class MyClass/*4*/
        \\{
        \\constructor()/*cons*/
        \\{ }
        \\        public MyFunction()/*5*/
        \\        {
        \\                return 0;
        \\        }
        \\public get Getter()/*6*/
        \\{
        \\}
        \\public set Setter(x)/*7*/
        \\{
        \\}
        \\}
        \\function foo()/*8*/
        \\{
        \\{}/*9*/
        \\}
        \\(function()/*10*/
        \\{
        \\});
        \\(() =>/*11*/
        \\{
        \\});
        \\var x :/*12*/
        \\{};/*13*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "namespace InternalModule {");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "interface MyInterface {");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "enum E {");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "class MyClass {");
    _ = f.GoToMarker(undefined, "cons");
    try f.VerifyCurrentLineContent(undefined, "    constructor() { }");
    _ = f.GoToMarker(undefined, "5");
    try f.VerifyCurrentLineContent(undefined, "    public MyFunction() {");
    _ = f.GoToMarker(undefined, "6");
    try f.VerifyCurrentLineContent(undefined, "    public get Getter() {");
    _ = f.GoToMarker(undefined, "7");
    try f.VerifyCurrentLineContent(undefined, "    public set Setter(x) {");
    _ = f.GoToMarker(undefined, "8");
    try f.VerifyCurrentLineContent(undefined, "function foo() {");
    _ = f.GoToMarker(undefined, "9");
    try f.VerifyCurrentLineContent(undefined, "    { }");
    _ = f.GoToMarker(undefined, "10");
    try f.VerifyCurrentLineContent(undefined, "(function() {");
    _ = f.GoToMarker(undefined, "11");
    try f.VerifyCurrentLineContent(undefined, "(() => {");
    _ = f.GoToMarker(undefined, "12");
    try f.VerifyCurrentLineContent(undefined, "var x:");
    _ = f.GoToMarker(undefined, "13");
    try f.VerifyCurrentLineContent(undefined, "    {};");
}

test "TestMemberListOnFunctionParameter" {
    const content =
        \\namespace Test10 {
        \\    var x: string[] = [];
        \\    x.forEach(function (y) { y./**/} );
        \\}
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
//                 "charAt",
//             },
//             .Excludes = &.{
//                 "toFixed",
//             },
//         },
//     });
}

test "TestFormattingAfterChainedFatArrow" {
    const content =
        \\var x = n => p => {
        \\    while (true) {
        \\        void 0;
        \\    }/**/
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentLineContent(undefined, "    }");
}

test "TestCompletionListModuleMembers" {
    const content =
        \\ namespace Module {
        \\     var innerVariable = 1;
        \\     function innerFunction() { }
        \\     class innerClass { }
        \\     namespace innerModule { }
        \\     interface innerInterface {}
        \\     export var exportedVariable = 1;
        \\     export function exportedFunction() { }
        \\     export class exportedClass { }
        \\     export namespace exportedModule { export var exportedInnerModuleVariable = 1; }
        \\     export interface exportedInterface {}
        \\ }
        \\
        \\Module./*ValueReference*/;
        \\
        \\var x : Module./*TypeReference*/
        \\
        \\class TestClass extends Module./*TypeReferenceInExtendsList*/ { }
        \\
        \\interface TestInterface implements Module./*TypeReferenceInImplementsList*/ { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"ValueReference", "TypeReferenceInExtendsList"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "exportedFunction",
//                 "exportedVariable",
//                 "exportedClass",
//                 "exportedModule",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"TypeReference", "TypeReferenceInImplementsList"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "exportedClass",
//                 "exportedInterface",
//             },
//         },
//     });
}

test "TestUnusedFunctionInNamespace1" {
    const content =
        \\// @noUnusedLocals: true
        \\[| namespace greeter {
        \\  // some legit comments
        \\  function function1() {
        \\  }/*1*/
        \\} |]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "namespace greeter {\n   // some legit comments\n}", false, 0, 0);
}

test "TestRecursiveInternalModuleImport" {
    const content =
        \\namespace M {
        \\    import A = B;
        \\    import /**/B = A;
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyQuickInfoExists(undefined);
}

test "TestFindAllRefsObjectBindingElementPropertyName06" {
    const content =
        \\interface I {
        \\    /*0*/property1: number;
        \\    property2: string;
        \\}
        \\
        \\var elems: I[];
        \\for (let { /*1*/property1: p } of elems) {
        \\}
        \\for (let { /*2*/property1 } of elems) {
        \\}
        \\for (var { /*3*/property1: p1 } of elems) {
        \\}
        \\var p2;
        \\for ({ /*4*/property1 : p2 } of elems) {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "0", "1", "3", "4", "2");
}

test "TestImportStatementCompletions_js2" {
    const content =
        \\// @allowJs: true
        \\// @target: es2020
        \\// @checkJs: true
        \\// @module: commonjs
        \\// @esModuleInterop: false
        \\// @allowSyntheticDefaultImports: false
        \\// @noEmit: true
        \\// @Filename: /node_modules/react/index.d.ts
        \\declare namespace React {
        \\   export class Component {}
        \\}
        \\export = React;
        \\// @Filename: /test.js
        \\[|import R/**/|]
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
//             .Exact = &.{
//                 &.{
//                     .Label =      "React",
//                     .InsertText = undefined("import * as React from \"react\";"),
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "react",
//                         },
//                     },
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "React",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestGetJavaScriptQuickInfo7" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: file.js
        \\/**
        \\ * This is a very cool function that is very nice.
        \\ * @returns something
        \\ * @param p anotherthing
        \\ */
        \\function a1(p) {
        \\    try {
        \\        throw new Error('x');
        \\    } catch (x) { x--; }
        \\    return 23;
        \\}
        \\
        \\x - /**/a1()
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "function a1(p: any): number", "This is a very cool function that is very nice.");
}

test "TestMemberListInReopenedEnum" {
    const content =
        \\namespace M {
        \\    enum E {
        \\        A, B
        \\    }
        \\    enum E {
        \\        C = 0, D
        \\    }
        \\    var x = E./*1*/
        \\}
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
//             .Exact = &.{
//                 &.{
//                     .Label =  "A",
//                     .Detail = undefined("(enum member) E.A = 0"),
//                 },
//                 &.{
//                     .Label =  "B",
//                     .Detail = undefined("(enum member) E.B = 1"),
//                 },
//                 &.{
//                     .Label =  "C",
//                     .Detail = undefined("(enum member) E.C = 0"),
//                 },
//                 &.{
//                     .Label =  "D",
//                     .Detail = undefined("(enum member) E.D = 1"),
//                 },
//             },
//         },
//     });
}

test "TestGoToImplementationInterfaceMethod_02" {
    const content =
        \\interface Foo {
        \\    he/*declaration*/llo(): void
        \\}
        \\
        \\abstract class AbstractBar implements Foo {
        \\    abstract hello(): void;
        \\}
        \\
        \\class Bar extends AbstractBar {
        \\    [|hello|]() {}
        \\}
        \\
        \\function whatever(a: AbstractBar) {
        \\    a.he/*function_call*/llo();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "function_call", "declaration");
}

test "TestGetOccurrencesSwitchCaseDefault5" {
    const content =
        \\switch/*1*/ (10) {
        \\    case/*2*/ 1:
        \\    case/*3*/ 2:
        \\    case/*4*/ 4:
        \\    case/*5*/ 8:
        \\        foo: switch/*6*/ (20) {
        \\            case/*7*/ 1:
        \\            case/*8*/ 2:
        \\                break/*9*/;
        \\            default/*10*/:
        \\                break foo;
        \\        }
        \\    case/*11*/ 0xBEEF:
        \\    default/*12*/:
        \\        break/*13*/;
        \\    case 16/*14*/:
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Markers()));
}

test "TestNgProxy3" {
    const content =
        \\// @Filename: tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "lib": ["es5"],
        \\        "plugins": [
        \\            { "name": "create-thrower" }
        \\        ]
        \\    },
        \\    "files": ["a.ts"]
        \\}
        \\// @Filename: a.ts
        \\let x = [1, 2];
        \\x/**/
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyQuickInfoIs(undefined, "let x: number[]", "");
}

test "TestFormatSelectionWithTrivia2" {
    const content =
        \\/*begin*/;    
        \\    
        \\/*end*/    
        \\    
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatSelection(undefined, "begin", "end");
    try f.VerifyCurrentFileContent(undefined, ";\n\n\n    ");
}

test "TestGetOccurrencesStatic1" {
    const content =
        \\namespace m {
        \\    export class C1 {
        \\        public pub1;
        \\        public pub2;
        \\        private priv1;
        \\        private priv2;
        \\        protected prot1;
        \\        protected prot2;
        \\
        \\        public public;
        \\        private private;
        \\        protected protected;
        \\
        \\        public constructor(public a, private b, protected c, public d, private e, protected f) {
        \\            this.public = 10;
        \\            this.private = 10;
        \\            this.protected = 10;
        \\        }
        \\
        \\        public get x() { return 10; }
        \\        public set x(value) { }
        \\
        \\        public [|static|] statPub;
        \\        private [|static|] statPriv;
        \\        protected [|static|] statProt;
        \\    }
        \\
        \\    export interface I1 {
        \\    }
        \\
        \\    export declare namespace ma.m1.m2.m3 {
        \\        interface I2 {
        \\        }
        \\    }
        \\
        \\    export namespace mb.m1.m2.m3 {
        \\        declare var foo;
        \\
        \\        export class C2 {
        \\            public pub1;
        \\            private priv1;
        \\            protected prot1;
        \\
        \\            protected constructor(public public, protected protected, private private) {
        \\                public = private = protected;
        \\            }
        \\        }
        \\    }
        \\
        \\    declare var ambientThing: number;
        \\    export var exportedThing = 10;
        \\    declare function foo(): string;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestFormattingObjectLiteralOpenCurlyNewline" {
    const content =
        \\
        \\var clear =
        \\{
        \\    outerKey:
        \\    {
        \\        innerKey: 1,
        \\        innerKey2:
        \\            2
        \\    }
        \\};
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "\nvar clear =\n{\n    outerKey:\n    {\n        innerKey: 1,\n        innerKey2:\n            2\n    }\n};\n");
    // f.GetOptions();
    // f.Configure(undefined, opts444);
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "\nvar clear =\n    {\n        outerKey:\n            {\n                innerKey: 1,\n                innerKey2:\n                    2\n            }\n    };\n");
}

test "TestMemberListInFunctionCall" {
    const content =
        \\function aa(x: any) {}
        \\aa({
        \\  "1": function () {
        \\    var b = "";
        \\    b/**/;
        \\  }
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, ".");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "charAt",
//             },
//         },
//     });
}

test "TestAutoImportProvider_exportMap3" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "nodenext",
        \\    "lib": ["es5"]
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{
        \\  "type": "module",
        \\  "dependencies": {
        \\    "dependency": "^1.0.0"
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/dependency/package.json
        \\{
        \\  "name": "dependency",
        \\  "version": "1.0.0",
        \\  "main": "./lib/index.js",
        \\  "exports": "./lib/lol.d.ts"
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/dependency/lib/index.d.ts
        \\export function fooFromIndex(): void;
        \\// @Filename: /home/src/workspaces/project/node_modules/dependency/lib/lol.d.ts
        \\export function fooFromLol(): void;
        \\// @Filename: /home/src/workspaces/project/src/foo.ts
        \\fooFrom/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "fooFromLol",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "dependency",
//                         },
//                     },
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                 },
//             },
//             .Excludes = &.{
//                 "fooFromIndex",
//             },
//         },
//     });
}

test "TestFormattingRegexes" {
    const content =
        \\removeAllButLast(sortedTypes, undefinedType, /keepNullableType**/ true)/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, ";");
    try f.VerifyCurrentLineContent(undefined, "removeAllButLast(sortedTypes, undefinedType, /keepNullableType**/ true);");
}

test "TestCompletionInUncheckedJSFile" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: false
        \\// @Filename: index.js
        \\function hello() {
        \\
        \\}
        \\
        \\const goodbye = 5;
        \\
        \\console./*0*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "0", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "hello",
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//                 &.{
//                     .Label =    "goodbye",
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//             },
//         },
//     });
}

test "TestNavigationBarItemsMissingName2" {
    const content =
        \\/**
        \\ * This is a class.
        \\ */
        \\class /* But it has no name! */ {
        \\    foo() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestQuickInfoInheritDoc5" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: quickInfoInheritDoc5.js
        \\function A() {}
        \\
        \\class B extends A {
        \\    /**
        \\     * @inheritdoc
        \\     */
        \\    static /**/value() {
        \\        return undefined;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestImportNameCodeFixNewImportFileQuoteStyleMixed1" {
    const content =
        \\[|import { v2 } from './module2';
        \\import { v3 } from "./module3";
        \\
        \\f1/*0*/();|]
        \\// @Filename: module1.ts
        \\export function f1() {}
        \\// @Filename: module2.ts
        \\export var v2 = 6;
        \\// @Filename: module3.ts
        \\export var v3 = 6;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from './module1';\nimport { v2 } from './module2';\nimport { v3 } from \"./module3\";\n\nf1();",
    }, null );
}

test "TestCompletionForStringLiteralNonrelativeImportTypings3" {
    const content =
        \\// @Filename: subdirectory/test0.ts
        \\/// <reference types="m/*types_ref0*/" />
        \\import * as foo1 from "m/*import_as0*/
        \\import foo2 = require("m/*import_equals0*/
        \\var foo3 = require("m/*require0*/
        \\// @Filename: subdirectory/node_modules/@types/module-x/index.d.ts
        \\export var x = 9;
        \\// @Filename: subdirectory/package.json
        \\{ "dependencies": { "@types/module-x": "latest" } }
        \\// @Filename: node_modules/@types/module-y/index.d.ts
        \\export var y = 9;
        \\// @Filename: package.json
        \\{ "dependencies": { "@types/module-y": "latest" } }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"types_ref0", "import_as0", "import_equals0", "require0"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "module-x",
//                 "module-y",
//             },
//         },
//     });
}

test "TestSyntacticClassificationsConflictMarkers1" {
    const content =
        \\class C {
        \\<<<<<<< HEAD
        \\    v = 1;
        \\=======
        \\    v = 2;
        \\>>>>>>> Branch - a
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "class.declaration", .Text = "C"},
//         .{.Type = "property.declaration", .Text = "v"},
//     });
}

test "TestGetJavaScriptCompletions21" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: file.js
        \\class Prv {
        \\    #privatething = 1;
        \\    notSoPrivate = 1;
        \\}
        \\new Prv()['[|/**/|]'];
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
//                     .Label = "notSoPrivate",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "notSoPrivate",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestImportNameCodeFixUMDGlobalReact0" {
    const content =
        \\// @jsx: react
        \\// @allowSyntheticDefaultImports: false
        \\// @module: es2015
        \\// @moduleResolution: bundler
        \\// @Filename: /node_modules/@types/react/index.d.ts
        \\export = React;
        \\export as namespace React;
        \\declare namespace React {
        \\    export class Component { render(): JSX.Element | null; }
        \\}
        \\declare global {
        \\    namespace JSX {
        \\        interface Element {}
        \\    }
        \\}
        \\// @Filename: /a.tsx
        \\[|import { Component } from "react";
        \\export class MyMap extends Component { }
        \\<MyMap/>;|]
        \\// @Filename: /b.tsx
        \\[|import { Component } from "react";
        \\<></>;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.tsx");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import * as React from \"react\";\nimport { Component } from \"react\";\nexport class MyMap extends Component { }\n<MyMap/>;",
    }, null );
    _ = f.GoToFile(undefined, "/b.tsx");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import * as React from \"react\";\nimport { Component } from \"react\";\n<></>;",
    }, null );
}

test "TestGoToDefinitionMetaProperty" {
    const content =
        \\// @Filename: /a.ts
        \\im/*1*/port.met/*2*/a;
        \\function /*functionDefinition*/f() { n/*3*/ew.[|t/*4*/arget|]; }
        \\// @Filename: /b.ts
        \\im/*5*/port.m;
        \\class /*classDefinition*/c { constructor() { n/*6*/ew.[|t/*7*/arget|]; } }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1", "2", "3", "4", "5", "6", "7");
}

test "TestJsdocTypedefTagGoToDefinition" {
    const content =
        \\// @lib: es5
        \\// @allowNonTsExtensions: true
        \\// @Filename: jsdocCompletion_typedef.js
        \\/**
        \\ * @typedef {Object} Person
        \\ * @property {string} /*1*/personName
        \\ * @property {number} personAge
        \\ */
        \\
        \\/**
        \\ * @typedef {{ /*2*/animalName: string, animalAge: number }} Animal
        \\ */
        \\
        \\/** @type {Person} */
        \\var person; person.[|personName/*3*/|]
        \\
        \\/** @type {Animal} */
        \\var animal; animal.[|animalName/*4*/|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "3", "4");
}

test "TestCodeFixUseBigIntLiteralWithNumericSeparators" {
    const content =
        \\6_402_373_705_728_000;  // 18! < 2 ** 53
        \\0x16_BE_EC_CA_73_00_00; // 18! < 2 ** 53
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined, "useBigintLiteral");
}

test "TestQuickInfoForTypeParameterInTypeAlias1" {
    const content =
        \\type Ctor<AA> = new () => A/*1*/A;
        \\type MixinCtor<AA> = new () => AA & { constructor: MixinCtor<A/*2*/A> };
        \\type NestedCtor<AA> = new() => AA & (new () => AA & { constructor: NestedCtor<A/*3*/A> });
        \\type Method<AA> = { method(): A/*4*/A };
        \\type Construct<AA> = { new(): A/*5*/A };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(type parameter) AA in type Ctor<AA>", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(type parameter) AA in type MixinCtor<AA>", "");
    try f.VerifyQuickInfoAt(undefined, "3", "(type parameter) AA in type NestedCtor<AA>", "");
    try f.VerifyQuickInfoAt(undefined, "4", "(type parameter) AA in type Method<AA>", "");
    try f.VerifyQuickInfoAt(undefined, "5", "(type parameter) AA in type Construct<AA>", "");
}

test "TestCodeFixClassImplementInterfaceConstructorName2" {
    const content =
        \\interface I {
        \\    constructor(): number;
        \\}
        \\class C implements I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "interface I {\n    constructor(): number;\n}\nclass C implements I {\n    [\"constructor\"](): number {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestCompletionEntryForDeferredMappedTypeMembers" {
    const content =
        \\// @Filename: test.ts
        \\interface A { a: A }
        \\declare let a: A;
        \\type Deep<T> = { [K in keyof T]: Deep<T[K]> }
        \\declare function foo<T>(deep: Deep<T>): T;
        \\const out = foo(a);
        \\out./*1*/a
        \\out.a./*2*/a
        \\out.a.a./*3*/a
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, f.Markers(), &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "a",
//             },
//         },
//     });
}

test "TestReferencesForMergedDeclarations7" {
    const content =
        \\interface Foo { }
        \\namespace Foo {
        \\    export interface /*1*/Bar { }
        \\    export module /*2*/Bar { export interface Baz { } }
        \\    export function /*3*/Bar() { }
        \\}
        \\
        \\// module, value and type
        \\import a2 = Foo./*4*/Bar;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestTsxQuickInfo3" {
    const content =
        \\//@Filename: file.tsx
        \\// @jsx: preserve
        \\// @noLib: true
        \\interface OptionProp {
        \\    propx: 2
        \\}
        \\class Opt extends React.Component<OptionProp, {}> {
        \\    render() {
        \\        return <div>Hello</div>;
        \\    }
        \\}
        \\const obj1: OptionProp = {
        \\    propx: 2
        \\}
        \\let y1 = <O/*1*/pt pro/*2*/px={2} />;
        \\let y2 = <Opt {...ob/*3*/j1} />;
        \\let y2 = <Opt {...obj1} pr/*4*/opx />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "class Opt", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(property) propx: number", "");
    try f.VerifyQuickInfoAt(undefined, "3", "const obj1: OptionProp", "");
    try f.VerifyQuickInfoAt(undefined, "4", "(property) propx: true", "");
}

test "TestQuickInfoForDestructuringShorthandInitializer" {
    const content =
        \\let a = '';
        \\let b: string;
        \\({b = /**/a} = {b: 'b'});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "let a: string", "");
}

test "TestImportNameCodeFix_pathsWithoutBaseUrl1" {
    const content =
        \\// @Filename: tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "commonjs",
        \\    "paths": {
        \\      "@app/*": ["./lib/*"]
        \\    }
        \\  }
        \\}
        \\// @Filename: index.ts
        \\utils/**/
        \\// @Filename: lib/utils.ts
        \\export const utils = {};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { utils } from \"@app/utils\";\n\nutils",
    }, null );
}

test "TestFormatVariableDeclarationList" {
    const content =
        \\/*1*/var   fun1   =   function   (     )     {
        \\/*2*/            var               x   =   'foo'             ,
        \\/*3*/                z   =   'bar'           ;
        \\/*4*/                return  x            ;
        \\/*5*/},
        \\
        \\/*6*/fun2   =   (                function        (   f               )   {
        \\/*7*/            var   fun   =   function   (        )       {
        \\/*8*/                        console         .  log             (           f     (  )  )       ;
        \\/*9*/            },
        \\/*10*/            x   =   'Foo'           ;
        \\/*11*/                return   fun            ;
        \\/*12*/}   (           fun1            )   )       ;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "var fun1 = function() {");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "    var x = 'foo',");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "        z = 'bar';");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "    return x;");
    _ = f.GoToMarker(undefined, "5");
    try f.VerifyCurrentLineContent(undefined, "},");
    _ = f.GoToMarker(undefined, "6");
    try f.VerifyCurrentLineContent(undefined, "    fun2 = (function(f) {");
    _ = f.GoToMarker(undefined, "7");
    try f.VerifyCurrentLineContent(undefined, "        var fun = function() {");
    _ = f.GoToMarker(undefined, "8");
    try f.VerifyCurrentLineContent(undefined, "            console.log(f());");
    _ = f.GoToMarker(undefined, "9");
    try f.VerifyCurrentLineContent(undefined, "        },");
    _ = f.GoToMarker(undefined, "10");
    try f.VerifyCurrentLineContent(undefined, "            x = 'Foo';");
    _ = f.GoToMarker(undefined, "11");
    try f.VerifyCurrentLineContent(undefined, "        return fun;");
    _ = f.GoToMarker(undefined, "12");
    try f.VerifyCurrentLineContent(undefined, "    }(fun1));");
}

test "TestQuickInfoOnErrorTypes1" {
    const content =
        \\var /*A*/f: {
        \\    x: number;
        \\    <
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "A", "var f: {\n    (): any;\n    x: number;\n}", "");
}

test "TestMultiModuleFundule" {
    const content =
        \\// @strict: false
        \\function C(x: number) { }
        \\
        \\namespace C {
        \\    export var x = 1;
        \\}
        \\namespace C {
        \\    export function foo() { }
        \\}
        \\
        \\var /*2*/r = C(/*1*/
        \\var /*4*/r2 = new C(/*3*/ // using void returning function as constructor
        \\var r3 = C./*5*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "C",
//             },
//         },
//     });
    _ = f.Insert(undefined, "C.x);");
    try f.VerifyQuickInfoAt(undefined, "2", "var r: void", "");
    // f.VerifyCompletions(undefined, "3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "C",
//             },
//         },
//     });
    _ = f.Insert(undefined, "C.x);");
    try f.VerifyQuickInfoAt(undefined, "4", "var r2: any", "");
    // f.VerifyCompletions(undefined, "5", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "x",
//                 "foo",
//             },
//         },
//     });
    _ = f.Insert(undefined, "x;");
    try f.VerifyNoErrors(undefined);
}

test "TestQuickInfoJsDocTags12" {
    const content =
        \\/**
        \\ * @param {Object} options the args object
        \\ * @param {number} options.a first number
        \\ * @param {number} options.b second number
        \\ * @param {Function} callback the callback function
        \\ * @returns {number}
        \\ */
        \\function /**/f(options, callback = null) {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestRenameLocationsForClassExpression01" {
    const content =
        \\class Foo {
        \\}
        \\
        \\var x = [|class [|{| "contextRangeIndex": 0 |}Foo|] {
        \\    doIt() {
        \\        return [|Foo|];
        \\    }
        \\
        \\    static doItStatically() {
        \\        return [|Foo|].y;
        \\    }
        \\}|]
        \\
        \\var y = class {
        \\   getSomeName() {
        \\      return Foo
        \\   }
        \\}
        \\var z = class Foo {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "Foo");
}

test "TestGoToImplementationInterface_05" {
    const content =
        \\interface Fo/*interface_definition*/o {
        \\    (a: number): void
        \\}
        \\
        \\let bar2 = <Foo> [|function(a) {}|];
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "interface_definition");
}

test "TestInlayHintsThisParameter" {
    const content =
        \\interface I {
        \\    a: number;
        \\}
        \\
        \\declare function fn(
        \\    callback: (a: number, b: string) => void
        \\): void;
        \\
        \\
        \\fn(function (this, a, b) { });
        \\fn(function (this: I, a, b) { });
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayFunctionParameterTypeHints = core.TSTrue}});
}

test "TestReferencesForClassMembersExtendingGenericClass" {
    const content =
        \\class Base<T> {
        \\    /*a1*/a: this;
        \\    /*method1*/method<U>(a?:T, b?:U): this { }
        \\}
        \\class MyClass extends Base<number> {
        \\    /*a2*/a;
        \\    /*method2*/method() { }
        \\}
        \\
        \\var c: MyClass;
        \\c./*a3*/a;
        \\c./*method3*/method();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "a1", "a2", "a3", "method1", "method2", "method3");
}

test "TestImportNameCodeFixNewImportNodeModules2" {
    const content =
        \\[|f1/*0*/();|]
        \\// @Filename: ../package.json
        \\{ "dependencies": { "fake-module": "latest" } }
        \\// @Filename: ../node_modules/fake-module/notindex.d.ts
        \\export var v1 = 5;
        \\export function f1();
        \\// @Filename: ../node_modules/fake-module/notindex.js
        \\module.exports = {
        \\   v1: 5,
        \\   f1: function () {}
        \\};
        \\// @Filename: ../node_modules/fake-module/package.json
        \\{ "main":"./notindex.js", "typings":"./notindex.d.ts" }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from \"fake-module\";\n\nf1();",
    }, null );
}

test "TestReferencesForInheritedProperties5" {
    const content =
        \\interface interface1 extends interface1 {
        \\   /*1*/doStuff(): void;
        \\   /*2*/propName: string;
        \\}
        \\interface interface2 extends interface1 {
        \\   doStuff(): void;
        \\   propName: string;
        \\}
        \\
        \\var v: interface1;
        \\v.propName;
        \\v.doStuff();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestJsDocSee1" {
    const content =
        \\interface [|/*def1*/Foo|] {
        \\    foo: string
        \\}
        \\namespace NS {
        \\    export interface [|/*def2*/Bar|] {
        \\        baz: Foo
        \\    }
        \\}
        \\/** @see {/*use1*/[|Foo|]} foooo*/
        \\const a = ""
        \\/** @see {NS./*use2*/[|Bar|]} ns.bar*/
        \\const b = ""
        \\/** @see /*use3*/[|Foo|] f1*/
        \\const c = ""
        \\/** @see NS./*use4*/[|Bar|] ns.bar*/
        \\const [|/*def3*/d|] = ""
        \\/** @see /*use5*/[|d|] dd*/
        \\const e = ""
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, false, "use1", "use2", "use3", "use4", "use5");
}

test "TestGenericCallSignaturesInNonGenericTypes1" {
    const content =
        \\interface WrappedObject<T> { }
        \\interface WrappedArray<T> { }
        \\interface Underscore {
        \\    <T>(list: T[]): WrappedArray<T>;
        \\    <T>(obj: T): WrappedObject<T>;
        \\}
        \\var _: Underscore;
        \\var a: number[];
        \\var /**/b = _(a); 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "var b: WrappedArray<number>", "");
}

test "TestAutoImportFileExcludePatterns6" {
    const content =
        \\// @Filename: /src/vs/workbench/test.ts
        \\import { Parts } from './parts';
        \\export class /**/EditorParts implements Parts { }
        \\// @Filename: /src/vs/event/event.ts
        \\export interface Event {
        \\    (): string;
        \\}
        \\// @Filename: /src/vs/workbench/parts.ts
        \\import { Event } from '../event/event';
        \\export interface Parts {
        \\    readonly options: Event;
        \\}
        \\// @Filename: /src/vs/workbench/workbench.ts
        \\import { Event } from './canImport';
        \\export { Event };
        \\// @Filename: /src/vs/workbench/canImport.ts
        \\import { Event } from '../event/event';
        \\export { Event };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'Parts'",
        .NewFileContent = "import { Event } from './canImport';\nimport { Parts } from './parts';\nexport class EditorParts implements Parts {\n    options: Event;\n}",
        .Index =           0,
        .UserPreferences = &.{.AutoImportFileExcludePatterns = &.{"src/vs/workbench/workbench.ts"}},
    });
}

test "TestFindAllRefsNoImportClause" {
    const content =
        \\// @Filename: /a.ts
        \\/*1*/export const /*2*/x = 0;
        \\// @Filename: /b.ts
        \\import "./a";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestImportNameCodeFixNewImportFile1" {
    const content =
        \\[|/// <reference path="./tripleSlashReference.ts" />
        \\f1/*0*/();|]
        \\// @Filename: Module.ts
        \\export function f1() {}
        \\export var v1 = 5;
        \\// @Filename: tripleSlashReference.ts
        \\var x = 5;/*dummy*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "/// <reference path=\"./tripleSlashReference.ts\" />\n\nimport { f1 } from \"./Module\";\n\nf1();",
    }, null );
}

test "TestFindAllRefsWriteAccess" {
    const content =
        \\interface Obj {
        \\    [
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestFindAllReferencesLinkTag1" {
    const content =
        \\class C/*7*/ {
        \\    m/*1*/() { }
        \\    n/*2*/ = 1
        \\    static s/*3*/() { }
        \\    /**
        \\     * {@link m}
        \\     * @see {m}
        \\     * {@link C.m}
        \\     * @see {C.m}
        \\     * {@link C#m}
        \\     * @see {C#m}
        \\     * {@link C.prototype.m}
        \\     * @see {C.prototype.m}
        \\     */
        \\    p() { }
        \\    /**
        \\     * {@link n}
        \\     * @see {n}
        \\     * {@link C.n}
        \\     * @see {C.n}
        \\     * {@link C#n}
        \\     * @see {C#n}
        \\     * {@link C.prototype.n}
        \\     * @see {C.prototype.n}
        \\     */
        \\    q() { }
        \\    /**
        \\     * {@link s}
        \\     * @see {s}
        \\     * {@link C.s}
        \\     * @see {C.s}
        \\     */
        \\    r() { }
        \\}
        \\
        \\interface I/*8*/ {
        \\    a/*4*/()
        \\    b/*5*/: 1
        \\    /**
        \\     * {@link a}
        \\     * @see {a}
        \\     * {@link I.a}
        \\     * @see {I.a}
        \\     * {@link I#a}
        \\     * @see {I#a}
        \\     */
        \\    c()
        \\    /**
        \\     * {@link b}
        \\     * @see {b}
        \\     * {@link I.b}
        \\     * @see {I.b}
        \\     */
        \\    d()
        \\}
        \\
        \\function nestor() {
        \\    /** {@link r2} */
        \\    function ref() { }
        \\    /** @see {r2} */
        \\    function d3() { }
        \\    function r2/*6*/() { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8");
}

test "TestImportCompletionsPackageJsonImportsPattern_ts" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#*": "./src/*.ts"
        \\  }
        \\}
        \\// @Filename: /src/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /a.ts
        \\import {} from "/*1*/";
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
//                 "#something",
//             },
//         },
//     });
}

test "TestGoToImplementationInterfaceMethod_01" {
    const content =
        \\interface Foo {
        \\    hel/*declaration*/lo(): void;
        \\    okay?: number;
        \\}
        \\
        \\class Bar implements Foo {
        \\    [|hello|]() {}
        \\    public sure() {}
        \\}
        \\
        \\function whatever(a: Foo) {
        \\    a.he/*function_call*/llo();
        \\}
        \\
        \\whatever(new Bar());
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "function_call", "declaration");
}

test "TestQuickInfoNestedExportEqualExportDefault" {
    const content =
        \\export = (state, messages) => {
        \\   export/*1*/ default/*2*/ {
        \\   }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestCodeFixMissingTypeAnnotationOnExports20" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @lib: es2019
        \\export function foo () {
        \\    return Symbol();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFixAvailable(undefined, &.{"Add return type 'symbol'"});
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add return type 'symbol'",
        .NewFileContent = "export function foo (): symbol {\n    return Symbol();\n}",
        .Index = 0,
    });
}

test "TestReferenceInParameterPropertyDeclaration" {
    const content =
        \\// @Filename: file1.ts
        \\class Foo {
        \\    constructor(private /*1*/privateParam: number,
        \\        public /*2*/publicParam: string,
        \\        protected /*3*/protectedParam: boolean) {
        \\
        \\        let localPrivate = privateParam;
        \\        this.privateParam += 10;
        \\
        \\        let localPublic = publicParam;
        \\        this.publicParam += " Hello!";
        \\
        \\        let localProtected = protectedParam;
        \\        this.protectedParam = false;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestCompletionForStringLiteralNonrelativeImport9" {
    const content =
        \\// @Filename: tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "baseUrl": "./modules",
        \\        "paths": {
        \\            "module1": ["some/path/whatever.ts"],
        \\            "module2": ["some/other/path.ts"]
        \\        }
        \\    }
        \\}
        \\// @Filename: tests/test0.ts
        \\import * as foo1 from "m/*import_as0*/
        \\import foo2 = require("m/*import_equals0*/
        \\var foo3 = require("m/*require0*/
        \\// @Filename: some/path/whatever.ts
        \\export var x = 9;
        \\// @Filename: some/other/path.ts
        \\export var y = 10;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, f.Markers(), &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "module1",
//                 "module2",
//             },
//         },
//     });
}

test "TestRenameParameterPropertyDeclaration5" {
    const content =
        \\class Foo {
        \\    constructor([|protected [ [|{| "contextRangeIndex": 0 |}protectedParam|] ]|]) {
        \\        let myProtectedParam = [|protectedParam|];
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "protectedParam");
}

test "TestCompletionListInUnclosedFunction09" {
    const content =
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string = "hello", c: typeof x = "hello") {
        \\        var v = /*1*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "foo",
//                 "x",
//                 "y",
//                 "z",
//                 "bar",
//                 "a",
//                 "b",
//                 "c",
//             },
//         },
//     });
}

test "TestReferencesForMergedDeclarations5" {
    const content =
        \\interface /*1*/Foo { }
        \\module /*2*/Foo { export interface Bar { } }
        \\function /*3*/Foo() { }
        \\
        \\export = /*4*/Foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestStringLiteralCompletionsInArgUsingInferenceResultFromPreviousArg" {
    const content =
        \\// @strict: true
        \\// https://github.com/microsoft/TypeScript/issues/55545
        \\enum myEnum {
        \\  valA = "valA",
        \\  valB = "valB",
        \\}
        \\
        \\interface myEnumParamMapping {
        \\  ["valA"]: "1" | "2";
        \\  ["valB"]: "3" | "4";
        \\}
        \\
        \\function myFunction<K extends keyof typeof myEnum>(
        \\  a: K,
        \\  b: myEnumParamMapping[K],
        \\) {}
        \\
        \\myFunction("valA", "/*ts1*/");
        \\myFunction("valA", 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"ts1", "ts2", "ts3", "ts4"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "1",
//                 "2",
//             },
//         },
//     });
}

test "TestOutliningSpansSwitchCases" {
    const content =
        \\switch (undefined)[| {
        \\ case 0:[|
        \\   console.log(1)
        \\   console.log(2)
        \\   break;
        \\   console.log(3);|]
        \\ case 1:[|
        \\   break;|]
        \\ case 2:[|
        \\   break;
        \\   console.log(3);|]
        \\ case 3:[|
        \\   console.log(4);|]
        \\ 
        \\ case 4:
        \\ case 5:
        \\ case 6:[|
        \\
        \\
        \\   console.log(5);|]
        \\ 
        \\ case 7:[| console.log(6);|]
        \\
        \\ case 8:[| [|{
        \\   console.log(8);
        \\   break;
        \\ }|]
        \\ console.log(8);|]
        \\
        \\ default:[|
        \\   console.log(7);
        \\   console.log(8);|]
        \\}|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOutliningSpans(undefined);
}

test "TestFormatNoSpaceBeforeCloseBrace" {
    const content =
        \\foo(1, /* comment */    );
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "foo(1, /* comment */);");
}

test "TestSignatureHelpIteratorNext" {
    const content =
        \\// @lib: esnext
        \\declare const iterator: Iterator<string, void, number>;
        \\
        \\iterator.next(/*1*/);
        \\iterator.next(/*2*/ 0);
        \\
        \\declare const generator: Generator<string, void, number>;
        \\
        \\generator.next(/*3*/);
        \\generator.next(/*4*/ 0);
        \\
        \\declare const asyncIterator: AsyncIterator<string, void, number>;
        \\
        \\asyncIterator.next(/*5*/);
        \\asyncIterator.next(/*6*/ 0);
        \\
        \\declare const asyncGenerator: AsyncGenerator<string, void, number>;
        \\
        \\asyncGenerator.next(/*7*/);
        \\asyncGenerator.next(/*8*/ 0);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSignatureHelp(undefined);
}

test "TestCompletionListInUnclosedElementAccessExpression01" {
    const content =
        \\var x;
        \\var y = x[/*1*/
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
//             .Includes = &.{
//                 "x",
//             },
//         },
//     });
}

test "TestGoToDefinitionImport2" {
    const content =
        \\// @Filename: /b.ts
        \\/*2*/export const foo = 1;
        \\// @Filename: /a.ts
        \\import { foo } [|from/*1*/|]       "./b";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestImportNameCodeFixExistingImportEquals0" {
    const content =
        \\[|import ns = require("ambient-module");
        \\var x = v1/*0*/ + 5;|]
        \\// @Filename: ambientModule.ts
        \\declare module "ambient-module" {
        \\   export function f1();
        \\   export var v1;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import ns = require(\"ambient-module\");\nvar x = ns.v1 + 5;",
        "import { v1 } from \"ambient-module\";\nimport ns = require(\"ambient-module\");\nvar x = v1 + 5;",
    }, null );
}

test "TestQuickInfoDisplayPartsLocalFunction" {
    const content =
        \\function /*1*/outerFoo() {
        \\    function /*2*/foo(param: string, optionalParam?: string, paramWithInitializer = "hello", ...restParam: string[]) {
        \\    }
        \\    function /*3*/foowithoverload(a: string): string;
        \\    function /*4*/foowithoverload(a: number): number;
        \\    function /*5*/foowithoverload(a: any): any {
        \\        return a;
        \\    }
        \\    function /*6*/foowith3overload(a: string): string;
        \\    function /*7*/foowith3overload(a: number): number;
        \\    function /*8*/foowith3overload(a: boolean): boolean;
        \\    function /*9*/foowith3overload(a: any): any {
        \\        return a;
        \\    }
        \\    /*10*/foo("hello");
        \\    /*11*/foowithoverload("hello");
        \\    /*12*/foowithoverload(10);
        \\    /*13*/foowith3overload("hello");
        \\    /*14*/foowith3overload(10);
        \\    /*15*/foowith3overload(true);
        \\}
        \\/*16*/outerFoo();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestFormatSelectionWithTrivia3" {
    const content =
        \\if (true) {
        \\/*begin*/// test comment
        \\/*end*/}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatSelection(undefined, "begin", "end");
    try f.VerifyCurrentFileContent(undefined, "if (true) {\n    // test comment\n}");
}

test "TestCodeFixAddMissingAwait_notAvailableWithoutPromise" {
    const content =
        \\async function fn(a: {}, b: number) {
        \\  a + b;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined, "addMissingAwait");
}

test "TestCodeFixMissingTypeAnnotationOnExports49_private_name" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @moduleResolution: bundler
        \\// @target: es2018
        \\// @jsx: react-jsx
        \\export function two() {
        \\    const y = "";
        \\    return {} as typeof y;
        \\}
        \\
        \\export function three() {
        \\    type Z = string;
        \\    return {} as Z;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add return type '\"\"'",
        .NewFileContent = "export function two(): \"\" {\n    const y = \"\";\n    return {} as typeof y;\n}\n\nexport function three() {\n    type Z = string;\n    return {} as Z;\n}",
        .Index = 0,
    });
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add return type 'string'",
        .NewFileContent = "export function two() {\n    const y = \"\";\n    return {} as typeof y;\n}\n\nexport function three(): string {\n    type Z = string;\n    return {} as Z;\n}",
        .Index = 1,
    });
}

test "TestImportCompletionsPackageJsonImportsPattern2" {
    const content =
        \\// @module: node18
        \\// @allowImportingTsExtensions: true
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#*": "./src/*"
        \\  }
        \\}
        \\// @Filename: /src/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /a.ts
        \\import {} from "/*1*/";
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
//                 "#something.ts",
//             },
//         },
//     });
}

test "TestTsxRename9" {
    const content =
        \\//@Filename: file.tsx
        \\// @jsx: preserve
        \\// @noLib: true
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\    }
        \\    interface ElementAttributesProperty { props; }
        \\}
        \\interface ClickableProps {
        \\    children?: string;
        \\    className?: string;
        \\}
        \\interface ButtonProps extends ClickableProps {
        \\    [|[|{| "contextRangeIndex": 0 |}onClick|](event?: React.MouseEvent<HTMLButtonElement>): void;|]
        \\}
        \\interface LinkProps extends ClickableProps {
        \\    [|[|{| "contextRangeIndex": 2 |}goTo|]: string;|]
        \\}
        \\[|declare function [|{| "contextRangeIndex": 4 |}MainButton|](buttonProps: ButtonProps): JSX.Element;|]
        \\[|declare function [|{| "contextRangeIndex": 6 |}MainButton|](linkProps: LinkProps): JSX.Element;|]
        \\[|declare function [|{| "contextRangeIndex": 8 |}MainButton|](props: ButtonProps | LinkProps): JSX.Element;|]
        \\let opt = [|<[|{| "contextRangeIndex": 10 |}MainButton|] />|];
        \\let opt = [|<[|{| "contextRangeIndex": 12 |}MainButton|] children="chidlren" />|];
        \\let opt = [|<[|{| "contextRangeIndex": 14 |}MainButton|] [|[|{| "contextRangeIndex": 16 |}onClick|]={()=>{}}|] />|];
        \\let opt = [|<[|{| "contextRangeIndex": 18 |}MainButton|] [|[|{| "contextRangeIndex": 20 |}onClick|]={()=>{}}|] [|ignore-prop|] />|];
        \\let opt = [|<[|{| "contextRangeIndex": 23 |}MainButton|] [|[|{| "contextRangeIndex": 25 |}goTo|]="goTo"|] />|];
        \\let opt = [|<[|{| "contextRangeIndex": 27 |}MainButton|] [|wrong|] />|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "onClick", "goTo", "MainButton", "ignore-prop", "wrong");
}

test "TestGetJavaScriptCompletions9" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\/**
        \\ * @type {function(new:number)}
        \\ */
        \\var v;
        \\new v()./**/
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
//                     .Label = "toExponential",
//                     .Kind =  undefined(lsproto.CompletionItemKindMethod),
//                 },
//             },
//         },
//     });
}

test "TestGoToImplementationThis_01" {
    const content =
        \\class [|Bar|] extends Foo {
        \\    hello(): th/*this_type*/is {
        \\        return this;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "this_type");
}

test "TestFormatInTsxFiles" {
    const content =
        \\//@Filename: file.tsx
        \\interface I<T1, T2> {
        \\    next: I</* */
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
}

test "TestGoToDefinitionSwitchCase5" {
    const content =
        \\export [|/*start*/default|] {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "start");
}

test "TestQuickInfoOnJsxNamespacedNameWithDoc1" {
    const content =
        \\// @jsx: react
        \\// @Filename: /types.d.ts
        \\declare namespace JSX {
        \\  interface IntrinsicElements {
        \\    'my-el': {
        \\      /** This appears */
        \\      foo: string;
        \\
        \\      /** This also appears */
        \\      'prop:foo': string;
        \\    };
        \\  }
        \\}
        \\// @filename: /a.tsx
        \\<my-el /*1*/prop:foo="bar" /*2*/foo="baz" />
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(property) 'prop:foo': string", "This also appears");
    try f.VerifyQuickInfoAt(undefined, "2", "(property) foo: string", "This appears");
}

test "TestStringLiteralTypeCompletionsInTypeArgForNonGeneric1" {
    const content =
        \\interface Foo {}
        \\type Bar = {};
        \\
        \\let x: Foo<"/*1*/">;
        \\let y: Bar<"/*2*/">;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, f.Markers(), &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{},
//     });
}

test "TestQuickInfoAlias" {
    const content =
        \\// @Filename: /a.ts
        \\/**
        \\ * Doc
        \\ * @tag Tag text
        \\ */
        \\export const x = 0;
        \\// @Filename: /b.ts
        \\import { x } from "./a";
        \\x/*b*/;
        \\// @Filename: /c.ts
        \\/**
        \\ * Doc 2
        \\ * @tag Tag text 2
        \\ */
        \\import {
        \\    /**
        \\     * Doc 3
        \\     * @tag Tag text 3
        \\     */
        \\    x
        \\} from "./a";
        \\x/*c*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestGetOccurrencesSetAndGet3" {
    const content =
        \\class Foo {
        \\    set bar(b: any) {
        \\    }
        \\
        \\    public get bar(): any {
        \\        return undefined;
        \\    }
        \\
        \\    public set set(s: any) {
        \\    }
        \\
        \\    public get set(): any {
        \\        return undefined;
        \\    }
        \\
        \\    public [|set|] get(g: any) {
        \\    }
        \\
        \\    public [|get|] get(): any {
        \\        return undefined;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestCompletionListInObjectBindingPattern08" {
    const content =
        \\interface I {
        \\    propertyOfI_1: number;
        \\    propertyOfI_2: string;
        \\}
        \\interface J {
        \\    property1: I;
        \\    property2: string;
        \\}
        \\
        \\var foo: J;
        \\var { property1: { propertyOfI_1, /**/ } } = foo;
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
//                 "propertyOfI_2",
//             },
//         },
//     });
}

test "TestInsertMethodCallAboveOthers" {
    const content =
        \\/**/ 
        \\paired.reduce();
        \\paired.map(() => undefined);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "paired.reduce();");
}

test "TestGetOccurrencesPropertyInAliasedInterface" {
    const content =
        \\namespace m {
        \\    export interface Foo {
        \\        [|abc|]
        \\    }
        \\}
        \\
        \\import Bar = m.Foo;
        \\
        \\export interface I extends Bar {
        \\    [|abc|]
        \\}
        \\
        \\class C implements Bar {
        \\    [|abc|]
        \\}
        \\
        \\(new C()).[|abc|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestFindAllRefsForMappedType" {
    const content =
        \\interface T { /*1*/a: number };
        \\type U = { [K in keyof T]: string };
        \\type V = { [K in keyof U]: boolean };
        \\const u: U = { a: "" }
        \\const v: V = { a: true }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestCompletionsUnion" {
    const content =
        \\interface I { x: number; }
        \\interface Many<T> extends ReadonlyArray<T> { extra: number; }
        \\class C { private priv: number; }
        \\const x: I | I[] | Many<string> | C = { /**/ };
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
//                 "x",
//             },
//         },
//     });
}

test "TestPathCompletionsPackageJsonImportsIgnoreMatchingNodeModule1" {
    const content =
        \\// @module: node18
        \\// @Filename: /src/node_modules/#internal/package.json
        \\{
        \\  "imports": {
        \\    "#thing": "./dist/something.js"
        \\  }
        \\}
        \\// @Filename: /src/node_modules/#internal/dist/something.d.ts
        \\export function something(name: string): any;
        \\// @Filename: /src/a.ts
        \\import {} from "#internal//*1*/";
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
//             .Exact = &.{},
//         },
//     });
}

test "TestRenameModuleExportsProperties3" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\[|class [|{| "contextRangeIndex": 0 |}A|] {}|]
        \\module.exports = { [|A|] }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, &.{.UseAliasesForRename = core.TSTrue}, f.Ranges()[1], f.Ranges()[2]);
}

test "TestCodeFixMissingTypeAnnotationOnExports13" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\function foo() {
        \\    return { x: 1, y: 1 };
        \\}
        \\export const { x: abcd, y: defg } = foo();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Extract binding expressions to variable",
        .NewFileContent = "function foo() {\n    return { x: 1, y: 1 };\n}\nconst dest = foo();\nexport const abcd: number = dest.x;\nexport const defg: number = dest.y;",
        .Index = 0,
    });
}

test "TestSmartSelection_mappedTypes" {
    const content =
        \\type M = { /*1*/-re/*2*/adonly /*3*/[K in ke/*4*/yof any]/*5*/-/*6*/?: any };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSelectionRanges(undefined);
}

test "TestQuickinfoForNamespaceMergeWithClassConstrainedToSelf" {
    const content =
        \\declare namespace AMap {
        \\    namespace MassMarks {
        \\        interface Data {
        \\            style?: number;
        \\        }
        \\    }
        \\    class MassMarks<D extends MassMarks.Data = MassMarks.Data> {
        \\        constructor(data: D[] | string);
        \\        clear(): void;
        \\    }
        \\}
        \\
        \\interface MassMarksCustomData extends AMap.MassMarks./*1*/Data {
        \\    name: string;
        \\    id: string;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "interface AMap.MassMarks<D extends AMap.MassMarks.Data = AMap.MassMarks.Data>.Data", "");
}

test "TestJavascriptModules24" {
    const content =
        \\// @Filename: mod.ts
        \\function foo() { return 42; }
        \\namespace foo {
        \\  export function bar (a: string) { return a; }
        \\}
        \\export = foo;
        \\// @Filename: app.ts
        \\import * as foo from "./mod"
        \\foo/*1*/();
        \\foo.bar(/*2*/"test");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyErrorExistsBeforeMarker(undefined, "1");
    try f.VerifyQuickInfoIs(undefined, "(alias) function foo(): number\n(alias) namespace foo\nimport foo", "");
    _ = f.GoToMarker(undefined, "2");
    // try f.VerifySignatureHelp(undefined, .{});
}

test "TestCompletionListInObjectBindingPattern13" {
    const content =
        \\interface I {
        \\    x: number;
        \\    y: string;
        \\    z: boolean;
        \\}
        \\
        \\interface J {
        \\    x: string;
        \\    y: string;
        \\}
        \\
        \\let { /**/ }: I | J = { x: 10 };
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
//                 "x",
//                 "y",
//             },
//         },
//     });
}

test "TestInsertInterfaceAndCheckTypeLiteralField" {
    const content =
        \\/*addC*/
        \\interface G<T, U> { }
        \\var v2: G<{ a: /*checkParam*/C }, C>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "addC");
    _ = f.Insert(undefined, "interface C { }");
    _ = f.GoToMarker(undefined, "checkParam");
    try f.VerifyQuickInfoExists(undefined);
}

test "TestSignatureHelpCommentsClass" {
    const content =
        \\/** This is class c2 without constructor*/
        \\class c2 {
        \\}
        \\var i2 = new c2(/*3*/);
        \\var i2_c = c2;
        \\class c3 {
        \\    /** Constructor comment*/
        \\    constructor() {
        \\    }
        \\}
        \\var i3 = new c3(/*8*/);
        \\var i3_c = c3;
        \\/** Class comment*/
        \\class c4 {
        \\    /** Constructor comment*/
        \\    constructor() {
        \\    }
        \\}
        \\var i4 = new c4(/*13*/);
        \\var i4_c = c4;
        \\/** Class with statics*/
        \\class c5 {
        \\    static s1: number;
        \\}
        \\var i5 = new c5(/*18*/);
        \\var i5_c = c5;
        \\/** class with statics and constructor*/
        \\class c6 {
        \\    /** s1 comment*/
        \\    static s1: number;
        \\    /** constructor comment*/
        \\    constructor() {
        \\    }
        \\}
        \\var i6 = new c6(/*23*/);
        \\var i6_c = c6;
        \\
        \\class a {
        \\    /**
        \\    constructor for a
        \\    @param a this is my a
        \\    */
        \\    constructor(a: string) {
        \\    }
        \\}
        \\new a(/*27*/"Hello");
        \\namespace m {
        \\    export namespace m2 {
        \\        /** class comment */
        \\        export class c1 {
        \\            /** constructor comment*/
        \\            constructor() {
        \\            }
        \\        }
        \\    }
        \\}
        \\var myVar = new m.m2.c1();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSignatureHelp(undefined);
}

test "TestAutoImportPackageJsonImportsPattern_js_ts" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#*.js": "./src/*.ts"
        \\  }
        \\}
        \\// @Filename: /src/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /a.ts
        \\something/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"#something.js"}, null );
}

test "TestFormatSelectionWithTrivia" {
    const content =
        \\if (true) {     
        \\  //   
        \\   /*begin*/   
        \\     //    
        \\     ;    
        \\       
        \\      }/*end*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatSelection(undefined, "begin", "end");
    try f.VerifyCurrentFileContent(undefined, "if (true) {     \n  //   \n\n    //    \n    ;\n\n}");
}

test "TestGoToImplementationNamespace_06" {
    const content =
        \\namespace [|F/*declaration*/oo|] {
        \\    declare function hello(): void;
        \\}
        \\
        \\
        \\let x: typeof Foo = [|{ hello() {} }|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "declaration");
}

test "TestCorreuptedTryExpressionsDontCrashGettingOutlineSpans" {
    const content =
        \\try[| {
        \\  var x = [
        \\    {% try[||] %}|][|{% except %}|] 
        \\  ]
        \\} catch (e)[| {
        \\  
        \\}|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOutliningSpans(undefined);
}

test "TestNoQuickInfoForLabel" {
    const content =
        \\/*1*/label : while(true){
        \\    break /*2*/label;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyNotQuickInfoExists(undefined);
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyNotQuickInfoExists(undefined);
}

test "TestGetOccurrencesSetAndGet2" {
    const content =
        \\class Foo {
        \\    set bar(b: any) {
        \\    }
        \\
        \\    public get bar(): any {
        \\        return undefined;
        \\    }
        \\
        \\    public [|set|] set(s: any) {
        \\    }
        \\
        \\    public [|get|] set(): any {
        \\        return undefined;
        \\    }
        \\
        \\    public set get(g: any) {
        \\    }
        \\
        \\    public get get(): any {
        \\        return undefined;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

