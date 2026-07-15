const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestDefinition01" {
    const content =
        \\// @lib: es5
        \\// @Filename: b.ts
        \\import n = require([|'./a/*1*/'|]);
        \\var x = new n.Foo();
        \\// @Filename: a.ts
        \\ /*2*/export class Foo {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestGoToDefinitionImportedNames6" {
    const content =
        \\// @Filename: b.ts
        \\import [|/*moduleAliasDefinition*/alias|] = require("./a");
        \\// @Filename: a.ts
        \\/*moduleDefinition*/export namespace Module {
        \\}
        \\export class Class {
        \\    private f;
        \\}
        \\export interface Interface {
        \\    x;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "moduleAliasDefinition");
}

test "TestNavigationBarItemsFunctionsBroken2" {
    const content =
        \\function;
        \\function f() {
        \\    function;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestFormatRemoveSpaceBetweenDotDotDotAndTypeName" {
    const content =
        \\let a: [... any[]];
        \\let b: [...   number[]];
        \\let c: [...     string[]];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "let a: [...any[]];\nlet b: [...number[]];\nlet c: [...string[]];");
}

test "TestCompletionEntryForArrayElementConstrainedToString2" {
    const content =
        \\declare function test<T extends 'a' | 'b'>(a: { foo: T[] }): void
        \\
        \\test({ foo: ['a', /*ts*/] })
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"ts"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "\"a\"",
//                 "\"b\"",
//             },
//         },
//     });
}

test "TestGoToDefinitionVariableAssignment3" {
    const content =
        \\// @filename: foo.ts
        \\const Foo = module./*def*/exports = function () {}
        \\Foo.prototype.bar = function() {}
        \\new [|Foo/*ref*/|]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "foo.ts");
    // f.VerifyBaselineGoToDefinition(undefined, true, "ref");
}

test "TestImportNameCodeFixExistingImport4" {
    const content =
        \\[|import d from "./module";
        \\f1/*0*/();|]
        \\// @Filename: module.ts
        \\export function f1() {}
        \\export var v1 = 5;
        \\export default var d1 = 6;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import d, { f1 } from \"./module\";\nf1();",
    }, null );
}

test "TestCompletionsImportDefaultExportCrash2" {
    const content =
        \\// @module: node18
        \\// @allowJs: true
        \\// @Filename: /node_modules/dom7/index.d.ts
        \\export interface Dom7Array {
        \\  length: number;
        \\  prop(propName: string): any;
        \\}
        \\
        \\export interface Dom7 {
        \\  (): Dom7Array;
        \\  fn: any;
        \\}
        \\
        \\declare const Dom7: Dom7;
        \\
        \\export {
        \\  Dom7 as $,
        \\};
        \\// @Filename: /dom7.js
        \\import * as methods from 'dom7';
        \\Object.keys(methods).forEach((methodName) => {
        \\  if (methodName === '$') return;
        \\  methods.$.fn[methodName] = methods[methodName];
        \\});
        \\
        \\export default methods.$;
        \\// @Filename: /swipe-back.js
        \\/*1*/
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
//                     .Label =               "$",
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "dom7",
//                         },
//                     },
//                     .SortText = undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//                 &.{
//                     .Label =               "Dom7",
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./dom7",
//                         },
//                     },
//                     .SortText = undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
}

test "TestCompletionListInClosedFunction01" {
    const content =
        \\function foo(x: string, y: number, z: boolean) {
        \\    /*1*/
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
//                 "x",
//                 "y",
//                 "z",
//             },
//         },
//     });
}

test "TestNavigationBarItemsItemsModuleVariables" {
    const content =
        \\// @Filename: navigationItemsModuleVariables_0.ts
        \\ /*file1*/
        \\namespace Module1 {
        \\    export var x = 0;
        \\}
        \\// @Filename: navigationItemsModuleVariables_1.ts
        \\ /*file2*/
        \\namespace Module1.SubModule {
        \\    export var y = 0;
        \\}
        \\// @Filename: navigationItemsModuleVariables_2.ts
        \\ /*file3*/
        \\namespace Module1 {
        \\    export var z = 0;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "file1");
    _ = f.VerifyBaselineDocumentSymbol(undefined);
    _ = f.GoToMarker(undefined, "file2");
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCompletionsImportDeclarationAttributesEmptyModuleSpecifier1" {
    const content =
        \\// @strict: true
        \\// @filename: global.d.ts
        \\interface ImportAttributes { 
        \\  type: "json";
        \\}
        \\// @filename: index.ts
        \\import * as ns from "" with { type: "/**/" };
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
//                 "json",
//             },
//         },
//     });
}

test "TestCodeFixClassImplementInterfaceAutoImportsReExports" {
    const content =
        \\// @Filename: node_modules/test-module/index.d.ts
        \\declare namespace e {
        \\    interface Foo {}
        \\}
        \\export = e;
        \\// @Filename: a.ts
        \\import { Foo } from "test-module";
        \\export interface A {
        \\    foo(): Foo;
        \\}
        \\// @Filename: b.ts
        \\import { A } from "./a";
        \\export class B implements A {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "b.ts");
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'A'",
        .NewFileContent = "import { Foo } from \"test-module\";\nimport { A } from \"./a\";\nexport class B implements A {\n    foo(): Foo {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestFormattingOnClasses" {
    const content =
        \\/*1*/         class                    a                  {
        \\/*2*/                                                        constructor       (       n   :                 number    )             ;
        \\/*3*/                                                        constructor       (       s   :                 string    )             ;
        \\/*4*/                                                        constructor       (       ns   :                 any    )                            {
        \\
        \\/*5*/                                                        }
        \\
        \\/*6*/                                                            public                 pgF       (           )                            {                  }
        \\
        \\/*7*/                                                            public                 pv   ;
        \\/*8*/                                                            public                 get              d       (           )                            {
        \\/*9*/                                                                                                                return              30   ;
        \\/*10*/                                                        }
        \\/*11*/                                                            public                 set              d       (       number        )                            {
        \\/*12*/                                                        }
        \\
        \\/*13*/                                                            public                 static                    get              p2       (           )                            {
        \\/*14*/                                                                                                                return                  {                  x   :                 30   ,                  y   :                 40              }   ;
        \\/*15*/                                                        }
        \\
        \\/*16*/                                                                         private                static                    d2       (           )                            {
        \\/*17*/                                                        }
        \\/*18*/                                                                         private                static                    get              p3       (           )                            {
        \\/*19*/                                                                                                                return              "string"   ;
        \\/*20*/                                                        }
        \\/*21*/                                                                         private                pv3   ;
        \\
        \\/*22*/                                                                         private                foo       (       n   :                 number    )             :                 string   ;
        \\/*23*/                                                                         private                foo       (       s   :                 string    )             :                 string   ;
        \\/*24*/                                                                         private                foo       (       ns   :                 any    )                            {
        \\/*25*/                                                                                                                return              ns.toString       (           )             ;
        \\/*26*/                                                        }
        \\/*27*/}
        \\
        \\/*28*/         class                    b              extends              a                  {
        \\/*29*/}
        \\
        \\/*30*/         class   m1b      {
        \\
        \\/*31*/}
        \\
        \\/*32*/                                                interface   m1ib                               {
        \\
        \\/*33*/  }
        \\/*34*/         class                    c              extends              m1b                  {
        \\/*35*/}
        \\
        \\/*36*/         class                    ib2              implements              m1ib                  {
        \\/*37*/}
        \\
        \\/*38*/    declare                            class                    aAmbient                  {
        \\/*39*/                                                        constructor                     (       n   :                 number    )             ;
        \\/*40*/                                                        constructor                     (       s   :                 string    )             ;
        \\/*41*/                                                            public                 pgF       (           )             :                 void   ;
        \\/*42*/                                                            public                 pv   ;
        \\/*43*/                                                            public                 d                 :                 number   ;
        \\/*44*/                                                        static                    p2                 :                     {                  x   :                 number   ;              y   :                 number   ;              }   ;
        \\/*45*/                                                        static                    d2       (           )             ;
        \\/*46*/                                                        static                    p3   ;
        \\/*47*/                                                                         private                pv3   ;
        \\/*48*/                                                                         private                foo       (       s    )             ;
        \\/*49*/}
        \\
        \\/*50*/         class                    d                  {
        \\/*51*/                                                                         private                foo       (       n   :                 number    )             :                 string   ;
        \\/*52*/                                                                         private                foo       (       s   :                 string    )             :                 string   ;
        \\/*53*/                                                                         private                foo       (       ns   :                 any    )                            {
        \\/*54*/                                                                                                                return              ns.toString       (           )             ;
        \\/*55*/                                                        }
        \\/*56*/}
        \\
        \\/*57*/         class                    e                  {
        \\/*58*/                                                                         private                foo       (       s   :                 string    )             :                 string   ;
        \\/*59*/                                                                         private                foo       (       n   :                 number    )             :                 string   ;
        \\/*60*/                                                                         private                foo       (       ns   :                 any    )                            {
        \\/*61*/                                                                                                                return              ns.toString       (           )             ;
        \\/*62*/                                                        }
        \\/*63*/                                                                         protected              bar        (            )  {                 }
        \\/*64*/                                                                         protected     static   bar2       (            )  {                 }
        \\/*65*/                                                                         private                pv4  :    number =
        \\/*66*/                                                                         {};
        \\/*END*/}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "class a {");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "    constructor(n: number);");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "    constructor(s: string);");
    _ = f.GoToMarker(undefined, "4");
    _ = f.VerifyCurrentLineContent(undefined, "    constructor(ns: any) {");
    _ = f.GoToMarker(undefined, "5");
    _ = f.VerifyCurrentLineContent(undefined, "    }");
    _ = f.GoToMarker(undefined, "6");
    _ = f.VerifyCurrentLineContent(undefined, "    public pgF() { }");
    _ = f.GoToMarker(undefined, "7");
    _ = f.VerifyCurrentLineContent(undefined, "    public pv;");
    _ = f.GoToMarker(undefined, "8");
    _ = f.VerifyCurrentLineContent(undefined, "    public get d() {");
    _ = f.GoToMarker(undefined, "9");
    _ = f.VerifyCurrentLineContent(undefined, "        return 30;");
    _ = f.GoToMarker(undefined, "10");
    _ = f.VerifyCurrentLineContent(undefined, "    }");
    _ = f.GoToMarker(undefined, "11");
    _ = f.VerifyCurrentLineContent(undefined, "    public set d(number) {");
    _ = f.GoToMarker(undefined, "12");
    _ = f.VerifyCurrentLineContent(undefined, "    }");
    _ = f.GoToMarker(undefined, "13");
    _ = f.VerifyCurrentLineContent(undefined, "    public static get p2() {");
    _ = f.GoToMarker(undefined, "14");
    _ = f.VerifyCurrentLineContent(undefined, "        return { x: 30, y: 40 };");
    _ = f.GoToMarker(undefined, "15");
    _ = f.VerifyCurrentLineContent(undefined, "    }");
    _ = f.GoToMarker(undefined, "16");
    _ = f.VerifyCurrentLineContent(undefined, "    private static d2() {");
    _ = f.GoToMarker(undefined, "17");
    _ = f.VerifyCurrentLineContent(undefined, "    }");
    _ = f.GoToMarker(undefined, "18");
    _ = f.VerifyCurrentLineContent(undefined, "    private static get p3() {");
    _ = f.GoToMarker(undefined, "19");
    _ = f.VerifyCurrentLineContent(undefined, "        return \"string\";");
    _ = f.GoToMarker(undefined, "20");
    _ = f.VerifyCurrentLineContent(undefined, "    }");
    _ = f.GoToMarker(undefined, "21");
    _ = f.VerifyCurrentLineContent(undefined, "    private pv3;");
    _ = f.GoToMarker(undefined, "22");
    _ = f.VerifyCurrentLineContent(undefined, "    private foo(n: number): string;");
    _ = f.GoToMarker(undefined, "23");
    _ = f.VerifyCurrentLineContent(undefined, "    private foo(s: string): string;");
    _ = f.GoToMarker(undefined, "24");
    _ = f.VerifyCurrentLineContent(undefined, "    private foo(ns: any) {");
    _ = f.GoToMarker(undefined, "25");
    _ = f.VerifyCurrentLineContent(undefined, "        return ns.toString();");
    _ = f.GoToMarker(undefined, "26");
    _ = f.VerifyCurrentLineContent(undefined, "    }");
    _ = f.GoToMarker(undefined, "27");
    _ = f.VerifyCurrentLineContent(undefined, "}");
    _ = f.GoToMarker(undefined, "28");
    _ = f.VerifyCurrentLineContent(undefined, "class b extends a {");
    _ = f.GoToMarker(undefined, "29");
    _ = f.VerifyCurrentLineContent(undefined, "}");
    _ = f.GoToMarker(undefined, "30");
    _ = f.VerifyCurrentLineContent(undefined, "class m1b {");
    _ = f.GoToMarker(undefined, "31");
    _ = f.VerifyCurrentLineContent(undefined, "}");
    _ = f.GoToMarker(undefined, "32");
    _ = f.VerifyCurrentLineContent(undefined, "interface m1ib {");
    _ = f.GoToMarker(undefined, "33");
    _ = f.VerifyCurrentLineContent(undefined, "}");
    _ = f.GoToMarker(undefined, "34");
    _ = f.VerifyCurrentLineContent(undefined, "class c extends m1b {");
    _ = f.GoToMarker(undefined, "35");
    _ = f.VerifyCurrentLineContent(undefined, "}");
    _ = f.GoToMarker(undefined, "36");
    _ = f.VerifyCurrentLineContent(undefined, "class ib2 implements m1ib {");
    _ = f.GoToMarker(undefined, "37");
    _ = f.VerifyCurrentLineContent(undefined, "}");
    _ = f.GoToMarker(undefined, "38");
    _ = f.VerifyCurrentLineContent(undefined, "declare class aAmbient {");
    _ = f.GoToMarker(undefined, "39");
    _ = f.VerifyCurrentLineContent(undefined, "    constructor(n: number);");
    _ = f.GoToMarker(undefined, "40");
    _ = f.VerifyCurrentLineContent(undefined, "    constructor(s: string);");
    _ = f.GoToMarker(undefined, "41");
    _ = f.VerifyCurrentLineContent(undefined, "    public pgF(): void;");
    _ = f.GoToMarker(undefined, "42");
    _ = f.VerifyCurrentLineContent(undefined, "    public pv;");
    _ = f.GoToMarker(undefined, "43");
    _ = f.VerifyCurrentLineContent(undefined, "    public d: number;");
    _ = f.GoToMarker(undefined, "44");
    _ = f.VerifyCurrentLineContent(undefined, "    static p2: { x: number; y: number; };");
    _ = f.GoToMarker(undefined, "45");
    _ = f.VerifyCurrentLineContent(undefined, "    static d2();");
    _ = f.GoToMarker(undefined, "46");
    _ = f.VerifyCurrentLineContent(undefined, "    static p3;");
    _ = f.GoToMarker(undefined, "47");
    _ = f.VerifyCurrentLineContent(undefined, "    private pv3;");
    _ = f.GoToMarker(undefined, "48");
    _ = f.VerifyCurrentLineContent(undefined, "    private foo(s);");
    _ = f.GoToMarker(undefined, "49");
    _ = f.VerifyCurrentLineContent(undefined, "}");
    _ = f.GoToMarker(undefined, "50");
    _ = f.VerifyCurrentLineContent(undefined, "class d {");
    _ = f.GoToMarker(undefined, "51");
    _ = f.VerifyCurrentLineContent(undefined, "    private foo(n: number): string;");
    _ = f.GoToMarker(undefined, "52");
    _ = f.VerifyCurrentLineContent(undefined, "    private foo(s: string): string;");
    _ = f.GoToMarker(undefined, "53");
    _ = f.VerifyCurrentLineContent(undefined, "    private foo(ns: any) {");
    _ = f.GoToMarker(undefined, "54");
    _ = f.VerifyCurrentLineContent(undefined, "        return ns.toString();");
    _ = f.GoToMarker(undefined, "55");
    _ = f.VerifyCurrentLineContent(undefined, "    }");
    _ = f.GoToMarker(undefined, "56");
    _ = f.VerifyCurrentLineContent(undefined, "}");
    _ = f.GoToMarker(undefined, "57");
    _ = f.VerifyCurrentLineContent(undefined, "class e {");
    _ = f.GoToMarker(undefined, "58");
    _ = f.VerifyCurrentLineContent(undefined, "    private foo(s: string): string;");
    _ = f.GoToMarker(undefined, "59");
    _ = f.VerifyCurrentLineContent(undefined, "    private foo(n: number): string;");
    _ = f.GoToMarker(undefined, "60");
    _ = f.VerifyCurrentLineContent(undefined, "    private foo(ns: any) {");
    _ = f.GoToMarker(undefined, "61");
    _ = f.VerifyCurrentLineContent(undefined, "        return ns.toString();");
    _ = f.GoToMarker(undefined, "62");
    _ = f.VerifyCurrentLineContent(undefined, "    }");
    _ = f.GoToMarker(undefined, "63");
    _ = f.VerifyCurrentLineContent(undefined, "    protected bar() { }");
    _ = f.GoToMarker(undefined, "64");
    _ = f.VerifyCurrentLineContent(undefined, "    protected static bar2() { }");
    _ = f.GoToMarker(undefined, "65");
    _ = f.VerifyCurrentLineContent(undefined, "    private pv4: number =");
    _ = f.GoToMarker(undefined, "66");
    _ = f.VerifyCurrentLineContent(undefined, "        {};");
    _ = f.GoToMarker(undefined, "END");
    _ = f.VerifyCurrentLineContent(undefined, "}");
}

test "TestGoToImplementationNamespace_03" {
    const content =
        \\namespace Foo {
        \\    export interface Bar {
        \\        hello(): void;
        \\    }
        \\
        \\    class [|BarImpl|] implements Bar {
        \\        hello() {}
        \\    }
        \\}
        \\
        \\class [|Baz|] implements Foo.Bar {
        \\    hello() {}
        \\}
        \\
        \\var someVar1 : Foo.Bar = [|{ hello: () => {/**1*/} }|];
        \\
        \\var someVar2 = <Foo.Bar> [|{ hello: () => {/**2*/} }|];
        \\
        \\function whatever(x: Foo.Ba/*reference*/r) {
        \\
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "reference");
}

test "TestGoToDefinitionAwait3" {
    const content =
        \\class C {
        \\    notAsync() {
        \\      [|/*start1*/await|] Promise.resolve(0);
        \\    }
        \\
        \\    async /*end2*/foo() {
        \\      [|/*start2*/await|] Promise.resolve(0);
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "start1", "start2");
}

test "TestImportNameCodeFix_importType3" {
    const content =
        \\// @verbatimModuleSyntax: true
        \\// @module: es2015
        \\// @Filename: /exports.ts
        \\class SomeClass {}
        \\export type { SomeClass };
        \\// @Filename: /a.ts
        \\import {} from "./exports.js";
        \\function takeSomeClass(c: SomeClass/**/)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { type SomeClass } from \"./exports.js\";\nfunction takeSomeClass(c: SomeClass)",
    }, null );
}

test "TestCompletionListForDerivedType1" {
    const content =
        \\interface IFoo {
        \\    bar(): IFoo;
        \\}
        \\interface IFoo2 extends IFoo {
        \\    bar2(): IFoo2;
        \\}
        \\var f: IFoo;
        \\var f2: IFoo2;
        \\f./*1*/; // completion here shows bar with return type is any
        \\f2./*2*/ // here bar has return type any, but bar2 is Foo2
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
//                     .Label =  "bar",
//                     .Detail = undefined("(method) IFoo.bar(): IFoo"),
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
//                     .Label =  "bar",
//                     .Detail = undefined("(method) IFoo.bar(): IFoo"),
//                 },
//                 &.{
//                     .Label =  "bar2",
//                     .Detail = undefined("(method) IFoo2.bar2(): IFoo2"),
//                 },
//             },
//         },
//     });
}

test "TestContextuallyTypedObjectLiteralMethodDeclarationParam01" {
    const content =
        \\// @noImplicitAny: true
        \\interface A {
        \\    numProp: number;
        \\}
        \\
        \\interface B  {
        \\    strProp: string;
        \\}
        \\
        \\interface Foo {
        \\    method1(arg: A): void;
        \\    method2(arg: B): void;
        \\}
        \\
        \\function getFoo1(): Foo {
        \\    return {
        \\        method1(/*param1*/arg) {
        \\            arg.numProp = 10;
        \\        },
        \\        method2(/*param2*/arg) {
        \\            arg.strProp = "hello";
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "param1", "(parameter) arg: A", "");
    // f.VerifyQuickInfoAt(undefined, "param2", "(parameter) arg: B", "");
}

test "TestReferencesForInheritedProperties6" {
    const content =
        \\class class1 extends class1 {
        \\    /*1*/doStuff() { }
        \\}
        \\class class2 extends class1 {
        \\    doStuff() { }
        \\}
        \\
        \\var v: class2;
        \\v.doStuff();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestFindAllReferencesUndefined" {
    const content =
        \\// @Filename: /a.ts
        \\/**/undefined;
        \\
        \\void undefined;
        \\// @Filename: /b.ts
        \\undefined;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestRenameStringPropertyNames" {
    const content =
        \\var o = {
        \\    [|[|{| "contextRangeIndex": 0 |}prop|]: 0|]
        \\};
        \\
        \\o = {
        \\    [|"[|{| "contextRangeIndex": 2 |}prop|]": 1|]
        \\};
        \\
        \\o["[|prop|]"];
        \\o['[|prop|]'];
        \\o.[|prop|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "prop");
}

test "TestImportNameCodeFix_tripleSlashOrdering" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "skipDefaultLibCheck": false
        \\    }
        \\}
        \\// @Filename: /a.ts
        \\export const x = 0;
        \\// @Filename: /b.ts
        \\// some comment
        \\
        \\/// <reference lib="es2017.string" />
        \\
        \\const y = x + 1;
        \\// @Filename: /c.ts
        \\// some comment
        \\
        \\/// <reference path="jquery-1.8.3.js" />
        \\
        \\const y = x + 1;
        \\// @Filename: /d.ts
        \\// some comment
        \\
        \\/// <reference types="node" />
        \\
        \\const y = x + 1;
        \\// @Filename: /f.ts
        \\// some comment
        \\
        \\/// <amd-module name="NamedModule" />
        \\
        \\const y = x + 1;
        \\// @Filename: /g.ts
        \\// some comment
        \\
        \\/// <amd-dependency path="legacy/moduleA" name="moduleA" />
        \\
        \\const y = x + 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "// some comment\n\n/// <reference lib=\"es2017.string\" />\n\nimport { x } from \"./a\";\n\nconst y = x + 1;",
    }, null );
    _ = f.GoToFile(undefined, "/c.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "// some comment\n\n/// <reference path=\"jquery-1.8.3.js\" />\n\nimport { x } from \"./a\";\n\nconst y = x + 1;",
    }, null );
    _ = f.GoToFile(undefined, "/d.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "// some comment\n\n/// <reference types=\"node\" />\n\nimport { x } from \"./a\";\n\nconst y = x + 1;",
    }, null );
    _ = f.GoToFile(undefined, "/f.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "// some comment\n\n/// <amd-module name=\"NamedModule\" />\n\nimport { x } from \"./a\";\n\nconst y = x + 1;",
    }, null );
    _ = f.GoToFile(undefined, "/g.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "// some comment\n\n/// <amd-dependency path=\"legacy/moduleA\" name=\"moduleA\" />\n\nimport { x } from \"./a\";\n\nconst y = x + 1;",
    }, null );
}

test "TestTsxCompletion6" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        div: { ONE: string; TWO: number; }
        \\    }
        \\}
        \\var x = <div ONE='hello' /**/ />;
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
//                 "TWO",
//             },
//         },
//     });
}

test "TestSmartSelection_objectTypes" {
    const content =
        \\type X = {
        \\  /*1*/foo?: string;
        \\  /*2*/readonly /*3*/bar: { x: num/*4*/ber };
        \\  /*5*/meh
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSelectionRanges(undefined);
}

test "TestQuickInfoForIn" {
    const content =
        \\var obj;
        \\for (var /**/p in obj) { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "var p: string", "");
}

test "TestImportNameCodeFix_all" {
    const content =
        \\// @module: commonjs
        \\// @esModuleInterop: false
        \\// @allowSyntheticDefaultImports: false
        \\// @Filename: /a.ts
        \\export default function ad() {}
        \\export const a0 = 0;
        \\// @Filename: /b.ts
        \\export default function bd() {}
        \\export const b0 = 0;
        \\// @Filename: /c.ts
        \\export default function cd() {}
        \\export const c0 = 0;
        \\// @Filename: /d.ts
        \\export default function dd() {}
        \\export const d0 = 0;
        \\export const d1 = 1;
        \\// @Filename: /e.d.ts
        \\declare function e(): void;
        \\export = e;
        \\// @Filename: /disposable.d.ts
        \\export declare class Disposable { }
        \\// @Filename: /disposable_global.d.ts
        \\interface Disposable { }
        \\// @Filename: /user.ts
        \\import * as b from "./b";
        \\import { } from "./c";
        \\import dd from "./d";
        \\
        \\ad; ad; a0; a0;
        \\bd; bd; b0; b0;
        \\cd; cd; c0; c0;
        \\dd; dd; d0; d0; d1; d1;
        \\e; e;
        \\class X extends Disposable { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/user.ts");
    _ = f.VerifyCodeFixAll(undefined, .{
        .FixID = "fixMissingImport",
        .NewFileContent = "import ad, { a0 } from \"./a\";\nimport bd, * as b from \"./b\";\nimport cd, { c0 } from \"./c\";\nimport dd, { d0, d1 } from \"./d\";\nimport { Disposable } from \"./disposable\";\nimport e = require(\"./e\");\n\nad; ad; a0; a0;\nbd; bd; b.b0; b.b0;\ncd; cd; c0; c0;\ndd; dd; d0; d0; d1; d1;\ne; e;\nclass X extends Disposable { }",
    });
}

test "TestDocumentHighlightAtParameterPropertyDeclaration2" {
    const content =
        \\// @Filename: file1.ts
        \\class Foo {
        \\    // This is not valid syntax: parameter property can't be binding pattern
        \\    constructor(private {[|privateParam|]}: number,
        \\        public {[|publicParam|]}: string,
        \\        protected {[|protectedParam|]}: boolean) {
        \\
        \\        let localPrivate = [|privateParam|];
        \\        this.privateParam += 10;
        \\
        \\        let localPublic = [|publicParam|];
        \\        this.publicParam += " Hello!";
        \\
        \\        let localProtected = [|protectedParam|];
        \\        this.protectedParam = false;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestNavigationBarWithLocalVariables" {
    const content =
        \\function x(){
        \\    const x = Object()
        \\    x.foo = ""
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCodeFixMissingTypeAnnotationOnExports43_expando_functions" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @lib: es2019
        \\// @Filename: /code.ts
        \\const foo = (): void => {}
        \\foo.a = "A";
        \\foo.b = "C"
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add annotation of type '{ (): void; a: string; b: string; }'",
        .NewFileContent = "const foo: {\n    (): void;\n    a: string;\n    b: string;\n} = (): void => {}\nfoo.a = \"A\";\nfoo.b = \"C\"",
        .Index = 0,
    });
}

test "TestGoToDefinitionAwait1" {
    const content =
        \\async function /*end1*/foo() {
        \\    [|/*start1*/await|] Promise.resolve(0);
        \\}
        \\function notAsync() {
        \\    [|/*start2*/await|] Promise.resolve(0);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "start1", "start2");
}

test "TestRestArgSignatureHelp" {
    const content =
        \\function f(...x: any[]) { }
        \\f(/**/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifySignatureHelp(undefined, .{.ParameterName = "x", .IsVariadic = true, .IsVariadicSet = true});
}

test "TestFindAllRefs_jsEnum" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\/** @enum {string} */
        \\/*1*/const /*2*/E = { A: "" };
        \\/*3*/E["A"];
        \\/** @type {/*4*/E} */
        \\const e = /*5*/E.A;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5");
}

test "TestTsxFindAllReferencesUnionElementType2" {
    const content =
        \\//@Filename: file.tsx
        \\// @jsx: preserve
        \\// @noLib: true
        \\class RC1 extends React.Component<{}, {}> {
        \\    render() {
        \\        return null;
        \\    }
        \\}
        \\class RC2 extends React.Component<{}, {}> {
        \\    render() {
        \\        return null;
        \\    }
        \\    private method() { }
        \\}
        \\/*1*/var /*2*/RCComp = RC1 || RC2;
        \\/*3*/</*4*/RCComp />
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestQuickInfoJsDocGetterSetterNoCrash1" {
    const content =
        \\class A implements A {
        \\  get x(): string { return "" }
        \\}
        \\const e = new A()
        \\e.x/*1*/
        \\
        \\class B implements B {
        \\  set x(v: string) {}
        \\}
        \\const f = new B()
        \\f.x/*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(property) A.x: string", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(property) B.x: string", "");
}

test "TestCompletionListOnParamInClass" {
    const content =
        \\export class encoder {
        \\    static getEncoding(buffer: buffer/**/Pointer
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
//                 "encoder",
//             },
//             .Excludes = &.{
//                 "parseInt",
//             },
//         },
//     });
}

test "TestFindAllRefsForObjectLiteralProperties" {
    const content =
        \\var x = {
        \\    /*1*/property: {}
        \\};
        \\
        \\x./*2*/property;
        \\
        \\/*3*/let {/*4*/property: pVar} = x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestDocumentHighlights_windowsPath" {
    const content =
        \\//@Filename: C:\a\b\c.ts
        \\var /*1*/[|x|] = 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlightsWithOptions(undefined, null , &.{f.Ranges()[0].FileName()}, f.Ranges()[0]);
}

test "TestCompletionImportMeta" {
    const content =
        \\// @lib: es5
        \\// @Filename: a.ts
        \\import./*1*/
        \\// @Filename: b.ts
        \\import.meta./*2*/
        \\// @Filename: c.ts
        \\import./*3*/meta
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
//                 "meta",
//             },
//         },
//     });
    _ = f.VerifyCompletions(undefined, "2", null);
    // f.VerifyCompletions(undefined, "3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "meta",
//             },
//         },
//     });
}

test "TestQuickInfoForIndexerResultWithConstraint" {
    const content =
        \\function foo<T>(x: T) {
        \\        return x;
        \\}
        \\function other2<T extends Date>(arg: T) {
        \\    var b: { [x: string]: T };
        \\    var /*1*/r2 = foo(b); // just shows T
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(local var) r2: {\n    [x: string]: T;\n}", "");
}

test "TestCompletionForStringLiteralFromSignature" {
    const content =
        \\declare function f(a: "x"): void;
        \\declare function f(a: string): void;
        \\f("[|/**/|]");
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
//                 &.{
//                     .Label = "x",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "x",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestCompletionsWithDeprecatedTag1" {
    const content =
        \\// @strict: true
        \\// @filename: /foobar.ts
        \\/** @deprecated */
        \\export function foobar() {}
        \\// @filename: /foo.ts
        \\import { foobar/*4*/ } from "./foobar";
        \\
        \\/** @deprecated */
        \\interface Foo {
        \\    /** @deprecated */
        \\    bar(): void
        \\    /** @deprecated */
        \\    prop: number
        \\}
        \\declare const foo: Foo;
        \\declare const foooo: Fo/*1*/;
        \\foo.ba/*2*/;
        \\foo.pro/*3*/;
        \\
        \\fooba/*5*/;
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
//                     .Label =    "Foo",
//                     .Kind =     undefined(lsproto.CompletionItemKindInterface),
//                     .SortText = undefined(string(ls.DeprecateSortText(ls.SortTextLocationPriority))),
//                     .Tags =     &&.{lsproto.CompletionItemTagDeprecated},
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
//                     .Label =    "bar",
//                     .Kind =     undefined(lsproto.CompletionItemKindMethod),
//                     .SortText = undefined(string(ls.DeprecateSortText(ls.SortTextLocationPriority))),
//                     .Tags =     &&.{lsproto.CompletionItemTagDeprecated},
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
//                     .Label =    "prop",
//                     .Kind =     undefined(lsproto.CompletionItemKindField),
//                     .SortText = undefined(string(ls.DeprecateSortText(ls.SortTextLocationPriority))),
//                     .Tags =     &&.{lsproto.CompletionItemTagDeprecated},
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
//                     .Label =    "foobar",
//                     .Kind =     undefined(lsproto.CompletionItemKindFunction),
//                     .SortText = undefined(string(ls.DeprecateSortText(ls.SortTextLocationPriority))),
//                     .Tags =     &&.{lsproto.CompletionItemTagDeprecated},
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
//                     .Label =    "foobar",
//                     .Kind =     undefined(lsproto.CompletionItemKindVariable),
//                     .SortText = undefined(string(ls.DeprecateSortText(ls.SortTextLocationPriority))),
//                     .Tags =     &&.{lsproto.CompletionItemTagDeprecated},
//                 },
//             },
//         },
//     });
}

test "TestReferencesForInheritedProperties7" {
    const content =
        \\class class1 extends class1 {
        \\   /*0*/doStuff() { }
        \\   /*1*/propName: string;
        \\}
        \\interface interface1 extends interface1 {
        \\   /*2*/doStuff(): void;
        \\   /*3*/propName: string;
        \\}
        \\class class2 extends class1 implements interface1 {
        \\   /*4*/doStuff() { }
        \\   /*5*/propName: string;
        \\}
        \\
        \\var v: class2;
        \\v.doStuff();
        \\v.propName;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2", "3", "4", "5");
}

test "TestCodeFixUnusedInterfaceInNamespace1" {
    const content =
        \\// @noUnusedLocals: true
        \\ [| namespace greeter {
        \\    interface interface1 {
        \\    }
        \\} |]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "\nnamespace greeter {\n}", false, 0, 0);
}

test "TestJsDocPropertyDescription11" {
    const content =
        \\type AliasExample = {
        \\    /** Something generic */
        \\    [p: string]: string;
        \\    /** Something else */
        \\    [key: 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "alias", "(index) AliasExample[string | `any${string}`]: string", "Something generic\nSomething else");
}

test "TestGoToTypeDefinition5" {
    const content =
        \\// @Filename: foo.ts
        \\let Foo: /*definition*/unresolved;
        \\type Foo = { x: string };
        \\/*reference*/Foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToTypeDefinition(undefined, "reference");
}

test "TestCodeFixSpellingJs5" {
    const content =
        \\// @allowjs: true
        \\// @noEmit: true
        \\// @filename: a.js
        \\var other = {
        \\    puuce: 4
        \\}
        \\var Jimmy = 1
        \\var John = 2
        \\// @filename: b.js
        \\other.puuuce // OK, from another file
        \\new Date().getGMTDate() // OK, from another file
        \\window.argle // OK, from globalThis
        \\self.blargle // OK, from globalThis
        \\
        \\// No suggestions for globals from other files
        \\const atoc = setIntegral(() => console.log('ok'), 500)
        \\AudioBuffin // etc
        \\Jimmy
        \\Jon
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
}

test "TestCompletionsClassMemberImportTypeNodeParameter3" {
    const content =
        \\// @module: node18
        \\// @FileName: /other/foo.d.ts
        \\export declare type Bar = { baz: string };
        \\// @FileName: /other/cls.d.ts
        \\export declare class Cls {
        \\  method(
        \\    param: import("./foo.js").Bar,
        \\  ): import("./foo.js").Bar;
        \\}
        \\// @FileName: /index.d.ts
        \\import { Cls } from "./other/cls.js";
        \\
        \\export declare class Derived extends Cls {
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
//                     .Label =               "method",
//                     .InsertText =          undefined("method(param: import(\"./other/foo.js\").Bar): import(\"./other/foo.js\").Bar;"),
//                     .FilterText =          undefined("method"),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                 },
//             },
//         },
//     });
}

test "TestQuickInfo_errorSignatureFillsInTypeParameter" {
    const content =
        \\declare function f<T>(x: number): T;
        \\const x/**/ = f();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "const x: unknown", "");
}

test "TestCompletionListOnAliases" {
    const content =
        \\namespace M {
        \\    export var value;
        \\
        \\    import x = M;
        \\    /*1*/
        \\    x./*2*/
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
//                     .Label =  "x",
//                     .Detail = undefined("(alias) namespace x\nimport x = M"),
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
//                 "value",
//             },
//         },
//     });
}

test "TestImportTypeCompletions7" {
    const content =
        \\// @target: es2020
        \\// @module: esnext
        \\// @Filename: /foo.d.ts
        \\declare namespace Foo {}
        \\export = Foo;
        \\// @Filename: /test.ts
        \\[|import F/**/|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/test.ts");
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
//                     .InsertText = undefined("import Foo from \"./foo\";"),
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
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestCompletionListInObjectLiteral5" {
    const content =
        \\const o = 'something' 
        \\const obj = {
        \\    prop: o/*1*/,
        \\    pro() {
        \\        const obj1 = {
        \\            p:{
        \\                s: {
        \\                    h: {
        \\                       hh: o/*2*/
        \\                    },
        \\                    someFun() {
        \\                        o/*3*/
        \\                    }
        \\                }
        \\            }
        \\        }
        \\    },
        \\    o/*4*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "o",
//             },
//             .Excludes = &.{
//                 "obj",
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
//                 "o",
//                 "obj",
//             },
//             .Excludes = &.{
//                 "obj1",
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
//             .Includes = &.{
//                 "o",
//                 "obj",
//                 "obj1",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"4"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "o",
//             },
//             .Excludes = &.{
//                 "obj",
//             },
//         },
//     });
}

test "TestGetOccurrencesNonStringImportAssertion" {
    const content =
        \\// @module: node18
        \\import * as react from "react" with { cache: /**/0 };
        \\react.Children;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , "");
}

test "TestDocumentHighlightAtParameterPropertyDeclaration1" {
    const content =
        \\// @Filename: file1.ts
        \\class Foo {
        \\    constructor(private [|privateParam|]: number,
        \\        public [|publicParam|]: string,
        \\        protected [|protectedParam|]: boolean) {
        \\
        \\        let localPrivate = [|privateParam|];
        \\        this.[|privateParam|] += 10;
        \\
        \\        let localPublic = [|publicParam|];
        \\        this.[|publicParam|] += " Hello!";
        \\
        \\        let localProtected = [|protectedParam|];
        \\        this.[|protectedParam|] = false;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestOrganizeImports2" {
    const content =
        \\import {
        \\    Foo   
        \\ , Bar   
        \\} from "foo"
        \\
        \\console.log(Foo, Bar);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(undefined,
//         "import {\n    Bar,\n    Foo\n} from \"foo\";\n\nconsole.log(Foo, Bar);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestJavaScriptModules13" {
    const content =
        \\// @allowJs: true
        \\// @Filename: myMod.js
        \\if (true) {
        \\    module.exports = { a: 10 };
        \\}
        \\var invisible = true;
        \\// @Filename: isGlobal.js
        \\var y = 10;
        \\// @Filename: consumer.js
        \\var x = require('./myMod');
        \\/**/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "consumer.js");
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
//                     .Label =    "y",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//             .Excludes = &.{
//                 "invisible",
//             },
//         },
//     });
    _ = f.Insert(undefined, "x.");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "a",
//                     .Kind =  undefined(lsproto.CompletionItemKindField),
//                 },
//             },
//         },
//     });
    _ = f.Insert(undefined, "a.");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "toFixed",
//                     .Kind =  undefined(lsproto.CompletionItemKindMethod),
//                 },
//             },
//         },
//     });
}

test "TestFormattingVoid" {
    const content =
        \\/*1*/  var x: () =>           void    ;
        \\/*2*/  var y:     void    ;
        \\/*3*/  function test(a:void,b:string){}
        \\/*4*/  var a, b, c, d;
        \\/*5*/  void    a    ;
        \\/*6*/  void        (0);
        \\/*7*/  b=void(c=1,d=2);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "var x: () => void;");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "var y: void;");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "function test(a: void, b: string) { }");
    _ = f.GoToMarker(undefined, "5");
    _ = f.VerifyCurrentLineContent(undefined, "void a;");
    _ = f.GoToMarker(undefined, "6");
    _ = f.VerifyCurrentLineContent(undefined, "void (0);");
    _ = f.GoToMarker(undefined, "7");
    _ = f.VerifyCurrentLineContent(undefined, "b = void (c = 1, d = 2);");
}

test "TestCompletionListInExportClause02" {
    const content =
        \\declare module "M1" {
        \\    export var V;
        \\}
        \\var W;
        \\declare module "M2" {
        \\    export { /**/ } from "M1"
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
//                 "V",
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestFindAllRefsDestructureGetter" {
    const content =
        \\class Test {
        \\    get /*x0*/x() { return 0; }
        \\
        \\    set /*y0*/y(a: number) {}
        \\}
        \\const { /*x1*/x, /*y1*/y } = new Test();
        \\/*x2*/x; /*y2*/y;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "x0", "x1", "x2", "y0", "y1", "y2");
}

test "TestCodefixClassImplementInterface_omit" {
    const content =
        \\interface One {
        \\    a: number;
        \\    b: string;
        \\}
        \\
        \\interface Two extends Omit<One, "a"> {
        \\    c: boolean;
        \\}
        \\
        \\class TwoStore implements Two {[| |]}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'Two'",
        .NewFileContent = "interface One {\n    a: number;\n    b: string;\n}\n\ninterface Two extends Omit<One, \"a\"> {\n    c: boolean;\n}\n\nclass TwoStore implements Two {\n    c: boolean;\n    b: string;\n}",
        .Index = 0,
    });
}

test "TestImportNameCodeFix_pathsWithExtension" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "target": "ESNext",
        \\    "module": "Node16",
        \\    "moduleResolution": "Node16",
        \\    "rootDir": "./src",
        \\    "outDir": "./dist",
        \\    "paths": {
        \\      "#internals/*": ["./src/internals/*.ts"]
        \\    }
        \\  },
        \\  "include": ["src"]
        \\}
        \\// @Filename: /src/internals/example.ts
        \\export function helloWorld() {}
        \\// @Filename: /src/index.ts
        \\helloWorld/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"#internals/example"}, &.{.ImportModuleSpecifierEnding = "js"});
}

test "TestInlayHintsQuotePreference1" {
    const content =
        \\const a1: '"' = '"';
        \\const b1: '\\' = '\\';
        \\export function fn(a = a1, b = b1) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.QuotePreference = lsutil.QuotePreference("double"), .InlayHints = .{.IncludeInlayFunctionParameterTypeHints = core.TSTrue}});
}

test "TestJsdocImportTagCompletion1" {
    const content =
        \\// @allowJS: true
        \\// @checkJs: true
        \\// @filename: /a.js
        \\/**
        \\ * @/**/
        \\ */
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
//                 "import",
//             },
//         },
//     });
}

test "TestImportCompletionsPackageJsonExportsTrailingSlash1" {
    const content =
        \\// @module: node18
        \\// @moduleResolution: nodenext
        \\// @Filename: /node_modules/pkg/package.json
        \\{
        \\    "name": "pkg",
        \\    "version": "1.0.0",
        \\    "exports": {
        \\      "./test/": "./"
        \\    }
        \\ }
        \\// @Filename: /node_modules/pkg/foo.d.ts
        \\export function foo(): void;
        \\// @Filename: /package.json
        \\{
        \\    "dependencies": {
        \\       "pkg": "*"
        \\    }
        \\ }
        \\// @Filename: /index.ts
        \\import {} from "pkg//*1*/";
        \\import {} from "pkg/test//*2*/";
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
//                 "test",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"2"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "foo.js",
//             },
//         },
//     });
}

test "TestStaticGenericOverloads1" {
    const content =
        \\class A<T> {
        \\    static B<S>(v: A<S>): A<S>;
        \\    static B<S>(v: S): A<S>;
        \\    static B<S>(v: any): A<S> {
        \\        return null;
        \\    }
        \\}
        \\var a = new A<number>();
        \\A.B(/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
    _ = f.Insert(undefined, "a");
    // f.VerifySignatureHelp(undefined, .{.Text = "B(v: A<number>): A<number>", .OverloadsCount = 2});
    _ = f.Insert(undefined, "); A.B(");
    // f.VerifySignatureHelp(undefined, .{.Text = "B(v: A<unknown>): A<unknown>", .OverloadsCount = 2});
    _ = f.Insert(undefined, "a");
    // f.VerifySignatureHelp(undefined, .{.Text = "B(v: A<number>): A<number>", .OverloadsCount = 2});
}

test "TestCompletionsImport_require_addNew" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\const x = 0;
        \\module.exports = { x };
        \\// @Filename: /b.js
        \\x/**/
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
//                     .Label = "x",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./a",
//                         },
//                     },
//                     .Detail =              undefined("(alias) const x: 0\nimport x"),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "x",
//         .Source =      "./a",
//         .Description = "Add import from \"./a\"",
//         .NewFileContent = undefined("const { x } = require(\"./a\");\n\nx"),
//     });
}

test "TestImportNameCodeFix_barrelExport" {
    const content =
        \\// @module: commonjs
        \\// @Filename: /foo/a.ts
        \\export const A = 0;
        \\// @Filename: /foo/b.ts
        \\export {};
        \\A/*sibling*/
        \\// @Filename: /foo/index.ts
        \\export * from "./a";
        \\export * from "./b";
        \\// @Filename: /index.ts
        \\export * from "./foo";
        \\export * from "./src";
        \\// @Filename: /src/a.ts
        \\export {};
        \\A/*parent*/
        \\// @Filename: /src/index.ts
        \\export * from "./a";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyImportFixModuleSpecifiers(undefined, "sibling", &.{"./a", ".", ".."}, null );
    // f.VerifyImportFixModuleSpecifiers(undefined, "parent", &.{"../foo", "../foo/a", ".."}, null );
}

test "TestInlayHintsWithClosures" {
    const content =
        \\function foo1(a: number) {
        \\    return (b: number) => {
        \\        return a + b
        \\    }
        \\}
        \\foo1(1)(2);
        \\function foo2(a: (b: number) => number) {
        \\    return a(1) + 2
        \\}
        \\foo2((c: number) => c + 1);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayParameterNameHints = lsutil.IncludeInlayParameterNameHintsAll}});
}

test "TestCodeFixMissingTypeAnnotationOnExports39_extract_arr_to_variable" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @lib: es2019
        \\// @Filename: /code.ts
        \\let c: string[] = [];
        \\export let o = {
        \\    p: [
        \\        ...c
        \\    ]
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Mark array literal as const",
        .NewFileContent = "let c: string[] = [];\nexport let o = {\n    p: [\n        ...c\n    ] as const\n}",
        .Index =        2,
        .ApplyChanges = true,
    });
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Extract to variable and replace with 'newLocal as typeof newLocal'",
        .NewFileContent = "let c: string[] = [];\nconst newLocal = [\n    ...c\n] as const;\nexport let o = {\n    p: newLocal as typeof newLocal\n}",
        .Index =        1,
        .ApplyChanges = true,
    });
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add annotation of type 'readonly string[]'",
        .NewFileContent = "let c: string[] = [];\nconst newLocal: readonly string[] = [\n    ...c\n] as const;\nexport let o = {\n    p: newLocal as typeof newLocal\n}",
        .Index =        0,
        .ApplyChanges = true,
    });
}

test "TestQuickInfoSignatureRestParameterFromUnion4" {
    const content =
        \\declare const fn:
        \\  | ((a?: { x: number }, b?: { x: number }) => number)
        \\  | ((...a: { y: number }[]) => number);
        \\
        \\/**/fn();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "const fn: (a?: {\n    x: number;\n} & {\n    y: number;\n}, b?: {\n    x: number;\n} & {\n    y: number;\n}, ...args: {\n    y: number;\n}[]) => number", "");
}

test "TestIndentationInJsx3" {
    const content =
        \\//@Filename: file.tsx
        \\function foo() {
        \\   return (
        \\        <div>
        \\hello
        \\goodbye
        \\        </div>
        \\    )
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCurrentFileContent(undefined, "function foo() {\n   return (\n        <div>\nhello\ngoodbye\n        </div>\n    )\n}");
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "function foo() {\n    return (\n        <div>\n            hello\n            goodbye\n        </div>\n    )\n}");
}

test "TestFindAllReferencesUmdModuleAsGlobalConst" {
    const content =
        \\// @Filename: /node_modules/@types/three/three-core.d.ts
        \\export class Vector3 {
        \\    constructor(x?: number, y?: number, z?: number);
        \\    x: number;
        \\    y: number;
        \\}
        \\// @Filename: /node_modules/@types/three/index.d.ts
        \\export * from "./three-core";
        \\export as namespace /*0*/THREE;
        \\// @Filename: /typings/global.d.ts
        \\import * as _THREE from '/*1*/three';
        \\declare global {
        \\    const /*2*/THREE: typeof _THREE;
        \\}
        \\// @Filename: /src/index.ts
        \\export const a = {};
        \\let v = new /*3*/THREE.Vector2();
        \\// @Filename: /tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "esModuleInterop": true,
        \\        "outDir": "./build/js/",
        \\        "noImplicitAny": true,
        \\        "module": "es6",
        \\        "target": "es6",
        \\        "allowJs": true,
        \\        "skipLibCheck": true,
        \\        "lib": ["es2016", "dom"],
        \\        "typeRoots": ["node_modules/@types/"],
        \\        "types": ["three"]
        \\     },
        \\    "files": ["/src/index.ts", "typings/global.d.ts"]
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2", "3");
}

test "TestImportNameCodeFixConvertTypeOnly1" {
    const content =
        \\// @Filename: /a.ts
        \\export class A {}
        \\export class B {}
        \\// @Filename: /b.ts
        \\import type { A } from './a';
        \\new B
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { B, type A } from './a';\nnew B",
    }, null );
}

test "TestCompletionListInUnclosedTypeOfExpression01" {
    const content =
        \\var x;
        \\var y = typeof /*1*/
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
//                 "x",
//             },
//         },
//     });
}

test "TestGoToTypeDefinitionUnionType" {
    const content =
        \\class /*definition0*/C {
        \\    p;
        \\}
        \\
        \\interface /*definition1*/I {
        \\    x;
        \\}
        \\
        \\namespace M {
        \\    export interface /*definition2*/I {
        \\        y;
        \\    }
        \\}
        \\
        \\var x: C | I | M.I;
        \\
        \\/*reference*/x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToTypeDefinition(undefined, "reference");
}

test "TestCompletionListInUnclosedFunction16" {
    const content =
        \\interface MyType {
        \\}
        \\
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string = "hello", c: typeof x = "hello") {
        \\        var v = (p: MyType) => /*1*/
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

test "TestOutliningSpansForImportAndExportAttributes" {
    const content =
        \\import { a1, a2 } from "a";
        \\;
        \\import {
        \\} from "a";
        \\;
        \\import [|{
        \\  b1,
        \\  b2,
        \\}|] from "b";
        \\;
        \\import j1 from "./j" with { type: "json" };
        \\;
        \\import j2 from "./j" with {
        \\};
        \\;
        \\import j3 from "./j" with [|{
        \\  type: "json"
        \\}|];
        \\;
        \\[|import { a5, a6 } from "a";
        \\import [|{
        \\  a7,
        \\  a8,
        \\}|] from "a";|]
        \\export { a1, a2 };
        \\;
        \\export { a3, a4 } from "a";
        \\;
        \\export {
        \\};
        \\;
        \\export [|{
        \\  b1,
        \\  b2,
        \\}|];
        \\;
        \\export {
        \\} from "b";
        \\;
        \\export [|{
        \\  b3,
        \\  b4,
        \\}|] from "b";
        \\;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOutliningSpans(undefined);
}

test "TestGotoDefinitionLinkTag4" {
    const content =
        \\// @filename: a.ts
        \\interface [|/*2*/Foo|] {
        \\    foo: E.Foo;
        \\}
        \\// @Filename: b.ts
        \\enum E {
        \\    /** {@link /*1*/[|Foo|]} */
        \\    Foo
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, false, "1");
}

test "TestCompletionListAtIdentifierDefinitionLocations_interfaces" {
    const content =
        \\var aa = 1;
        \\interface /*interfaceName1*/
        \\interface a/*interfaceName2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, f.Markers(), null);
}

test "TestCodeFixTopLevelAwait_module_compatibleCompilerOptionsInTsConfig" {
    const content =
        \\// @filename: /dir/a.ts
        \\declare const p: Promise<number>;
        \\await p;
        \\export {};
        \\// @filename: /dir/tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "target": "es2017",
        \\        "module": "esnext"
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined, "fixModuleOption");
}

test "TestReferencesForClassLocal" {
    const content =
        \\var n = 14;
        \\
        \\class foo {
        \\    /*1*/private /*2*/n = 0;
        \\
        \\    public bar() {
        \\        this./*3*/n = 9;
        \\    }
        \\
        \\    constructor() {
        \\        this./*4*/n = 4;
        \\    }
        \\
        \\    public bar2() {
        \\        var n = 12;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestCompletionListAfterRegularExpressionLiteral03" {
    const content =
        \\let v = 100;
        \\let x = /absidey/
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
//                 "v",
//             },
//         },
//     });
}

test "TestFindAllRefsDeclareClass" {
    const content =
        \\/*1*/declare class /*2*/C {
        \\    static m(): void;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestGoToDefinitionExternalModuleName" {
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

test "TestGoToDefinitionImportedNames5" {
    const content =
        \\// @Filename: b.ts
        \\export {Class as [|/*classAliasDefinition*/ClassAlias|]} from "./a";
        \\// @Filename: a.ts
        \\export namespace Module {
        \\}
        \\export class /*classDefinition*/Class {
        \\    private f;
        \\}
        \\export interface Interface {
        \\    x;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "classAliasDefinition");
}

test "TestGetJavaScriptSyntacticDiagnostics13" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\var v: () => number;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestGetOccurrencesThisNegatives2" {
    const content =
        \\this;
        \\this;
        \\
        \\function f() {
        \\    this;
        \\    this;
        \\    () => this;
        \\    () => {
        \\        if (this) {
        \\            this;
        \\        }
        \\        else {
        \\            this.t/*1*/his;
        \\        }
        \\    }
        \\    function inside() {
        \\        this;
        \\        (function (_) {
        \\            this;
        \\        })(this);
        \\    }
        \\}
        \\
        \\namespace m {
        \\    function f() {
        \\        this;
        \\        this;
        \\        () => this;
        \\        () => {
        \\            if (this) {
        \\                this;
        \\            }
        \\            else {
        \\                this./*2*/this;
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
        \\
        \\class A {
        \\    public b = this.method1;
        \\
        \\    public method1() {
        \\        this;
        \\        this;
        \\        () => this;
        \\        () => {
        \\            if (this) {
        \\                this;
        \\            }
        \\            else {
        \\                this.thi/*3*/s;
        \\            }
        \\        }
        \\        function inside() {
        \\            this;
        \\            (function (_) {
        \\                this;
        \\            })(this);
        \\        }
        \\    }
        \\
        \\    private method2() {
        \\        this;
        \\        this;
        \\        () => this;
        \\        () => {
        \\            if (this) {
        \\                this;
        \\            }
        \\            else {
        \\                this.t/*4*/his;
        \\            }
        \\        }
        \\        function inside() {
        \\            this;
        \\            (function (_) {
        \\                this;
        \\            })(this);
        \\        }
        \\    }
        \\
        \\    public static staticB = this.staticMethod1;
        \\
        \\    public static staticMethod1() {
        \\        this;
        \\        this;
        \\        () => this;
        \\        () => {
        \\            if (this) {
        \\                this;
        \\            }
        \\            else {
        \\                this.th/*5*/is;
        \\            }
        \\        }
        \\        function inside() {
        \\            this;
        \\            (function (_) {
        \\                this;
        \\            })(this);
        \\        }
        \\    }
        \\
        \\    private static staticMethod2() {
        \\        this;
        \\        this;
        \\        () => this;
        \\        () => {
        \\            if (this) {
        \\                this;
        \\            }
        \\            else {
        \\                this.th/*6*/is;
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
        \\
        \\var x = {
        \\    f() {
        \\        this;
        \\    },
        \\    g() {
        \\        this;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Markers()));
}

test "TestTypeOfAFundule" {
    const content =
        \\function m1() { return 1; }
        \\namespace m1 { export var y = 2; }
        \\function foo13() {
        \\    return m1;
        \\}
        \\var /**/r13 = foo13();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "var r13: typeof m1", "");
}

test "TestQuickInfoOnElementAccessInWriteLocation5" {
    const content =
        \\// @strict: true
        \\interface Serializer {
        \\  set value(v: string | number);
        \\  get value(): string;
        \\}
        \\declare let box: Serializer;
        \\box['value'/*1*/] += 10;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(property) Serializer.value: string | number", "");
}

test "TestJavascriptModules21" {
    const content =
        \\// @allowJs: true
        \\// @module: system
        \\// @Filename: mod.js
        \\function foo() { return {a: true}; }
        \\module.exports = foo();
        \\// @Filename: app.js
        \\import mod from "./mod"
        \\mod./**/
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
//                     .Label = "a",
//                     .Kind =  undefined(lsproto.CompletionItemKindField),
//                 },
//                 &.{
//                     .Label =    "mod",
//                     .Kind =     undefined(lsproto.CompletionItemKindText),
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//             },
//         },
//     });
}

test "TestDocumentHighlightAtInheritedProperties5" {
    const content =
        \\// @Filename: file1.ts
        \\interface C extends D {
        \\    [|prop0|]: string;
        \\    [|prop1|]: number;
        \\}
        \\
        \\interface D extends C {
        \\    [|prop0|]: string;
        \\    [|prop1|]: number;
        \\}
        \\
        \\var d: D;
        \\d.[|prop1|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestGoToDefinitionReturn5" {
    const content =
        \\function foo() {
        \\    class Foo {
        \\        static { [|/*start*/return|]; }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "start");
}

test "TestParameterWithNestedDestructuring" {
    const content =
        \\[[{ a: 'hello', b: [1] }]]
        \\  .map(([{ a, b: [c] }]) => /*1*/a + /*2*/c);
        \\function f([[/*3*/a]]: [[string]], { b1: { /*4*/b2 } }: { b1: { b2: string; } }) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(parameter) a: string", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(parameter) c: number", "");
    // f.VerifyQuickInfoAt(undefined, "3", "(parameter) a: string", "");
    // f.VerifyQuickInfoAt(undefined, "4", "(parameter) b2: string", "");
}

test "TestFormattingJsxTexts1" {
    const content =
        \\//@Filename: file.tsx
        \\<option>
        \\    homu   ;      homu
        \\    homu;homu
        \\    homu   :    homu
        \\    homu:homu
        \\    homu    ?     homu
        \\    homu    .    homu
        \\
        \\    homu    [   homu   ]   homu
        \\
        \\    !     homu
        \\    --    Type
        \\    homu    --
        \\    homu    ++
        \\    ++     homu
        \\
        \\    homu  ,   homu
        \\
        \\    var    homu
        \\    throw    homu
        \\    new    homu
        \\    delete   homu
        \\    return       homu
        \\    typeof     homu
        \\    await     homu
        \\
        \\    abstract  homu
        \\    class     homu
        \\    declare   homu
        \\    default   homu
        \\    enum      homu
        \\    export    homu
        \\    homu    extends   homu
        \\    get       homu
        \\    homu    implements     homu
        \\    interface      homu
        \\    module    homu
        \\    namespace      homu
        \\    private   homu
        \\    public    homu
        \\    protected      homu
        \\    set       homu
        \\    static    homu
        \\    type      homu
        \\
        \\    homu    =>    homu
        \\    homu=>homu
        \\
        \\    ...       homu
        \\
        \\    homu     @     homu
        \\    homu@homu
        \\
        \\    (    homu   )    homu
        \\</option>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "<option>\n    homu   ;      homu\n    homu;homu\n    homu   :    homu\n    homu:homu\n    homu    ?     homu\n    homu    .    homu\n\n    homu    [   homu   ]   homu\n\n    !     homu\n    --    Type\n    homu    --\n    homu    ++\n    ++     homu\n\n    homu  ,   homu\n\n    var    homu\n    throw    homu\n    new    homu\n    delete   homu\n    return       homu\n    typeof     homu\n    await     homu\n\n    abstract  homu\n    class     homu\n    declare   homu\n    default   homu\n    enum      homu\n    export    homu\n    homu    extends   homu\n    get       homu\n    homu    implements     homu\n    interface      homu\n    module    homu\n    namespace      homu\n    private   homu\n    public    homu\n    protected      homu\n    set       homu\n    static    homu\n    type      homu\n\n    homu    =>    homu\n    homu=>homu\n\n    ...       homu\n\n    homu     @     homu\n    homu@homu\n\n    (    homu   )    homu\n</option>;");
}

test "TestReferencesBloomFilters" {
    const content =
        \\// @Filename: declaration.ts
        \\var container = { /*1*/searchProp : 1 };
        \\// @Filename: expression.ts
        \\function blah() { return (1 + 2 + container.searchProp()) === 2;  };
        \\// @Filename: stringIndexer.ts
        \\function blah2() { container["searchProp"] };
        \\// @Filename: redeclaration.ts
        \\container = { "searchProp" : 18 };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestCompletionsWithOptionalPropertiesGenericPartial" {
    const content =
        \\// @strict: true
        \\interface Foo {
        \\    a_a: boolean;
        \\    a_b: boolean;
        \\    a_c: boolean;
        \\    b_a: boolean;
        \\}
        \\function partialFoo<T extends Partial<Foo>>(t: T) {return t}
        \\partialFoo({ /*1*/ });
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
//                     .Label =      "a_a?",
//                     .InsertText = undefined("a_a"),
//                     .FilterText = undefined("a_a"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =      "a_b?",
//                     .InsertText = undefined("a_b"),
//                     .FilterText = undefined("a_b"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =      "a_c?",
//                     .InsertText = undefined("a_c"),
//                     .FilterText = undefined("a_c"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =      "b_a?",
//                     .InsertText = undefined("b_a"),
//                     .FilterText = undefined("b_a"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
}

test "TestCodeFixClassExprClassImplementClassFunctionVoidInferred" {
    const content =
        \\class A {
        \\    f() {}
        \\}
        \\let B = class implements A {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'A'",
        .NewFileContent = "class A {\n    f() {}\n}\nlet B = class implements A {\n    f(): void {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestCompletionImportModuleSpecifierEndingUnsupportedExtension" {
    const content =
        \\//@Filename:index.css
        \\ body {}
        \\//@Filename:module.ts
        \\import ".//**/"
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
//             .Excludes = &.{
//                 "index.css",
//             },
//         },
//         .UserPreferences = &.{.ImportModuleSpecifierEnding = "js"},
//     });
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Excludes = &.{
//                 "index",
//             },
//         },
//         .UserPreferences = &.{.ImportModuleSpecifierEnding = "index"},
//     });
}

test "TestGenericFunctionSignatureHelp2" {
    const content =
        \\var f = <T>(a: T) => a;
        \\f(/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifySignatureHelp(undefined, .{.Text = "f(a: unknown): unknown"});
}

test "TestUnusedLocalsInFunction1" {
    const content =
        \\// @noUnusedLocals: true
        \\ [| function greeter() {
        \\    var x = 0;
        \\} |]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "\nfunction greeter() {\n}", false, 0, 0);
}

test "TestFindAllRefsFromContextualUnionType1" {
    const content =
        \\// @strict: true
        \\function test1(arg: { prop: "foo" }) {}
        \\test1({ /*1*/prop: "bar" });
        \\
        \\function test2(arg: { prop: "foo" } | undefined) {}
        \\test2({ /*2*/prop: "bar" });
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestImportNameCodeFixExistingImport7" {
    const content =
        \\import [|{ v1 }|] from "../other_dir/module";
        \\f1/*0*/();
        \\// @Filename: ../other_dir/module.ts
        \\export var v1 = 5;
        \\export function f1();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "{ f1, v1 }",
    }, null );
}

test "TestReferencesForIndexProperty" {
    const content =
        \\class Foo {
        \\    /*1*/property: number;
        \\    /*2*/method(): void { }
        \\}
        \\
        \\var f: Foo;
        \\f["/*3*/property"];
        \\f["/*4*/method"];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestInlayHintsFunctionParameterTypes3" {
    const content =
        \\interface IFoo {
        \\    bar(x?: boolean): void;
        \\}
        \\
        \\const a: IFoo = {
        \\    bar: function (x?): void {
        \\        throw new Error("Function not implemented.");
        \\    }
        \\}
        \\class Foo {
        \\    #value = 0;
        \\    get foo(): number { return this.#value; }
        \\    set foo(value) { this.#value = value; }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayFunctionParameterTypeHints = core.TSTrue}});
}

test "TestTsxGoToDefinitionClasses" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements { }
        \\    interface ElementAttributesProperty { props; }
        \\}
        \\class /*ct*/MyClass {
        \\    props: {
        \\        /*pt*/foo: string;
        \\    }
        \\}
        \\var x = <[|My/*c*/Class|] />;
        \\var y = <MyClass [|f/*p*/oo|]= 'hello' />;
        \\var z = <[|MyCl/*w*/ass|] wrong= 'hello' />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "c", "p", "w");
}

test "TestGoToDefinitionFunctionOverloadsInClass" {
    const content =
        \\class clsInOverload {
        \\    static fnOverload();
        \\    static [|/*staticFunctionOverload*/fnOverload|](foo: string);
        \\    static /*staticFunctionOverloadDefinition*/fnOverload(foo: any) { }
        \\    public [|/*functionOverload*/fnOverload|](): any;
        \\    public fnOverload(foo: string);
        \\    public /*functionOverloadDefinition*/fnOverload(foo: any) { return "foo" }
        \\
        \\    constructor() { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "staticFunctionOverload", "functionOverload");
}

test "TestCodeFixSpellingCaseSensitive2" {
    const content =
        \\export let console = 1;
        \\export let Console = 1;
        \\[|conole|] = 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "console", false, 0, 0);
}

test "TestCompletionsInExport" {
    const content =
        \\const a = "a";
        \\type T = number;
        \\export { /**/ };
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
//                 "a",
//                 "T",
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
    _ = f.Insert(undefined, "a, ");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "T",
//                 &.{
//                     .Label =      "a?",
//                     .InsertText = undefined("a"),
//                     .FilterText = undefined("a"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
    _ = f.Insert(undefined, "T as ");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{},
//         },
//     });
    _ = f.Insert(undefined, "U, ");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "T",
//                 &.{
//                     .Label =      "a?",
//                     .InsertText = undefined("a"),
//                     .FilterText = undefined("a"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
    _ = f.Insert(undefined, "T, ");
    // f.VerifyCompletions(undefined, null, &.{
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
//                     .Label =      "T?",
//                     .InsertText = undefined("T"),
//                     .FilterText = undefined("T"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestRenameCommentsAndStrings4" {
    const content =
        \\///<reference path="./Bar.ts" />
        \\[|function [|{| "contextRangeIndex": 0 |}Bar|]() {
        \\    // This is a reference to [|Bar|] in a comment.
        \\    "this is a reference to [|Bar|] in a string";
        \\    
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1]);
}

test "TestCompletionsObjectLiteralMethod6" {
    const content =
        \\// @Filename: a.ts
        \\type T = {
        \\    foo: () => Promise<void>;
        \\}
        \\const foo: T = {
        \\    async f/**/
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
//                     .Label =    "foo",
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//             },
//         },
//     });
}

test "TestJsdocOnInheritedMembers1" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @filename: /a.js
        \\/** @template T */
        \\class A {
        \\    /** Method documentation. */
        \\    method() {}
        \\}
        \\
        \\/** @extends {A<number>} */
        \\class B extends A {
        \\    method() {}
        \\}
        \\
        \\const b = new B();
        \\b.method/**/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestJsdocTemplateTagCompletion" {
    const content =
        \\// @lib: es5
        \\/**
        \\ * @template {/**/} T
        \\ * @typedef {Object} Foo
        \\ * @property {T} foo
        \\ */
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
//             .Exact = CompletionGlobalTypes,
//         },
//     });
}

test "TestCodeFixSpellingCaseWeight1" {
    const content =
        \\let ABCDEFGHIJKLMNOPQR = 1;
        \\let abcdefghijklmnopqrs = 1;
        \\[|abcdefghijklmnopqr|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "abcdefghijklmnopqrs", false, 0, 0);
}

test "TestCompletionOfAwaitPromise4" {
    const content =
        \\function foo(x: Promise<string>) {
        \\   [|x./**/|]
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
//                 "then",
//             },
//             .Excludes = &.{
//                 "trim",
//             },
//         },
//     });
}

test "TestGoToDefinitionShorthandProperty06" {
    const content =
        \\interface Foo {
        \\    /*2*/foo(): void
        \\}
        \\const foo = 1;
        \\let x: Foo = {
        \\    [|f/*1*/oo|]()
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestGetOccurrencesExport3" {
    const content =
        \\
        \\declare var x;
        \\[|export|] declare var y, z;
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
        \\declare [|export|] var v1, v2;
        \\declare namespace dm { }
        \\[|export|] class EC { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestNavigationBarFunctionIndirectlyInVariableDeclaration" {
    const content =
        \\var a = {
        \\    propA: function() {
        \\        var c;
        \\    }
        \\};
        \\var b;
        \\b = {
        \\    propB: function() {
        \\    // function must not have an empty body to appear top level
        \\        var d;
        \\    }
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCompletionAtDottedNamespace" {
    const content =
        \\namespace wwer./**/w
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
//             .Exact = &.{},
//         },
//     });
}

test "TestFindAllRefsReExport_broken" {
    const content =
        \\// @Filename: /a.ts
        \\/*1*/export { /*2*/x };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestInlayHintsJsDocParameterNames" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /a.js
        \\var x
        \\x.foo(1, 2);
        \\/**
        \\ * @type {{foo: (a: number, b: number) => void}}
        \\ */
        \\var y
        \\y.foo(1, 2)
        \\/**
        \\ * @type {string}
        \\ */
        \\var z = ""
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.js");
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayParameterNameHints = lsutil.IncludeInlayParameterNameHintsLiterals}});
}

test "TestQuickInfoImportNonunicodePath" {
    const content =
        \\// @Filename: /江南今何在/tmp.ts
        \\export const foo = 1;
        \\// @Filename: /test.ts
        \\import { foo } from "./江南/*1*/今何在/tmp";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "module \"./江南今何在/tmp\"", "");
}

test "TestCompletionListAndMemberListOnCommentedLine" {
    const content =
        \\// /**/
        \\var
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "", null);
}

test "TestAmbientShorthandFindAllRefs" {
    const content =
        \\// @Filename: declarations.d.ts
        \\declare module "jquery";
        \\// @Filename: user.ts
        \\import {/*1*/x} from "jquery";
        \\// @Filename: user2.ts
        \\import {/*2*/x} from "jquery";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestGenericRespecialization1" {
    const content =
        \\// @strict: false
        \\class Food {
        \\    private amount: number;
        \\    constructor(public name: string) {
        \\        this.amount = 100;
        \\    }
        \\    public eat(amountToEat: number): boolean {
        \\        this.amount -= amountToEat;
        \\        if (this.amount <= 0) {
        \\            this.amount = 0;
        \\            return false;
        \\        }
        \\        else {
        \\            return true;
        \\        }
        \\    }
        \\}
        \\class IceCream extends Food {
        \\    private isDairyFree: boolean;
        \\    constructor(public flavor: string) {
        \\        super("Ice Cream");
        \\    }
        \\}
        \\class Cookie extends Food {
        \\    constructor(public flavor: string, public isGlutenFree: boolean) {
        \\        super("Cookie");
        \\    }
        \\}
        \\class Slug {
        \\    // This is NOT a food!!!
        \\}
        \\class GenericMonster<T extends Food, V> {
        \\    private name: string;
        \\    private age: number;
        \\    private isFriendly: boolean;
        \\    constructor(name: string, age: number, isFriendly: boolean, private food: T, public variant: V) {
        \\        this.name = name;
        \\        this.age = age;
        \\        this.isFriendly = isFriendly;
        \\    }
        \\    public getFood(): T {
        \\        return this.food;
        \\    }
        \\    public getVariant(): V {
        \\        return this.variant;
        \\    }
        \\    public eatFood(amountToEat: number): boolean {
        \\        return this.food.eat(amountToEat);
        \\    }
        \\    public sayGreeting(): string {
        \\        return ("My name is " + this.name + ", and my age is " + this.age + ".  I enjoy eating " + this.food.name + " and my variant is " + this.variant);
        \\    }
        \\}
        \\class GenericPlanet<T extends GenericMonster</*2*/Cookie, any>> {
        \\    constructor(public name: string, public solarSystem: string, public species: T) { }
        \\}
        \\var cookie = new Cookie("Chocolate Chip", false);
        \\var cookieMonster = new GenericMonster<Cookie, string>("Cookie Monster", 50, true, cookie, "hello");
        \\var sesameStreet = new GenericPlanet<GenericMonster<Cookie, string>>("Sesame Street", "Alpha Centuri", cookieMonster);
        \\class GenericPlanet2<T extends Food, V>{
        \\    constructor(public name: string, public solarSystem: string, public species: GenericMonster<T, V>) { }
        \\}
        \\ /*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    _ = f.GoToMarker(undefined, "1");
    _ = f.InsertLine(undefined, "");
    _ = f.InsertLine(undefined, "");
    _ = f.VerifyNoErrors(undefined);
    _ = f.GoToMarker(undefined, "2");
    _ = f.DeleteAtCaret(undefined, 6);
    _ = f.Insert(undefined, "any");
    _ = f.VerifyNoErrors(undefined);
    _ = f.InsertLine(undefined, "var narnia = new GenericPlanet2<Cookie, string>(");
}

test "TestFindAllRefsThisKeyword" {
    const content =
        \\// @noLib: true
        \\/*1*/this;
        \\function f(/*2*/this) {
        \\    return /*3*/this;
        \\    function g(/*4*/this) { return /*5*/this; }
        \\}
        \\class C {
        \\    static x() {
        \\        /*6*/this;
        \\    }
        \\    static y() {
        \\        () => /*7*/this;
        \\    }
        \\    constructor() {
        \\        /*8*/this;
        \\    }
        \\    method() {
        \\        () => /*9*/this;
        \\    }
        \\}
        \\// These are *not* real uses of the 'this' keyword, they are identifiers.
        \\const x = { /*10*/this: 0 }
        \\x./*11*/this;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11");
}

test "TestCompletionListInTemplateLiteralParts1" {
    const content =
        \\// @lib: es5
        \\/*0*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "7"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobals,
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"2", "3", "4", "5", "6", "8"}, &.{
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

test "TestGoToDefinitionImportedNames7" {
    const content =
        \\// @Filename: b.ts
        \\import [|/*classAliasDefinition*/defaultExport|] from "./a";
        \\// @Filename: a.ts
        \\class /*classDefinition*/Class {
        \\    private f;
        \\}
        \\export default Class;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "classAliasDefinition");
}

test "TestDocCommentTemplateClassDeclProperty01" {
    const content =
        \\class C {
        \\    /** /*0*/  */
        \\    foo = (p0) => {
        \\        return p0;
        \\    };
        \\    /*1*/
        \\    bar = (p1) => {
        \\        return p1;
        \\    }
        \\    /*2*/
        \\    baz = function (p2, p3) {
        \\        return p2;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyJSDocCompletion(undefined, "0", 11, "/**\n     * \n     * @param p0\n     * @returns\n     */", null);
    // f.VerifyJSDocCompletion(undefined, "1", 11, "/**\n     * \n     * @param p1\n     * @returns\n     */", null);
    // f.VerifyJSDocCompletion(undefined, "2", 11, "/**\n     * \n     * @param p2\n     * @param p3\n     * @returns\n     */", null);
}

test "TestGetOccurrencesIfElse3" {
    const content =
        \\if (true) {
        \\    if (false) {
        \\    }
        \\    else {
        \\    }
        \\    [|if|] (true) {
        \\    }
        \\    [|else|] {
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
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestCompletionsTriggerCharacter" {
    const content =
        \\// @jsx: preserve
        \\/** @/*tag*/ */
        \\//</*comment*/
        \\const x: "a" | "b" = "[|/*openQuote*/|]"/*closeQuote*/;
        \\const y: 'a' | 'b' = '[|/*openSingleQuote*/|]'/*closeSingleQuote*/;
        \\const z: 'a' | 'b' = 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "tag", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "param",
//             },
//         },
//     });
    _ = f.VerifyCompletions(undefined, "comment", null);
    // f.VerifyCompletions(undefined, "openQuote", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "a",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "a",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "b",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "b",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
    _ = f.VerifyCompletions(undefined, "closeQuote", null);
    // f.VerifyCompletions(undefined, "openSingleQuote", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "a",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "a",
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
//             },
//         },
//     });
    _ = f.VerifyCompletions(undefined, "closeSingleQuote", null);
    // f.VerifyCompletions(undefined, "openTemplate", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "a",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "a",
//                             .Range =   f.Ranges()[2].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "b",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "b",
//                             .Range =   f.Ranges()[2].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
    _ = f.VerifyCompletions(undefined, "closeTemplate", null);
    _ = f.VerifyCompletions(undefined, "quoteInComment", null);
    _ = f.VerifyCompletions(undefined, "lessInComment", null);
    // f.VerifyCompletions(undefined, "openTag", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "div",
//             },
//         },
//     });
    _ = f.VerifyCompletions(undefined, "lessThan", null);
    // f.VerifyCompletions(undefined, "closeTag", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "div>",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "path", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "importMe",
//             },
//         },
//     });
    _ = f.VerifyCompletions(undefined, "divide", null);
}

test "TestCodeFixAmbientClassImplementClassAbstractGettersAndSetters" {
    const content =
        \\abstract class A {
        \\    abstract get a(): string;
        \\    abstract set a(newName: string);
        \\
        \\    abstract get b(): number;
        \\
        \\    abstract set c(arg: number | string);
        \\}
        \\
        \\declare class C implements A {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'A'",
        .NewFileContent = "abstract class A {\n    abstract get a(): string;\n    abstract set a(newName: string);\n\n    abstract get b(): number;\n\n    abstract set c(arg: number | string);\n}\n\ndeclare class C implements A {\n    get a(): string;\n    set a(newName: string);\n    get b(): number;\n    set c(arg: string | number);\n}",
        .Index = 0,
    });
}

test "TestReferencesForInheritedProperties2" {
    const content =
        \\interface interface1 {
        \\    /*1*/doStuff(): void;
        \\}
        \\
        \\interface interface2 {
        \\    doStuff(): void;
        \\}
        \\
        \\interface interface2 extends interface1 {
        \\}
        \\
        \\class class1 implements interface2 {
        \\    doStuff() {
        \\
        \\    }
        \\}
        \\
        \\class class2 extends class1 {
        \\
        \\}
        \\
        \\var v: class2;
        \\v.doStuff();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestAugmentedTypesModule3" {
    const content =
        \\function m2g() { };
        \\namespace m2g { export class C { foo(x: number) { } } }
        \\var x: m2g./*1*/;
        \\var /*2*/r = m2g/*3*/;
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
    _ = f.Insert(undefined, "C.");
    _ = f.VerifyCompletions(undefined, null, null);
    _ = f.Backspace(undefined, 1);
    // f.VerifyQuickInfoAt(undefined, "2", "var r: typeof m2g", "");
    _ = f.GoToMarker(undefined, "3");
    _ = f.Insert(undefined, "(");
    // f.VerifySignatureHelp(undefined, .{.Text = "m2g(): void"});
}

test "TestGoToSource9_mapFromAtTypes2" {
    const content =
        \\// @lib: es5
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/lodash/package.json
        \\{ "name": "lodash", "version": "4.17.15", "main": "./lodash.js" }
        \\// @Filename: /home/src/workspaces/project/node_modules/lodash/lodash.js
        \\;(function() {
        \\    /**
        \\     * Adds two numbers.
        \\     *
        \\     * @static
        \\     * @memberOf _
        \\     * @since 3.4.0
        \\     * @category Math
        \\     * @param {number} augend The first number in an addition.
        \\     * @param {number} addend The second number in an addition.
        \\     * @returns {number} Returns the total.
        \\     * @example
        \\     *
        \\     * _.add(6, 4);
        \\     * // => 10
        \\     */
        \\    var [|/*variable*/add|] = createMathOperation(function(augend, addend) {
        \\     return augend + addend;
        \\    }, 0);
        \\
        \\    function lodash(value) {}
        \\    lodash.[|/*property*/add|] = add;
        \\
        \\    /** Detect free variable 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "defaultImport", "unresolvableNamedImport", "moduleSpecifier");
}

test "TestRenameExportSpecifier2" {
    const content =
        \\// @Filename: a.ts
        \\const name = {};
        \\export { name/**/ };
        \\// @Filename: b.ts
        \\import { name } from './a';
        \\const x = name.toString();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, &.{.UseAliasesForRename = core.TSFalse}, "");
}

test "TestCompletionsOverridingProperties1" {
    const content =
        \\// @newline: LF
        \\// @Filename: a.ts
        \\class Base {
        \\    protected foo: string = "bar";
        \\}
        \\
        \\class Sub extends Base {
        \\    /*a*/
        \\}
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
//                     .Label =      "foo",
//                     .InsertText = undefined("protected foo: string;"),
//                     .FilterText = undefined("foo"),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                 },
//             },
//         },
//     });
}

test "TestSelfReferencedExternalModule2" {
    const content =
        \\// @Filename: app.ts
        \\export import A = require('./app2');
        \\export var I = 1;
        \\A./*1*/Y;
        \\A.B.A.B./*2*/I;
        \\// @Filename: app2.ts
        \\export import B = require('./app');
        \\export var Y = 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var A.Y: number", "");
    // f.VerifyQuickInfoAt(undefined, "2", "var I: number", "");
}

test "TestFindAllRefsJsDocTemplateTag_class" {
    const content =
        \\/** @template /*1*/T */
        \\class C</*2*/T> {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestCallHierarchyFunctionAmbiguity2" {
    const content =
        \\// @filename: a.d.ts
        \\declare function /**/foo(x?: number): void;
        \\// @filename: b.d.ts
        \\declare function foo(x?: string): void;
        \\declare function foo(x?: boolean): void;
        \\// @filename: main.ts
        \\function bar() {
        \\    foo();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyBaselineCallHierarchy(undefined);
}

test "TestCompletionsIsTypeOnlyCompletion" {
    const content =
        \\// @noLib: true
        \\// @Filename: /abc.ts
        \\export type Abc = number;
        \\// @Filename: /user.ts
        \\ import { Abc } from "./abc";
        \\function f(Abc: Ab/**/) {}
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
//             .Exact = CompletionTypeKeywordsPlus(
//                 &.{
//                     "Abc",
//                 },
//             ),
//         },
//     });
}

test "TestImportTypeCompletions1" {
    const content =
        \\// @target: esnext
        \\// @filename: /foo.ts
        \\export interface Foo {}
        \\// @filename: /bar.ts
        \\[|import type F/**/|]
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
//                     .InsertText = undefined("import type { Foo } from \"./foo\";"),
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

test "TestReferencesForInheritedProperties10" {
    const content =
        \\interface IFeedbackHandler {
        \\  /*1*/handleAccept?(): void;
        \\  handleReject?(): void;
        \\}
        \\
        \\abstract class AbstractFeedbackHandler implements IFeedbackHandler {}
        \\
        \\class FeedbackHandler extends AbstractFeedbackHandler {
        \\  /*2*/handleAccept(): void {
        \\    console.log("Feedback accepted");
        \\  }
        \\
        \\  handleReject(): void {
        \\    console.log("Feedback rejected");
        \\  }
        \\}
        \\
        \\function foo(handler: IFeedbackHandler) {
        \\  handler./*3*/handleAccept?.();
        \\  handler.handleReject?.();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestFormattingTypeInfer" {
    const content =
        \\
        \\/*L1*/type C<T> = T extends Array<infer U> ? U : never;
        \\
        \\/*L2*/  type   C  <  T  >   =   T   extends   Array   <   infer     U  >  ?   U   :   never  ; 
        \\
        \\/*L3*/type C<T> = T extends Array<infer U> ? U : T;
        \\
        \\/*L4*/  type   C  <  T  >   =   T   extends   Array   <   infer     U  >  ?   U   :   T  ;  
        \\
        \\/*L5*/type Foo<T> = T extends { a: infer U, b: infer U } ? U : never;
        \\
        \\/*L6*/  type   Foo  <  T  > = T   extends   {   a  :   infer   U  ,   b  :   infer   U   }   ?   U   :   never  ;  
        \\
        \\/*L7*/type Bar<T> = T extends { a: (x: infer U) => void, b: (x: infer U) => void } ? U : never;
        \\
        \\/*L8*/  type   Bar  <  T  >   =   T   extends   {   a  :   (x  :  infer  U  ) =>   void  ,   b  :   (x  :   infer   U  )   =>   void   }    ?   U   :   never  ;
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "L1");
    _ = f.VerifyCurrentLineContent(undefined, "type C<T> = T extends Array<infer U> ? U : never;");
    _ = f.GoToMarker(undefined, "L2");
    _ = f.VerifyCurrentLineContent(undefined, "type C<T> = T extends Array<infer U> ? U : never;");
    _ = f.GoToMarker(undefined, "L3");
    _ = f.VerifyCurrentLineContent(undefined, "type C<T> = T extends Array<infer U> ? U : T;");
    _ = f.GoToMarker(undefined, "L4");
    _ = f.VerifyCurrentLineContent(undefined, "type C<T> = T extends Array<infer U> ? U : T;");
    _ = f.GoToMarker(undefined, "L5");
    _ = f.VerifyCurrentLineContent(undefined, "type Foo<T> = T extends { a: infer U, b: infer U } ? U : never;");
    _ = f.GoToMarker(undefined, "L6");
    _ = f.VerifyCurrentLineContent(undefined, "type Foo<T> = T extends { a: infer U, b: infer U } ? U : never;");
    _ = f.GoToMarker(undefined, "L7");
    _ = f.VerifyCurrentLineContent(undefined, "type Bar<T> = T extends { a: (x: infer U) => void, b: (x: infer U) => void } ? U : never;");
    _ = f.GoToMarker(undefined, "L8");
    _ = f.VerifyCurrentLineContent(undefined, "type Bar<T> = T extends { a: (x: infer U) => void, b: (x: infer U) => void } ? U : never;");
}

test "TestCodeFixClassImplementInterface_typeInOtherFile" {
    const content =
        \\// @Filename: /I.ts
        \\export interface J {}
        \\export interface I {
        \\    x: J;
        \\    m(): J;
        \\}
        \\// @Filename: /C.ts
        \\import { I } from "./I";
        \\export class C implements I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/C.ts");
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "import { I, J } from \"./I\";\nexport class C implements I {\n    x: J;\n    m(): J {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestImportNameCodeFixNewImportExportEqualsESNextInteropOff" {
    const content =
        \\// @Module: esnext
        \\// @Filename: /foo.d.ts
        \\declare module "foo" {
        \\  const foo: number;
        \\  export = foo;
        \\}
        \\// @Filename: /index.ts
        \\foo
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/index.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import foo from \"foo\";\n\nfoo",
    }, null );
}

test "TestTsxFindAllReferences2" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        div: {
        \\            /*1*/name?: string;
        \\            isOpen?: boolean;
        \\        };
        \\        span: { n: string; };
        \\    }
        \\}
        \\var x = <div name="hello" />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestCompletionsLiterals" {
    const content =
        \\const x: 0 | "one" = /**/;
        \\const y: 0 | "one" | 1n = /*1*/;
        \\const y2: 0 | "one" | 1n = 'one'/*2*/;
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
//                     .Label =  "0",
//                     .Kind =   undefined(lsproto.CompletionItemKindConstant),
//                     .Detail = undefined("0"),
//                 },
//                 &.{
//                     .Label =  "\"one\"",
//                     .Kind =   undefined(lsproto.CompletionItemKindConstant),
//                     .Detail = undefined("\"one\""),
//                 },
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
//             .Includes = &.{
//                 &.{
//                     .Label =  "0",
//                     .Kind =   undefined(lsproto.CompletionItemKindConstant),
//                     .Detail = undefined("0"),
//                 },
//                 &.{
//                     .Label =  "\"one\"",
//                     .Kind =   undefined(lsproto.CompletionItemKindConstant),
//                     .Detail = undefined("\"one\""),
//                 },
//                 &.{
//                     .Label =  "1n",
//                     .Kind =   undefined(lsproto.CompletionItemKindConstant),
//                     .Detail = undefined("1n"),
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
//             .Excludes = &.{
//                 "\"one\"",
//             },
//         },
//     });
}

test "TestFindAllRefsWithLeadingUnderscoreNames2" {
    const content =
        \\class Foo {
        \\    /*1*/public /*2*/__bar() { return 0; }
        \\}
        \\
        \\var x: Foo;
        \\x./*3*/__bar;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestOrganizeImportsType2" {
    const content =
        \\// @allowSyntheticDefaultImports: true
        \\// @moduleResolution: bundler
        \\// @noUnusedLocals: true
        \\// @target: es2018
        \\type A = string;
        \\type B = string;
        \\const C = "hello";
        \\export { A, type B, C };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(undefined,
//         "type A = string;\ntype B = string;\nconst C = \"hello\";\nexport { A, C, type B };\n",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
    // f.VerifyOrganizeImports(undefined,
//         "type A = string;\ntype B = string;\nconst C = \"hello\";\nexport { A, type B, C };\n",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderInline,
//         },
//     );
    // f.VerifyOrganizeImports(undefined,
//         "type A = string;\ntype B = string;\nconst C = \"hello\";\nexport { type B, A, C };\n",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderFirst,
//         },
//     );
    // f.VerifyOrganizeImports(undefined,
//         "type A = string;\ntype B = string;\nconst C = \"hello\";\nexport { A, C, type B };\n",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderLast,
//         },
//     );
}

test "TestGetJavaScriptQuickInfo3" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\/** @param {number[]} [a] */
        \\function /**/f(a) { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "function f(a?: number[]): void", "");
}

test "TestCompletionInJsDoc" {
    const content =
        \\// @allowJs: true
        \\// @Filename: Foo.js
        \\/** @/*1*/ */
        \\var v1;
        \\
        \\/** @p/*2*/ */
        \\var v2;
        \\
        \\/** @param /*3*/ */
        \\var v3;
        \\
        \\/** @param { n/*4*/ } bar */
        \\var v4;
        \\
        \\/** @type { n/*5*/ } */
        \\var v5;
        \\
        \\// @/*6*/
        \\var v6;
        \\
        \\// @pa/*7*/
        \\var v7;
        \\
        \\/** @return { n/*8*/ } */
        \\var v8;
        \\
        \\/** /*9*/ */
        \\
        \\/**
        \\ /*10*/
        \\*/
        \\
        \\/**
        \\ * /*11*/
        \\ */
        \\
        \\/**
        \\          /*12*/
        \\ */
        \\
        \\/**
        \\  *       /*13*/
        \\  */
        \\
        \\/**
        \\  * some comment /*14*/
        \\  */
        \\
        \\/**
        \\  * @param /*15*/
        \\  */
        \\
        \\/** @param /*16*/ */
        \\
        \\/**
        \\  * jsdoc inline tag {@/*17*/}
        \\  */
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
//                 "constructor",
//                 "param",
//                 "type",
//                 "method",
//                 "template",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"3", "15", "16"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{},
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"4", "5", "8"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "number",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
    _ = f.VerifyCompletions(undefined, &.{"6", "7", "14"}, null);
    // f.VerifyCompletions(undefined, &.{"9", "10", "11", "12", "13"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "@argument",
//                 "@returns",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"17"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "link",
//                 "tutorial",
//             },
//         },
//     });
}

test "TestFindAllRefsGlobalThisKeywordInModule" {
    const content =
        \\// @noLib: true
        \\/*1*/this;
        \\export const c = 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestStringPropertyNames2" {
    const content =
        \\export interface Album<T> {
        \\   "artist": T;
        \\}
        \\var a: Album<number>;
        \\var /**/x = a['artist']; 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "var x: number", "");
}

test "TestCompletionEntryOnNarrowedType" {
    const content =
        \\function foo(strOrNum: string | number) {
        \\    /*1*/
        \\    if (typeof strOrNum === "number") {
        \\        strOrNum/*2*/;
        \\    }
        \\    else {
        \\        strOrNum/*3*/;
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
//                 &.{
//                     .Label =  "strOrNum",
//                     .Detail = undefined("(parameter) strOrNum: string | number"),
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
//                     .Label =  "strOrNum",
//                     .Detail = undefined("(parameter) strOrNum: number"),
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
//                     .Label =  "strOrNum",
//                     .Detail = undefined("(parameter) strOrNum: string"),
//                 },
//             },
//         },
//     });
}

test "TestSignatureHelpAfterParameter" {
    const content =
        \\type Type = (a, b, c) => void
        \\const a: Type = (a/*1*/, b/*2*/) => {}
        \\const b: Type = function (a/*3*/, b/*4*/) {}
        \\const c: Type = ({ /*5*/a: { b/*6*/ }}/*7*/ = { }/*8*/, [b/*9*/]/*10*/, .../*11*/c/*12*/) => {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSignatureHelp(undefined);
}

test "TestFormattingInDestructuring2" {
    const content =
        \\/*1*/function   drawText(    { text = "", location: [x, y]=           [0, 0], bold = false }) {
        \\    // Draw text  
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "function drawText({ text = \"\", location: [x, y] = [0, 0], bold = false }) {");
}

test "TestSignatureHelpInference" {
    const content =
        \\declare function f<T extends string>(a: T, b: T, c: T): void;
        \\f("x", /**/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifySignatureHelp(undefined, .{.Text = "f(a: \"x\", b: \"x\", c: \"x\"): void", .ParameterCount = 3, .ParameterName = "b", .ParameterSpan = "b: \"x\""});
}

test "TestCodeFixMissingTypeAnnotationOnExports22_formatting" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @lib: es2019
        \\/**
        \\ * Test
        \\ */
        \\export function foo(){}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFixAvailable(undefined, &.{"Add return type 'void'"});
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add return type 'void'",
        .NewFileContent = "/**\n * Test\n */\nexport function foo(): void{}",
        .Index = 0,
    });
}

test "TestGoToDefinitionUnionTypeProperty4" {
    const content =
        \\interface SnapCrackle {
        \\    /*def1*/pop(): string;
        \\}
        \\
        \\interface Magnitude {
        \\    /*def2*/pop(): number;
        \\}
        \\
        \\interface Art {
        \\    /*def3*/pop(): boolean;
        \\}
        \\
        \\var art: Art;
        \\var magnitude: Magnitude;
        \\var snapcrackle: SnapCrackle;
        \\
        \\var x = (snapcrackle || magnitude || art).[|/*usage*/pop|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "usage");
}

test "TestImportNameCodeFixNewImportFile2" {
    const content =
        \\[|f1/*0*/();|]
        \\// @Filename: ../../other_dir/module.ts
        \\export var v1 = 5;
        \\export function f1();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from \"../../other_dir/module\";\n\nf1();",
    }, null );
}

test "TestCodeFixMissingTypeAnnotationOnExports43_expando_functions_4" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @lib: es2019
        \\// @Filename: /code.ts
        \\function foo(): void {}
        \\// cannot name this property because it's an invalid variable name.
        \\foo["@bar"] = 42;
        \\foo.x = 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Annotate types of properties expando function in a namespace",
        .NewFileContent = "function foo(): void {}\ndeclare namespace foo {\n    export var x: number;\n}\n// cannot name this property because it's an invalid variable name.\nfoo[\"@bar\"] = 42;\nfoo.x = 1;",
        .Index = 0,
    });
}

test "TestAutoImportProvider_exportMap4" {
    const content =
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
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/dependency/package.json
        \\{
        \\  "type": "module",
        \\  "name": "dependency",
        \\  "version": "1.0.0",
        \\  "exports": {
        \\    "types": "./lib/index.d.ts",
        \\    "require": "./lib/lol.js"
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/dependency/lib/index.d.ts
        \\export function fooFromIndex(): void;
        \\// @Filename: /home/src/workspaces/project/node_modules/dependency/lib/lol.d.ts
        \\export function fooFromLol(): void;
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
//             },
//             .Excludes = &.{
//                 "fooFromLol",
//             },
//         },
//     });
}

test "TestCompletionListOutsideOfClosedFunctionDeclaration01" {
    const content =
        \\// no a or b
        \\/*1*/function f (a, b) {}
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
//                 "b",
//             },
//         },
//     });
}

test "TestGoToImplementationLocal_05" {
    const content =
        \\class Bar {
        \\    public hello() {}
        \\}
        \\
        \\var [|someVar|] = new Bar();
        \\someVa/*reference*/r.hello();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "reference");
}

test "TestFindAllRefsJsDocImportTag3" {
    const content =
        \\// @checkJs: true
        \\// @Filename: /component.js
        \\export class Component {
        \\  constructor() {
        \\    this.id_ = Math.random();
        \\  }
        \\  id() {
        \\    return this.id_;
        \\  }
        \\}
        \\// @Filename: /spatial-navigation.js
        \\/** @import { Component } from './component.js' */
        \\
        \\export class SpatialNavigation {
        \\  /**
        \\   * @param {Component} component
        \\   */
        \\  add(component) {}
        \\}
        \\// @Filename: /player.js
        \\import { Component } from './component.js';
        \\
        \\/**
        \\ * @extends Component/*1*/
        \\ */
        \\export class Player extends Component {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestJavaScriptModulesWithBackticks" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\exports.x = 0;
        \\// @Filename: consumer.js
        \\var a = require(
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
//                 "x",
//             },
//         },
//     });
}

test "TestInlayHintsCrash1" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: foo.js
        \\/**
        \\ * @param {function(string): boolean} f
        \\ */
        \\function doThing(f) {
        \\    f(100)
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayVariableTypeHints = core.TSTrue, .IncludeInlayParameterNameHints = lsutil.IncludeInlayParameterNameHintsAll}});
}

test "TestRenameTemplateLiteralsDefinePropertyJs" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\let obj = {};
        \\
        \\Object.defineProperty(obj, 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "prop");
}

test "TestNavigationBarItemsFunctions" {
    const content =
        \\function foo() {
        \\    var x = 10;
        \\    function bar() {
        \\        var y = 10;
        \\        function biz() {
        \\            var z = 10;
        \\        }
        \\        function qux() {
        \\            // A function with an empty body should not be top level
        \\        }
        \\    }
        \\}
        \\
        \\function baz() {
        \\    var v = 10;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestAddMemberToModule" {
    const content =
        \\namespace A {
        \\    /*var*/
        \\}
        \\module /*check*/A {
        \\    var p;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "check");
    _ = f.VerifyQuickInfoExists(undefined);
    _ = f.GoToMarker(undefined, "var");
    _ = f.Insert(undefined, "var o;");
    _ = f.GoToMarker(undefined, "check");
    _ = f.VerifyQuickInfoExists(undefined);
}

test "TestQuickInfoInObjectLiteral" {
    const content =
        \\interface Foo {
        \\    doStuff(x: string, callback: (a: string) => string);
        \\}
        \\var x1: Foo = {
        \\    y/*1*/1: () => {
        \\        return "";
        \\    } ,
        \\    doStuff: (z, callback) => { return callback(this.y); }
        \\}
        \\var value = 3;
        \\class Foo {
        \\    static getRandomPosition() {
        \\        return {
        \\            "row": v/*2*/alue
        \\        }
        \\  }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(property) y1: () => string", "");
    // f.VerifyQuickInfoAt(undefined, "2", "var value: number", "");
}

test "TestGoToDefinitionDestructuredRequire1" {
    const content =
        \\// @allowJs: true
        \\// @Filename: util.js
        \\class /*2*/Util {}
        \\module.exports = { Util };
        \\// @Filename: index.js
        \\const { Util } = require('./util');
        \\new [|Util/*1*/|]()
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestFormattingOnDocumentReadyFunction" {
    const content =
        \\/*1*/$    (   document   )   .  ready  (   function   (   )   {
        \\/*2*/    alert    (           'i am ready'  )   ;
        \\/*3*/           }                 );
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "$(document).ready(function() {");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "    alert('i am ready');");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "});");
}

test "TestCodeFixClassImplementInterfaceTypeParamInstantiateT" {
    const content =
        \\interface I<T> { x: T; }
        \\class C<T> implements I<T> {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I<T>'",
        .NewFileContent = "interface I<T> { x: T; }\nclass C<T> implements I<T> {\n    x: T;\n}",
        .Index = 0,
    });
}

test "TestCallHierarchyClassStaticBlock2" {
    const content =
        \\class C {
        \\    /**/static {
        \\        function foo() {
        \\            bar();
        \\        }
        \\
        \\        function bar() {
        \\            baz();
        \\            quxx();
        \\            baz();
        \\        }
        \\
        \\        foo();
        \\    }
        \\}
        \\
        \\function baz() {
        \\}
        \\
        \\function quxx() {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyBaselineCallHierarchy(undefined);
}

test "TestCodeFixClassExtendAbstractSomePropertiesPresent" {
    const content =
        \\// @strict: false
        \\// @noImplicitOverride: true
        \\abstract class A {
        \\   abstract x: number;
        \\   abstract y: number;
        \\   abstract z: number;
        \\}
        \\
        \\class C extends A {[|   
        \\   |]constructor(public x: number) { super(); }
        \\   y: number;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "\noverride z: number;\n", false, 0, 0);
}

test "TestRenameInConfiguredProject" {
    const content =
        \\// @Filename: referencesForGlobals_1.ts
        \\[|var [|{| "contextRangeIndex": 0 |}globalName|] = 0;|]
        \\// @Filename: referencesForGlobals_2.ts
        \\var y = [|globalName|];
        \\// @Filename: tsconfig.json
        \\{ "files": ["referencesForGlobals_1.ts", "referencesForGlobals_2.ts"], "compilerOptions": { "lib": ["es5"] } }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyBaselineRename(undefined, null , ToAny(f.Ranges()[1:]));
}

test "TestFormattingOnEnterInStrings" {
    const content =
        \\var x = /*1*/"unclosed string literal\/*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "2");
    _ = f.InsertLine(undefined, "");
    _ = f.InsertLine(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "var x = \"unclosed string literal\\");
}

test "TestTransitiveExportImports2" {
    const content =
        \\// @Filename: a.ts
        \\[|namespace /*A*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 0 |}A|] {
        \\    export const x = 0;
        \\}|]
        \\// @Filename: b.ts
        \\[|export import /*B*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 2 |}B|] = [|A|];|]
        \\[|B|].x;
        \\// @Filename: c.ts
        \\[|import { /*C*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 6 |}B|] } from "./b";|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyBaselineFindAllReferences(undefined, "A", "B", "C");
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[4]);
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[3], f.Ranges()[5]);
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[7]);
}

test "TestImportNameCodeFixNewImportFile4" {
    const content =
        \\[|let t: A/*0*/.B.I;|]
        \\// @Filename: ./module.ts
        \\export namespace A {
        \\   export namespace B {
        \\       export interface I { }
        \\   }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { A } from \"./module\";\n\nlet t: A.B.I;",
    }, null );
}

test "TestSignatureHelpOnOverloadsDifferentArity" {
    const content =
        \\declare function f(s: string);
        \\declare function f(n: number);
        \\declare function f(s: string, b: boolean);
        \\declare function f(n: number, b: boolean);
        \\
        \\f(1/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifySignatureHelp(undefined, .{.Text = "f(n: number): any", .ParameterName = "n", .ParameterSpan = "n: number", .OverloadsCount = 4});
    _ = f.Insert(undefined, ", ");
    // f.VerifySignatureHelp(undefined, .{.Text = "f(n: number, b: boolean): any", .ParameterName = "b", .ParameterSpan = "b: boolean", .OverloadsCount = 4});
}

test "TestCompletionListInObjectLiteral2" {
    const content =
        \\interface TelemetryService {
        \\    publicLog(eventName: string, data: any): any;
        \\};
        \\class SearchResult {
        \\    count() { return 5; }
        \\    isEmpty() { return true; }
        \\    fileCount(): string { return ""; }
        \\}
        \\class Foo {
        \\    public telemetryService: TelemetryService;   // If telemetry service is of type 'any' (i.e. uncomment below line), the drop-down list works
        \\    public telemetryService2;
        \\    private test() {
        \\        var onComplete = (searchResult: SearchResult) => {
        \\            var hasResults = !searchResult.isEmpty();  // Drop-down list on searchResult fine here
        \\            // No drop-down list available on searchResult members within object literal below
        \\            this.telemetryService.publicLog('searchResultsShown', { count: searchResult./*1*/count(), fileCount: searchResult.fileCount() });
        \\            this.telemetryService2.publicLog('searchResultsShown', { count: searchResult./*2*/count(), fileCount: searchResult.fileCount() });
        \\        };
        \\    }
        \\}
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
//                 "count",
//                 "fileCount",
//                 "isEmpty",
//             },
//         },
//     });
}

test "TestFindAllRefsObjectBindingElementPropertyName05" {
    const content =
        \\interface I {
        \\    property1: number;
        \\    property2: string;
        \\}
        \\
        \\function f({ /**/property1: p }, { property1 }) {
        \\    let x = property1;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestAutoImportSortCaseSensitivity1" {
    const content =
        \\// @Filename: /exports1.ts
        \\export const a = 0;
        \\export const A = 1;
        \\export const b = 2;
        \\export const B = 3;
        \\export const c = 4;
        \\export const C = 5;
        \\// @Filename: /exports2.ts
        \\export const d = 0;
        \\export const D = 1;
        \\export const e = 2;
        \\export const E = 3;
        \\// @Filename: /index0.ts
        \\import { A, B, C } from "./exports1";
        \\a/*0*/
        \\// @Filename: /index1.ts
        \\import { A, a, B, b } from "./exports1";
        \\import { E } from "./exports2";
        \\d/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "0");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { a, A, B, C } from \"./exports1\";\na",
    }, null );
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { a, A, B, C } from \"./exports1\";\na",
    }, null );
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { A, a, B, b } from \"./exports1\";\nimport { d, E } from \"./exports2\";\nd",
    }, null );
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { A, a, B, b } from \"./exports1\";\nimport { E, d } from \"./exports2\";\nd",
    }, null );
}

test "TestFormatAsyncClassMethod1" {
    const content =
        \\class Foo {
        \\    async     foo() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "class Foo {\n    async foo() { }\n}");
}

test "TestCompletionListInTypeParameterOfTypeAlias3" {
    const content =
        \\type constructorType<T1, T2> = new <T/*1*/, /*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, f.Markers(), null);
}

test "TestAutoImport_node12_node_modules1" {
    const content =
        \\// @lib: es5
        \\// @module: node16
        \\// @Filename: /node_modules/undici/index.d.ts
        \\export function request(): any;
        \\// @Filename: /index.mts
        \\request/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"undici"}, null );
}

test "TestCompletionListInTypeLiteralInTypeParameter2" {
    const content =
        \\interface Foo {
        \\    one: string;
        \\    two: number;
        \\}
        \\
        \\interface Bar<T extends Foo> {
        \\    foo: T;
        \\}
        \\
        \\var foobar: Bar<{ on/**/
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
//                 "one",
//                 "two",
//             },
//         },
//     });
}

test "TestCompletionAsKeyword" {
    const content =
        \\const x = this /*1*/
        \\function foo() {
        \\    const x = this /*2*/
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
//                     .Label =    "as",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestGoToDefinitionUnionTypeProperty1" {
    const content =
        \\interface One {
        \\    /*propertyDefinition1*/commonProperty: number;
        \\    commonFunction(): number;
        \\}
        \\
        \\interface Two {
        \\    /*propertyDefinition2*/commonProperty: string
        \\    commonFunction(): number;
        \\}
        \\
        \\var x : One | Two;
        \\
        \\x.[|/*propertyReference*/commonProperty|];
        \\x./*3*/commonFunction;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "propertyReference");
}

test "TestUnreachableStatementNodeReuse" {
    const content =
        \\function test() {
        \\    return/*a*/abc();
        \\    return;
        \\}
        \\function abc() { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
    _ = f.GoToMarker(undefined, "a");
    _ = f.Insert(undefined, " ");
    _ = f.VerifyNoErrors(undefined);
}

test "TestJsdocDeprecated_suggestion7" {
    const content =
        \\enum Direction {
        \\    Left = -1,
        \\    Right = 1,
        \\}
        \\type T = Direction.Left
        \\/** @deprecated */
        \\const x = 1
        \\type x = string
        \\var y: x = 'hi'
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifySuggestionDiagnostics(undefined, null);
}

test "TestGetOccurrencesIsDefinitionOfFunction" {
    const content =
        \\/*1*/function /*2*/func(x: number) {
        \\}
        \\/*3*/func(x)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestFormatTrimRemainingRange" {
    const content =
        \\// @lib: es5
        \\    ;
        \\    /*
        \\    
        \\*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, ";\n/*\n \n*/");
}

test "TestCodeFixSpellingCaseSensitive1" {
    const content =
        \\export let Console = 1;
        \\export let console = 1;
        \\[|conole|] = 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "console", false, 0, 0);
}

test "TestCompletionListInUnclosedFunction02" {
    const content =
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string, c: typeof /*1*/
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
//             },
//         },
//     });
}

test "TestIncompatibleOverride" {
    const content =
        \\// @strict: false
        \\class Foo { xyz: string; }
        \\class Bar extends Foo { /*1*/xyz/*2*/: number = 1; }
        \\class Baz extends Foo { public /*3*/xyz/*4*/: number = 2; }
        \\class /*5*/Baf/*6*/ extends Foo {
        \\   constructor(public xyz: number) {
        \\      super();
        \\   }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyErrorExistsBetweenMarkers(undefined, "1", "2");
    _ = f.VerifyErrorExistsBetweenMarkers(undefined, "3", "4");
    _ = f.VerifyErrorExistsBetweenMarkers(undefined, "5", "6");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 3);
}

test "TestFormatSelectionEditAtEndOfRange" {
    const content =
        \\/*1*/var x = 1;/*2*/
        \\void 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts110);
    _ = f.FormatSelection(undefined, "1", "2");
    _ = f.VerifyCurrentFileContent(undefined, "var x = 1\nvoid 0;");
}

test "TestGoToDefinitionImportedNames9" {
    const content =
        \\// @allowjs: true
        \\// @Filename: a.js
        \\class /*classDefinition*/Class {
        \\    f;
        \\}
        \\ export { Class };
        \\// @Filename: b.js
        \\const { Class } = require("./a");
        \\ [|/*classAliasDefinition*/Class|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "classAliasDefinition");
}

test "TestFormattingElseInsideAFunction" {
    const content =
        \\var x = function() {
        \\    if (true) {
        \\    /*1*/} else {/*2*/
        \\}
        \\
        \\// newline at the end of the file
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "2");
    _ = f.InsertLine(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "    } else {");
}

test "TestCompletionsTypeOnlyNamespace" {
    const content =
        \\// @Filename: /a.ts
        \\export namespace ns {
        \\  export class Box<T> {}
        \\  export type Type = {};
        \\  export const Value = {};
        \\}
        \\// @Filename: /b.ts
        \\import type { ns } from './a';
        \\let x: ns./**/
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
//                     .Label =  "Box",
//                     .Detail = undefined("class ns.Box<T>"),
//                 },
//                 &.{
//                     .Label =  "Type",
//                     .Detail = undefined("type ns.Type = {}"),
//                 },
//             },
//         },
//     });
}

