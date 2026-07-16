const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestFindAllRefsImportType" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\module.exports = 0;
        \\/*1*/export type /*2*/N = number;
        \\// @Filename: /b.js
        \\type T = import("./a")./*3*/N;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestCodeFixClassImplementInterfaceIndexSignaturesNumber" {
    const content =
        \\interface I {
        \\    [x: number]: I;
        \\}
        \\class C implements I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "interface I {\n    [x: number]: I;\n}\nclass C implements I {\n    [x: number]: I;\n}",
        .Index = 0,
    });
}

test "TestCodeFixMissingTypeAnnotationOnExports37_array_spread" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @Filename: /code.ts
        \\const Start = [
        \\  'A',
        \\  'B',
        \\] as const;
        \\
        \\const End = [
        \\  "Y",
        \\  "Z"
        \\] as const;
        \\export const All_Part1 = {};
        \\function getPart() {
        \\  return ["Z"]
        \\}
        \\
        \\export const All = [
        \\  1,
        \\  ...Start,
        \\  1,
        \\  ...getPart(),
        \\  ...End,
        \\  1,
        \\] as const;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add annotation of type '[...typeof All_Part1_1, ...typeof Start, ...typeof All_Part3, ...typeof All_Part4, ...typeof End, ...typeof All_Part6]'",
        .NewFileContent = "const Start = [\n  'A',\n  'B',\n] as const;\n\nconst End = [\n  \"Y\",\n  \"Z\"\n] as const;\nexport const All_Part1 = {};\nfunction getPart() {\n  return [\"Z\"]\n}\n\nconst All_Part1_1 = [\n    1\n] as const;\nconst All_Part3 = [\n    1\n] as const;\nconst All_Part4 = getPart() as const;\nconst All_Part6 = [\n    1\n] as const;\nexport const All: [\n    ...typeof All_Part1_1,\n    ...typeof Start,\n    ...typeof All_Part3,\n    ...typeof All_Part4,\n    ...typeof End,\n    ...typeof All_Part6\n] = [\n    ...All_Part1_1,\n    ...Start,\n    ...All_Part3,\n    ...All_Part4,\n    ...End,\n    ...All_Part6\n] as const;",
        .Index = 1,
    });
}

test "TestSignatureHelpJSX" {
    const content =
        \\//@Filename: test.tsx
        \\//@jsx: react
        \\declare var React: any;
        \\const z = <div>{[].map(x => </**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifyNoSignatureHelpWithContext(undefined, &.{.TriggerKind = lsproto.SignatureHelpTriggerKindTriggerCharacter, .TriggerCharacter = undefined("<"), .IsRetrigger = false});
}

test "TestQuickInfoOnThis" {
    const content =
        \\interface Restricted {
        \\    n: number;
        \\}
        \\function wrapper(wrapped: { (): void; }) { }
        \\class Foo {
        \\    n: number;
        \\    prop1: th/*0*/is;
        \\    public explicitThis(this: this) {
        \\        wrapper(
        \\            function explicitVoid(this: void) {
        \\                console.log(th/*1*/is);
        \\            }
        \\        )
        \\        console.log(th/*2*/is);
        \\    }
        \\    public explicitInterface(th/*3*/is: Restricted) {
        \\        console.log(th/*4*/is);
        \\    }
        \\    public explicitClass(th/*5*/is: Foo) {
        \\        console.log(th/*6*/is);
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "0", "this", "");
    try f.VerifyQuickInfoAt(undefined, "1", "this: void", "");
    try f.VerifyQuickInfoAt(undefined, "2", "this: this", "");
    try f.VerifyQuickInfoAt(undefined, "3", "(parameter) this: Restricted", "");
    try f.VerifyQuickInfoAt(undefined, "4", "this: Restricted", "");
    try f.VerifyQuickInfoAt(undefined, "5", "(parameter) this: Foo", "");
    try f.VerifyQuickInfoAt(undefined, "6", "this: Foo", "");
}

test "TestConstQuickInfoAndCompletionList" {
    const content =
        \\const /*1*/a = 10;
        \\var x = /*2*/a;
        \\/*3*/
        \\function foo() {
        \\    const /*4*/b = 20;
        \\    var y = /*5*/b;
        \\    var z = /*6*/a;
        \\    /*7*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "a",
//                     .Detail = undefined("const a: 10"),
//                 },
//             },
//             .Excludes = &.{
//                 "b",
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
//                 &.{
//                     .Label =  "a",
//                     .Detail = undefined("const a: 10"),
//                 },
//             },
//             .Excludes = &.{
//                 "b",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"5", "6"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "a",
//                     .Detail = undefined("const a: 10"),
//                 },
//                 &.{
//                     .Label =  "b",
//                     .Detail = undefined("const b: 20"),
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
//                     .Label =  "a",
//                     .Detail = undefined("const a: 10"),
//                 },
//                 &.{
//                     .Label =  "b",
//                     .Detail = undefined("const b: 20"),
//                 },
//             },
//         },
//     });
    try f.VerifyQuickInfoAt(undefined, "1", "const a: 10", "");
    try f.VerifyQuickInfoAt(undefined, "2", "const a: 10", "");
    try f.VerifyQuickInfoAt(undefined, "4", "const b: 20", "");
    try f.VerifyQuickInfoAt(undefined, "5", "const b: 20", "");
    try f.VerifyQuickInfoAt(undefined, "6", "const a: 10", "");
}

test "TestCommentsInterfaceFourslash" {
    const content =
        \\// @lib: es5
        \\/** this is interface 1*/
        \\interface i/*1*/1 {
        \\}
        \\var i1/*2*/_i: i1;
        \\interface nc_/*3*/i1 {
        \\}
        \\var nc_/*4*/i1_i: nc_i1;
        \\/** this is interface 2 with members*/
        \\interface i/*5*/2 {
        \\    /** this is x*/
        \\    x: number;
        \\    /** this is foo*/
        \\    foo: (/**param help*/b: number) => string;
        \\    /** this is indexer*/
        \\    [/**string param*/i: string]: number;
        \\    /**new method*/
        \\    new (/** param*/i: i1);
        \\    nc_x: number;
        \\    nc_foo: (b: number) => string;
        \\    [i: number]: number;
        \\    /** this is call signature*/
        \\    (/**paramhelp a*/a: number,/**paramhelp b*/ b: number) : number;
        \\    /** this is fnfoo*/
        \\    fnfoo(/**param help*/b: number): string;
        \\    nc_fnfoo(b: number): string;
        \\}
        \\var i2/*6*/_i: /*34i*/i2;
        \\var i2_i/*7*/_x = i2_i./*8*/x;
        \\var i2_i/*9*/_foo = i2_i.f/*10*/oo;
        \\var i2_i_f/*11*/oo_r = i2_i.f/*12q*/oo(/*12*/30);
        \\var i2_i_i2_/*13*/si = i2/*13q*/_i["hello"];
        \\var i2_i_i2/*14*/_ii = i2/*14q*/_i[30];
        \\var i2_/*15*/i_n = new i2/*16q*/_i(/*16*/i1_i);
        \\var i2_i/*17*/_nc_x = i2_i.n/*18*/c_x;
        \\var i2_i_/*19*/nc_foo = i2_i.n/*20*/c_foo;
        \\var i2_i_nc_f/*21*/oo_r = i2_i.nc/*22q*/_foo(/*22*/30);
        \\var i2/*23*/_i_r = i2/*24q*/_i(/*24*/10, /*25*/20);
        \\var i2_i/*26*/_fnfoo = i2_i.fn/*27*/foo;
        \\var i2_i_/*28*/fnfoo_r = i2_i.fn/*29q*/foo(/*29*/10);
        \\var i2_i/*30*/_nc_fnfoo = i2_i.nc_fn/*31*/foo;
        \\var i2_i_nc_/*32*/fnfoo_r = i2_i.nc/*33q*/_fnfoo(/*33*/10);
        \\/*34*/
        \\interface i3 {
        \\    /** Comment i3 x*/
        \\    x: number;
        \\    /** Function i3 f*/
        \\    f(/**number parameter*/a: number): string;
        \\    /** i3 l*/
        \\    l: (/**comment i3 l b*/b: number) => string;
        \\    nc_x: number;
        \\    nc_f(a: number): string;
        \\    nc_l: (b: number) => string;
        \\}
        \\var i3_i: i3;
        \\i3_i = {
        \\    /*35*/f: /**own f*/ (/**i3_i a*/a: number) => "Hello" + /*36*/a,
        \\    l: this./*37*/f,
        \\    /** own x*/
        \\    x: this.f(/*38*/10),
        \\    nc_x: this.l(/*39*/this.x),
        \\    nc_f: this.f,
        \\    nc_l: this.l
        \\};
        \\/*40*/i/*40q*/3_i./*41*/f(/*42*/10);
        \\i3_i./*43q*/l(/*43*/10);
        \\i3_i.nc_/*44q*/f(/*44*/10);
        \\i3_i.nc/*45q*/_l(/*45*/10);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "interface i1", "this is interface 1");
    try f.VerifyQuickInfoAt(undefined, "2", "var i1_i: i1", "");
    try f.VerifyQuickInfoAt(undefined, "3", "interface nc_i1", "");
    try f.VerifyQuickInfoAt(undefined, "4", "var nc_i1_i: nc_i1", "");
    try f.VerifyQuickInfoAt(undefined, "5", "interface i2", "this is interface 2 with members");
    try f.VerifyQuickInfoAt(undefined, "6", "var i2_i: i2", "");
    try f.VerifyQuickInfoAt(undefined, "7", "var i2_i_x: number", "");
    try f.VerifyQuickInfoAt(undefined, "8", "(property) i2.x: number", "this is x");
    // f.VerifyCompletions(undefined, "8", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionFunctionMembersWithPrototypePlus(
//                 &.{
//                     &.{
//                         .Label =  "x",
//                         .Detail = undefined("(property) i2.x: number"),
//                         .Documentation = &.{
//                             .MarkupContent = &.{
//                                 .Kind =  lsproto.MarkupKindMarkdown,
//                                 .Value = "this is x",
//                             },
//                         },
//                     },
//                     &.{
//                         .Label =  "foo",
//                         .Detail = undefined("(property) i2.foo: (b: number) => string"),
//                         .Documentation = &.{
//                             .MarkupContent = &.{
//                                 .Kind =  lsproto.MarkupKindMarkdown,
//                                 .Value = "this is foo",
//                             },
//                         },
//                     },
//                     &.{
//                         .Label =  "nc_x",
//                         .Detail = undefined("(property) i2.nc_x: number"),
//                     },
//                     &.{
//                         .Label =  "nc_foo",
//                         .Detail = undefined("(property) i2.nc_foo: (b: number) => string"),
//                     },
//                     &.{
//                         .Label =  "fnfoo",
//                         .Detail = undefined("(method) i2.fnfoo(b: number): string"),
//                         .Documentation = &.{
//                             .MarkupContent = &.{
//                                 .Kind =  lsproto.MarkupKindMarkdown,
//                                 .Value = "this is fnfoo",
//                             },
//                         },
//                     },
//                     &.{
//                         .Label =  "nc_fnfoo",
//                         .Detail = undefined("(method) i2.nc_fnfoo(b: number): string"),
//                     },
//                 },
//             ),
//         },
//     });
    try f.VerifyQuickInfoAt(undefined, "9", "var i2_i_foo: (b: number) => string", "");
    try f.VerifyQuickInfoAt(undefined, "10", "(property) i2.foo: (b: number) => string", "this is foo");
    try f.VerifyQuickInfoAt(undefined, "11", "var i2_i_foo_r: string", "");
    _ = f.GoToMarker(undefined, "12");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "", .ParameterDocComment = "param help"});
    try f.VerifyQuickInfoAt(undefined, "12q", "(property) i2.foo: (b: number) => string", "this is foo");
    try f.VerifyQuickInfoAt(undefined, "13", "var i2_i_i2_si: number", "");
    try f.VerifyQuickInfoAt(undefined, "13q", "var i2_i: i2", "");
    try f.VerifyQuickInfoAt(undefined, "14", "var i2_i_i2_ii: number", "");
    try f.VerifyQuickInfoAt(undefined, "14q", "var i2_i: i2", "");
    try f.VerifyQuickInfoAt(undefined, "15", "var i2_i_n: any", "");
    _ = f.GoToMarker(undefined, "16");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "new method", .ParameterDocComment = "param"});
    try f.VerifyQuickInfoAt(undefined, "16q", "var i2_i: i2\nnew (i: i1) => any", "new method");
    try f.VerifyQuickInfoAt(undefined, "17", "var i2_i_nc_x: number", "");
    try f.VerifyQuickInfoAt(undefined, "18", "(property) i2.nc_x: number", "");
    try f.VerifyQuickInfoAt(undefined, "19", "var i2_i_nc_foo: (b: number) => string", "");
    try f.VerifyQuickInfoAt(undefined, "20", "(property) i2.nc_foo: (b: number) => string", "");
    try f.VerifyQuickInfoAt(undefined, "21", "var i2_i_nc_foo_r: string", "");
    _ = f.GoToMarker(undefined, "22");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    try f.VerifyQuickInfoAt(undefined, "22q", "(property) i2.nc_foo: (b: number) => string", "");
    try f.VerifyQuickInfoAt(undefined, "23", "var i2_i_r: number", "");
    _ = f.GoToMarker(undefined, "24");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "this is call signature", .ParameterDocComment = "paramhelp a"});
    try f.VerifyQuickInfoAt(undefined, "24q", "var i2_i: i2\n(a: number, b: number) => number", "this is call signature");
    _ = f.GoToMarker(undefined, "25");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "this is call signature", .ParameterDocComment = "paramhelp b"});
    try f.VerifyQuickInfoAt(undefined, "26", "var i2_i_fnfoo: (b: number) => string", "");
    try f.VerifyQuickInfoAt(undefined, "27", "(method) i2.fnfoo(b: number): string", "this is fnfoo");
    try f.VerifyQuickInfoAt(undefined, "28", "var i2_i_fnfoo_r: string", "");
    _ = f.GoToMarker(undefined, "29");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "this is fnfoo", .ParameterDocComment = "param help"});
    try f.VerifyQuickInfoAt(undefined, "29q", "(method) i2.fnfoo(b: number): string", "this is fnfoo");
    try f.VerifyQuickInfoAt(undefined, "30", "var i2_i_nc_fnfoo: (b: number) => string", "");
    try f.VerifyQuickInfoAt(undefined, "31", "(method) i2.nc_fnfoo(b: number): string", "");
    try f.VerifyQuickInfoAt(undefined, "32", "var i2_i_nc_fnfoo_r: string", "");
    _ = f.GoToMarker(undefined, "33");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    try f.VerifyQuickInfoAt(undefined, "33q", "(method) i2.nc_fnfoo(b: number): string", "");
    // f.VerifyCompletions(undefined, "34", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "i1_i",
//                     .Detail = undefined("var i1_i: i1"),
//                 },
//                 &.{
//                     .Label =  "nc_i1_i",
//                     .Detail = undefined("var nc_i1_i: nc_i1"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i2_i",
//                     .Detail = undefined("var i2_i: i2"),
//                 },
//                 &.{
//                     .Label =  "i2_i_x",
//                     .Detail = undefined("var i2_i_x: number"),
//                 },
//                 &.{
//                     .Label =  "i2_i_foo",
//                     .Detail = undefined("var i2_i_foo: (b: number) => string"),
//                 },
//                 &.{
//                     .Label =  "i2_i_foo_r",
//                     .Detail = undefined("var i2_i_foo_r: string"),
//                 },
//                 &.{
//                     .Label =  "i2_i_i2_si",
//                     .Detail = undefined("var i2_i_i2_si: number"),
//                 },
//                 &.{
//                     .Label =  "i2_i_i2_ii",
//                     .Detail = undefined("var i2_i_i2_ii: number"),
//                 },
//                 &.{
//                     .Label =  "i2_i_n",
//                     .Detail = undefined("var i2_i_n: any"),
//                 },
//                 &.{
//                     .Label =  "i2_i_nc_x",
//                     .Detail = undefined("var i2_i_nc_x: number"),
//                 },
//                 &.{
//                     .Label =  "i2_i_nc_foo",
//                     .Detail = undefined("var i2_i_nc_foo: (b: number) => string"),
//                 },
//                 &.{
//                     .Label =  "i2_i_nc_foo_r",
//                     .Detail = undefined("var i2_i_nc_foo_r: string"),
//                 },
//                 &.{
//                     .Label =  "i2_i_r",
//                     .Detail = undefined("var i2_i_r: number"),
//                 },
//                 &.{
//                     .Label =  "i2_i_fnfoo",
//                     .Detail = undefined("var i2_i_fnfoo: (b: number) => string"),
//                 },
//                 &.{
//                     .Label =  "i2_i_fnfoo_r",
//                     .Detail = undefined("var i2_i_fnfoo_r: string"),
//                 },
//                 &.{
//                     .Label =  "i2_i_nc_fnfoo",
//                     .Detail = undefined("var i2_i_nc_fnfoo: (b: number) => string"),
//                 },
//                 &.{
//                     .Label =  "i2_i_nc_fnfoo_r",
//                     .Detail = undefined("var i2_i_nc_fnfoo_r: string"),
//                 },
//             },
//             .Excludes = &.{
//                 "i1",
//                 "nc_i1",
//                 "i2",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "34i", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "i1",
//                     .Detail = undefined("interface i1"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "this is interface 1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "nc_i1",
//                     .Detail = undefined("interface nc_i1"),
//                 },
//                 &.{
//                     .Label =  "i2",
//                     .Detail = undefined("interface i2"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "this is interface 2 with members",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "36", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "a",
//                     .Detail = undefined("(parameter) a: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i3_i a",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    try f.VerifyQuickInfoAt(undefined, "40q", "var i3_i: i3", "");
    // f.VerifyCompletions(undefined, "40", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "i3_i",
//                     .Detail = undefined("var i3_i: i3"),
//                 },
//             },
//             .Excludes = &.{
//                 "i3",
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "41");
    try f.VerifyQuickInfoIs(undefined, "(method) i3.f(a: number): string", "Function i3 f");
    // f.VerifyCompletions(undefined, "41", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "f",
//                     .Detail = undefined("(method) i3.f(a: number): string"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "Function i3 f",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "l",
//                     .Detail = undefined("(property) i3.l: (b: number) => string"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i3 l",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "nc_f",
//                     .Detail = undefined("(method) i3.nc_f(a: number): string"),
//                 },
//                 &.{
//                     .Label =  "nc_l",
//                     .Detail = undefined("(property) i3.nc_l: (b: number) => string"),
//                 },
//                 &.{
//                     .Label =  "nc_x",
//                     .Detail = undefined("(property) i3.nc_x: number"),
//                 },
//                 &.{
//                     .Label =  "x",
//                     .Detail = undefined("(property) i3.x: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "Comment i3 x",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "42");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "Function i3 f", .ParameterDocComment = "number parameter"});
    _ = f.GoToMarker(undefined, "43");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "", .ParameterDocComment = "comment i3 l b"});
    try f.VerifyQuickInfoAt(undefined, "43q", "(property) i3.l: (b: number) => string", "i3 l");
    _ = f.GoToMarker(undefined, "44");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    try f.VerifyQuickInfoAt(undefined, "44q", "(method) i3.nc_f(a: number): string", "");
    _ = f.GoToMarker(undefined, "45");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    try f.VerifyQuickInfoAt(undefined, "45q", "(property) i3.nc_l: (b: number) => string", "");
}

test "TestFixExactOptionalUnassignableProperties9" {
    const content =
        \\// @strictNullChecks: true
        \\// @exactOptionalPropertyTypes: true
        \\interface IAny {
        \\    a?: any
        \\}
        \\interface J {
        \\    a?: number | undefined
        \\}
        \\declare var iany: IAny
        \\declare var j: J
        \\iany/**/ = j
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestAutoImportPackageJsonFilterExistingImport2" {
    const content =
        \\// @lib: es5
        \\// @module: preserve
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/react/index.d.ts
        \\export declare function useMemo(): void;
        \\export declare function useState(): void;
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{}
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\useMemo/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyImportFixAtPosition(undefined, &.{}, null );
    _ = f.GoToBOF(undefined);
    _ = f.InsertLine(undefined, "import { useState } from \"react\";");
    _ = f.GoToMarker(undefined, "");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { useMemo, useState } from \"react\";\nuseMemo",
    }, null );
}

test "TestGoToDefinitionCSSPatternAmbientModule" {
    const content =
        \\// @esModuleInterop: true
        \\// @Filename: index.css
        \\/*2a*/html { font-size: 16px; }
        \\// @Filename: types.ts
        \\declare module /*2b*/"*.css" {
        \\  const styles: any;
        \\  export = styles;
        \\}
        \\// @Filename: index.ts
        \\import styles from [|/*1*/"./index.css"|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

