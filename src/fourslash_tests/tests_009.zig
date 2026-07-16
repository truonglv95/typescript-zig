const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestInlayHintsNoVariableTypeHints" {
    const content =
        \\const a = 123;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayVariableTypeHints = core.TSFalse}});
}

test "TestReferencesForContextuallyTypedUnionProperties" {
    const content =
        \\interface A {
        \\    a: number;
        \\    /*1*/common: string;
        \\}
        \\
        \\interface B {
        \\    b: number;
        \\    /*2*/common: number;
        \\}
        \\
        \\// Assignment
        \\var v1: A | B = { a: 0, /*3*/common: "" };
        \\var v2: A | B = { b: 0, /*4*/common: 3 };
        \\
        \\// Function call
        \\function consumer(f:  A | B) { }
        \\consumer({ a: 0, b: 0, /*5*/common: 1 });
        \\
        \\// Type cast
        \\var c = <A | B> { /*6*/common: 0, b: 0 };
        \\
        \\// Array literal
        \\var ar: Array<A|B> = [{ a: 0, /*7*/common: "" }, { b: 0, /*8*/common: 0 }];
        \\
        \\// Nested object literal
        \\var ob: { aorb: A|B } = { aorb: { b: 0, /*9*/common: 0 } };
        \\
        \\// Widened type
        \\var w: A|B = { a:0, /*10*/common: undefined };
        \\
        \\// Untped -- should not be included
        \\var u1 = { a: 0, b: 0, common: "" };
        \\var u2 = { b: 0, common: 0 };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8", "9", "10");
}

test "TestFormatEmptyBlock" {
    const content =
        \\{}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToEOF(undefined);
    _ = f.Insert(undefined, "\n");
    _ = f.GoToBOF(undefined);
    try f.VerifyCurrentLineContent(undefined, "{ }");
}

test "TestRenameInheritedProperties3" {
    const content =
        \\interface interface1 extends interface1 {
        \\   [|[|{| "contextRangeIndex": 0 |}propName|]: string;|]
        \\}
        \\
        \\var v: interface1;
        \\v.[|propName|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "propName");
}

test "TestCompletionsExternalModuleReferenceResolutionOrderInImportDeclaration" {
    const content =
        \\// @Filename: externalModuleRefernceResolutionOrderInImportDeclaration_file1.ts
        \\export function foo() { };
        \\// @Filename: externalModuleRefernceResolutionOrderInImportDeclaration_file2.ts
        \\declare module "externalModuleRefernceResolutionOrderInImportDeclaration_file1" {
        \\    export function bar();
        \\}
        \\// @Filename: externalModuleRefernceResolutionOrderInImportDeclaration_file3.ts
        \\///<reference path='externalModuleRefernceResolutionOrderInImportDeclaration_file2.ts'/>
        \\import file1 = require('externalModuleRefernceResolutionOrderInImportDeclaration_file1');
        \\/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "file1.");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "bar",
//             },
//             .Excludes = &.{
//                 "foo",
//             },
//         },
//     });
}

test "TestJavaScriptClass2" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\class Foo {
        \\   constructor() {
        \\       [|this.[|{| "contextRangeIndex": 0 |}union|] = 'foo';|]
        \\       [|this.[|{| "contextRangeIndex": 2 |}union|] = 100;|]
        \\   }
        \\   method() { return this.[|union|]; }
        \\}
        \\var x = new Foo();
        \\x.[|union|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "union");
}

test "TestFindAllRefsNonexistentPropertyNoCrash1" {
    const content =
        \\// @strict: true
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @filename: ./src/parser-input.js
        \\export default () => {
        \\  let input;
        \\
        \\  const parserInput = {};
        \\
        \\  parserInput.currentChar = () => input.charAt(parserInput.i);
        \\
        \\  parserInput.end = () => {
        \\    const isFinished = parserInput.i >= input.length;
        \\
        \\    return {
        \\      isFinished,
        \\      furthest: parserInput.i,
        \\    };
        \\  };
        \\
        \\  return parserInput;
        \\};
        \\// @filename: ./src/parser.js
        \\import getParserInput from "./parser-input";
        \\
        \\const Parser = function Parser(context, imports, fileInfo, currentIndex) {
        \\  currentIndex = currentIndex || 0;
        \\  let parsers;
        \\  const parserInput = getParserInput();
        \\
        \\  return {
        \\    parserInput,
        \\    parsers: (parsers = {
        \\      variable: function () {
        \\        let name;
        \\
        \\        if (parserInput.currentChar() === "/*1*/@") {
        \\          return name[1];
        \\        }
        \\      },
        \\    }),
        \\  };
        \\};
        \\
        \\export default Parser;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestFindAllRefsJsDocTemplateTag_class_js" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\/** @template /*1*/T */
        \\class C {
        \\    constructor() {
        \\        /** @type {/*2*/T} */
        \\        this.x = null;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestCompletionListAfterFunction2" {
    const content =
        \\// Outside the function expression
        \\declare var f1: (a: number) => void; /*1*/
        \\
        \\declare var f1: (b: number, b2: /*2*/) => void;
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
//             .Excludes = &.{
//                 "b",
//             },
//         },
//     });
    _ = f.Insert(undefined, "typeof ");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "b",
//             },
//         },
//     });
}

test "TestMemberListOnConstructorType" {
    const content =
        \\// @lib: es5
        \\var f: new () => void;
        \\f./*1*/
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
//             .Exact = CompletionFunctionMembersWithPrototype,
//         },
//     });
}

test "TestCompletionListAfterPropertyName" {
    const content =
        \\// @Filename: a.ts
        \\class Test1 {
        \\    public some /*afterPropertyName*/
        \\}
        \\// @Filename: b.ts
        \\class Test2 {
        \\    public some(/*inMethodParameter*/
        \\}
        \\// @Filename: c.ts
        \\class Test3 {
        \\    public some(a/*atMethodParameter*/
        \\}
        \\// @Filename: d.ts
        \\class Test4 {
        \\    public some(a /*afterMethodParameter*/
        \\}
        \\// @Filename: e.ts
        \\class Test5 {
        \\    public some(a /*afterMethodParameterBeforeComma*/,
        \\}
        \\// @Filename: f.ts
        \\class Test6 {
        \\    public some(a, /*afterMethodParameterComma*/
        \\}
        \\// @Filename: g.ts
        \\class Test7 {
        \\    constructor(/*inConstructorParameter*/
        \\}
        \\// @Filename: h.ts
        \\class Test8 {
        \\    constructor(public /*inConstructorParameterAfterModifier*/
        \\}
        \\// @Filename: i.ts
        \\class Test9 {
        \\    constructor(a/*atConstructorParameter*/
        \\}
        \\// @Filename: j.ts
        \\class Test10 {
        \\    constructor(public/*atConstructorParameterModifier*/
        \\}
        \\// @Filename: k.ts
        \\class Test11 {
        \\    constructor(public a/*atConstructorParameterAfterModifier*/
        \\}
        \\// @Filename: l.ts
        \\class Test12 {
        \\    constructor(a /*afterConstructorParameter*/
        \\}
        \\// @Filename: m.ts
        \\class Test13 {
        \\    constructor(a /*afterConstructorParameterBeforeComma*/,
        \\}
        \\// @Filename: n.ts
        \\class Test14 {
        \\    constructor(public a, /*afterConstructorParameterComma*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, &.{"afterPropertyName", "inMethodParameter", "atMethodParameter", "afterMethodParameter", "afterMethodParameterBeforeComma", "afterMethodParameterComma", "afterConstructorParameter"}, null);
    // f.VerifyCompletions(undefined, &.{"inConstructorParameter", "inConstructorParameterAfterModifier", "atConstructorParameter", "atConstructorParameterModifier", "atConstructorParameterAfterModifier", "afterConstructorParameterComma"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionConstructorParameterKeywords,
//         },
//     });
}

test "TestRenameContextuallyTypedProperties" {
    const content =
        \\interface I {
        \\    [|[|{| "contextRangeIndex": 0 |}prop1|]: () => void;|]
        \\    prop2(): void;
        \\}
        \\
        \\var o1: I = {
        \\    [|[|{| "contextRangeIndex": 2 |}prop1|]() { }|],
        \\    prop2() { }
        \\};
        \\
        \\var o2: I = {
        \\    [|[|{| "contextRangeIndex": 4 |}prop1|]: () => { }|],
        \\    prop2: () => { }
        \\};
        \\
        \\var o3: I = {
        \\    [|get [|{| "contextRangeIndex": 6 |}prop1|]() { return () => { }; }|],
        \\    get prop2() { return () => { }; }
        \\};
        \\
        \\var o4: I = {
        \\    [|set [|{| "contextRangeIndex": 8 |}prop1|](v) { }|],
        \\    set prop2(v) { }
        \\};
        \\
        \\var o5: I = {
        \\    [|"[|{| "contextRangeIndex": 10 |}prop1|]"() { }|],
        \\    "prop2"() { }
        \\};
        \\
        \\var o6: I = {
        \\    [|"[|{| "contextRangeIndex": 12 |}prop1|]": function () { }|],
        \\    "prop2": function () { }
        \\};
        \\
        \\var o7: I = {
        \\    [|["[|{| "contextRangeIndex": 14 |}prop1|]"]: function () { }|],
        \\    ["prop2"]: function () { }
        \\};
        \\
        \\var o8: I = {
        \\    [|["[|{| "contextRangeIndex": 16 |}prop1|]"]() { }|],
        \\    ["prop2"]() { }
        \\};
        \\
        \\var o9: I = {
        \\    [|get ["[|{| "contextRangeIndex": 18 |}prop1|]"]() { return () => { }; }|],
        \\    get ["prop2"]() { return () => { }; }
        \\};
        \\
        \\var o10: I = {
        \\    [|set ["[|{| "contextRangeIndex": 20 |}prop1|]"](v) { }|],
        \\    set ["prop2"](v) { }
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "prop1");
}

test "TestFormattingOnInvalidCodes" {
    const content =
        \\/*1*/var a;var c          , b;var  $d
        \\/*2*/var $e
        \\/*3*/var f
        \\/*4*/a++;b++;
        \\
        \\/*5*/function        f     (     )        {
        \\/*6*/    for (i = 0; i < 10; i++) {
        \\/*7*/        k = abc + 123 ^ d;
        \\/*8*/        a = XYZ[m  (a[b[c][d]])];
        \\/*9*/        break;
        \\
        \\/*10*/        switch ( variable){
        \\/*11*/       case  1: abc += 425;
        \\/*12*/break;
        \\/*13*/case 404 : a [x--/2]%=3 ;
        \\/*14*/                    break ;
        \\/*15*/                case vari : v[--x ] *=++y*( m + n / k[z]);
        \\/*16*/                for (a in b){
        \\/*17*/             for (a = 0; a < 10; ++a) {
        \\/*18*/              a++;--a;
        \\/*19*/                   if (a == b) {
        \\/*20*/                          a++;b--;
        \\/*21*/                     }
        \\/*22*/else
        \\/*23*/if (a == c){
        \\/*24*/++a;
        \\/*25*/(--c)+=d;
        \\/*26*/$c = $a + --$b;
        \\/*27*/}
        \\/*28*/if (a == b)
        \\/*29*/if (a != b) {
        \\/*30*/ if (a !== b)
        \\/*31*/ if (a === b)
        \\/*32*/ --a;
        \\/*33*/ else
        \\/*34*/  --a;
        \\/*35*/  else {
        \\/*36*/  a--;++b;
        \\/*37*/a++
        \\/*38*/                    }
        \\/*39*/                    }
        \\/*40*/                    }
        \\/*41*/                    for (x in y) {
        \\/*42*/m-=m;
        \\/*43*/k=1+2+3+4;
        \\/*44*/}
        \\/*45*/}
        \\/*46*/    break;
        \\
        \\/*47*/    }
        \\/*48*/    }
        \\/*49*/    var a  ={b:function(){}};
        \\/*50*/    return {a:1,b:2}
        \\/*51*/}
        \\
        \\/*52*/var z = 1;
        \\/*53*/            for (i = 0; i < 10; i++)
        \\/*54*/     for (j = 0; j < 10; j++)
        \\/*55*/for (k = 0; k < 10; ++k) {
        \\/*56*/z++;
        \\/*57*/}
        \\
        \\/*58*/for (k = 0; k < 10; k += 2) {
        \\/*59*/z++;
        \\/*60*/}
        \\
        \\/*61*/    $(document).ready ();
        \\
        \\
        \\/*62*/ function  pageLoad() {
        \\/*63*/ $('#TextBox1' ) .     unbind   (  ) ;
        \\/*64*/$('#TextBox1' ) . datepicker ( ) ;
        \\/*65*/}
        \\
        \\/*66*/        function pageLoad    (     )    {
        \\/*67*/    var webclass=[
        \\/*68*/                { 'student'     :/*69*/
        \\/*70*/                { 'id': '1', 'name': 'Linda Jones', 'legacySkill': 'Access, VB 5.0' }
        \\/*71*/        }   ,
        \\/*72*/{    'student':/*73*/
        \\/*74*/{'id':'2','name':'Adam Davidson','legacySkill':'Cobol,MainFrame'}
        \\/*75*/}      ,
        \\/*76*/    { 'student':/*77*/
        \\/*78*/{   'id':'3','name':'Charles Boyer' ,'legacySkill':'HTML, XML'}
        \\/*79*/}
        \\/*80*/    ];
        \\
        \\/*81*/$create(Sys.UI.DataView,{data:webclass},null,null,$get('SList'));
        \\
        \\/*82*/}
        \\
        \\/*83*/$( document ).ready(function(){
        \\/*84*/alert('hello');
        \\/*85*/    } ) ;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "var a; var c, b; var $d");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "var $e");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "var f");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "a++; b++;");
    _ = f.GoToMarker(undefined, "5");
    try f.VerifyCurrentLineContent(undefined, "function f() {");
    _ = f.GoToMarker(undefined, "6");
    try f.VerifyCurrentLineContent(undefined, "    for (i = 0; i < 10; i++) {");
    _ = f.GoToMarker(undefined, "7");
    try f.VerifyCurrentLineContent(undefined, "        k = abc + 123 ^ d;");
    _ = f.GoToMarker(undefined, "8");
    try f.VerifyCurrentLineContent(undefined, "        a = XYZ[m(a[b[c][d]])];");
    _ = f.GoToMarker(undefined, "9");
    try f.VerifyCurrentLineContent(undefined, "        break;");
    _ = f.GoToMarker(undefined, "10");
    try f.VerifyCurrentLineContent(undefined, "        switch (variable) {");
    _ = f.GoToMarker(undefined, "11");
    try f.VerifyCurrentLineContent(undefined, "            case 1: abc += 425;");
    _ = f.GoToMarker(undefined, "12");
    try f.VerifyCurrentLineContent(undefined, "                break;");
    _ = f.GoToMarker(undefined, "13");
    try f.VerifyCurrentLineContent(undefined, "            case 404: a[x-- / 2] %= 3;");
    _ = f.GoToMarker(undefined, "14");
    try f.VerifyCurrentLineContent(undefined, "                break;");
    _ = f.GoToMarker(undefined, "15");
    try f.VerifyCurrentLineContent(undefined, "            case vari: v[--x] *= ++y * (m + n / k[z]);");
    _ = f.GoToMarker(undefined, "16");
    try f.VerifyCurrentLineContent(undefined, "                for (a in b) {");
    _ = f.GoToMarker(undefined, "17");
    try f.VerifyCurrentLineContent(undefined, "                    for (a = 0; a < 10; ++a) {");
    _ = f.GoToMarker(undefined, "18");
    try f.VerifyCurrentLineContent(undefined, "                        a++; --a;");
    _ = f.GoToMarker(undefined, "19");
    try f.VerifyCurrentLineContent(undefined, "                        if (a == b) {");
    _ = f.GoToMarker(undefined, "20");
    try f.VerifyCurrentLineContent(undefined, "                            a++; b--;");
    _ = f.GoToMarker(undefined, "21");
    try f.VerifyCurrentLineContent(undefined, "                        }");
    _ = f.GoToMarker(undefined, "22");
    try f.VerifyCurrentLineContent(undefined, "                        else");
    _ = f.GoToMarker(undefined, "23");
    try f.VerifyCurrentLineContent(undefined, "                            if (a == c) {");
    _ = f.GoToMarker(undefined, "24");
    try f.VerifyCurrentLineContent(undefined, "                                ++a;");
    _ = f.GoToMarker(undefined, "25");
    try f.VerifyCurrentLineContent(undefined, "                                (--c) += d;");
    _ = f.GoToMarker(undefined, "26");
    try f.VerifyCurrentLineContent(undefined, "                                $c = $a + --$b;");
    _ = f.GoToMarker(undefined, "27");
    try f.VerifyCurrentLineContent(undefined, "                            }");
    _ = f.GoToMarker(undefined, "28");
    try f.VerifyCurrentLineContent(undefined, "                        if (a == b)");
    _ = f.GoToMarker(undefined, "29");
    try f.VerifyCurrentLineContent(undefined, "                            if (a != b) {");
    _ = f.GoToMarker(undefined, "30");
    try f.VerifyCurrentLineContent(undefined, "                                if (a !== b)");
    _ = f.GoToMarker(undefined, "31");
    try f.VerifyCurrentLineContent(undefined, "                                    if (a === b)");
    _ = f.GoToMarker(undefined, "32");
    try f.VerifyCurrentLineContent(undefined, "                                        --a;");
    _ = f.GoToMarker(undefined, "33");
    try f.VerifyCurrentLineContent(undefined, "                                    else");
    _ = f.GoToMarker(undefined, "34");
    try f.VerifyCurrentLineContent(undefined, "                                        --a;");
    _ = f.GoToMarker(undefined, "35");
    try f.VerifyCurrentLineContent(undefined, "                                else {");
    _ = f.GoToMarker(undefined, "36");
    try f.VerifyCurrentLineContent(undefined, "                                    a--; ++b;");
    _ = f.GoToMarker(undefined, "37");
    try f.VerifyCurrentLineContent(undefined, "                                    a++");
    _ = f.GoToMarker(undefined, "38");
    try f.VerifyCurrentLineContent(undefined, "                                }");
    _ = f.GoToMarker(undefined, "39");
    try f.VerifyCurrentLineContent(undefined, "                            }");
    _ = f.GoToMarker(undefined, "40");
    try f.VerifyCurrentLineContent(undefined, "                    }");
    _ = f.GoToMarker(undefined, "41");
    try f.VerifyCurrentLineContent(undefined, "                    for (x in y) {");
    _ = f.GoToMarker(undefined, "42");
    try f.VerifyCurrentLineContent(undefined, "                        m -= m;");
    _ = f.GoToMarker(undefined, "43");
    try f.VerifyCurrentLineContent(undefined, "                        k = 1 + 2 + 3 + 4;");
    _ = f.GoToMarker(undefined, "44");
    try f.VerifyCurrentLineContent(undefined, "                    }");
    _ = f.GoToMarker(undefined, "45");
    try f.VerifyCurrentLineContent(undefined, "                }");
    _ = f.GoToMarker(undefined, "46");
    try f.VerifyCurrentLineContent(undefined, "                break;");
    _ = f.GoToMarker(undefined, "47");
    try f.VerifyCurrentLineContent(undefined, "        }");
    _ = f.GoToMarker(undefined, "48");
    try f.VerifyCurrentLineContent(undefined, "    }");
    _ = f.GoToMarker(undefined, "49");
    try f.VerifyCurrentLineContent(undefined, "    var a = { b: function() { } };");
    _ = f.GoToMarker(undefined, "50");
    try f.VerifyCurrentLineContent(undefined, "    return { a: 1, b: 2 }");
    _ = f.GoToMarker(undefined, "51");
    try f.VerifyCurrentLineContent(undefined, "}");
    _ = f.GoToMarker(undefined, "52");
    try f.VerifyCurrentLineContent(undefined, "var z = 1;");
    _ = f.GoToMarker(undefined, "53");
    try f.VerifyCurrentLineContent(undefined, "for (i = 0; i < 10; i++)");
    _ = f.GoToMarker(undefined, "54");
    try f.VerifyCurrentLineContent(undefined, "    for (j = 0; j < 10; j++)");
    _ = f.GoToMarker(undefined, "55");
    try f.VerifyCurrentLineContent(undefined, "        for (k = 0; k < 10; ++k) {");
    _ = f.GoToMarker(undefined, "56");
    try f.VerifyCurrentLineContent(undefined, "            z++;");
    _ = f.GoToMarker(undefined, "57");
    try f.VerifyCurrentLineContent(undefined, "        }");
    _ = f.GoToMarker(undefined, "58");
    try f.VerifyCurrentLineContent(undefined, "for (k = 0; k < 10; k += 2) {");
    _ = f.GoToMarker(undefined, "59");
    try f.VerifyCurrentLineContent(undefined, "    z++;");
    _ = f.GoToMarker(undefined, "60");
    try f.VerifyCurrentLineContent(undefined, "}");
    _ = f.GoToMarker(undefined, "61");
    try f.VerifyCurrentLineContent(undefined, "$(document).ready();");
    _ = f.GoToMarker(undefined, "62");
    try f.VerifyCurrentLineContent(undefined, "function pageLoad() {");
    _ = f.GoToMarker(undefined, "63");
    try f.VerifyCurrentLineContent(undefined, "    $('#TextBox1').unbind();");
    _ = f.GoToMarker(undefined, "64");
    try f.VerifyCurrentLineContent(undefined, "    $('#TextBox1').datepicker();");
    _ = f.GoToMarker(undefined, "65");
    try f.VerifyCurrentLineContent(undefined, "}");
    _ = f.GoToMarker(undefined, "66");
    try f.VerifyCurrentLineContent(undefined, "function pageLoad() {");
    _ = f.GoToMarker(undefined, "67");
    try f.VerifyCurrentLineContent(undefined, "    var webclass = [");
    _ = f.GoToMarker(undefined, "68");
    try f.VerifyCurrentLineContent(undefined, "        {");
    _ = f.GoToMarker(undefined, "69");
    try f.VerifyCurrentLineContent(undefined, "            'student':");
    _ = f.GoToMarker(undefined, "70");
    try f.VerifyCurrentLineContent(undefined, "                { 'id': '1', 'name': 'Linda Jones', 'legacySkill': 'Access, VB 5.0' }");
    _ = f.GoToMarker(undefined, "71");
    try f.VerifyCurrentLineContent(undefined, "        },");
    _ = f.GoToMarker(undefined, "72");
    try f.VerifyCurrentLineContent(undefined, "        {");
    _ = f.GoToMarker(undefined, "73");
    try f.VerifyCurrentLineContent(undefined, "            'student':");
    _ = f.GoToMarker(undefined, "74");
    try f.VerifyCurrentLineContent(undefined, "                { 'id': '2', 'name': 'Adam Davidson', 'legacySkill': 'Cobol,MainFrame' }");
    _ = f.GoToMarker(undefined, "75");
    try f.VerifyCurrentLineContent(undefined, "        },");
    _ = f.GoToMarker(undefined, "76");
    try f.VerifyCurrentLineContent(undefined, "        {");
    _ = f.GoToMarker(undefined, "77");
    try f.VerifyCurrentLineContent(undefined, "            'student':");
    _ = f.GoToMarker(undefined, "78");
    try f.VerifyCurrentLineContent(undefined, "                { 'id': '3', 'name': 'Charles Boyer', 'legacySkill': 'HTML, XML' }");
    _ = f.GoToMarker(undefined, "79");
    try f.VerifyCurrentLineContent(undefined, "        }");
    _ = f.GoToMarker(undefined, "80");
    try f.VerifyCurrentLineContent(undefined, "    ];");
    _ = f.GoToMarker(undefined, "81");
    try f.VerifyCurrentLineContent(undefined, "    $create(Sys.UI.DataView, { data: webclass }, null, null, $get('SList'));");
    _ = f.GoToMarker(undefined, "82");
    try f.VerifyCurrentLineContent(undefined, "}");
    _ = f.GoToMarker(undefined, "83");
    try f.VerifyCurrentLineContent(undefined, "$(document).ready(function() {");
    _ = f.GoToMarker(undefined, "84");
    try f.VerifyCurrentLineContent(undefined, "    alert('hello');");
    _ = f.GoToMarker(undefined, "85");
    try f.VerifyCurrentLineContent(undefined, "});");
}

test "TestQuickInfoAssertionNodeNotReusedWhenTypeNotEquivalent1" {
    const content =
        \\// @strict: true
        \\type Wrapper<T> = {
        \\  _type: T;
        \\};
        \\
        \\function stringWrapper(): Wrapper<string> {
        \\  return { _type: "" };
        \\}
        \\
        \\function objWrapper<T extends Record<string, Wrapper<any>>>(
        \\  obj: T,
        \\): Wrapper<T> {
        \\  return { _type: obj };
        \\}
        \\
        \\const value = objWrapper({
        \\  prop1: stringWrapper() as Wrapper<"hello">,
        \\});
        \\
        \\type Unwrap<T extends Wrapper<any>> = T["_type"] extends Record<
        \\  string,
        \\  Wrapper<any>
        \\>
        \\  ? { [Key in keyof T["_type"]]: Unwrap<T["_type"][Key]> }
        \\  : T["_type"];
        \\
        \\type Test/*1*/ = Unwrap<typeof value>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "type Test = {\n    prop1: \"hello\";\n}", "");
}

test "TestQuickInfoJsDocGetterSetter" {
    const content =
        \\class A {
        \\    /**
        \\     * getter A
        \\     * @returns return A
        \\     */
        \\    get /*1*/x(): string {
        \\        return "";
        \\    }
        \\    /**
        \\     * setter A
        \\     * @param value foo A
        \\     * @todo empty jsdoc
        \\     */
        \\    set /*2*/x(value) { }
        \\}
        \\// override both getter and setter
        \\class B extends A {
        \\    /**
        \\     * getter B
        \\     * @returns return B
        \\     */
        \\    get /*3*/x(): string {
        \\        return "";
        \\    }
        \\    /**
        \\     * setter B
        \\     * @param value foo B
        \\     */
        \\    set /*4*/x(vale) { }
        \\}
        \\// not override
        \\class C extends A { }
        \\// only override setter
        \\class D extends A {
        \\    /**
        \\     * setter D
        \\     * @param value foo D
        \\     */
        \\    set /*5*/x(val: string) { }
        \\}
        \\new A()./*6*/x = "1";
        \\new B()./*7*/x = "1";
        \\new C()./*8*/x = "1";
        \\new D()./*9*/x = "1";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestQuickInfoForJSDocUnknownTag" {
    const content =
        \\/**
        \\ * @example
        \\ * if (true) {
        \\ *     foo()
        \\ * }
        \\ */
        \\function fo/*1*/o() {
        \\    return '2';
        \\}
        \\/**
        \\ @example
        \\ {
        \\     foo()
        \\ }
        \\ */
        \\function fo/*2*/o2() {
        \\    return '2';
        \\}
        \\/**
        \\ * @example
        \\ *   x y
        \\ *   12345
        \\ *      b
        \\ */
        \\function m/*3*/oo() {
        \\    return '2';
        \\}
        \\/**
        \\ * @func
        \\ * @example
        \\ *   x y
        \\ *   12345
        \\ *      b
        \\ */
        \\function b/*4*/oo() {
        \\    return '2';
        \\}
        \\/**
        \\ * @func
        \\ * @example    x y
        \\ *             12345
        \\ *                b
        \\ */
        \\function go/*5*/o() {
        \\    return '2';
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestCompletionsJsxAttribute2" {
    const content =
        \\// @jsx: preserve
        \\// @Filename: /a.tsx
        \\declare namespace JSX {
        \\    interface Element {}
        \\    interface IntrinsicElements {
        \\        div: {
        \\            /** Doc */
        \\            foo: boolean;
        \\            bar: string;
        \\            "aria-foo": boolean;
        \\        }
        \\    }
        \\}
        \\
        \\<div foo /*1*/></div>;
        \\<div foo={true} /*2*/></div>;
        \\<div bar="test" /*3*/></div>;
        \\<div aria-foo /*4*/></div>;
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
//                 "aria-foo",
//                 "bar",
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
//                 "aria-foo",
//                 "bar",
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
//                 "aria-foo",
//                 "foo",
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
//                 "foo",
//             },
//         },
//     });
}

test "TestCompletionsObjectLiteralUnionTemplateLiteralType" {
    const content =
        \\type UnionType = {
        \\  key1: string;
        \\} | {
        \\  key2: number;
        \\} | 
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
//                     .Label = "key1",
//                 },
//                 &.{
//                     .Label = "key2",
//                 },
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
//                 &.{
//                     .Label = "key2",
//                 },
//             },
//         },
//     });
}

test "TestImportNameCodeFix_importType5" {
    const content =
        \\// @module: es2015
        \\// @Filename: /exports.ts
        \\export interface SomeInterface {}
        \\export class SomePig {}
        \\// @Filename: /a.ts
        \\import type { SomeInterface, SomePig } from "./exports.js";
        \\new SomePig/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { SomeInterface, SomePig } from \"./exports.js\";\nnew SomePig",
    }, null );
}

test "TestObjectLiteralBindingInParameter" {
    const content =
        \\interface I { x1: number; x2: string }
        \\function f(cb: (ev: I) => any) { }
        \\f(({/*1*/}) => 0);
        \\[<I>null].reduce(({/*2*/}, b) => b);
        \\interface Foo {
        \\    m(x: { x1: number, x2: number }): void;
        \\    prop: I;
        \\}
        \\let x: Foo = {
        \\    m({ /*3*/ }) {
        \\    },
        \\    get prop(): I { return undefined; },
        \\    set prop({ /*4*/ }) {
        \\    }
        \\};
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
//             .Exact = &.{
//                 "x1",
//                 "x2",
//             },
//         },
//     });
}

test "TestFormattingIllegalImportClause" {
    const content =
        \\var expect = require('expect.js');
        \\import React   from 'react'/*1*/;
        \\import { mount } from 'enzyme';
        \\require('../setup');
        \\var Amount = require('../../src/js/components/amount');
        \\describe('<Failed />', () => {
        \\  var history
        \\  beforeEach(() => {
        \\    history = createMemoryHistory();
        \\    sinon.spy(history, 'pushState');
        \\  });
        \\  afterEach(() => {
        \\  })
        \\  it('redirects to order summary', () => {
        \\  });
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "import React from 'react';");
}

test "TestFormattingHexLiteral" {
    const content =
        \\var x =  0x1,y;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
}

test "TestRenameJsExports02" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\module.exports = class /*1*/A {}
        \\// @Filename: b.js
        \\const /*2*/A = require("./a");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestCompletionEntryForPropertyFromUnionOfModuleType" {
    const content =
        \\namespace E {
        \\    export var n = 1;
        \\    export var x = 0;
        \\}
        \\namespace F {
        \\    export var n = 1;
        \\    export var y = 0;
        \\}
        \\var q: typeof E | typeof F;
        \\var j = q./*1*/
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
//                     .Label =  "n",
//                     .Detail = undefined("(property) n: number"),
//                 },
//             },
//         },
//     });
}

test "TestCompletionListInImportClause06" {
    const content =
        \\// @typeRoots: T1,T2
        \\// @Filename: app.ts
        \\import * as A from "/*1*/";
        \\// @Filename: T1/a__b/index.d.ts
        \\export declare let x: number;
        \\// @Filename: T2/a__b/index.d.ts
        \\export declare let x: number;
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
//                 "@a/b",
//             },
//         },
//     });
}

test "TestJsxSpreadReference" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\    }
        \\    interface ElementAttributesProperty { props }
        \\}
        \\class MyClass {
        \\  props: {
        \\    name?: string;
        \\    size?: number;
        \\  }
        \\}
        \\
        \\[|var [|/*dst*/{| "contextRangeIndex": 0 |}nn|]: {name?: string; size?: number};|]
        \\var x = <MyClass {...[|n/*src*/n|]}></MyClass>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "nn");
    // try f.VerifyBaselineGoToDefinition(undefined, true, "src");
}

test "TestCompletionListInNamedFunctionExpressionWithShadowing" {
    const content =
        \\function foo() {}
        \\/*0*/
        \\var x = function foo() {
        \\   /*1*/
        \\}
        \\var y = function () {
        \\   /*2*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"0", "2"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "foo",
//                     .Detail = undefined("function foo(): void"),
//                     .Kind =   undefined(lsproto.CompletionItemKindFunction),
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
//                     .Label =  "foo",
//                     .Detail = undefined("(local function) foo(): void"),
//                     .Kind =   undefined(lsproto.CompletionItemKindFunction),
//                 },
//             },
//         },
//     });
}

test "TestRemoveInterfaceUsedAsGenericTypeArgument" {
    const content =
        \\/**/interface A { a: string; }
        \\interface G<T, U> { }
        \\var v1: G<A, C>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.DeleteAtCaret(undefined, 26);
}

test "TestCompletionListInUnclosedTaggedTemplate02" {
    const content =
        \\var x;
        \\var y = (p) => x 
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
//                 "p",
//                 "x",
//             },
//         },
//     });
}

test "TestSuggestionNoDuplicates" {
    const content =
        \\// @strict: false
        \\// @Filename: foo.ts
        \\import { f } from [|'m'|]
        \\f
        \\// @Filename: node_modules/m/index.js
        \\module.exports.f = function (x) { return x }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNonSuggestionDiagnostics(undefined, null);
    // try f.VerifySuggestionDiagnostics(undefined, []*.{
//         .{
//             .Code =    &.{.Integer = undefined(int32(7016))},
//             .Message = .{.String = undefined("Could not find a declaration file for module 'm'. '/node_modules/m/index.js' implicitly has an 'any' type.")},
//         },
//     });
}

test "TestGetJavaScriptSyntacticDiagnostics19" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\enum E { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestCompletionListInTypeLiteralInTypeParameter7" {
    const content =
        \\interface Foo {
        \\    one: string;
        \\    two: {
        \\        three: number;
        \\    }
        \\}
        \\
        \\interface Bar<T extends Foo> {
        \\    foo: T;
        \\}
        \\
        \\var foobar: Bar<{
        \\    two: {/**/
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
//                 "three",
//             },
//         },
//     });
}

test "TestGotoDefinitionLinkTag1" {
    const content =
        \\// @Filename: foo.ts
        \\interface [|/*def1*/Foo|] {
        \\    foo: string
        \\}
        \\namespace NS {
        \\    export interface [|/*def2*/Bar|] {
        \\        baz: Foo
        \\    }
        \\}
        \\/** {@link /*use1*/[|Foo|]} foooo*/
        \\const a = ""
        \\/** {@link NS./*use2*/[|Bar|]} ns.bar*/
        \\const b = ""
        \\/** {@link /*use3*/[|Foo|] f1}*/
        \\const c = ""
        \\/** {@link NS./*use4*/[|Bar|] ns.bar}*/
        \\const [|/*def3*/d|] = ""
        \\/** {@link /*use5*/[|d|] }dd*/
        \\const e = ""
        \\/** @param x {@link /*use6*/[|Foo|]} */
        \\function foo(x) { }
        \\// @Filename: bar.ts
        \\/** {@link /*use7*/[|Foo|] }dd*/
        \\const f = ""
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, false, "use1", "use2", "use3", "use4", "use5", "use6", "use7");
}

test "TestCodeFixClassImplementInterfaceSomePropertiesPresent" {
    const content =
        \\// @strict: false
        \\
        \\interface I {
        \\    x: number;
        \\    y: number;
        \\    z: number & { __iBrand: any };
        \\}
        \\
        \\class C implements I {[|
        \\   |]constructor(public x: number) { }
        \\   y: number;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "\ninterface I {\n    x: number;\n    y: number;\n    z: number & { __iBrand: any };\n}\n\nclass C implements I {\n   constructor(public x: number) { }\n    z: number & { __iBrand: any; };\n   y: number;\n}",
        .Index = 0,
    });
}

test "TestGetSemanticDiagnosticForDeclaration" {
    const content =
        \\// @strict: false
        \\// @module: CommonJS
        \\// @declaration: true
        \\export function /*1*/foo/*2*/() {
        \\    interface privateInterface {}
        \\    class Bar implements privateInterface { private a; }
        \\    return Bar;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyErrorExistsBetweenMarkers(undefined, "1", "2");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestCodeFixMissingTypeAnnotationOnExports54_generator_generics" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @lib: es2015
        \\export function foo(x: Generator<number>) {
        \\    return x;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add return type 'Generator<number>'",
        .NewFileContent = "export function foo(x: Generator<number>): Generator<number> {\n    return x;\n}",
        .Index = 0,
    });
}

test "TestInsertVarAfterEmptyTypeParamList" {
    const content =
        \\class Dictionary<> { }
        \\var x;
        \\/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "var y;\n");
}

test "TestTsxFindAllReferences8" {
    const content =
        \\//@Filename: file.tsx
        \\// @jsx: preserve
        \\// @noLib: true
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\    }
        \\    interface ElementAttributesProperty { props; }
        \\}
        \\interface ClickableProps {
        \\    children?: string;
        \\    className?: string;
        \\}
        \\interface ButtonProps extends ClickableProps {
        \\    onClick(event?: React.MouseEvent<HTMLButtonElement>): void;
        \\}
        \\interface LinkProps extends ClickableProps {
        \\    goTo: string;
        \\}
        \\/*1*/declare function /*2*/MainButton(buttonProps: ButtonProps): JSX.Element;
        \\/*3*/declare function /*4*/MainButton(linkProps: LinkProps): JSX.Element;
        \\/*5*/declare function /*6*/MainButton(props: ButtonProps | LinkProps): JSX.Element;
        \\let opt = /*7*/</*8*/MainButton />;
        \\let opt = /*9*/</*10*/MainButton children="chidlren" />;
        \\let opt = /*11*/</*12*/MainButton onClick={()=>{}} />;
        \\let opt = /*13*/</*14*/MainButton onClick={()=>{}} ignore-prop />;
        \\let opt = /*15*/</*16*/MainButton goTo="goTo" />;
        \\let opt = /*17*/</*18*/MainButton wrong />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18");
}

test "TestImportNameCodeFixNewImportFileQuoteStyle2" {
    const content =
        \\[|import m2 = require('./module2');
        \\
        \\f1/*0*/();|]
        \\// @Filename: module1.ts
        \\export function f1() {}
        \\// @Filename: module2.ts
        \\export var v2 = 6;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from './module1';\nimport m2 = require('./module2');\n\nf1();",
    }, null );
}

test "TestCompletionsRecommended_equals" {
    const content =
        \\enum Enu {}
        \\declare const e: Enu;
        \\e === /*a*/;
        \\e === E/*b*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"a", "b"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =     "Enu",
//                     .Detail =    undefined("enum Enu"),
//                     .Kind =      undefined(lsproto.CompletionItemKindEnum),
//                     .Preselect = undefined(true),
//                 },
//             },
//         },
//     });
}

test "TestCompletionInJSDocFunctionThis" {
    const content =
        \\// @allowJs: true
        \\// @Filename: Foo.js
        \\/** @type {function (this: string, string): string} */
        \\var f = function (s) { return this/**/; }
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
//                     .Label =    "this",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestGetOccurrencesModifiersNegatives1" {
    const content =
        \\class C {
        \\    [|{| "count": 3 |}export|] foo;
        \\    [|{| "count": 3 |}declare|] bar;
        \\    [|{| "count": 3 |}export|] [|{| "count": 3 |}declare|] foobar;
        \\    [|{| "count": 3 |}declare|] [|{| "count": 3 |}export|] barfoo;
        \\
        \\    constructor([|{| "count": 9 |}export|] conFoo,
        \\                [|{| "count": 9 |}declare|] conBar,
        \\                [|{| "count": 9 |}export|] [|{| "count": 9 |}declare|] conFooBar,
        \\                [|{| "count": 9 |}declare|] [|{| "count": 9 |}export|] conBarFoo,
        \\                [|{| "count": 4 |}static|] sue,
        \\                [|{| "count": 4 |}static|] [|{| "count": 9 |}export|] [|{| "count": 9 |}declare|] sueFooBar,
        \\                [|{| "count": 4 |}static|] [|{| "count": 9 |}declare|] [|{| "count": 9 |}export|] sueBarFoo,
        \\                [|{| "count": 9 |}declare|] [|{| "count": 4 |}static|] [|{| "count": 9 |}export|] barSueFoo) {
        \\    }
        \\}
        \\
        \\namespace m {
        \\    [|{| "count": 0 |}static|] a;
        \\    [|{| "count": 0 |}public|] b;
        \\    [|{| "count": 0 |}private|] c;
        \\    [|{| "count": 0 |}protected|] d;
        \\    [|{| "count": 0 |}static|] [|{| "count": 0 |}public|] [|{| "count": 0 |}private|] [|{| "count": 0 |}protected|] e;
        \\    [|{| "count": 0 |}public|] [|{| "count": 0 |}static|] [|{| "count": 0 |}protected|] [|{| "count": 0 |}private|] f;
        \\    [|{| "count": 0 |}protected|] [|{| "count": 0 |}static|] [|{| "count": 0 |}public|] g;
        \\}
        \\[|{| "count": 0 |}static|] a;
        \\[|{| "count": 0 |}public|] b;
        \\[|{| "count": 0 |}private|] c;
        \\[|{| "count": 0 |}protected|] d;
        \\[|{| "count": 0 |}static|] [|{| "count": 0 |}public|] [|{| "count": 0 |}private|] [|{| "count": 0 |}protected|] e;
        \\[|{| "count": 0 |}public|] [|{| "count": 0 |}static|] [|{| "count": 0 |}protected|] [|{| "count": 0 |}private|] f;
        \\[|{| "count": 0 |}protected|] [|{| "count": 0 |}static|] [|{| "count": 0 |}public|] g;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestGoToDefinitionImplicitConstructor" {
    const content =
        \\class /*constructorDefinition*/ImplicitConstructor {
        \\}
        \\var implicitConstructor = new /*constructorReference*/ImplicitConstructor();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, false, "constructorReference");
}

test "TestFindAllRefsTypeofImport" {
    const content =
        \\// @Filename: /a.ts
        \\/*1*/export const /*2*/x = 0;
        \\declare const a: typeof import("./a");
        \\a./*3*/x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestCallHierarchyClass" {
    const content =
        \\function foo() {
        \\    bar();
        \\}
        \\
        \\function /**/bar() {
        \\    new Baz();
        \\}
        \\
        \\class Baz {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifyBaselineCallHierarchy(undefined);
}

test "TestCodeFixMissingTypeAnnotationOnExports33_methods" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @Filename: /code.ts
        \\export class Foo {
        \\  m() {
        \\  }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFixAvailable(undefined, &.{"Add return type 'void'"});
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add return type 'void'",
        .NewFileContent = "export class Foo {\n  m(): void {\n  }\n}",
        .Index = 0,
    });
}

test "TestCompletionListInTypeLiteralInTypeParameter13" {
    const content =
        \\// @jsx: preserve
        \\// @filename: a.tsx
        \\interface Foo {
        \\    one: string;
        \\    two: number;
        \\}
        \\
        \\const Component = <T extends Foo>() => <></>;
        \\
        \\<Component<{/*0*/}>></Component>;
        \\<Component<{/*1*/}>/>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "0", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "one",
//                 "two",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "one",
//                 "two",
//             },
//         },
//     });
}

test "TestQuickInfoLink6" {
    const content =
        \\const A = 123;
        \\/**
        \\ *  See {@link A |constant A} instead
        \\ */
        \\const /**/B = 456;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestGoToDefinitionApparentTypeProperties" {
    const content =
        \\interface Number {
        \\    /*definition*/myObjectMethod(): number;
        \\}
        \\
        \\var o = 0;
        \\o.[|/*reference1*/myObjectMethod|]();
        \\o[[|"/*reference2*/myObjectMethod"|]]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "reference1", "reference2");
}

test "TestCompletionListInTypeParameterOfTypeAlias2" {
    const content =
        \\type Map1<K, /*0*/
        \\type Map1<K, /*1*/V> = [];
        \\type Map1<K,V> = /*2*/[];
        \\type Map1<K1, V1> = </*3*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, &.{"0", "1"}, null);
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "K",
//                 "V",
//             },
//         },
//     });
    _ = f.VerifyCompletions(undefined, "3", null);
}

test "TestSyntacticClassifications1" {
    const content =
        \\// comment
        \\namespace M {
        \\    var v = 0 + 1;
        \\    var s = "string";
        \\
        \\    class C<T> {
        \\    }
        \\
        \\    enum E {
        \\    }
        \\
        \\    interface I {
        \\    }
        \\
        \\    namespace M1.M2 {
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "namespace.declaration", .Text = "M"},
//         .{.Type = "variable.declaration.local", .Text = "v"},
//         .{.Type = "variable.declaration.local", .Text = "s"},
//         .{.Type = "class.declaration", .Text = "C"},
//         .{.Type = "typeParameter.declaration", .Text = "T"},
//         .{.Type = "enum.declaration", .Text = "E"},
//         .{.Type = "interface.declaration", .Text = "I"},
//         .{.Type = "namespace.declaration", .Text = "M1"},
//         .{.Type = "namespace.declaration", .Text = "M2"},
//     });
}

test "TestQuickinfo01" {
    const content =
        \\// @lib: es5
        \\interface One {
        \\    commonProperty: number;
        \\    commonFunction(): number;
        \\}
        \\
        \\interface Two {
        \\    commonProperty: string
        \\    commonFunction(): number;
        \\}
        \\
        \\var /*1*/x : One | Two;
        \\
        \\x./*2*/commonProperty;
        \\x./*3*/commonFunction;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    try f.VerifyQuickInfoAt(undefined, "1", "var x: One | Two", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(property) commonProperty: string | number", "");
    try f.VerifyQuickInfoAt(undefined, "3", "(method) commonFunction(): number", "");
}

test "TestCompletionListAfterRegularExpressionLiteral05" {
    const content =
        \\let v = 100;
        \\let x = /absidey/g/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "", null);
}

test "TestJsdocDeprecated_suggestion19" {
    const content =
        \\interface I {
        \\    x: number;
        \\    y: number;
        \\}
        \\interface I {
        \\    /** @deprecated  */
        \\    x: number;
        \\}
        \\const foo: I = { x: 1, y: 1 };
        \\foo.[|x|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySuggestionDiagnostics(undefined, []*.{
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'x' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[0].LSRange,
//         },
//     });
}

test "TestFindAllRefsParameterPropertyDeclaration_inheritance" {
    const content =
        \\class C {
        \\    constructor(public /*0*/x: string) {
        \\        /*1*/x;
        \\    }
        \\}
        \\class D extends C {
        \\    constructor(public /*2*/x: string) {
        \\        super(/*3*/x);
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2", "3");
}

test "TestImportNameCodeFixNewImportNodeModules7" {
    const content =
        \\[|f1/*0*/('');|]
        \\// @Filename: package.json
        \\{ "dependencies": { "package-name": "0.0.1" } }
        \\// @Filename: node_modules/package-name/bin/lib/libfile.d.ts
        \\export declare function f1(text: string): string;
        \\// @Filename: node_modules/package-name/bin/lib/libfile.js
        \\function f1(text) {}
        \\exports.f1 = f1;
        \\// @Filename: node_modules/package-name/package.json
        \\{ "main": "bin/lib/libfile.js" }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from \"package-name\";\n\nf1('');",
    }, null );
}

test "TestGoToImplementationInterface_01" {
    const content =
        \\interface Fo/*interface_definition*/o { hello(): void }
        \\
        \\class [|SuperBar|] implements Foo {
        \\    hello () {}
        \\}
        \\
        \\abstract class [|AbstractBar|] implements Foo {
        \\    abstract hello (): void;
        \\}
        \\
        \\class [|Bar|] extends SuperBar {
        \\}
        \\
        \\class [|NotAbstractBar|] extends AbstractBar {
        \\    hello () {}
        \\}
        \\
        \\var x = new SuperBar();
        \\var y: SuperBar = new SuperBar();
        \\var z: AbstractBar = new NotAbstractBar();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "interface_definition");
}

test "TestQuickInfoMappedType" {
    const content =
        \\interface I {
        \\  /** m documentation */ m(): void;
        \\}
        \\declare const o: { [K in keyof I]: number };
        \\o.m/*0*/;
        \\
        \\declare const p: { [K in keyof I]: I[K] };
        \\p.m/*1*/;
        \\
        \\declare const q: Pick<I, "m">;
        \\q.m/*2*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "0", "(property) m: number", "m documentation");
    try f.VerifyQuickInfoAt(undefined, "1", "(method) m(): void", "m documentation");
    try f.VerifyQuickInfoAt(undefined, "2", "(method) m(): void", "m documentation");
}

test "TestQuickInfoForConstAssertions" {
    const content =
        \\const a = { a: 1 } as /*1*/const;
        \\const b = 1 as /*2*/const;
        \\const c = "c" as /*3*/const;
        \\const d = [1, 2] as /*4*/const;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestPublicBreak" {
    const content =
        \\public break;
        \\/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, " ");
}

test "TestQuickInfoDisplayPartsTypeParameterInFunctionLikeInTypeAlias" {
    const content =
        \\type MixinCtor<A> = new () => /*0*/A & { constructor: MixinCtor</*1*/A> };
        \\type MixinCtor<A> = new () => A & { constructor: { constructor: MixinCtor</*2*/A> } };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestGetEditsForFileRename_unresolvableImport" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "allowJs": true,
        \\    "paths": {
        \\      "*": ["./next/src/*"],
        \\      "@app": ["./modules/@app/*"],
        \\      "@app/*": ["./modules/@app/*"],
        \\      "@local": ["./modules/@local/*"],
        \\      "@local/*": ["./modules/@local/*"]
        \\    }
        \\  }
        \\}
        \\// @Filename: /modules/@app/something/index.js
        \\import "@local/some-other-import";
        \\// @Filename: /modules/@local/index.js
        \\import "@local/some-other-import";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyWillRenameFilesEdits(undefined, "/modules/@app/something", "/modules/@app/something-2", .{}, null );
}

test "TestQuickInfoJsDocTags16" {
    const content =
        \\class A {
        \\    /**
        \\     * Description text here.
        \\     *
        \\     * @virtual
        \\     */
        \\    foo() { }
        \\}
        \\
        \\class B extends A {
        \\    override /*1*/foo() { }
        \\}
        \\
        \\class C extends B {
        \\    override /*2*/foo() { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestMultilineCommentBeforeOpenBrace" {
    const content =
        \\function test() /*1*//* %^ */
        \\{
        \\    if (true) /*2*//* %^ */
        \\    {
        \\    }
        \\}
        \\function a() {
        \\    /* %^ */ }/*3*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "function test() /* %^ */ {");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "    if (true) /* %^ */ {");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "}");
}

test "TestCodeFixMissingTypeAnnotationOnExports14" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\function foo() {
        \\    return { x: 1, y: 1};
        \\}
        \\export const { x, y = 0} = foo(), z= 42;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Extract binding expressions to variable",
        .NewFileContent = "function foo() {\n    return { x: 1, y: 1};\n}\nconst dest = foo();\nexport const x: number = dest.x;\nconst temp = dest.y;\nexport const y: number = temp === undefined ? 0 : dest.y;\nexport const z = 42;",
        .Index = 0,
    });
}

test "TestRenameFromNodeModulesDep4" {
    const content =
        \\// @Filename: /index.ts
        \\import hljs from "highlight.js/lib/core"
        \\import { h } from "highlight.js/lib/core";
        \\import { /*notOk*/h as hh } from "highlight.js/lib/core";
        \\/*ok*/[|hljs|];
        \\/*okWithAlias*/[|h|];
        \\/*ok2*/[|hh|];
        \\// @Filename: /node_modules/highlight.js/lib/core.d.ts
        \\declare const hljs: { registerLanguage(s: string): void };
        \\export default hljs;
        \\export const h: string;
        \\// @Filename: /tsconfig.json
        \\{}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "ok");
    // try f.VerifyRenameSucceeded(undefined, &.{.UseAliasesForRename = core.TSTrue});
    // try f.VerifyRenameSucceeded(undefined, &.{.UseAliasesForRename = core.TSFalse});
    _ = f.GoToMarker(undefined, "ok2");
    // try f.VerifyRenameSucceeded(undefined, &.{.UseAliasesForRename = core.TSTrue});
    // try f.VerifyRenameSucceeded(undefined, &.{.UseAliasesForRename = core.TSFalse});
    _ = f.GoToMarker(undefined, "notOk");
    // try f.VerifyRenameFailed(undefined, &.{.UseAliasesForRename = core.TSTrue});
    // try f.VerifyRenameFailed(undefined, &.{.UseAliasesForRename = core.TSFalse});
    _ = f.GoToMarker(undefined, "okWithAlias");
    // try f.VerifyRenameSucceeded(undefined, &.{.UseAliasesForRename = core.TSTrue});
    // try f.VerifyRenameFailed(undefined, &.{.UseAliasesForRename = core.TSFalse});
}

test "TestModuleNodeNextAutoImport2" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{ "compilerOptions": { "module": "nodenext" } }
        \\// @Filename: /package.json
        \\{ "type": "module" }
        \\// @Filename: /mobx.d.cts
        \\export declare function autorun(): void;
        \\// @Filename: /index.ts
        \\autorun/**/
        \\// @Filename: /utils.ts
        \\import "./mobx.cjs";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { autorun } from \"./mobx.cjs\";\n\nautorun",
    }, null );
}

test "TestOutliningSpansForArrowFunctionBody" {
    const content =
        \\() => 42;
        \\() => ( 42 );
        \\() =>[| {
        \\    42
        \\}|];
        \\() => [|(
        \\    42
        \\)|];
        \\() =>[| "foo" +
        \\    "bar" +
        \\    "baz"|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOutliningSpans(undefined);
}

test "TestCodeFixAddMissingMember21" {
    const content =
        \\declare let p: Promise<string>;
        \\async function f() {
        \\    p.toLowerCase();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined, "fixMissingMember");
}

test "TestGoToSource18_reusedFromDifferentFolder" {
    const content =
        \\// @lib: es5
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/yargs/package.json
        \\{
        \\    "name": "@types/yargs",
        \\    "version": "1.0.0",
        \\    "types": "./index.d.ts"
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/yargs/callback.d.ts
        \\export declare class Yargs { positional(): Yargs; }
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/yargs/index.d.ts
        \\import { Yargs } from "./callback";
        \\export declare function command(command: string, cb: (yargs: Yargs) => void): void;
        \\// @Filename: /home/src/workspaces/project/node_modules/yargs/package.json
        \\{
        \\    "name": "yargs",
        \\    "version": "1.0.0",
        \\    "main": "index.js"
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/yargs/callback.js
        \\export class Yargs { positional() { } }
        \\// @Filename: /home/src/workspaces/project/node_modules/yargs/index.js
        \\// Specifically didnt have ./callback import to ensure that resolving module sepcifier adds the file to project at later stage
        \\export function command(cmd, cb) { cb(Yargs) }
        \\// @Filename: /home/src/workspaces/project/folder/random.ts
        \\import { Yargs } from "yargs/callback";
        \\// @Filename: /home/src/workspaces/project/some/index.ts
        \\import { random } from "../folder/random";
        \\import { command } from "yargs";
        \\command("foo", yargs => {
        \\    yargs.[|/*start*/positional|]();
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineGoToSourceDefinition(undefined, "start");
}

test "TestTsxCompletion14" {
    const content =
        \\//@module: commonjs
        \\//@jsx: preserve
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\    }
        \\    interface ElementAttributesProperty { props; }
        \\}
        \\//@Filename: exporter.tsx
        \\export class Thing { props: { ONE: string; TWO: number } }
        \\export namespace M {
        \\   export declare function SFCComp(props: { Three: number; Four: string }): JSX.Element;
        \\}
        \\//@Filename: file.tsx
        \\import * as Exp from './exporter';
        \\var x1 = <Exp.Thing /*1*/ />;
        \\var x2 = <Exp.M.SFCComp /*2*/ />;
        \\var x3 = <Exp.Thing /*3*/ ></Exp.Thing>;
        \\var x4 = <Exp.M.SFCComp /*4*/ ></Exp.M.SFCComp>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "3"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "ONE",
//                 "TWO",
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
//                 "Four",
//                 "Three",
//             },
//         },
//     });
}

test "TestImportNameCodeFixShebang" {
    const content =
        \\// @Filename: /a.ts
        \\export const foo = 0;
        \\// @Filename: /b.ts
        \\[|#!/usr/bin/env node
        \\foo/**/|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.ts");
    _ = f.GoToFile(undefined, "/b.ts");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "#!/usr/bin/env node\n\nimport { foo } from \"./a\";\n\nfoo",
    }, null );
}

test "TestIndirectClassInstantiation" {
    const content =
        \\// @allowJs: true
        \\// @Filename: something.js
        \\function TestObj(){
        \\    this.property = "value";
        \\}
        \\var constructor = TestObj;
        \\var instance = new constructor();
        \\instance./*a*/
        \\var class2 = function() { };
        \\class2.prototype.blah = function() { };
        \\var inst2 = new class2();
        \\inst2.blah/*b*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "a");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "property",
//                 &.{
//                     .Label =    "blah",
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//                 &.{
//                     .Label =    "class2",
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//                 &.{
//                     .Label =    "constructor",
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//                 &.{
//                     .Label =    "inst2",
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//                 &.{
//                     .Label =    "instance",
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//                 &.{
//                     .Label =    "prototype",
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//                 &.{
//                     .Label =    "TestObj",
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//             },
//         },
//     });
    _ = f.Backspace(undefined, 1);
    _ = f.GoToMarker(undefined, "b");
    try f.VerifyQuickInfoIs(undefined, "(method) class2.blah(): void", "");
}

test "TestFormatSimulatingScriptBlocks" {
    const content =
        \\/* BEGIN EXTERNAL SOURCE */
        \\/*begin5*/
        \\                        var a = 1;
        \\                        alert("/*end5*//********//*begin4*/");
        \\                    /*end4*/
        \\/* END EXTERNAL SOURCE */
        \\
        \\/* BEGIN EXTERNAL SOURCE */
        \\/*begin3*/
        \\                            var b = 1;
        \\
        \\                        var c = "/*end3*//********//*begin2*/";
        \\       var d = 1;
        \\
        \\            var e = "/*end2*//********//*begin1*/";
        \\            var f = 1;
        \\        /*end1*/
        \\/* END EXTERNAL SOURCE */
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts640);
    _ = f.FormatSelection(undefined, "begin1", "end1");
    _ = f.FormatSelection(undefined, "begin2", "end2");
    _ = f.FormatSelection(undefined, "begin3", "end3");
    // f.GetOptions();
    // f.Configure(undefined, opts794);
    _ = f.FormatSelection(undefined, "begin4", "end4");
    _ = f.FormatSelection(undefined, "begin5", "end5");
    try f.VerifyCurrentFileContent(undefined, "/* BEGIN EXTERNAL SOURCE */\n\n                        var a = 1;\n                        alert(\"/********/\");\n\n/* END EXTERNAL SOURCE */\n\n/* BEGIN EXTERNAL SOURCE */\n\n            var b = 1;\n\n            var c = \"/********/\";\n            var d = 1;\n\n            var e = \"/********/\";\n            var f = 1;\n\n/* END EXTERNAL SOURCE */");
}

test "TestCompletionListInUnclosedFunction15" {
    const content =
        \\interface MyType {
        \\}
        \\
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string = "hello", c: typeof x = "hello") {
        \\        var v = (p: MyType) => /*1*/
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
//             .Includes = &.{
//                 "foo",
//                 "x",
//                 "y",
//                 "z",
//                 "bar",
//                 "a",
//                 "b",
//                 "c",
//                 "v",
//                 "p",
//             },
//         },
//     });
}

test "TestSignatureHelpTypeParametersNotVariadic" {
    const content =
        \\declare function f(a: any, ...b: any[]): any;
        \\f</*1*/>(1, 2);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.IsVariadic = false, .IsVariadicSet = true});
}

test "TestImportNameCodeFix_HeaderComment2" {
    const content =
        \\// @Filename: /a.ts
        \\export const foo = 0;
        \\// @Filename: /b.ts
        \\export const bar = 0;
        \\// @Filename: /c.ts
        \\/*--------------------
        \\ *  Copyright Header
        \\ *--------------------*/
        \\
        \\const afterHeader = 1;
        \\
        \\// non-header comment
        \\import { bar } from "./b";
        \\foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/c.ts");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "/*--------------------\n *  Copyright Header\n *--------------------*/\n\nconst afterHeader = 1;\n\nimport { foo } from \"./a\";\n// non-header comment\nimport { bar } from \"./b\";\nfoo;",
    }, null );
}

test "TestCodeFixClassImplementInterfaceMultipleImplements2" {
    const content =
        \\// @strict: false
        \\interface I1 {
        \\    x: number;
        \\}
        \\interface I2 {
        \\    y: "𣋝ઢȴ¬⏊";
        \\}
        \\
        \\class C implements I1,I2 {[|
        \\    |]x: number;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "\ny: \"𣋝ઢȴ¬⏊\";\n", false, 0, 0);
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestCompletionsOptionalKindModifier" {
    const content =
        \\interface A { a?: number; method?(): number; };
        \\function f(x: A) {
        \\x./*a*/;
        \\}
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
//                 &.{
//                     .Label =      "a?",
//                     .InsertText = undefined("a"),
//                     .FilterText = undefined("a"),
//                     .Kind =       undefined(lsproto.CompletionItemKindField),
//                 },
//                 &.{
//                     .Label =      "method?",
//                     .InsertText = undefined("method"),
//                     .FilterText = undefined("method"),
//                     .Kind =       undefined(lsproto.CompletionItemKindMethod),
//                 },
//             },
//         },
//     });
}

test "TestNavigationBarItemsExports" {
    const content =
        \\export { a } from "a";
        \\
        \\export { b as B } from "a" 
        \\
        \\export import e = require("a");
        \\
        \\export * from "a"; // no bindings here
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestJsDocPropertyDescription8" {
    const content =
        \\class SymbolClass {
        \\    /** Something generic */
        \\    static [p: symbol]: any;
        \\}
        \\function symbolClass(e: typeof SymbolClass) {
        \\    console.log(e./*symbolClass*/anything);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "symbolClass", "any", "");
}

test "TestQuickInfoForGenericConstraints1" {
    const content =
        \\function foo4<T extends Date>(te/**/st: T): T;
        \\function foo4<T extends Date>(test: any): any { return null; }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "(parameter) test: T extends Date", "");
}

test "TestFormattingOnDoWhileNoSemicolon" {
    const content =
        \\/*2*/do {
        \\/*3*/    for (var i = 0; i < 10; i++)
        \\/*4*/        i -= 2
        \\/*5*/        }/*1*/while (1 !== 1)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "\n");
    try f.VerifyCurrentLineContent(undefined, "while (1 !== 1)");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "do {");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "    for (var i = 0; i < 10; i++)");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "        i -= 2");
    _ = f.GoToMarker(undefined, "5");
    try f.VerifyCurrentLineContent(undefined, "}");
}

test "TestSignatureHelpOnTypePredicates" {
    const content =
        \\function f1(a: any): a is number {}
        \\function f2<T>(a: any): a is T {}
        \\function f3(a: any, ...b): a is number {}
        \\f1(/*1*/)
        \\f2(/*2*/)
        \\f3(/*3*/)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "f1(a: any): a is number"});
    _ = f.GoToMarker(undefined, "2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "f2(a: any): a is unknown"});
    _ = f.GoToMarker(undefined, "3");
    // try f.VerifySignatureHelp(undefined, .{.Text = "f3(a: any, ...b: any[]): a is number", .IsVariadic = true, .IsVariadicSet = true});
}

test "TestCompletionForStringLiteralNonrelativeImport17" {
    const content =
        \\// @Filename: tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "paths": {
        \\            "module1/*": ["some/path/*"],
        \\        }
        \\    }
        \\}
        \\// @Filename: test0.ts
        \\import * as foo1 from "module1/w/*first*/
        \\// @Filename: some/path/whatever.ts
        \\export {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"first"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "whatever",
//             },
//         },
//     });
}

test "TestCodeFixClassImplementInterfacePropertySignatures" {
    const content =
        \\interface I {
        \\    a0: {};
        \\    a1: { (b1: number, c1: string): number; };
        \\    a2: (b2: number, c2: string) => number;
        \\    a3: { (b3: number, c3: string): number, x: number };
        \\
        \\    a4: { new (b1: number, c1: string): number; };
        \\    a5: new (b2: number, c2: string) => number;
        \\    a6: { new (b3: number, c3: string): number, x: number };
        \\
        \\    a7: { foo(b7: number, c7: string): number };
        \\
        \\    a8: { (b81: number, c81: string): number, new (b82: number, c82: string): number; };
        \\
        \\    a9: { (b9: number, c9: string): number; [d9: number]: I };
        \\    a10: { (b10: number, c10: string): number; [d10: string]: I };
        \\}
        \\class C implements I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFix(undefined, .{
//         .Description = "Implement interface 'I'",
//         .NewFileContent = "interface I {\n    a0: {};\n    a1: { (b1: number, c1: string): number; };\n    a2: (b2: number, c2: string) => number;\n    a3: { (b3: number, c3: string): number, x: number };\n\n    a4: { new (b1: number, c1: string): number; };\n    a5: new (b2: number, c2: string) => number;\n    a6: { new (b3: number, c3: string): number, x: number };\n\n    a7: { foo(b7: number, c7: string): number };\n\n    a8: { (b81: number, c81: string): number, new (b82: number, c82: string): number; };\n\n    a9: { (b9: number, c9: string): number; [d9: number]: I };\n    a10: { (b10: number, c10: string): number; [d10: string]: I };\n}\nclass C implements I {\n    a0: {};\n    a1: (b1: number, c1: string) => number;\n    a2: (b2: number, c2: string) => number;\n    a3: { (b3: number, c3: string): number; x: number; };\n    a4: new (b1: number, c1: string) => number;\n    a5: new (b2: number, c2: string) => number;\n    a6: { new(b3: number, c3: string): number; x: number; };\n    a7: { foo(b7: number, c7: string): number; };\n    a8: { (b81: number, c81: string): number; new(b82: number, c82: string): number; };\n    a9: { (b9: number, c9: string): number;[d9: number]: I; };\n    a10: { (b10: number, c10: string): number;[d10: string]: I; };\n}",
//         .Index = 0,
//     });
}

test "TestTsxRename3" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\    }
        \\    interface ElementAttributesProperty { props }
        \\}
        \\class MyClass {
        \\  props: {
        \\    [|[|{| "contextRangeIndex": 0 |}name|]?: string;|]
        \\    size?: number;
        \\}
        \\
        \\
        \\var x = <MyClass [|[|{| "contextRangeIndex": 2 |}name|]='hello'|]/>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "name");
}

test "TestReferencesForInheritedProperties9" {
    const content =
        \\class D extends C {
        \\    /*1*/prop1: string;
        \\}
        \\
        \\class C extends D {
        \\    /*2*/prop1: string;
        \\}
        \\
        \\var c: C;
        \\c./*3*/prop1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestAutoImportFileExcludePatterns4" {
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
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'Parts'",
        .NewFileContent = "import { Event } from '../event/event';\nimport { Parts } from './parts';\nexport class EditorParts implements Parts {\n    options: Event;\n}",
        .Index =           0,
        .UserPreferences = &.{.AutoImportFileExcludePatterns = &.{"src/vs/workbench/workbench.ts"}},
    });
}

test "TestGoToDefinitionSwitchCase7" {
    const content =
        \\switch (null) {
        \\  case null:
        \\    export [|/*start*/default|] 123;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "start");
}

test "TestCompletionForStringLiteral4" {
    const content =
        \\// @allowJs: true
        \\// @Filename: in.js
        \\/** I am documentation
        \\ * @param {'literal'} p1
        \\ * @param {"literal"} p2
        \\ * @param {'other1' | 'other2'} p3
        \\ * @param {'literal' | number} p4
        \\ * @param {12 | true} p5
        \\ */
        \\function f(p1, p2, p3, p4, p5) {
        \\    return p1 + p2 + p3 + p4 + p5 + '.';
        \\}
        \\f/*1*/('literal', 'literal', "[|o/*2*/ther1|]", 12);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyQuickInfoExists(undefined);
    try f.VerifyQuickInfoIs(undefined, "function f(p1: \"literal\", p2: \"literal\", p3: \"other1\" | \"other2\", p4: \"literal\" | number, p5: 12 | true): string", "I am documentation");
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "other1",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "other1",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "other2",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "other2",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestAutoImportCrossProject_baseUrl_toDist" {
    const content =
        \\// @Filename: /home/src/workspaces/project/common/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "lib": ["es5"],
        \\    "module": "commonjs",
        \\    "outDir": "dist",
        \\    "composite": true
        \\  },
        \\  "include": ["src"]
        \\}
        \\// @Filename: /home/src/workspaces/project/common/src/MyModule.ts
        \\export function square(n: number) {
        \\  return n * 2;
        \\}
        \\// @Filename: /home/src/workspaces/project/web/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "lib": ["es5"],
        \\    "module": "esnext",
        \\    "moduleResolution": "node",
        \\    "noEmit": true,
        \\    "baseUrl": "."
        \\  },
        \\  "include": ["src"],
        \\  "references": [{ "path": "../common" }]
        \\}
        \\// @Filename: /home/src/workspaces/project/web/src/MyApp.ts
        \\import { square } from "../../common/dist/src/MyModule";
        \\// @Filename: /home/src/workspaces/project/web/src/Helper.ts
        \\export function saveMe() {
        \\  square/**/(2);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToFile(undefined, "/home/src/workspaces/project/web/src/Helper.ts");
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"../../common/src/MyModule"}, &.{.ImportModuleSpecifierPreference = "non-relative"});
}

test "TestGoToDefinitionExpandoClass1" {
    const content =
        \\// @strict: true
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @filename: index.js
        \\const Core = {}
        \\
        \\Core.Test = class { }
        \\
        \\Core.Test.prototype.foo = 10
        \\
        \\new Core.Tes/*1*/t()
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestSemanticClassification1" {
    const content =
        \\module /*0*/M {
        \\    export interface /*1*/I {
        \\    }
        \\}
        \\interface /*2*/X extends /*3*/M./*4*/I { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "namespace.declaration", .Text = "M"},
//         .{.Type = "interface.declaration", .Text = "I"},
//         .{.Type = "interface.declaration", .Text = "X"},
//         .{.Type = "namespace", .Text = "M"},
//         .{.Type = "interface", .Text = "I"},
//     });
}

test "TestAutoImportPackageRootPath" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /node_modules/pkg/package.json
        \\{
        \\    "name": "pkg",
        \\    "version": "1.0.0",
        \\    "main": "lib",
        \\    "module": "lib"
        \\ }
        \\// @Filename: /node_modules/pkg/lib/index.js
        \\export function foo() {};
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
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"pkg"}, null );
}

test "TestCompletionBeforeSemanticDiagnosticsInArrowFunction1" {
    const content =
        \\var f4 = <T>(x: T/**/ ) => {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Backspace(undefined, 1);
    _ = f.Insert(undefined, "A");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "T",
//                     .Detail = undefined("(type parameter) T in <T>(x: A): void"),
//                 },
//             },
//         },
//     });
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestCodeFixMissingTypeAnnotationOnExports47" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @moduleResolution: bundler
        \\// @target: es2018
        \\// @jsx: react-jsx
        \\// @filename: node_modules/react/package.json
        \\{
        \\    "name": "react",
        \\    "types": "index.d.ts"
        \\}
        \\// @filename: node_modules/react/index.d.ts
        \\export = React;
        \\declare namespace JSX {
        \\    interface Element extends GlobalJSXElement { }
        \\    interface IntrinsicElements extends GlobalJSXIntrinsicElements { }
        \\}
        \\declare namespace React { }
        \\declare global {
        \\    namespace JSX {
        \\        interface Element { }
        \\        interface IntrinsicElements { [x: string]: any; }
        \\    }
        \\}
        \\interface GlobalJSXElement extends JSX.Element {}
        \\interface GlobalJSXIntrinsicElements extends JSX.IntrinsicElements {}
        \\// @filename: node_modules/react/jsx-runtime.d.ts
        \\import './';
        \\// @filename: node_modules/react/jsx-dev-runtime.d.ts
        \\import './';
        \\// @filename: /a.tsx
        \\export const x = <div aria-label="label text" />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.tsx");
    try f.VerifyCodeFix(undefined, .{
        .Description =    "Add annotation of type 'JSX.Element'",
        .NewFileContent = "export const x: JSX.Element = <div aria-label=\"label text\" />;",
        .Index =          0,
    });
}

test "TestCodeFixTopLevelForAwait_module_missingCompilerOptionsInTsConfig" {
    const content =
        \\// @filename: /dir/a.ts
        \\declare const p: number[];
        \\for await (const _ of p);
        \\export {};
        \\// @filename: /dir/tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "module": "commonjs"
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined, "fixModuleOption");
}

test "TestCompletionForStringLiteral_quotePreference5" {
    const content =
        \\type T = "0" | "1";
        \\const t: T = /**/
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
//                     .Label = "'1'",
//                 },
//                 &.{
//                     .Label = "'0'",
//                 },
//             },
//         },
//         .UserPreferences = &.{.QuotePreference = lsutil.QuotePreference("single")},
//     });
}

test "TestCompletionListNewIdentifierBindingElement" {
    const content =
        \\var { x:html/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "1", null);
}

test "TestJsdocSatisfiesTagFindAllReferences" {
    const content =
        \\// @noEmit: true
        \\// @allowJS: true
        \\// @checkJs: true
        \\// @filename: /a.js
        \\/**
        \\ * @typedef {Object} T
        \\ * @property {number} a
        \\ */
        \\
        \\/** @satisfies {/**/T} comment */
        \\const foo = { a: 1 };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestCompletionsImport_default_fromMergedDeclarations" {
    const content =
        \\// @module: esnext
        \\// @Filename: /a.ts
        \\declare module "m" {
        \\    export default class M {}
        \\}
        \\// @Filename: /b.ts
        \\declare module "m" {
        \\    export default interface M {}
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
//                     .Detail =              undefined("class M"),
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
//         .NewFileContent = undefined("import M from \"m\";\n\n"),
//     });
}

test "TestReferencesForMergedDeclarations8" {
    const content =
        \\interface Foo { }
        \\namespace Foo {
        \\    export interface Bar { }
        \\    /*1*/export module /*2*/Bar { export interface Baz { } }
        \\    export function Bar() { }
        \\}
        \\
        \\// module
        \\import a3 = Foo./*3*/Bar.Baz;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestRenameDestructuringAssignmentNestedInForOf2" {
    const content =
        \\interface MultiRobot {
        \\    name: string;
        \\    skills: {
        \\        [|[|{| "contextRangeIndex": 0 |}primary|]: string;|]
        \\        secondary: string;
        \\    };
        \\}
        \\let multiRobots: MultiRobot[], [|[|{| "contextRangeIndex": 2 |}primary|]: string|];
        \\for ([|{ skills: { [|{| "contextRangeIndex": 4 |}primary|]: primaryA, secondary: secondaryA } } of multiRobots|]) {
        \\    console.log(primaryA);
        \\}
        \\for ([|{ skills: { [|{| "contextRangeIndex": 6 |}primary|], secondary } } of multiRobots|]) {
        \\    console.log([|primary|]);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[5], f.Ranges()[3], f.Ranges()[7], f.Ranges()[8]);
}

test "TestJsObjectDefinePropertyRenameLocations" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @noEmit: true
        \\// @Filename: index.js
        \\var CircularList = (function () {
        \\    var CircularList = function() {};
        \\    Object.defineProperty(CircularList.prototype, "[|maxLength|]", { value: 0, writable: true });
        \\    CircularList.prototype.push = function (value) {
        \\        // ...
        \\        this.[|maxLength|] + this.[|maxLength|]
        \\    }
        \\    return CircularList;
        \\})()
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null );
}

test "TestTransitiveExportImports3" {
    const content =
        \\// @Filename: a.ts
        \\[|export function /*f*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 0 |}f|]() {}|]
        \\// @Filename: b.ts
        \\[|export { [|{| "contextRangeIndex": 2 |}f|] as /*g0*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 2 |}g|] } from "./a";|]
        \\[|import { /*f2*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 5 |}f|] } from "./a";|]
        \\[|import { /*g1*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 7 |}g|] } from "./b";|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    // try f.VerifyBaselineFindAllReferences(undefined, "f", "g0", "g1", "f2");
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[3]);
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[6]);
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[4]);
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[8]);
}

test "TestInlayHintsInferredTypePredicate1" {
    const content =
        \\// @strict: true
        \\function test(x: unknown) {
        \\  return typeof x === 'number';
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayFunctionLikeReturnTypeHints = core.TSTrue}});
}

test "TestExportEqualCallableInterface" {
    const content =
        \\// @lib: es5
        \\// @Filename: exportEqualCallableInterface_file0.ts
        \\interface x {
        \\    (): Date;
        \\    foo: string;
        \\}
        \\export = x;
        \\// @Filename: exportEqualCallableInterface_file1.ts
        \\///<reference path='exportEqualCallableInterface_file0.ts'/>
        \\import test = require('./exportEqualCallableInterface_file0');
        \\var t2: test;
        \\t2./**/
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
//             .Exact = CompletionFunctionMembersWithPrototypePlus(
//                 &.{
//                     "foo",
//                 },
//             ),
//         },
//     });
}

test "TestCodeFixMissingTypeAnnotationOnExports5" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\const a = 42;
        \\const b = 42;
        \\export class C {
        \\  get property() { return a + b; }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFixAvailable(undefined, &.{"Add return type 'number'"});
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add return type 'number'",
        .NewFileContent = "const a = 42;\nconst b = 42;\nexport class C {\n  get property(): number { return a + b; }\n}",
        .Index = 0,
    });
}

test "TestQuickInfoEnumMembersAcceptNonAsciiStrings" {
    const content =
        \\enum Demo {
        \\    /*Emoji*/Emoji = '🍎',
        \\    /*Hebrew*/Hebrew = 'תפוח',
        \\    /*Chinese*/Chinese = '苹果',
        \\    /*Japanese*/Japanese = 'りんご',
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "Emoji", "(enum member) Demo.Emoji = \"🍎\"", "");
    try f.VerifyQuickInfoAt(undefined, "Hebrew", "(enum member) Demo.Hebrew = \"תפוח\"", "");
    try f.VerifyQuickInfoAt(undefined, "Chinese", "(enum member) Demo.Chinese = \"苹果\"", "");
    try f.VerifyQuickInfoAt(undefined, "Japanese", "(enum member) Demo.Japanese = \"りんご\"", "");
}

test "TestGetEditsForFileRename_amd" {
    const content =
        \\// @moduleResolution: classic
        \\// @Filename: /src/user.ts
        \\import { x } from "old";
        \\// @Filename: /src/old.ts
        \\export const x = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyWillRenameFilesEdits(undefined, "/src/old.ts", "/src/new.ts", .{
//         .@"/src/user.ts" = "import { x } from \"./new\";",
//     }, null );
}

test "TestSignatureHelpWithUnknown" {
    const content =
        \\eval(\/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSignatureHelp(undefined);
}

test "TestQuickfixImplementInterfaceUnreachableTypeUsesRelativeImport" {
    const content =
        \\// @Filename: class.ts
        \\export class Class { }
        \\// @Filename: interface.ts
        \\import { Class } from './class';
        \\
        \\export interface Foo {
        \\    x: Class;
        \\}
        \\// @Filename: index.ts
        \\import { Foo } from './interface';
        \\
        \\class /*1*/X implements Foo {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCodeFix(undefined, .{
        .Description =    "Implement interface 'Foo'",
        .NewFileContent = "",
        .Index =          0,
    });
}

test "TestRenameInheritedProperties8" {
    const content =
        \\class C implements D {
        \\    [|[|{| "contextRangeIndex": 0 |}prop1|]: string;|]
        \\}
        \\
        \\interface D extends C {
        \\    [|[|{| "contextRangeIndex": 2 |}prop1|]: string;|]
        \\}
        \\
        \\var c: C;
        \\c.[|prop1|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "prop1");
}

test "TestGetOccurrencesSwitchCaseDefault3" {
    const content =
        \\foo: [|switch|] (1) {
        \\    [|case|] 1:
        \\    [|case|] 2:
        \\        [|break|];
        \\    [|case|] 3:
        \\        switch (2) {
        \\            case 1:
        \\                [|break|] foo;
        \\                continue; // invalid
        \\            default:
        \\                break;
        \\        }
        \\    [|default|]:
        \\        [|break|];
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestSuperInDerivedTypeOfGenericWithStatics" {
    const content =
        \\// @strict: false
        \\namespace M {
        \\   export class C<T extends Date> {
        \\      static foo(): C<Date> {
        \\          return null;
        \\           }
        \\     }
        \\}
        \\class D extends M.C<Date> {
        \\    constructor() {
        \\        /**/ // was an error appearing on super in editing scenarios
        \\       }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "super();");
    try f.VerifyNoErrors(undefined);
}

test "TestQuickInfoContextuallyTypedSignatureOptionalParameterFromIntersection1" {
    const content =
        \\// @strict: true
        \\const optionals: ((a?: number) => unknown) & ((b?: string) => unknown) = (
        \\  arg,
        \\) =/**/> {};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "function(arg: string | number | undefined): void", "");
}

test "TestCompletionsJSDocNoCrash1" {
    const content =
        \\// @strict: true
        \\// @checkJs: true
        \\// @allowJs: true
        \\// @filename: index.js
        \\/**
        \\ * @example
        \\  <file name="glyphicons.css">
        \\    @import url(//netdna.bootstrapcdn.com/bootstrap/3.0.0/css/bootstrap-glyphicons.css);
        \\  </file>
        \\  <example module="ngAnimate" deps="angular-animate.js" animations="true">
        \\    <file name="animations.css">
        \\      .animate-show.ng-hide-add.ng-hide-add-active,
        \\      .animate-show.ng-hide-remove.ng-hide-remove-active {
        \\        transition:all linear 0./**/5s;
        \\      }
        \\    </file>
        \\  </example>
        \\ */
        \\var ngShowDirective = ['$animate', function($animate) {}];
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
//                 "url",
//             },
//         },
//     });
}

test "TestCodeFixInferFromFunctionThisUsageObjectPropertyShorthand" {
    const content =
        \\// @noImplicitThis: true
        \\function returnThisMember([| |]) {
        \\     return this.member;
        \\ }
        \\
        \\ interface Container {
        \\     member: string;
        \\     returnThisMember(): string;
        \\ }
        \\
        \\ const container: Container = {
        \\     member: "sample",
        \\     returnThisMember,
        \\ };
        \\
        \\ container.returnThisMember();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "this: Container", false, 0, 0);
}

test "TestNumericPropertyNames" {
    const content =
        \\var /**/t2 = { 0: 1, 1: "" };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "var t2: {\n    0: number;\n    1: string;\n}", "");
}

test "TestInlayHintsInteractiveRestParameters2" {
    const content =
        \\function foo(a: unknown, b: unknown, c: unknown) { }
        \\function foo1(...x: [number, number | undefined]) {
        \\    foo(...x, 3);
        \\}
        \\function foo2(...x: []) {
        \\    foo(...x, 1, 2, 3);
        \\}
        \\function foo3(...x: [number, number?]) {
        \\    foo(1, ...x);
        \\}
        \\function foo4(...x: [number, number?]) {
        \\    foo(...x, 3);
        \\}
        \\function foo5(...x: [number, number]) {
        \\    foo(...x, 3);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayParameterNameHints = lsutil.IncludeInlayParameterNameHintsAll}});
}

test "TestWhiteSpaceTrimming2" {
    const content =
        \\let noSubTemplate = 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "\n");
    _ = f.GoToMarker(undefined, "2");
    _ = f.Insert(undefined, "\n");
    _ = f.GoToMarker(undefined, "3");
    _ = f.Insert(undefined, "\n");
    _ = f.GoToMarker(undefined, "4");
    _ = f.Insert(undefined, "\n");
    try f.VerifyCurrentFileContent(undefined, "let noSubTemplate = `/*    \n`;\nlet templateHead = `/*    \n${1 + 2}`;\nlet templateMiddle = `/*    ${1 + 2\n    }`;\nlet templateTail = `/*    ${1 + 2}    \n`;");
}

test "TestDocumentHighlightDefaultInSwitch" {
    const content =
        \\const foo = 'foo';
        \\[|switch|] (foo) {
        \\   [|case|] 'foo':
        \\       [|break|];
        \\   [|default|]:
        \\       [|break|];
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , f.Ranges()[1], f.Ranges()[4]);
}

test "TestNavigationBarItemsBindingPatterns" {
    const content =
        \\'use strict'
        \\var foo, {}
        \\var bar, []
        \\let foo1, {a, b}
        \\const bar1, [c, d]
        \\var {e, x: [f, g]} = {a:1, x:[]};
        \\var { h: i = function j() {} } = obj;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestFindAllRefsParameterPropertyDeclaration2" {
    const content =
        \\class Foo {
        \\    constructor(public /*0*/publicParam: number) {
        \\        let localPublic = /*1*/publicParam;
        \\        this./*2*/publicParam += 10;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2");
}

test "TestCompletionsForStringDependingOnContexSensitiveSignature" {
    const content =
        \\// @strict: true
        \\
        \\type ActorRef<TEvent extends { type: string }> = {
        \\  send: (ev: TEvent) => void
        \\}
        \\
        \\type Action<TContext> = {
        \\  (ctx: TContext): void
        \\}
        \\
        \\type Config<TContext> = {
        \\  entry: Action<TContext>
        \\}
        \\
        \\declare function createMachine<TContext>(config: Config<TContext>): void
        \\
        \\type EventFrom<T> = T extends ActorRef<infer TEvent> ? TEvent : never
        \\
        \\declare function sendTo<
        \\  TContext,
        \\  TActor extends ActorRef<any>
        \\>(
        \\  actor: ((ctx: TContext) => TActor),
        \\  event: EventFrom<TActor>
        \\): Action<TContext>
        \\
        \\createMachine<{
        \\  child: ActorRef<{ type: "EVENT" }>;
        \\}>({
        \\  entry: sendTo((ctx) => ctx.child, { type: /*1*/ }),
        \\});
        \\
        \\createMachine<{
        \\  child: ActorRef<{ type: "EVENT" }>;
        \\}>({
        \\  entry: sendTo((ctx) => ctx.child, { type: "/*2*/" }),
        \\});
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
//             .Includes = &.{
//                 "\"EVENT\"",
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
//                 "EVENT",
//             },
//         },
//     });
}

test "TestFormattingSpaceBetweenParent" {
    const content =
        \\/*1*/foo(() => 1);
        \\/*2*/foo(1);
        \\/*3*/if((true)){}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts180);
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "foo( () => 1 );");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "foo( 1 );");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "if ( ( true ) ) { }");
}

test "TestImportNameCodeFix_jsCJSvsESM2" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: types/dep.d.ts
        \\export declare class Dep {}
        \\// @Filename: index.js
        \\Dep/**/
        \\// @Filename: util1.ts
        \\import fs from 'fs';
        \\// @Filename: util2.js
        \\const fs = require('fs');
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "const { Dep } = require(\"./types/dep\");\n\nDep",
    }, null );
}

test "TestArgumentsIndexExpression" {
    const content =
        \\function f() {
        \\    var x = /**/arguments[0];
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyQuickInfoExists(undefined);
}

test "TestSemanticModernClassificationClassProperties" {
    const content =
        \\class A { 
        \\  private y: number;
        \\  constructor(public x : number, _y : number) { this.y = _y; }
        \\  get z() : number { return this.x + this.y; }
        \\  set a(v: number) { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "class.declaration", .Text = "A"},
//         .{.Type = "property.declaration", .Text = "y"},
//         .{.Type = "parameter.declaration", .Text = "x"},
//         .{.Type = "parameter.declaration", .Text = "_y"},
//         .{.Type = "property", .Text = "y"},
//         .{.Type = "parameter", .Text = "_y"},
//         .{.Type = "property.declaration", .Text = "z"},
//         .{.Type = "property", .Text = "x"},
//         .{.Type = "property", .Text = "y"},
//         .{.Type = "property.declaration", .Text = "a"},
//         .{.Type = "parameter.declaration", .Text = "v"},
//     });
}

test "TestGoToDefinitionDecoratorOverloads" {
    const content =
        \\// @Target: ES6
        \\// @experimentaldecorators: true
        \\async function f() {}
        \\
        \\function /*defDecString*/dec(target: any, propertyKey: string): void;
        \\function /*defDecSymbol*/dec(target: any, propertyKey: symbol): void;
        \\function dec(target: any, propertyKey: string | symbol) {}
        \\
        \\declare const s: symbol;
        \\class C {
        \\    @[|/*useDecString*/dec|] f() {}
        \\    @[|/*useDecSymbol*/dec|] [s]() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "useDecString", "useDecSymbol");
}

test "TestReferencesForContextuallyTypedObjectLiteralProperties" {
    const content =
        \\interface IFoo { /*xy*/xy: number; }
        \\
        \\// Assignment
        \\var a1: IFoo = { xy: 0 };
        \\var a2: IFoo = { xy: 0 };
        \\
        \\// Function call
        \\function consumer(f: IFoo) { }
        \\consumer({ xy: 1 });
        \\
        \\// Type cast
        \\var c = <IFoo>{ xy: 0 };
        \\
        \\// Array literal
        \\var ar: IFoo[] = [{ xy: 1 }, { xy: 2 }];
        \\
        \\// Nested object literal
        \\var ob: { ifoo: IFoo } = { ifoo: { xy: 0 } };
        \\
        \\// Widened type
        \\var w: IFoo = { xy: undefined };
        \\
        \\// Untped -- should not be included
        \\var u = { xy: 0 };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "xy");
}

test "TestImportNameCodeFix_jsx3" {
    const content =
        \\// @lib: es5
        \\// @jsx: react
        \\// @module: esnext
        \\// @esModuleInterop: true
        \\// @moduleResolution: bundler
        \\// @Filename: /node_modules/react/index.d.ts
        \\export = React;
        \\export as namespace React;
        \\declare namespace React {
        \\    class Component {}
        \\}
        \\// @Filename: /node_modules/react-native/index.d.ts
        \\import * as React from "react";
        \\export class Text extends React.Component {};
        \\// @Filename: /a.tsx
        \\import React from "react";
        \\<Text></[|Text|]>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.tsx");
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add import from \"react-native\"",
        .NewFileContent = "import React from \"react\";\nimport { Text } from \"react-native\";\n<Text></Text>;",
        .Index = 0,
    });
}

test "TestCompletionListAtIdentifierDefinitionLocations_Generics" {
    const content =
        \\interface A</*genericName1*/
        \\class A</*genericName2*/
        \\class B<T, /*genericName3*/
        \\class A{
        \\     f</*genericName4*/
        \\function A</*genericName5*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, f.Markers(), null);
}

test "TestAutoImportCompletionExportListAugmentation1" {
    const content =
        \\// @module: node18
        \\// @Filename: /node_modules/@sapphire/pieces/index.d.ts
        \\interface Container {
        \\  stores: unknown;
        \\}
        \\
        \\declare class Piece {
        \\  container: Container;
        \\}
        \\
        \\export { Piece, type Container };
        \\// @FileName: /augmentation.ts
        \\declare module "@sapphire/pieces" {
        \\  interface Container {
        \\    client: unknown;
        \\  }
        \\  export { Container };
        \\}
        \\// @Filename: /index.ts
        \\import { Piece } from "@sapphire/pieces";
        \\class FullPiece extends Piece {
        \\  /*1*/
        \\}
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
//                 &.{
//                     .Label =               "container",
//                     .InsertText =          undefined("container: Container;"),
//                     .FilterText =          undefined("container"),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .Data = &.{
//                         .Source = "ClassMemberSnippet/",
//                     },
//                 },
//             },
//         },
//     });
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined("1"), &.{
//         .Name =        "container",
//         .Source =      "ClassMemberSnippet/",
//         .Description = "Includes imports of types referenced by 'container'",
//         .NewFileContent = undefined("import { Container, Piece } from \"@sapphire/pieces\";\nclass FullPiece extends Piece {\n  \n}"),
//     });
}

test "TestRemoveDuplicateIdentifier" {
    const content =
        \\class foo{}
        \\function foo() { return null; }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToBOF(undefined);
    _ = f.DeleteAtCaret(undefined, 11);
}

test "TestImportNameCodeFix_require_importVsRequire_importWins" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: blah.js
        \\export default class Blah {}
        \\export const Named1 = 0;
        \\export const Named2 = 1;
        \\// @Filename: addToExisting.js
        \\const { Named2 } = require('./blah')
        \\import { Named1 } from './blah'
        \\
        \\new Blah
        \\// @Filename: newImport.js
        \\import fs from 'fs';
        \\const path = require('path');
        \\
        \\new Blah
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "addToExisting.js");
    try f.VerifyCodeFix(undefined, .{
        .Description = "Update import from \"./blah\"",
        .NewFileContent = "const { Named2 } = require('./blah')\nimport Blah, { Named1 } from './blah'\n\nnew Blah",
        .Index = 0,
    });
    _ = f.GoToFile(undefined, "newImport.js");
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add import from \"./blah\"",
        .NewFileContent = "import fs from 'fs';\nimport Blah from './blah';\nconst path = require('path');\n\nnew Blah",
        .Index = 0,
    });
}

test "TestDeclarationMapGoToDefinition" {
    const content =
        \\// @lib: es5
        \\// @Filename: index.ts
        \\export class Foo {
        \\    member: string;
        \\    /*2*/methodName(propName: SomeType): void {}
        \\    otherMethod() {
        \\        if (Math.random() > 0.5) {
        \\            return {x: 42};
        \\        }
        \\        return {y: "yes"};
        \\    }
        \\}
        \\
        \\export interface SomeType {
        \\    member: number;
        \\}
        \\// @Filename: indexdef.d.ts.map
        \\{"version":3,"file":"indexdef.d.ts","sourceRoot":"","sources":["index.ts"],"names":[],"mappings":"AAAA;IACI,MAAM,EAAE,MAAM,CAAC;IACf,UAAU,CAAC,QAAQ,EAAE,QAAQ,GAAG,IAAI;IACpC,WAAW;;;;;;;CAMd;AAED,MAAM,WAAW,QAAQ;IACrB,MAAM,EAAE,MAAM,CAAC;CAClB"}
        \\// @Filename: indexdef.d.ts
        \\export declare class Foo {
        \\    member: string;
        \\    methodName(propName: SomeType): void;
        \\    otherMethod(): {
        \\        x: number;
        \\        y?: undefined;
        \\    } | {
        \\        y: string;
        \\        x?: undefined;
        \\    };
        \\}
        \\export interface SomeType {
        \\    member: number;
        \\}
        \\//# sourceMappingURL=indexdef.d.ts.map
        \\// @Filename: mymodule.ts
        \\import * as mod from "./indexdef";
        \\const instance = new mod.Foo();
        \\instance.[|/*1*/methodName|]({member: 12});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestGetOccurrencesAsyncAwait2" {
    const content =
        \\[|a/**/sync|] function f() {
        \\ [|await|] 100;
        \\ [|await|] [|await|] 200;
        \\ return [|await|] async function () {
        \\   await 300;
        \\ }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestRenameImportNamespaceAndShorthand" {
    const content =
        \\[|import * as [|{| "contextRangeIndex": 0 |}foo|] from 'bar';|]
        \\const bar = { [|foo|] };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[2]);
}

test "TestUnusedLocalsinConstructorFS1" {
    const content =
        \\// @noUnusedLocals: true
        \\// @noUnusedParameters:true
        \\class greeter {
        \\    [| constructor() {
        \\        var unused = 20;
        \\    } |]
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "constructor() {\n}", false, 0, 0);
}

test "TestCompletionsImport_compilerOptionsModule" {
    const content =
        \\// @allowJs: true
        \\// @module: commonjs
        \\// @Filename: /node_modules/a/index.d.ts
        \\export const foo = 0;
        \\// @Filename: /b.js
        \\const a = require("./a");
        \\fo/*b*/
        \\// @Filename: /c.js
        \\const x = 0;/*c*/
        \\// @Filename: /c1.js
        \\// @ts-check
        \\const x = 0;/*ccheck*/
        \\// @Filename: /c2.ts
        \\const x = 0;/*cts*/
        \\// @Filename: /d.js
        \\const a = import("./a"); // Does not make this an external module
        \\fo/*d*/
        \\// @Filename: /d1.js
        \\// @ts-check
        \\const a = import("./a"); // Does not make this an external module
        \\fo/*dcheck*/
        \\// @Filename: /d2.ts
        \\const a = import("./a"); // Does not make this an external module
        \\fo/*dts*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"b", "c", "ccheck", "cts", "d", "dcheck", "dts"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "foo",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "a",
//                         },
//                     },
//                     .Detail =              undefined("const foo: 0"),
//                     .Kind =                undefined(lsproto.CompletionItemKindVariable),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
}

test "TestSmartSelection_JSDocTags8" {
    const content =
        \\/**
        \\ * @this {/*1*/Foo}
        \\ * @param {/*2*/*} e
        \\ */
        \\function callback(e) {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSelectionRanges(undefined);
}

test "TestAutoImportProvider_exportMap6" {
    const content =
        \\// @types package should be ignored because implementation package has types
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "nodenext",
        \\    "lib": ["es5"]
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{
        \\  "type": "module",
        \\  "dependencies": {
        \\    "dependency": "^1.0.0"
        \\  },
        \\  "devDependencies": {
        \\    "@types/dependency": "^1.0.0"
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/dependency/package.json
        \\{
        \\  "type": "module",
        \\  "name": "dependency",
        \\  "version": "1.0.0",
        \\  "exports": {
        \\    ".": "./lib/index.js",
        \\    "./lol": "./lib/lol.js"
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/dependency/lib/index.js
        \\export function fooFromIndex() {}
        \\// @Filename: /home/src/workspaces/project/node_modules/dependency/lib/index.d.ts
        \\export declare function fooFromIndex(): void
        \\// @Filename: /home/src/workspaces/project/node_modules/dependency/lib/lol.js
        \\export function fooFromLol() {}
        \\// @Filename: /home/src/workspaces/project/node_modules/dependency/lib/lol.d.ts
        \\export declare function fooFromLol(): void
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/dependency/package.json
        \\{
        \\  "type": "module",
        \\  "name": "@types/dependency",
        \\  "version": "1.0.0",
        \\  "exports": {
        \\    ".": "./lib/index.d.ts",
        \\    "./lol": "./lib/lol.d.ts"
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/dependency/lib/index.d.ts
        \\export declare function fooFromAtTypesIndex(): void;
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/dependency/lib/lol.d.ts
        \\export declare function fooFromAtTypesLol(): void;
        \\// @Filename: /home/src/workspaces/project/src/foo.ts
        \\fooFrom/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
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
//                     .Label = "fooFromIndex",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "dependency",
//                         },
//                     },
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                 },
//                 &.{
//                     .Label = "fooFromLol",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "dependency/lol",
//                         },
//                     },
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                 },
//             },
//         },
//     });
}

test "TestSyntacticClassificationsFunctionWithComments" {
    const content =
        \\/**
        \\ * This is my function.
        \\ * There are many like it, but this one is mine.
        \\ */
        \\function myFunction(/* x */ x: any) {
        \\    var y = x ? x++ : ++x;
        \\}
        \\// end of file
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "function.declaration", .Text = "myFunction"},
//         .{.Type = "parameter.declaration", .Text = "x"},
//         .{.Type = "variable.declaration.local", .Text = "y"},
//         .{.Type = "parameter", .Text = "x"},
//         .{.Type = "parameter", .Text = "x"},
//         .{.Type = "parameter", .Text = "x"},
//     });
}

test "TestGoToDefinitionAmbiants" {
    const content =
        \\declare var /*ambientVariableDefinition*/ambientVar;
        \\declare function /*ambientFunctionDefinition*/ambientFunction();
        \\declare class ambientClass {
        \\    /*constructorDefinition*/constructor();
        \\    static /*staticMethodDefinition*/method();
        \\    public /*instanceMethodDefinition*/method();
        \\}
        \\
        \\/*ambientVariableReference*/ambientVar = 1;
        \\/*ambientFunctionReference*/ambientFunction();
        \\var ambientClassVariable = new /*constructorReference*/ambientClass();
        \\ambientClass./*staticMethodReference*/method();
        \\ambientClassVariable./*instanceMethodReference*/method();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, false, "ambientVariableReference", "ambientFunctionReference", "constructorReference", "staticMethodReference", "instanceMethodReference");
}

test "TestCompletionListForExportEquals" {
    const content =
        \\// @Filename: /node_modules/foo/index.d.ts
        \\export = Foo;
        \\declare var Foo: Foo.Static;
        \\declare namespace Foo {
        \\    interface Static {
        \\        foo(): void;
        \\    }
        \\}
        \\// @Filename: /a.ts
        \\import { /**/ } from "foo";
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
//                 "foo",
//                 "Static",
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestInlayHintsRestParameters2" {
    const content =
        \\function foo(a: unknown, b: unknown, c: unknown) { }
        \\function foo1(...x: [number, number | undefined]) {
        \\    foo(...x, 3);
        \\}
        \\function foo2(...x: []) {
        \\    foo(...x, 1, 2, 3);
        \\}
        \\function foo3(...x: [number, number?]) {
        \\    foo(1, ...x);
        \\}
        \\function foo4(...x: [number, number?]) {
        \\    foo(...x, 3);
        \\}
        \\function foo5(...x: [number, number]) {
        \\    foo(...x, 3);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayParameterNameHints = lsutil.IncludeInlayParameterNameHintsAll}});
}

test "TestJsDocFunctionSignatures10" {
    const content =
        \\// @allowJs: true
        \\// @Filename: Foo.js
        \\/**
        \\ * Do some foo things
        \\ * @template T A Foolish template
        \\ * @param {T} x a parameter
        \\ */
        \\function foo(x) {
        \\}
        \\
        \\fo/**/o()
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyQuickInfoIs(undefined, "function foo<any>(x: any): void", "Do some foo things");
}

test "TestCodeCompletionEscaping" {
    const content =
        \\// @Filename: a.js
        \\// @allowJs: true
        \\___foo; __foo;/**/
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
//                     .Label =    "__foo",
//                     .Kind =     undefined(lsproto.CompletionItemKindText),
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//                 &.{
//                     .Label =    "___foo",
//                     .Kind =     undefined(lsproto.CompletionItemKindText),
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//             },
//         },
//     });
}

test "TestCodeFixUnusedIdentifier_suggestion" {
    const content =
        \\// @strict: false
        \\function f([|p|]) {
        \\    const [|x|] = 0;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySuggestionDiagnostics(undefined, []*.{
//         .{
//             .Message = .{.String = undefined("Parameter 'p' implicitly has an 'any' type, but a better type may be inferred from usage.")},
//             .Range =   f.Ranges()[0].LSRange,
//             .Code =    &.{.Integer = undefined(int32(7044))},
//         },
//         .{
//             .Message = .{.String = undefined("'p' is declared but its value is never read.")},
//             .Range =   f.Ranges()[0].LSRange,
//             .Code =    &.{.Integer = undefined(int32(6133))},
//             .Tags =    &&.{lsproto.DiagnosticTagUnnecessary},
//         },
//         .{
//             .Message = .{.String = undefined("'x' is declared but its value is never read.")},
//             .Range =   f.Ranges()[1].LSRange,
//             .Code =    &.{.Integer = undefined(int32(6133))},
//             .Tags =    &&.{lsproto.DiagnosticTagUnnecessary},
//         },
//     });
    try f.VerifyCodeFixAvailable(undefined, null);
}

test "TestFindAllReferencesDynamicImport1" {
    const content =
        \\// @lib: es5
        \\// @Filename: foo.ts
        \\export function foo() { return "foo"; }
        \\/*1*/import("/*2*/./foo")
        \\/*3*/var x = import("/*4*/./foo")
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestCompletionListAtThisType" {
    const content =
        \\// @stableTypeOrdering: true
        \\class Test {
        \\    foo() {}
        \\
        \\    bar() {
        \\        this.baz(this, "/*1*/");
        \\
        \\        const t = new Test()
        \\        this.baz(t, "/*2*/");
        \\    }
        \\
        \\    baz<T>(a: T, k: keyof T) {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "2"}, &.{
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
//             },
//         },
//     });
}

test "TestSmartSelection_JSDocTags11" {
    const content =
        \\const x = 1;
        \\type Foo = {
        \\  /** comment */
        \\  /*2*/readonly /*1*/status: number;
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSelectionRanges(undefined);
}

test "TestJsxWithTypeParametershasInstantiatedSignatureHelp" {
    const content =
        \\declare namespace JSX {
        \\    interface Element {
        \\        render(): Element | string | false;
        \\    }
        \\}
        \\
        \\function SFC<T>(_props: Record<string, T>) {
        \\    return '';
        \\}
        \\
        \\(</*1*/SFC/>);
        \\(</*2*/SFC<string>/>);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "SFC(_props: Record<string, unknown>): string"});
    _ = f.GoToMarker(undefined, "2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "SFC(_props: Record<string, string>): string"});
}

test "TestCallHierarchyExportDefaultFunction" {
    const content =
        \\// @filename: main.ts
        \\import bar from "./other";
        \\
        \\function foo() {
        \\    bar();
        \\}
        \\// @filename: other.ts
        \\export /**/default function () {
        \\    baz();
        \\}
        \\
        \\function baz() {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifyBaselineCallHierarchy(undefined);
}

test "TestGoToDefinitionOverriddenMember25" {
    const content =
        \\// @strict: true
        \\// @target: esnext
        \\// @lib: esnext
        \\const prop: symbol = Symbol();
        \\
        \\abstract class A {}
        \\
        \\export class B extends A {
        \\  static [|/*1*/override|] [prop]() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestFindAllRefsForVariableInImplementsClause01" {
    const content =
        \\var Base = class { };
        \\class C extends Base implements /**/Base { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestDocCommentTemplatePrototypeMethod" {
    const content =
        \\// @allowJs: true
        \\// @Filename: foo.js
        \\/** @class */
        \\function C() { }
        \\/*above*/
        \\C.prototype.method = /*next*/ function (p) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkerNames();
    // try f.VerifyJSDocCompletion(undefined, marker, 7, "/**\n * \n * @param {any} p\n */", null);
}

test "TestModuleNodeNextAutoImport1" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{ "compilerOptions": { "module": "nodenext" } }
        \\// @Filename: /package.json
        \\{ "type": "module" }
        \\// @Filename: /mobx.d.ts
        \\export declare function autorun(): void;
        \\// @Filename: /index.ts
        \\autorun/**/
        \\// @Filename: /utils.ts
        \\import "./mobx.js";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { autorun } from \"./mobx.js\";\n\nautorun",
    }, null );
}

test "TestFindAllRefs_importType_typeofImport" {
    const content =
        \\// @Filename: /a.ts
        \\export const x = 0;
        \\// @Filename: /b.ts
        \\/*1*/const x: typeof import("/*2*/./a") = { x: 0 };
        \\/*3*/const y: typeof import("/*4*/./a") = { x: 0 };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestFormattingSpaceBeforeCloseParen" {
    const content =
        \\/*1*/({});
        \\/*2*/(  {});
        \\/*3*/({foo:42});
        \\/*4*/(  {foo:42}  );
        \\/*5*/var bar = (function (a) { });
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts235);
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "( {} );");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "( {} );");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "( { foo: 42 } );");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "( { foo: 42 } );");
    _ = f.GoToMarker(undefined, "5");
    try f.VerifyCurrentLineContent(undefined, "var bar = ( function( a ) { } );");
    // f.GetOptions();
    // f.Configure(undefined, opts674);
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "({});");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "({});");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "({ foo: 42 });");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "({ foo: 42 });");
    _ = f.GoToMarker(undefined, "5");
    try f.VerifyCurrentLineContent(undefined, "var bar = (function(a) { });");
}

test "TestNgProxy1" {
    const content =
        \\// @Filename: tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "lib": ["es5"],
        \\        "plugins": [
        \\            { "name": "quickinfo-augmeneter", "message": "hello world" }
        \\        ]
        \\    },
        \\    "files": ["a.ts"]
        \\}
        \\// @Filename: a.ts
        \\let x = [1, 2];
        \\x/**/
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyQuickInfoIs(undefined, "Proxied x: number[]hello world", "");
}

test "TestDeclarationMapsOutOfDateMapping" {
    const content =
        \\// @lib: es5
        \\// @Filename: /home/src/workspaces/project/node_modules/a/dist/index.d.ts
        \\export declare class Foo {
        \\    bar: any;
        \\}
        \\//# sourceMappingURL=index.d.ts.map
        \\// @Filename: /home/src/workspaces/project/node_modules/a/dist/index.d.ts.map
        \\{"version":3,"file":"index.d.ts","sourceRoot":"","sources":["../src/index.ts"],"names":[],"mappings":"AAAA,qBAAa,GAAG;IACZ,GAAG,MAAC;CACP"}
        \\// @Filename: /home/src/workspaces/project/node_modules/a/src/index.ts
        \\export class /*2*/Foo {
        \\}
        \\
        \\// @Filename: /home/src/workspaces/project/node_modules/a/package.json
        \\{
        \\    "name": "a",
        \\    "version": "0.0.0",
        \\    "private": true,
        \\    "main": "dist",
        \\    "types": "dist"
        \\}
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { Foo/*1*/ } from "a";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToFile(undefined, "/home/src/workspaces/project/index.ts");
    // try f.VerifyBaselineGoToDefinition(undefined, false, "1");
}

test "TestCompletionListInsideTargetTypedFunction" {
    const content =
        \\namespace Fix2 {
        \\    interface iFace { (event: string); }
        \\    var foo: iFace = function (elem) { /**/ }
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
//                 &.{
//                     .Label =  "elem",
//                     .Detail = undefined("(parameter) elem: string"),
//                 },
//             },
//         },
//     });
}

test "TestImportNameCodeFixNewImportIndex" {
    const content =
        \\// @Filename: /a/index.ts
        \\export const foo = 0;
        \\// @Filename: /b.ts
        \\[|/**/foo;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a/index.ts");
    _ = f.GoToFile(undefined, "/b.ts");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { foo } from \"./a\";\n\nfoo;",
    }, null );
}

test "TestQuickInfoForDecorators" {
    const content =
        \\@/*1*/decorator
        \\class C {
        \\}
        \\/** decorator documentation*/
        \\var decorator = t=> t;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "var decorator: (t: any) => any", "decorator documentation");
}

test "TestCompletionsClassPropertiesAfterPrivateProperty" {
    const content =
        \\interface X {
        \\    bla: string;
        \\}
        \\class Y implements X {
        \\    private blub = "";
        \\    /**/
        \\}
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
//                 "bla",
//             },
//         },
//     });
}

test "TestGetJavaScriptCompletions4" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\/** @return {number} */
        \\function foo(a,b) { }
        \\foo(1,2)./**/
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

test "TestQuickInfoNarrowedTypeOfAliasSymbol" {
    const content =
        \\// @strict: true
        \\// @Filename: modules.ts
        \\export declare const someEnv: string | undefined;
        \\// @Filename: app.ts
        \\import { someEnv } from "./modules";
        \\declare function isString(v: any): v is string;
        \\
        \\if (isString(someEnv)) {
        \\  someEnv/*1*/.charAt(0);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "app.ts");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyQuickInfoIs(undefined, "(alias) const someEnv: string\nimport someEnv", "");
}

test "TestGenericCombinators3" {
    const content =
        \\interface Collection<T, U> {
        \\}
        \\
        \\interface Combinators {
        \\    map<T, U, V>(c: Collection<T,U>, f: (x: T, y: U) => V): Collection<T, V>;
        \\    map<T, U>(c: Collection<T,U>, f: (x: T, y: U) => any): Collection<any, any>;
        \\}
        \\
        \\var c2: Collection<number, string>;
        \\
        \\var _: Combinators;
        \\
        \\var /*9*/r1a  = _.ma/*1c*/p(c2, (/*1a*/x,/*1b*/y) => { return x + "" });  // check quick info of map here
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1a", "(parameter) x: number", "");
    try f.VerifyQuickInfoAt(undefined, "1b", "(parameter) y: string", "");
    try f.VerifyQuickInfoAt(undefined, "1c", "(method) Combinators.map<number, string, string>(c: Collection<number, string>, f: (x: number, y: string) => string): Collection<number, string> (+1 overload)", "");
    try f.VerifyQuickInfoAt(undefined, "9", "var r1a: Collection<number, string>", "");
}

test "TestThisPredicateFunctionQuickInfo02" {
    const content =
        \\interface Sundries {
        \\    broken: boolean;
        \\}
        \\
        \\interface Supplies {
        \\    spoiled: boolean;
        \\}
        \\
        \\interface Crate<T> {
        \\    contents: T;
        \\    /*1*/isSundries(): this is Crate<Sundries>;
        \\    /*2*/isSupplies(): this is Crate<Supplies>;
        \\    /*3*/isPackedTight(): this is (this & {extraContents: T});
        \\}
        \\const crate: Crate<any>;
        \\if (crate.isPackedTight/*4*/()) {
        \\    crate.;
        \\}
        \\if (crate.isSundries/*5*/()) {
        \\    crate.contents.;
        \\    if (crate.isPackedTight/*6*/()) {
        \\       crate.;
        \\    }
        \\}
        \\if (crate.isSupplies/*7*/()) {
        \\    crate.contents.;
        \\    if (crate.isPackedTight/*8*/()) {
        \\       crate.;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(method) Crate<T>.isSundries(): this is Crate<Sundries>", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(method) Crate<T>.isSupplies(): this is Crate<Supplies>", "");
    try f.VerifyQuickInfoAt(undefined, "3", "(method) Crate<T>.isPackedTight(): this is (this & {\n    extraContents: T;\n})", "");
    try f.VerifyQuickInfoAt(undefined, "4", "(method) Crate<any>.isPackedTight(): this is (Crate<any> & {\n    extraContents: any;\n})", "");
    try f.VerifyQuickInfoAt(undefined, "5", "(method) Crate<any>.isSundries(): this is Crate<Sundries>", "");
    try f.VerifyQuickInfoAt(undefined, "6", "(method) Crate<Sundries>.isPackedTight(): this is (Crate<Sundries> & {\n    extraContents: Sundries;\n})", "");
    try f.VerifyQuickInfoAt(undefined, "7", "(method) Crate<any>.isSupplies(): this is Crate<Supplies>", "");
    try f.VerifyQuickInfoAt(undefined, "8", "(method) Crate<Supplies>.isPackedTight(): this is (Crate<Supplies> & {\n    extraContents: Supplies;\n})", "");
}

test "TestFindAllRefsWithLeadingUnderscoreNames4" {
    const content =
        \\class Foo {
        \\    /*1*/public /*2*/____bar() { return 0; }
        \\}
        \\
        \\var x: Foo;
        \\x./*3*/____bar;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestOverloadQuickInfo" {
    const content =
        \\function Foo(a: string, b: number, c: boolean);
        \\function Foo(a: any, name: string, age: number);
        \\function Foo(fred: any[], name: string, age: number);
        \\function Foo(fred: any[  ] , name: string[], age: number);
        \\function Foo(fred: any[], name: string[], age: number[]);
        \\function Foo(fred:         any, name: string[], age: number[]); // Extraneous spaces should get removed
        \\function Foo(fred: any, name: boolean, age: number[]);
        \\function Foo(dave: boolean, name: string);
        \\function Foo(fred: any, mandy: {(): number}, age: number[]);    // Embedded interface will get converted to shorthand notation, () => 
        \\function Foo(fred: any, name: string, age: { });
        \\function Foo(fred: any, name: string, age: number[]);
        \\function Foo(test: string, name, age: number);
        \\function Foo();
        \\function Foo(x?: any, y?: any, z?: any) {
        \\}
        \\Fo/**/o();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "function Foo(): any (+12 overloads)", "");
}

test "TestCompletionsImport_packageJsonImportsPreference" {
    const content =
        \\// @module: preserve
        \\// @allowImportingTsExtensions: true
        \\// @Filename: /project/package.json
        \\{
        \\  "name": "project",
        \\  "version": "1.0.0",
        \\  "imports": {
        \\    "#internal/*": "./src/internal/*.ts"
        \\  }
        \\}
        \\// @Filename: /project/src/internal/foo.ts
        \\export const internalFoo = 0;
        \\// @Filename: /project/src/other.ts
        \\export * from "./internal/foo.ts";
        \\// @Filename: /project/src/main.ts
        \\internalFoo/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "internalFoo",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "#internal/foo",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//         .UserPreferences = &.{.ImportModuleSpecifierPreference = "non-relative"},
//     });
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "internalFoo",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./other",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//         .UserPreferences = &.{.ImportModuleSpecifierPreference = "relative"},
//     });
}

test "TestGetOccurrencesClassExpressionConstructor" {
    const content =
        \\let A = class Foo {
        \\    [|constructor|]();
        \\    [|constructor|](x: number);
        \\    [|constructor|](y: string);
        \\    [|constructor|](a?: any) {
        \\    }
        \\}
        \\
        \\let B = class D {
        \\    constructor(x: number) {
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestPasteLambdaOverModule" {
    const content =
        \\// @strict: false
        \\/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Paste(undefined, "namespace B { }");
    _ = f.GoToBOF(undefined);
    _ = f.DeleteAtCaret(undefined, 15);
    _ = f.Insert(undefined, "var t = (public x) => { };");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestFormatOnEnterOpenBraceAddNewLine" {
    const content =
        \\if(true) {/*0*/}
        \\if(false)/*1*/{
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts148);
    _ = f.GoToMarker(undefined, "0");
    _ = f.InsertLine(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "if (true)\n{\n}\nif(false){\n}");
    _ = f.GoToMarker(undefined, "1");
    _ = f.InsertLine(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "if (true)\n{\n}\nif (false)\n{\n}");
}

test "TestJsdocTypedefTagRename01" {
    const content =
        \\// @lib: es5
        \\// @allowNonTsExtensions: true
        \\// @Filename: jsDocTypedef_form1.js
        \\
        \\/** @typedef {(string | number)} */
        \\[|var [|{| "contextRangeIndex": 0 |}NumberLike|];|]
        \\
        \\[|NumberLike|] = 10;
        \\
        \\/** @type {[|NumberLike|]} */
        \\var numberLike;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineRename(undefined, null , ToAny(f.Ranges()[1:]));
}

test "TestDocCommentTemplateReturnsTag2" {
    const content =
        \\/*0*/
        \\function f1(x: number, y: number) {
        \\    return 1;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyJSDocCompletion(undefined, "0", 7, "/**\n * \n * @param x\n * @param y\n * @returns\n */", undefined(true));
    // try f.VerifyJSDocCompletion(undefined, "0", 7, "/**\n * \n * @param x\n * @param y\n */", undefined(false));
}

test "TestQuickInfoJsDocTags11" {
    const content =
        \\// @noEmit: true
        \\// @allowJs: true
        \\// @Filename: quickInfoJsDocTags11.js
        \\/**
        \\ * @param {T1} a
        \\ * @param {T2} b
        \\ * @template {number} T1 Comment T1
        \\ * @template {number} T2 Comment T2
        \\ */
        \\const /**/foo = (a, b) => {};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestRenameReferenceFromLinkTag3" {
    const content =
        \\// @filename: a.ts
        \\interface Foo {
        \\    foo: E.Foo;
        \\}
        \\// @Filename: b.ts
        \\enum E {
        \\    /** {@link /**/Foo} */
        \\    Foo
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , "");
}

test "TestImportNameCodeFixNewImportPaths1" {
    const content =
        \\[|foo/*0*/();|]
        \\// @Filename: folder_b/f2.ts
        \\export function foo() {};
        \\// @Filename: tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "baseUrl": ".",
        \\        "paths": {
        \\            "b/*": [ "folder_b/*" ]
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { foo } from \"b/f2\";\n\nfoo();",
    }, null );
}

test "TestAliasToVarUsedAsType" {
    const content =
        \\/**/
        \\namespace A {
        \\export var X;
        \\import Z = A.X;
        \\var v: Z;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, " ");
}

test "TestGetOccurrencesIfElse2" {
    const content =
        \\if (true) {
        \\    [|if|] (false) {
        \\    }
        \\    [|else|]{
        \\    }
        \\    if (true) {
        \\    }
        \\    else {
        \\        if (false)
        \\            if (true)
        \\                var x = undefined;
        \\    }
        \\}
        \\else            if (null) {
        \\}
        \\else /* whar garbl */ if (undefined) {
        \\}
        \\else
        \\if (false) {
        \\}
        \\else { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestAutoImportsWithRootDirsAndRootedPath01" {
    const content =
        \\// @Filename: /dir/foo.ts
        \\ export function foo() {}
        \\// @Filename: /dir/bar.ts
        \\ /*$*/
        \\// @Filename: /dir/tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "module": "amd",
        \\        "moduleResolution": "classic",
        \\        "rootDirs": ["D:/"]
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "$");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{},
//     });
}

test "TestJsdocDeprecated_suggestion16" {
    const content =
        \\// @module: esnext
        \\// @filename: /a.ts
        \\const a = 1;
        \\const b = 1;
        \\export { a, /** @deprecated b is deprecated */ b }
        \\// @filename: /b.ts
        \\import { [|b|] } from "./a";
        \\[|b|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    // try f.VerifySuggestionDiagnostics(undefined, []*.{
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'b' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[0].LSRange,
//         },
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'b' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[1].LSRange,
//         },
//     });
}

test "TestQuickInfoOnNewKeyword01" {
    const content =
        \\class Cat {
        \\  /**
        \\   * NOTE: this constructor is private! Please use the factory function
        \\   */
        \\  private constructor() { }
        \\
        \\  static makeCat() { new Cat(); }
        \\}
        \\
        \\ne/*1*/w Ca/*2*/t();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "constructor Cat(): Cat", "NOTE: this constructor is private! Please use the factory function");
    try f.VerifyQuickInfoAt(undefined, "2", "constructor Cat(): Cat", "NOTE: this constructor is private! Please use the factory function");
}

test "TestCompletionsIndexSignatureConstraint1" {
    const content =
        \\// @strict: true
        \\
        \\repro #9900
        \\
        \\interface Test {
        \\  a?: number;
        \\  b?: string;
        \\}
        \\
        \\interface TestIndex {
        \\  [key: string]: Test;
        \\}
        \\
        \\declare function testFunc<T extends TestIndex>(t: T): void;
        \\
        \\testFunc({
        \\  test: {
        \\    /**/
        \\  },
        \\});
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
//                     .Label =      "a?",
//                     .InsertText = undefined("a"),
//                     .FilterText = undefined("a"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =      "b?",
//                     .InsertText = undefined("b"),
//                     .FilterText = undefined("b"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
}

test "TestFormattingDecorators" {
    const content =
        \\/*1*/        @    decorator1    
        \\/*2*/            @        decorator2
        \\/*3*/    @decorator3
        \\/*4*/        @    decorator4    @            decorator5
        \\/*5*/class C {
        \\/*6*/            @    decorator6    
        \\/*7*/                @        decorator7
        \\/*8*/        @decorator8
        \\/*9*/    method1() { }
        \\
        \\/*10*/        @    decorator9    @            decorator10 @decorator11            method2() { }
        \\
        \\    method3(
        \\/*11*/                @    decorator12    
        \\/*12*/                    @        decorator13
        \\/*13*/            @decorator14
        \\/*14*/        x) { }
        \\
        \\    method4(
        \\/*15*/            @    decorator15    @            decorator16 @decorator17             x) { }
        \\
        \\/*16*/            @    decorator18    
        \\/*17*/                @        decorator19
        \\/*18*/        @decorator20    
        \\/*19*/    ["computed1"]() { }
        \\
        \\/*20*/        @    decorator21    @            decorator22 @decorator23            ["computed2"]() { }
        \\
        \\/*21*/            @    decorator24    
        \\/*22*/                @        decorator25
        \\/*23*/        @decorator26
        \\/*24*/    get accessor1() { }
        \\
        \\/*25*/        @    decorator27    @            decorator28 @decorator29            get accessor2() { }
        \\
        \\/*26*/            @    decorator30    
        \\/*27*/                @        decorator31
        \\/*28*/        @decorator32
        \\/*29*/    property1;
        \\
        \\/*30*/        @    decorator33    @            decorator34 @decorator35            property2;
        \\/*31*/function test(@decorator36@decorator37 param) {};
        \\/*32*/function test2(@decorator38()@decorator39()param) {};
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "@decorator1");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "@decorator2");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "@decorator3");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "@decorator4 @decorator5");
    _ = f.GoToMarker(undefined, "5");
    try f.VerifyCurrentLineContent(undefined, "class C {");
    _ = f.GoToMarker(undefined, "6");
    try f.VerifyCurrentLineContent(undefined, "    @decorator6");
    _ = f.GoToMarker(undefined, "7");
    try f.VerifyCurrentLineContent(undefined, "    @decorator7");
    _ = f.GoToMarker(undefined, "8");
    try f.VerifyCurrentLineContent(undefined, "    @decorator8");
    _ = f.GoToMarker(undefined, "9");
    try f.VerifyCurrentLineContent(undefined, "    method1() { }");
    _ = f.GoToMarker(undefined, "10");
    try f.VerifyCurrentLineContent(undefined, "    @decorator9 @decorator10 @decorator11 method2() { }");
    _ = f.GoToMarker(undefined, "11");
    try f.VerifyCurrentLineContent(undefined, "        @decorator12");
    _ = f.GoToMarker(undefined, "12");
    try f.VerifyCurrentLineContent(undefined, "        @decorator13");
    _ = f.GoToMarker(undefined, "13");
    try f.VerifyCurrentLineContent(undefined, "        @decorator14");
    _ = f.GoToMarker(undefined, "14");
    try f.VerifyCurrentLineContent(undefined, "        x) { }");
    _ = f.GoToMarker(undefined, "15");
    try f.VerifyCurrentLineContent(undefined, "        @decorator15 @decorator16 @decorator17 x) { }");
    _ = f.GoToMarker(undefined, "16");
    try f.VerifyCurrentLineContent(undefined, "    @decorator18");
    _ = f.GoToMarker(undefined, "17");
    try f.VerifyCurrentLineContent(undefined, "    @decorator19");
    _ = f.GoToMarker(undefined, "18");
    try f.VerifyCurrentLineContent(undefined, "    @decorator20");
    _ = f.GoToMarker(undefined, "19");
    try f.VerifyCurrentLineContent(undefined, "    [\"computed1\"]() { }");
    _ = f.GoToMarker(undefined, "20");
    try f.VerifyCurrentLineContent(undefined, "    @decorator21 @decorator22 @decorator23 [\"computed2\"]() { }");
    _ = f.GoToMarker(undefined, "21");
    try f.VerifyCurrentLineContent(undefined, "    @decorator24");
    _ = f.GoToMarker(undefined, "22");
    try f.VerifyCurrentLineContent(undefined, "    @decorator25");
    _ = f.GoToMarker(undefined, "23");
    try f.VerifyCurrentLineContent(undefined, "    @decorator26");
    _ = f.GoToMarker(undefined, "24");
    try f.VerifyCurrentLineContent(undefined, "    get accessor1() { }");
    _ = f.GoToMarker(undefined, "25");
    try f.VerifyCurrentLineContent(undefined, "    @decorator27 @decorator28 @decorator29 get accessor2() { }");
    _ = f.GoToMarker(undefined, "26");
    try f.VerifyCurrentLineContent(undefined, "    @decorator30");
    _ = f.GoToMarker(undefined, "27");
    try f.VerifyCurrentLineContent(undefined, "    @decorator31");
    _ = f.GoToMarker(undefined, "28");
    try f.VerifyCurrentLineContent(undefined, "    @decorator32");
    _ = f.GoToMarker(undefined, "29");
    try f.VerifyCurrentLineContent(undefined, "    property1;");
    _ = f.GoToMarker(undefined, "30");
    try f.VerifyCurrentLineContent(undefined, "    @decorator33 @decorator34 @decorator35 property2;");
    _ = f.GoToMarker(undefined, "31");
    try f.VerifyCurrentLineContent(undefined, "function test(@decorator36 @decorator37 param) { };");
    _ = f.GoToMarker(undefined, "32");
    try f.VerifyCurrentLineContent(undefined, "function test2(@decorator38() @decorator39() param) { };");
}

test "TestCodeFixClassImplementInterfaceIndexSignaturesNoFix" {
    const content =
        \\interface I4 {
        \\    [x: string, y: number]: number;
        \\}
        \\
        \\class C implements I {[|  |]}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestCommentsExternalModulesFourslash" {
    const content =
        \\// @Filename: commentsExternalModules_file0.ts
        \\/** Namespace comment*/
        \\export namespace m/*1*/1 {
        \\    /** b's comment*/
        \\    export var b: number;
        \\    /** foo's comment*/
        \\    function foo() {
        \\        return /*2*/b;
        \\    }
        \\    /** m2 comments*/
        \\    export namespace m2 {
        \\        /** class comment;*/
        \\        export class c {
        \\        };
        \\        /** i*/
        \\        export var i = new c();
        \\    }
        \\    /** exported function*/
        \\    export function fooExport() {
        \\        return f/*3q*/oo(/*3*/);
        \\    }
        \\}
        \\/*4*/m1./*5*/fooEx/*6q*/port(/*6*/);
        \\var my/*7*/var = new m1.m2./*8*/c();
        \\// @Filename: commentsExternalModules_file1.ts
        \\/**This is on import declaration*/
        \\import ex/*9*/tMod = require("./commentsExternalModules_file0");
        \\/*10*/extMod./*11*/m1./*12*/fooExp/*13q*/ort(/*13*/);
        \\var new/*14*/Var = new extMod.m1.m2./*15*/c();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "commentsExternalModules_file0.ts");
    try f.VerifyQuickInfoAt(undefined, "1", "namespace m1", "Namespace comment");
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "b",
//                     .Detail = undefined("var b: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "b's comment",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "foo",
//                     .Detail = undefined("function foo(): number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "foo's comment",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "3");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "foo's comment"});
    try f.VerifyQuickInfoAt(undefined, "3q", "function foo(): number", "foo's comment");
    // f.VerifyCompletions(undefined, "4", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "m1",
//                     .Detail = undefined("namespace m1"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "Namespace comment",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "5", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "b",
//                     .Detail = undefined("var m1.b: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "b's comment",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "fooExport",
//                     .Detail = undefined("function m1.fooExport(): number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "exported function",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "m2",
//                     .Detail = undefined("namespace m1.m2"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "m2 comments",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "6");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "exported function"});
    try f.VerifyQuickInfoAt(undefined, "6q", "function m1.fooExport(): number", "exported function");
    try f.VerifyQuickInfoAt(undefined, "7", "var myvar: m1.m2.c", "");
    // f.VerifyCompletions(undefined, "8", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "c",
//                     .Detail = undefined("constructor m1.m2.c(): m1.m2.c"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "class comment;",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i",
//                     .Detail = undefined("var m1.m2.i: m1.m2.c"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    _ = f.GoToFile(undefined, "commentsExternalModules_file1.ts");
    try f.VerifyQuickInfoAt(undefined, "9", "import extMod = require(\"./commentsExternalModules_file0\")", "This is on import declaration");
    // f.VerifyCompletions(undefined, "10", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "extMod",
//                     .Detail = undefined("import extMod = require(\"./commentsExternalModules_file0\")"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "This is on import declaration",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "11", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "m1",
//                     .Detail = undefined("namespace extMod.m1"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "Namespace comment",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "12", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "b",
//                     .Detail = undefined("var extMod.m1.b: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "b's comment",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "fooExport",
//                     .Detail = undefined("function extMod.m1.fooExport(): number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "exported function",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "m2",
//                     .Detail = undefined("namespace extMod.m1.m2"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "m2 comments",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "13");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "exported function"});
    try f.VerifyQuickInfoAt(undefined, "13q", "function extMod.m1.fooExport(): number", "exported function");
    try f.VerifyQuickInfoAt(undefined, "14", "var newVar: extMod.m1.m2.c", "");
    // f.VerifyCompletions(undefined, "15", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "c",
//                     .Detail = undefined("constructor extMod.m1.m2.c(): extMod.m1.m2.c"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "class comment;",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i",
//                     .Detail = undefined("var extMod.m1.m2.i: extMod.m1.m2.c"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i",
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestSignatureHelpFunctionParameter" {
    const content =
        \\function parameterFunction(callback: (a: number, b: string) => void) {
        \\    callback(/*parameterFunction1*/5, /*parameterFunction2*/"");
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "parameterFunction1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "callback(a: number, b: string): void", .ParameterCount = 2, .ParameterName = "a", .ParameterSpan = "a: number"});
    _ = f.GoToMarker(undefined, "parameterFunction2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "callback(a: number, b: string): void", .ParameterName = "b", .ParameterSpan = "b: string"});
}

test "TestSignatureHelpCommentsCommentParsing" {
    const content =
        \\/// This is simple /// comments
        \\function simple() {
        \\}
        \\
        \\simple( /*1*/);
        \\
        \\/// multiLine /// Comments
        \\/// This is example of multiline /// comments
        \\/// Another multiLine
        \\function multiLine() {
        \\}
        \\multiLine( /*2*/);
        \\
        \\/** this is eg of single line jsdoc style comment */
        \\function jsDocSingleLine() {
        \\}
        \\jsDocSingleLine(/*3*/);
        \\
        \\
        \\/** this is multiple line jsdoc stule comment
        \\*New line1
        \\*New Line2*/
        \\function jsDocMultiLine() {
        \\}
        \\jsDocMultiLine(/*4*/);
        \\
        \\/** multiple line jsdoc comments no longer merge
        \\*New line1
        \\*New Line2*/
        \\/** Shoul mege this line as well
        \\* and this too*/ /** Another this one too*/
        \\function jsDocMultiLineMerge() {
        \\}
        \\jsDocMultiLineMerge(/*5*/);
        \\
        \\
        \\/// Triple slash comment
        \\/** jsdoc comment */
        \\function jsDocMixedComments1() {
        \\}
        \\jsDocMixedComments1(/*6*/);
        \\
        \\/// Triple slash comment
        \\/** jsdoc comment */ /** another jsDocComment*/
        \\function jsDocMixedComments2() {
        \\}
        \\jsDocMixedComments2(/*7*/);
        \\
        \\/** jsdoc comment */ /*** triplestar jsDocComment*/
        \\/// Triple slash comment
        \\function jsDocMixedComments3() {
        \\}
        \\jsDocMixedComments3(/*8*/);
        \\
        \\/** jsdoc comment */ /** another jsDocComment*/
        \\/// Triple slash comment
        \\/// Triple slash comment 2
        \\function jsDocMixedComments4() {
        \\}
        \\jsDocMixedComments4(/*9*/);
        \\
        \\/// Triple slash comment 1
        \\/** jsdoc comment */ /** another jsDocComment*/
        \\/// Triple slash comment
        \\/// Triple slash comment 2
        \\function jsDocMixedComments5() {
        \\}
        \\jsDocMixedComments5(/*10*/);
        \\
        \\/** another jsDocComment*/
        \\/// Triple slash comment 1
        \\/// Triple slash comment
        \\/// Triple slash comment 2
        \\/** jsdoc comment */
        \\function jsDocMixedComments6() {
        \\}
        \\jsDocMixedComments6(/*11*/);
        \\
        \\// This shoulnot be help comment
        \\function noHelpComment1() {
        \\}
        \\noHelpComment1(/*12*/);
        \\
        \\/* This shoulnot be help comment */
        \\function noHelpComment2() {
        \\}
        \\noHelpComment2(/*13*/);
        \\
        \\function noHelpComment3() {
        \\}
        \\noHelpComment3(/*14*/);
        \\/** Adds two integers and returns the result
        \\  * @param {number} a first number
        \\  * @param b second number
        \\  */
        \\function sum(a: number, b: number) {
        \\    return a + b;
        \\}
        \\sum(/*16*/10, /*17*/20);
        \\/** This is multiplication function
        \\ * @param 
        \\ * @param a first number
        \\ * @param b
        \\ * @param c {
        \\ @param d @anotherTag
        \\ * @param e LastParam @anotherTag*/
        \\function multiply(a: number, b: number, c?: number, d?, e?) {
        \\}
        \\multiply(/*19*/10,/*20*/ 20,/*21*/ 30, /*22*/40, /*23*/50);
        \\/** fn f1 with number
        \\* @param { string} b about b
        \\*/
        \\function f1(a: number);
        \\function f1(b: string);
        \\/**@param opt optional parameter*/
        \\function f1(aOrb, opt?) {
        \\    return aOrb;
        \\}
        \\f1(/*25*/10);
        \\f1(/*26*/"hello");
        \\
        \\/** This is subtract function
        \\@param { a
        \\*@param { number | } b this is about b
        \\@param { { () => string; } } c this is optional param c
        \\@param { { () => string; } d this is optional param d
        \\@param { { () => string; } } e this is optional param e
        \\@param { { { () => string; } } f this is optional param f
        \\*/
        \\function subtract(a: number, b: number, c?: () => string, d?: () => string, e?: () => string, f?: () => string) {
        \\}
        \\subtract(/*28*/10, /*29*/ 20, /*30*/ null, /*31*/ null, /*32*/ null, /*33*/null);
        \\/** this is square function
        \\@paramTag { number } a this is input number of paramTag
        \\@param { number } a this is input number
        \\@returnType { number } it is return type
        \\*/
        \\function square(a: number) {
        \\    return a * a;
        \\}
        \\square(/*34*/10);
        \\/** this is divide function
        \\@param { number} a this is a
        \\@paramTag { number } g this is optional param g
        \\@param { number} b this is b
        \\*/
        \\function divide(a: number, b: number) {
        \\}
        \\divide(/*35*/10, /*36*/20);
        \\/**
        \\Function returns string concat of foo and bar
        \\@param            {string}        foo        is string
        \\@param            {string}        bar        is second string
        \\*/
        \\function fooBar(foo: string, bar: string) {
        \\    return foo + bar;
        \\}
        \\fooBar(/*37*/"foo",/*38*/"bar");
        \\/** This is a comment */
        \\var x;
        \\/**
        \\  * This is a comment
        \\  */
        \\var y;
        \\/** this is jsdoc style function with param tag as well as inline parameter help
        \\*@param a it is first parameter
        \\*@param c it is third parameter
        \\*/
        \\function jsDocParamTest(/** this is inline comment for a */a: number, /** this is inline comment for b*/ b: number, c: number, d: number) {
        \\    return /*39*/a + b + c + d;
        \\}
        \\jsDocParamTest(/*40*/30, /*41*/40, /*42*/50, /*43*/60);
        \\/** This is function comment
        \\  * And properly aligned comment
        \\  */
        \\function jsDocCommentAlignmentTest1() {
        \\}
        \\jsDocCommentAlignmentTest1(/*45*/);
        \\/** This is function comment
        \\  *     And aligned with 4 space char margin
        \\  */
        \\function jsDocCommentAlignmentTest2() {
        \\}
        \\jsDocCommentAlignmentTest2(/*46*/);
        \\/** This is function comment
        \\  *     And aligned with 4 space char margin
        \\  * @param {string} a this is info about a
        \\  *                   spanning on two lines and aligned perfectly
        \\  * @param b          this is info about b
        \\  *                   spanning on two lines and aligned perfectly
        \\  *                   spanning one more line alined perfectly
        \\  *                       spanning another line with more margin
        \\  * @param c          this is info about b
        \\  *  not aligned text about parameter will eat only one space
        \\  */
        \\function jsDocCommentAlignmentTest3(a: string, b, c) {
        \\}
        \\jsDocCommentAlignmentTest3(/*47*/"hello",/*48*/1, /*49*/2);
        \\/**/
        \\class NoQuickInfoClass {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSignatureHelp(undefined);
}

test "TestImportCompletionsPackageJsonImportsPattern_ts_js" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#*.ts": "./src/*.js"
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
//                 "#something.ts",
//             },
//         },
//     });
}

test "TestAsOperatorCompletion2" {
    const content =
        \\type T = number;
        \\var x;
        \\var y = x as /**/
        \\
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

test "TestCompletionsOptionalMethod" {
    const content =
        \\// @strictNullChecks: true
        \\declare const x: { m?(): void };
        \\x./**/
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
//                 "m",
//             },
//         },
//     });
}

test "TestCodeFixInferFromUsageInaccessibleTypes" {
    const content =
        \\// @strict: false
        \\// @noImplicitAny: true
        \\function f1(a) { a; }
        \\function h1() {
        \\    class C { p: number };
        \\    f1({ ofTypeC: new C() });
        \\}
        \\
        \\function f2(a) { a; }
        \\function h2() {
        \\    interface I { a: number }
        \\    var i: I = {a : 1};
        \\    f2(i);
        \\    f2(2);
        \\    f2(false);
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestSymbolCompletionLowerPriority" {
    const content =
        \\declare const Symbol: (s: string) => symbol;
        \\const mySymbol = Symbol("test");
        \\interface TestInterface { 
        \\    [mySymbol]: string;
        \\    normalProperty: number;
        \\}
        \\const obj: TestInterface = {} as any;
        \\obj./*completions*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "completions", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "normalProperty",
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//                 &.{
//                     .Label =      "mySymbol",
//                     .InsertText = undefined("[mySymbol]"),
//                     .SortText =   undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestCompletionListInUnclosedTaggedTemplate01" {
    const content =
        \\var x;
        \\var y = (p) => x 
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
//                 "p",
//                 "x",
//             },
//         },
//     });
}

