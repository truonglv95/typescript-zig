const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestImportCompletionsPackageJsonImports_js" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#thing": "./src/something.js"
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

test "TestCodeFixRequireInTs3" {
    const content =
        \\// @Filename: /a.ts
        \\const { a, b: { c } } = [|require("a")|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestTypeCheckAfterAddingGenericParameter" {
    const content =
        \\function f<x, x>() { }
        \\function f2<X, X>(b: X): X { return null; }
        \\class C<X> {
        \\    public f<x, x>() {}
        \\f2<X>(b): X { return null; }
        \\}
        \\
        \\interface I<X, X> {
        \\    f<X/*addTypeParam*/>();
        \\    f2<X>(/*addParam*/a: X): X;
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "addParam");
    _ = f.Insert(undefined, ", X");
    _ = f.GoToMarker(undefined, "addTypeParam");
    _ = f.Insert(undefined, ", X");
}

test "TestQuickInfoOnNarrowedTypeInModule" {
    const content =
        \\// @strict: false
        \\var strOrNum: string | number;
        \\namespace m {
        \\    var nonExportedStrOrNum: string | number;
        \\    export var exportedStrOrNum: string | number;
        \\    var num: number;
        \\    var str: string;
        \\    if (typeof /*1*/nonExportedStrOrNum === "number") {
        \\        num = /*2*/nonExportedStrOrNum;
        \\    }
        \\    else {
        \\        str = /*3*/nonExportedStrOrNum.length;
        \\    }
        \\    if (typeof /*4*/exportedStrOrNum === "number") {
        \\        strOrNum = /*5*/exportedStrOrNum;
        \\    }
        \\    else {
        \\        strOrNum = /*6*/exportedStrOrNum;
        \\    }
        \\}
        \\if (typeof m./*7*/exportedStrOrNum === "number") {
        \\    strOrNum = m./*8*/exportedStrOrNum;
        \\}
        \\else {
        \\    strOrNum = m./*9*/exportedStrOrNum;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "var nonExportedStrOrNum: string | number", "");
    try f.VerifyQuickInfoAt(undefined, "2", "var nonExportedStrOrNum: number", "");
    try f.VerifyQuickInfoAt(undefined, "3", "var nonExportedStrOrNum: string", "");
    try f.VerifyQuickInfoAt(undefined, "4", "var m.exportedStrOrNum: string | number", "");
    try f.VerifyQuickInfoAt(undefined, "5", "var m.exportedStrOrNum: number", "");
    try f.VerifyQuickInfoAt(undefined, "6", "var m.exportedStrOrNum: string", "");
    try f.VerifyQuickInfoAt(undefined, "7", "var m.exportedStrOrNum: string | number", "");
    try f.VerifyQuickInfoAt(undefined, "8", "var m.exportedStrOrNum: number", "");
    try f.VerifyQuickInfoAt(undefined, "9", "var m.exportedStrOrNum: string", "");
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "nonExportedStrOrNum",
//                     .Detail = undefined("var nonExportedStrOrNum: string | number"),
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
//             .Includes = &.{
//                 &.{
//                     .Label =  "nonExportedStrOrNum",
//                     .Detail = undefined("var nonExportedStrOrNum: number"),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "nonExportedStrOrNum",
//                     .Detail = undefined("var nonExportedStrOrNum: string"),
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
//                     .Label =  "exportedStrOrNum",
//                     .Detail = undefined("var exportedStrOrNum: string | number"),
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
//                     .Label =  "exportedStrOrNum",
//                     .Detail = undefined("var exportedStrOrNum: number"),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "6", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "exportedStrOrNum",
//                     .Detail = undefined("var exportedStrOrNum: string"),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "7", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "exportedStrOrNum",
//                     .Detail = undefined("var m.exportedStrOrNum: string | number"),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "8", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "exportedStrOrNum",
//                     .Detail = undefined("var m.exportedStrOrNum: number"),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "9", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "exportedStrOrNum",
//                     .Detail = undefined("var m.exportedStrOrNum: string"),
//                 },
//             },
//         },
//     });
}

test "TestCompletionForStringLiteralNonrelativeImportTypings1" {
    const content =
        \\// @typeRoots: my_typings,my_other_typings
        \\// @Filename: tests/test0.ts
        \\/// <reference types="m/*types_ref0*/" />
        \\import * as foo1 from "m/*import_as0*/
        \\import foo2 = require("m/*import_equals0*/
        \\var foo3 = require("m/*require0*/
        \\// @Filename: my_typings/module-x/index.d.ts
        \\export var x = 9;
        \\// @Filename: my_typings/module-x/whatever.d.ts
        \\export var w = 9;
        \\// @Filename: my_typings/module-y/index.d.ts
        \\export var y = 9;
        \\// @Filename: my_other_typings/module-z/index.d.ts
        \\export var z = 9;
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
//                 "module-x",
//                 "module-y",
//                 "module-z",
//             },
//         },
//     });
}

test "TestFormatMultilineComment" {
    const content =
        \\/*1*//** 1
        \\ */*2*/2
        \\/*3*/ 3*/
        \\
        \\class Foo {
        \\/*4*//**4
        \\    */*5*/5
        \\/*6*/                *6
        \\/*7*/          7*/
        \\    bar() {
        \\/*8*/                /**8
        \\    */*9*/9
        \\/*10*/                *10
        \\/*11*/                           *11
        \\/*12*/          12*/
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "/** 1");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, " *2");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, " 3*/");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "    /**4");
    _ = f.GoToMarker(undefined, "5");
    try f.VerifyCurrentLineContent(undefined, "        *5");
    _ = f.GoToMarker(undefined, "6");
    try f.VerifyCurrentLineContent(undefined, "                    *6");
    _ = f.GoToMarker(undefined, "7");
    try f.VerifyCurrentLineContent(undefined, "              7*/");
    _ = f.GoToMarker(undefined, "8");
    try f.VerifyCurrentLineContent(undefined, "        /**8");
    _ = f.GoToMarker(undefined, "9");
    try f.VerifyCurrentLineContent(undefined, "*9");
    _ = f.GoToMarker(undefined, "10");
    try f.VerifyCurrentLineContent(undefined, "        *10");
    _ = f.GoToMarker(undefined, "11");
    try f.VerifyCurrentLineContent(undefined, "                   *11");
    _ = f.GoToMarker(undefined, "12");
    try f.VerifyCurrentLineContent(undefined, "  12*/");
}

test "TestMemberListOnExplicitThis" {
    const content =
        \\interface Restricted {
        \\   n: number;
        \\}
        \\class C1 implements Restricted {
        \\   n: number;
        \\   m: number;
        \\   f(this: this) {this./*1*/} // test on 'this.'
        \\   g(this: Restricted) {this./*2*/}
        \\}
        \\function f(this: void) {this./*3*/}
        \\function g(this: Restricted) {this./*4*/}
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
//                     .Label =  "f",
//                     .Detail = undefined("(method) C1.f(this: this): void"),
//                 },
//                 &.{
//                     .Label =  "g",
//                     .Detail = undefined("(method) C1.g(this: Restricted): void"),
//                 },
//                 &.{
//                     .Label =  "m",
//                     .Detail = undefined("(property) C1.m: number"),
//                 },
//                 &.{
//                     .Label =  "n",
//                     .Detail = undefined("(property) C1.n: number"),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"2", "4"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "n",
//                     .Detail = undefined("(property) Restricted.n: number"),
//                 },
//             },
//         },
//     });
    _ = f.VerifyCompletions(undefined, "3", null);
}

test "TestCompletionsImport_filteredByPackageJson_direct" {
    const content =
        \\//@noEmit: true
        \\//@Filename: /package.json
        \\{
        \\  "dependencies": {
        \\    "react": "*"
        \\  }
        \\}
        \\//@Filename: /node_modules/react/index.d.ts
        \\export declare var React: any;
        \\//@Filename: /node_modules/react/package.json
        \\{
        \\  "name": "react",
        \\  "types": "./index.d.ts"
        \\}
        \\//@Filename: /node_modules/fake-react/index.d.ts
        \\export declare var ReactFake: any;
        \\//@Filename: /node_modules/fake-react/package.json
        \\{
        \\  "name": "fake-react",
        \\  "types": "./index.d.ts"
        \\}
        \\//@Filename: /src/index.ts
        \\const x = Re/**/
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
//                     .Label =               "React",
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "react",
//                         },
//                     },
//                     .SortText = undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//             .Excludes = &.{
//                 "ReactFake",
//             },
//         },
//     });
}

test "TestAsConstRefsNoErrors1" {
    const content =
        \\class Tex {
        \\    type = 'Text' as /**/const;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "");
    try f.VerifyNoErrors(undefined);
}

test "TestQuickInfoOnPrivateConstructorCall" {
    const content =
        \\class A {
        \\    private constructor() {}
        \\}
        \\var x = new A(/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyNoSignatureHelpForMarkers(undefined, "1");
}

