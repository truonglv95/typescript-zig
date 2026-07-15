const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionListAtInvalidLocations" {
    const content =
        \\var v1 = '';
        \\" /*openString1*/
        \\var v2 = '';
        \\"/*openString2*/
        \\var v3 = '';
        \\" bar./*openString3*/
        \\var v4 = '';
        \\// bar./*inComment1*/
        \\var v6 = '';
        \\// /*inComment2*/
        \\var v7 = '';
        \\/* /*inComment3*/
        \\var v11 = '';
        \\  // /*inComment4*/
        \\var v12 = '';
        \\type htm/*inTypeAlias*/
        \\
        \\//  /*inComment5*/
        \\foo;
        \\var v10 = /reg/*inRegExp1*/ex/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"openString1", "openString2", "openString3"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{},
//         },
//     });
    _ = f.VerifyCompletions(undefined, &.{"inComment1", "inComment2", "inComment3", "inComment4", "inTypeAlias", "inComment5", "inRegExp1"}, null);
}

test "TestAutoImportProvider_wildcardExports3" {
    const content =
        \\// @Filename: /home/src/workspaces/project/packages/ui/package.json
        \\{
        \\  "name": "@repo/ui",
        \\  "version": "1.0.0",
        \\  "exports": {
        \\    "./*": "./src/*.tsx"
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/packages/ui/src/Card.tsx
        \\export const Card = () => null;
        \\// @Filename: /home/src/workspaces/project/apps/web/package.json
        \\{
        \\  "name": "web",
        \\  "version": "1.0.0",
        \\  "dependencies": {
        \\    "@repo/ui": "workspace:*"
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/apps/web/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "esnext",
        \\    "moduleResolution": "bundler",
        \\    "noEmit": true,
        \\    "jsx": "preserve",
        \\    "lib": ["es5"]
        \\  },
        \\ "include": ["app"]
        \\}
        \\// @Filename: /home/src/workspaces/project/apps/web/app/index.tsx
        \\(<Card/**/ />);
        \\// @link: /home/src/workspaces/project/packages/ui -> /home/src/workspaces/project/apps/web/node_modules/@repo/ui
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
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
//                     .Label = "Card",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "@repo/ui/Card",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
}

test "TestQuickInfoContextualTyping" {
    const content =
        \\// DEFAULT INTERFACES
        \\interface IFoo {
        \\    n: number;
        \\    s: string;
        \\    f(i: number, s: string): string;
        \\    a: number[];
        \\}
        \\interface IBar {
        \\    foo: IFoo;
        \\}
        \\// CONTEXT: Class property declaration
        \\class C1T5 {
        \\    /*1*/foo: (i: number, s: string) => number = function(/*2*/i) {
        \\        return /*3*/i;
        \\    }
        \\}
        \\// CONTEXT: Module property declaration
        \\namespace C2T5 {
        \\    export var /*4*/foo: (i: number, s: string) => number = function(/*5*/i) {
        \\        return /*6*/i;
        \\    }
        \\}
        \\// CONTEXT: Variable declaration
        \\var /*7*/c3t1: (s: string) => string = (function(/*8*/s) { return /*9*/s });
        \\var /*10*/c3t2 = <IFoo>({
        \\    n: 1
        \\})
        \\var /*11*/c3t3: number[] = [];
        \\var /*12*/c3t4: () => IFoo = function() { return <IFoo>({}) };
        \\var /*13*/c3t5: (n: number) => IFoo = function(/*14*/n) { return <IFoo>({}) };
        \\var /*15*/c3t6: (n: number, s: string) => IFoo = function(/*16*/n, /*17*/s) { return <IFoo>({}) };
        \\var /*18*/c3t7: {
        \\    (n: number): number;
        \\    (s1: string): number;
        \\};
        \\var /*20*/c3t8: (n: number, s: string) => number = function(/*21*/n) { return n; };
        \\var /*22*/c3t9: number[][] = [[],[]];
        \\var /*23*/c3t10: IFoo[] = [<IFoo>({}),<IFoo>({})];
        \\var /*24*/c3t11: {(n: number, s: string): string;}[] = [function(/*25*/n, /*26*/s) { return s; }];
        \\var /*27*/c3t12: IBar = {
        \\    /*28*/foo: <IFoo>({})
        \\}
        \\var /*29*/c3t13 = <IFoo>({
        \\    /*30*/f: function(/*31*/i, /*32*/s) { return s; }
        \\})
        \\var /*33*/c3t14 = <IFoo>({
        \\    /*34*/a: []
        \\})
        \\// CONTEXT: Class property assignment
        \\class C4T5 {
        \\    /*35*/foo: (i: number, s: string) => string;
        \\    constructor() {
        \\        this.foo = function(/*36*/i, /*37*/s) {
        \\            return s;
        \\        }
        \\    }
        \\}
        \\// CONTEXT: Module property assignment
        \\namespace C5T5 {
        \\    export var /*38*/foo: (i: number, s: string) => string;
        \\    foo = function(/*39*/i, /*40*/s) {
        \\        return s;
        \\    }
        \\}
        \\// CONTEXT: Variable assignment
        \\var /*41*/c6t5: (n: number) => IFoo;
        \\c6t5 = <(n: number) => IFoo>function(/*42*/n) { return <IFoo>({}) };
        \\// CONTEXT: Array index assignment
        \\var /*43*/c7t2: IFoo[];
        \\/*44*/c7t2[0] = <IFoo>({n: 1});
        \\// CONTEXT: Object property assignment
        \\interface IPlaceHolder {
        \\    t1: (s: string) => string;
        \\    t2: IFoo;
        \\    t3: number[];
        \\    t4: () => IFoo;
        \\    t5: (n: number) => IFoo;
        \\    t6: (n: number, s: string) => IFoo;
        \\    t7: {
        \\            (n: number, s: string): number;
        \\            //(s1: string, s2: string): number;
        \\        };
        \\    t8: (n: number, s: string) => number;
        \\    t9: number[][];
        \\    t10: IFoo[];
        \\    t11: {(n: number, s: string): string;}[];
        \\    t12: IBar;
        \\    t13: IFoo;
        \\    t14: IFoo;
        \\    }
        \\var objc8: {
        \\    t1: (s: string) => string;
        \\    t2: IFoo;
        \\    t3: number[];
        \\    t4: () => IFoo;
        \\    t5: (n: number) => IFoo;
        \\    t6: (n: number, s: string) => IFoo;
        \\    t7: {
        \\            (n: number, s: string): number;
        \\            //(s1: string, s2: string): number;
        \\        };
        \\    t8: (n: number, s: string) => number;
        \\    t9: number[][];
        \\    t10: IFoo[];
        \\    t11: {(n: number, s: string): string;}[];
        \\    t12: IBar;
        \\    t13: IFoo;
        \\    t14: IFoo;
        \\} = <IPlaceHolder>({});
        \\objc8./*45*/t1 = (function(/*46*/s) { return s });
        \\objc8./*47*/t2 = <IFoo>({
        \\    n: 1
        \\});
        \\objc8./*48*/t3 = [];
        \\objc8./*49*/t4 = function() { return <IFoo>({}) };
        \\objc8./*50*/t5 = function(/*51*/n) { return <IFoo>({}) };
        \\objc8./*52*/t6 = function(/*53*/n, /*54*/s) { return <IFoo>({}) };
        \\objc8./*55*/t7 = function(n: number) { return n };
        \\objc8./*56*/t8 = function(/*57*/n) { return n; };
        \\objc8./*58*/t9 = [[],[]];
        \\objc8./*59*/t10 = [<IFoo>({}),<IFoo>({})];
        \\objc8./*60*/t11 = [function (/*61*/n, /*62*/s) { return s; }];
        \\objc8./*63*/t12 = {
        \\    /*64*/foo: <IFoo>({})
        \\}
        \\objc8./*65*/t13 = <IFoo>({
        \\    /*66*/f: function(/*67*/i, /*68*/s) { return s; }
        \\})
        \\objc8./*69*/t14 = <IFoo>({
        \\    /*70*/a: []
        \\})
        \\// CONTEXT: Function call
        \\function c9t5(f: (n: number) => IFoo) {};
        \\c9t5(function(/*71*/n) {
        \\    return <IFoo>({});
        \\});
        \\// CONTEXT: Return statement
        \\var /*72*/c10t5: () => (n: number) => IFoo = function() { return function(/*73*/n) { return <IFoo>({}) } };
        \\// CONTEXT: Newing a class
        \\class C11t5 { constructor(f: (n: number) => IFoo) { } };
        \\var i = new C11t5(function(/*74*/n) { return <IFoo>({}) });
        \\// CONTEXT: Type annotated expression
        \\var /*75*/c12t1 = <(s: string) => string> (function (/*76*/s) { return s });
        \\var /*77*/c12t2 = <IFoo> ({
        \\    n: 1
        \\});
        \\var /*78*/c12t3 = <number[]> [];
        \\var /*79*/c12t4 = <() => IFoo> function() { return <IFoo>({}) };
        \\var /*80*/c12t5 = <(n: number) => IFoo> function(/*81*/n) { return <IFoo>({}) };
        \\var /*82*/c12t6 = <(n: number, s: string) => IFoo> function(/*83*/n, /*84*/s) { return <IFoo>({}) };
        \\var /*85*/c12t7 = <{
        \\    (n: number, s: string): number;
        \\    //(s1: string, s2: string): number;
        \\}> function(n:number) { return n };
        \\var /*86*/c12t8 = <(n: number, s: string) => number> function (/*87*/n) { return n; };
        \\var /*88*/c12t9 = <number[][]> [[],[]];
        \\var /*89*/c12t10 = <IFoo[]> [<IFoo>({}),<IFoo>({})];
        \\var /*90*/c12t11 = <{ (n: number, s: string): string; }[]>[function (/*91*/n, /*92*/s) { return s; }];
        \\var /*93*/c12t12 = <IBar> {
        \\    /*94*/foo: <IFoo>({})
        \\}
        \\var /*95*/c12t13 = <IFoo> ({
        \\    /*96*/f: function(/*97*/i, /*98*/s) { return s; }
        \\})
        \\var /*99*/c12t14 = <IFoo> ({
        \\    /*100*/a: []
        \\})
        \\// CONTEXT: Contextual typing declarations
        \\// contextually typing function declarations
        \\function EF1(a: number, b:number):number;
        \\function /*101*/EF1(/*102*/a,/*103*/b) { return a+b; }
        \\var efv = EF1(1,2);
        \\// contextually typing from ambient class declarations
        \\declare class Point
        \\{
        \\      constructor(x: number, y: number);
        \\      x: number;
        \\      y: number;
        \\      add(dx: number, dy: number): Point;
        \\      static origin: Point;
        \\}
        \\Point./*110*/origin = new /*111*/Point(0, 0);
        \\Point.prototype./*112*/add = function (/*113*/dx, /*114*/dy) {
        \\    return new Point(this.x + dx, this.y + dy);
        \\};
        \\Point.prototype = {
        \\    x: 0,
        \\    y: 0,
        \\    /*115*/add: function (/*116*/dx, /*117*/dy) {
        \\        return new Point(this.x + dx, this.y + dy);
        \\    }
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(property) C1T5.foo: (i: number, s: string) => number", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(parameter) i: number", "");
    // f.VerifyQuickInfoAt(undefined, "3", "(parameter) i: number", "");
    // f.VerifyQuickInfoAt(undefined, "4", "var C2T5.foo: (i: number, s: string) => number", "");
    // f.VerifyQuickInfoAt(undefined, "5", "(parameter) i: number", "");
    // f.VerifyQuickInfoAt(undefined, "6", "(parameter) i: number", "");
    // f.VerifyQuickInfoAt(undefined, "7", "var c3t1: (s: string) => string", "");
    // f.VerifyQuickInfoAt(undefined, "8", "(parameter) s: string", "");
    // f.VerifyQuickInfoAt(undefined, "9", "(parameter) s: string", "");
    // f.VerifyQuickInfoAt(undefined, "10", "var c3t2: IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "11", "var c3t3: number[]", "");
    // f.VerifyQuickInfoAt(undefined, "12", "var c3t4: () => IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "13", "var c3t5: (n: number) => IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "14", "(parameter) n: number", "");
    // f.VerifyQuickInfoAt(undefined, "15", "var c3t6: (n: number, s: string) => IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "16", "(parameter) n: number", "");
    // f.VerifyQuickInfoAt(undefined, "17", "(parameter) s: string", "");
    // f.VerifyQuickInfoAt(undefined, "18", "var c3t7: {\n    (n: number): number;\n    (s1: string): number;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "20", "var c3t8: (n: number, s: string) => number", "");
    // f.VerifyQuickInfoAt(undefined, "21", "(parameter) n: number", "");
    // f.VerifyQuickInfoAt(undefined, "22", "var c3t9: number[][]", "");
    // f.VerifyQuickInfoAt(undefined, "23", "var c3t10: IFoo[]", "");
    // f.VerifyQuickInfoAt(undefined, "24", "var c3t11: ((n: number, s: string) => string)[]", "");
    // f.VerifyQuickInfoAt(undefined, "25", "(parameter) n: number", "");
    // f.VerifyQuickInfoAt(undefined, "26", "(parameter) s: string", "");
    // f.VerifyQuickInfoAt(undefined, "27", "var c3t12: IBar", "");
    // f.VerifyQuickInfoAt(undefined, "28", "(property) IBar.foo: IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "29", "var c3t13: IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "30", "(method) IFoo.f(i: number, s: string): string", "");
    // f.VerifyQuickInfoAt(undefined, "31", "(parameter) i: number", "");
    // f.VerifyQuickInfoAt(undefined, "32", "(parameter) s: string", "");
    // f.VerifyQuickInfoAt(undefined, "33", "var c3t14: IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "34", "(property) IFoo.a: number[]", "");
    // f.VerifyQuickInfoAt(undefined, "35", "(property) C4T5.foo: (i: number, s: string) => string", "");
    // f.VerifyQuickInfoAt(undefined, "36", "(parameter) i: number", "");
    // f.VerifyQuickInfoAt(undefined, "37", "(parameter) s: string", "");
    // f.VerifyQuickInfoAt(undefined, "38", "var C5T5.foo: (i: number, s: string) => string", "");
    // f.VerifyQuickInfoAt(undefined, "39", "(parameter) i: number", "");
    // f.VerifyQuickInfoAt(undefined, "40", "(parameter) s: string", "");
    // f.VerifyQuickInfoAt(undefined, "41", "var c6t5: (n: number) => IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "42", "(parameter) n: number", "");
    // f.VerifyQuickInfoAt(undefined, "43", "var c7t2: IFoo[]", "");
    // f.VerifyQuickInfoAt(undefined, "44", "var c7t2: IFoo[]", "");
    // f.VerifyQuickInfoAt(undefined, "45", "(property) t1: (s: string) => string", "");
    // f.VerifyQuickInfoAt(undefined, "46", "(parameter) s: string", "");
    // f.VerifyQuickInfoAt(undefined, "47", "(property) t2: IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "48", "(property) t3: number[]", "");
    // f.VerifyQuickInfoAt(undefined, "49", "(property) t4: () => IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "50", "(property) t5: (n: number) => IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "51", "(parameter) n: number", "");
    // f.VerifyQuickInfoAt(undefined, "52", "(property) t6: (n: number, s: string) => IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "53", "(parameter) n: number", "");
    // f.VerifyQuickInfoAt(undefined, "54", "(parameter) s: string", "");
    // f.VerifyQuickInfoAt(undefined, "55", "(property) t7: (n: number, s: string) => number", "");
    // f.VerifyQuickInfoAt(undefined, "56", "(property) t8: (n: number, s: string) => number", "");
    // f.VerifyQuickInfoAt(undefined, "57", "(parameter) n: number", "");
    // f.VerifyQuickInfoAt(undefined, "58", "(property) t9: number[][]", "");
    // f.VerifyQuickInfoAt(undefined, "59", "(property) t10: IFoo[]", "");
    // f.VerifyQuickInfoAt(undefined, "60", "(property) t11: ((n: number, s: string) => string)[]", "");
    // f.VerifyQuickInfoAt(undefined, "61", "(parameter) n: number", "");
    // f.VerifyQuickInfoAt(undefined, "62", "(parameter) s: string", "");
    // f.VerifyQuickInfoAt(undefined, "63", "(property) t12: IBar", "");
    // f.VerifyQuickInfoAt(undefined, "64", "(property) IBar.foo: IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "65", "(property) t13: IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "66", "(method) IFoo.f(i: number, s: string): string", "");
    // f.VerifyQuickInfoAt(undefined, "67", "(parameter) i: number", "");
    // f.VerifyQuickInfoAt(undefined, "68", "(parameter) s: string", "");
    // f.VerifyQuickInfoAt(undefined, "69", "(property) t14: IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "70", "(property) IFoo.a: number[]", "");
    // f.VerifyQuickInfoAt(undefined, "71", "(parameter) n: number", "");
    // f.VerifyQuickInfoAt(undefined, "72", "var c10t5: () => (n: number) => IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "73", "(parameter) n: number", "");
    // f.VerifyQuickInfoAt(undefined, "74", "(parameter) n: number", "");
    // f.VerifyQuickInfoAt(undefined, "75", "var c12t1: (s: string) => string", "");
    // f.VerifyQuickInfoAt(undefined, "76", "(parameter) s: string", "");
    // f.VerifyQuickInfoAt(undefined, "77", "var c12t2: IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "78", "var c12t3: number[]", "");
    // f.VerifyQuickInfoAt(undefined, "79", "var c12t4: () => IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "80", "var c12t5: (n: number) => IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "81", "(parameter) n: number", "");
    // f.VerifyQuickInfoAt(undefined, "82", "var c12t6: (n: number, s: string) => IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "83", "(parameter) n: number", "");
    // f.VerifyQuickInfoAt(undefined, "84", "(parameter) s: string", "");
    // f.VerifyQuickInfoAt(undefined, "85", "var c12t7: (n: number, s: string) => number", "");
    // f.VerifyQuickInfoAt(undefined, "86", "var c12t8: (n: number, s: string) => number", "");
    // f.VerifyQuickInfoAt(undefined, "87", "(parameter) n: number", "");
    // f.VerifyQuickInfoAt(undefined, "88", "var c12t9: number[][]", "");
    // f.VerifyQuickInfoAt(undefined, "89", "var c12t10: IFoo[]", "");
    // f.VerifyQuickInfoAt(undefined, "90", "var c12t11: ((n: number, s: string) => string)[]", "");
    // f.VerifyQuickInfoAt(undefined, "91", "(parameter) n: number", "");
    // f.VerifyQuickInfoAt(undefined, "92", "(parameter) s: string", "");
    // f.VerifyQuickInfoAt(undefined, "93", "var c12t12: IBar", "");
    // f.VerifyQuickInfoAt(undefined, "94", "(property) IBar.foo: IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "95", "var c12t13: IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "96", "(method) IFoo.f(i: number, s: string): string", "");
    // f.VerifyQuickInfoAt(undefined, "97", "(parameter) i: number", "");
    // f.VerifyQuickInfoAt(undefined, "98", "(parameter) s: string", "");
    // f.VerifyQuickInfoAt(undefined, "99", "var c12t14: IFoo", "");
    // f.VerifyQuickInfoAt(undefined, "100", "(property) IFoo.a: number[]", "");
    // f.VerifyQuickInfoAt(undefined, "101", "function EF1(a: number, b: number): number", "");
    // f.VerifyQuickInfoAt(undefined, "102", "(parameter) a: any", "");
    // f.VerifyQuickInfoAt(undefined, "103", "(parameter) b: any", "");
    // f.VerifyQuickInfoAt(undefined, "110", "(property) Point.origin: Point", "");
    // f.VerifyQuickInfoAt(undefined, "111", "constructor Point(x: number, y: number): Point", "");
    // f.VerifyQuickInfoAt(undefined, "112", "(method) Point.add(dx: number, dy: number): Point", "");
    // f.VerifyQuickInfoAt(undefined, "113", "(parameter) dx: number", "");
    // f.VerifyQuickInfoAt(undefined, "114", "(parameter) dy: number", "");
    // f.VerifyQuickInfoAt(undefined, "115", "(method) Point.add(dx: number, dy: number): Point", "");
    // f.VerifyQuickInfoAt(undefined, "116", "(parameter) dx: number", "");
    // f.VerifyQuickInfoAt(undefined, "117", "(parameter) dy: number", "");
}

test "TestFormatNoSpaceBeforeCloseBrace4" {
    const content =
        \\new Foo(1
        \\, /* comment */    );
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "new Foo(1\n    , /* comment */);");
}

test "TestReferencesForAmbients2" {
    const content =
        \\// @Filename: /defA.ts
        \\declare module "a" {
        \\    /*1*/export type /*2*/T = number;
        \\}
        \\// @Filename: /defB.ts
        \\declare module "b" {
        \\    export import a = require("a");
        \\    export const x: a./*3*/T;
        \\}
        \\// @Filename: /defC.ts
        \\declare module "c" {
        \\    import b = require("b");
        \\    const x: b.a./*4*/T;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestGoToDefinitionFunctionType" {
    const content =
        \\const /*constDefinition*/c: () => void;
        \\/*constReference*/c();
        \\function test(/*cbDefinition*/cb: () => void) {
        \\    /*cbReference*/cb();
        \\}
        \\class C {
        \\    /*propDefinition*/prop: () => void;
        \\    m() {
        \\        this./*propReference*/prop();
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, false, "constReference", "cbReference", "propReference");
}

test "TestCodeFixSpellingJs6" {
    const content =
        \\// @allowjs: true
        \\// @checkjs: false
        \\// @noEmit: true
        \\// @filename: spellingUncheckedJS.js
        \\export var inModule = 1
        \\inmodule.toFixed()
        \\
        \\function f() {
        \\    var locals = 2 + true
        \\    locale.toFixed()
        \\}
        \\class Classe {
        \\    non = 'oui'
        \\    methode() {
        \\        // no error on 'this' references
        \\        return this.none
        \\    }
        \\}
        \\class Derivee extends Classe {
        \\    methode() {
        \\        // no error on 'super' references
        \\        return super.none
        \\    }
        \\}
        \\
        \\
        \\var object = {
        \\    spaaace: 3
        \\}
        \\object.spaaaace // error on read
        \\object.spaace = 12 // error on write
        \\object.fresh = 12 // OK
        \\other.puuuce // OK, from another file
        \\new Date().getGMTDate() // OK, from another file
        \\
        \\// No suggestions for globals from other files
        \\const atoc = setIntegral(() => console.log('ok'), 500)
        \\AudioBuffin // etc
        \\Jimmy
        \\Jon
        \\window.argle
        \\self.blargle
        \\// @filename: other.js
        \\var Jimmy = 1
        \\var John = 2
        \\Jon // error, it's from the same file
        \\var other = {
        \\    puuce: 4
        \\}
        \\window.argle
        \\self.blargle
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
}

test "TestNavigationBarItemsModules2" {
    const content =
        \\namespace Test.A { }
        \\
        \\namespace Test.B {
        \\    class Foo { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestGoToDefinitionAwait4" {
    const content =
        \\async function outerAsyncFun() {
        \\    let /*end*/af = async () => {
        \\      [|/*start*/await|] Promise.resolve(0);
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "start");
}

test "TestAutoImportProvider_wildcardExports2" {
    const content =
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/package.json
        \\{
        \\    "name": "pkg",
        \\    "version": "1.0.0",
        \\    "exports": {
        \\        "./core/*": {
        \\            "types": "./lib/core/*.d.ts",
        \\            "default": "./lib/core/*.js"
        \\        }
        \\    }
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/lib/core/test.d.ts
        \\export function test(): void;
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{
        \\    "type": "module",
        \\    "dependencies": {
        \\        "pkg": "1.0.0"
        \\    }
        \\}
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "module": "nodenext",
        \\        "lib": ["es5"]
        \\    }
        \\}
        \\// @Filename: /home/src/workspaces/project/main.ts
        \\/**/
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
//                 &.{
//                     .Label = "test",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "pkg/core/test",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
}

test "TestImportNameCodeFix_importType4" {
    const content =
        \\// @preserveValueImports: true
        \\// @isolatedModules: true
        \\// @module: es2015
        \\// @Filename: /exports.ts
        \\export interface SomeInterface {}
        \\export class SomePig {}
        \\// @Filename: /a.ts
        \\import type { SomeInterface } from "./exports.js";
        \\new SomePig/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { SomePig, type SomeInterface } from \"./exports.js\";\nnew SomePig",
    }, null );
}

test "TestFormatNestedClassWithOpenBraceOnNewLines" {
    const content =
        \\module A
        \\{
        \\    class B {
        \\        /*1*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts168);
    // f.GetOptions();
    // f.Configure(undefined, opts232);
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "}");
    _ = f.VerifyCurrentFileContent(undefined, "module A\n{\n    class B\n    {\n    }\n}");
}

test "TestGetOccurrencesLoopBreakContinue" {
    const content =
        \\var arr = [1, 2, 3, 4];
        \\label1: [|for|] (var n in arr) {
        \\    [|break|];
        \\    [|continue|];
        \\    [|br/**/eak|] label1;
        \\    [|continue|] label1;
        \\
        \\    label2: for (var i = 0; i < arr[n]; i++) {
        \\        [|break|] label1;
        \\        [|continue|] label1;
        \\
        \\        break;
        \\        continue;
        \\        break label2;
        \\        continue label2;
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
        \\                    () => { break; }
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

test "TestUnusedLocalsinConstructorFS2" {
    const content =
        \\// @noUnusedLocals: true
        \\// @noUnusedParameters: true
        \\class greeter {
        \\    [|constructor() {
        \\        var unused = 20;
        \\        var used = "dummy";
        \\        used = used + "second part";
        \\    }|]
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "\n    constructor() {\n        var used = \"dummy\";\n        used = used + \"second part\";\n    }\n", false, 0, 0);
}

test "TestCompletionListStaticProtectedMembers" {
    const content =
        \\class Base {
        \\    private static privateMethod() { }
        \\    private static privateProperty;
        \\
        \\    protected static protectedMethod() { }
        \\    protected static protectedProperty;
        \\
        \\    public static publicMethod() { }
        \\    public static publicProperty;
        \\
        \\    protected static protectedOverriddenMethod() { }
        \\    protected static protectedOverriddenProperty;
        \\
        \\    static test() {
        \\        Base./*1*/;
        \\        this./*2*/;
        \\        C1./*3*/;
        \\    }
        \\}
        \\
        \\class C1 extends Base {
        \\    protected static protectedOverriddenMethod() { }
        \\    protected static protectedOverriddenProperty;
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
//             .Includes = &.{
//                 &.{
//                     .Label =    "privateMethod",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//                 &.{
//                     .Label =    "privateProperty",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//                 &.{
//                     .Label =    "protectedMethod",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//                 &.{
//                     .Label =    "protectedProperty",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//                 &.{
//                     .Label =    "publicMethod",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//                 &.{
//                     .Label =    "publicProperty",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//                 &.{
//                     .Label =    "protectedOverriddenMethod",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//                 &.{
//                     .Label =    "protectedOverriddenProperty",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
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
//                     .Label =    "privateMethod",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//                 &.{
//                     .Label =    "privateProperty",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//                 &.{
//                     .Label =    "protectedMethod",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//                 &.{
//                     .Label =    "protectedProperty",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//                 &.{
//                     .Label =    "publicMethod",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//                 &.{
//                     .Label =    "publicProperty",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//             },
//             .Excludes = &.{
//                 "protectedOverriddenMethod",
//                 "protectedOverriddenProperty",
//             },
//         },
//     });
}

test "TestGoToDefinitionExternalModuleName3" {
    const content =
        \\// @Filename: b.ts
        \\import n = require([|'e/*1*/'|]);
        \\var x = new n.Foo();
        \\// @Filename: a.ts
        \\declare module /*2*/"e" {
        \\    class Foo { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestGoToDefinitionInMemberDeclaration" {
    const content =
        \\interface /*interfaceDefinition*/IFoo { method1(): number; }
        \\
        \\class /*classDefinition*/Foo implements IFoo {
        \\    public method1(): number { return 0; }
        \\}
        \\
        \\enum /*enumDefinition*/Enum { value1, value2 };
        \\
        \\class /*selfDefinition*/Bar {
        \\    public _interface: [|IFo/*interfaceReference*/o|] = new [|Fo/*classReferenceInInitializer*/o|]();
        \\    public _class: [|Fo/*classReference*/o|] = new Foo();
        \\    public _list: [|IF/*interfaceReferenceInList*/oo|][]=[];
        \\    public _enum: [|E/*enumReference*/num|] = [|En/*enumReferenceInInitializer*/um|].value1;
        \\    public _self: [|Ba/*selfReference*/r|];
        \\
        \\    constructor(public _inConstructor: [|IFo/*interfaceReferenceInConstructor*/o|]) {
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "interfaceReference", "interfaceReferenceInList", "interfaceReferenceInConstructor", "classReference", "classReferenceInInitializer", "enumReference", "enumReferenceInInitializer", "selfReference");
}

test "TestCompletionsImport_importType" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\export const x = 0;
        \\export class C {}
        \\/** @typedef {number} T */
        \\// @Filename: /b.js
        \\export const m = 0;
        \\/** @type {/*0*/} */
        \\/** @type {/*1*/} */
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"0", "1"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "C",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./a",
//                         },
//                     },
//                     .Detail =              undefined("class C"),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//                 &.{
//                     .Label = "T",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./a",
//                         },
//                     },
//                     .Detail =              undefined("type T = number"),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//             .Excludes = &.{
//                 "x",
//             },
//         },
//     });
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined("0"), &.{
//         .Name =        "C",
//         .Source =      "./a",
//         .Description = "Add import from \"./a\"",
//         .NewFileContent = undefined("import { C } from \"./a\";\n\nexport const m = 0;\n/** @type {} */\n/** @type {} */"),
//     });
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined("1"), &.{
//         .Name =        "T",
//         .Source =      "./a",
//         .Description = "Change 'T' to 'import(\"./a\").T'",
//         .NewFileContent = undefined("import { C } from \"./a\";\n\nexport const m = 0;\n/** @type {} */\n/** @type {import(\"./a\").} */"),
//     });
}

test "TestImportNameCodeFix_exportEquals" {
    const content =
        \\// @module: commonjs
        \\// @esModuleInterop: false
        \\// @allowSyntheticDefaultImports: false
        \\// @Filename: /a.d.ts
        \\declare function a(): void;
        \\declare namespace a {
        \\    export interface b {}
        \\}
        \\export = a;
        \\// @Filename: /b.ts
        \\a;
        \\let x: b;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    _ = f.VerifyCodeFixAll(undefined, .{
        .FixID = "fixMissingImport",
        .NewFileContent = "import { b } from \"./a\";\nimport a = require(\"./a\");\n\na;\nlet x: b;",
    });
}

test "TestQuickInfoTypedefTag" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\/**
        \\ * The typedef tag should not appear in the quickinfo.
        \\ * @typedef {{ foo: 'foo' }} Foo
        \\ */
        \\function f() { }
        \\f/*1*/()
        \\/**
        \\ * A removed comment
        \\ * @tag Usage shows that non-param tags in comments explain the typedef instead of using it
        \\ * @typedef {{ nope: any }} Nope not here
        \\ * @tag comment 2
        \\ */
        \\function g() { }
        \\g/*2*/()
        \\/**
        \\ * The whole thing is kept
        \\ * @param {Local} keep
        \\ * @typedef {{ local: any }} Local kept too
        \\ * @returns {void} also kept
        \\ */
        \\function h(keep) { }
        \\h/*3*/({ nope: 1 })
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestQuickInfoCanBeTruncated" {
    const content =
        \\// @stableTypeOrdering: true
        \\// @noLib: true
        \\interface Foo {
        \\  _0: 0;
        \\  _1: 1;
        \\  _2: 2;
        \\  _3: 3;
        \\  _4: 4;
        \\  _5: 5;
        \\  _6: 6;
        \\  _7: 7;
        \\  _8: 8;
        \\  _9: 9;
        \\  _10: 10;
        \\  _11: 11;
        \\  _12: 12;
        \\  _13: 13;
        \\  _14: 14;
        \\  _15: 15;
        \\  _16: 16;
        \\  _17: 17;
        \\  _18: 18;
        \\  _19: 19;
        \\  _20: 20;
        \\  _21: 21;
        \\  _22: 22;
        \\  _23: 23;
        \\  _24: 24;
        \\  _25: 25;
        \\  _26: 26;
        \\  _27: 27;
        \\  _28: 28;
        \\  _29: 29;
        \\  _30: 30;
        \\  _31: 31;
        \\  _32: 32;
        \\  _33: 33;
        \\  _34: 34;
        \\  _35: 35;
        \\  _36: 36;
        \\  _37: 37;
        \\  _38: 38;
        \\  _39: 39;
        \\  _40: 40;
        \\  _41: 41;
        \\  _42: 42;
        \\  _43: 43;
        \\  _44: 44;
        \\  _45: 45;
        \\  _46: 46;
        \\  _47: 47;
        \\  _48: 48;
        \\  _49: 49;
        \\  _50: 50;
        \\  _51: 51;
        \\  _52: 52;
        \\  _53: 53;
        \\  _54: 54;
        \\  _55: 55;
        \\  _56: 56;
        \\  _57: 57;
        \\  _58: 58;
        \\  _59: 59;
        \\  _60: 60;
        \\  _61: 61;
        \\  _62: 62;
        \\  _63: 63;
        \\  _64: 64;
        \\  _65: 65;
        \\  _66: 66;
        \\  _67: 67;
        \\  _68: 68;
        \\  _69: 69;
        \\  _70: 70;
        \\  _71: 71;
        \\  _72: 72;
        \\  _73: 73;
        \\  _74: 74;
        \\  _75: 75;
        \\  _76: 76;
        \\  _77: 77;
        \\  _78: 78;
        \\  _79: 79;
        \\  _80: 80;
        \\  _81: 81;
        \\  _82: 82;
        \\  _83: 83;
        \\  _84: 84;
        \\  _85: 85;
        \\  _86: 86;
        \\  _87: 87;
        \\  _88: 88;
        \\  _89: 89;
        \\  _90: 90;
        \\  _91: 91;
        \\  _92: 92;
        \\  _93: 93;
        \\  _94: 94;
        \\  _95: 95;
        \\  _96: 96;
        \\  _97: 97;
        \\  _98: 98;
        \\  _99: 99;
        \\  _100: 100;
        \\  _101: 101;
        \\  _102: 102;
        \\  _103: 103;
        \\  _104: 104;
        \\  _105: 105;
        \\  _106: 106;
        \\  _107: 107;
        \\  _108: 108;
        \\  _109: 109;
        \\  _110: 110;
        \\  _111: 111;
        \\  _112: 112;
        \\  _113: 113;
        \\  _114: 114;
        \\  _115: 115;
        \\  _116: 116;
        \\  _117: 117;
        \\  _118: 118;
        \\  _119: 119;
        \\  _120: 120;
        \\  _121: 121;
        \\  _122: 122;
        \\  _123: 123;
        \\  _124: 124;
        \\  _125: 125;
        \\  _126: 126;
        \\  _127: 127;
        \\  _128: 128;
        \\  _129: 129;
        \\  _130: 130;
        \\  _131: 131;
        \\  _132: 132;
        \\  _133: 133;
        \\  _134: 134;
        \\  _135: 135;
        \\  _136: 136;
        \\  _137: 137;
        \\  _138: 138;
        \\  _139: 139;
        \\  _140: 140;
        \\  _141: 141;
        \\  _142: 142;
        \\  _143: 143;
        \\  _144: 144;
        \\  _145: 145;
        \\  _146: 146;
        \\  _147: 147;
        \\  _148: 148;
        \\  _149: 149;
        \\  _150: 150;
        \\  _151: 151;
        \\  _152: 152;
        \\  _153: 153;
        \\  _154: 154;
        \\  _155: 155;
        \\  _156: 156;
        \\  _157: 157;
        \\  _158: 158;
        \\  _159: 159;
        \\  _160: 160;
        \\  _161: 161;
        \\  _162: 162;
        \\  _163: 163;
        \\  _164: 164;
        \\  _165: 165;
        \\  _166: 166;
        \\  _167: 167;
        \\  _168: 168;
        \\  _169: 169;
        \\  _170: 170;
        \\  _171: 171;
        \\  _172: 172;
        \\  _173: 173;
        \\  _174: 174;
        \\  _175: 175;
        \\  _176: 176;
        \\  _177: 177;
        \\  _178: 178;
        \\  _179: 179;
        \\  _180: 180;
        \\  _181: 181;
        \\  _182: 182;
        \\  _183: 183;
        \\  _184: 184;
        \\  _185: 185;
        \\  _186: 186;
        \\  _187: 187;
        \\  _188: 188;
        \\  _189: 189;
        \\  _190: 190;
        \\  _191: 191;
        \\  _192: 192;
        \\  _193: 193;
        \\  _194: 194;
        \\  _195: 195;
        \\  _196: 196;
        \\  _197: 197;
        \\  _198: 198;
        \\  _199: 199;
        \\  _200: 200;
        \\  _201: 201;
        \\  _202: 202;
        \\  _203: 203;
        \\  _204: 204;
        \\  _205: 205;
        \\  _206: 206;
        \\  _207: 207;
        \\  _208: 208;
        \\  _209: 209;
        \\  _210: 210;
        \\  _211: 211;
        \\  _212: 212;
        \\  _213: 213;
        \\  _214: 214;
        \\  _215: 215;
        \\  _216: 216;
        \\  _217: 217;
        \\  _218: 218;
        \\  _219: 219;
        \\  _220: 220;
        \\  _221: 221;
        \\  _222: 222;
        \\  _223: 223;
        \\  _224: 224;
        \\  _225: 225;
        \\  _226: 226;
        \\  _227: 227;
        \\  _228: 228;
        \\  _229: 229;
        \\  _230: 230;
        \\  _231: 231;
        \\  _232: 232;
        \\  _233: 233;
        \\  _234: 234;
        \\  _235: 235;
        \\  _236: 236;
        \\  _237: 237;
        \\  _238: 238;
        \\  _239: 239;
        \\  _240: 240;
        \\  _241: 241;
        \\  _242: 242;
        \\  _243: 243;
        \\  _244: 244;
        \\  _245: 245;
        \\  _246: 246;
        \\  _247: 247;
        \\  _248: 248;
        \\  _249: 249;
        \\  _250: 250;
        \\  _251: 251;
        \\  _252: 252;
        \\  _253: 253;
        \\  _254: 254;
        \\  _255: 255;
        \\  _256: 256;
        \\  _257: 257;
        \\  _258: 258;
        \\  _259: 259;
        \\  _260: 260;
        \\  _261: 261;
        \\  _262: 262;
        \\  _263: 263;
        \\  _264: 264;
        \\  _265: 265;
        \\  _266: 266;
        \\  _267: 267;
        \\  _268: 268;
        \\  _269: 269;
        \\  _270: 270;
        \\  _271: 271;
        \\  _272: 272;
        \\  _273: 273;
        \\  _274: 274;
        \\  _275: 275;
        \\  _276: 276;
        \\  _277: 277;
        \\  _278: 278;
        \\  _279: 279;
        \\  _280: 280;
        \\  _281: 281;
        \\  _282: 282;
        \\  _283: 283;
        \\  _284: 284;
        \\  _285: 285;
        \\  _286: 286;
        \\  _287: 287;
        \\  _288: 288;
        \\  _289: 289;
        \\  _290: 290;
        \\  _291: 291;
        \\  _292: 292;
        \\  _293: 293;
        \\  _294: 294;
        \\  _295: 295;
        \\  _296: 296;
        \\  _297: 297;
        \\  _298: 298;
        \\  _299: 299;
        \\  _300: 300;
        \\  _301: 301;
        \\  _302: 302;
        \\  _303: 303;
        \\  _304: 304;
        \\  _305: 305;
        \\  _306: 306;
        \\  _307: 307;
        \\  _308: 308;
        \\  _309: 309;
        \\  _310: 310;
        \\  _311: 311;
        \\  _312: 312;
        \\  _313: 313;
        \\  _314: 314;
        \\  _315: 315;
        \\  _316: 316;
        \\  _317: 317;
        \\  _318: 318;
        \\  _319: 319;
        \\  _320: 320;
        \\  _321: 321;
        \\  _322: 322;
        \\  _323: 323;
        \\  _324: 324;
        \\  _325: 325;
        \\  _326: 326;
        \\  _327: 327;
        \\  _328: 328;
        \\  _329: 329;
        \\  _330: 330;
        \\  _331: 331;
        \\  _332: 332;
        \\  _333: 333;
        \\  _334: 334;
        \\  _335: 335;
        \\  _336: 336;
        \\  _337: 337;
        \\  _338: 338;
        \\  _339: 339;
        \\  _340: 340;
        \\  _341: 341;
        \\  _342: 342;
        \\  _343: 343;
        \\  _344: 344;
        \\  _345: 345;
        \\  _346: 346;
        \\  _347: 347;
        \\  _348: 348;
        \\  _349: 349;
        \\  _350: 350;
        \\  _351: 351;
        \\  _352: 352;
        \\  _353: 353;
        \\  _354: 354;
        \\  _355: 355;
        \\  _356: 356;
        \\  _357: 357;
        \\  _358: 358;
        \\  _359: 359;
        \\  _360: 360;
        \\  _361: 361;
        \\  _362: 362;
        \\  _363: 363;
        \\  _364: 364;
        \\  _365: 365;
        \\  _366: 366;
        \\  _367: 367;
        \\  _368: 368;
        \\  _369: 369;
        \\  _370: 370;
        \\  _371: 371;
        \\  _372: 372;
        \\  _373: 373;
        \\  _374: 374;
        \\  _375: 375;
        \\  _376: 376;
        \\  _377: 377;
        \\  _378: 378;
        \\  _379: 379;
        \\  _380: 380;
        \\  _381: 381;
        \\  _382: 382;
        \\  _383: 383;
        \\  _384: 384;
        \\  _385: 385;
        \\  _386: 386;
        \\  _387: 387;
        \\  _388: 388;
        \\  _389: 389;
        \\  _390: 390;
        \\  _391: 391;
        \\  _392: 392;
        \\  _393: 393;
        \\  _394: 394;
        \\  _395: 395;
        \\  _396: 396;
        \\  _397: 397;
        \\  _398: 398;
        \\  _399: 399;
        \\  _400: 400;
        \\  _401: 401;
        \\  _402: 402;
        \\  _403: 403;
        \\  _404: 404;
        \\  _405: 405;
        \\  _406: 406;
        \\  _407: 407;
        \\  _408: 408;
        \\  _409: 409;
        \\  _410: 410;
        \\  _411: 411;
        \\  _412: 412;
        \\  _413: 413;
        \\  _414: 414;
        \\  _415: 415;
        \\  _416: 416;
        \\  _417: 417;
        \\  _418: 418;
        \\  _419: 419;
        \\  _420: 420;
        \\  _421: 421;
        \\  _422: 422;
        \\  _423: 423;
        \\  _424: 424;
        \\  _425: 425;
        \\  _426: 426;
        \\  _427: 427;
        \\  _428: 428;
        \\  _429: 429;
        \\  _430: 430;
        \\  _431: 431;
        \\  _432: 432;
        \\  _433: 433;
        \\  _434: 434;
        \\  _435: 435;
        \\  _436: 436;
        \\  _437: 437;
        \\  _438: 438;
        \\  _439: 439;
        \\  _440: 440;
        \\  _441: 441;
        \\  _442: 442;
        \\  _443: 443;
        \\  _444: 444;
        \\  _445: 445;
        \\  _446: 446;
        \\  _447: 447;
        \\  _448: 448;
        \\  _449: 449;
        \\  _450: 450;
        \\  _451: 451;
        \\  _452: 452;
        \\  _453: 453;
        \\  _454: 454;
        \\  _455: 455;
        \\  _456: 456;
        \\  _457: 457;
        \\  _458: 458;
        \\  _459: 459;
        \\  _460: 460;
        \\  _461: 461;
        \\  _462: 462;
        \\  _463: 463;
        \\  _464: 464;
        \\  _465: 465;
        \\  _466: 466;
        \\  _467: 467;
        \\  _468: 468;
        \\  _469: 469;
        \\  _470: 470;
        \\  _471: 471;
        \\  _472: 472;
        \\  _473: 473;
        \\  _474: 474;
        \\  _475: 475;
        \\  _476: 476;
        \\  _477: 477;
        \\  _478: 478;
        \\  _479: 479;
        \\  _480: 480;
        \\  _481: 481;
        \\  _482: 482;
        \\  _483: 483;
        \\  _484: 484;
        \\  _485: 485;
        \\  _486: 486;
        \\  _487: 487;
        \\  _488: 488;
        \\  _489: 489;
        \\  _490: 490;
        \\  _491: 491;
        \\  _492: 492;
        \\  _493: 493;
        \\  _494: 494;
        \\  _495: 495;
        \\  _496: 496;
        \\  _497: 497;
        \\  _498: 498;
        \\  _499: 499;
        \\}
        \\type A/*1*/ = keyof Foo;
        \\type Exclude<T, U> = T extends U ? never : T;
        \\type Less/*2*/ = Exclude<A, "_0">;
        \\function f<T extends A>(s: T, x: Exclude<A, T>, y: string) {}
        \\f("_499", /*3*/);
        \\type Decomposed/*4*/ = {[K in A]: Foo[K]}
        \\type LongTuple/*5*/ = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17.18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70];
        \\type DeeplyMapped/*6*/ = {[K in keyof Foo]: {[K2 in keyof Foo]: [K, K2, Foo[K], Foo[K2]]}}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyQuickInfoIs(undefined, "type A = keyof Foo", "");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyQuickInfoIs(undefined, "type Less = \"_1\" | \"_10\" | \"_100\" | \"_101\" | \"_102\" | \"_103\" | \"_104\" | \"_105\" | \"_106\" | \"_107\" | \"_108\" | \"_109\" | \"_11\" | \"_110\" | \"_111\" | \"_112\" | \"_113\" | \"_114\" | \"_115\" | \"_116\" | \"_117\" | \"_118\" | \"_119\" | \"_12\" | \"_120\" | \"_121\" | \"_122\" | \"_123\" | \"_124\" | \"_125\" | \"_126\" | \"_127\" | \"_128\" | \"_129\" | \"_13\" | \"_130\" | \"_131\" | \"_132\" | \"_133\" | \"_134\" | \"_135\" | \"_136\" | \"_137\" | \"_138\" | \"_139\" | \"_14\" | \"_140\" | \"_141\" | \"_142\" | \"_143\" | \"_144\" | \"_145\" | \"_146\" | \"_147\" | \"_148\" | \"_149\" | \"_15\" | \"_150\" | \"_151\" | \"_152\" | \"_153\" | \"_154\" | \"_155\" | \"_156\" | ... 434 more ... | \"_99\"", "");
    _ = f.GoToMarker(undefined, "3");
    _ = f.GoToMarker(undefined, "3");
    // f.VerifySignatureHelp(undefined, .{.Text = "f(s: \"_499\", x: \"_0\" | \"_1\" | \"_10\" | \"_100\" | \"_101\" | \"_102\" | \"_103\" | \"_104\" | \"_105\" | \"_106\" | \"_107\" | \"_108\" | \"_109\" | \"_11\" | \"_110\" | \"_111\" | \"_112\" | \"_113\" | \"_114\" | \"_115\" | \"_116\" | ... 477 more ... | \"_99\", y: string): void"});
    _ = f.GoToMarker(undefined, "4");
    _ = f.VerifyQuickInfoIs(undefined, "type Decomposed = {\n    _0: 0;\n    _1: 1;\n    _10: 10;\n    _100: 100;\n    _101: 101;\n    _102: 102;\n    _103: 103;\n    _104: 104;\n    _105: 105;\n    _106: 106;\n    _107: 107;\n    _108: 108;\n    _109: 109;\n    _11: 11;\n    _110: 110;\n    _111: 111;\n    _112: 112;\n    _113: 113;\n    _114: 114;\n    _115: 115;\n    _116: 116;\n    _117: 117;\n    _118: 118;\n    _119: 119;\n    _12: 12;\n    _120: 120;\n    _121: 121;\n    _122: 122;\n    _123: 123;\n    _124: 124;\n    _125: 125;\n    _126: 126;\n    _127: 127;\n    _128: 128;\n    _129: 129;\n    _13: 13;\n    _130: 130;\n    _131: 131;\n    _132: 132;\n    _133: 133;\n    _134: 134;\n    _135: 135;\n    _136: 136;\n    _137: 137;\n    _138: 138;\n    _139: 139;\n    _14: 14;\n    _140: 140;\n    _141: 141;\n    _142: 142;\n    _143: 143;\n    _144: 144;\n    _145: 145;\n    _146: 146;\n    _147: 147;\n    _148: 148;\n    _149: 149;\n    _15: 15;\n    _150: 150;\n    _151: 151;\n    _152: 152;\n    _153: 153;\n    _154: 154;\n    _155: 155;\n    _156: 156;\n    _157: 157;\n    ... 433 more ...;\n    _99: 99;\n}", "");
    _ = f.GoToMarker(undefined, "5");
    _ = f.VerifyQuickInfoIs(undefined, "type LongTuple = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17.18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70]", "");
    _ = f.GoToMarker(undefined, "6");
    _ = f.VerifyQuickInfoIs(undefined, "type DeeplyMapped = {\n    _0: {\n        _0: [\"_0\", \"_0\", 0, 0];\n        _1: [\"_0\", \"_1\", 0, 1];\n        _2: [\"_0\", \"_2\", 0, 2];\n        _3: [\"_0\", \"_3\", 0, 3];\n        _4: [\"_0\", \"_4\", 0, 4];\n        _5: [\"_0\", \"_5\", 0, 5];\n        _6: [\"_0\", \"_6\", 0, 6];\n        _7: [\"_0\", \"_7\", 0, 7];\n        _8: [\"_0\", \"_8\", 0, 8];\n        _9: [\"_0\", \"_9\", 0, 9];\n        _10: [\"_0\", \"_10\", 0, 10];\n        _11: [\"_0\", \"_11\", 0, 11];\n        _12: [\"_0\", \"_12\", 0, 12];\n        _13: [\"_0\", \"_13\", 0, 13];\n        _14: [\"_0\", \"_14\", 0, 14];\n        _15: [\"_0\", \"_15\", 0, 15];\n        _16: [\"_0\", \"_16\", 0, 16];\n        _17: [\"_0\", \"_17\", 0, 17];\n        _18: [\"_0\", \"_18\", 0, 18];\n        _19: [\"_0\", \"_19\", 0, 19];\n        _20: [\"_0\", \"_20\", 0, 20];\n        _21: [\"_0\", \"_21\", 0, 21];\n        ... 477 more ...;\n        _499: [...];\n    };\n    ... 498 more ...;\n    _499: {\n        ...;\n    };\n}", "");
}

test "TestCodeFixInferFromFunctionThisUsageObjectProperty" {
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
        \\     returnThisMember: returnThisMember,
        \\ };
        \\
        \\ container.returnThisMember();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "this: Container", false, 0, 0);
}

test "TestRenameLocationsForFunctionExpression01" {
    const content =
        \\var x = [|function [|{| "contextRangeIndex": 0 |}f|](g: any, h: any) {
        \\    [|f|]([|f|], g);
        \\}|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "f");
}

test "TestMemberCompletionOnRightSideOfImport" {
    const content =
        \\import x = M./**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "", null);
}

test "TestInlayHintsTypeMatchesName" {
    const content =
        \\type Client = {};
        \\function getClient(): Client { return {}; };
        \\const client = getClient();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayVariableTypeHints = core.TSTrue, .IncludeInlayVariableTypeHintsWhenTypeMatchesName = core.TSFalse}});
}

test "TestQuickInfoForGetterAndSetter" {
    const content =
        \\class Test {
        \\    constructor() {
        \\        this.value;
        \\    }
        \\
        \\    /** Getter text */
        \\    get val/*1*/ue() {
        \\        return this.value;
        \\    }
        \\
        \\    /** Setter text */
        \\    set val/*2*/ue(value) {
        \\        this.value = value;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyQuickInfoIs(undefined, "(getter) Test.value: any", "Getter text");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyQuickInfoIs(undefined, "(setter) Test.value: any", "Setter text");
}

test "TestUnusedFunctionInNamespaceWithTrivia" {
    const content =
        \\// @noUnusedLocals: true
        \\[| namespace greeter {
        \\  // Do not remove
        \\  /**
        \\   * JSDoc Comment
        \\   */
        \\  function function1() {
        \\  }/*1*/
        \\} |]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "namespace greeter {\n    // Do not remove\n }", false, 0, 0);
}

test "TestImportNameCodeFixNewImportFileQuoteStyle3" {
    const content =
        \\[|export { v2 } from './module2';
        \\
        \\f1/*0*/();|]
        \\// @Filename: module1.ts
        \\export function f1() {}
        \\// @Filename: module2.ts
        \\export var v2 = 6;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from './module1';\n\nexport { v2 } from './module2';\n\nf1();",
    }, null );
}

test "TestFindAllReferencesLinkTag3" {
    const content =
        \\namespace NPR/*5*/ {
        \\    export class Consider/*4*/ {
        \\        This/*3*/ = class {
        \\            show/*2*/() { }
        \\        }
        \\        m/*1*/() { }
        \\    }
        \\    /**
        \\     * {@linkcode Consider.prototype.m}
        \\     * {@linkplain Consider#m}
        \\     * {@linkcode Consider#This#show}
        \\     * {@linkplain Consider.This.show}
        \\     * {@linkcode NPR.Consider#This#show}
        \\     * {@linkplain NPR.Consider.This#show}
        \\     * {@linkcode NPR.Consider#This.show} # doesn't parse trailing .
        \\     * {@linkcode NPR.Consider.This.show}
        \\     */
        \\    export function ref() { }
        \\}
        \\/**
        \\ * {@linkplain NPR.Consider#This#show hello hello}
        \\ * {@linkplain NPR.Consider.This#show}
        \\ * {@linkcode NPR.Consider#This.show} # doesn't parse trailing .
        \\ * {@linkcode NPR.Consider.This.show}
        \\ */
        \\export function outerref() { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5");
}

test "TestCompletionListInUnclosedIndexSignature01" {
    const content =
        \\class C {
        \\    [foo: string]: typeof /*1*/
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
//                 "C",
//             },
//         },
//     });
}

test "TestCompletionsImport_duplicatePackages_typesAndNotTypes" {
    const content =
        \\// @lib: es5
        \\// @module: commonjs
        \\// @esModuleInterop: true
        \\// @Filename: /node_modules/@types/react-dom/package.json
        \\{ "name": "react-dom", "version": "1.0.0", "types": "./index.d.ts" }
        \\// @Filename: /node_modules/@types/react-dom/index.d.ts
        \\import * as React from "react";
        \\export function render(): void;
        \\// @Filename: /node_modules/@types/react/package.json
        \\{ "name": "react", "version": "1.0.0", "types": "./index.d.ts" }
        \\// @Filename: /node_modules/@types/react/index.d.ts
        \\import "./other";
        \\export declare function useState(): void;
        \\// @Filename: /node_modules/@types/react/other.d.ts
        \\export declare function useRef(): void;
        \\// @Filename: /packages/a/node_modules/react/package.json
        \\{ "name": "react", "version": "1.0.1", "types": "./index.d.ts" }
        \\// @Filename: /packages/a/node_modules/react/index.d.ts
        \\export declare function useState(): void;
        \\// @Filename: /packages/a/index.ts
        \\import "react-dom";
        \\import "react";
        \\// @Filename: /packages/a/foo.ts
        \\useState/**/
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
//                         .Label = "useState",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "react",
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

test "TestJavaScriptModules14" {
    const content =
        \\// @allowJs: true
        \\// @Filename: myMod.js
        \\if (true) {
        \\    exports.b = true;
        \\} else {
        \\    exports.n = 3;
        \\}
        \\function fn() {
        \\    exports.s = 'foo';
        \\}
        \\var invisible = true;
        \\// @Filename: isGlobal.js
        \\var y = 10;
        \\// @Filename: consumer.js
        \\var x = require('myMod');
        \\/**/;
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
//                     .Label =    "y",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//             .Excludes = &.{
//                 "invisible",
//             },
//         },
//     });
}

test "TestFindAllRefsForObjectSpread" {
    const content =
        \\interface A1 { readonly /*0*/a: string };
        \\interface A2 { /*1*/a?: number };
        \\let a1: A1;
        \\let a2: A2;
        \\let a12 = { ...a1, ...a2 };
        \\a12./*2*/a;
        \\a1./*3*/a;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2", "3");
}

test "TestHoverOverComment" {
    const content =
        \\export function f() {}
        \\//foo
        \\/**///moo
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyQuickInfoIs(undefined, "", "");
    // f.VerifyBaselineFindAllReferences(undefined, "");
    // f.VerifyBaselineGoToDefinition(undefined, false, "");
}

test "TestMultiModuleClodule" {
    const content =
        \\// @lib: es5
        \\class C {
        \\    constructor(x: number) { }
        \\    foo() { }
        \\    bar() { }
        \\    static boo() { }
        \\}
        \\
        \\namespace C {
        \\    export var x = 1;
        \\    var y = 2;
        \\}
        \\namespace C {
        \\    export function foo() { }
        \\    function baz() { return ''; }
        \\}
        \\
        \\var c = new C/*1*/(C./*2*/x);
        \\c./*3*/foo = C./*4*/foo;
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
//                 "C",
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
//             .Exact = CompletionFunctionMembersPlus(
//                 &.{
//                     &.{
//                         .Label =    "boo",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "foo",
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
    // f.VerifyCompletions(undefined, "3", &.{
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
    _ = f.VerifyNoErrors(undefined);
}

test "TestCompletionListInArrowFunctionInUnclosedCallSite01" {
    const content =
        \\declare function foo(...params: any[]): any;
        \\function getAllFiles(rootFileNames: string[]) {
        \\    var processedFiles = rootFileNames.map(fileName => foo(/*1*/
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
//                 "fileName",
//                 "rootFileNames",
//                 "getAllFiles",
//                 "foo",
//             },
//         },
//     });
}

test "TestCodeFixAddMissingImportForReactJsx1" {
    const content =
        \\// @jsx: react-jsx
        \\// @Filename: node_modules/react/index.d.ts
        \\export declare var React: any;
        \\// @Filename: node_modules/react/package.json
        \\{
        \\  "name": "react",
        \\  "types": "./index.d.ts"
        \\}
        \\// @Filename: foo.tsx
        \\ export default function Foo(){
        \\     return <></>;
        \\ }
        \\// @Filename: bar.tsx
        \\ export default function Bar(){
        \\     return <Foo></Foo>;
        \\ }
        \\// @Filename: package.json
        \\{
        \\  "dependencies": {
        \\    "react": "*"
        \\  }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "bar.tsx");
    _ = f.VerifyCodeFixAll(undefined, .{
        .FixID = "fixMissingImport",
        .NewFileContent = "import Foo from \"./foo\";\n\nexport default function Bar(){\n    return <Foo></Foo>;\n}",
    });
}

test "TestGoToDefinitionDecorator" {
    const content =
        \\// @Filename: b.ts
        \\@[|/*decoratorUse*/decorator|]
        \\class C {
        \\    @[|decora/*decoratorFactoryUse*/torFactory|](a, "22", true)
        \\    method() {}
        \\}
        \\// @Filename: a.ts
        \\function /*decoratorDefinition*/decorator(target) {
        \\    return target;
        \\}
        \\function /*decoratorFactoryDefinition*/decoratorFactory(...args) {
        \\    return target => target;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "decoratorUse", "decoratorFactoryUse");
}

test "TestCompletionAfterBrace" {
    const content =
        \\// @lib: es5
        \\
        \\}/**/
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
//             .Exact = CompletionGlobals,
//         },
//     });
}

test "TestGoToDefinitionExternalModuleName4" {
    const content =
        \\// @Filename: b.ts
        \\import n = require('unknown/*1*/');
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestGetOccurrencesSwitchCaseDefault4" {
    const content =
        \\foo: [|switch|] (10) {
        \\    [|case|] 1:
        \\    [|case|] 2:
        \\    [|case|] 3:
        \\        [|break|];
        \\        [|break|] foo;
        \\        co/*1*/ntinue;
        \\        contin/*2*/ue foo;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Markers()));
}

test "TestQuickInfoJSDocBackticks" {
    const content =
        \\// @noEmit: true
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @strict: true
        \\// @Filename: jsdocParseMatchingBackticks.js
        \\/**
        \\ * 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "f");
    _ = f.VerifyQuickInfoIs(undefined, "function f(x: string, y: string): string", "`@param` initial at-param is OK in title comment");
    _ = f.GoToMarker(undefined, "x");
    _ = f.VerifyQuickInfoIs(undefined, "(parameter) x: string", "hi there `@param`");
    _ = f.GoToMarker(undefined, "y");
    _ = f.VerifyQuickInfoIs(undefined, "(parameter) y: string", "hi there `@ * param\nthis is the margin");
}

test "TestNavigationBarItemsTypeAlias" {
    const content =
        \\type T = number | string;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestUnclosedStringLiteralErrorRecovery" {
    const content =
        \\"an unclosed string is a terrible thing!
        \\
        \\class foo { public x() { } }
        \\var f = new foo();
        \\f./**/
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
//                 "x",
//             },
//         },
//     });
}

test "TestImportNameCodeFixNewImportFileAllComments" {
    const content =
        \\[|/*!
        \\ * This is a license or something
        \\ */
        \\/// <reference types="node" />
        \\/// <reference path="./a.ts" />
        \\/// <amd-dependency path="./b.ts" />
        \\/**
        \\ * This is a comment intended to be attached to this interface
        \\ */
        \\export interface SomeInterface {
        \\}
        \\f1/*0*/();|]
        \\// @Filename: module.ts
        \\export function f1() {}
        \\export var v1 = 5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "/*!\n * This is a license or something\n */\n/// <reference types=\"node\" />\n/// <reference path=\"./a.ts\" />\n/// <amd-dependency path=\"./b.ts\" />\n\nimport { f1 } from \"./module\";\n\n/**\n * This is a comment intended to be attached to this interface\n */\nexport interface SomeInterface {\n}\nf1();",
    }, null );
}

test "TestImportNameCodeFixOptionalImport1" {
    const content =
        \\// @Filename: a/f1.ts
        \\[|foo/*0*/();|]
        \\// @Filename: a/node_modules/bar/index.ts
        \\export function foo() {};
        \\// @Filename: a/foo.ts
        \\export { foo } from "bar";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { foo } from \"bar\";\n\nfoo();",
        "import { foo } from \"./foo\";\n\nfoo();",
    }, null );
}

test "TestFindAllRefsImportNamed" {
    const content =
        \\// @module: commonjs
        \\// @Filename: f.ts
        \\export { foo as foo }
        \\function /*start*/foo(a: number, b: number) { }
        \\// @Filename: b.ts
        \\import x = require("./f");
        \\x.foo(1, 2);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyBaselineFindAllReferences(undefined, "start");
}

test "TestTsxQuickInfo2" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        div: any
        \\    }
        \\}
        \\var x1 = <di/*1*/v></di/*2*/v>
        \\class MyElement {}
        \\var z = <My/*3*/Element></My/*4*/Element>
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(property) JSX.IntrinsicElements.div: any", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(property) JSX.IntrinsicElements.div: any", "");
    // f.VerifyQuickInfoAt(undefined, "3", "class MyElement", "");
    // f.VerifyQuickInfoAt(undefined, "4", "class MyElement", "");
}

test "TestFindAllReferPropertyAccessExpressionHeritageClause" {
    const content =
        \\class B {}
        \\function foo() {
        \\    return {/*1*/B: B};
        \\}
        \\class C extends (foo())./*2*/B {}
        \\class C1 extends foo()./*3*/B {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestDocCommentTemplateClassDeclMethods02" {
    const content =
        \\class C {
        \\    /*0*/
        \\    [Symbol.iterator]() {
        \\        return undefined;
        \\    }
        \\    /*1*/
        \\    [1 + 2 + 3 + Math.rand()](x: number, y: string, z = true) { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyJSDocCompletion(undefined, "0", 11, "/**\n     * \n     * @returns\n     */", null);
    // f.VerifyJSDocCompletion(undefined, "1", 11, "/**\n     * \n     * @param x\n     * @param y\n     * @param z\n     */", null);
}

