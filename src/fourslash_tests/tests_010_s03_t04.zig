const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestRenameRest" {
    const content =
        \\interface Gen {
        \\    x: number;
        \\    [|[|{| "contextRangeIndex": 0 |}parent|]: Gen;|]
        \\    millenial: string;
        \\}
        \\let t: Gen;
        \\var { x, ...rest } = t;
        \\rest.[|parent|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "parent");
}

test "TestCompletionListInExportClause01" {
    const content =
        \\// @Filename: m1.ts
        \\export var foo: number = 1;
        \\export function bar() { return 10; }
        \\export function baz() { return 10; }
        \\// @Filename: m2.ts
        \\export {/*1*/, /*2*/ from "./m1"
        \\export {/*3*/} from "./m1"
        \\export {foo,/*4*/ from "./m1"
        \\export {bar as /*5*/, /*6*/ from "./m1"
        \\export {foo, bar, baz as b,/*7*/} from "./m1"
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "2", "3"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "bar",
//                 "baz",
//                 "foo",
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
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
//             .Exact = &.{
//                 "bar",
//                 "baz",
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
    _ = f.VerifyCompletions(undefined, "5", null);
    // f.VerifyCompletions(undefined, "6", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "baz",
//                 "foo",
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
    _ = f.VerifyCompletions(undefined, "7", null);
}

test "TestCompletionsJSDocImportTagEmptyModuleSpecifier1" {
    const content =
        \\// @strict: true
        \\// @checkJs: true
        \\// @allowJs: true
        \\// @moduleResolution: nodenext
        \\// @filename: node_modules/pkg/index.d.ts
        \\export type MyUnion = string | number;
        \\// @filename: index.js
        \\/** @import { MyUnion } from "/**/" */
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
//                 "pkg",
//             },
//         },
//     });
}

test "TestRenameInheritedProperties5" {
    const content =
        \\interface C extends D {
        \\    propC: number;
        \\}
        \\interface D extends C {
        \\    [|[|{| "contextRangeIndex": 0 |}propD|]: string;|]
        \\}
        \\var d: D;
        \\d.[|propD|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "propD");
}

test "TestGetOccurrencesReturn3" {
    const content =
        \\function f(a: number) {
        \\    if (a > 0) {
        \\        return (function () {
        \\            return;
        \\            return;
        \\            return;
        \\
        \\            if (false) {
        \\                return true;
        \\            }
        \\        })() || true;
        \\    }
        \\
        \\    var unusued = [1, 2, 3, 4].map(x => { [|return|] 4 })
        \\
        \\    return;
        \\    return true;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestGoToDefinitionReturn4" {
    const content =
        \\[|/*start*/return|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "start");
}

test "TestFunctionIndentation" {
    const content =
        \\namespace M {
        \\export =
        \\C;
        \\class C {
        \\constructor(b
        \\) {
        \\}
        \\foo(a
        \\: string) {
        \\return a
        \\|| true;
        \\}
        \\get bar(
        \\) {
        \\return 1;
        \\}
        \\}
        \\function foo(a,
        \\b?) {
        \\new M.C(
        \\"hello");
        \\}
        \\{
        \\{
        \\}
        \\}
        \\foo(
        \\function() {
        \\"hello";
        \\});
        \\foo(
        \\() => {
        \\"hello";
        \\});
        \\var t,
        \\u = 1,
        \\v;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "namespace M {\n" ++ "    export =\n" ++ "        C;\n" ++ "    class C {\n" ++ "        constructor(b\n" ++ "        ) {\n" ++ "        }\n" ++ "        foo(a\n" ++ "            : string) {\n" ++ "            return a\n" ++ "                || true;\n" ++ "        }\n" ++ "        get bar(\n" ++ "        ) {\n" ++ "            return 1;\n" ++ "        }\n" ++ "    }\n" ++ "    function foo(a,\n" ++ "        b?) {\n" ++ "        new M.C(\n" ++ "            \"hello\");\n" ++ "    }\n" ++ "    {\n" ++ "        {\n" ++ "        }\n" ++ "    }\n" ++ "    foo(\n" ++ "        function() {\n" ++ "            \"hello\";\n" ++ "        });\n" ++ "    foo(\n" ++ "        () => {\n" ++ "            \"hello\";\n" ++ "        });\n" ++ "    var t,\n" ++ "        u = 1,\n" ++ "        v;\n" ++ "}");
}

test "TestAssertContextualType" {
    const content =
        \\<(aa: number) =>void >(function myFn(b/**/b) { });
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "(parameter) bb: number", "");
}

test "TestSignatureHelpOnOverloads" {
    const content =
        \\declare function fn(x: string);
        \\declare function fn(x: string, y: number);
        \\fn(/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifySignatureHelp(undefined, .{.Text = "fn(x: string): any", .ParameterName = "x", .ParameterSpan = "x: string", .OverloadsCount = 2});
    _ = f.Insert(undefined, "'',");
    // f.VerifySignatureHelp(undefined, .{.Text = "fn(x: string, y: number): any", .ParameterName = "y", .ParameterSpan = "y: number", .OverloadsCount = 2});
}

test "TestQuickInfoForConstTypeReference" {
    const content =
        \\"" as /**/const;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNotQuickInfoExists(undefined);
}

