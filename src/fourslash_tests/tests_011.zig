const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestGoToDefinition_filteringMappedType" {
    const content =
        \\const obj = { /*def*/a: 1, b: 2 };
        \\const filtered: { [P in keyof typeof obj as P extends 'b' ? never : P]: 0; } = { a: 0 };
        \\filtered.[|/*ref*/a|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "ref");
}

test "TestCompletionListInScope" {
    const content =
        \\namespace TestModule {
        \\    var localVariable = "";
        \\    export var exportedVariable = 0;
        \\
        \\    function localFunction() { }
        \\    export function exportedFunction() { }
        \\
        \\    class localClass { }
        \\    export class exportedClass { }
        \\
        \\    interface localInterface {}
        \\    export interface exportedInterface {}
        \\
        \\    namespace localModule {
        \\        export var x = 0;
        \\    }
        \\    export namespace exportedModule {
        \\        export var x = 0;
        \\    }
        \\
        \\    var v = /*valueReference*/ 0;
        \\    var t :/*typeReference*/;
        \\}
        \\
        \\// Add some new items to the module
        \\namespace TestModule {
        \\    var localVariable2 = "";
        \\    export var exportedVariable2 = 0;
        \\
        \\    function localFunction2() { }
        \\    export function exportedFunction2() { }
        \\
        \\    class localClass2 { }
        \\    export class exportedClass2 { }
        \\
        \\    interface localInterface2 {}
        \\    export interface exportedInterface2 {}
        \\
        \\    namespace localModule2 {
        \\        export var x = 0;
        \\    }
        \\    export namespace exportedModule2 {
        \\        export var x = 0;
        \\    }
        \\}
        \\var globalVar: string = "";
        \\function globalFunction() { }
        \\
        \\class TestClass {
        \\    property: number;
        \\    method() { }
        \\    staticMethod() { }
        \\    testMethod(param: number) {
        \\        var localVar = 0;
        \\        function localFunction() {};
        \\        /*insideMethod*/
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "valueReference", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "localVariable",
//                 "exportedVariable",
//                 "localFunction",
//                 "exportedFunction",
//                 "localClass",
//                 "exportedClass",
//                 "localModule",
//                 "exportedModule",
//                 "exportedVariable2",
//                 "exportedFunction2",
//                 "exportedClass2",
//                 "exportedModule2",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "typeReference", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "localInterface",
//                 "exportedInterface",
//                 "localClass",
//                 "exportedClass",
//                 "exportedClass2",
//             },
//             .Excludes = &.{
//                 "localModule",
//                 "exportedModule",
//                 "exportedModule2",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "insideMethod", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "globalVar",
//                 "globalFunction",
//                 "param",
//                 "localVar",
//                 "localFunction",
//             },
//             .Excludes = &.{
//                 "property",
//                 "testMethod",
//                 "staticMethod",
//             },
//         },
//     });
}

test "TestReferencesForObjectLiteralProperties" {
    const content =
        \\var x = { /*1*/add: 0, b: "string" };
        \\x["/*2*/add"];
        \\x./*3*/add;
        \\var y = x;
        \\y./*4*/add;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestCompletionListAfterNumericLiteral1" {
    const content =
        \\5../**/
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
//                 "toExponential",
//                 "toFixed",
//                 "toLocaleString",
//                 "toPrecision",
//                 "toString",
//                 "valueOf",
//             },
//         },
//     });
}

test "TestSyntacticClassificationsDocComment1" {
    const content =
        \\/** @type {number} */
        \\var v;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "variable.declaration", .Text = "v"},
//     });
}

test "TestCodeFixClassImplementInterfaceIndexSignaturesBoth" {
    const content =
        \\interface I {
        \\    [x: number]: I;
        \\    [y: string]: I;
        \\}
        \\
        \\class C implements I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "interface I {\n    [x: number]: I;\n    [y: string]: I;\n}\n\nclass C implements I {\n    [x: number]: I;\n    [y: string]: I;\n}",
        .Index = 0,
    });
}

test "TestImportNameCodeFixNewImportTypeRoots1" {
    const content =
        \\// @Filename: a/f1.ts
        \\[|foo/*0*/();|]
        \\// @Filename: types/random/index.ts
        \\export function foo() {};
        \\// @Filename: tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "baseUrl": ".",
        \\        "typeRoots": [
        \\            "./types"
        \\        ]
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { foo } from \"types/random\";\n\nfoo();",
    }, null );
}

test "TestCompletionListClassMembers" {
    const content =
        \\// @lib: es5
        \\class Class {
        \\    private privateInstanceMethod() { }
        \\    public publicInstanceMethod() { }
        \\
        \\    private privateProperty = 1;
        \\    public publicProperty = 1;
        \\
        \\    private static privateStaticProperty = 1;
        \\    public static publicStaticProperty = 1;
        \\
        \\    private static privateStaticMethod() { }
        \\    public static publicStaticMethod() {
        \\        Class./*staticsInsideClassScope*/publicStaticMethod();
        \\        var c = new Class();
        \\        c./*instanceMembersInsideClassScope*/privateProperty;
        \\    }
        \\}
        \\
        \\Class./*staticsOutsideClassScope*/publicStaticMethod();
        \\var c = new Class();
        \\c./*instanceMembersOutsideClassScope*/privateProperty;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "staticsInsideClassScope", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionFunctionMembersPlus(
//                 &.{
//                     &.{
//                         .Label =    "privateStaticMethod",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "privateStaticProperty",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "publicStaticMethod",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "publicStaticProperty",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "prototype",
//                         .SortText = undefined(string(ls.SortTextLocationPriority)),
//                     },
//                 },
//             ),
//         },
//     });
    // f.VerifyCompletions(undefined, "instanceMembersInsideClassScope", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "privateInstanceMethod",
//                 "publicInstanceMethod",
//                 "privateProperty",
//                 "publicProperty",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "staticsOutsideClassScope", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionFunctionMembersPlus(
//                 &.{
//                     &.{
//                         .Label =    "publicStaticMethod",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "publicStaticProperty",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "prototype",
//                         .SortText = undefined(string(ls.SortTextLocationPriority)),
//                     },
//                 },
//             ),
//         },
//     });
    // f.VerifyCompletions(undefined, "instanceMembersOutsideClassScope", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "publicInstanceMethod",
//                 "publicProperty",
//             },
//         },
//     });
}

test "TestQuickInfoTypeError" {
    const content =
        \\foo({
        \\    /**/f: function() {},
        \\    f() {}
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "(method) f(): void", "");
}

test "TestFindAllRefsBadImport" {
    const content =
        \\import { /*0*/ab as /*1*/cd } from "doesNotExist";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "0", "1");
}

test "TestFindAllRefsOnDefinition" {
    const content =
        \\//@Filename: findAllRefsOnDefinition-import.ts
        \\export class Test{
        \\
        \\    constructor(){
        \\
        \\    }
        \\
        \\    /*1*/public /*2*/start(){
        \\        return this;
        \\    }
        \\
        \\    public stop(){
        \\        return this;
        \\    }
        \\}
        \\//@Filename: findAllRefsOnDefinition.ts
        \\import Second = require("./findAllRefsOnDefinition-import");
        \\
        \\var second = new Second.Test()
        \\second./*3*/start();
        \\second.stop();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestFormatEmptyParamList" {
    const content =
        \\function f( f: function){/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "}");
    try f.VerifyCurrentLineContent(undefined, "function f(f: function) { }");
}

test "TestCompletionListOnSuper" {
    const content =
        \\class TAB<T>{
        \\    foo<T>(x: T) {
        \\    }
        \\    bar(a: number, b: number) {
        \\    }
        \\}
        \\
        \\class TAD<T> extends TAB<T> {
        \\    constructor() {
        \\        super();
        \\    }
        \\    bar(f: number) {
        \\        super./**/
        \\    }
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
//             .Exact = &.{
//                 "bar",
//                 "foo",
//             },
//         },
//     });
}

test "TestAutoImportPackageJsonFilterExistingImport3" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{ "compilerOptions": { "lib": ["es5"], "module": "preserve", "types": ["*"] } }
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/node/index.d.ts
        \\declare module "node:fs" {
        \\    export function readFile(): void;
        \\    export function writeFile(): void;
        \\}
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{}
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\readFile/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyImportFixAtPosition(undefined, &.{}, null );
    _ = f.GoToBOF(undefined);
    _ = f.InsertLine(undefined, "import { writeFile } from \"node:fs\";");
    _ = f.GoToMarker(undefined, "");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { readFile, writeFile } from \"node:fs\";\nreadFile",
    }, null );
}

test "TestFormatDocumentWithJSDoc" {
    const content =
        \\/**
        \\ * JSDoc for things
        \\ */
        \\function f() {
        \\    /** more
        \\        jsdoc */
        \\    var t;
        \\    /**
        \\     * multiline
        \\     */
        \\    var multiline;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "/**\n * JSDoc for things\n */\nfunction f() {\n    /** more\n        jsdoc */\n    var t;\n    /**\n     * multiline\n     */\n    var multiline;\n}");
}

test "TestCompletionListBuilderLocations_properties" {
    const content =
        \\var aa = 1;
        \\class A1 {
        \\    public static /*property1*/
        \\}
        \\class A2 {
        \\    public static a/*property2*/
        \\}
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
//             .Exact = CompletionClassElementKeywords,
//         },
//     });
}

test "TestTypeErrorAfterStringCompletionsInNestedCall2" {
    const content =
        \\// @stableTypeOrdering: true
        \\// @strict: true
        \\
        \\type ActionFunction<
        \\  TExpressionEvent extends { type: string },
        \\  out TEvent extends { type: string }
        \\> = {
        \\  ({ event }: { event: TExpressionEvent }): void;
        \\  _out_TEvent?: TEvent;
        \\};
        \\
        \\interface MachineConfig<TEvent extends { type: string }> {
        \\  types: {
        \\    events: TEvent;
        \\  };
        \\  on: {
        \\    [K in TEvent["type"]]?: ActionFunction<
        \\      Extract<TEvent, { type: K }>,
        \\      TEvent
        \\    >;
        \\  };
        \\}
        \\
        \\declare function raise<
        \\  TExpressionEvent extends { type: string },
        \\  TEvent extends { type: string }
        \\>(
        \\  resolve: ({ event }: { event: TExpressionEvent }) => TEvent
        \\): {
        \\  ({ event }: { event: TExpressionEvent }): void;
        \\  _out_TEvent?: TEvent;
        \\};
        \\
        \\declare function createMachine<TEvent extends { type: string }>(
        \\  config: MachineConfig<TEvent>
        \\): void;
        \\
        \\createMachine({
        \\  types: {
        \\    events: {} as { type: "FOO" } | { type: "BAR" },
        \\  },
        \\  on: {
        \\    [|/*error*/FOO|]: raise(({ event }) => {
        \\      return {
        \\        type: "BAR/*1*/" as const,
        \\      };
        \\    }),
        \\  },
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "x");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "BAR",
//                 "FOO",
//             },
//         },
//     });
    // try f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestInlayHintsInteractiveRestParameters1" {
    const content =
        \\function foo1(a: number, ...b: number[]) {}
        \\foo1(1, 1, 1, 1);
        \\type Args2 = [a: number, b: number]
        \\declare function foo2(c: number, ...args: Args2);
        \\foo2(1, 2, 3)
        \\type Args3 = [number, number]
        \\declare function foo3(c: number, ...args: Args3);
        \\foo3(1, 2, 3)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayParameterNameHints = lsutil.IncludeInlayParameterNameHintsLiterals}});
}

test "TestSemanticModernClassificationInterfaces" {
    const content =
        \\interface Pos { x: number, y: number };
        \\const p = { x: 1, y: 2 } as Pos;
        \\const foo = (o: Pos) => o.x + o.y;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "interface.declaration", .Text = "Pos"},
//         .{.Type = "property.declaration", .Text = "x"},
//         .{.Type = "property.declaration", .Text = "y"},
//         .{.Type = "variable.declaration.readonly", .Text = "p"},
//         .{.Type = "property.declaration", .Text = "x"},
//         .{.Type = "property.declaration", .Text = "y"},
//         .{.Type = "interface", .Text = "Pos"},
//         .{.Type = "function.declaration.readonly", .Text = "foo"},
//         .{.Type = "parameter.declaration", .Text = "o"},
//         .{.Type = "interface", .Text = "Pos"},
//         .{.Type = "parameter", .Text = "o"},
//         .{.Type = "property", .Text = "x"},
//         .{.Type = "parameter", .Text = "o"},
//         .{.Type = "property", .Text = "y"},
//     });
}

test "TestImportNameCodeFixExistingImport12" {
    const content =
        \\import [|{}|] from "./module";
        \\f1/*0*/();
        \\// @Filename: module.ts
        \\export function f1() {}
        \\export var v1 = 5;
        \\export var v2 = 5;
        \\export var v3 = 5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "{ f1 }",
    }, null );
}

test "TestGoToImplementationEnum_00" {
    const content =
        \\enum Foo {
        \\    [|Foo1|] = function initializer() { return 5 } (),
        \\    Foo2 = 6
        \\}
        \\
        \\Foo.Fo/*reference*/o1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "reference");
}

test "TestInlayHintsParameterNames" {
    const content =
        \\ function foo1 (a: number, b: number) {}
        \\ foo1(1, 2);
        \\ function foo2 (a: number, { c }: any) {}
        \\ foo2(1, { c: 1 });
        \\function foo3(a: any, b: number) {}
        \\foo3({}, 1);
        \\const foo3 = (a = 1) => class { }
        \\const C1 = class extends foo3(1) { }
        \\class C2 extends foo3(1) { }
        \\function foo4(a: number, b: number, c: number, d: number) {}
        \\foo4(1, +1, -1, +"1");
        \\function foo5(
        \\    a: string,
        \\    b: undefined,
        \\    c: null,
        \\    d: boolean,
        \\    e: boolean,
        \\    f: number,
        \\    g: number,
        \\    h: number,
        \\    i: RegExp,
        \\    j: bigint,
        \\) {
        \\}
        \\foo5(
        \\    "hello",
        \\    undefined,
        \\    null,
        \\    true,
        \\    false,
        \\    Infinity,
        \\    -Infinity,
        \\    NaN,
        \\    /hello/g,
        \\    123n,
        \\);
        \\ declare const unknownCall: any;
        \\ unknownCall();
        \\function trace(message: string) {}
        \\trace(
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayParameterNameHints = lsutil.IncludeInlayParameterNameHintsLiterals}});
}

test "TestQuickInfoJsPropertyAssignedAfterMethodDeclaration" {
    const content =
        \\// @noLib: true
        \\// @allowJs: true
        \\// @noImplicitThis: true
        \\// @Filename: /a.js
        \\const o = {
        \\    test/*1*/() {
        \\        this./*2*/test = 0;
        \\    }
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(method) test(): void", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(method) test(): void", "");
}

test "TestGoToImplementationShorthandPropertyAssignment_02" {
    const content =
        \\interface Foo {
        \\     hello(): void;
        \\}
        \\
        \\function createFoo(): Foo {
        \\    return {
        \\         hello
        \\    };
        \\
        \\    function [|hello|]() {}
        \\}
        \\
        \\function whatever(x: Foo) {
        \\     x.h/*function_call*/ello();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "function_call");
}

test "TestCompletionForStringLiteral3" {
    const content =
        \\declare function f(a: "A", b: number): void;
        \\declare function f(a: "B", b: number): void;
        \\declare function f(a: "C", b: number): void;
        \\declare function f(a: string, b: number): void;
        \\
        \\f("[|/*1*/C|]", 2);
        \\
        \\f("/*2*/
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
//             .Exact = &.{
//                 &.{
//                     .Label = "A",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "A",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "B",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "B",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "C",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "C",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "A",
//                 "B",
//                 "C",
//             },
//         },
//     });
}

test "TestCompletionListInObjectLiteral" {
    const content =
        \\interface point {
        \\    x: number;
        \\    y: number;
        \\}
        \\interface thing {
        \\    name: string;
        \\    pos: point;
        \\}
        \\var t: thing;
        \\t.pos = { x: 4, y: 3 + t./**/ };
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
//                 "name",
//                 "pos",
//             },
//         },
//     });
}

test "TestGoToDefinitionOverriddenMember8" {
    const content =
        \\// @noImplicitOverride: true
        \\// @Filename: ./a.ts
        \\export class A {
        \\    /*2*/m() {}
        \\}
        \\// @Filename: ./b.ts
        \\import { A } from "./a";
        \\class B extends A {
        \\    [|/*1*/override|] m() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestFormatOnEnterFunctionDeclaration" {
    const content =
        \\/*0*/function listAPIFiles(path: string): string[] {/*1*/ }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.InsertLine(undefined, "");
    _ = f.GoToMarker(undefined, "0");
    try f.VerifyCurrentLineContent(undefined, "function listAPIFiles(path: string): string[] {");
}

test "TestIncrementalResolveAccessor" {
    const content =
        \\class c1 {
        \\    get p1(): string {
        \\        return "30";
        \\    }
        \\    set p1(a: number) {
        \\        a = "30";
        \\    }
        \\}
        \\var val = new c1();
        \\var b = val.p1;
        \\/*1*/b;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "var b: string", "");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestCodeFixMissingTypeAnnotationOnExports11" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\function mixin<T extends new (...a: any) => any>(ctor: T): T {
        \\    return ctor;
        \\}
        \\class Point2D { x = 0; y = 0; }
        \\export class Point3D extends mixin(Point2D) {  z = 0; }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Extract base class to variable",
        .NewFileContent = "function mixin<T extends new (...a: any) => any>(ctor: T): T {\n    return ctor;\n}\nclass Point2D { x = 0; y = 0; }\nconst Point3DBase: typeof Point2D = mixin(Point2D);\nexport class Point3D extends Point3DBase {  z = 0; }",
        .Index = 0,
    });
}

test "TestCompletionsImport_named_fromMergedDeclarations" {
    const content =
        \\// @module: esnext
        \\// @Filename: /a.ts
        \\declare module "m" {
        \\    export class M {}
        \\}
        \\// @Filename: /b.ts
        \\declare module "m" {
        \\    export interface M {}
        \\}
        \\// @Filename: /c.ts
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
//                     .Label = "M",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "m",
//                         },
//                     },
//                     .Detail =              undefined("class M\ninterface M"),
//                     .Kind =                undefined(lsproto.CompletionItemKindClass),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "M",
//         .Source =      "m",
//         .Description = "Add import from \"m\"",
//         .NewFileContent = undefined("import { M } from \"m\";\n\n"),
//     });
}

test "TestDocumentHighlightAtParameterPropertyDeclaration3" {
    const content =
        \\// @Filename: file1.ts
        \\class Foo {
        \\    // This is not valid syntax: parameter property can't be binding pattern
        \\    constructor(private [[|privateParam|]]: number,
        \\        public [[|publicParam|]]: string,
        \\        protected [[|protectedParam|]]: boolean) {
        \\
        \\        let localPrivate = [|privateParam|];
        \\        this.privateParam += 10;
        \\
        \\        let localPublic = [|publicParam|];
        \\        this.publicParam += " Hello!";
        \\
        \\        let localProtected = [|protectedParam|];
        \\        this.protectedParam = false;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestCompletionsImport_duplicatePackages_scoped" {
    const content =
        \\// @lib: es5
        \\// @module: commonjs
        \\// @esModuleInterop: true
        \\// @Filename: /node_modules/@scope/react-dom/package.json
        \\{ "name": "react-dom", "version": "1.0.0", "types": "./index.d.ts" }
        \\// @Filename: /node_modules/@scope/react-dom/index.d.ts
        \\import * as React from "react";
        \\export function render(): void;
        \\// @Filename: /node_modules/@scope/react/package.json
        \\{ "name": "react", "version": "1.0.0", "types": "./index.d.ts" }
        \\// @Filename: /node_modules/@scope/react/index.d.ts
        \\import "./other";
        \\export declare function useState(): void;
        \\// @Filename: /node_modules/@scope/react/other.d.ts
        \\export declare function useRef(): void;
        \\// @Filename: /packages/a/node_modules/@scope/react/package.json
        \\{ "name": "react", "version": "1.0.1", "types": "./index.d.ts" }
        \\// @Filename: /packages/a/node_modules/@scope/react/index.d.ts
        \\export declare function useState(): void;
        \\// @Filename: /packages/a/index.ts
        \\import "@scope/react-dom";
        \\import "@scope/react";
        \\// @Filename: /packages/a/foo.ts
        \\/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
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
//                         .Label = "render",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "@scope/react-dom",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                     &.{
//                         .Label = "useState",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "@scope/react",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                 }, false,
//             ),
//         },
//     });
}

test "TestDocCommentTemplateWithExistingJSDoc" {
    const content =
        \\/** /**/ */
        \\
        \\/**
        \\ * @param {string} a
        \\ * @param {string} b
        \\ */
        \\function foo(a, b) {
        \\    return a + b;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyNoJSDocCompletion(undefined, "");
}

test "TestGetJavaScriptSyntacticDiagnostics7" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\namespace M { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestOutliningSpansForFunction" {
    const content =
        \\[|(
        \\    a: number,
        \\    b: number
        \\) => {
        \\    return a + b;
        \\}|];
        \\
        \\(a: number, b: number) =>[| {
        \\    return a + b;
        \\}|]
        \\
        \\const f1 = function[| (
        \\    a: number
        \\    b: number
        \\) {
        \\    return a + b;
        \\}|]
        \\
        \\const f2 = function (a: number, b: number)[| {
        \\    return a + b;
        \\}|]
        \\
        \\function f3[| (
        \\    a: number
        \\    b: number
        \\) {
        \\    return a + b;
        \\}|]
        \\
        \\function f4(a: number, b: number)[| {
        \\    return a + b;
        \\}|]
        \\
        \\class Foo[| {
        \\    constructor[|(
        \\        a: number,
        \\        b: number
        \\    ) {
        \\        this.a = a;
        \\        this.b = b;
        \\    }|]
        \\
        \\    m1[|(
        \\        a: number,
        \\        b: number
        \\    ) {
        \\        return a + b;
        \\    }|]
        \\
        \\    m1(a: number, b: number)[| {
        \\        return a + b;
        \\    }|]
        \\}|]
        \\
        \\declare function foo(props: any): void;
        \\foo[|(
        \\    a =>[| {
        \\
        \\    }|]
        \\)|]
        \\
        \\foo[|(
        \\    (a) =>[| {
        \\
        \\    }|]
        \\)|]
        \\
        \\foo[|(
        \\    (a, b, c) =>[| {
        \\
        \\    }|]
        \\)|]
        \\
        \\foo[|([|
        \\    (a,
        \\     b,
        \\     c) => {
        \\
        \\    }|]
        \\)|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOutliningSpans(undefined);
}

test "TestCodeFixClassImplementInterfaceArrayTuple" {
    const content =
        \\interface I {
        \\    x: number[];
        \\    y: Array<number>;
        \\    z: [number, string, I];
        \\}
        \\
        \\class C implements I {[| |]}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "interface I {\n    x: number[];\n    y: Array<number>;\n    z: [number, string, I];\n}\n\nclass C implements I {\n    x: number[];\n    y: number[];\n    z: [number, string, I];\n}",
        .Index = 0,
    });
}

test "TestImportNameCodeFix_jsx1" {
    const content =
        \\// @jsx: react
        \\// @Filename: /node_modules/react/index.d.ts
        \\export const React: any;
        \\// @Filename: /a.tsx
        \\[|<this>|]</this>
        \\// @Filename: /Foo.tsx
        \\export const Foo = 0;
        \\// @Filename: /c.tsx
        \\import { React } from "react";
        \\<Foo />;
        \\// @Filename: /d.tsx
        \\import { Foo } from "./Foo";
        \\<Foo />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.tsx");
    try f.VerifyImportFixAtPosition(undefined, &.{}, null );
    _ = f.GoToFile(undefined, "/c.tsx");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { React } from \"react\";\nimport { Foo } from \"./Foo\";\n<Foo />;",
    }, null );
    _ = f.GoToFile(undefined, "/d.tsx");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { React } from \"react\";\nimport { Foo } from \"./Foo\";\n<Foo />;",
    }, null );
}

test "TestJsdocOnInheritedMembers2" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @filename: /a.js
        \\/** @template T */
        \\class A {
        \\    /** Method documentation. */
        \\    method() {}
        \\}
        \\
        \\/** @extends {A<number>} */
        \\const B = class extends A {
        \\    method() {}
        \\}
        \\
        \\const b = new B();
        \\b.method/**/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestRenameForStringLiteral" {
    const content =
        \\// @filename: /a.ts
        \\interface Foo {
        \\    property: /**/"foo";
        \\}
        \\/**
        \\ * @type {{ property: "foo"}}
        \\ */
        \\const obj: Foo = {
        \\    property: "foo",
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , "");
}

test "TestCompletionForStringLiteral_quotePreference3" {
    const content =
        \\const a = {
        \\    "#": "a"
        \\};
        \\a[|./**/|]
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
//                     .Label =      "#",
//                     .InsertText = undefined("[\"#\"]"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "#",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//         .UserPreferences = &.{.QuotePreference = lsutil.QuotePreference("double")},
//     });
}

test "TestReverseMappedTypeQuickInfo" {
    const content =
        \\interface IAction {
        \\    type: string;
        \\}
        \\
        \\type Reducer<S> = (state: S, action: IAction) => S
        \\
        \\function combineReducers<S>(reducers: { [K in keyof S]: Reducer<S[K]> }): Reducer<S> {
        \\    const dummy = {} as S;
        \\    return () => dummy;
        \\}
        \\
        \\const test_inner = (test: string, action: IAction) => {
        \\    return 'dummy';
        \\}
        \\const test = combineReducers({
        \\    test_inner
        \\});
        \\
        \\const test_outer = combineReducers({
        \\    test
        \\});
        \\
        \\// '{test: { test_inner: any } }'
        \\type FinalType/*1*/ = ReturnType<typeof test_outer>;
        \\
        \\var k: FinalType;
        \\k.test.test_inner/*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "type FinalType = {\n    test: {\n        test_inner: string;\n    };\n}", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(property) test_inner: string", "");
}

test "TestCodeFixCorrectReturnValue27" {
    const content =
        \\const a: ((() => number) | (() => undefined)) = () => { "" }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestOrganizeImports22" {
    const content =
        \\import {abc, Abc, bc, Bc} from 'b';
        \\import {
        \\  I,
        \\  R,
        \\  M,
        \\} from 'a';
        \\console.log(abc, Abc, bc, Bc, I, R, M);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "import {\n    I,\n    M,\n    R,\n} from 'a';\nimport { abc, Abc, bc, Bc } from 'b';\nconsole.log(abc, Abc, bc, Bc, I, R, M);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
    // try f.VerifyOrganizeImports(undefined,
//         "import {\n    I,\n    M,\n    R,\n} from 'a';\nimport { abc, Abc, bc, Bc } from 'b';\nconsole.log(abc, Abc, bc, Bc, I, R, M);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestAutoImportPackageJsonExportsSpecifierEndsInTs" {
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
        \\foo/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"pkg/something.ts"}, null );
}

test "TestAugmentedTypesModule4" {
    const content =
        \\namespace m3d { export var y = 2; }
        \\declare class m3d { foo(): void }
        \\var /*1*/r = new m3d();
        \\r./*2*/
        \\var /*4*/r2 = m3d./*3*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "var r: m3d", "");
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "foo",
//             },
//         },
//     });
    _ = f.Insert(undefined, "foo();");
    // f.VerifyCompletions(undefined, "3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "y",
//             },
//         },
//     });
    _ = f.Insert(undefined, "y;");
    try f.VerifyQuickInfoAt(undefined, "4", "var r2: number", "");
}

test "TestRenameStringLiteralOk" {
    const content =
        \\interface Foo {
        \\    f: '[|foo|]' | 'bar'
        \\}
        \\const d: 'foo' = 'foo'
        \\declare const f: Foo
        \\f.f = '[|foo|]'
        \\f.f = 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "foo");
}

test "TestExtendsKeywordCompletion1" {
    const content =
        \\export interface B ex/**/
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
//                     .Label =    "extends",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestQuickInfoElementAccessDeclaration" {
    const content =
        \\// @checkJs: true
        \\// @allowJs: true
        \\// @Filename: a.js
        \\const mod = {};
        \\mod["@@thing1"] = {};
        \\mod["/**/@@thing1"]["@@thing2"] = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyQuickInfoIs(undefined, "module mod[\"@@thing1\"]\n(property) mod[\"@@thing1\"]: typeof mod.@@thing1", "");
}

test "TestJsdocNullableUnion" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @checkJs: true
        \\// @Filename: Foo.js
        \\/**
        \\ * @param {never | {x: string}} p1
        \\ * @param {undefined | {y: number}} p2
        \\ * @param {null | {z: boolean}} p3
        \\ * @returns {void} nothing
        \\ */
        \\function f(p1, p2, p3) {
        \\    p1./*1*/;
        \\    p2./*2*/;
        \\    p3./*3*/;
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
//                 "x",
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
//                 "y",
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
//                 "z",
//             },
//         },
//     });
}

test "TestFormatTryFinally" {
    const content =
        \\if (true) try  {
        \\    // ...
        \\}   finally    {
        \\    // ...
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "if (true) try {\n    // ...\n} finally {\n    // ...\n}");
}

test "TestDocCommentTemplateObjectLiteralMethods01" {
    const content =
        \\var x = {
        \\    /*0*/
        \\    foo() {
        \\        return undefined;
        \\    }
        \\
        \\    /*1*/
        \\    [1 + 2 + 3 + Math.rand()](x: number, y: string, z = true) { }
        \\
        \\    /*2*/
        \\    m1: function(a) {}
        \\
        \\    /*3*/
        \\    m2: (a: string, b: string) => {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyJSDocCompletion(undefined, "0", 11, "/**\n     * \n     * @returns\n     */", null);
    // try f.VerifyJSDocCompletion(undefined, "1", 11, "/**\n     * \n     * @param x\n     * @param y\n     * @param z\n     */", null);
    // try f.VerifyJSDocCompletion(undefined, "2", 11, "/**\n     * \n     * @param a\n     */", null);
    // try f.VerifyJSDocCompletion(undefined, "3", 11, "/**\n     * \n     * @param a\n     * @param b\n     */", null);
}

test "TestCompletionsImport_reExport_wrongName" {
    const content =
        \\// @moduleResolution: bundler
        \\// @Filename: /a.ts
        \\export const x = 0;
        \\// @Filename: /index.ts
        \\export { x as y } from "./a";
        \\// @Filename: /c.ts
        \\/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
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
//                     .Label = "x",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./a",
//                         },
//                     },
//                     .Detail =              undefined("const x: 0"),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//                 &.{
//                     .Label = "y",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = ".",
//                         },
//                     },
//                     .Detail =              undefined("(alias) const y: 0\nexport y"),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "x",
//         .Source =      "./a",
//         .Description = "Add import from \"./a\"",
//         .NewFileContent = undefined("import { x } from \"./a\";\n\n"),
//     });
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "y",
//         .Source =      ".",
//         .Description = "Add import from \".\"",
//         .NewFileContent = undefined("import { y } from \".\";\nimport { x } from \"./a\";\n\n"),
//     });
}

test "TestImportTypeNodeGoToDefinition" {
    const content =
        \\// @Filename: /ns.ts
        \\/*refFile*/export namespace /*refFoo*/Foo {
        \\    export namespace /*refBar*/Bar {
        \\        export class /*refBaz*/Baz {}
        \\    }
        \\}
        \\// @Filename: /usage.ts
        \\type A = typeof import([|/*1*/"./ns"|]).[|/*2*/Foo|].[|/*3*/Bar|];
        \\type B = import([|/*4*/"./ns"|]).[|/*5*/Foo|].[|/*6*/Bar|].[|/*7*/Baz|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1", "2", "3", "4", "5", "6", "7");
}

test "TestLetQuickInfoAndCompletionList" {
    const content =
        \\let /*1*/a = 10;
        \\/*2*/a = 30;
        \\function foo() {
        \\    let /*3*/b = 20;
        \\    /*4*/b = /*5*/a;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "a",
//                     .Detail = undefined("let a: number"),
//                 },
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
//             .Includes = &.{
//                 &.{
//                     .Label =  "a",
//                     .Detail = undefined("let a: number"),
//                 },
//                 &.{
//                     .Label =  "b",
//                     .Detail = undefined("let b: number"),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "5", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "a",
//                     .Detail = undefined("let a: number"),
//                 },
//                 &.{
//                     .Label =  "b",
//                     .Detail = undefined("let b: number"),
//                 },
//             },
//         },
//     });
    try f.VerifyQuickInfoAt(undefined, "1", "let a: number", "");
    try f.VerifyQuickInfoAt(undefined, "2", "let a: number", "");
    try f.VerifyQuickInfoAt(undefined, "3", "let b: number", "");
    try f.VerifyQuickInfoAt(undefined, "4", "let b: number", "");
    try f.VerifyQuickInfoAt(undefined, "5", "let a: number", "");
}

test "TestReferencesForGlobals3" {
    const content =
        \\// @Filename: referencesForGlobals_1.ts
        \\/*1*/interface /*2*/globalInterface {
        \\     f();
        \\}
        \\// @Filename: referencesForGlobals_2.ts
        \\var i: /*3*/globalInterface;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestQuickInfoTypeAliasDefinedInDifferentFile" {
    const content =
        \\// @Filename: /a.ts
        \\export type X = { x: number };
        \\export function f(x: X): void {}
        \\// @Filename: /b.ts
        \\import { f } from "./a";
        \\/**/f({ x: 1 });
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "(alias) f(x: X): void\nimport f", "");
}

test "TestGoToDefinitionClassStaticBlocks" {
    const content =
        \\class ClassStaticBocks {
        \\    static x;
        \\    [|/*classStaticBocks1*/static|] {}
        \\    static y;
        \\    [|/*classStaticBocks2*/static|] {}
        \\    static y;
        \\    [|/*classStaticBocks3*/static|] {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "classStaticBocks1", "classStaticBocks2", "classStaticBocks3");
}

test "TestJavascriptModulesTypeImport" {
    const content =
        \\// @allowJs: true
        \\// @Filename: types.js
        \\/**
        \\ * @typedef {Object} Pet
        \\ * @prop {string} name
        \\ */
        \\module.exports = { a: 1 };
        \\// @Filename: app.js
        \\/**
        \\ * @param { import("./types")./**/ } p
        \\ */
        \\function walk(p) {
        \\ console.log(
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
//                 "Pet",
//             },
//         },
//     });
}

test "TestGoToImplementationNamespace_00" {
    const content =
        \\namespace /*implementation0*/Foo {
        \\    export function hello() {}
        \\}
        \\
        \\module /*implementation1*/Bar {
        \\    export function sure() {}
        \\}
        \\
        \\let x = Fo/*reference0*/o;
        \\let y = Ba/*reference1*/r;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "reference0", "reference1");
}

test "TestCompletionsLiteralDirectlyInArgumentWithNullableConstraint" {
    const content =
        \\// @strict: true
        \\
        \\declare function func<
        \\  const T extends 'a' | 'b' | undefined = undefined,
        \\>(arg?: T): string;
        \\
        \\func('/*1*/');
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
//             .Exact = &.{
//                 "a",
//                 "b",
//             },
//         },
//     });
}

test "TestGetOccurrencesSuperNegatives" {
    const content =
        \\function f(x = [|super|]) {
        \\    [|super|];
        \\}
        \\
        \\namespace M {
        \\    [|super|];
        \\    function f(x = [|super|]) {
        \\    [|super|];
        \\    }
        \\
        \\    class A {
        \\    }
        \\
        \\    class B extends A {
        \\        constructor() {
        \\            super();
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestFormatNoSpaceBeforeCloseBrace6" {
    const content =
        \\new Foo(1, /* comment */  
        \\  );
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "new Foo(1, /* comment */\n);");
}

test "TestImportNameCodeFixNewImportPaths_withLeadingDotSlash" {
    const content =
        \\// @Filename: /a.ts
        \\[|foo|]
        \\// @Filename: /thisHasPathMapping.ts
        \\export function foo() {};
        \\// @Filename: /tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "baseUrl": ".",
        \\        "paths": {
        \\            "foo": ["././thisHasPathMapping"]
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { foo } from \"foo\";\n\nfoo",
    }, null );
}

test "TestImportCompletionsPackageJsonImports_ts" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#thing": "./src/something.ts"
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
//                 "#thing",
//             },
//         },
//     });
}

test "TestSignatureHelpThis" {
    const content =
        \\class Foo<T> {
        \\    public implicitAny(n: number) {
        \\    }
        \\    public explicitThis(this: this, n: number) {
        \\        console.log(this);
        \\    }
        \\    public explicitClass(this: Foo<T>, n: number) {
        \\        console.log(this);
        \\    }
        \\}
        \\
        \\function implicitAny(x: number): void {
        \\    return this;
        \\}
        \\function explicitVoid(this: void, x: number): void {
        \\    return this;
        \\}
        \\function explicitLiteral(this: { n: number }, x: number): void {
        \\    console.log(this);
        \\}
        \\let foo = new Foo<number>();
        \\foo.implicitAny(/*1*/);
        \\foo.explicitThis(/*2*/);
        \\foo.explicitClass(/*3*/);
        \\implicitAny(/*4*/12);
        \\explicitVoid(/*5*/13);
        \\let o = { n: 14, m: explicitLiteral };
        \\o.m(/*6*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.ParameterName = "n"});
    _ = f.GoToMarker(undefined, "2");
    // try f.VerifySignatureHelp(undefined, .{.ParameterName = "n"});
    _ = f.GoToMarker(undefined, "3");
    // try f.VerifySignatureHelp(undefined, .{.ParameterName = "n"});
    _ = f.GoToMarker(undefined, "4");
    // try f.VerifySignatureHelp(undefined, .{.ParameterName = "x"});
    _ = f.GoToMarker(undefined, "5");
    // try f.VerifySignatureHelp(undefined, .{.ParameterName = "x"});
    _ = f.GoToMarker(undefined, "6");
    // try f.VerifySignatureHelp(undefined, .{.ParameterName = "x"});
}

test "TestGoToSource10_mapFromAtTypes3" {
    const content =
        \\// @lib: es5
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/lodash/package.json
        \\{ "name": "lodash", "version": "4.17.15", "main": "./lodash.js" }
        \\// @Filename: /home/src/workspaces/project/node_modules/lodash/lodash.js
        \\;(function() {
        \\    /**
        \\     * Adds two numbers.
        \\     *
        \\     * @static
        \\     * @memberOf _
        \\     * @since 3.4.0
        \\     * @category Math
        \\     * @param {number} augend The first number in an addition.
        \\     * @param {number} addend The second number in an addition.
        \\     * @returns {number} Returns the total.
        \\     * @example
        \\     *
        \\     * _.add(6, 4);
        \\     * // => 10
        \\     */
        \\    var [|/*variable*/add|] = createMathOperation(function(augend, addend) {
        \\     return augend + addend;
        \\    }, 0);
        \\
        \\    function lodash(value) {}
        \\    lodash.[|/*property*/add|] = add;
        \\
        \\    /** Detect free variable 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineGoToSourceDefinition(undefined, "start");
}

test "TestCodeFixInferFromUsageCallbackParameter7" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @noImplicitAny: false
        \\// @filename: /foo.js
        \\/** @type {(x: number) => number} */
        \\const foo = x => x + 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestCodeFixClassImplementInterfaceMultipleImplements1" {
    const content =
        \\// @strict: false
        \\interface I1 {
        \\    x: number;
        \\}
        \\interface I2 {
        \\    y: number;
        \\}
        \\
        \\class C implements I1,I2 {[|
        \\    |]y: number;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "\nx: number;\n", false, 0, 0);
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestSignatureHelpRestArgs2" {
    const content =
        \\// @strict: true
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @filename: index.js
        \\const promisify = function (thisArg, fnName) {
        \\    const fn = thisArg[fnName];
        \\    return function () {
        \\        return new Promise((resolve) => {
        \\            fn.call(thisArg, ...arguments, /*1*/);
        \\        });
        \\    };
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSignatureHelp(undefined);
}

test "TestQuickInfoJsDocTagsTypedef" {
    const content =
        \\// @noEmit: true
        \\// @allowJs: true
        \\// @Filename: quickInfoJsDocTagsTypedef.js
        \\/**
        \\ * Bar comment
        \\ * @typedef {Object} /*1*/Bar
        \\ * @property {string} baz - baz comment
        \\ * @property {string} qux - qux comment
        \\ */
        \\
        \\/**
        \\ * foo comment
        \\ * @param {/*2*/Bar} x - x comment
        \\ * @returns {Bar}
        \\ */
        \\function foo(x) {
        \\    return x;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestTypeAboveNumberLiteralExpressionStatement" {
    const content =
        \\
        \\// foo
        \\1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToBOF(undefined);
    _ = f.Insert(undefined, "var x;\n");
}

test "TestGetOccurrencesThis5" {
    const content =
        \\this;
        \\this;
        \\
        \\function f() {
        \\    this;
        \\    this;
        \\    () => this;
        \\    () => {
        \\        if (this) {
        \\            this;
        \\        }
        \\        else {
        \\            this.this;
        \\        }
        \\    }
        \\    function inside() {
        \\        this;
        \\        (function (_) {
        \\            this;
        \\        })(this);
        \\    }
        \\}
        \\
        \\namespace m {
        \\    function f() {
        \\        this;
        \\        this;
        \\        () => this;
        \\        () => {
        \\            if (this) {
        \\                this;
        \\            }
        \\            else {
        \\                this.this;
        \\            }
        \\        }
        \\        function inside() {
        \\            this;
        \\            (function (_) {
        \\                this;
        \\            })(this);
        \\        }
        \\    }
        \\}
        \\
        \\class A {
        \\    public b = this.method1;
        \\
        \\    public method1() {
        \\        this;
        \\        this;
        \\        () => this;
        \\        () => {
        \\            if (this) {
        \\                this;
        \\            }
        \\            else {
        \\                this.this;
        \\            }
        \\        }
        \\        function inside() {
        \\            this;
        \\            (function (_) {
        \\                this;
        \\            })(this);
        \\        }
        \\    }
        \\
        \\    private method2() {
        \\        this;
        \\        this;
        \\        () => this;
        \\        () => {
        \\            if (this) {
        \\                this;
        \\            }
        \\            else {
        \\                this.this;
        \\            }
        \\        }
        \\        function inside() {
        \\            this;
        \\            (function (_) {
        \\                this;
        \\            })(this);
        \\        }
        \\    }
        \\
        \\    public static staticB = [|this|].staticMethod1;
        \\
        \\    public static staticMethod1() {
        \\        [|this|];
        \\        [|this|];
        \\        () => [|this|];
        \\        () => {
        \\            if ([|this|]) {
        \\                [|this|];
        \\            }
        \\            else {
        \\                [|this|].this;
        \\            }
        \\        }
        \\        function inside() {
        \\            this;
        \\            (function (_) {
        \\                this;
        \\            })(this);
        \\        }
        \\    }
        \\
        \\    private static staticMethod2() {
        \\        [|this|];
        \\        [|this|];
        \\        () => [|this|];
        \\        () => {
        \\            if ([|this|]) {
        \\                [|this|];
        \\            }
        \\            else {
        \\                [|t/**/his|].this;
        \\            }
        \\        }
        \\        function inside() {
        \\            this;
        \\            (function (_) {
        \\                this;
        \\            })(this);
        \\        }
        \\    }
        \\}
        \\
        \\var x = {
        \\    f() {
        \\        this;
        \\    },
        \\    g() {
        \\        this;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestRenameForDefaultExport03" {
    const content =
        \\[|function /*1*/[|{| "contextRangeIndex": 0 |}f|]() {
        \\    return 100;
        \\}|]
        \\
        \\[|export default /*2*/[|{| "contextRangeIndex": 2 |}f|];|]
        \\
        \\var x: typeof /*3*/[|f|];
        \\
        \\var y = /*4*/[|f|]();
        \\
        \\/**
        \\ *  Commenting [|{| "inComment": true |}f|]
        \\ */
        \\[|namespace /*5*/[|{| "contextRangeIndex": 7 |}f|] {
        \\    var local = 100;
        \\}|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , ToAny(core.Filter(f.GetRangesByText().Get("f"), func(r *fourslash.RangeMarker) bool .{ return r.Marker == null || r.Marker.Data["inComment"] == null })));
}

test "TestCompletionListInStringLiterals2" {
    const content =
        \\"/*1*/       /*2*/\/*3*/
        \\ /*4*/   \\\/*5*/
        \\ /*6*/
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
//             .Exact = &.{},
//         },
//     });
}

test "TestIsDefinitionShorthandProperty" {
    const content =
        \\const /*1*/x = 1;
        \\const y: { /*2*/x: number } = { /*3*/x };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestCodeFixClassImplementInterfaceCallSignature" {
    const content =
        \\interface I {
        \\    (x: number, b: string): number;
        \\}
        \\class C implements I {[| |]}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestCompletionAfterDotDotDot" {
    const content =
        \\// @lib: es5
        \\.../**/
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
//             .Exact = CompletionGlobals,
//         },
//     });
}

test "TestCompletionListAtIdentifierDefinitionLocations_enumMembers" {
    const content =
        \\var aa = 1;
        \\enum a { /*enumValueName1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, f.Markers(), null);
}

test "TestTsxGoToDefinitionClassInDifferentFile" {
    const content =
        \\// @jsx: preserve
        \\// @Filename: C.tsx
        \\export default class /*def*/C {}
        \\// @Filename: a.tsx
        \\import C from "./C";
        \\const foo = </*use*/C />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    // try f.VerifyBaselineGoToDefinition(undefined, false, "use");
}

test "TestJsDocAugments" {
    const content =
        \\// @allowJs: true
        \\// @Filename: dummy.js
        \\/**
        \\ * @augments {Thing<string>}
        \\ */
        \\class MyStringThing extends Thing {
        \\    constructor() {
        \\        var x = this.mine;
        \\        x/**/;
        \\    }
        \\}
        \\// @Filename: declarations.d.ts
        \\declare class Thing<T> {
        \\    mine: T;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyQuickInfoIs(undefined, "(local var) x: string", "");
}

test "TestRenameDestructuringAssignment" {
    const content =
        \\interface I {
        \\    [|[|{| "contextRangeIndex": 0 |}x|]: number;|]
        \\}
        \\var a: I;
        \\var x;
        \\([|{ [|{| "contextRangeIndex": 2 |}x|]: x } = a|]);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "x");
}

test "TestFindAllRefsPrefixSuffixPreference" {
    const content =
        \\// @Filename: /file1.ts
        \\declare function log(s: string | number): void;
        \\[|const /*q0*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 0 |}q|] = 1;|]
        \\[|export { /*q1*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 2 |}q|] };|]
        \\const x = {
        \\    [|/*z0*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 4 |}z|]: 'value'|]
        \\}
        \\[|const { /*z1*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 6 |}z|] } = x;|]
        \\log(/*z2*/[|z|]);
        \\// @Filename: /file2.ts
        \\declare function log(s: string | number): void;
        \\[|import { /*q2*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 9 |}q|] } from "./file1";|]
        \\log(/*q3*/[|q|] + 1);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    // try f.VerifyBaselineFindAllReferences(undefined, "q0", "q1", "q2", "q3", "z0", "z1", "z2");
    // try f.VerifyBaselineRename(undefined, &.{.UseAliasesForRename = core.TSTrue}, f.Ranges()[1], f.Ranges()[3], f.Ranges()[10], f.Ranges()[11]);
    // try f.VerifyBaselineRename(undefined, &.{.UseAliasesForRename = core.TSFalse}, f.Ranges()[1], f.Ranges()[3], f.Ranges()[10], f.Ranges()[11]);
    // try f.VerifyBaselineRename(undefined, &.{.UseAliasesForRename = core.TSTrue}, f.Ranges()[5], f.Ranges()[7], f.Ranges()[8]);
    // try f.VerifyBaselineRename(undefined, &.{.UseAliasesForRename = core.TSFalse}, f.Ranges()[5], f.Ranges()[7], f.Ranges()[8]);
}

test "TestJsxElementMissingOpeningTagNoCrash" {
    const content =
        \\//@Filename: file.tsx
        \\declare function Foo(): any;
        \\let x = <></Fo/*$*/o>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "$", "let Foo: any", "");
}

test "TestCodeFixClassImplementInterfaceInheritsAbstractMethod" {
    const content =
        \\abstract class C1 { }
        \\abstract class C2 {
        \\    abstract fＡ<T extends number>(): T;
        \\}
        \\interface I1 extends C1, C2 { }
        \\class C3 implements I1 {[| |]}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I1'",
        .NewFileContent = "abstract class C1 { }\nabstract class C2 {\n    abstract fＡ<T extends number>(): T;\n}\ninterface I1 extends C1, C2 { }\nclass C3 implements I1 {\n    fＡ<T extends number>(): T {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestSyntacticClassificationsConflictDiff3Markers1" {
    const content =
        \\class C {
        \\<<<<<<< HEAD
        \\    v = 1;
        \\||||||| merged common ancestors
        \\    v = 3;
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

test "TestFormatDocumentWithTrivia" {
    const content =
        \\  
        \\// 1 below   
        \\    
        \\// 2 above   
        \\    
        \\let x;
        \\  
        \\// abc
        \\  
        \\let y;
        \\  
        \\// 3 above
        \\   
        \\while (true) {
        \\    while (true) {
        \\    }
        \\      
        \\    // 4 above   
        \\}
        \\  
        \\// 5 above  
        \\   
        \\   
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "\n// 1 below   \n\n// 2 above   \n\nlet x;\n\n// abc\n\nlet y;\n\n// 3 above\n\nwhile (true) {\n    while (true) {\n    }\n\n    // 4 above   \n}\n\n// 5 above  \n\n");
}

test "TestInlayHintsInteractiveRestParameters3" {
    const content =
        \\function fn(x: number, y: number, a: number, b: number) {
        \\    return x + y + a + b;
        \\}
        \\const foo: [x: number, y: number] = [1, 2];
        \\fn(...foo, 3, 4);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayParameterNameHints = lsutil.IncludeInlayParameterNameHintsAll}});
}

test "TestAutoImportPathsConfigDir" {
    const content =
        \\// @Filename: tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "paths": {
        \\            "@root/*": ["${configDir}/src/*"]
        \\        }
        \\    }
        \\}
        \\// @Filename: src/one.ts
        \\export const one = 1;
        \\// @Filename: src/foo/two.ts
        \\one/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"@root/one"}, null );
}

test "TestCallHierarchyFunctionAmbiguity3" {
    const content =
        \\// @filename: a.d.ts
        \\declare function foo(x?: number): void;
        \\// @filename: b.d.ts
        \\declare function /**/foo(x?: string): void;
        \\declare function foo(x?: boolean): void;
        \\// @filename: main.ts
        \\function bar() {
        \\    foo();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifyBaselineCallHierarchy(undefined);
}

test "TestCommentsEnumsFourslash" {
    const content =
        \\/** Enum of colors*/
        \\enum /*1*/Colors {
        \\    /** Fancy name for 'blue'*/
        \\    /*2*/Cornflower,
        \\    /** Fancy name for 'pink'*/
        \\    /*3*/FancyPink
        \\}
        \\var /*4*/x = /*5*/Colors./*6*/Cornflower;
        \\x = Colors./*7*/FancyPink;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "enum Colors", "Enum of colors");
    try f.VerifyQuickInfoAt(undefined, "2", "(enum member) Colors.Cornflower = 0", "Fancy name for 'blue'");
    try f.VerifyQuickInfoAt(undefined, "3", "(enum member) Colors.FancyPink = 1", "Fancy name for 'pink'");
    try f.VerifyQuickInfoAt(undefined, "4", "var x: Colors", "");
    try f.VerifyQuickInfoAt(undefined, "5", "enum Colors", "Enum of colors");
    try f.VerifyQuickInfoAt(undefined, "6", "(enum member) Colors.Cornflower = 0", "Fancy name for 'blue'");
    try f.VerifyQuickInfoAt(undefined, "7", "(enum member) Colors.FancyPink = 1", "Fancy name for 'pink'");
    // f.VerifyCompletions(undefined, "5", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "Colors",
//                     .Detail = undefined("enum Colors"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "Enum of colors",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"6", "7"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "Cornflower",
//                     .Detail = undefined("(enum member) Colors.Cornflower = 0"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "Fancy name for 'blue'",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "FancyPink",
//                     .Detail = undefined("(enum member) Colors.FancyPink = 1"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "Fancy name for 'pink'",
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestMemberListInsideObjectLiterals" {
    const content =
        \\namespace ObjectLiterals {
        \\    interface MyPoint {
        \\        x1: number;
        \\        y1: number;
        \\    }
        \\
        \\    var p1: MyPoint = {
        \\        /*1*/
        \\    };
        \\
        \\    var p2: MyPoint = {
        \\        x1: 5,
        \\        /*2*/
        \\    };
        \\
        \\    var p3: MyPoint = {
        \\        x1/*3*/:
        \\    };
        \\
        \\    var p4: MyPoint = {
        \\        /*4*/y1
        \\    };
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "3", "4"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "x1",
//                     .Detail = undefined("(property) MyPoint.x1: number"),
//                 },
//                 &.{
//                     .Label =  "y1",
//                     .Detail = undefined("(property) MyPoint.y1: number"),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"2"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "y1",
//                     .Detail = undefined("(property) MyPoint.y1: number"),
//                 },
//             },
//         },
//     });
}

test "TestAutoImportProvider_importsMap4" {
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
        \\    "#is-browser": {
        \\      "types": "./dist/env/browser.d.ts",
        \\      "default": "./dist/env/browser.js"
        \\    }
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/src/env/browser.ts
        \\export const isBrowser = true;
        \\// @Filename: /home/src/workspaces/project/src/a.ts
        \\isBrowser/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"#is-browser"}, null );
}

test "TestGetOccurrencesIsDefinitionOfBindingPattern" {
    const content =
        \\const { /*1*/x, y } = { /*2*/x: 1, y: 2 };
        \\const z = /*3*/x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestFormatComments" {
    const content =
        \\_.chain()
        \\// wow/*callChain1*/
        \\  .then()
        \\// waa/*callChain2*/
        \\    .then();
        \\wow(
        \\  3,
        \\// uaa/*argument1*/
        \\    4
        \\// wua/*argument2*/
        \\);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "callChain1");
    try f.VerifyCurrentLineContent(undefined, "    // wow");
    _ = f.GoToMarker(undefined, "callChain2");
    try f.VerifyCurrentLineContent(undefined, "    // waa");
    _ = f.GoToMarker(undefined, "argument1");
    try f.VerifyCurrentLineContent(undefined, "    // uaa");
    _ = f.GoToMarker(undefined, "argument2");
    try f.VerifyCurrentLineContent(undefined, "    // wua");
}

test "TestGetEditsForFileRename_directory_noUpdateNodeModulesImport" {
    const content =
        \\// @Filename: /a/b/file1.ts
        \\import { foo } from "foo";
        \\// @Filename: /a/b/node_modules/foo/index.d.ts
        \\export const foo = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyWillRenameFilesEdits(undefined, "/a/b", "/a/d", .{}, null );
}

test "TestNavigationBarItemsBindingPatternsInConstructor" {
    const content =
        \\class A {
        \\    x: any
        \\    constructor([a]: any) {
        \\    }
        \\}
        \\class B {
        \\    x: any;
        \\    constructor( {a} = { a: 1 }) {
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestMemberListOnContextualThis" {
    const content =
        \\interface A {
        \\    a: string;
        \\}
        \\declare function ctx(callback: (this: A) => string): string;
        \\ctx(function () { return th/*1*/is./*2*/a });
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "this: A", "");
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "a",
//                     .Detail = undefined("(property) A.a: string"),
//                 },
//             },
//         },
//     });
}

test "TestNavigationBarItemsStaticAndNonStaticNoMerge" {
    const content =
        \\class C {
        \\    static x;
        \\    x;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestQuickInfoInheritedLinkTag" {
    const content =
        \\export class C {
        \\     /**
        \\      * @deprecated Use {@link PerspectiveCamera#setFocalLength .setFocalLength()} and {@link PerspectiveCamera#filmGauge .filmGauge} instead.
        \\      */
        \\    m() { }
        \\}
        \\export class D extends C {
        \\    m() { } // crashes here
        \\}
        \\new C().m/**/ // and here (with a different thing trying to access undefined)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    try f.VerifyBaselineHover(undefined);
}

test "TestCodeFixForgottenThisPropertyAccess04" {
    const content =
        \\// @jsx: react
        \\// @jsxFactory: factory
        \\// @Filename: /a.tsx
        \\export class C {
        \\    foo() {
        \\        return <a.div />;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestGetJavaScriptCompletions10" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\/**
        \\ * @type {function(this:number)}
        \\ */
        \\function f() { this./**/ }
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

test "TestDocCommentTemplateJsSpecialPropertyAssignment" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\/*0*/module.exports = function(a) {};
        \\const myNamespace  = {};
        \\/*1*/myNamespace.myExport = function(x) {};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyJSDocCompletion(undefined, "0", 7, "/**\n * \n * @param {any} a\n */\n", null);
    // try f.VerifyJSDocCompletion(undefined, "1", 7, "/**\n * \n * @param {any} x\n */\n", null);
}

test "TestRenameLabel6" {
    const content =
        \\loop1: for (let i = 0; i <= 10; i++) {
        \\    loop2: for (let j = 0; j <= 10; j++) {
        \\        if (i === 5) continue loop1;
        \\        if (j === 5) break /**/loop2;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , "");
}

test "TestFormattingOfExportDefault" {
    const content =
        \\namespace Foo {
        \\/*1*/    export        default        class        Test { }
        \\}
        \\/*2*/export        default        function        bar() { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "    export default class Test { }");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "export default function bar() { }");
}

test "TestAsOperatorCompletion3" {
    const content =
        \\type T = number;
        \\var x;
        \\var y = x as /**/ // comment
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
//                 "T",
//             },
//         },
//     });
}

test "TestGetOccurrencesTryCatchFinally3" {
    const content =
        \\try {
        \\    try {
        \\    }
        \\    catch (x) {
        \\    }
        \\
        \\    [|t/*1*/r/*2*/y|] {
        \\    }
        \\    [|finall/*3*/y|] {
        \\    }
        \\}
        \\catch (e) {
        \\}
        \\finally {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Markers()));
}

test "TestQuickInfoDisplayPartsEnum4" {
    const content =
        \\const enum Foo {
        \\    "\t" = 9,
        \\    "\u007f" = 127,
        \\}
        \\Foo[/*1*/"\t"]
        \\Foo[/*2*/"\u007f"]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestGoToDefinitionObjectLiteralProperties2" {
    const content =
        \\type C = {
        \\  foo: string;
        \\  bar: number;
        \\};
        \\
        \\declare function fn<T extends C>(arg: T): T;
        \\
        \\fn({
        \\  foo/*1*/: "",
        \\  bar/*2*/: true,
        \\});
        \\
        \\const result = fn({
        \\  foo/*3*/: "",
        \\  bar/*4*/: 1,
        \\});
        \\
        \\// this one shouldn't go to the constraint type
        \\result.foo/*5*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1", "2", "3", "4", "5");
}

test "TestFormatSelectionSingleProperty" {
    const content =
        \\console.log({
        \\}, {
        \\/*1*/    a: 1,
        \\/*2*/    b: 2
        \\})
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatSelection(undefined, "1", "2");
    try f.VerifyCurrentFileContent(undefined, "console.log({\n}, {\n    a: 1,\n    b: 2\n})");
}

test "TestGoToDefinitionPrivateName" {
    const content =
        \\class A {
        \\    [|/*pnMethodDecl*/#method|]() { }
        \\    [|/*pnFieldDecl*/#foo|] = 3;
        \\    get [|/*pnPropGetDecl*/#prop|]() { return ""; }
        \\    set [|/*pnPropSetDecl*/#prop|](value: string) {  }
        \\    constructor() {
        \\        this.[|/*pnFieldUse*/#foo|]
        \\        this.[|/*pnMethodUse*/#method|]
        \\        this.[|/*pnPropUse*/#prop|]
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "pnFieldUse", "pnMethodUse", "pnPropUse");
}

test "TestRenameImportAndExportInDiffFiles" {
    const content =
        \\// @Filename: a.ts
        \\[|export var /*1*/[|{| "isDefinition": true, "contextRangeIndex": 0 |}a|];|]
        \\// @Filename: b.ts
        \\[|import { /*2*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 2 |}a|] } from './a';|]
        \\[|export { /*3*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 4 |}a|] };|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[3], f.Ranges()[5]);
}

test "TestUnusedEnumInNamespace1" {
    const content =
        \\// @noUnusedLocals: true
        \\[| namespace greeter {
        \\  enum enum1 {
        \\      Monday
        \\  }
        \\} |]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "namespace greeter {\n}", false, 0, 0);
}

test "TestGoToSource11_propertyOfAlias" {
    const content =
        \\// @lib: es5
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/a.js
        \\export const a = { /*end*/a: 'a' };
        \\// @Filename: /home/src/workspaces/project/a.d.ts
        \\export declare const a: { a: string };
        \\// @Filename: /home/src/workspaces/project/b.ts
        \\import { a } from './a';
        \\a.[|a/*start*/|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineGoToSourceDefinition(undefined, "start");
}

test "TestCompletionListOutsideOfClosedArrowFunction01" {
    const content =
        \\// no a or b
        \\/*1*/(a, b) => { }
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
//                 "b",
//             },
//         },
//     });
}

test "TestParameterWithDestructuring" {
    const content =
        \\const result = [{ a: 'hello' }]
        \\    .map(({ /*1*/a }) => /*2*/a)
        \\    .map(a => a);
        \\
        \\const f1 = (a: (b: string[]) => void) => {};
        \\f1(([a, b]) => { /*3*/a.charAt(0); });
        \\
        \\function f2({/*4*/a }: { a: string; }, [/*5*/b]: [string]) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(parameter) a: string", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(parameter) a: string", "");
    try f.VerifyQuickInfoAt(undefined, "3", "(parameter) a: string", "");
    try f.VerifyQuickInfoAt(undefined, "4", "(parameter) a: string", "");
    try f.VerifyQuickInfoAt(undefined, "5", "(parameter) b: string", "");
}

test "TestFindAllRefsWithShorthandPropertyAssignment" {
    const content =
        \\// @lib: es5
        \\var /*0*/name = "Foo";
        \\
        \\var obj = { /*1*/name };
        \\var obj1 = { /*2*/name: /*3*/name };
        \\obj./*4*/name;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "0", "3", "1", "2", "4");
}

test "TestCompletionOfAwaitPromise3" {
    const content =
        \\interface Foo { ["foo-foo"]: string }
        \\async function foo(x: Promise<Foo>) {
        \\   [|x./**/|]
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
//                 "then",
//                 &.{
//                     .Label =      "foo-foo",
//                     .InsertText = undefined("(await x)[\"foo-foo\"]"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "foo-foo",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestPathCompletionsAllowModuleAugmentationExtensions" {
    const content =
        \\// @Filename: /project/foo.css
        \\export const foo = 0;
        \\// @Filename: declarations.d.ts
        \\declare module "*.css" {}
        \\// @Filename: /project/main.ts
        \\import {} from ".//**/"
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
//                 "foo.css",
//             },
//         },
//     });
}

test "TestUnusedClassInNamespaceWithTrivia2" {
    const content =
        \\// @noUnusedLocals: true
        \\[| namespace greeter {
        \\  // Do not remove
        \\  /**
        \\   * JSDoc Comment
        \\   */
        \\  class /* comment2 */ class1 {
        \\  }
        \\} |]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "namespace greeter {\n   // Do not remove\n}", false, 0, 0);
}

test "TestAutomaticConstructorToggling" {
    const content =
        \\class A<T> { }
        \\class B<T> {/*B*/ }
        \\class C<T> { /*C*/constructor(val: T) { } }
        \\class D<T> { constructor(/*D*/val: T) { } }
        \\
        \\new /*Asig*/A<string>();
        \\new /*Bsig*/B("");
        \\new /*Csig*/C("");
        \\new /*Dsig*/D<string>();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "B");
    _ = f.Insert(undefined, "constructor(val: T) { }");
    try f.VerifyQuickInfoAt(undefined, "Asig", "constructor A<string>(): A<string>", "");
    try f.VerifyQuickInfoAt(undefined, "Bsig", "constructor B<string>(val: string): B<string>", "");
    try f.VerifyQuickInfoAt(undefined, "Csig", "constructor C<string>(val: string): C<string>", "");
    try f.VerifyQuickInfoAt(undefined, "Dsig", "constructor D<string>(val: string): D<string>", "");
    _ = f.GoToMarker(undefined, "C");
    _ = f.DeleteAtCaret(undefined, 23);
    try f.VerifyQuickInfoAt(undefined, "Asig", "constructor A<string>(): A<string>", "");
    try f.VerifyQuickInfoAt(undefined, "Bsig", "constructor B<string>(val: string): B<string>", "");
    try f.VerifyQuickInfoAt(undefined, "Csig", "constructor C<unknown>(): C<unknown>", "");
    try f.VerifyQuickInfoAt(undefined, "Dsig", "constructor D<string>(val: string): D<string>", "");
    _ = f.GoToMarker(undefined, "D");
    _ = f.DeleteAtCaret(undefined, 6);
    try f.VerifyQuickInfoAt(undefined, "Asig", "constructor A<string>(): A<string>", "");
    try f.VerifyQuickInfoAt(undefined, "Bsig", "constructor B<string>(val: string): B<string>", "");
    try f.VerifyQuickInfoAt(undefined, "Csig", "constructor C<unknown>(): C<unknown>", "");
    try f.VerifyQuickInfoAt(undefined, "Dsig", "constructor D<string>(): D<string>", "");
}

test "TestQuickInfoDisplayPartsArrowFunctionExpression" {
    const content =
        \\var /*1*/x = /*5*/a => 10;
        \\var /*2*/y = (/*6*/a, /*7*/b) => 10;
        \\var /*3*/z = (/*8*/a: number) => 10;
        \\var /*4*/z2 = () => 10;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestRenameJsThisProperty06" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\var C = class {
        \\  constructor(y) {
        \\    this.x = y;
        \\  }
        \\}
        \\[|C.prototype.[|{| "contextRangeIndex": 0 |}z|] = 1;|]
        \\var t = new C(12);
        \\[|t.[|{| "contextRangeIndex": 2 |}z|] = 11;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "z");
}

test "TestCodeFixClassImplementInterfaceComputedPropertyLiterals" {
    const content =
        \\interface I {
        \\    ["foo"](o: any): boolean;
        \\    ["x"]: boolean;
        \\    [1](): string;
        \\    [2]: boolean;
        \\}
        \\
        \\class C implements I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "interface I {\n    [\"foo\"](o: any): boolean;\n    [\"x\"]: boolean;\n    [1](): string;\n    [2]: boolean;\n}\n\nclass C implements I {\n    [\"foo\"](o: any): boolean {\n        throw new Error(\"Method not implemented.\");\n    }\n    [\"x\"]: boolean;\n    [1](): string {\n        throw new Error(\"Method not implemented.\");\n    }\n    [2]: boolean;\n}",
        .Index = 0,
    });
}

test "TestAsOperatorCompletion" {
    const content =
        \\type T = number;
        \\var x;
        \\var y = x as /**/
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
//                 "T",
//             },
//         },
//     });
}

test "TestCompletionsImport_exportEquals" {
    const content =
        \\// @module: commonjs
        \\// @esModuleInterop: false
        \\// @allowSyntheticDefaultImports: false
        \\// @Filename: /a.d.ts
        \\declare function a(): void;
        \\declare namespace a {
        \\    export interface b {}
        \\}
        \\export = a;
        \\// @Filename: /b.ts
        \\a/*0*/;
        \\let x: b/*1*/;
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
//                     .Label = "a",
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
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "b",
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
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined("1"), &.{
//         .Name =        "b",
//         .Source =      "./a",
//         .Description = "Add import from \"./a\"",
//         .NewFileContent = undefined("import { b } from \"./a\";\n\na;\nlet x: b;"),
//     });
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined("0"), &.{
//         .Name =        "a",
//         .Source =      "./a",
//         .Description = "Add import from \"./a\"",
//         .NewFileContent = undefined("import { b } from \"./a\";\nimport a = require(\"./a\");\n\na;\nlet x: b;"),
//     });
}

test "TestAutoImportFileExcludePatterns9" {
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
        \\import { Event } from '../event/event';
        \\export { Event };
        \\// @Filename: /src/vs/test.ts
        \\import { Event } from './event/event';
        \\export { Event };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'Parts'",
        .NewFileContent = "import { Event } from '../test';\nimport { Parts } from './parts';\nexport class EditorParts implements Parts {\n    options: Event;\n}",
        .Index =           0,
        .UserPreferences = &.{.AutoImportFileExcludePatterns = &.{"src/vs/workbench/workbench*"}},
    });
}

test "TestImportNameCodeFixNewImportExportEqualsESNextInteropOn" {
    const content =
        \\// @EsModuleInterop: true
        \\// @Module: es2015
        \\// @Filename: /foo.d.ts
        \\declare module "foo" {
        \\  const foo: number;
        \\  export = foo;
        \\}
        \\// @Filename: /index.ts
        \\[|foo|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/index.ts");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import foo from \"foo\";\n\nfoo",
    }, null );
}

test "TestImportNameCodeFix_jsCJSvsESM1" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: types/dep.d.ts
        \\export declare class Dep {}
        \\// @Filename: index.js
        \\Dep/**/
        \\// @Filename: util.js
        \\import fs from 'fs';
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { Dep } from \"./types/dep\";\n\nDep",
    }, null );
}

test "TestCompletionsBeforeRestArg1" {
    const content =
        \\// @target: esnext
        \\// @lib: esnext
        \\const layers = Object.assign({}, /*1*/...[]);
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
//             .Includes = CompletionGlobals,
//         },
//     });
}

test "TestForceIndentAfterNewLineInsert" {
    const content =
        \\function f1()
        \\{ return 0; }
        \\function f2()
        \\{
        \\return 0;
        \\}
        \\function g()
        \\{ function h() {
        \\return 0;
        \\}}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "function f1() { return 0; }\nfunction f2() {\n    return 0;\n}\nfunction g() {\n    function h() {\n        return 0;\n    }\n}");
}

test "TestCodeFixSpellingCaseWeight2" {
    const content =
        \\let ABCDEFGHI = 1;
        \\let abcdefghij = 1;
        \\[|abcdefghi|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "ABCDEFGHI", false, 0, 0);
}

test "TestJsxTagNameCompletionWithExistingJsxInitializer" {
    const content =
        \\// @filename: /foo.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        foo: {
        \\            className: string;
        \\        }
        \\    }
        \\}
        \\<foo cl/**/={""} />
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
//                     .Label =  "className",
//                     .Detail = undefined("(property) className: string"),
//                 },
//             },
//         },
//     });
}

test "TestCodeFixRequireInTs5" {
    const content =
        \\// @Filename: /a.ts
        \\const a = 1;
        \\const b = 2;
        \\const foo = require(
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestFindAllRefs_importType_js" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /a.js
        \\/**/module.exports = class C {};
        \\module.exports.D = class D {};
        \\// @Filename: /b.js
        \\/** @type {import("./a")} */
        \\const x = 0;
        \\/** @type {import("./a").D} */
        \\const y = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    // try f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestImportTypeCompletions9" {
    const content =
        \\// @target: esnext
        \\// @filename: /foo.ts
        \\export interface Foo {}
        \\// @filename: /bar.ts
        \\[|import { type /**/ }|]
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
//                     .InsertText = undefined("import { type Foo } from \"./foo\";"),
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

test "TestFindAllRefsJsDocImportTag5" {
    const content =
        \\// @checkJs: true
        \\// @Filename: /a.js
        \\export default function /*0*/a() {}
        \\// @Filename: /b.js
        \\/** @import /*1*/a, * as ns from "./a" */
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "0", "1");
}

test "TestGetOccurrencesThrow3" {
    const content =
        \\function f(a: number) {
        \\    try {
        \\        [|throw|] "Hello";
        \\
        \\        try {
        \\            throw 10;
        \\        }
        \\        catch (x) {
        \\            return 100;
        \\        }
        \\        finally {
        \\            [|thr/**/ow|] 10;
        \\        }
        \\    }
        \\    catch (x) {
        \\        throw "Something";
        \\    }
        \\    finally {
        \\        throw "Also something";
        \\    }
        \\    if (a > 0) {
        \\        return (function () {
        \\            return;
        \\            return;
        \\            return;
        \\
        \\            if (false) {
        \\                return true;
        \\            }
        \\            throw "Hello!";
        \\        })() || true;
        \\    }
        \\
        \\    throw 10;
        \\
        \\    var unusued = [1, 2, 3, 4].map(x => { throw 4 })
        \\
        \\    return;
        \\    return true;
        \\    throw false;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestGoToDefinitionSimple" {
    const content =
        \\// @Filename: Definition.ts
        \\class /*2*/c { }
        \\// @Filename: Consumption.ts
        \\ var n = new [|/*1*/c|]();
        \\ var n = new [|c/*3*/|]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1", "3");
}

test "TestGetJavaScriptCompletions5" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\/**
        \\ * @template T
        \\ * @param {T} a
        \\ * @return {T} */
        \\function foo(a) { }
        \\let x = foo;
        \\foo(1)./**/
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

test "TestFindAllRefs_importType_meaningAtLocation" {
    const content =
        \\// @Filename: /a.ts
        \\/*1*/export type /*2*/T = 0;
        \\/*3*/export const /*4*/T = 0;
        \\// @Filename: /b.ts
        \\const x: import("./a")./*5*/T = 0;
        \\const x: typeof import("./a")./*6*/T = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6");
}

test "TestImportNameCodeFixNewImportAmbient2" {
    const content =
        \\[|/*!
        \\ * I'm a license or something
        \\ */
        \\f1/*0*/();|]
        \\// @Filename: ambientModule.ts
        \\ declare module "ambient-module" {
        \\    export function f1();
        \\    export var v1;
        \\ }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "/*!\n * I'm a license or something\n */\n\nimport { f1 } from \"ambient-module\";\n\nf1();",
    }, null );
}

test "TestQuickinfoVerbosityToplevelTruncation1" {
    const content =
        \\export enum LargeEnum/*1*/ {
        \\    Member1,
        \\    Member2,
        \\    Member3,
        \\    Member4,
        \\    Member5,
        \\    Member6,
        \\    Member7,
        \\    Member8,
        \\    Member9,
        \\    Member10,
        \\    Member11,
        \\    Member12,
        \\    Member13,
        \\    Member14,
        \\    Member15,
        \\    Member16,
        \\    Member17,
        \\    Member18,
        \\    Member19,
        \\    Member20,
        \\    Member21,
        \\    Member22,
        \\    Member23,
        \\    Member24,
        \\    Member25,
        \\}
        \\export interface LargeInterface/*2*/ {
        \\    property1: string;
        \\    property2: number;
        \\    property3: boolean;
        \\    property4: Date;
        \\    property5: string[];
        \\    property6: number[];
        \\    property7: boolean[];
        \\    property8: { [key: string]: unknown };
        \\    property9: string | null;
        \\    property10: number | null;
        \\    property11: boolean | null;
        \\    property12: Date | null;
        \\    property13: string | number;
        \\    property14: number | boolean;
        \\    property15: string | boolean;
        \\    property16: Array<{ id: number; name: string }>;
        \\    property17: Array<{ key: string; value: unknown }>;
        \\    property18: { nestedProp1: string; nestedProp2: number };
        \\    property19: { nestedProp3: boolean; nestedProp4: Date };
        \\    property20: () => void;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{1}, .@"2" = .{1}});
}

test "TestGoToDefinitionJsModuleName" {
    const content =
        \\// @allowJs: true
        \\// @Filename: foo.js
        \\/*2*/module.exports = {};
        \\// @Filename: bar.js
        \\var x = require([|/*1*/"./foo"|]);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestNavigationBarItemsMissingName1" {
    const content =
        \\export function
        \\class C {
        \\    foo() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCodeFixClassImplementInterfaceNoBody" {
    const content =
        \\interface I {
        \\   m(): void
        \\}
        \\class C/*c*/ implements I
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyErrorExistsBeforeMarker(undefined, "c");
    _ = f.GoToMarker(undefined, "c");
    try f.VerifyCodeFixAvailable(undefined, &.{"Implement interface 'I'"});
}

test "TestInlayHintsMultifile1" {
    const content =
        \\// @Filename: /a.ts
        \\export interface Foo { a: string }
        \\// @Filename: /b.ts
        \\async function foo () {
        \\    return {} as any as import('./a').Foo
        \\}
        \\function bar () { return import('./a') }
        \\async function main () {
        \\    const a = await foo()
        \\    const b = await bar()
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayVariableTypeHints = core.TSTrue, .IncludeInlayFunctionLikeReturnTypeHints = core.TSTrue}});
}

test "TestNavigationBarAssignmentTypes" {
    const content =
        \\'use strict'
        \\const a = {
        \\    ...b,
        \\    c,
        \\    d: 0
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCompletionsWrappedClass" {
    const content =
        \\class Client {
        \\    private close() { }
        \\    public open() { }
        \\}
        \\type Wrap<T> = T &
        \\{
        \\    [K in Extract<keyof T, string> as 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "a", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "open",
//                 "openWrapped",
//             },
//         },
//     });
}

test "TestCodeFixUnusedIdentifier_parameter1" {
    const content =
        \\// @noUnusedLocals: true
        \\// @noUnusedParameters: true
        \\function g(a, b) { b; }
        \\g(1, 2);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined, "Remove unused declaration for: 'a'");
}

test "TestCompletionListInObjectBindingPattern10" {
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
        \\var foo: J[];
        \\var [{ property1: { propertyOfI_1, }, /*1*/ }, { /*2*/ }] = foo;
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
//                 "property2",
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
//                 "property1",
//                 "property2",
//             },
//         },
//     });
}

test "TestIsDefinitionAcrossModuleProjects" {
    const content =
        \\// @Filename: /home/src/workspaces/project/a/index.ts
        \\import { NS } from "../b";
        \\import { I } from "../c";
        \\
        \\declare module "../b" {
        \\    export namespace NS {
        \\        export function /*1*/FA();
        \\    }
        \\}
        \\
        \\declare module "../c" {
        \\    export interface /*2*/I {
        \\        /*3*/FA();
        \\    }
        \\}
        \\
        \\const ia: I = {
        \\    FA: NS.FA,
        \\    FC() { },
        \\};
        \\// @Filename: /home/src/workspaces/project/a/tsconfig.json
        \\{
        \\    "extends": "../tsconfig.settings.json",
        \\    "references": [
        \\        { "path": "../b" },
        \\        { "path": "../c" },
        \\    ],
        \\    "files": [
        \\        "index.ts",
        \\    ],
        \\}
        \\// @Filename: /home/src/workspaces/project/a2/index.ts
        \\import { NS } from "../b";
        \\import { I } from "../c";
        \\
        \\declare module "../b" {
        \\    export namespace NS {
        \\        export function /*4*/FA();
        \\    }
        \\}
        \\
        \\declare module "../c" {
        \\    export interface /*5*/I {
        \\        /*6*/FA();
        \\    }
        \\}
        \\
        \\const ia: I = {
        \\    FA: NS.FA,
        \\    FC() { },
        \\};
        \\// @Filename: /home/src/workspaces/project/a2/tsconfig.json
        \\{
        \\    "extends": "../tsconfig.settings.json",
        \\    "references": [
        \\        { "path": "../b" },
        \\        { "path": "../c" },
        \\    ],
        \\    "files": [
        \\        "index.ts",
        \\    ],
        \\}
        \\// @Filename: /home/src/workspaces/project/b/index.ts
        \\export namespace NS {
        \\    export function /*7*/FB() {}
        \\}
        \\
        \\export interface /*8*/I {
        \\    /*9*/FB();
        \\}
        \\
        \\const ib: I = { FB() {} };
        \\// @Filename: /home/src/workspaces/project/b/other.ts
        \\export const Other = 1;
        \\// @Filename: /home/src/workspaces/project/b/tsconfig.json
        \\{
        \\    "extends": "../tsconfig.settings.json",
        \\    "files": [
        \\        "index.ts",
        \\        "other.ts",
        \\    ],
        \\}
        \\// @Filename: /home/src/workspaces/project/c/index.ts
        \\export namespace NS {
        \\    export function /*10*/FC() {}
        \\}
        \\
        \\export interface /*11*/I {
        \\    /*12*/FC();
        \\}
        \\
        \\const ic: I = { FC() {} };
        \\// @Filename: /home/src/workspaces/project/c/tsconfig.json
        \\{
        \\    "extends": "../tsconfig.settings.json",
        \\    "files": [
        \\        "index.ts",
        \\    ],
        \\}
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "composite": true,
        \\        "lib": ["es5"],
        \\    },
        \\    "references": [
        \\        { "path": "a" },
        \\        { "path": "a2" },
        \\    ],
        \\    "files": []
        \\}
        \\// @Filename: /home/src/workspaces/project/tsconfig.settings.json
        \\{
        \\    "compilerOptions": {
        \\        "composite": true,
        \\        "skipLibCheck": true,
        \\        "declarationMap": true,
        \\        "module": "CommonJS",
        \\        "emitDeclarationOnly": true,
        \\        "lib": ["es5"],
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12");
}

test "TestFindAllRefsExportConstEqualToClass" {
    const content =
        \\// @Filename: /a.ts
        \\class C {}
        \\export const /*0*/D = C;
        \\// @Filename: /b.ts
        \\import { /*1*/D } from "./a";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "0", "1");
}

test "TestFormattingInExpressionsInTsx" {
    const content =
        \\// @Filename: test.tsx
        \\import * as React from "react";
        \\<div
        \\    autoComplete={(function () {
        \\return true/*1*/
        \\    })() }
        \\    >
        \\</div>
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, ";");
    try f.VerifyCurrentLineContent(undefined, "        return true;");
}

test "TestImportCompletionsPackageJsonImportsPatternRootWildcard" {
    const content =
        \\// @module: nodenext
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#/*": "./src/*"
        \\  }
        \\}
        \\// @Filename: /src/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /src/features/bar.ts
        \\export function bar(): any;
        \\// @Filename: /a.ts
        \\import {} from "#//*1*/";
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
//                 "something.js",
//                 "features",
//             },
//         },
//     });
}

test "TestCompletionEntryForArgumentConstrainedToString" {
    const content =
        \\declare function test<P extends "a" | "b">(p: P): void;
        \\
        \\test(/*ts*/)
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"ts"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "\"a\"",
//                 "\"b\"",
//             },
//         },
//     });
}

test "TestSignatureHelpCommentsFunctionDeclaration" {
    const content =
        \\/** This comment should appear for foo*/
        \\function foo() {
        \\}
        \\foo(/*4*/);
        \\/** This is comment for function signature*/
        \\function fooWithParameters(/** this is comment about a*/a: string,
        \\    /** this is comment for b*/
        \\    b: number) {
        \\    var d = a;
        \\}
        \\fooWithParameters(/*10*/"a",/*11*/10);
        \\/**
        \\* Does something
        \\* @param a a string
        \\*/
        \\declare function fn(a: string);
        \\fn(/*12*/"hello");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSignatureHelp(undefined);
}

test "TestJsxElementExtendsNoCrash2" {
    const content =
        \\// @filename: index.tsx
        \\<T extends/>
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifySuggestionDiagnostics(undefined, null);
}

test "TestOrganizeImportsReactJsx" {
    const content =
        \\// @allowSyntheticDefaultImports: true
        \\// @moduleResolution: bundler
        \\// @noUnusedLocals: true
        \\// @target: es2018
        \\// @jsx: react-jsx
        \\// @filename: test.tsx
        \\import React from 'react';
        \\export default () => <div></div>
        \\// @filename: node_modules/react/package.json
        \\{
        \\    "name": "react",
        \\    "types": "index.d.ts"
        \\}
        \\// @filename: node_modules/react/index.d.ts
        \\export = React;
        \\declare namespace JSX {
        \\    interface IntrinsicElements { [x: string]: any; }
        \\}
        \\declare namespace React {}
        \\// @filename: node_modules/react/jsx-runtime.d.ts
        \\import './';
        \\// @filename: node_modules/react/jsx-dev-runtime.d.ts
        \\import './';
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "test.tsx");
    // try f.VerifyOrganizeImports(undefined,
//         "export default () => <div></div>",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestQuickInfoTemplateTag" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /foo.js
        \\/**
        \\ * Doc
        \\ * @template {new (...args: any[]) => any} T
        \\ * @param {T} cls
        \\ */
        \\function /**/myMixin(cls) {
        \\    return class extends cls {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "function myMixin<T extends new (...args: any[]) => any>(cls: T): {\n    new (...args: any[]): (Anonymous class);\n    prototype: myMixin<any>.(Anonymous class);\n} & T", "Doc");
}

test "TestGoToDefinitionImportedNames11" {
    const content =
        \\// @allowjs: true
        \\// @Filename: a.js
        \\ class /*classDefinition*/Class {
        \\     f;
        \\ }
        \\ module.exports = { Class };
        \\// @Filename: b.js
        \\const { Class } = require("./a");
        \\ [|/*classAliasDefinition*/Class|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "classAliasDefinition");
}

test "TestOrganizeImportsType4" {
    const content =
        \\import {
        \\    d, 
        \\    type d as D,
        \\    type c,
        \\    c as C,
        \\    b,
        \\    b as B,
        \\    type A,
        \\    a
        \\} from './foo';
        \\console.log(A, a, B, b, c, C, d, D);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "import {\n    type A,\n    a,\n    b,\n    b as B,\n    type c,\n    c as C,\n    d,\n    type d as D\n} from './foo';\nconsole.log(A, a, B, b, c, C, d, D);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSTrue,
//             .OrganizeImportsTypeOrder =  lsutil.OrganizeImportsTypeOrderInline,
//         },
//     );
}

test "TestCompletionForQuotedPropertyInPropertyAssignment2" {
    const content =
        \\export interface Config {
        \\   files: ConfigFiles
        \\}
        \\export interface ConfigFiles {
        \\  jspm: string;
        \\  'jspm:browser': string;
        \\}
        \\let config: Config;
        \\config = {
        \\   files: {
        \\       /*0*/: '',
        \\       '[|/*1*/|]': ''
        \\   }
        \\}
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
//             .Exact = &.{
//                 "\"jspm:browser\"",
//                 "jspm",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "jspm",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "jspm",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "jspm:browser",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "jspm:browser",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestSmartSelection_lastBlankLine" {
    const content =
        \\class C {}
        \\/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSelectionRanges(undefined);
}

test "TestFindAllRefsConstructorFunctions" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\function f() {
        \\    /*1*/this./*2*/x = 0;
        \\}
        \\f.prototype.setX = function() {
        \\    /*3*/this./*4*/x = 1;
        \\}
        \\f.prototype.useX = function() { this./*5*/x; }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5");
}

test "TestCompletionForQuotedPropertyInPropertyAssignment3" {
    const content =
        \\ let configFiles1: {
        \\     jspm: string;
        \\     'jspm:browser': string;
        \\ } = {
        \\         /*0*/: "",
        \\ }
        \\ let configFiles2: {
        \\     jspm: string;
        \\     'jspm:browser': string;
        \\ } = {
        \\        jspm: "",
        \\        '[|/*1*/|]': ""
        \\ }
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
//             .Exact = &.{
//                 "\"jspm:browser\"",
//                 "jspm",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "jspm",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "jspm",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "jspm:browser",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "jspm:browser",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestCodeFixConvertToMappedObjectType13" {
    const content =
        \\let x: {
        \\    [p: ""]: string;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined, "fixConvertToMappedObjectType");
}

test "TestSmartSelection_JSDocTags2" {
    const content =
        \\/**
        \\ * @type {/**/string}
        \\ */
        \\const foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSelectionRanges(undefined);
}

test "TestQuickinfoVerbosityNoErrorTruncation1" {
    const content =
        \\// @noErrorTruncation: true
        \\type /*1*/T = [
        \\  1, 2, 3, 4, 5, 6, 7, 8, 9, 0,
        \\  1, 2, 3, 4, 5, 6, 7, 8, 9, 0,
        \\  1, 2, 3, 4, 5, 6, 7, 8, 9, 0,
        \\  1, 2, 3, 4, 5, 6, 7, 8, 9, 0,
        \\  1, 2, 3, 4, 5, 6, 7, 8, 9, 0,
        \\  1, 2, 3, 4, 5, 6, 7, 8, 9, 0,
        \\  1, 2, 3, 4, 5, 6, 7, 8, 9, 0,
        \\  1, 2, 3, 4, 5, 6, 7, 8, 9, 0,
        \\  1, 2, 3, 4, 5, 6, 7, 8, 9, 0,
        \\  1, 2, 3, 4, 5, 6, 7, 8, 9, 0,
        \\  1, 2, 3, 4, 5, 6, 7, 8, 9, 0,
        \\  1, 2, 3, 4, 5, 6, 7, 8, 9, 0,
        \\  1, 2, 3, 4, 5, 6, 7, 8, 9, 0,
        \\  1, 2, 3, 4, 5, 6, 7, 8, 9, 0,
        \\  1, 2, 3, 4, 5, 6, 7, 8, 9, 0,
        \\  1, 2, 3, 4, 5, 6, 7, 8, 9, 0,
        \\  1, 2, 3, 4, 5, 6, 7, 8, 9, 0,
        \\  'still good', 'now truncating'
        \\];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{0, 1}});
}

test "TestFindAllRefsPrivateNameAccessors" {
    const content =
        \\class C {
        \\    /*1*/get /*2*/#foo(){ return 1; }
        \\    /*3*/set /*4*/#foo(value: number){  }
        \\    constructor() {
        \\        this./*5*/#foo();
        \\    }
        \\}
        \\class D extends C {
        \\    constructor() {
        \\        super()
        \\        this.#foo = 20;
        \\    }
        \\}
        \\class E {
        \\    /*6*/get /*7*/#foo(){ return 1; }
        \\    /*8*/set /*9*/#foo(value: number){  }
        \\    constructor() {
        \\        this./*10*/#foo();
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8", "9", "10");
}

test "TestFormattingOnNestedStatements" {
    const content =
        \\{
        \\/*1*/{
        \\/*3*/test
        \\}/*2*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatSelection(undefined, "1", "2");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "    {");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "        test");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "    }");
}

test "TestNavigationBarImports" {
    const content =
        \\import a, {b} from "m";
        \\import c = require("m");
        \\import * as d from "m";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCodeFixClassImplementInterfaceUndeclaredSymbol" {
    const content =
        \\interface I {
        \\   x: T;
        \\}
        \\
        \\class C implements I { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFixAvailable(undefined, &.{"Implement interface 'I'"});
}

test "TestOutliningSpansForParenthesizedExpression" {
    const content =
        \\const a = [|(
        \\    true
        \\        ? true
        \\        : false
        \\            ? true
        \\            : false
        \\)|];
        \\
        \\const b = ( 1 );
        \\
        \\const c = [|(
        \\    1
        \\)|];
        \\
        \\( 1 );
        \\
        \\[|(
        \\    [|(
        \\        [|(
        \\            1
        \\        )|]
        \\    )|]
        \\)|];
        \\
        \\[|(
        \\    [|(
        \\        ( 1 )
        \\    )|]
        \\)|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOutliningSpans(undefined);
}

test "TestFindAllRefsJsDocImportTag4" {
    const content =
        \\// @checkJs: true
        \\// @Filename: /component.js
        \\export class Component {
        \\  constructor() {
        \\    this.id_ = Math.random();
        \\  }
        \\  id() {
        \\    return this.id_;
        \\  }
        \\}
        \\// @Filename: /spatial-navigation.js
        \\/** @import * as C from './component.js' */
        \\
        \\export class SpatialNavigation {
        \\  /**
        \\   * @param {C.Component} component
        \\   */
        \\  add(component) {}
        \\}
        \\// @Filename: /player.js
        \\import * as C from './component.js';
        \\
        \\/**
        \\ * @extends C/*1*/.Component
        \\ */
        \\export class Player extends Component {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestGetOccurrencesIsDefinitionOfVariable" {
    const content =
        \\/*1*/var /*2*/x = 0;
        \\var assignmentRightHandSide = /*3*/x;
        \\var assignmentRightHandSide2 = 1 + /*4*/x;
        \\
        \\/*5*/x = 1;
        \\/*6*/x = /*7*/x + /*8*/x;
        \\
        \\/*9*/x == 1;
        \\/*10*/x <= 1;
        \\
        \\var preIncrement = ++/*11*/x;
        \\var postIncrement = /*12*/x++;
        \\var preDecrement = --/*13*/x;
        \\var postDecrement = /*14*/x--;
        \\
        \\/*15*/x += 1;
        \\/*16*/x <<= 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16");
}

test "TestAutoImportAllowImportingTsExtensionsPackageJsonImports2" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "nodenext",
        \\    "allowImportingTsExtensions": true,
        \\    "rootDir": "src",
        \\    "outDir": "dist",
        \\    "declarationDir": "types",
        \\    "declaration": true
        \\  }
        \\}
        \\// @Filename: /package.json
        \\{
        \\  "name": "self",
        \\  "type": "module",
        \\  "imports": {
        \\    "#*": {
        \\      "types": "./types/*",
        \\      "default": "./dist/*"
        \\    }
        \\  }
        \\}
        \\// @Filename: /src/add.ts
        \\export function add(a: number, b: number) {}
        \\// @Filename: /src/index.ts
        \\add/*imports*/;
        \\external/*exports*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "imports", &.{"#add.js"}, null );
}

test "TestRenameFromNodeModulesDep1" {
    const content =
        \\// @Filename: /index.ts
        \\import { /*okWithAlias*/[|Foo|] } from "foo";
        \\declare const f: Foo;
        \\f./*notOk*/bar;
        \\// @Filename: /tsconfig.json
        \\ { }
        \\// @Filename: /node_modules/foo/package.json
        \\ { "types": "index.d.ts" }
        \\// @Filename: /node_modules/foo/index.d.ts
        \\export interface Foo {
        \\    bar: string;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "okWithAlias");
    // try f.VerifyRenameSucceeded(undefined, &.{.UseAliasesForRename = core.TSTrue});
    // try f.VerifyRenameFailed(undefined, &.{.UseAliasesForRename = core.TSFalse});
    _ = f.GoToMarker(undefined, "notOk");
    // try f.VerifyRenameFailed(undefined, null );
}

test "TestQuickInfoOnJsxIntrinsicDeclaredUsingTemplateLiteralTypeSignatures" {
    const content =
        \\// @jsx: react
        \\// @filename: /a.tsx
        \\declare namespace JSX {
        \\  interface IntrinsicElements {
        \\    [k: 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestGoToDefinitionClassConstructors" {
    const content =
        \\// @filename: definitions.ts
        \\export class Base {
        \\    constructor(protected readonly cArg: string) {}
        \\}
        \\
        \\export class Derived extends Base {
        \\    readonly email = this.cArg.getByLabel('Email')
        \\    readonly password =  this.cArg.getByLabel('Password')
        \\}
        \\// @filename: main.ts
        \\import { Derived } from './definitions'
        \\const derived = new [|/*Derived*/Derived|](cArg)
        \\// @filename: defInSameFile.ts
        \\import { Base } from './definitions'
        \\class SameFile extends Base {
        \\    readonly name: string = 'SameFile'
        \\}
        \\const SameFile = new [|/*SameFile*/SameFile|](cArg)
        \\const wrapper = new [|/*Base*/Base|](cArg)
        \\// @filename: hasConstructor.ts
        \\import { Base } from './definitions'
        \\class HasConstructor extends Base {
        \\    constructor() {}
        \\    readonly name: string = '';
        \\}
        \\const hasConstructor = new [|/*HasConstructor*/HasConstructor|](cArg)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "Derived", "SameFile", "HasConstructor", "Base");
}

test "TestFormatSpaceAfterTemplateHeadAndMiddle" {
    const content =
        \\const a1 = 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts405);
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "const a1 = `${ 1 }${ 1 }`;\n" ++ "const a2 = `\n" ++ "    ${ 1 }${ 1 }\n" ++ "`;\n" ++ "const a3 = `\n" ++ "\n" ++ "\n" ++ "    ${ 1 }${ 1 }\n" ++ "`;\n" ++ "const a4 = `\n" ++ "\n" ++ "    ${ 1 }${ 1 }\n" ++ "\n" ++ "`;\n" ++ "const a5 = `text ${ 1 } text ${ 1 } text`;\n" ++ "const a6 = `\n" ++ "    text ${ 1 }\n" ++ "    text ${ 1 }\n" ++ "    text\n" ++ "`;");
}

test "TestGoToDefinitionExpandoElementAccess" {
    const content =
        \\function f() {}
        \\f[/*0*/"x"] = 0;
        \\f[[|/*1*/"x"|]] = 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestFindAllRefsJsDocTypeDef_js" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\/** /*1*/@typedef {number} /*2*/T */
        \\
        \\/**
        \\ * @return {/*3*/T}
        \\ */
        \\function f(obj) { return 0; }
        \\
        \\/**
        \\ * @return {/*4*/T}
        \\ */
        \\function f2(obj) { return 0; }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestCompletionsImport_mergedReExport" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{ "compilerOptions": { "module": "commonjs", "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{ "dependencies": { "@jest/types": "*", "ts-jest": "*" } }
        \\// @Filename: /home/src/workspaces/project/node_modules/@jest/types/package.json
        \\{ "name": "@jest/types" }
        \\// @Filename: /home/src/workspaces/project/node_modules/@jest/types/index.d.ts
        \\import type * as Config from "./Config";
        \\export type { Config };
        \\// @Filename: /home/src/workspaces/project/node_modules/@jest/types/Config.d.ts
        \\export interface ConfigGlobals {
        \\    [K: string]: unknown;
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/ts-jest/index.d.ts
        \\export {};
        \\declare module "@jest/types" {
        \\    namespace Config {
        \\        interface ConfigGlobals {
        \\            'ts-jest': any;
        \\        }
        \\    }
        \\}
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\C/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "Config",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "@jest/types",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
    _ = f.Insert(undefined, "o");
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "Config",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "@jest/types",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
}

test "TestRenamePropertyAccessExpressionHeritageClause" {
    const content =
        \\class B {}
        \\function foo() {
        \\    return {[|[|{| "contextRangeIndex": 0 |}B|]: B|]};
        \\}
        \\class C extends (foo()).[|B|] {}
        \\class C1 extends foo().[|B|] {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "B");
}

test "TestOrganizeImportsType8" {
    const content =
        \\import { type A, type a, b, B } from "foo";
        \\console.log(a, b, A, B);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "import { type A, type a, b, B } from \"foo\";\nconsole.log(a, b, A, B);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSUnknown,
//             .OrganizeImportsTypeOrder =  lsutil.OrganizeImportsTypeOrderInline,
//         },
//     );
    _ = f.ReplaceLine(undefined, 0, "import { type A, type a, b, B } from \"foo1\";");
    // try f.VerifyOrganizeImports(undefined,
//         "import { type A, type a, b, B } from \"foo1\";\nconsole.log(a, b, A, B);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSUnknown,
//             .OrganizeImportsTypeOrder =  lsutil.OrganizeImportsTypeOrderFirst,
//         },
//     );
    _ = f.ReplaceLine(undefined, 0, "import { type A, type a, b, B } from \"foo2\";");
    // try f.VerifyOrganizeImports(undefined,
//         "import { b, B, type A, type a } from \"foo2\";\nconsole.log(a, b, A, B);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSUnknown,
//             .OrganizeImportsTypeOrder =  lsutil.OrganizeImportsTypeOrderLast,
//         },
//     );
    _ = f.ReplaceLine(undefined, 0, "import { type A, type a, b, B } from \"foo3\";");
    // try f.VerifyOrganizeImports(undefined,
//         "import { type A, type a, b, B } from \"foo3\";\nconsole.log(a, b, A, B);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSUnknown,
//         },
//     );
    _ = f.ReplaceLine(undefined, 0, "import { type A, type a, b, B } from \"foo4\";");
    // try f.VerifyOrganizeImports(undefined,
//         "import { type A, type a, b, B } from \"foo4\";\nconsole.log(a, b, A, B);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSTrue,
//         },
//     );
    _ = f.ReplaceLine(undefined, 0, "import { type A, type a, b, B } from \"foo5\";");
    // try f.VerifyOrganizeImports(undefined,
//         "import { type A, B, type a, b } from \"foo5\";\nconsole.log(a, b, A, B);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSFalse,
//         },
//     );
}

test "TestSingleLineTypeLiteralFormatting" {
    const content =
        \\function of1(b: { r: { c: number/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, ";");
    try f.VerifyCurrentLineContent(undefined, "function of1(b: { r: { c: number;");
}

test "TestCompletionListPrivateMembers2" {
    const content =
        \\class Foo {
        \\    private y;
        \\    constructor(private x) {}
        \\    method() { this./*1*/; }
        \\}
        \\var f:Foo;
        \\f./*2*/
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
//                 "method",
//                 "x",
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
//             .Exact = &.{
//                 "method",
//             },
//         },
//     });
}

test "TestFormattingOnInterfaces" {
    const content =
        \\/*1*/interface Blah 
        \\{
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "interface Blah {");
}

test "TestFindAllRefsGlobalModuleAugmentation" {
    const content =
        \\// @Filename: /a.ts
        \\export {};
        \\declare global {
        \\    /*1*/function /*2*/f(): void;
        \\}
        \\// @Filename: /b.ts
        \\/*3*/f();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestGoToImplementationClassMethod_00" {
    const content =
        \\class Bar {
        \\    [|{|"parts": ["(","method",")"," ","Bar",".","hello","(",")",":"," ","void"], "kind": "method"|}hello|]() {}
        \\}
        \\
        \\new Bar().hel/*reference*/lo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "reference");
}

test "TestQuickInfoDisplayPartsEnum2" {
    const content =
        \\enum /*1*/E {
        \\    /*2*/"e1",
        \\    /*3*/'e2' = 10,
        \\    /*4*/"e3"
        \\}
        \\var /*5*/eInstance: /*6*/E;
        \\/*7*/eInstance = /*8*/E./*9*/e1;
        \\/*10*/eInstance = /*11*/E./*12*/e2;
        \\/*13*/eInstance = /*14*/E./*15*/e3;
        \\const enum /*16*/constE {
        \\    /*17*/"e1",
        \\    /*18*/'e2' = 10,
        \\    /*19*/"e3"
        \\}
        \\var /*20*/eInstance1: /*21*/constE;
        \\/*22*/eInstance1 = /*23*/constE./*24*/e1;
        \\/*25*/eInstance1 = /*26*/constE./*27*/e2;
        \\/*28*/eInstance1 = /*29*/constE./*30*/e3;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestDocCommentTemplateClassDeclMethods01" {
    const content =
        \\class C {
        \\/*0*/    /*1*/
        \\    foo();
        \\    /*2*/foo(a);
        \\    /*3*/foo(a, b);
        \\    /*4*/foo(a, {x: string}, [c]);
        \\    /*5*/foo(a?, b?, ...args) {
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyJSDocCompletion(undefined, "0", 3, "/** */", null);
    // try f.VerifyJSDocCompletion(undefined, "1", 3, "/** */", null);
    // try f.VerifyJSDocCompletion(undefined, "2", 11, "/**\n     * \n     * @param a\n     */\n    ", null);
    // try f.VerifyJSDocCompletion(undefined, "3", 11, "/**\n     * \n     * @param a\n     * @param b\n     */\n    ", null);
    // try f.VerifyJSDocCompletion(undefined, "4", 11, "/**\n     * \n     * @param a\n     * @param param1\n     * @param param2\n     */\n    ", null);
    // try f.VerifyJSDocCompletion(undefined, "5", 11, "/**\n     * \n     * @param a\n     * @param b\n     * @param args\n     */\n    ", null);
}

test "TestCodeFixMissingTypeAnnotationOnExports24_heritage_formatting_2" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\function mixin<T extends new (...a: any) => any>(ctor: T): T {
        \\    return ctor;
        \\}
        \\class Point2D { x = 0; y = 0; }
        \\export class Point3D2 extends mixin(Point2D) {
        \\    z = 0;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFixAvailable(undefined, &.{"Extract base class to variable"});
    try f.VerifyCodeFix(undefined, .{
        .Description = "Extract base class to variable",
        .NewFileContent = "function mixin<T extends new (...a: any) => any>(ctor: T): T {\n    return ctor;\n}\nclass Point2D { x = 0; y = 0; }\nconst Point3D2Base: typeof Point2D = mixin(Point2D);\nexport class Point3D2 extends Point3D2Base {\n    z = 0;\n}",
        .Index = 0,
    });
}

test "TestImportNameCodeFix_importType7" {
    const content =
        \\// @module: es2015
        \\// @Filename: /exports.ts
        \\export interface SomeInterface {}
        \\export class SomePig {}
        \\// @Filename: /a.ts
        \\import {
        \\    type SomeInterface,
        \\    type SomePig,
        \\} from "./exports.js";
        \\new SomePig/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import {\n    SomePig,\n    type SomeInterface,\n} from \"./exports.js\";\nnew SomePig",
    }, null );
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import {\n    SomePig,\n    type SomeInterface,\n} from \"./exports.js\";\nnew SomePig",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderLast});
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import {\n    type SomeInterface,\n    SomePig,\n} from \"./exports.js\";\nnew SomePig",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderInline});
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import {\n    type SomeInterface,\n    SomePig,\n} from \"./exports.js\";\nnew SomePig",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderFirst});
}

test "TestImportNameCodeFix_jsxReact17" {
    const content =
        \\// @jsx: preserve
        \\// @module: commonjs
        \\// @Filename: /node_modules/@types/react/index.d.ts
        \\declare namespace React {
        \\  function createElement(): any;
        \\}
        \\export = React;
        \\export as namespace React;
        \\
        \\declare global {
        \\  namespace JSX {
        \\    interface IntrinsicElements {}
        \\    interface IntrinsicAttributes {}
        \\  }  
        \\}
        \\// @Filename: /component.tsx
        \\import "react";
        \\export declare function Component(): any;
        \\// @Filename: /index.tsx
        \\(<Component/**/ />);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { Component } from \"./component\";\n\n(<Component />);",
    }, null );
}

test "TestFindAllRefsInsideTemplates2" {
    const content =
        \\/*1*/function /*2*/f(...rest: any[]) { }
        \\/*3*/f 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5");
}

test "TestReferencesForMergedDeclarations4" {
    const content =
        \\/*1*/class /*2*/testClass {
        \\    static staticMethod() { }
        \\    method() { }
        \\}
        \\
        \\/*3*/module /*4*/testClass {
        \\    export interface Bar {
        \\
        \\    }
        \\    export var s = 0;
        \\}
        \\
        \\var c1: /*5*/testClass;
        \\var c2: /*6*/testClass.Bar;
        \\/*7*/testClass.staticMethod();
        \\/*8*/testClass.prototype.method();
        \\/*9*/testClass.bind(this);
        \\/*10*/testClass.s;
        \\new /*11*/testClass();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11");
}

test "TestJsdocTypedefTagRename04" {
    const content =
        \\// @lib: es5
        \\// @allowNonTsExtensions: true
        \\// @Filename: jsDocTypedef_form2.js
        \\
        \\function test1() {
        \\   /** @typedef {(string | number)} NumberLike */
        \\
        \\   /** @type {/*1*/NumberLike} */
        \\   var numberLike;
        \\}
        \\function test2() {
        \\   /** @typedef {(string | number)} NumberLike2 */
        \\
        \\   /** @type {NumberLike2} */
        \\   var n/*2*/umberLike2;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyQuickInfoExists(undefined);
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "111");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyQuickInfoExists(undefined);
}

test "TestRenameReExportDefault" {
    const content =
        \\// @Filename: /a.ts
        \\export { default } from "./b";
        \\[|export { default as [|{| "contextRangeIndex": 0 |}b|] } from "./b";|]
        \\export { default as bee } from "./b";
        \\[|import { default as [|{| "contextRangeIndex": 2 |}b|] } from "./b";|]
        \\import { default as bee } from "./b";
        \\[|import [|{| "contextRangeIndex": 4 |}b|] from "./b";|]
        \\// @Filename: /b.ts
        \\[|const [|{| "contextRangeIndex": 6 |}b|] = 0;|]
        \\[|export default [|{| "contextRangeIndex": 8 |}b|];|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[3], f.Ranges()[5], f.Ranges()[7], f.Ranges()[9]);
}

