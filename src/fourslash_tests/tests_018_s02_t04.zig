const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestFormattingJsxTexts4" {
    const content =
        \\//@Filename: file.tsx
        \\function foo() {
        \\const a = <ns: foobar   x : test1   x :test2="string"  x:test3={true?1:0}  />;
        \\
        \\return a;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "function foo() {\n    const a = <ns:foobar x:test1 x:test2=\"string\" x:test3={true ? 1 : 0} />;\n\n    return a;\n}");
}

test "TestRenameLabel3" {
    const content =
        \\/**/loop:
        \\for (let i = 0; i <= 10; i++) {
        \\   if (i === 0) continue loop;
        \\   if (i === 1) continue loop;
        \\   if (i === 10) break loop;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , "");
}

test "TestFunctionTypes" {
    const content =
        \\// @lib: es5
        \\// @strict: false
        \\var f: Function;
        \\function g() { }
        \\
        \\class C {
        \\    h: () => void ;
        \\    i(): number { return 5; }
        \\    static j = (e) => e;
        \\    static k() { return 'hi';}
        \\}
        \\var l = () => void 0;
        \\var z = new C;
        \\
        \\f./*1*/apply(this, [1]);
        \\g./*2*/arguments;
        \\z.h./*3*/bind(undefined, 1, 2);
        \\z.i./*4*/call(null)
        \\C.j./*5*/length === 1;
        \\typeof C.k./*6*/caller === 'function';
        \\l./*7*/prototype = Object.prototype;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyCompletions(undefined, &.{"1", "2", "3", "4", "5", "6"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionFunctionMembersWithPrototype,
//         },
//     });
    // f.VerifyCompletions(undefined, "7", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionFunctionMembersPlus(
//                 &.{
//                     "prototype",
//                 },
//             ),
//         },
//     });
}

test "TestSmartSelection_function1" {
    const content =
        \\const f1 = () => {
        \\   /**/
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSelectionRanges(undefined);
}

test "TestSemanticClassificationInTemplateExpressions" {
    const content =
        \\module /*0*/M {
        \\    export class /*1*/C {
        \\        static x;
        \\    }
        \\    export enum /*2*/E {
        \\        E1 = 0
        \\    }
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "namespace.declaration", .Text = "M"},
//         .{.Type = "class.declaration", .Text = "C"},
//         .{.Type = "property.declaration.static", .Text = "x"},
//         .{.Type = "enum.declaration", .Text = "E"},
//         .{.Type = "enumMember.declaration.readonly", .Text = "E1"},
//         .{.Type = "namespace", .Text = "M"},
//         .{.Type = "class", .Text = "C"},
//         .{.Type = "property.static", .Text = "x"},
//         .{.Type = "namespace", .Text = "M"},
//         .{.Type = "enum", .Text = "E"},
//         .{.Type = "enumMember.readonly", .Text = "E1"},
//     });
}

test "TestDefinition" {
    const content =
        \\// @Filename: b.ts
        \\import n = require([|'./a/*1*/'|]);
        \\var x = new n.Foo();
        \\// @Filename: a.ts
        \\ /*2*/export class Foo {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestAutoImportNodeNextJSRequire" {
    const content =
        \\// @module: node18
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @noEmit: true
        \\// @Filename: /matrix.js
        \\exports.variants = [];
        \\// @Filename: /main.js
        \\exports.dedupeLines = data => {
        \\  variants/**/
        \\}
        \\// @Filename: /totally-irrelevant-no-way-this-changes-things-right.js
        \\export default 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/main.js");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "const { variants } = require(\"./matrix\")\n\nexports.dedupeLines = data => {\n  variants\n}",
    }, null );
}

test "TestGetJavaScriptQuickInfo5" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\/** @param {{b:number}} [a] */
        \\function /**/f(a) { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "function f(a?: {\n    b: number;\n}): void", "");
}

test "TestGoToDefinitionYield2" {
    const content =
        \\function* outerGen() {
        \\    function* /*end*/gen() {
        \\        [|/*start*/yield|] 0;
        \\    }
        \\    return gen
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "start");
}

test "TestQuickinfoVerbosityTypeof" {
    const content =
        \\interface Apple {
        \\    color: string;
        \\    weight: number;
        \\}
        \\const a: Apple = { color: "red", weight: 150 };
        \\const b/*b*/: typeof a = { color: "green", weight: 120 };
        \\class Banana {
        \\    length: number;
        \\    constructor(length: number) {
        \\        this.length = length;
        \\    }
        \\}
        \\const c/*c*/: typeof Banana = Banana;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"b" = .{0, 1}, .@"c" = .{0, 1}});
}

