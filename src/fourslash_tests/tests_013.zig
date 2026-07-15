const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCodeFixSpellingShortName1" {
    const content =
        \\export let ab = 1;
        \\[|aB|] = 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "ab", false, 0, 0);
}

test "TestGetOccurrencesIsDefinitionOfComputedProperty" {
    const content =
        \\let o = { /*1*/["/*2*/foo"]: 12 };
        \\let y = o./*3*/foo;
        \\let z = o['/*4*/foo'];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestFindAllRefs_importType_js4" {
    const content =
        \\// @module: commonjs
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /a.js
        \\/**
        \\ * @callback /**/A
        \\ * @param {unknown} response
        \\ */
        \\
        \\module.exports = {};
        \\// @Filename: /b.js
        \\/** @typedef {import("./a").A} A */
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestCommentsVariables" {
    const content =
        \\/** This is my variable*/
        \\var myV/*1*/ariable = 10;
        \\/*2*/
        \\/** d variable*/
        \\var d = 10;
        \\myVariable = d;
        \\/*3*/
        \\/** foos comment*/
        \\function foo() {
        \\}
        \\/** fooVar comment*/
        \\var foo/*12*/Var: () => void;
        \\/*4*/
        \\f/*5q*/oo(/*5*/);
        \\fo/*6q*/oVar(/*6*/);
        \\fo/*13*/oVar = f/*14*/oo;
        \\/*7*/
        \\f/*8q*/oo(/*8*/);
        \\foo/*9q*/Var(/*9*/);
        \\var fooVarVar = /*9aq*/fooVar;
        \\/**class comment*/
        \\class c {
        \\    /** constructor comment*/
        \\    constructor() {
        \\    }
        \\}
        \\/**instance comment*/
        \\var i = new c();
        \\/*10*/
        \\/** interface comments*/
        \\interface i1 {
        \\}
        \\/**interface instance comments*/
        \\var i1_i: i1;
        \\/*11*/
        \\function foo2(a: number): void;
        \\function foo2(b: string): void;
        \\function foo2(aOrb) {
        \\}
        \\var x = fo/*15*/o2;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var myVariable: number", "This is my variable");
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "myVariable",
//                     .Detail = undefined("var myVariable: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "This is my variable",
//                         },
//                     },
//                 },
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
//                     .Label =  "myVariable",
//                     .Detail = undefined("var myVariable: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "This is my variable",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "d",
//                     .Detail = undefined("var d: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "d variable",
//                         },
//                     },
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
//                     .Label =  "foo",
//                     .Detail = undefined("function foo(): void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "foos comment",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "fooVar",
//                     .Detail = undefined("var fooVar: () => void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "fooVar comment",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "5");
    // f.VerifySignatureHelp(undefined, .{.DocComment = "foos comment"});
    // f.VerifyQuickInfoAt(undefined, "5q", "function foo(): void", "foos comment");
    _ = f.GoToMarker(undefined, "6");
    // f.VerifySignatureHelp(undefined, .{.DocComment = "fooVar comment"});
    // f.VerifyQuickInfoAt(undefined, "6q", "var fooVar: () => void", "fooVar comment");
    // f.VerifyCompletions(undefined, "7", &.{
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
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "foos comment",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "fooVar",
//                     .Detail = undefined("var fooVar: () => void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "fooVar comment",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "8");
    // f.VerifySignatureHelp(undefined, .{.DocComment = "foos comment"});
    // f.VerifyQuickInfoAt(undefined, "8q", "function foo(): void", "foos comment");
    _ = f.GoToMarker(undefined, "9");
    // f.VerifySignatureHelp(undefined, .{.DocComment = "fooVar comment"});
    // f.VerifyQuickInfoAt(undefined, "9q", "var fooVar: () => void", "fooVar comment");
    // f.VerifyQuickInfoAt(undefined, "9aq", "var fooVar: () => void", "fooVar comment");
    // f.VerifyCompletions(undefined, "10", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "i",
//                     .Detail = undefined("var i: c"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "instance comment",
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
//                     .Label =  "i1_i",
//                     .Detail = undefined("var i1_i: i1"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "interface instance comments",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    // f.VerifyQuickInfoAt(undefined, "12", "var fooVar: () => void", "fooVar comment");
    // f.VerifyQuickInfoAt(undefined, "13", "var fooVar: () => void", "fooVar comment");
    // f.VerifyQuickInfoAt(undefined, "14", "function foo(): void", "foos comment");
    // f.VerifyQuickInfoAt(undefined, "15", "function foo2(a: number): void (+1 overload)", "");
}

test "TestGoToDefinitionOverriddenMember24" {
    const content =
        \\// @strict: true
        \\// @target: esnext
        \\// @lib: esnext
        \\const prop: symbol = Symbol();
        \\
        \\abstract class A {
        \\  [prop]() {}
        \\}
        \\
        \\export class B extends A {
        \\  [|/*1*/override|] [prop]() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestGoToSource14_unresolvedRequireDestructuring" {
    const content =
        \\// @lib: es5
        \\// @allowJs: true
        \\// @Filename: /home/src/workspaces/project/index.js
        \\const { blah/**/ } = require("unresolved");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "");
}

test "TestImportNameCodeFix_fromPathMapping" {
    const content =
        \\// @Filename: /a.ts
        \\export const foo = 0;
        \\// @Filename: /x/y.ts
        \\foo;
        \\// @Filename: /tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "baseUrl": ".",
        \\        "paths": {
        \\            "@root/*": ["*"],
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/x/y.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { foo } from \"@root/a\";\n\nfoo;",
    }, null );
}

test "TestCompletionListOfUnion" {
    const content =
        \\// @strictNullChecks: true
        \\const x: { a: number, b: number } | { a: string, c: string } | { b: boolean } | number | null | undefined = { /*x*/ };
        \\interface I { a: number; }
        \\function f(...args: Array<I | I[]>) {}
        \\f({ /*f*/ });
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "x", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "a",
//                     .Detail = undefined("(property) a: string | number"),
//                 },
//                 &.{
//                     .Label =  "b",
//                     .Detail = undefined("(property) b: number | boolean"),
//                 },
//                 &.{
//                     .Label =  "c",
//                     .Detail = undefined("(property) c: string"),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "f", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "a",
//                     .Detail = undefined("(property) I.a: number"),
//                 },
//             },
//         },
//     });
}

test "TestMemberListOfModule" {
    const content =
        \\namespace Foo {
        \\  export class Bar {
        \\
        \\  }
        \\
        \\
        \\  export namespace Blah {
        \\
        \\  }
        \\}
        \\
        \\var x: Foo./**/
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
//                 "Bar",
//             },
//         },
//     });
}

test "TestFindAllRefsWithLeadingUnderscoreNames1" {
    const content =
        \\class Foo {
        \\    /*1*/public /*2*/_bar() { return 0; }
        \\}
        \\
        \\var x: Foo;
        \\x./*3*/_bar;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestCompletionAfterAtChar" {
    const content =
        \\// @lib: es5
        \\@a/**/
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
//             .Exact = CompletionGlobals,
//         },
//     });
}

test "TestRenameJsThisProperty03" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\class C {
        \\  constructor(y) {
        \\    [|this.[|{| "contextRangeIndex": 0 |}x|] = y;|]
        \\  }
        \\}
        \\var t = new C(12);
        \\[|t.[|{| "contextRangeIndex": 2 |}x|] = 11;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "x");
}

test "TestSignatureHelpInRecursiveType" {
    const content =
        \\type Tail<T extends any[]> =
        \\    ((...args: T) => any) extends ((head: any, ...tail: infer R) => any) ? R : never;
        \\
        \\type Reverse<List extends any[]> = _Reverse<List, []>;
        \\
        \\type _Reverse<Source extends any[], Result extends any[] = []> = {
        \\    1: Result,
        \\    0: _Reverse<Tail<Source>, 0>,
        \\}[Source extends [] ? 1 : 0];
        \\
        \\type Foo = Reverse<[0,/**/]>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifySignatureHelp(undefined, .{.Text = "Reverse<List extends any[]>"});
}

test "TestQuickinfoVerbosityTruncation2" {
    const content =
        \\interface LargeInterface/*o1*/ {
        \\    prop1: any;
        \\    prop2: any;
        \\    prop3: any;
        \\    prop4: any;
        \\    prop5: any;
        \\    prop6: any;
        \\    prop7: any;
        \\    prop8: any;
        \\    prop9: any;
        \\    prop10: any;
        \\    prop11: any;
        \\    prop12: any;
        \\    prop13: any;
        \\    prop14: any;
        \\    prop15: any;
        \\    prop16: any;
        \\    prop17: any;
        \\    prop18: any;
        \\    prop19: any;
        \\    prop20: any;
        \\    prop21: any;
        \\    prop22: any;
        \\    prop23: any;
        \\    prop24: any;
        \\    prop25: any;
        \\    prop26: any;
        \\    prop27: any;
        \\    prop28: any;
        \\    prop29: any;
        \\    prop30: any;
        \\    prop31: any;
        \\    prop32: any;
        \\    prop33: any;
        \\    prop34: any;
        \\    prop35: any;
        \\    prop36: any;
        \\    prop37: any;
        \\    prop38: any;
        \\    prop39: any;
        \\    prop40: any;
        \\    prop41: any;
        \\    prop42: any;
        \\    prop43: any;
        \\    prop44: any;
        \\    prop45: any;
        \\    prop46: any;
        \\    prop47: any;
        \\    prop48: any;
        \\    prop49: any;
        \\    prop50: any;
        \\    prop51: any;
        \\    prop52: any;
        \\    prop53: any;
        \\    prop54: any;
        \\    prop55: any;
        \\    prop56: any;
        \\    prop57: any;
        \\    prop58: any;
        \\    prop59: any;
        \\    prop60: any;
        \\    prop61: any;
        \\    prop62: any;
        \\    prop63: any;
        \\    prop64: any;
        \\    prop65: any;
        \\    prop66: any;
        \\    prop67: any;
        \\    prop68: any;
        \\    prop69: any;
        \\    prop70: any;
        \\    prop71: any;
        \\    prop72: any;
        \\    prop73: any;
        \\    prop74: any;
        \\    prop75: any;
        \\    prop76: any;
        \\    prop77: any;
        \\    prop78: any;
        \\    prop79: any;
        \\    prop80: any;
        \\    prop81: any;
        \\    prop82: any;
        \\    prop83: any;
        \\    prop84: any;
        \\    prop85: any;
        \\    prop86: any;
        \\    prop87: any;
        \\    prop88: any;
        \\    prop89: any;
        \\    prop90: any;
        \\    prop91: any;
        \\    prop92: any;
        \\    prop93: any;
        \\    prop94: any;
        \\    prop95: any;
        \\    prop96: any;
        \\    prop97: any;
        \\    prop98: any;
        \\    prop99: any;
        \\    prop100: any;
        \\    prop101: any;
        \\    prop102: any;
        \\    prop103: any;
        \\    prop104: any;
        \\    prop105: any;
        \\    prop106: any;
        \\    prop107: any;
        \\    prop108: any;
        \\    prop109: any;
        \\    prop110: any;
        \\    prop111: any;
        \\    prop112: any;
        \\    prop113: any;
        \\    prop114: any;
        \\    prop115: any;
        \\    prop116: any;
        \\    prop117: any;
        \\    prop118: any;
        \\    prop119: any;
        \\    prop120: any;
        \\    prop121: any;
        \\    prop122: any;
        \\    prop123: any;
        \\    prop124: any;
        \\    prop125: any;
        \\    prop126: any;
        \\    prop127: any;
        \\    prop128: any;
        \\    prop129: any;
        \\    prop130: any;
        \\    prop131: any;
        \\    prop132: any;
        \\    prop133: any;
        \\    prop134: any;
        \\    prop135: any;
        \\    prop136: any;
        \\    prop137: any;
        \\    prop138: any;
        \\    prop139: any;
        \\    prop140: any;
        \\    prop141: any;
        \\    prop142: any;
        \\    prop143: any;
        \\    prop144: any;
        \\    prop145: any;
        \\    prop146: any;
        \\    prop147: any;
        \\    prop148: any;
        \\    prop149: any;
        \\    prop150: any;
        \\    prop151: any;
        \\    prop152: any;
        \\    prop153: any;
        \\    prop154: any;
        \\    prop155: any;
        \\    prop156: any;
        \\    prop157: any;
        \\    prop158: any;
        \\    prop159: any;
        \\    prop160: any;
        \\    prop161: any;
        \\    prop162: any;
        \\    prop163: any;
        \\    prop164: any;
        \\    prop165: any;
        \\    prop166: any;
        \\    prop167: any;
        \\    prop168: any;
        \\    prop169: any;
        \\    prop170: any;
        \\    prop171: any;
        \\    prop172: any;
        \\    prop173: any;
        \\    prop174: any;
        \\    prop175: any;
        \\    prop176: any;
        \\    prop177: any;
        \\    prop178: any;
        \\    prop179: any;
        \\    prop180: any;
        \\    prop181: any;
        \\    prop182: any;
        \\    prop183: any;
        \\    prop184: any;
        \\    prop185: any;
        \\    prop186: any;
        \\    prop187: any;
        \\    prop188: any;
        \\    prop189: any;
        \\    prop190: any;
        \\    prop191: any;
        \\    prop192: any;
        \\    prop193: any;
        \\    prop194: any;
        \\    prop195: any;
        \\    prop196: any;
        \\    prop197: any;
        \\    prop198: any;
        \\    prop199: any;
        \\    prop200: any;
        \\    prop201: any;
        \\    prop202: any;
        \\    prop203: any;
        \\    prop204: any;
        \\    prop205: any;
        \\    prop206: any;
        \\    prop207: any;
        \\    prop208: any;
        \\    prop209: any;
        \\    prop210: any;
        \\    prop211: any;
        \\    prop212: any;
        \\    prop213: any;
        \\    prop214: any;
        \\    prop215: any;
        \\    prop216: any;
        \\    prop217: any;
        \\    prop218: any;
        \\    prop219: any;
        \\    prop220: any;
        \\    prop221: any;
        \\    prop222: any;
        \\    prop223: any;
        \\    prop224: any;
        \\    prop225: any;
        \\    prop226: any;
        \\    prop227: any;
        \\    prop228: any;
        \\    prop229: any;
        \\    prop230: any;
        \\    prop231: any;
        \\    prop232: any;
        \\    prop233: any;
        \\    prop234: any;
        \\    prop235: any;
        \\    prop236: any;
        \\    prop237: any;
        \\    prop238: any;
        \\    prop239: any;
        \\    prop240: any;
        \\    prop241: any;
        \\    prop242: any;
        \\    prop243: any;
        \\    prop244: any;
        \\    prop245: any;
        \\    prop246: any;
        \\    prop247: any;
        \\    prop248: any;
        \\    prop249: any;
        \\    prop250: any;
        \\    prop251: any;
        \\    prop252: any;
        \\    prop253: any;
        \\    prop254: any;
        \\    prop255: any;
        \\    prop256: any;
        \\    prop257: any;
        \\    prop258: any;
        \\    prop259: any;
        \\    prop260: any;
        \\    prop261: any;
        \\    prop262: any;
        \\    prop263: any;
        \\    prop264: any;
        \\    prop265: any;
        \\    prop266: any;
        \\    prop267: any;
        \\    prop268: any;
        \\    prop269: any;
        \\    prop270: any;
        \\    prop271: any;
        \\    prop272: any;
        \\    prop273: any;
        \\    prop274: any;
        \\    prop275: any;
        \\    prop276: any;
        \\    prop277: any;
        \\    prop278: any;
        \\    prop279: any;
        \\    prop280: any;
        \\    prop281: any;
        \\    prop282: any;
        \\    prop283: any;
        \\    prop284: any;
        \\    prop285: any;
        \\    prop286: any;
        \\    prop287: any;
        \\    prop288: any;
        \\    prop289: any;
        \\    prop290: any;
        \\    prop291: any;
        \\    prop292: any;
        \\    prop293: any;
        \\    prop294: any;
        \\    prop295: any;
        \\    prop296: any;
        \\    prop297: any;
        \\    prop298: any;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"o1" = .{0, 1}});
}

test "TestJsdocSatisfiesTagRename" {
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
    // f.VerifyBaselineRename(undefined, null , "");
}

test "TestOrganizeImportsUnicode1" {
    const content =
        \\import {
        \\    Ab,
        \\    _aB,
        \\    aB,
        \\    _Ab,
        \\} from './foo';
        \\
        \\console.log(_aB, _Ab, aB, Ab);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(undefined,
//         "import {\n    Ab,\n    _Ab,\n    _aB,\n    aB,\n} from './foo';\n\nconsole.log(_aB, _Ab, aB, Ab);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSFalse,
//             .OrganizeImportsCollation =  lsutil.OrganizeImportsCollationOrdinal,
//         },
//     );
    // f.VerifyOrganizeImports(undefined,
//         "import {\n    _aB,\n    _Ab,\n    aB,\n    Ab,\n} from './foo';\n\nconsole.log(_aB, _Ab, aB, Ab);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSFalse,
//             .OrganizeImportsCollation =  lsutil.OrganizeImportsCollationUnicode,
//         },
//     );
}

test "TestGetJavaScriptSyntacticDiagnostics12" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\declare var v;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestCompletionEntryForClassMembers_StaticWhenBaseTypeIsNotResolved" {
    const content =
        \\// @Filename: /a.ts
        \\import React from 'react'
        \\class Slider extends React.Component {
        \\    static defau/**/ltProps = {
        \\        onMouseDown: () => { },
        \\        onMouseUp: () => { },
        \\        unit: 'px',
        \\    }
        \\    handleChange = () => 10;
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
//             .Exact = CompletionClassElementKeywords,
//         },
//     });
}

test "TestImportNameCodeFixNewImportNodeModules3" {
    const content =
        \\// @Filename: /a.ts
        \\[|f1/*0*/();|]
        \\// @Filename: /node_modules/@types/random/index.d.ts
        \\export var v1 = 5;
        \\export function f1();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from \"random\";\n\nf1();",
    }, null );
}

test "TestFindAllRefsReExportStar" {
    const content =
        \\// @Filename: /a.ts
        \\export function /*0*/foo(): void {}
        \\// @Filename: /b.ts
        \\export * from "./a";
        \\// @Filename: /c.ts
        \\import { /*1*/foo } from "./b";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyBaselineFindAllReferences(undefined, "0", "1");
}

test "TestOrganizeImports17" {
    const content =
        \\import { Both } from "module-specifiers-unsorted";
        \\import { aa, CaseInsensitively, sorted } from "aardvark";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(undefined,
//         "import { aa, CaseInsensitively, sorted } from \"aardvark\";\nimport { Both } from \"module-specifiers-unsorted\";\n",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSUnknown,
//         },
//     );
}

test "TestImportNameCodeFixExistingImport10" {
    const content =
        \\import [|{
        \\    v1,
        \\    v2
        \\}|] from "./module";
        \\f1/*0*/();
        \\// @Filename: module.ts
        \\export function f1() {}
        \\export var v1 = 5;
        \\export var v2 = 5;
        \\export var v3 = 5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "{\n    f1,\n    v1,\n    v2\n}",
    }, null );
}

test "TestCodeFixClassImplementClassPropertyTypeQuery" {
    const content =
        \\// @strict: false
        \\class A {
        \\    A: typeof A;
        \\}
        \\class D implements A {[| |]}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'A'",
        .NewFileContent = "class A {\n    A: typeof A;\n}\nclass D implements A {\n    A: typeof A;\n}",
        .Index = 0,
    });
}

test "TestFindAllRefsOfConstructor_withModifier" {
    const content =
        \\class X {
        \\    public /*0*/constructor() {}
        \\}
        \\var x = new X();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "0");
}

test "TestQuickInfoForArgumentsPropertyNameInJsMode1" {
    const content =
        \\// @allowJs: true
        \\// @filename: a.js
        \\const foo = {
        \\    f1: (params) => { }
        \\}
        \\
        \\function /*1*/f2(x) {
        \\   foo.f1({ x, arguments: [] });
        \\}
        \\
        \\/*2*/f2('');
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestGoToDefinitionJsDocImportTag3" {
    const content =
        \\// @allowJS: true
        \\// @checkJs: true
        \\// @Filename: /b.ts
        \\/*2*/export interface A { }
        \\// @Filename: /a.js
        \\/**
        \\ * @import { A } [|from     /*1*/|] "./b";
        \\ */
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestCompletionListInObjectBindingPattern15" {
    const content =
        \\class Foo {
        \\    private   xxx1 = 1;
        \\    protected xxx2 = 2;
        \\    public    xxx3 = 3;
        \\    private   static xxx4 = 4;
        \\    protected static xxx5 = 5;
        \\    public    static xxx6 = 6;
        \\    foo() {
        \\        const { /*1*/ } = this;
        \\        const { /*2*/ } = Foo;
        \\    }
        \\}
        \\
        \\const { /*3*/ } = new Foo();
        \\const { /*4*/ } = Foo;
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
//             .Unsorted = &.{
//                 "xxx1",
//                 "xxx2",
//                 "xxx3",
//                 "foo",
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
//             .Unsorted = &.{
//                 "prototype",
//                 "xxx4",
//                 "xxx5",
//                 "xxx6",
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
//             .Unsorted = &.{
//                 "xxx3",
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
//             .Unsorted = &.{
//                 "prototype",
//                 "xxx6",
//             },
//         },
//     });
}

test "TestQuickInfoFromContextualType" {
    const content =
        \\// @Filename: quickInfoExportAssignmentOfGenericInterface_0.ts
        \\interface I {
        \\    /** Documentation */
        \\    x: number;
        \\}
        \\const i: I = { /**/x: 0 };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "(property) I.x: number", "Documentation");
}

test "TestRenameLabel4" {
    const content =
        \\loop:
        \\for (let i = 0; i <= 10; i++) {
        \\   if (i === 0) continue loop;
        \\   if (i === 1) continue /**/loop;
        \\   if (i === 10) break loop;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , "");
}

test "TestJsxFindAllReferencesOnRuntimeImportWithPaths1" {
    const content =
        \\// @Filename: project/src/foo.ts
        \\import * as x from /**/"@foo/dir/jsx-runtime";
        \\// @Filename: project/src/bar.tsx
        \\export default <div></div>;
        \\// @Filename: project/src/baz.tsx
        \\export default <></>;
        \\// @Filename: project/src/bam.tsx
        \\export default <script src=""/>;
        \\// @Filename: project/src/bat.tsx
        \\export const a = 1;
        \\// @Filename: project/src/bal.tsx
        \\
        \\// @Filename: project/src/dir/jsx-runtime.ts
        \\export {}
        \\// @Filename: project/tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "moduleResolution": "node",
        \\        "module": "es2020",
        \\        "jsx": "react-jsx",
        \\        "jsxImportSource": "@foo/dir",
        \\        "moduleDetection": "force",
        \\        "paths": {
        \\            "@foo/dir/jsx-runtime": ["./src/dir/jsx-runtime"]
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestCodeFixClassImplementInterfaceMultipleSignaturesRest1" {
    const content =
        \\interface I {
        \\    method(a: number, ...b: string[]): boolean;
        \\    method(a: string, ...b: number[]): Function;
        \\    method(a: string): Function;
        \\}
        \\
        \\class C implements I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "interface I {\n    method(a: number, ...b: string[]): boolean;\n    method(a: string, ...b: number[]): Function;\n    method(a: string): Function;\n}\n\nclass C implements I {\n    method(a: number, ...b: string[]): boolean;\n    method(a: string, ...b: number[]): Function;\n    method(a: string): Function;\n    method(a: unknown, ...b?: unknown[]): boolean | Function {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestQuickInfoDisplayPartsClassProperty" {
    const content =
        \\class c {
        \\    public /*1*/publicProperty: string;
        \\    private /*2*/privateProperty: string;
        \\    protected /*21*/protectedProperty: string;
        \\    static /*3*/staticProperty: string;
        \\    private static /*4*/privateStaticProperty: string;
        \\    protected static /*41*/protectedStaticProperty: string;
        \\    method() {
        \\        this./*5*/publicProperty;
        \\        this./*6*/privateProperty;
        \\        this./*61*/protectedProperty;
        \\        c./*7*/staticProperty;
        \\        c./*8*/privateStaticProperty;
        \\        c./*81*/protectedStaticProperty;
        \\    }
        \\}
        \\var cInstance = new c();
        \\/*9*/cInstance./*10*/publicProperty;
        \\/*11*/c./*12*/staticProperty;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestGoToDefinitionSwitchCase4" {
    const content =
        \\     switch (null) {
        \\         case null: break;
        \\     }
        \\
        \\     switch (null) {
        \\        [|/*start*/case|] null: break;
        \\     }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "start");
}

test "TestEmptyArrayInference" {
    const content =
        \\// @strict: false
        \\var x/*1*/x = true ? [1] : [undefined]; 
        \\var y/*2*/y = true ? [1] : [];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var xx: number[]", "");
    // f.VerifyQuickInfoAt(undefined, "2", "var yy: number[]", "");
}

test "TestCompletionListInObjectLiteral6" {
    const content =
        \\const foo = {
        \\    a: "a",
        \\    b: "b"
        \\};
        \\function fn<T extends { [key: string]: any }>(obj: T, events: { [Key in 
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
//                 &.{
//                     .Label =      "on_a?",
//                     .InsertText = undefined("on_a"),
//                     .FilterText = undefined("on_a"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =      "on_b?",
//                     .InsertText = undefined("on_b"),
//                     .FilterText = undefined("on_b"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
}

test "TestCodeFixClassImplementInterfaceConstructSignature" {
    const content =
        \\interface I {
        \\    new (x: number, b: string);
        \\}
        \\class C implements I {[| |]}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestFindAllReferencesFromLinkTagReference4" {
    const content =
        \\enum E {
        \\    /** {@link /**/B} */
        \\    A,
        \\    B
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestGoToDefinitionShorthandProperty04" {
    const content =
        \\interface Foo {
        \\    /*2*/foo(): void
        \\}
        \\
        \\let x: Foo = {
        \\    [|f/*1*/oo|]
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestImportNameCodeFix_defaultExport" {
    const content =
        \\// @module: esnext
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /a.js
        \\class C {}
        \\export default C;
        \\// @Filename: /b.js
        \\[|C;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.js");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import C from \"./a\";\n\nC;",
    }, null );
}

test "TestTrailingCommaSignatureHelp" {
    const content =
        \\function str(n: number): string;
        \\/**
        \\ * Stringifies a number with radix
        \\ * @param radix The radix
        \\ */
        \\function str(n: number, radix: number): string;
        \\function str(n: number, radix?: number): string { return ""; }
        \\
        \\str(1, /*a*/)
        \\
        \\declare function f<T>(a: T): T;
        \\f(2, /*b*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSignatureHelp(undefined);
}

test "TestNavigationItemsExportDefaultExpression" {
    const content =
        \\export default function () {}
        \\export default function () {
        \\    return class Foo {
        \\    }
        \\}
        \\
        \\export default () => ""
        \\export default () => {
        \\    return class Foo {
        \\    }
        \\}
        \\
        \\export default function f1() {}
        \\export default function f2() {
        \\    return class Foo {
        \\    }
        \\}
        \\
        \\const abc = 12;
        \\export default abc;
        \\export default class AB {}
        \\export default {
        \\    a: 1,
        \\    b: 1,
        \\    c: {
        \\        d: 1
        \\    }
        \\}
        \\
        \\function foo(props: { x: number; y: number }) {}
        \\export default foo({ x: 1, y: 1 });
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestGetJavaScriptSyntacticDiagnostics3" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\class C<T> { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestCompletionsLiteralMatchingGenericSignature" {
    const content =
        \\// @Filename: /a.tsx
        \\declare function bar1<P extends "" | "bar" | "baz">(p: P): void;
        \\
        \\bar1("/*ts*/")
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"ts"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "",
//                 "bar",
//                 "baz",
//             },
//         },
//     });
}

test "TestFindAllRefsForComputedProperties2" {
    const content =
        \\interface I {
        \\    [/*1*/42](): void;
        \\}
        \\
        \\class C implements I {
        \\    [/*2*/42]: any;
        \\}
        \\
        \\var x: I = {
        \\    ["/*3*/42"]: function () { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestSuperInsideInnerClass" {
    const content =
        \\class Base {
        \\    constructor(n: number) {
        \\    }
        \\}
        \\class Derived extends Base {
        \\    constructor() {
        \\        class Nested {
        \\            [super(/*1*/)] = 11111
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyNoSignatureHelpForMarkers(undefined, "1");
}

test "TestRewriteRelativeImportExtensionsProjectReferences1" {
    const content =
        \\// @Filename: packages/common/tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "lib": ["es5"],
        \\        "composite": true,
        \\        "rootDir": "src",
        \\        "outDir": "dist",
        \\        "module": "nodenext",
        \\        "resolveJsonModule": false,
        \\    }
        \\}
        \\// @Filename: packages/common/package.json
        \\{
        \\    "name": "common",
        \\    "version": "1.0.0",
        \\    "type": "module",
        \\    "exports": {
        \\        ".": {
        \\            "source": "./src/index.ts",
        \\            "default": "./dist/index.js"
        \\        }
        \\    }
        \\}
        \\// @Filename: packages/common/src/index.ts
        \\export {};
        \\// @Filename: packages/main/tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "module": "nodenext",
        \\        "rewriteRelativeImportExtensions": true,
        \\        "lib": ["es5"],
        \\        "rootDir": "src",
        \\        "outDir": "dist",
        \\        "resolveJsonModule": false,
        \\    },
        \\    "references": [
        \\        { "path": "../common" }
        \\    ]
        \\}
        \\// @Filename: packages/main/package.json
        \\{ "type": "module" }
        \\// @Filename: packages/main/src/index.ts
        \\import {} from "../../common/src/index.ts";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToFile(undefined, "/packages/main/src/index.ts");
    // f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestQuickInfoOnObjectLiteralWithOnlyGetter" {
    const content =
        \\function /*1*/makePoint(x: number) {
        \\    return {
        \\        get x() { return x; },
        \\    };
        \\};
        \\var /*4*/point = makePoint(2);
        \\var /*2*/x = point./*3*/x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "function makePoint(x: number): {\n    readonly x: number;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "2", "var x: number", "");
    // f.VerifyQuickInfoAt(undefined, "4", "var point: {\n    readonly x: number;\n}", "");
    // f.VerifyCompletions(undefined, "3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "x",
//                     .Detail = undefined("(property) x: number"),
//                 },
//             },
//         },
//     });
}

test "TestCodeFixClassImplementInterfaceWithAmbientSignatures3" {
    const content =
        \\declare abstract class A {
        \\    abstract method(): void;
        \\}
        \\class B implements A {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'A'",
        .NewFileContent = "declare abstract class A {\n    abstract method(): void;\n}\nclass B implements A {\n    method(): void {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestCodeFixAddParameterNames2" {
    const content =
        \\// @noImplicitAny: true
        \\type Rest = ([|...number|]) => void;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "...arg0: number[]", false, 0, 0);
}

test "TestNoCompletionsForCurrentOrLaterParametersInDefaults" {
    const content =
        \\function f1(a = /*1*/, b) { }
        \\function f2(a = a/*2*/, b) { }
        \\function f3(a = a + /*3*/, b = a/*4*/, c = /*5*/) { }
        \\function f3(a) {
        \\    function f4(b = /*6*/, c) { }
        \\}
        \\const f5 = (a, b = (c = /*7*/, e) => { }, d = b) => { }
        \\
        \\type A1<K = /*T1*/, L> = K
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
//             .Excludes = &.{
//                 "a",
//                 "b",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"3"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Excludes = &.{
//                 "a",
//                 "b",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"4"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "a",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"5"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "a",
//                 "b",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"6"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "a",
//             },
//             .Excludes = &.{
//                 "b",
//                 "c",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"7"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "a",
//                 "b",
//                 "d",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"T1"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Excludes = &.{
//                 "K",
//                 "L",
//             },
//         },
//     });
}

test "TestImportNameCodeFixReExport" {
    const content =
        \\// @Filename: /a.ts
        \\export const x = 0";
        \\// @Filename: /b.ts
        \\[|export { x } from "./a";
        \\x;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    _ = f.VerifyRangeAfterCodeFix(undefined, "import { x } from \"./a\";\n\nexport { x } from \"./a\";\nx;", true, 0, 0);
}

test "TestCompletionListAfterNumericLiteral" {
    const content =
        \\// @Filename: f1.ts
        \\0./*dotOnNumberExpressions1*/
        \\// @Filename: f2.ts
        \\0.0./*dotOnNumberExpressions2*/
        \\// @Filename: f3.ts
        \\0.0.0./*dotOnNumberExpressions3*/
        \\// @Filename: f4.ts
        \\0./** comment *//*dotOnNumberExpressions4*/
        \\// @Filename: f5.ts
        \\(0)./*validDotOnNumberExpressions1*/
        \\// @Filename: f6.ts
        \\(0.)./*validDotOnNumberExpressions2*/
        \\// @Filename: f7.ts
        \\(0.0)./*validDotOnNumberExpressions3*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, &.{"dotOnNumberExpressions1", "dotOnNumberExpressions4"}, null);
    // f.VerifyCompletions(undefined, &.{"dotOnNumberExpressions2", "dotOnNumberExpressions3", "validDotOnNumberExpressions1", "validDotOnNumberExpressions2", "validDotOnNumberExpressions3"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "toExponential",
//             },
//         },
//     });
}

test "TestGoToDefinitionInstanceof2" {
    const content =
        \\// @lib: esnext
        \\// @filename: /main.ts
        \\class C {
        \\  static /*end*/[Symbol.hasInstance](value: unknown): boolean { return true; }
        \\}
        \\declare var obj: any;
        \\obj [|/*start*/instanceof|] C;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "start");
}

test "TestDeleteModifierBeforeVarStatement1" {
    const content =
        \\
        \\
        \\/////////////////////////////
        \\/// Windows Script Host APIS
        \\/////////////////////////////
        \\
        \\declare var ActiveXObject: { new (s: string): any; };
        \\
        \\interface ITextWriter {
        \\    WriteLine(s): void;
        \\}
        \\
        \\declare var WScript: {
        \\    Echo(s): void;
        \\    StdErr: ITextWriter;
        \\    Arguments: { length: number; Item(): string; };
        \\    ScriptFullName: string;
        \\    Quit(): number;
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFileNumber(undefined, 0);
    _ = f.GoToPosition(undefined, 0);
    _ = f.DeleteAtCaret(undefined, 100);
    _ = f.GoToPosition(undefined, 198);
    _ = f.DeleteAtCaret(undefined, 16);
    _ = f.GoToPosition(undefined, 198);
    _ = f.Insert(undefined, "Item(): string; ");
}

test "TestSignatureHelpCommentsClassMembers" {
    const content =
        \\/** This is comment for c1*/
        \\class c1 {
        \\    /** p1 is property of c1*/
        \\    public p1: number;
        \\    /** sum with property*/
        \\    public p2(/** number to add*/b: number) {
        \\        return this.p1 + b;
        \\    }
        \\    /** getter property 1*/
        \\    public get p3() {
        \\        return this.p2(/*8*/this.p1);
        \\    }
        \\    /** setter property 1*/
        \\    public set p3(/** this is value*/value: number) {
        \\        this.p1 = this.p2(/*13*/value);
        \\    }
        \\    /** pp1 is property of c1*/
        \\    private pp1: number;
        \\    /** sum with property*/
        \\    private pp2(/** number to add*/b: number) {
        \\        return this.p1 + b;
        \\    }
        \\    /** getter property 2*/
        \\    private get pp3() {
        \\        return this.pp2(/*20*/this.pp1);
        \\    }
        \\    /** setter property 2*/
        \\    private set pp3( /** this is value*/value: number) {
        \\        this.pp1 = this.pp2(/*25*/value);
        \\    }
        \\    /** Constructor method*/
        \\    constructor() {
        \\    }
        \\    /** s1 is static property of c1*/
        \\    static s1: number;
        \\    /** static sum with property*/
        \\    static s2(/** number to add*/b: number) {
        \\        return c1.s1 + b;
        \\    }
        \\    /** static getter property*/
        \\    static get s3() {
        \\        return c1.s2(/*35*/c1.s1);
        \\    }
        \\    /** setter property 3*/
        \\    static set s3( /** this is value*/value: number) {
        \\        c1.s1 = c1.s2(/*42*/value);
        \\    }
        \\    public nc_p1: number;
        \\    public nc_p2(b: number) {
        \\        return this.nc_p1 + b;
        \\    }
        \\    public get nc_p3() {
        \\        return this.nc_p2(/*47*/this.nc_p1);
        \\    }
        \\    public set nc_p3(value: number) {
        \\        this.nc_p1 = this.nc_p2(/*49*/value);
        \\    }
        \\    private nc_pp1: number;
        \\    private nc_pp2(b: number) {
        \\        return this.nc_pp1 + b;
        \\    }
        \\    private get nc_pp3() {
        \\        return this.nc_pp2(/*54*/this.nc_pp1);
        \\    }
        \\    private set nc_pp3(value: number) {
        \\        this.nc_pp1 = this.nc_pp2(/*56*/value);
        \\    }
        \\    static nc_s1: number;
        \\    static nc_s2(b: number) {
        \\        return c1.nc_s1 + b;
        \\    }
        \\    static get nc_s3() {
        \\        return c1.nc_s2(/*61*/c1.nc_s1);
        \\    }
        \\    static set nc_s3(value: number) {
        \\        c1.nc_s1 = c1.nc_s2(/*63*/value);
        \\    }
        \\}
        \\var i1 = new c1(/*65*/);
        \\var i1_p = i1.p1;
        \\var i1_f = i1.p2;
        \\var i1_r = i1.p2(/*71*/20);
        \\var i1_prop = i1.p3;
        \\i1.p3 = i1_prop;
        \\var i1_nc_p = i1.nc_p1;
        \\var i1_ncf = i1.nc_p2;
        \\var i1_ncr = i1.nc_p2(/*81*/20);
        \\var i1_ncprop = i1.nc_p3;
        \\i1.nc_p3 = i1_ncprop;
        \\var i1_s_p = c1.s1;
        \\var i1_s_f = c1.s2;
        \\var i1_s_r = c1.s2(/*92*/20);
        \\var i1_s_prop = c1.s3;
        \\c1.s3 = i1_s_prop;
        \\var i1_s_nc_p = c1.nc_s1;
        \\var i1_s_ncf = c1.nc_s2;
        \\var i1_s_ncr = c1.nc_s2(/*102*/20);
        \\var i1_s_ncprop = c1.nc_s3;
        \\c1.nc_s3 = i1_s_ncprop;
        \\var i1_c = c1;
        \\
        \\class cProperties {
        \\    private val: number;
        \\    /** getter only property*/
        \\    public get p1() {
        \\        return this.val;
        \\    }
        \\    public get nc_p1() {
        \\        return this.val;
        \\    }
        \\    /**setter only property*/
        \\    public set p2(value: number) {
        \\        this.val = value;
        \\    }
        \\    public set nc_p2(value: number) {
        \\        this.val = value;
        \\    }
        \\}
        \\var cProperties_i = new cProperties();
        \\cProperties_i.p2 = cProperties_i.p1;
        \\cProperties_i.nc_p2 = cProperties_i.nc_p1;
        \\class cWithConstructorProperty {
        \\    /**
        \\    * this is class cWithConstructorProperty's constructor
        \\    * @param a this is first parameter a
        \\    */
        \\    constructor(/**more info about a*/public a: number) {
        \\        var bbbb = 10;
        \\        this.a = a + 2 + bbbb;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSignatureHelp(undefined);
}

test "TestCodeFixClassImplementInterfaceMultipleImplementsIntersection2" {
    const content =
        \\// @strict: false
        \\interface I1 {
        \\    x: number;
        \\}
        \\interface I2 {
        \\    x: string;
        \\}
        \\
        \\class C implements I1,I2 {
        \\    x: string;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestGetOccurrencesThrow5" {
    const content =
        \\function f(a: number) {
        \\    try {
        \\        throw "Hello";
        \\
        \\        try {
        \\            throw 10;
        \\        }
        \\        catch (x) {
        \\            return 100;
        \\        }
        \\        finally {
        \\            throw 10;
        \\        }
        \\    }
        \\    catch (x) {
        \\        throw "Something";
        \\    }
        \\    finally {
        \\        throw "Also something";
        \\    }
        \\    if (a > 0) {
        \\        return (function () {
        \\            return;
        \\            return;
        \\            return;
        \\
        \\            if (false) {
        \\                return true;
        \\            }
        \\            throw "Hello!";
        \\        })() || true;
        \\    }
        \\
        \\    throw 10;
        \\
        \\    var unusued = [1, 2, 3, 4].map(x => { [|thr/**/ow|] 4 })
        \\
        \\    return;
        \\    return true;
        \\    throw false;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestRemoveDeclareParamTypeAnnotation" {
    const content =
        \\declare class T { }
        \\declare function parseInt(/**/s:T):T;
        \\parseInt('2');
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.DeleteAtCaret(undefined, 3);
}

test "TestFormattingInDestructuring1" {
    const content =
        \\interface let { }
        \\/*1*/var x: let         [];
        \\
        \\function foo() {
        \\    'use strict'
        \\/*2*/    let        [x] = [];
        \\/*3*/    const      [x] = [];
        \\/*4*/    for (let[x] = [];x < 1;) {
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "var x: let[];");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "    let [x] = [];");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "    const [x] = [];");
    _ = f.GoToMarker(undefined, "4");
    _ = f.VerifyCurrentLineContent(undefined, "    for (let [x] = []; x < 1;) {");
}

test "TestNavigationBarPrivateName" {
    const content =
        \\class A {
        \\  #foo: () => {
        \\    class B {
        \\      #bar: () => {   
        \\         function baz () {
        \\         }
        \\      }
        \\    }
        \\  }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCompletionsOverridingMethod2" {
    const content =
        \\// @newline: LF
        \\// @Filename: a.ts
        \\interface DollarSign {
        \\    "$usd"(a: number): number;
        \\    $cad(b: number): number;
        \\    cla$$y(c: number): number;
        \\    isDollarAmountString(s: string): s is 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "a", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =            "$usd",
//                     .InsertText =       undefined("\"\\$usd\"(a: number): number {\n    $0\n}"),
//                     .FilterText =       undefined("$usd"),
//                     .SortText =         undefined(string(ls.SortTextLocationPriority)),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                 },
//                 &.{
//                     .Label =            "$cad",
//                     .InsertText =       undefined("\\$cad(b: number): number {\n    $0\n}"),
//                     .FilterText =       undefined("$cad"),
//                     .SortText =         undefined(string(ls.SortTextLocationPriority)),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                 },
//                 &.{
//                     .Label =            "cla$$y",
//                     .InsertText =       undefined("cla\\$\\$y(c: number): number {\n    $0\n}"),
//                     .FilterText =       undefined("cla$$y"),
//                     .SortText =         undefined(string(ls.SortTextLocationPriority)),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                 },
//                 &.{
//                     .Label =            "isDollarAmountString",
//                     .InsertText =       undefined("isDollarAmountString(s: string): s is `\\$\\${number}` {\n    $0\n}"),
//                     .FilterText =       undefined("isDollarAmountString"),
//                     .SortText =         undefined(string(ls.SortTextLocationPriority)),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                 },
//             },
//         },
//     });
}

test "TestGoToDefinitionDifferentFileIndirectly" {
    const content =
        \\// @Filename: Remote2.ts
        \\var /*remoteVariableDefinition*/rem2Var;
        \\function /*remoteFunctionDefinition*/rem2Fn() { }
        \\class /*remoteClassDefinition*/rem2Cls { }
        \\interface /*remoteInterfaceDefinition*/rem2Int{}
        \\module /*remoteModuleDefinition*/rem2Mod { export var foo; }
        \\// @Filename: Remote1.ts
        \\var remVar;
        \\function remFn() { }
        \\class remCls { }
        \\interface remInt{}
        \\namespace remMod { export var foo; }
        \\// @Filename: Definition.ts
        \\/*remoteVariableReference*/rem2Var = 1;
        \\/*remoteFunctionReference*/rem2Fn();
        \\var rem2foo = new /*remoteClassReference*/rem2Cls();
        \\class rem2fooCls implements /*remoteInterfaceReference*/rem2Int { }
        \\var rem2fooVar = /*remoteModuleReference*/rem2Mod.foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, false, "remoteVariableReference", "remoteFunctionReference", "remoteClassReference", "remoteInterfaceReference", "remoteModuleReference");
}

test "TestImportNameCodeFix_dollar" {
    const content =
        \\// @module: esnext
        \\// @moduleResolution: bundler
        \\// @Filename: /node_modules/qwik/index.d.ts
        \\export declare const $: any;
        \\// @Filename: /index.ts
        \\import {} from "qwik";
        \\$/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { $ } from \"qwik\";\n$",
    }, null );
}

test "TestImportFixes_ambientCircularDefaultCrash" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "preserve",
        \\    "lib": ["es5"]
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/types.d.ts
        \\declare module "mymod" {
        \\  import mymod from "mymod";
        \\  export default mymod;
        \\}
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\my/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyImportFixModuleSpecifiers(undefined, "", &.{}, null );
}

test "TestNavbar_const" {
    const content =
        \\const c = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestGoToImplementationNamespace_01" {
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

test "TestArgumentsAreAvailableAfterEditsAtEndOfFunction" {
    const content =
        \\namespace Test1 {
        \\    class Person {
        \\        children: string[];
        \\        constructor(public name: string, children: string[]) {
        \\            /**/
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "this.children = ch");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "children",
//                     .Detail = undefined("(parameter) children: string[]"),
//                 },
//             },
//         },
//     });
}

test "TestCompletionListInUnclosedFunction13" {
    const content =
        \\interface MyType {
        \\}
        \\
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string = "hello", c: typeof x = "hello") {
        \\        var v = (p: /*1*/
        \\    }
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
//                 "MyType",
//             },
//         },
//     });
}

test "TestGetOccurrencesClassExpressionStaticThis" {
    const content =
        \\var x = class C {
        \\    public x;
        \\    public y;
        \\    public z;
        \\    public staticX;
        \\    constructor() {
        \\        this;
        \\        this.x;
        \\        this.y;
        \\        this.z;
        \\    }
        \\    foo() {
        \\        this;
        \\        () => this;
        \\        () => {
        \\            if (this) {
        \\                this;
        \\            }
        \\        }
        \\        function inside() {
        \\            this;
        \\            (function (_) {
        \\                this;
        \\            })(this);
        \\        }
        \\        return this.x;
        \\    }
        \\
        \\    static bar() {
        \\        [|this|];
        \\        [|this|].staticX;
        \\        () => [|this|];
        \\        () => {
        \\            if ([|this|]) {
        \\                [|this|];
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
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestGoToTypeDefinitionModule" {
    const content =
        \\// @Filename: module1.ts
        \\module /*definition*/M {
        \\    export var p;
        \\}
        \\var m: typeof M;
        \\// @Filename: module3.ts
        \\/*reference1*/M;
        \\/*reference2*/m;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToTypeDefinition(undefined, "reference1", "reference2");
}

test "TestCompletionsImport_computedSymbolName" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{ "compilerOptions": { "module": "commonjs", "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/ts-node/index.d.ts
        \\export {};
        \\declare const REGISTER_INSTANCE: unique symbol;
        \\declare global {
        \\    namespace NodeJS {
        \\      interface Process {
        \\          [REGISTER_INSTANCE]?: Service;
        \\      }
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/node/index.d.ts
        \\declare module "process" {
        \\    global {
        \\        var process: NodeJS.Process;
        \\        namespace NodeJS {
        \\            interface Process {
        \\                argv: string[];
        \\            }
        \\        }
        \\    }
        \\    export = process;
        \\}
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\I/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{},
//     });
    _ = f.Insert(undefined, "N");
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{},
//     });
}

test "TestFormatInTryCatchFinally" {
    const content =
        \\try 
        \\{
        \\    var x = 1/*1*/
        \\}
        \\catch (e) 
        \\{
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, ";");
    _ = f.VerifyCurrentLineContent(undefined, "    var x = 1;");
}

test "TestGoToImplementationInterface_07" {
    const content =
        \\interface Fo/*interface_definition*/o {
        \\    hello (): void;
        \\}
        \\
        \\interface Bar {
        \\    hello (): void;
        \\}
        \\
        \\let x1: Foo            = [|{ hello ()          { /**typeReference*/ } }|];
        \\let x2: () => Foo      = [|(() => { hello ()   { /**functionType*/} })|];
        \\let x3: Foo | Bar      = [|{ hello ()          { /**unionType*/} }|];
        \\let x4: Foo & (Foo & Bar)      = [|{ hello ()          { /**intersectionType*/} }|];
        \\let x5: [Foo]          = [|[{ hello ()         { /**tupleType*/} }]|];
        \\let x6: (Foo)          = [|{ hello ()          { /**parenthesizedType*/} }|];
        \\let x7: (new() => Foo) = [|class { hello ()    { /**constructorType*/} }|];
        \\let x8: Foo[]          = [|[{ hello ()         { /**arrayType*/} }]|];
        \\let x9: { y: Foo }     = [|{ y: { hello ()     { /**typeLiteral*/} } }|];
        \\let x10 = [|{|"parts": ["(","anonymous local class",")"], "kind": "local class"|}class implements Foo { hello() {} }|]
        \\let x11 = class [|{|"parts": ["(","local class",")"," ","C"], "kind": "local class"|}C|] implements Foo { hello() {} }
        \\
        \\// Should not do anything for type predicates
        \\function isFoo(a: any): a is Foo {
        \\    return true;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "interface_definition");
}

test "TestCodeFixAwaitInSyncFunction3" {
    const content =
        \\const f = {
        \\    get a() {
        \\        return await Promise.resolve();
        \\    },
        \\    get a() {
        \\        await Promise.resolve();
        \\    },
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestCodeFixAddOptionalParam15" {
    const content =
        \\function f(a: number, b: number) {}
        \\f();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined, "addOptionalParam");
}

test "TestGoToDefinitionUnionTypeProperty2" {
    const content =
        \\interface HasAOrB {
        \\    /*propertyDefinition1*/a: string;
        \\    b: string;
        \\}
        \\
        \\interface One {
        \\    common: { /*propertyDefinition2*/a : number; };
        \\}
        \\
        \\interface Two {
        \\    common: HasAOrB;
        \\}
        \\
        \\var x : One | Two;
        \\
        \\x.common.[|/*propertyReference*/a|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "propertyReference");
}

test "TestNavbarNestedCommonJsExports" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\exports.a = exports.b = exports.c = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestJsDocIndentationPreservation3" {
    const content =
        \\// @allowJs: true
        \\// @Filename: Foo.js
        \\/**
        \\    Does some stuff.
        \\        Second line.
        \\        Third line.
        \\*/
        \\function foo/**/(){}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyQuickInfoIs(undefined, "function foo(): void", "Does some stuff.\n    Second line.\n\tThird line.");
}

test "TestCodeFixTopLevelForAwait_module_targetES2017CompilerOptionsInTsConfig" {
    const content =
        \\// @filename: /dir/a.ts
        \\declare const p: number[];
        \\for await (const _ of p);
        \\export {};
        \\// @filename: /dir/tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "target": "es2017"
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined, "fixTargetOption");
    _ = f.VerifyCodeFixAvailable(undefined, null);
}

test "TestCompletionListBeforeNewScope02" {
    const content =
        \\a/*1*/
        \\
        \\{
        \\    let aaaaaa = 10;
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
//             .Excludes = &.{
//                 "aaaaaa",
//             },
//         },
//     });
}

test "TestSmartSelection_stringLiteral" {
    const content =
        \\const a = 'a';
        \\const b = /**/'b';
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSelectionRanges(undefined);
}

test "TestCompletionForStringLiteral5" {
    const content =
        \\// @stableTypeOrdering: true
        \\interface Foo {
        \\    foo: string;
        \\    bar: string;
        \\}
        \\
        \\function f<K extends keyof Foo>(a: K) { };
        \\f("/*1*/
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
//                 "bar",
//                 "foo",
//             },
//         },
//     });
}

test "TestQuickInfoOnClassMergedWithFunction" {
    const content =
        \\namespace Test {
        \\    class Mocked {
        \\        myProp: string;
        \\    }
        \\    class Tester {
        \\        willThrowError() {
        \\            Mocked = Mocked || function () { // => Error: Invalid left-hand side of assignment expression.
        \\                return { /**/myProp: "test" };
        \\            };
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "(property) myProp: string", "");
}

test "TestGetOccurrencesReadonly3" {
    const content =
        \\class C {
        \\  [|readonly|] prop: /**/readonly string[] = [];
        \\  constructor([|readonly|] prop2: string) {
        \\    class D {
        \\      readonly prop: string = "";  
        \\    }
        \\  }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
    // f.VerifyBaselineDocumentHighlights(undefined, null , "");
}

test "TestCodeFixMissingTypeAnnotationOnExports35_variable_releative" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @Filename: /code.ts
        \\const foo = { a: 1 }
        \\export const exported = foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add annotation of type 'typeof foo'",
        .NewFileContent = "const foo = { a: 1 }\nexport const exported: typeof foo = foo;",
        .Index = 1,
    });
}

test "TestCompletionListAtNodeBoundary" {
    const content =
        \\interface Iterator<T, U> {
        \\    (value: T, index: any, list: any): U;
        \\}
        \\
        \\interface WrappedArray<T> {
        \\    map<U>(iterator: Iterator<T, U>, context?: any): U[];
        \\}
        \\
        \\interface Underscore {
        \\    <T>(list: T[]): WrappedArray<T>;
        \\    map<T, U>(list: T[], iterator: Iterator<T, U>, context?: any): U[];
        \\}
        \\
        \\declare var _: Underscore;
        \\var a: string[];
        \\var e = a.map(x => x./**/);
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
//                 "charAt",
//             },
//         },
//     });
}

test "TestQuickInfoOnCircularTypes" {
    const content =
        \\interface A { (): B; };
        \\declare var a: A;
        \\var xx = a();
        \\
        \\interface B { (): C; };
        \\declare var b: B;
        \\var yy = b();
        \\
        \\interface C { (): A; };
        \\declare var c: C;
        \\var zz = c();
        \\
        \\x/*B*/x = y/*C*/y;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "B", "var xx: B", "");
    // f.VerifyQuickInfoAt(undefined, "C", "var yy: C", "");
}

test "TestCodeFixClassSuperMustPrecedeThisAccess_callWithThisInside" {
    const content =
        \\class Base{
        \\    constructor(id: number) { id; }
        \\}
        \\class C extends Base{
        \\    constructor(private a:number) {
        \\        super(this.a);
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestGoToDefinitionOverriddenMember1" {
    const content =
        \\// @noImplicitOverride: true
        \\class Foo {
        \\    /*2*/p = '';
        \\}
        \\class Bar extends Foo {
        \\    [|/*1*/override|] p = '';
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestInlayHintsOverloadCall1" {
    const content =
        \\interface Call {
        \\    (a: number): void
        \\    (b: number, c: number): void
        \\    new (d: number): Call
        \\}
        \\declare const call: Call;
        \\call(1);
        \\call(1, 2);
        \\new call(1);
        \\declare function foo(w: number): void
        \\declare function foo(a: number, b: number): void;
        \\declare function foo(a: number | undefined, b: number | undefined): void;
        \\foo(1)
        \\foo(1, 2)
        \\class Class {
        \\    constructor(a: number);
        \\    constructor(b: number, c: number);
        \\    constructor(b: number, c?: number) { }
        \\}
        \\new Class(1)
        \\new Class(1, 2)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayParameterNameHints = lsutil.IncludeInlayParameterNameHintsLiterals}});
}

test "TestImportValueUsedAsType" {
    const content =
        \\/**/
        \\namespace A {
        \\    export var X;
        \\    import Z = A.X;
        \\    var v: Z;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, " ");
}

test "TestGetOccurrencesDeclare3" {
    const content =
        \\
        \\[|declare|] var x;
        \\export [|declare|] var y, z;
        \\
        \\namespace m {
        \\    export class C1 {
        \\        public pub1;
        \\        public pub2;
        \\        private priv1;
        \\        private priv2;
        \\        protected prot1;
        \\        protected prot2;
        \\
        \\        public public;
        \\        private private;
        \\        protected protected;
        \\
        \\        public constructor(public a, private b, protected c, public d, private e, protected f) {
        \\            this.public = 10;
        \\            this.private = 10;
        \\            this.protected = 10;
        \\        }
        \\
        \\        public get x() { return 10; }
        \\        public set x(value) { }
        \\
        \\        public static statPub;
        \\        private static statPriv;
        \\        protected static statProt;
        \\    }
        \\
        \\    export interface I1 {
        \\    }
        \\
        \\    export declare namespace ma.m1.m2.m3 {
        \\        interface I2 {
        \\        }
        \\    }
        \\
        \\    export namespace mb.m1.m2.m3 {
        \\        declare var foo;
        \\
        \\        export class C2 {
        \\            public pub1;
        \\            private priv1;
        \\            protected prot1;
        \\
        \\            protected constructor(public public, protected protected, private private) {
        \\            }
        \\        }
        \\    }
        \\
        \\    declare var ambientThing: number;
        \\    export var exportedThing = 10;
        \\    declare function foo(): string;
        \\}
        \\
        \\[|declare|] export var v1, v2;
        \\[|declare|] namespace dm { }
        \\export class EC { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestJsxAttributeSnippetCompletionUnclosed" {
    const content =
        \\// @strict: false
        \\//@Filename: file.tsx
        \\interface NestedInterface {
        \\    Foo: NestedInterface;
        \\    (props: {className?: string}): any;
        \\}
        \\
        \\declare const Foo: NestedInterface;
        \\
        \\function fn1() {
        \\    return <Foo>
        \\        <Foo /*1*/
        \\    </Foo>
        \\}
        \\function fn2() {
        \\    return <Foo>
        \\        <Foo.Foo /*2*/
        \\    </Foo>
        \\}
        \\function fn3() {
        \\    return <Foo>
        \\        <Foo.Foo cla/*3*/
        \\    </Foo>
        \\}
        \\function fn4() {
        \\    return <Foo>
        \\        <Foo.Foo cla/*4*/ something
        \\    </Foo>
        \\}
        \\function fn5() {
        \\    return <Foo>
        \\        <Foo.Foo something /*5*/
        \\    </Foo>
        \\}
        \\function fn6() {
        \\    return <Foo>
        \\        <Foo.Foo something cla/*6*/
        \\    </Foo>
        \\}
        \\function fn7() {
        \\    return <Foo /*7*/
        \\}
        \\function fn8() {
        \\    return <Foo cla/*8*/
        \\}
        \\function fn9() {
        \\    return <Foo cla/*9*/ something
        \\}
        \\function fn10() {
        \\    return <Foo something /*10*/
        \\}
        \\function fn11() {
        \\    return <Foo something cla/*11*/
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
//                 &.{
//                     .Label =            "className?",
//                     .InsertText =       undefined("className={$1}"),
//                     .FilterText =       undefined("className"),
//                     .Detail =           undefined("(property) className?: string"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .SortText =         undefined(string(ls.SortTextOptionalMember)),
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
//             .Includes = &.{
//                 &.{
//                     .Label =            "className?",
//                     .InsertText =       undefined("className={$1}"),
//                     .FilterText =       undefined("className"),
//                     .Detail =           undefined("(property) className?: string"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .SortText =         undefined(string(ls.SortTextOptionalMember)),
//                 },
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
//                     .Label =            "className?",
//                     .InsertText =       undefined("className={$1}"),
//                     .FilterText =       undefined("className"),
//                     .Detail =           undefined("(property) className?: string"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .SortText =         undefined(string(ls.SortTextOptionalMember)),
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
//                     .Label =            "className?",
//                     .InsertText =       undefined("className={$1}"),
//                     .FilterText =       undefined("className"),
//                     .Detail =           undefined("(property) className?: string"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .SortText =         undefined(string(ls.SortTextOptionalMember)),
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
//                     .Label =            "className?",
//                     .InsertText =       undefined("className={$1}"),
//                     .FilterText =       undefined("className"),
//                     .Detail =           undefined("(property) className?: string"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .SortText =         undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "6", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =            "className?",
//                     .InsertText =       undefined("className={$1}"),
//                     .FilterText =       undefined("className"),
//                     .Detail =           undefined("(property) className?: string"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .SortText =         undefined(string(ls.SortTextOptionalMember)),
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
//                     .Label =            "className?",
//                     .InsertText =       undefined("className={$1}"),
//                     .FilterText =       undefined("className"),
//                     .Detail =           undefined("(property) className?: string"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .SortText =         undefined(string(ls.SortTextOptionalMember)),
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
//                     .Label =            "className?",
//                     .InsertText =       undefined("className={$1}"),
//                     .FilterText =       undefined("className"),
//                     .Detail =           undefined("(property) className?: string"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .SortText =         undefined(string(ls.SortTextOptionalMember)),
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
//                     .Label =            "className?",
//                     .InsertText =       undefined("className={$1}"),
//                     .FilterText =       undefined("className"),
//                     .Detail =           undefined("(property) className?: string"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .SortText =         undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "10", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =            "className?",
//                     .InsertText =       undefined("className={$1}"),
//                     .FilterText =       undefined("className"),
//                     .Detail =           undefined("(property) className?: string"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .SortText =         undefined(string(ls.SortTextOptionalMember)),
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
//                     .Label =            "className?",
//                     .InsertText =       undefined("className={$1}"),
//                     .FilterText =       undefined("className"),
//                     .Detail =           undefined("(property) className?: string"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .SortText =         undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
}

test "TestIncrementalParsingInsertIntoMethod1" {
    const content =
        \\class C {
        \\    public foo1() { }
        \\    public foo2() {
        \\        return 1/*1*/;
        \\    }
        \\    public foo3() { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, " + 1");
}

test "TestGoToDefinitionShorthandProperty02" {
    const content =
        \\let x = {
        \\    [|f/*1*/oo|]
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestImportNameCodeFixNewImportAllowSyntheticDefaultImports0" {
    const content =
        \\// @AllowSyntheticDefaultImports: true
        \\// @Filename: a/f1.ts
        \\[|export var x = 0;
        \\bar/*0*/();|]
        \\// @Filename: a/foo.d.ts
        \\declare function bar(): number;
        \\export = bar;
        \\export as namespace bar;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import bar from \"./foo\";\n\nexport var x = 0;\nbar();",
    }, null );
}

test "TestGoToDefinitionObjectLiteralProperties" {
    const content =
        \\var o = {
        \\    /*valueDefinition*/value: 0,
        \\    get /*getterDefinition*/getter() {return 0 },
        \\    set /*setterDefinition*/setter(v: number) { },
        \\    /*methodDefinition*/method: () => { },
        \\    /*es6StyleMethodDefinition*/es6StyleMethod() { }
        \\};
        \\
        \\o./*valueReference*/value;
        \\o./*getterReference*/getter;
        \\o./*setterReference*/setter;
        \\o./*methodReference*/method;
        \\o./*es6StyleMethodReference*/es6StyleMethod;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, false, "valueReference", "getterReference", "setterReference", "methodReference", "es6StyleMethodReference");
}

test "TestQuickinfoVerbosityFunction" {
    const content =
        \\interface Apple {
        \\    color: string;
        \\    size: number;
        \\}
        \\interface Orchard {
        \\    takeOneApple(a: Apple): void;
        \\    getApple(): Apple;
        \\    getApple(size: number): Apple[];
        \\}
        \\const o/*o*/: Orchard = {} as any;
        \\declare function isApple/*f*/(x: unknown): x is Apple;
        \\type SomeType = {
        \\    prop1: string;
        \\}
        \\function someFun(a: SomeType): SomeType {
        \\    return a;
        \\}
        \\someFun/*s*/.what = 'what';
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"o" = .{0, 1, 2}, .@"f" = .{0, 1}, .@"s" = .{0, 1}});
}

test "TestThisPredicateFunctionQuickInfo01" {
    const content =
        \\class FileSystemObject {
        \\    /*1*/isFile(): this is Item {
        \\        return this instanceof Item;
        \\    }
        \\    /*2*/isDirectory(): this is Directory {
        \\        return this instanceof Directory;
        \\    }
        \\    /*3*/isNetworked(): this is (Networked & this) {
        \\       return !!(this as Networked).host;
        \\    }
        \\    constructor(public path: string) {}
        \\}
        \\
        \\class Item extends FileSystemObject {
        \\    constructor(path: string, public content: string) { super(path); }
        \\}
        \\class Directory extends FileSystemObject {
        \\    children: FileSystemObject[];
        \\}
        \\interface Networked {
        \\    host: string;
        \\}
        \\
        \\const obj: FileSystemObject = new Item("/foo", "");
        \\if (obj.isFile/*4*/()) {
        \\    obj.;
        \\    if (obj.isNetworked/*5*/()) {
        \\        obj.;
        \\    }
        \\}
        \\if (obj.isDirectory/*6*/()) {
        \\    obj.;
        \\    if (obj.isNetworked/*7*/()) {
        \\        obj.;
        \\    }
        \\}
        \\if (obj.isNetworked/*8*/()) {
        \\    obj.;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(method) FileSystemObject.isFile(): this is Item", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(method) FileSystemObject.isDirectory(): this is Directory", "");
    // f.VerifyQuickInfoAt(undefined, "3", "(method) FileSystemObject.isNetworked(): this is (Networked & this)", "");
    // f.VerifyQuickInfoAt(undefined, "4", "(method) FileSystemObject.isFile(): this is Item", "");
    // f.VerifyQuickInfoAt(undefined, "5", "(method) FileSystemObject.isNetworked(): this is (Networked & Item)", "");
    // f.VerifyQuickInfoAt(undefined, "6", "(method) FileSystemObject.isDirectory(): this is Directory", "");
    // f.VerifyQuickInfoAt(undefined, "7", "(method) FileSystemObject.isNetworked(): this is (Networked & Directory)", "");
    // f.VerifyQuickInfoAt(undefined, "8", "(method) FileSystemObject.isNetworked(): this is (Networked & FileSystemObject)", "");
}

test "TestCloduleAsBaseClass" {
    const content =
        \\// @lib: es5
        \\// @strict: false
        \\class A {
        \\    constructor(x: number) { }
        \\    foo() { }
        \\    static bar() { }
        \\}
        \\
        \\namespace A {
        \\    export var x = 1;
        \\    export function baz() { }
        \\}
        \\
        \\class D extends A {
        \\    constructor() {
        \\        super(1);
        \\    }
        \\    foo2() { }
        \\    static bar2() { }
        \\}
        \\
        \\var d: D;
        \\d./*1*/
        \\D./*2*/
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
//                 "foo",
//                 "foo2",
//             },
//         },
//     });
    _ = f.Insert(undefined, "foo()");
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionFunctionMembersPlus(
//                 &.{
//                     &.{
//                         .Label =    "bar",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "bar2",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "baz",
//                         .SortText = undefined(string(ls.SortTextLocationPriority)),
//                     },
//                     &.{
//                         .Label =    "prototype",
//                         .SortText = undefined(string(ls.SortTextLocationPriority)),
//                     },
//                     &.{
//                         .Label =    "x",
//                         .SortText = undefined(string(ls.SortTextLocationPriority)),
//                     },
//                 },
//             ),
//         },
//     });
    _ = f.Insert(undefined, "bar()");
    _ = f.VerifyNoErrors(undefined);
}

test "TestQuickInfoOnFunctionPropertyReturnedFromGenericFunction2" {
    const content =
        \\function createProps<T>(t: T) {
        \\  const getProps = function() {}
        \\  const createVariants = function() {}
        \\
        \\  getProps.createVariants = createVariants;
        \\  return getProps;
        \\}
        \\
        \\createProps({})./**/createVariants();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "(property) getProps<{}>.createVariants: () => void", "");
}

test "TestDoubleUnderscoreRenames" {
    const content =
        \\// @Filename: fileA.ts
        \\[|export function [|{| "contextRangeIndex": 0 |}__foo|]() {
        \\}|]
        \\
        \\// @Filename: fileB.ts
        \\[|import { [|{| "contextRangeIndex": 2 |}__foo|] as bar } from "./fileA";|]
        \\
        \\bar();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "__foo");
}

test "TestImportTypeCompletions4" {
    const content =
        \\// @esModuleInterop: true
        \\// @Filename: /foo.ts
        \\interface Foo { };
        \\export = Foo;
        \\// @Filename: /bar.ts
        \\ [|import type f/**/|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/bar.ts");
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "Foo",
//                     .InsertText = undefined("import type Foo from \"./foo\";"),
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./foo",
//                         },
//                     },
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "Foo",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestJsdocParamTagSpecialKeywords" {
    const content =
        \\// @lib: es5
        \\// @allowNonTsExtensions: true
        \\// @Filename: test.js
        \\/**
        \\ * @param {string} type
        \\ */
        \\function test(type) {
        \\    type./**/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "charAt",
//             },
//         },
//     });
}

test "TestGetOccurrencesYield" {
    const content =
        \\function* f() {
        \\ [|yield|] 100;
        \\ [|y/**/ield|] [|yield|] 200;
        \\  class Foo {
        \\      *memberFunction() {
        \\          return yield 1;
        \\      }
        \\  }
        \\  return function* g() {
        \\    yield 1;
        \\  }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestFindReferencesDefinitionDisplayParts" {
    const content =
        \\class Gre/*1*/eter {
        \\    someFunction() { th/*2*/is;  }
        \\}
        \\
        \\type Options = "opt/*3*/ion 1" | "option 2";
        \\let myOption: Options = "option 1";
        \\
        \\some/*4*/Label:
        \\break someLabel;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestFindAllRefsExportAsNamespace" {
    const content =
        \\// @Filename: /node_modules/a/index.d.ts
        \\export function /*0*/f(): void;
        \\export as namespace A;
        \\// @Filename: /b.ts
        \\import { /*1*/f } from "a";
        \\// @Filename: /c.ts
        \\A./*2*/f();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2");
}

test "TestCompletionForStringLiteralRelativeImport6" {
    const content =
        \\// @rootDirs: /repo/src1,/repo/src2/,/repo/generated1,/repo/generated2/
        \\// @Filename: /repo/src1/test1.ts
        \\import * as foo1 from "./dir//*import_as1*/
        \\import foo2 = require("./dir//*import_equals1*/
        \\var foo3 = require("./dir//*require1*/
        \\// @Filename: /repo/src2/test2.ts
        \\import * as foo1 from "./dir//*import_as2*/
        \\import foo2 = require("./dir//*import_equals2*/
        \\var foo3 = require("./dir//*require2*/
        \\// @Filename: /repo/generated1/dir/f1.ts
        \\/*f1*/
        \\// @Filename: /repo/generated2/dir/f2.ts
        \\/*f2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"import_as1", "import_equals1", "require1"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "f1",
//                 "f2",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"import_as2", "import_equals2", "require2"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "f1",
//                 "f2",
//             },
//         },
//     });
}

test "TestGetOccurrencesConstructor2" {
    const content =
        \\class C {
        \\    constructor();
        \\    constructor(x: number);
        \\    constructor(y: string, x: number);
        \\    constructor(a?: any, ...r: any[]) {
        \\        if (a === undefined && r.length === 0) {
        \\            return;
        \\        }
        \\
        \\        return;
        \\    }
        \\}
        \\
        \\class D {
        \\    [|con/**/structor|](public x: number, public y: number) {
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestCompletionListForRest" {
    const content =
        \\interface Gen {
        \\    x: number;
        \\    parent: Gen;
        \\    millenial: string;
        \\}
        \\let t: Gen;
        \\var { x, ...rest } = t;
        \\rest./*1*/x;
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
//                     .Label =  "millenial",
//                     .Detail = undefined("(property) Gen.millenial: string"),
//                 },
//                 &.{
//                     .Label =  "parent",
//                     .Detail = undefined("(property) Gen.parent: Gen"),
//                 },
//             },
//         },
//     });
}

test "TestInvertedFunduleAfterQuickInfo" {
    const content =
        \\namespace M {
        \\    namespace A {
        \\        var o;
        \\    }
        \\    function A(/**/x: number): void { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyQuickInfoExists(undefined);
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestGoToDefinitionShorthandProperty03" {
    const content =
        \\var /*varDef*/x = {
        \\    [|/*varProp*/x|]
        \\}
        \\let /*letDef*/y = {
        \\    [|/*letProp*/y|]
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "varProp", "letProp");
}

test "TestNgProxy4" {
    const content =
        \\// @Filename: tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "lib": ["es5"],
        \\        "plugins": [
        \\            { "name": "diagnostic-adder" }
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
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestCodeFixTopLevelAwait_module_noTsConfig" {
    const content =
        \\// @filename: /dir/a.ts
        \\declare const p: Promise<number>;
        \\await p;
        \\export {};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined, "fixModuleOption");
}

test "TestFormattingOnVariety" {
    const content =
        \\function f(a,b,c,d){/*1*/
        \\for(var i=0;i<10;i++){/*2*/
        \\var a=0;/*3*/
        \\var b=a+a+a*a%a/2-1;/*4*/
        \\b+=a;/*5*/
        \\++b;/*6*/
        \\f(a,b,c,d);/*7*/
        \\if(1===1){/*8*/
        \\var m=function(e,f){/*9*/
        \\return e^f;/*10*/
        \\}/*11*/
        \\}/*12*/
        \\}/*13*/
        \\}/*14*/
        \\
        \\for (var i = 0   ; i < this.foo(); i++) {/*15*/
        \\}/*16*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "function f(a, b, c, d) {");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "    for (var i = 0; i < 10; i++) {");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "        var a = 0;");
    _ = f.GoToMarker(undefined, "4");
    _ = f.VerifyCurrentLineContent(undefined, "        var b = a + a + a * a % a / 2 - 1;");
    _ = f.GoToMarker(undefined, "5");
    _ = f.VerifyCurrentLineContent(undefined, "        b += a;");
    _ = f.GoToMarker(undefined, "6");
    _ = f.VerifyCurrentLineContent(undefined, "        ++b;");
    _ = f.GoToMarker(undefined, "7");
    _ = f.VerifyCurrentLineContent(undefined, "        f(a, b, c, d);");
    _ = f.GoToMarker(undefined, "8");
    _ = f.VerifyCurrentLineContent(undefined, "        if (1 === 1) {");
    _ = f.GoToMarker(undefined, "9");
    _ = f.VerifyCurrentLineContent(undefined, "            var m = function(e, f) {");
    _ = f.GoToMarker(undefined, "10");
    _ = f.VerifyCurrentLineContent(undefined, "                return e ^ f;");
    _ = f.GoToMarker(undefined, "11");
    _ = f.VerifyCurrentLineContent(undefined, "            }");
    _ = f.GoToMarker(undefined, "12");
    _ = f.VerifyCurrentLineContent(undefined, "        }");
    _ = f.GoToMarker(undefined, "13");
    _ = f.VerifyCurrentLineContent(undefined, "    }");
    _ = f.GoToMarker(undefined, "14");
    _ = f.VerifyCurrentLineContent(undefined, "}");
    _ = f.GoToMarker(undefined, "15");
    _ = f.VerifyCurrentLineContent(undefined, "for (var i = 0; i < this.foo(); i++) {");
    _ = f.GoToMarker(undefined, "16");
    _ = f.VerifyCurrentLineContent(undefined, "}");
}

test "TestSemicolonFormattingNestedStatements" {
    const content =
        \\if (true)
        \\if (true)/*parentOutsideBlock*/
        \\if (true) {
        \\if (true)/*directParent*/
        \\var x = 0/*innermost*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "innermost");
    _ = f.Insert(undefined, ";");
    _ = f.VerifyCurrentLineContent(undefined, "        var x = 0;");
    _ = f.GoToMarker(undefined, "directParent");
    _ = f.VerifyCurrentLineContent(undefined, "    if (true)");
    _ = f.GoToMarker(undefined, "parentOutsideBlock");
    _ = f.VerifyCurrentLineContent(undefined, "if (true)");
}

test "TestReferencesInEmptyFile" {
    const content =
        \\// @lib: es5
        \\/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestNavigationBarNestedObjectLiterals" {
    const content =
        \\var a = {
        \\    b: 0,
        \\    c: {},
        \\    d: {
        \\        e: 1,
        \\    },
        \\    f: {
        \\        g: 2,
        \\        h: {
        \\            i: 3,
        \\        },
        \\    },
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestRenameTemplateLiteralsComputedProperties" {
    const content =
        \\// @Filename: a.ts
        \\interface Obj {
        \\    [|[
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "num", "bool");
}

test "TestCompletionListInObjectBindingPattern07" {
    const content =
        \\interface I {
        \\    propertyOfI_1: number;
        \\    propertyOfI_2: string;
        \\}
        \\interface J {
        \\    property1: I;
        \\    property2: string;
        \\}
        \\
        \\var foo: J;
        \\var { property1: { /**/ } } = foo;
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
//                 "propertyOfI_1",
//                 "propertyOfI_2",
//             },
//         },
//     });
}

test "TestGetOutliningSpansForImports" {
    const content =
        \\[|import * as ns from "mod";
        \\
        \\import d from "mod";
        \\import { a, b, c } from "mod";
        \\
        \\import r = require("mod");|]
        \\
        \\// statement
        \\var x = 0;
        \\
        \\// another set of imports
        \\[|import * as ns from "mod";
        \\import d from "mod";
        \\import { a, b, c } from "mod";
        \\import r = require("mod");|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOutliningSpans(undefined, lsproto.FoldingRangeKindImports);
}

test "TestGoToDefinitionDynamicImport2" {
    const content =
        \\// @Filename: foo.ts
        \\export function /*Destination*/bar() { return "bar"; }
        \\var x = import("./foo");
        \\x.then(foo => {
        \\    foo.[|b/*1*/ar|](); 
        \\})
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestCompletionListOfGenericSymbol" {
    const content =
        \\var a = [1,2,3];
        \\a./**/
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
//                     .Label =  "length",
//                     .Detail = undefined("(property) Array<number>.length: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "Gets or sets the length of the array. This is a number one higher than the highest index in the array.",
//                         },
//                     },
//                     .Kind = undefined(lsproto.CompletionItemKindField),
//                 },
//                 &.{
//                     .Label =  "toString",
//                     .Detail = undefined("(method) Array<number>.toString(): string"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "Returns a string representation of an array.",
//                         },
//                     },
//                     .Kind = undefined(lsproto.CompletionItemKindMethod),
//                 },
//             },
//         },
//     });
}

test "TestJsdocDeprecated_suggestion8" {
    const content =
        \\// @Filename: first.ts
        \\/** @deprecated */
        \\export declare function tap<T>(next: null): void;
        \\export declare function tap<T>(next: T): T;
        \\// @Filename: second.ts
        \\import { tap } from './first';
        \\tap
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "second.ts");
    _ = f.VerifyNoErrors(undefined);
    _ = f.VerifySuggestionDiagnostics(undefined, null);
}

test "TestSmartSelection_behindCaret" {
    const content =
        \\let/**/ x: string
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSelectionRanges(undefined);
}

test "TestNavigationBarClassStaticBlock" {
    const content =
        \\class C {
        \\  static {
        \\    let x;
        \\  }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestQuickInfoOnElementAccessInWriteLocation1" {
    const content =
        \\// @strict: true
        \\// @exactOptionalPropertyTypes: true
        \\declare const xx: { prop?: number };
        \\xx['prop'/*1*/] = 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(property) prop?: number", "");
}

test "TestCodeFixClassImplementInterfaceMultipleMembersAndPunctuation" {
    const content =
        \\interface I1 {
        \\    x: number,
        \\    y: number
        \\    z: number;
        \\    f(): number,
        \\    g(): any
        \\    h();
        \\}
        \\
        \\class C1 implements I1 {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I1'",
        .NewFileContent = "interface I1 {\n    x: number,\n    y: number\n    z: number;\n    f(): number,\n    g(): any\n    h();\n}\n\nclass C1 implements I1 {\n    x: number;\n    y: number;\n    z: number;\n    f(): number {\n        throw new Error(\"Method not implemented.\");\n    }\n    g() {\n        throw new Error(\"Method not implemented.\");\n    }\n    h() {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestFormatSelectionPreserveTrailingWhitespace" {
    const content =
        \\
        \\/*begin*/;    
        \\    
        \\/*end*/    
        \\    
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts154);
    _ = f.FormatSelection(undefined, "begin", "end");
    _ = f.VerifyCurrentFileContent(undefined, "\n;    \n    \n    \n    \n");
}

test "TestAutoImportPackageJsonImportsPattern_js" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#*": "./src/*.js"
        \\  }
        \\}
        \\// @Filename: /src/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /a.ts
        \\something/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"#something"}, null );
}

test "TestTypeKeywordInFunction" {
    const content =
        \\function a() {
        \\    ty/**/
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
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestGetOccurrencesLoopBreakContinue2" {
    const content =
        \\var arr = [1, 2, 3, 4];
        \\label1: for (var n in arr) {
        \\    break;
        \\    continue;
        \\    break label1;
        \\    continue label1;
        \\
        \\    label2: [|f/**/or|] (var i = 0; i < arr[n]; i++) {
        \\        break label1;
        \\        continue label1;
        \\
        \\        [|break|];
        \\        [|continue|];
        \\        [|break|] label2;
        \\        [|continue|] label2;
        \\
        \\        function foo() {
        \\            label3: while (true) {
        \\                break;
        \\                continue;
        \\                break label3;
        \\                continue label3;
        \\
        \\                // these cross function boundaries
        \\                break label1;
        \\                continue label1;
        \\                break label2;
        \\                continue label2;
        \\
        \\                label4: do {
        \\                    break;
        \\                    continue;
        \\                    break label4;
        \\                    continue label4;
        \\
        \\                    break label3;
        \\                    continue label3;
        \\
        \\                    switch (10) {
        \\                        case 1:
        \\                        case 2:
        \\                            break;
        \\                            break label4;
        \\                        default:
        \\                            continue;
        \\                    }
        \\
        \\                    // these cross function boundaries
        \\                    break label1;
        \\                    continue label1;
        \\                    break label2;
        \\                    continue label2;
        \\                    () => { break;
        \\                } while (true)
        \\            }
        \\        }
        \\    }
        \\}
        \\
        \\label5: while (true) break label5;
        \\
        \\label7: while (true) continue label5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestJsdocThrowsTag_rename" {
    const content =
        \\class /**/E extends Error {}
        \\/**
        \\ * @throws {E}
        \\ */
        \\function f() {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , "");
}

test "TestGoToDefinitionOverriddenMember23" {
    const content =
        \\// @strict: true
        \\// @target: esnext
        \\// @lib: esnext
        \\const prop: symbol = Symbol();
        \\
        \\abstract class A {
        \\  static [prop]() {}
        \\}
        \\
        \\export class B extends A {
        \\  static [|/*1*/override|] [prop]() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestCompletionsImport_default_anonymous" {
    const content =
        \\// @module: esnext
        \\// @noLib: true
        \\// @Filename: /src/foo-bar.ts
        \\export default 0;
        \\// @Filename: /src/b.ts
        \\def/*0*/
        \\fooB/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "0");
    // f.VerifyCompletions(undefined, "0", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalsPlus(
//                 &.{}, true,
//             ),
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
//                     .Label = "fooBar",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./foo-bar",
//                         },
//                     },
//                     .Detail =              undefined("(property) default: 0"),
//                     .Kind =                undefined(lsproto.CompletionItemKindField),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined("1"), &.{
//         .Name =        "fooBar",
//         .Source =      "./foo-bar",
//         .Description = "Add import from \"./foo-bar\"",
//         .NewFileContent = undefined("import fooBar from \"./foo-bar\"\n\ndef\nfooB"),
//     });
}

test "TestSelfReferencedExternalModule" {
    const content =
        \\// @Filename: app.ts
        \\export import A = require('./app');
        \\export var I = 1;
        \\A./**/I
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
//                     .Label =  "A",
//                     .Detail = undefined("import A = require('./app')"),
//                 },
//                 &.{
//                     .Label =  "I",
//                     .Detail = undefined("var I: number"),
//                 },
//             },
//         },
//     });
}

test "TestQuickInfoLink10" {
    const content =
        \\/**
        \\ * start {@link https://vscode.dev/ | end}
        \\ */
        \\const /**/a = () => 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestOrganizeImportsType3" {
    const content =
        \\import {
        \\    d, 
        \\    type d as D,
        \\    type c,
        \\    c as C,
        \\    b,
        \\    b as B,
        \\    type A,
        \\    a
        \\} from './foo';
        \\console.log(A, a, B, b, c, C, d, D);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(undefined,
//         "import {\n    type A,\n    b as B,\n    c as C,\n    type d as D,\n    a,\n    b,\n    type c,\n    d\n} from './foo';\nconsole.log(A, a, B, b, c, C, d, D);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSFalse,
//             .OrganizeImportsTypeOrder =  lsutil.OrganizeImportsTypeOrderInline,
//         },
//     );
}

test "TestImportNameCodeFix_add_all_missing_imports" {
    const content =
        \\// @Filename: /a.ts
        \\export const a: number;
        \\// @Filename: /b.ts
        \\export const b: number;
        \\// @Filename: /c.ts
        \\export const c: number;
        \\// @Filename: /main.ts
        \\a;
        \\b;
        \\c;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/main.ts");
    _ = f.VerifyCodeFixAll(undefined, .{
        .FixID = "fixMissingImport",
        .NewFileContent = "import { a } from \"./a\";\nimport { b } from \"./b\";\nimport { c } from \"./c\";\n\na;\nb;\nc;",
    });
}

test "TestQuickInfoDisplayPartsConst" {
    const content =
        \\const /*1*/a = 10;
        \\function foo() {
        \\    const /*2*/b = /*3*/a;
        \\    if (b) {
        \\        const /*4*/b1 = 10;
        \\    }
        \\}
        \\namespace m {
        \\    const /*5*/c = 10;
        \\    export const /*6*/d = 10;
        \\    if (c) {
        \\        const /*7*/e = 10;
        \\    }
        \\}
        \\const /*8*/f: () => number = () => 10;
        \\const /*9*/g = /*10*/f;
        \\/*11*/f();
        \\const /*12*/h: { (a: string): number; (a: number): string; } = a => a;
        \\const /*13*/i = /*14*/h;
        \\/*15*/h(10);
        \\/*16*/h("hello");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCompletionInTypeOf2" {
    const content =
        \\namespace m1c {
        \\    export class C { foo(): void; }
        \\}
        \\var x: typeof m1c./*1*/;
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
//                 "C",
//             },
//         },
//     });
}

test "TestJavaScriptClass3" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\class Foo {
        \\   constructor() {
        \\       this./*dst1*/alpha = 10;
        \\       this./*dst2*/beta = 'gamma';
        \\   }
        \\   method() { return this.alpha; }
        \\}
        \\var x = new Foo();
        \\x.[|alpha/*src1*/|];
        \\x.[|beta/*src2*/|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "src1", "src2");
}

test "TestCompletionsImport_noSemicolons" {
    const content =
        \\// @Filename: /a.ts
        \\export function foo() {}
        \\// @Filename: /b.ts
        \\const x = 0
        \\const y = 1
        \\const z = fo/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "foo",
//         .Source =      "./a",
//         .Description = "Add import from \"./a\"",
//         .NewFileContent = undefined("import { foo } from \"./a\"\n\nconst x = 0\nconst y = 1\nconst z = fo"),
//     });
}

test "TestFormatTSXWithInlineComment" {
    const content =
        \\// @Filename: foo.tsx
        \\const a = <div>
        \\    // <a />
        \\</div>
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "const a = <div>\n    // <a />\n</div>");
}

test "TestGoToImplementationInterface_02" {
    const content =
        \\interface Fo/*interface_definition*/o { hello: () => void }
        \\
        \\let x: number = 9;
        \\
        \\function createFoo(): Foo {
        \\    if (x === 2) {
        \\        return [|{
        \\            hello() {}
        \\        }|];
        \\    }
        \\    return [|{
        \\        hello() {}
        \\    }|];
        \\}
        \\
        \\let createFoo2 = (): Foo => [|({hello() {}})|];
        \\
        \\function createFooLike() {
        \\    return {
        \\        hello() {}
        \\    };
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "interface_definition");
}

test "TestStringLiteralCompletionsInJsxAttributeInitializer" {
    const content =
        \\// @jsx: preserve
        \\// @filename: /a.tsx
        \\type Props = { a: number } | { b: "somethingelse", c: 0 | 1 };
        \\declare function Foo(args: Props): any
        \\
        \\const a1 = <Foo b={"/*1*/"} />
        \\const a2 = <Foo b="/*2*/" />
        \\const a3 = <Foo b="somethingelse"/*3*/ />
        \\const a4 = <Foo b={"somethingelse"} /*4*/ />
        \\const a5 = <Foo b={"somethingelse"} c={0} /*5*/ />
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
//                 "somethingelse",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"3", "4"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Excludes = &.{
//                 "\"somethingelse\"",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"5"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Excludes = &.{
//                 "0",
//                 "1",
//             },
//         },
//     });
}

test "TestCompletionsImport_default_reExport" {
    const content =
        \\// @lib: es5
        \\// @module: commonjs
        \\// @allowJs: true
        \\// @Filename: /file1.js
        \\const a = 1;
        \\export {
        \\    a as b
        \\};
        \\export default a;
        \\// @Filename: /file2.js
        \\import * as foo from './file1';
        \\/**/
        \\export default foo.b;
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
//             .Exact = CompletionGlobalsInJSPlus(
//                 &.{
//                     "foo",
//                     &.{
//                         .Label = "a",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "./file1",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                     &.{
//                         .Label = "b",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "./file1",
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

test "TestFindAllRefsObjectBindingElementPropertyName01" {
    const content =
        \\interface I {
        \\    /*1*/property1: number;
        \\    property2: string;
        \\}
        \\
        \\var foo: I;
        \\/*2*/var { /*3*/property1: prop1 } = foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestGetOccurrencesExport2" {
    const content =
        \\namespace m {
        \\    export class C1 {
        \\        public pub1;
        \\        public pub2;
        \\        private priv1;
        \\        private priv2;
        \\        protected prot1;
        \\        protected prot2;
        \\
        \\        public public;
        \\        private private;
        \\        protected protected;
        \\
        \\        public constructor(public a, private b, protected c, public d, private e, protected f) {
        \\            this.public = 10;
        \\            this.private = 10;
        \\            this.protected = 10;
        \\        }
        \\
        \\        public get x() { return 10; }
        \\        public set x(value) { }
        \\
        \\        public static statPub;
        \\        private static statPriv;
        \\        protected static statProt;
        \\    }
        \\
        \\    export interface I1 {
        \\    }
        \\
        \\    export declare namespace ma.m1.m2.m3 {
        \\        interface I2 {
        \\        }
        \\    }
        \\
        \\    export namespace mb.m1.m2.m3 {
        \\        declare var foo;
        \\
        \\        [|export|] class C2 {
        \\            public pub1;
        \\            private priv1;
        \\            protected prot1;
        \\
        \\            protected constructor(public public, protected protected, private private) {
        \\                public = private = protected;
        \\            }
        \\        }
        \\    }
        \\
        \\    declare var ambientThing: number;
        \\    export var exportedThing = 10;
        \\    declare function foo(): string;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestTypeCheckObjectInArrayLiteral" {
    const content =
        \\declare function create<T>(initialValues);
        \\create([{}]);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToPosition(undefined, 0);
    _ = f.Insert(undefined, "");
}

test "TestEnumAddition" {
    const content =
        \\namespace m { export enum Color { Red } }
        \\var /**/t = m.Color.Red + 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "var t: number", "");
}

test "TestQuickInfoGenericCombinators2" {
    const content =
        \\interface Collection<T, U> {
        \\   length: number;
        \\   add(x: T, y: U): void ;
        \\   remove(x: T, y: U): boolean;
        \\}
        \\
        \\interface Combinators {
        \\   map<T, U, V>(c: Collection<T, U>, f: (x: T, y: U) => V): Collection<T, V>;
        \\   map<T, U>(c: Collection<T, U>, f: (x: T, y: U) => any): Collection<any, any>;
        \\}
        \\
        \\class A {
        \\   foo<T>(): T { return null; }
        \\}
        \\
        \\class B<T> {
        \\   foo(x: T): T { return null; }
        \\}
        \\
        \\var c1: Collection<any, any>;
        \\var c2: Collection<number, string>;
        \\var c3: Collection<Collection<number, number>, string>;
        \\var c4: Collection<number, A>;
        \\var c5: Collection<number, B<any>>;
        \\
        \\var _: Combinators;
        \\// param help on open paren for arg 2 should show 'number' not T or 'any'
        \\// x should be contextually typed to number
        \\var rf1 = (x: number, y: string) => { return x.toFixed() };
        \\var rf2 = (x: Collection<number, number>, y: string) => { return x.length };
        \\var rf3 = (x: number, y: A) => { return y.foo() };
        \\
        \\var /*9*/r1a  = _.map/*1c*/(c2, (/*1a*/x, /*1b*/y) => { return x.toFixed() });
        \\var /*10*/r1b = _.map(c2, rf1);
        \\
        \\var /*11*/r2a = _.map(c3, (/*2a*/x, /*2b*/y) => { return x.length });
        \\var /*12*/r2b = _.map(c3, rf2);
        \\
        \\var /*13*/r3a = _.map(c4, (/*3a*/x, /*3b*/y) => { return y.foo() });
        \\var /*14*/r3b = _.map(c4, rf3);
        \\
        \\var /*15*/r4a = _.map(c5, (/*4a*/x, /*4b*/y) => { return y.foo() });
        \\
        \\var /*17*/r5a = _.map<number, string, Date>(c2, /*17error1*/(/*5a*/x, /*5b*/y) => { return x.toFixed() }/*17error2*/); 
        \\var rf1b = (x: number, y: string) => { return new Date() };
        \\var /*18*/r5b = _.map<number, string, Date>(c2, rf1b);
        \\
        \\var /*19*/r6a = _.map<Collection<number, number>, string, Date>(c3, (/*6a*/x,/*6b*/y) => { return new Date(); });
        \\var rf2b = (x: Collection<number, number>, y: string) => { return new Date(); };
        \\var /*20*/r6b = _.map<Collection<number, number>, string, Date>(c3, rf2b);
        \\
        \\var /*21*/r7a = _.map<number, A, string>(c4, (/*7a*/x,/*7b*/y) => { return y.foo() });
        \\var /*22*/r7b = _.map<number, A, string>(c4, /*22error1*/rf3/*22error2*/);
        \\
        \\var /*23*/r8a = _.map<number, /*error1*/B/*error2*/, string>(c5, (/*8a*/x,/*8b*/y) => { return y.foo() }); 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "2a", "(parameter) x: Collection<number, number>", "");
    // f.VerifyQuickInfoAt(undefined, "2b", "(parameter) y: string", "");
    // f.VerifyQuickInfoAt(undefined, "3a", "(parameter) x: number", "");
    // f.VerifyQuickInfoAt(undefined, "3b", "(parameter) y: A", "");
    // f.VerifyQuickInfoAt(undefined, "4a", "(parameter) x: number", "");
    // f.VerifyQuickInfoAt(undefined, "4b", "(parameter) y: B<any>", "");
    // f.VerifyQuickInfoAt(undefined, "5a", "(parameter) x: number", "");
    // f.VerifyQuickInfoAt(undefined, "5b", "(parameter) y: string", "");
    // f.VerifyQuickInfoAt(undefined, "6a", "(parameter) x: Collection<number, number>", "");
    // f.VerifyQuickInfoAt(undefined, "6b", "(parameter) y: string", "");
    // f.VerifyQuickInfoAt(undefined, "7a", "(parameter) x: number", "");
    // f.VerifyQuickInfoAt(undefined, "7b", "(parameter) y: A", "");
    // f.VerifyQuickInfoAt(undefined, "8a", "(parameter) x: number", "");
    // f.VerifyQuickInfoAt(undefined, "8b", "(parameter) y: any", "");
    // f.VerifyQuickInfoAt(undefined, "9", "var r1a: Collection<number, string>", "");
    // f.VerifyQuickInfoAt(undefined, "10", "var r1b: Collection<number, string>", "");
    // f.VerifyQuickInfoAt(undefined, "11", "var r2a: Collection<Collection<number, number>, number>", "");
    // f.VerifyQuickInfoAt(undefined, "12", "var r2b: Collection<Collection<number, number>, number>", "");
    // f.VerifyQuickInfoAt(undefined, "13", "var r3a: Collection<number, unknown>", "");
    // f.VerifyQuickInfoAt(undefined, "14", "var r3b: Collection<number, unknown>", "");
    // f.VerifyQuickInfoAt(undefined, "15", "var r4a: Collection<number, any>", "");
    // f.VerifyQuickInfoAt(undefined, "17", "var r5a: Collection<number, Date>", "");
    // f.VerifyQuickInfoAt(undefined, "18", "var r5b: Collection<number, Date>", "");
    // f.VerifyQuickInfoAt(undefined, "19", "var r6a: Collection<Collection<number, number>, Date>", "");
    // f.VerifyQuickInfoAt(undefined, "20", "var r6b: Collection<Collection<number, number>, Date>", "");
    // f.VerifyQuickInfoAt(undefined, "21", "var r7a: Collection<number, string>", "");
    // f.VerifyQuickInfoAt(undefined, "22", "var r7b: Collection<number, string>", "");
    // f.VerifyQuickInfoAt(undefined, "23", "var r8a: Collection<number, string>", "");
    _ = f.VerifyErrorExistsBetweenMarkers(undefined, "error1", "error2");
    _ = f.VerifyErrorExistsBetweenMarkers(undefined, "17error1", "17error2");
    _ = f.VerifyErrorExistsBetweenMarkers(undefined, "22error1", "22error2");
}

test "TestFormattingSpaceBetweenOptionalChaining" {
    const content =
        \\/*1*/a    ?.    b   ?.   c   .   d;
        \\/*2*/o    .  m()   ?.   length;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "a?.b?.c.d;");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "o.m()?.length;");
}

test "TestCompletionListAndMemberListOnCommentedWhiteSpace" {
    const content =
        \\namespace M {
        \\  export class C { public pub = 0; private priv = 1; }
        \\  export var V = 0;
        \\}
        \\
        \\
        \\var c = new M.C();
        \\
        \\c. // test on c.
        \\
        \\//Test for comment
        \\//c. /**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "", null);
}

test "TestSignatureHelpConstructorInheritance" {
    const content =
        \\class base {
        \\    constructor(s: string);
        \\    constructor(n: number);
        \\    constructor(a: any) { }
        \\}
        \\class B1 extends base { }
        \\class B2 extends B1 { }
        \\class B3 extends B2 {
        \\    constructor() {
        \\        super(/*indirectSuperCall*/3);
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "indirectSuperCall");
    // f.VerifySignatureHelp(undefined, .{.Text = "B2(n: number): B2", .ParameterCount = 1, .ParameterName = "n", .ParameterSpan = "n: number", .OverloadsCount = 2});
}

test "TestQuickInfoThrowsTag" {
    const content =
        \\class E extends Error {}
        \\
        \\/**
        \\ * @throws {E}
        \\ */
        \\function f1() {}
        \\
        \\/**
        \\ * @throws {E} description
        \\ */
        \\function f2() {}
        \\
        \\/**
        \\ * @throws description
        \\ */
        \\function f3() {}
        \\f1/*1*/()
        \\f2/*2*/()
        \\f3/*3*/()
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCompletionListInUnclosedFunction10" {
    const content =
        \\interface MyType {
        \\}
        \\
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string = "hello", c: typeof x = "hello") {
        \\        var v = (p: /*1*/
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
//                 "MyType",
//             },
//         },
//     });
}

test "TestFixingTypeParametersQuickInfo" {
    const content =
        \\// @strict: false
        \\declare function f<T>(x: T, y: (p: T) => T, z: (p: T) => T): T;
        \\var /*1*/result = /*2*/f(0, /*3*/x => null, /*4*/x => x.blahblah);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var result: number", "");
    // f.VerifyQuickInfoAt(undefined, "2", "function f<number>(x: number, y: (p: number) => number, z: (p: number) => number): number", "");
    // f.VerifyQuickInfoAt(undefined, "3", "(parameter) x: number", "");
    // f.VerifyQuickInfoAt(undefined, "4", "(parameter) x: number", "");
}

test "TestCompletionListInvalidMemberNames" {
    const content =
        \\var x = {
        \\    "foo ": "space in the name",
        \\    "bar": "valid identifier name",
        \\    "break": "valid identifier name (matches a keyword)",
        \\    "any": "valid identifier name (matches a typescript keyword)",
        \\    "#": "invalid identifier name",
        \\    "$": "valid identifier name",
        \\    "\u0062": "valid unicode identifier name (b)",
        \\    "\u0031\u0062": "invalid unicode identifier name (1b)"
        \\};
        \\
        \\x[|./*a*/|];
        \\x["[|/*b*/|]"];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "b", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 &.{
//                     .Label = "foo ",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "foo ",
//                             .Range =   f.Ranges()[1].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "bar",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "bar",
//                             .Range =   f.Ranges()[1].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "break",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "break",
//                             .Range =   f.Ranges()[1].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "any",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "any",
//                             .Range =   f.Ranges()[1].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "#",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "#",
//                             .Range =   f.Ranges()[1].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "$",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "$",
//                             .Range =   f.Ranges()[1].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "b",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "b",
//                             .Range =   f.Ranges()[1].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "1b",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "1b",
//                             .Range =   f.Ranges()[1].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "a", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 &.{
//                     .Label =      "foo ",
//                     .InsertText = undefined("[\"foo \"]"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "foo ",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 "bar",
//                 "break",
//                 "any",
//                 &.{
//                     .Label =      "#",
//                     .InsertText = undefined("[\"#\"]"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "#",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 "$",
//                 "b",
//                 &.{
//                     .Label =      "1b",
//                     .InsertText = undefined("[\"1b\"]"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "1b",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestRenameJsPropertyAssignment2" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\class Minimatch {
        \\}
        \\[|Minimatch.[|{| "contextRangeIndex": 0 |}staticProperty|] = "string";|]
        \\console.log(Minimatch.[|staticProperty|]);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "staticProperty");
}

test "TestImportTypeFormatting" {
    const content =
        \\var y: import("./c2").mytype;
        \\var z: import ("./c2").mytype;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "var y: import(\"./c2\").mytype;\nvar z: import(\"./c2\").mytype;");
}

test "TestFormattingWithMultilineComments" {
    const content =
        \\f(/*
        \\/*2*/         */() => { /*1*/ });
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.InsertLine(undefined, "");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "         */() => {");
}

test "TestGetOccurrencesStringLiteralTypes" {
    const content =
        \\function foo(a: "[|option 1|]") { }
        \\foo("[|option 1|]");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestFindAllRefsCommonJsRequire2" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\function f() { }
        \\module.exports.f = f
        \\// @Filename: /b.js
        \\const { f } = require('./a')
        \\/**/f
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestGetJavaScriptSyntacticDiagnostics22" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\function foo(...a) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNonSuggestionDiagnostics(undefined, null);
}

test "TestReferencesForFunctionParameter" {
    const content =
        \\var x;
        \\var n;
        \\
        \\function n(x: number, /*1*/n: number) {
        \\    /*2*/n = 32;
        \\    x = /*3*/n;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestQuickInfoOnFunctionPropertyReturnedFromGenericFunction3" {
    const content =
        \\function createProps<T>(t: T) {
        \\  const getProps = () => {}
        \\  const createVariants = () => {}
        \\
        \\  getProps.createVariants = createVariants;
        \\  return getProps;
        \\}
        \\
        \\createProps({})./**/createVariants();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "(property) getProps<{}>.createVariants: () => void", "");
}

test "TestUnusedImports14FS" {
    const content =
        \\// @noUnusedLocals: true
        \\// @Filename: file2.ts
        \\[| import /* 1 */ A /* 2 */, /* 3 */ { /* 4 */ x /* 5 */ } /* 6 */ from './a'; |]
        \\console.log(A);
        \\// @Filename: file1.ts
        \\export default 10;
        \\export var x = 10;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "import /* 1 */ A /* 2 */ /* 6 */ from './a';", false, 0, 0);
}

test "TestCompletionListWithoutVariableinitializer" {
    const content =
        \\const a = a/*1*/;
        \\const b = a && b/*2*/;
        \\const c = [{ prop: [c/*3*/] }];
        \\const d = () => { d/*4*/ };
        \\const e = () => expression/*5*/
        \\const f = { prop() { e/*6*/ }  };
        \\const fn = (p = /*7*/) => {}
        \\const { g, h = /*8*/ } = { ... }
        \\const [ g1, h1 = /*9*/ ] = [ ... ]
        \\const { a1 } = a/*10*/;
        \\const { a2 } = fn({a: a/*11*/});
        \\const [ a3 ] = a/*12*/;
        \\const [ a4 ] = fn([a/*13*/]);
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
//             .Excludes = &.{
//                 "a",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"2"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "a",
//             },
//             .Excludes = &.{
//                 "b",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"3"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "a",
//                 "b",
//             },
//             .Excludes = &.{
//                 "c",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"4"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "a",
//                 "b",
//                 "c",
//                 "d",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"5"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "a",
//                 "b",
//                 "c",
//                 "d",
//                 "e",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"6"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "a",
//                 "b",
//                 "c",
//                 "d",
//                 "e",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"7"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "a",
//                 "b",
//                 "c",
//                 "d",
//                 "e",
//                 "fn",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"8"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "a",
//                 "b",
//                 "c",
//                 "d",
//                 "e",
//                 "fn",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"9"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "a",
//                 "b",
//                 "c",
//                 "d",
//                 "e",
//                 "fn",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"10"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Excludes = &.{
//                 "a1",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"11"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Excludes = &.{
//                 "a2",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"12"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Excludes = &.{
//                 "a3",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"13"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Excludes = &.{
//                 "a4",
//             },
//         },
//     });
}

test "TestLinkedEditingJsxTag3" {
    const content =
        \\// @Filename: /selfClosing.tsx
        \\/*0*/const jsx = /*1*/(
        \\   <div> /*2*/
        \\      <p>/*3*/
        \\         No lin/*4*/ked cursors here!
        \\         /*5*/</*6*/img/*7*/ /*8*///*9*/>
        \\     /*10*/ </p>/*11*/
        \\   /*12*/</div>
        \\/*13*/)/*14*/;/*15*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyLinkedEditing(undefined, .{
//         .@"0" =  null,
//         .@"1" =  null,
//         .@"2" =  null,
//         .@"3" =  null,
//         .@"4" =  null,
//         .@"5" =  null,
//         .@"6" =  null,
//         .@"7" =  null,
//         .@"8" =  null,
//         .@"9" =  null,
//         .@"10" = null,
//         .@"11" = null,
//         .@"12" = null,
//         .@"13" = null,
//         .@"14" = null,
//         .@"15" = null,
//     });
}

test "TestSyntacticClassificationsObjectLiteral" {
    const content =
        \\var v = 10e0;
        \\var x = {
        \\    p1: 1,
        \\    p2: 2,
        \\    any: 3,
        \\    function: 4,
        \\    var: 5,
        \\    void: void 0,
        \\    v: v += v,
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "variable.declaration", .Text = "v"},
//         .{.Type = "variable.declaration", .Text = "x"},
//         .{.Type = "property.declaration", .Text = "p1"},
//         .{.Type = "property.declaration", .Text = "p2"},
//         .{.Type = "property.declaration", .Text = "any"},
//         .{.Type = "property.declaration", .Text = "function"},
//         .{.Type = "property.declaration", .Text = "var"},
//         .{.Type = "property.declaration", .Text = "void"},
//         .{.Type = "property.declaration", .Text = "v"},
//         .{.Type = "variable", .Text = "v"},
//         .{.Type = "variable", .Text = "v"},
//     });
}

test "TestGoToDefinitionOverriddenMember2" {
    const content =
        \\// @noImplicitOverride: true
        \\class Foo {
        \\    /*2*/m() {}
        \\}
        \\
        \\class Bar extends Foo {
        \\    [|/*1*/override|] m() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestRenameDestructuringAssignmentNestedInFor2" {
    const content =
        \\// @strict: false
        \\interface MultiRobot {
        \\    name: string;
        \\    skills: {
        \\        [|[|{| "contextRangeIndex": 0 |}primary|]: string;|]
        \\        secondary: string;
        \\    };
        \\}
        \\let multiRobot: MultiRobot, [|[|{| "contextRangeIndex": 2 |}primary|]: string|], secondary: string, primaryA: string, secondaryA: string, i: number;
        \\for ([|{ skills: { [|{| "contextRangeIndex": 4 |}primary|]: primaryA, secondary: secondaryA } } = multiRobot|], i = 0; i < 1; i++) {
        \\    primaryA;
        \\}
        \\for ([|{ skills: { [|{| "contextRangeIndex": 6 |}primary|], secondary } } = multiRobot|], i = 0; i < 1; i++) {
        \\    [|primary|];
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[5], f.Ranges()[3], f.Ranges()[7], f.Ranges()[8]);
}

test "TestAutoImportPackageJsonImportsPreference3" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#*": "./src/*.ts"
        \\  }
        \\}
        \\// @Filename: /src/a/b/c/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /src/a/b/c/d.ts
        \\something/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"#a/b/c/something"}, &.{.ImportModuleSpecifierPreference = "non-relative"});
}

test "TestQuickInfoImportMeta" {
    const content =
        \\// @module: esnext
        \\// @Filename: foo.ts
        \\/// <reference path='./bar.d.ts' />
        \\im/*1*/port.me/*2*/ta;
        \\//@Filename: bar.d.ts
        \\/**
        \\ * The type of 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCompletionsImport_default_alreadyExistedWithRename" {
    const content =
        \\// @Filename: /a.ts
        \\export default function foo() {}
        \\// @Filename: /b.ts
        \\import f_o_o from "./a";
        \\f/**/;
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
//                     .Label = "foo",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./a",
//                         },
//                     },
//                     .Detail =              undefined("function foo(): void"),
//                     .Kind =                undefined(lsproto.CompletionItemKindFunction),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "foo",
//         .Source =      "./a",
//         .Description = "Add import from \"./a\"",
//         .NewFileContent = undefined("import foo from \"./a\";\nimport f_o_o from \"./a\";\nf;"),
//     });
}

test "TestConvertFunctionToEs6Class_noQuickInfoForIIFE" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\(/*1*/function () {
        \\   const foo = () => {
        \\        this.x = 10;
        \\   };
        \\   foo;
        \\})();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestGoToDefinitionDifferentFile" {
    const content =
        \\// @Filename: goToDefinitionDifferentFile_Definition.ts
        \\var /*remoteVariableDefinition*/remoteVariable;
        \\function /*remoteFunctionDefinition*/remoteFunction() { }
        \\class /*remoteClassDefinition*/remoteClass { }
        \\interface /*remoteInterfaceDefinition*/remoteInterface{ }
        \\module /*remoteModuleDefinition*/remoteModule{ export var foo = 1;}
        \\// @Filename: goToDefinitionDifferentFile_Consumption.ts
        \\/*remoteVariableReference*/remoteVariable = 1;
        \\/*remoteFunctionReference*/remoteFunction();
        \\var foo = new /*remoteClassReference*/remoteClass();
        \\class fooCls implements /*remoteInterfaceReference*/remoteInterface { }
        \\var fooVar = /*remoteModuleReference*/remoteModule.foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, false, "remoteVariableReference", "remoteFunctionReference", "remoteClassReference", "remoteInterfaceReference", "remoteModuleReference");
}

test "TestDocCommentTemplateVariableStatements03" {
    const content =
        \\/*a*/
        \\var a = x => x
        \\
        \\/*b*/
        \\let b = (x,y,z) => x + y + z;
        \\
        \\/*c*/
        \\const c = ((x => +x))
        \\
        \\/*d*/
        \\let d = (function () { })
        \\
        \\/*e*/
        \\let e = function e([a,b,c]) {
        \\    return "hello"
        \\};
        \\
        \\/*f*/
        \\let f = class {
        \\}
        \\
        \\/*g*/
        \\const g = ((class G {
        \\    constructor(private x);
        \\    constructor(x,y,z);
        \\    constructor(x,y,z, ...okayThatsEnough) {
        \\    }
        \\}))
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyJSDocCompletion(undefined, "a", 7, "/**\n * \n * @param x\n * @returns\n */", null);
    // f.VerifyJSDocCompletion(undefined, "b", 7, "/**\n * \n * @param x\n * @param y\n * @param z\n * @returns\n */", null);
    // f.VerifyJSDocCompletion(undefined, "c", 7, "/**\n * \n * @param x\n * @returns\n */", null);
    // f.VerifyJSDocCompletion(undefined, "d", 3, "/** */", null);
    // f.VerifyJSDocCompletion(undefined, "e", 7, "/**\n * \n * @param param0\n * @returns\n */", null);
    // f.VerifyJSDocCompletion(undefined, "f", 3, "/** */", null);
    // f.VerifyJSDocCompletion(undefined, "g", 7, "/**\n * \n * @param x\n */", null);
}

test "TestCodeFixClassImplementInterfaceTypeParamInstantiateError" {
    const content =
        \\interface I<T extends string> {
        \\   x: T;
        \\}
        \\
        \\class C implements I<number> { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFixAvailable(undefined, &.{"Implement interface 'I<number>'"});
}

test "TestOrganizeImports8" {
    const content =
        \\import { foo as foo } from "foo";
        \\foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(undefined,
//         "import { foo } from \"foo\";\nfoo;",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestCompletionListInComments2" {
    const content =
        \\// */{| "name" : "1" |}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "1", null);
}

test "TestRenameForAliasingExport01" {
    const content =
        \\// @Filename: foo.ts
        \\let x = 1;
        \\
        \\export { /**/[|x|] as y };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyRenameSucceeded(undefined, null );
}

test "TestCompletionsImport_filteredByPackageJson_typesOnly" {
    const content =
        \\//@noEmit: true
        \\//@Filename: /package.json
        \\{
        \\  "devDependencies": {
        \\    "@types/react": "*"
        \\  }
        \\}
        \\//@Filename: /node_modules/@types/react/index.d.ts
        \\export declare var React: any;
        \\//@Filename: /node_modules/@types/react/package.json
        \\{
        \\  "name": "@types/react"
        \\}
        \\//@Filename: /node_modules/@types/fake-react/index.d.ts
        \\export declare var ReactFake: any;
        \\//@Filename: /node_modules/@types/fake-react/package.json
        \\{
        \\  "name": "@types/fake-react"
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

test "TestCodeFixAwaitShouldNotCrashIfNotInFunction" {
    const content =
        \\await a
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined, "addMissingAwait");
}

test "TestReferencesForTypeKeywords" {
    const content =
        \\interface I {}
        \\function f<T /*typeParam_extendsKeyword*/extends I>() {}
        \\type A1<T, U> = T /*conditionalType_extendsKeyword*/extends U ? 1 : 0;
        \\type A2<T> = T extends /*inferType_inferKeyword*/infer U ? 1 : 0;
        \\type A3<T> = { [P /*mappedType_inOperator*/in keyof T]: 1 };
        \\type A4<T> = /*keyofOperator_keyofKeyword*/keyof T;
        \\type A5<T> = /*readonlyOperator_readonlyKeyword*/readonly T[];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "typeParam_extendsKeyword", "conditionalType_extendsKeyword", "inferType_inferKeyword", "mappedType_inOperator", "keyofOperator_keyofKeyword", "readonlyOperator_readonlyKeyword");
}

test "TestReferenceToClass" {
    const content =
        \\// @Filename: referenceToClass_1.ts
        \\class /*1*/foo {
        \\    public n: /*2*/foo;
        \\    public foo: number;
        \\}
        \\
        \\class bar {
        \\    public n: /*3*/foo;
        \\    public k = new /*4*/foo();
        \\}
        \\
        \\namespace mod {
        \\    var k: /*5*/foo = null;
        \\}
        \\// @Filename: referenceToClass_2.ts
        \\var k: /*6*/foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6");
}

test "TestInlayHintsImportType1" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /a.js
        \\module.exports.a = 1
        \\// @Filename: /b.js
        \\const a = require('./a');
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.js");
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayVariableTypeHints = core.TSTrue}});
}

test "TestFindAllRefsOnImportAliases2" {
    const content =
        \\//@Filename: a.ts
        \\[|export class /*class0*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 0 |}Class|] {}|]
        \\//@Filename: b.ts
        \\[|import { /*class1*/[|{| "contextRangeIndex": 2 |}Class|] as /*c2_0*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 2 |}C2|] } from "./a";|]
        \\var c = new /*c2_1*/[|C2|]();
        \\//@Filename: c.ts
        \\[|export { /*class2*/[|{| "contextRangeIndex": 6 |}Class|] as /*c3*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 6 |}C3|] } from "./a";|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "class0", "class1", "class2", "c2_0", "c2_1", "c3");
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "Class", "C2", "C3");
}

test "TestRemoveVarFromModuleWithReopenedEnums" {
    const content =
        \\namespace A {
        \\    /**/var o;
        \\}
        \\enum A {
        \\}
        \\enum A {
        \\}
        \\namespace A {
        \\    var p;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.DeleteAtCaret(undefined, 6);
}

test "TestCodeFixClassImplementInterfaceEmptyTypeLiteral" {
    const content =
        \\
        \\interface I {
        \\    x: {};
        \\}
        \\
        \\class C implements I {[|
        \\   |]constructor() { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "\ninterface I {\n    x: {};\n}\n\nclass C implements I {\n   constructor() { }\n    x: {};\n}",
        .Index = 0,
    });
}

test "TestContextualTypingFromTypeAssertion1" {
    const content =
        \\var f3 = <(x: string) => string> function (/**/x) { return x.toLowerCase(); };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "(parameter) x: string", "");
}

test "TestImportCompletionsPackageJsonImportsPattern_capsInPath2" {
    const content =
        \\// @module: node18
        \\// @Filename: /Dev/package.json
        \\{
        \\  "imports": {
        \\    "#thing/*": "./src/*.js"
        \\  }
        \\}
        \\// @Filename: /Dev/src/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /Dev/a.ts
        \\import {} from "#thing//*2*/";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"2"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "something",
//             },
//         },
//     });
}

test "TestGetJavaScriptSyntacticDiagnostics2" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\export = b;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestGenericTypeAliasIntersectionCompletions" {
    const content =
        \\type MixinCtor<A, B> = new () => A & B & { constructor: MixinCtor<A, B> };
        \\function merge<A, B>(a: { prototype: A }, b: { prototype: B }): MixinCtor<A, B> {
        \\  let merged = function() { }
        \\  Object.assign(merged.prototype, a.prototype, b.prototype);
        \\  return <MixinCtor<A, B>><any>merged;
        \\}
        \\
        \\class TreeNode {
        \\  value: any;
        \\}
        \\
        \\abstract class LeftSideNode extends TreeNode {
        \\  abstract right(): TreeNode;
        \\  left(): TreeNode {
        \\    return null;
        \\  }
        \\}
        \\
        \\abstract class RightSideNode extends TreeNode {
        \\  abstract left(): TreeNode;
        \\  right(): TreeNode {
        \\    return null;
        \\  };
        \\}
        \\
        \\var obj = new (merge(LeftSideNode, RightSideNode))();
        \\obj./**/
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
//                 "right",
//                 "left",
//                 "value",
//                 "constructor",
//             },
//         },
//     });
}

test "TestDocumentHighlightAtInheritedProperties6" {
    const content =
        \\// @Filename: file1.ts
        \\class C extends D {
        \\    [|prop0|]: string;
        \\    [|prop1|]: string;
        \\}
        \\
        \\class D extends C {
        \\    [|prop0|]: string;
        \\    [|prop1|]: string;
        \\}
        \\
        \\var d: D;
        \\d.[|prop1|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestQuickInfoSatisfiesTag" {
    const content =
        \\// @noEmit: true
        \\// @allowJS: true
        \\// @checkJs: true
        \\// @filename: /a.js
        \\/** @satisfies {number} comment */
        \\const /*1*/a = 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestRenameParameterPropertyDeclaration1" {
    const content =
        \\class Foo {
        \\    constructor([|private [|{| "contextRangeIndex": 0 |}privateParam|]: number|]) {
        \\        let localPrivate = [|privateParam|];
        \\        this.[|privateParam|] += 10;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "privateParam");
}

test "TestQuickinfoVerbosityEnum" {
    const content =
        \\// @filename: a.ts
        \\export {};
        \\enum Color/*c*/ {
        \\    Red,
        \\    Green,
        \\    Blue,
        \\}
        \\const x/*x*/: Color = Color.Red;
        \\const enum Direction/*d*/ {
        \\    Up,
        \\    Down,
        \\}
        \\const y/*y*/: Direction = Direction.Up;
        \\enum Flags/*f*/ {
        \\    None = 0,
        \\    IsDirectory = 1 << 0,
        \\    IsFile = 1 << 1,
        \\    IsSymlink = 1 << 2,
        \\}
        \\// @filename: b.ts
        \\export enum Color {
        \\    Red = "red"
        \\}
        \\// @filename: c.ts
        \\import { Color } from "./b";
        \\const c: Color/*a*/ = Color.Red;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"c" = .{0, 1}, .@"x" = .{0, 1}, .@"d" = .{0, 1}, .@"y" = .{0, 1}, .@"f" = .{0, 1}, .@"a" = .{0, 1}});
}

test "TestCompletionExportFrom" {
    const content =
        \\export * /*1*/;
        \\export {} /*2*/;
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
//             .Includes = &.{
//                 &.{
//                     .Label =    "from",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

