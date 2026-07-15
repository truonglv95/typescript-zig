const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestSpaceAfterReturn" {
    const content =
        \\function f( ) {
        \\return       1;/*1*/
        \\return[1];/*2*/
        \\return    ;/*3*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "    return 1;");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "    return [1];");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "    return;");
}

test "TestJsconfig" {
    const content =
        \\// @Filename: /a.js
        \\function f(/**/x) {
        \\}
        \\// @Filename: /jsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "checkJs": true,
        \\        "noImplicitAny": true
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.js");
    _ = f.VerifyErrorExistsAfterMarker(undefined, "");
}

test "TestTsxCompletion7" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        div: { ONE: string; TWO: number; }
        \\    }
        \\}
        \\let y = { ONE: '' };
        \\var x = <div {...y} /**/ />;
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
//                     .Label =    "TWO",
//                     .Kind =     undefined(lsproto.CompletionItemKindField),
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//                 &.{
//                     .Label =    "ONE",
//                     .Kind =     undefined(lsproto.CompletionItemKindField),
//                     .SortText = undefined(string(ls.SortTextMemberDeclaredBySpreadAssignment)),
//                 },
//             },
//         },
//     });
}

test "TestFormattingOnClosingBracket" {
    const content =
        \\function f( ) {/*1*/
        \\var     x = 3;/*2*/
        \\    var z = 2   ;/*3*/
        \\    a  = z  ++ - 2 *  x ;/*4*/
        \\        for ( ; ; ) {/*5*/
        \\    a+=(g +g)*a%t;/*6*/
        \\        b --                          ;/*7*/
        \\}/*8*/
        \\
        \\    switch ( a  )/*9*/
        \\    {
        \\        case 1  :     {/*10*/
        \\    a ++  ;/*11*/
        \\        b--;/*12*/
        \\    if(a===a)/*13*/
        \\                return;/*14*/
        \\    else/*15*/
        \\        {
        \\            for(a in b)/*16*/
        \\                if(a!=a)/*17*/
        \\    {
        \\    for(a in b)/*18*/
        \\            {
        \\a++;/*19*/
        \\        }/*20*/
        \\                }/*21*/
        \\    }/*22*/
        \\        }/*23*/
        \\    default:/*24*/
        \\        break;/*25*/
        \\    }/*26*/
        \\}/*27*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts874);
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "function f() {");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "    var x = 3;");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "    var z = 2;");
    _ = f.GoToMarker(undefined, "4");
    _ = f.VerifyCurrentLineContent(undefined, "    a = z++ - 2 * x;");
    _ = f.GoToMarker(undefined, "5");
    _ = f.VerifyCurrentLineContent(undefined, "    for (; ;) {");
    _ = f.GoToMarker(undefined, "6");
    _ = f.VerifyCurrentLineContent(undefined, "        a += (g + g) * a % t;");
    _ = f.GoToMarker(undefined, "7");
    _ = f.VerifyCurrentLineContent(undefined, "        b--;");
    _ = f.GoToMarker(undefined, "8");
    _ = f.VerifyCurrentLineContent(undefined, "    }");
    _ = f.GoToMarker(undefined, "9");
    _ = f.VerifyCurrentLineContent(undefined, "    switch (a) {");
    _ = f.GoToMarker(undefined, "10");
    _ = f.VerifyCurrentLineContent(undefined, "        case 1: {");
    _ = f.GoToMarker(undefined, "11");
    _ = f.VerifyCurrentLineContent(undefined, "            a++;");
    _ = f.GoToMarker(undefined, "12");
    _ = f.VerifyCurrentLineContent(undefined, "            b--;");
    _ = f.GoToMarker(undefined, "13");
    _ = f.VerifyCurrentLineContent(undefined, "            if (a === a)");
    _ = f.GoToMarker(undefined, "14");
    _ = f.VerifyCurrentLineContent(undefined, "                return;");
    _ = f.GoToMarker(undefined, "15");
    _ = f.VerifyCurrentLineContent(undefined, "            else {");
    _ = f.GoToMarker(undefined, "16");
    _ = f.VerifyCurrentLineContent(undefined, "                for (a in b)");
    _ = f.GoToMarker(undefined, "17");
    _ = f.VerifyCurrentLineContent(undefined, "                    if (a != a) {");
    _ = f.GoToMarker(undefined, "18");
    _ = f.VerifyCurrentLineContent(undefined, "                        for (a in b) {");
    _ = f.GoToMarker(undefined, "19");
    _ = f.VerifyCurrentLineContent(undefined, "                            a++;");
    _ = f.GoToMarker(undefined, "20");
    _ = f.VerifyCurrentLineContent(undefined, "                        }");
    _ = f.GoToMarker(undefined, "21");
    _ = f.VerifyCurrentLineContent(undefined, "                    }");
    _ = f.GoToMarker(undefined, "22");
    _ = f.VerifyCurrentLineContent(undefined, "            }");
    _ = f.GoToMarker(undefined, "23");
    _ = f.VerifyCurrentLineContent(undefined, "        }");
    _ = f.GoToMarker(undefined, "24");
    _ = f.VerifyCurrentLineContent(undefined, "        default:");
    _ = f.GoToMarker(undefined, "25");
    _ = f.VerifyCurrentLineContent(undefined, "            break;");
    _ = f.GoToMarker(undefined, "26");
    _ = f.VerifyCurrentLineContent(undefined, "    }");
    _ = f.GoToMarker(undefined, "27");
    _ = f.VerifyCurrentLineContent(undefined, "}");
}

test "TestGoToImplementationNamespace_02" {
    const content =
        \\namespace Foo {
        \\    export function [|hello|]() {}
        \\}
        \\
        \\Foo.hell/*reference*/o();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "reference");
}

test "TestNavigationItemsExportDefaultExpression2" {
    const content =
        \\export const foo = {
        \\  foo: {},
        \\};
        \\
        \\export default {
        \\  foo: {},
        \\};
        \\
        \\export default {
        \\  foo: {},
        \\};
        \\
        \\type Type = typeof foo;
        \\
        \\export default {
        \\  foo: {},
        \\} as Type;
        \\
        \\export default {
        \\  foo: {},
        \\} satisfies Type;
        \\
        \\export default (class {
        \\  prop = 42;
        \\});
        \\
        \\export default (class Cls {
        \\  prop = 42;
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestTypeReferenceOnServer" {
    const content =
        \\// @lib: es5
        \\/// <reference types="foo" />
        \\var x: number;
        \\x./*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "toFixed",
//             },
//         },
//     });
}

test "TestSignatureHelpTaggedTemplatesNegatives2" {
    const content =
        \\function foo(strs, ...rest) {
        \\}
        \\
        \\/*1*/fo/*2*/o /*3*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyNoSignatureHelpForMarkers(undefined, f.MarkerNames());
}

test "TestCompletionInfoWithExplicitTypeArguments" {
    const content =
        \\interface I { x: number; y: number; }
        \\
        \\declare function f<T>(x: T, y: number): void;
        \\f<I>({ /*f*/ });
        \\
        \\declare function g<T>(x: keyof T, y: number): void;
        \\g<I>("[|/*g*/|]");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "f", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "x",
//                 },
//                 &.{
//                     .Label = "y",
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "g", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "x",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "x",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "y",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "y",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestFindAllRefsForDefaultExport04" {
    const content =
        \\// @Filename: /a.ts
        \\const /*0*/a = 0;
        \\export /*1*/default /*2*/a;
        \\// @Filename: /b.ts
        \\import /*3*/a from "./a";
        \\/*4*/a;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "0", "2", "1", "3", "4");
}

