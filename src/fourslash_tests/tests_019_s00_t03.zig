const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestPathCompletionsTypesVersionsLocal" {
    const content =
        \\// @Filename: /package.json
        \\{
        \\  "typesVersions": {
        \\    "*": {
        \\      "*": ["./src/*"]
        \\    }
        \\  }
        \\}
        \\// @Filename: /src/add.ts
        \\export function add(a: number, b: number) { return a + b; }
        \\// @Filename: /src/index.ts
        \\import { add } from ".//**/";
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
//                 "add",
//             },
//         },
//     });
}

test "TestFormatSelectionJsxWithBinaryExpression" {
    const content =
        \\//@Filename: file.tsx
        \\function TestWidget() {
        \\    const test = true;
        \\    return (
        \\        <div>
        \\            {test &&
        \\                <div>
        \\ /*1*/                <div>some text</div>/*2*/
        \\                    <div>some text</div>
        \\                    <div>some text</div>
        \\                </div>
        \\            }
        \\            <div>some text</div>
        \\        </div>
        \\    );
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatSelection(undefined, "1", "2");
    try f.VerifyCurrentFileContent(undefined, "function TestWidget() {\n    const test = true;\n    return (\n        <div>\n            {test &&\n                <div>\n                    <div>some text</div>\n                    <div>some text</div>\n                    <div>some text</div>\n                </div>\n            }\n            <div>some text</div>\n        </div>\n    );\n}");
}

test "TestNavigationBarWellKnownSymbolExpando" {
    const content =
        \\function f() {}
        \\f[Symbol.iterator] = function() {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCompletionListInNamespaceImportName01" {
    const content =
        \\// @Filename: m1.ts
        \\export var foo: number = 1;
        \\// @Filename: m2.ts
        \\import * as /**/ from "m1"
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "", null);
}

test "TestCompletionListInObjectBindingPattern04" {
    const content =
        \\interface I {
        \\    property1: number;
        \\    property2: string;
        \\}
        \\
        \\var foo: I;
        \\var { prope/**/ } = foo;
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
//                 "property1",
//                 "property2",
//             },
//         },
//     });
}

test "TestRenameCommentsAndStrings2" {
    const content =
        \\///<reference path="./Bar.ts" />
        \\[|function [|{| "contextRangeIndex": 0 |}Bar|]() {
        \\    // This is a reference to Bar in a comment.
        \\    "this is a reference to [|Bar|] in a string"
        \\}|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1]);
}

test "TestCompletionListAtIdentifierDefinitionLocations_classes" {
    const content =
        \\var aa = 1;
        \\class /*className1*/
        \\class a/*className2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, f.Markers(), null);
}

test "TestGoToTypeDefinition4" {
    const content =
        \\// @Filename: foo.ts
        \\export type /*def0*/T = string;
        \\export const /*def1*/T = "";
        \\// @Filename: bar.ts
        \\import { T } from "./foo";
        \\let x: [|/*reference*/T|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToTypeDefinition(undefined, "reference");
    // try f.VerifyBaselineGoToDefinition(undefined, true, "reference");
}

test "TestAmbientVariablesWithSameName" {
    const content =
        \\declare namespace M {
        \\    export var x: string;
        \\}
        \\declare var x: number;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToEOF(undefined);
    _ = f.InsertLine(undefined, "");
    try f.VerifyNoErrors(undefined);
}

test "TestQuickinfoVerbosityInterface1" {
    const content =
        \\{
        \\    interface Foo {
        \\        a: "a" | "c";
        \\    }
        \\    const f/*f1*/: Foo = { a: "a" };
        \\}
        \\{
        \\    interface Bar {
        \\        b: "b" | "d";
        \\    }
        \\    interface Foo extends Bar {
        \\        a: "a" | "c";
        \\    }
        \\    const f/*f2*/: Foo = { a: "a", b: "b" };
        \\}
        \\{
        \\    type BarParam = "b" | "d";
        \\    interface Bar {
        \\        bar(b: BarParam): string;
        \\    }
        \\    type FooType = "a" | "c";
        \\    interface FooParam {
        \\        param: FooType;
        \\    }
        \\    interface Foo extends Bar {
        \\        a: FooType;
        \\        foo: (a: FooParam) => number;
        \\    }
        \\    const f/*f3*/: Foo = { a: "a", bar: () => "b", foo: () => 1 };
        \\}
        \\{
        \\    interface Bar<B> {
        \\        bar(b: B): string;
        \\    }
        \\    interface FooParam {
        \\        param: "a" | "c";
        \\    }
        \\    interface Foo extends Bar<FooParam> {
        \\        a: "a" | "c";
        \\        foo: (a: FooParam) => number;
        \\    }
        \\    const f/*f4*/: Foo = { a: "a", bar: () => "b", foo: () => 1 };
        \\    const b/*b1*/: Bar<number> = { bar: () => "" };
        \\}
        \\{
        \\    interface Foo<A> {
        \\        a: A;
        \\    }
        \\    type Alias = Foo<string>;
        \\    const a/*a*/: Alias = { a: "a" };
        \\}
        \\{
        \\    interface Foo {
        \\        a: "a";
        \\    }
        \\    interface Foo {
        \\        b: "b";
        \\    }
        \\    const f/*f5*/: Foo = { a: "a", b: "b" };
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"f1" = .{0, 1}, .@"f2" = .{0, 1}, .@"f3" = .{0, 1, 2, 3}, .@"f4" = .{0, 1, 2}, .@"b1" = .{0, 1}, .@"a" = .{0, 1, 2}, .@"f5" = .{0, 1}});
}

