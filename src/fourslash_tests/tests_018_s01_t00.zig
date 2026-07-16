const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestSyntacticClassificationsTemplates1" {
    const content =
        \\var v = 10e0;
        \\var x = {
        \\    p1: 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "variable.declaration", .Text = "v"},
//         .{.Type = "variable.declaration", .Text = "x"},
//         .{.Type = "property.declaration", .Text = "p1"},
//         .{.Type = "property.declaration", .Text = "p2"},
//     });
}

test "TestGetOccurrencesThis3" {
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
        \\        [|t/**/his|];
        \\        (function (_) {
        \\            this;
        \\        })([|this|]);
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
        \\    public static staticB = this.staticMethod1;
        \\
        \\    public static staticMethod1() {
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
        \\    private static staticMethod2() {
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

test "TestImportStatementCompletions_semicolons" {
    const content =
        \\// @Filename: /mod.ts
        \\export const foo = 0;
        \\// @Filename: /noSemicolons.ts
        \\import * as fs from "fs"
        \\[|import f/**/|]
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
//                     .Label =      "foo",
//                     .InsertText = undefined("import { foo$1 } from \"./mod\""),
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./mod",
//                         },
//                     },
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "foo",
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

test "TestRenameContextuallyTypedProperties2" {
    const content =
        \\interface I {
        \\    prop1: () => void;
        \\    [|[|{| "contextRangeIndex": 0 |}prop2|](): void;|]
        \\}
        \\
        \\var o1: I = {
        \\    prop1() { },
        \\    [|[|{| "contextRangeIndex": 2 |}prop2|]() { }|]
        \\};
        \\
        \\var o2: I = {
        \\    prop1: () => { },
        \\    [|[|{| "contextRangeIndex": 4 |}prop2|]: () => { }|]
        \\};
        \\
        \\var o3: I = {
        \\    get prop1() { return () => { }; },
        \\    [|get [|{| "contextRangeIndex": 6 |}prop2|]() { return () => { }; }|]
        \\};
        \\
        \\var o4: I = {
        \\    set prop1(v) { },
        \\    [|set [|{| "contextRangeIndex": 8 |}prop2|](v) { }|]
        \\};
        \\
        \\var o5: I = {
        \\    "prop1"() { },
        \\    [|"[|{| "contextRangeIndex": 10 |}prop2|]"() { }|]
        \\};
        \\
        \\var o6: I = {
        \\    "prop1": function () { },
        \\    [|"[|{| "contextRangeIndex": 12 |}prop2|]": function () { }|]
        \\};
        \\
        \\var o7: I = {
        \\    ["prop1"]: function () { },
        \\    [|["[|{| "contextRangeIndex": 14 |}prop2|]"]: function () { }|]
        \\};
        \\
        \\var o8: I = {
        \\    ["prop1"]() { },
        \\    [|["[|{| "contextRangeIndex": 16 |}prop2|]"]() { }|]
        \\};
        \\
        \\var o9: I = {
        \\    get ["prop1"]() { return () => { }; },
        \\    [|get ["[|{| "contextRangeIndex": 18 |}prop2|]"]() { return () => { }; }|]
        \\};
        \\
        \\var o10: I = {
        \\    set ["prop1"](v) { },
        \\    [|set ["[|{| "contextRangeIndex": 20 |}prop2|]"](v) { }|]
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "prop2");
}

test "TestCodeFixClassImplementInterface_quotePreferenceSingle" {
    const content =
        \\interface I {
        \\    a(): void;
        \\    b(x: 'x', y: 'a' | 'b'): 'b';
        \\
        \\    c: 'c';
        \\    d: { e: 'e'; };
        \\}
        \\class Foo implements I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFix(undefined, .{
//         .Description = "Implement interface 'I'",
//         .NewFileContent = "interface I {\n    a(): void;\n    b(x: 'x', y: 'a' | 'b'): 'b';\n\n    c: 'c';\n    d: { e: 'e'; };\n}\nclass Foo implements I {\n    a(): void {\n        throw new Error('Method not implemented.');\n    }\n    b(x: 'x', y: 'a' | 'b'): 'b' {\n        throw new Error('Method not implemented.');\n    }\n    c: 'c';\n    d: { e: 'e'; };\n}",
//         .Index =           0,
//         .UserPreferences = &.{.QuotePreference = lsutil.QuotePreference("single")},
//     });
}

test "TestCompletionsImport_duplicatePackages_scopedTypesAndNotTypes" {
    const content =
        \\// @lib: es5
        \\// @module: commonjs
        \\// @esModuleInterop: true
        \\// @Filename: /node_modules/@types/scope__react-dom/package.json
        \\{ "name": "react-dom", "version": "1.0.0", "types": "./index.d.ts" }
        \\// @Filename: /node_modules/@types/scope__react-dom/index.d.ts
        \\import * as React from "react";
        \\export function render(): void;
        \\// @Filename: /node_modules/@types/scope__react/package.json
        \\{ "name": "react", "version": "1.0.0", "types": "./index.d.ts" }
        \\// @Filename: /node_modules/@types/scope__react/index.d.ts
        \\import "./other";
        \\export declare function useState(): void;
        \\// @Filename: /node_modules/@types/scope__react/other.d.ts
        \\export declare function useRef(): void;
        \\// @Filename: /packages/a/node_modules/@scope/react/package.json
        \\{ "name": "react", "version": "1.0.1", "types": "./index.d.ts" }
        \\// @Filename: /packages/a/node_modules/@scope/react/index.d.ts
        \\export declare function useState(): void;
        \\// @Filename: /packages/a/index.ts
        \\import "react-dom";
        \\import "react";
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

test "TestGoToSource7_conditionallyMinified" {
    const content =
        \\// @lib: es5
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/react/package.json
        \\{ "name": "react", "version": "16.8.6", "main": "index.js" }
        \\// @Filename: /home/src/workspaces/project/node_modules/react/index.js
        \\'use strict';
        \\
        \\if (process.env.NODE_ENV === 'production') {
        \\  module.exports = require('./cjs/react.production.min.js');
        \\} else {
        \\  module.exports = require('./cjs/react.development.js');
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/react/cjs/react.production.min.js
        \\'use strict';exports./*production*/useState=function(a){};exports.version='16.8.6';
        \\// @Filename: /home/src/workspaces/project/node_modules/react/cjs/react.development.js
        \\'use strict';
        \\if (process.env.NODE_ENV !== 'production') {
        \\  (function() {
        \\    function useState(initialState) {}
        \\    exports./*development*/useState = useState;
        \\    exports.version = '16.8.6';
        \\  }());
        \\}
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { [|/*start*/useState|] } from 'react';
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineGoToSourceDefinition(undefined, "start");
}

test "TestQuickInfoJsDocTags6" {
    const content =
        \\// @noEmit: true
        \\// @allowJs: true
        \\// @Filename: quickInfoJsDocTags6.js
        \\class Foo {
        \\    /**
        \\     * comment
        \\     * @author Me <me@domain.tld>
        \\     * @see x (the parameter)
        \\     * @param {number} x - x comment
        \\     * @param {number} y - y comment
        \\     * @returns The result
        \\     */
        \\    method(x, y) {
        \\       return x + y;
        \\    }
        \\}
        \\
        \\class Bar extends Foo {
        \\    /** @inheritDoc */
        \\    /**/method(x, y) {
        \\        const res = super.method(x, y) + 100;
        \\        return res;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestDefinitionNameOnEnumMember" {
    const content =
        \\enum e {
        \\    firstMember,
        \\    secondMember,
        \\    thirdMember
        \\}
        \\var enumMember = e.[|/*1*/thirdMember|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, false, "1");
}

test "TestCodeFixInferFromFunctionThisUsageObjectPropertyParameter" {
    const content =
        \\// @noImplicitThis: true
        \\function returnThisMember([| |]suffix: string) {
        \\     return this.member + suffix;
        \\ }
        \\
        \\ interface Container {
        \\     member: string;
        \\     returnThisMember(suffix: string): string;
        \\ }
        \\
        \\ const container: Container = {
        \\     member: "sample",
        \\     returnThisMember: returnThisMember,
        \\ };
        \\
        \\ container.returnThisMember("");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "this: Container, ", false, 0, 0);
}

