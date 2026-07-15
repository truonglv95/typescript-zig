const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionListAfterRegularExpressionLiteral1" {
    const content =
        \\// @lib: es5
        \\/a/./**/
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
//             .Unsorted = &.{
//                 "exec",
//                 "test",
//                 "source",
//                 "global",
//                 "ignoreCase",
//                 "multiline",
//                 "lastIndex",
//                 &.{
//                     .Label =    "compile",
//                     .SortText = undefined(string(ls.DeprecateSortText(ls.SortTextLocationPriority))),
//                     .Tags =     &&.{lsproto.CompletionItemTagDeprecated},
//                 },
//             },
//         },
//     });
}

test "TestQuickInfoLinkCodePlain" {
    const content =
        \\export class C {
        \\     /**
        \\      * @deprecated Use {@linkplain PerspectiveCamera#setFocalLength .setFocalLength()} and {@linkcode PerspectiveCamera#filmGauge .filmGauge} instead.
        \\      */
        \\    m() { }
        \\}
        \\new C().m/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCompletionsMergedDeclarations1" {
    const content =
        \\// @lib: es5
        \\interface Point {
        \\    x: number;
        \\    y: number;
        \\}
        \\function point(x: number, y: number): Point {
        \\    return { x: x, y: y };
        \\}
        \\namespace point {
        \\    export var origin = point(0, 0);
        \\    export function equals(p1: Point, p2: Point) {
        \\        return p1.x == p2.x && p1.y == p2.y;
        \\    }
        \\}
        \\var p1 = /*1*/point(0, 0);
        \\var p2 = point./*2*/origin;
        \\var b = point./*3*/equals(p1, p2);
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
//                 "point",
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
//             .Exact = CompletionFunctionMembersWithPrototypePlus(
//                 &.{
//                     "equals",
//                     "origin",
//                 },
//             ),
//         },
//     });
}

test "TestCompletionListInClassExpressionWithTypeParameter" {
    const content =
        \\var x = class myClass <TypeParam> {
        \\   getClassName (){
        \\       /*0*/
        \\       var tmp: /*0Type*/;
        \\   }
        \\   prop: Ty/*1*/
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
//             .Excludes = &.{
//                 "TypeParam",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"0Type", "1"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "TypeParam",
//                     .Detail = undefined("(type parameter) TypeParam in myClass<TypeParam>"),
//                     .Kind =   undefined(lsproto.CompletionItemKindProperty),
//                 },
//             },
//         },
//     });
}

test "TestImportNameCodeFix_typeOnly" {
    const content =
        \\// @module: esnext
        \\// @verbatimModuleSyntax: true
        \\// @Filename: types.ts
        \\export class A {}
        \\// @Filename: index.ts
        \\const a: /**/A
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import type { A } from \"./types\";\n\nconst a: A",
    }, null );
}

test "TestGoToDefinitionOverriddenMember10" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @noEmit: true
        \\// @noImplicitOverride: true
        \\// @filename: a.js
        \\class Foo {}
        \\class Bar extends Foo {
        \\    /** [|@override{|"name": "1"|} |]*/
        \\    m() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestGetOccurrencesIsDefinitionOfExport" {
    const content =
        \\// @Filename: m.ts
        \\export var /*1*/x = 12;
        \\// @Filename: main.ts
        \\import { /*2*/x } from "./m";
        \\const y = x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestOrganizeImports20" {
    const content =
        \\const a = 1;
        \\const b = 1;
        \\export { a };
        \\export { b };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(undefined,
//         "const a = 1;\nconst b = 1;\nexport { a, b };\n",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestFindAllReferencesFilteringMappedTypeProperty" {
    const content =
        \\const obj = { /*1*/a: 1, b: 2 };
        \\const filtered: { [P in keyof typeof obj as P extends 'b' ? never : P]: 0; } = { /*2*/a: 0 };
        \\filtered./*3*/a;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestFindAllRefsReExportStarAs" {
    const content =
        \\// @Filename: /leafModule.ts
        \\export const /*helloDef*/hello = () => 'Hello';
        \\// @Filename: /exporting.ts
        \\export * as /*leafDef*/Leaf from './leafModule';
        \\// @Filename: /importing.ts
        \\ import { /*leafImportDef*/Leaf } from './exporting';
        \\ /*leafUse*/[|Leaf|]./*helloUse*/[|hello|]()
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyBaselineFindAllReferences(undefined, "helloDef", "helloUse", "leafDef", "leafImportDef", "leafUse");
}

