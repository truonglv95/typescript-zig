const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestDocumentHighlightVarianceModifiers" {
    const content =
        \\type TFoo<Value> = { value: Value };
        \\type TBar<[|in|] [|out|] Value> = TFoo<Value>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestQuickInfoForUMDModuleAlias" {
    const content =
        \\// @Filename: 0.d.ts
        \\export function doThing(): string;
        \\export function doTheOtherThing(): void;
        \\export as namespace /*0*/myLib;
        \\// @Filename: 1.ts
        \\/// <reference path="0.d.ts" />
        \\/*1*/myLib.doThing();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "0", "export namespace myLib", "");
    // f.VerifyQuickInfoAt(undefined, "1", "export namespace myLib", "");
}

test "TestCompletionListInTypeLiteralInTypeParameter17" {
    const content =
        \\class Foo<T extends { x: 'one' | 2 }> {}
        \\function foo<T extends { x: 'one' | 2 }>() {}
        \\
        \\type A = Foo<{ x: /*0*/ }>;
        \\new Foo<{ x: /*1*/ }>();
        \\foo<{ x: /*2*/ }>();
        \\foo<{ x: /*3*/ }>;
        \\Foo<{ x: /*4*/ }>;
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
//                 "\"one\"",
//                 "2",
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
//                 "\"one\"",
//                 "2",
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
//                 "\"one\"",
//                 "2",
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
//             .Includes = &.{
//                 "\"one\"",
//                 "2",
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
//                 "\"one\"",
//                 "2",
//             },
//         },
//     });
}

test "TestCompletionNoAutoInsertQuestionDotForTypeParameter" {
    const content =
        \\// @strict: true
        \\interface Address {
        \\    city: string = "";
        \\    "postal code": string = "";
        \\}
        \\function f<T extends Address>(x: T) {
        \\    x[|./**/|]
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
//                 &.{
//                     .Label =  "city",
//                     .Detail = undefined("(property) Address.city: string"),
//                 },
//                 &.{
//                     .Label =      "postal code",
//                     .InsertText = undefined("[\"postal code\"]"),
//                     .Detail =     undefined("(property) Address[\"postal code\"]: string"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "postal code",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestGoToDefinitionIndexSignature2" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\const o = {};
        \\o.[|/*use*/foo|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "use");
}

test "TestQuickInfoForAliasedGeneric" {
    const content =
        \\namespace M {
        \\    export namespace N {
        \\        export class C<T> { }
        \\        export class D { }
        \\    }
        \\}
        \\import d = M.N;
        \\var /*1*/aa: d.C<number>;
        \\var /*2*/bb: d.D;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var aa: d.C<number>", "");
    // f.VerifyQuickInfoAt(undefined, "2", "var bb: d.D", "");
}

test "TestGetJavaScriptSyntacticDiagnostics11" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\function F(): number { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestInvalidRestArgError" {
    const content =
        \\function b(.../*1*/)/*2*/ {}  
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyErrorExistsBetweenMarkers(undefined, "1", "2");
}

test "TestReferencesForClassParameter" {
    const content =
        \\var p = 2;
        \\
        \\class p { }
        \\
        \\class foo {
        \\    constructor (/*1*/public /*2*/p: any) {
        \\    }
        \\
        \\    public f(p) {
        \\        this./*3*/p = p;
        \\    }
        \\
        \\}
        \\
        \\var n = new foo(undefined);
        \\n./*4*/p = null;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestUnusedLabelAfterEdit" {
    const content =
        \\// @allowUnusedLabels: false
        \\myLabel: while (true) {
        \\    if (Math.random() > 0.5) {
        \\        /*marker*/break myLabel;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 0);
    // f.GoToMarker(undefined, "marker");
    _ = f.DeleteAtCaret(undefined, 14);
    _ = f.Insert(undefined, "break;");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
    // f.GoToMarker(undefined, "marker");
    _ = f.DeleteAtCaret(undefined, 6);
    _ = f.Insert(undefined, "break myLabel;");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 0);
}

