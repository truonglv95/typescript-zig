const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionListBuilderLocations_VariableDeclarations" {
    const content =
        \\// @lib: es5
        \\var x = a/*var1*/
        \\var x = (b/*var2*/
        \\var x = (c, d/*var3*/
        \\ var y : any = "", x = a/*var4*/
        \\ var y : any = "", x = (a/*var5*/
        \\class C{}
        \\var y = new C(/*var6*/
        \\ class C{}
        \\ var y = new C(0, /*var7*/
        \\var y = [/*var8*/
        \\var y = [0, /*var9*/
        \\var y = 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"var1"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     "C",
//                     "y",
//                 }, false,
//             ),
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"var2", "var3", "var4", "var5", "var6", "var7", "var8", "var9", "var10", "var11", "var12"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     "C",
//                     "x",
//                     "y",
//                 }, false,
//             ),
//         },
//     });
}

test "TestGenericsFormatting" {
    const content =
        \\/*inClassDeclaration*/class Foo   <    T1   ,  T2    >  {
        \\/*inMethodDeclaration*/    public method    <   T3,    T4   >   ( a: T1,   b: Array    < T4 > ):   Map < T1  ,   T2, Array < T3    >    > {
        \\    }
        \\}
        \\/*typeArguments*/var foo = new Foo   <  number, Array <   number  >   >  (  );
        \\/*typeArgumentsWithTypeLiterals*/foo = new Foo  <  {   bar  :  number }, Array   < {   baz :  string   }  >  >  (  );
        \\
        \\interface IFoo {
        \\/*inNewSignature*/new < T  > ( a: T);
        \\/*inOptionalMethodSignature*/op?< T , M > (a: T, b : M );
        \\}
        \\
        \\foo()<number, string, T >();
        \\(a + b)<number, string, T >();
        \\
        \\/*inFunctionDeclaration*/function bar <T> () {
        \\/*inClassExpression*/    return class  <  T2 > {
        \\    }
        \\}
        \\/*expressionWithTypeArguments*/class A < T > extends bar <  T >( )  <  T > {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "inClassDeclaration");
    _ = f.VerifyCurrentLineContent(undefined, "class Foo<T1, T2> {");
    _ = f.GoToMarker(undefined, "inMethodDeclaration");
    _ = f.VerifyCurrentLineContent(undefined, "    public method<T3, T4>(a: T1, b: Array<T4>): Map<T1, T2, Array<T3>> {");
    _ = f.GoToMarker(undefined, "typeArguments");
    _ = f.VerifyCurrentLineContent(undefined, "var foo = new Foo<number, Array<number>>();");
    _ = f.GoToMarker(undefined, "typeArgumentsWithTypeLiterals");
    _ = f.VerifyCurrentLineContent(undefined, "foo = new Foo<{ bar: number }, Array<{ baz: string }>>();");
    _ = f.GoToMarker(undefined, "inNewSignature");
    _ = f.VerifyCurrentLineContent(undefined, "    new <T>(a: T);");
    _ = f.GoToMarker(undefined, "inOptionalMethodSignature");
    _ = f.VerifyCurrentLineContent(undefined, "    op?<T, M>(a: T, b: M);");
    _ = f.GoToMarker(undefined, "inFunctionDeclaration");
    _ = f.VerifyCurrentLineContent(undefined, "function bar<T>() {");
    _ = f.GoToMarker(undefined, "inClassExpression");
    _ = f.VerifyCurrentLineContent(undefined, "    return class <T2> {");
    _ = f.GoToMarker(undefined, "expressionWithTypeArguments");
    _ = f.VerifyCurrentLineContent(undefined, "class A<T> extends bar<T>()<T> {");
}

test "TestGenericInterfacePropertyInference2" {
    const content =
        \\// @strict: false
        \\interface I {
        \\    x: number;
        \\}
        \\
        \\var anInterface: I;
        \\interface IG<T> {
        \\    x: T;
        \\}
        \\var aGenericInterface: IG<number>;
        \\
        \\class C<T> implements IG<T> {
        \\    x: T;
        \\}
        \\
        \\interface Foo<T> {
        \\    ofFooT: Foo<T>;
        \\    ofFooFooNum: Foo<Foo<number>>; // should be error?
        \\    ofIG: IG<T>;
        \\    ofIG5: { x: Foo<T>; }; // same as ofIG3
        \\    ofC1: C<T>;
        \\}
        \\
        \\var f: Foo<any>;
        \\var f2: Foo<number>;
        \\var f3: Foo<I>;
        \\var f4: Foo<{ x: number }>;
        \\var f5: Foo<Foo<number>>;
        \\
        \\// T is any
        \\var f_/*a1*/r4 = f.ofFooT;
        \\var f_/*a2*/r7 = f.ofFooFooNum;
        \\var f_/*a3*/r9 = f.ofIG;
        \\var f_/*a5*/r13 = f.ofIG5;
        \\var f_/*a7*/r17 = f.ofC1;
        \\
        \\// T is number
        \\var f2_/*b1*/r4 = f2.ofFooT;
        \\var f2_/*b2*/r7 = f2.ofFooFooNum;
        \\var f2_/*b3*/r9 = f2.ofIG;
        \\var f2_/*b5*/r13 = f2.ofIG5;
        \\var f2_/*b7*/r17 = f2.ofC1;
        \\
        \\// T is I}
        \\var f3_/*c1*/r4 = f3.ofFooT;
        \\var f3_/*c2*/r7 = f3.ofFooFooNum;
        \\var f3_/*c3*/r9 = f3.ofIG;
        \\var f3_/*c5*/r13 = f3.ofIG5;
        \\var f3_/*c7*/r17 = f3.ofC1;
        \\
        \\// T is {x: number}
        \\var f4_/*d1*/r4 = f4.ofFooT;
        \\var f4_/*d2*/r7 = f4.ofFooFooNum;
        \\var f4_/*d3*/r9 = f4.ofIG;
        \\var f4_/*d5*/r13 = f4.ofIG5;
        \\var f4_/*d7*/r17 = f4.ofC1;
        \\
        \\// T is Foo<number>
        \\var f5_/*e1*/r4 = f5.ofFooT;
        \\var f5_/*e2*/r7 = f5.ofFooFooNum;
        \\var f5_/*e3*/r9 = f5.ofIG;
        \\var f5_/*e5*/r13 = f5.ofIG5;
        \\var f5_/*e7*/r17 = f5.ofC1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyQuickInfoAt(undefined, "a1", "var f_r4: Foo<any>", "");
    // f.VerifyQuickInfoAt(undefined, "a2", "var f_r7: Foo<Foo<number>>", "");
    // f.VerifyQuickInfoAt(undefined, "a3", "var f_r9: IG<any>", "");
    // f.VerifyQuickInfoAt(undefined, "a5", "var f_r13: {\n    x: Foo<any>;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "a7", "var f_r17: C<any>", "");
    // f.VerifyQuickInfoAt(undefined, "b1", "var f2_r4: Foo<number>", "");
    // f.VerifyQuickInfoAt(undefined, "b2", "var f2_r7: Foo<Foo<number>>", "");
    // f.VerifyQuickInfoAt(undefined, "b3", "var f2_r9: IG<number>", "");
    // f.VerifyQuickInfoAt(undefined, "b5", "var f2_r13: {\n    x: Foo<number>;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "b7", "var f2_r17: C<number>", "");
    // f.VerifyQuickInfoAt(undefined, "c1", "var f3_r4: Foo<I>", "");
    // f.VerifyQuickInfoAt(undefined, "c2", "var f3_r7: Foo<Foo<number>>", "");
    // f.VerifyQuickInfoAt(undefined, "c3", "var f3_r9: IG<I>", "");
    // f.VerifyQuickInfoAt(undefined, "c5", "var f3_r13: {\n    x: Foo<I>;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "c7", "var f3_r17: C<I>", "");
    // f.VerifyQuickInfoAt(undefined, "d1", "var f4_r4: Foo<{\n    x: number;\n}>", "");
    // f.VerifyQuickInfoAt(undefined, "d2", "var f4_r7: Foo<Foo<number>>", "");
    // f.VerifyQuickInfoAt(undefined, "d3", "var f4_r9: IG<{\n    x: number;\n}>", "");
    // f.VerifyQuickInfoAt(undefined, "d5", "var f4_r13: {\n    x: Foo<{\n        x: number;\n    }>;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "d7", "var f4_r17: C<{\n    x: number;\n}>", "");
    // f.VerifyQuickInfoAt(undefined, "e1", "var f5_r4: Foo<Foo<number>>", "");
    // f.VerifyQuickInfoAt(undefined, "e2", "var f5_r7: Foo<Foo<number>>", "");
    // f.VerifyQuickInfoAt(undefined, "e3", "var f5_r9: IG<Foo<number>>", "");
    // f.VerifyQuickInfoAt(undefined, "e5", "var f5_r13: {\n    x: Foo<Foo<number>>;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "e7", "var f5_r17: C<Foo<number>>", "");
}

test "TestRenameBindingElementInitializerExternal" {
    const content =
        \\// @lib: es5
        \\[|const [|{| "contextRangeIndex": 0 |}external|] = true;|]
        \\
        \\function f({
        \\    lvl1 = [|external|],
        \\    nested: { lvl2 = [|external|]},
        \\    oldName: newName = [|external|]
        \\}) {}
        \\
        \\const {
        \\    lvl1 = [|external|],
        \\    nested: { lvl2 = [|external|]},
        \\    oldName: newName = [|external|]
        \\} = obj;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "external");
}

test "TestFindAllReferencesFromLinkTagReference2" {
    const content =
        \\// @Filename: /a.ts
        \\enum E {
        \\    /** {@link /**/Foo} */
        \\    Foo
        \\}
        \\interface Foo {
        \\    foo: E.Foo;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestStringCompletionsFromGenericConditionalTypesUsingTemplateLiteralTypes" {
    const content =
        \\// @stableTypeOrdering: true
        \\// @strict: true
        \\type keyword = "foo" | "bar" | "baz"
        \\
        \\type validateString<s> = s extends keyword
        \\    ? s
        \\    : s extends 
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
//                 "bar",
//                 "baz",
//                 "foo",
//                 "foo|bar",
//                 "foo|baz",
//                 "foo|foo",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"ts2"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "foo|bar",
//                 "foo|baz",
//                 "foo|foo",
//             },
//         },
//     });
}

test "TestCompletionListOutsideOfForLoop01" {
    const content =
        \\for (let i = 0; i < 10; i++) i;/*1*/
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
//                 "i",
//             },
//         },
//     });
}

test "TestQuickInfoFromContextualUnionType3" {
    const content =
        \\// @strict: true
        \\declare const foo1: <D extends Foo1<D>>(definition: D) => D;
        \\
        \\type Foo1<D, Bar = Prop<D, "bar">> = {
        \\  bar: {
        \\    [K in keyof Bar]: Bar[K] extends boolean
        \\      ? Bar[K]
        \\      : "Error: bar should be boolean";
        \\  };
        \\};
        \\
        \\declare const foo2: <D extends Foo2<D>>(definition: D) => D;
        \\
        \\type Foo2<D, Bar = Prop<D, "bar">> = {
        \\  bar?: {
        \\    [K in keyof Bar]: Bar[K] extends boolean
        \\      ? Bar[K]
        \\      : "Error: bar should be boolean";
        \\  };
        \\};
        \\
        \\type Prop<T, K> = K extends keyof T ? T[K] : never;
        \\
        \\foo1({ bar: { /*1*/X: "test" } });
        \\
        \\foo2({ bar: { /*2*/X: "test" } });
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(property) X: \"Error: bar should be boolean\"", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(property) X: \"Error: bar should be boolean\"", "");
}

test "TestRenameUMDModuleAlias1" {
    const content =
        \\// @Filename: 0.d.ts
        \\export function doThing(): string;
        \\export function doTheOtherThing(): void;
        \\[|export as namespace [|{| "contextRangeIndex": 0 |}myLib|];|]
        \\// @Filename: 1.ts
        \\/// <reference path="0.d.ts" />
        \\[|myLib|].doThing();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "myLib");
}

test "TestImportNameCodeFixExistingImport9" {
    const content =
        \\import [|{
        \\    v1
        \\}|] from "./module";
        \\f1/*0*/();
        \\// @Filename: module.ts
        \\export function f1() {}
        \\export var v1 = 5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "{\n    f1,\n    v1\n}",
    }, null );
}

test "TestGoToImplementationInvalid" {
    const content =
        \\var x1 = 50/*0*/0;
        \\var x2 = "hel/*1*/lo";
        \\/*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "0", "1", "2");
}

test "TestImportNameCodeFixNewImportAmbient1" {
    const content =
        \\import d from "other-ambient-module";
        \\import * as ns from "yet-another-ambient-module";
        \\var x = v1/*0*/ + 5;
        \\// @Filename: ambientModule.ts
        \\declare module "ambient-module" {
        \\   export function f1();
        \\   export var v1;
        \\}
        \\// @Filename: otherAmbientModule.ts
        \\declare module "other-ambient-module" {
        \\   export default function f2();
        \\}
        \\// @Filename: yetAnotherAmbientModule.ts
        \\declare module "yet-another-ambient-module" {
        \\   export function f3();
        \\   export var v3;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { v1 } from \"ambient-module\";\nimport d from \"other-ambient-module\";\nimport * as ns from \"yet-another-ambient-module\";\nvar x = v1 + 5;",
    }, null );
}

test "TestFormatIfWithEmptyCondition" {
    const content =
        \\if () {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts123);
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "if ()\n{\n}");
}

test "TestCompletionEntryForUnionProperty" {
    const content =
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
        \\var x : One | Two;
        \\
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
//                 &.{
//                     .Label =  "commonFunction",
//                     .Detail = undefined("(method) commonFunction(): number"),
//                 },
//                 &.{
//                     .Label =  "commonProperty",
//                     .Detail = undefined("(property) commonProperty: string | number"),
//                 },
//             },
//         },
//     });
}

test "TestCompletionListInNamedClassExpressionWithShadowing" {
    const content =
        \\class myClass { /*0*/ }
        \\/*1*/
        \\var x = class myClass {
        \\   getClassName (){
        \\       m/*2*/
        \\   }
        \\   /*3*/
        \\}
        \\var y = class {
        \\   getSomeName() {
        \\       /*4*/
        \\   }
        \\   /*5*/
        \\}
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
//             .Excludes = &.{
//                 "myClass",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"1", "4"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "myClass",
//                     .Detail = undefined("class myClass"),
//                     .Kind =   undefined(lsproto.CompletionItemKindClass),
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
//                     .Label =  "myClass",
//                     .Detail = undefined("(local class) myClass"),
//                     .Kind =   undefined(lsproto.CompletionItemKindProperty),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"3", "5"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Excludes = &.{
//                 "myClass",
//             },
//         },
//     });
}

test "TestLinkedEditingJsxTag10" {
    const content =
        \\// @Filename: /jsx0.tsx
        \\const jsx = </*0*/>
        \\// @Filename: /jsx1.tsx
        \\const jsx = <//*1*/>
        \\// @Filename: /jsx2.tsx
        \\const jsx = </*2*/div>
        \\// @Filename: /jsx3.tsx
        \\const jsx = <//*3*/div>
        \\// @Filename: /jsx4.tsx
        \\const jsx = </*4*/div> <//*4a*/>;
        \\// @Filename: /jsx5.tsx
        \\const jsx = </*5*/> <//*5a*/div>;
        \\// @Filename: /jsx6.tsx
        \\const jsx = /*6*/div> <//*6a*/div>;
        \\// @Filename: /jsx7.tsx
        \\const jsx = </*7*/div> //*7a*/div>;
        \\// @Filename: /jsx8.tsx
        \\const jsx = </*8*/div <//*8a*/div>;
        \\// @Filename: /jsx9.tsx
        \\const jsx = </*9*/div> <//*9a*/div;
        \\// @Filename: /jsx10.tsx
        \\const jsx = </*10*/> <//*10a*/;
        \\// @Filename: /jsx11.tsx
        \\const jsx = </*11*/ <//*11a*/>;
        \\// @Filename: /jsx12.tsx
        \\const jsx = /*12*/> <//*12a*/>;
        \\// @Filename: /jsx13.tsx
        \\const jsx = </*13*/> //*13a*/>;
        \\// @Filename: /jsx14.tsx
        \\const jsx = </*14*/> </*14a*/div> <//*14b*/> <//*14c*/div>;
        \\// @Filename: /jsx15.tsx
        \\const jsx = </*15*/div> </*15a*/> <//*15b*/div> <//*15c*/>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineLinkedEditing(undefined);
}

test "TestFindAllRefsImportStarOfExportEquals" {
    const content =
        \\// @allowSyntheticDefaultimports: true
        \\// @Filename: /node_modules/a/index.d.ts
        \\[|declare function /*a0*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 0 |}a|](): void;|]
        \\[|declare namespace /*a1*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 2 |}a|] {
        \\    export const x: number;
        \\}|]
        \\[|export = /*a2*/[|{| "contextRangeIndex": 4 |}a|];|]
        \\// @Filename: /b.ts
        \\[|import /*b0*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 6 |}b|] from "a";|]
        \\/*b1*/[|b|]();
        \\[|b|].x;
        \\// @Filename: /c.ts
        \\[|import /*c0*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 10 |}a|] from "a";|]
        \\/*c1*/[|a|]();
        \\/*c2*/[|a|].x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyBaselineFindAllReferences(undefined, "a0", "a1", "a2", "b0", "b1", "c0", "c1", "c2");
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[3], f.Ranges()[5]);
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[7], f.Ranges()[8], f.Ranges()[9]);
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[11], f.Ranges()[12], f.Ranges()[13]);
}

test "TestFindAllRefsClassExpression2" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\exports./*0*/A = class {};
        \\// @Filename: /b.js
        \\import { /*1*/A } from "./a";
        \\/*2*/A;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2");
}

test "TestInsertSecondTryCatchBlock" {
    const content =
        \\try {} catch(e) { }
        \\/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "try {} catch(e) { }");
}

test "TestCompletionListAfterSlash" {
    const content =
        \\var a = 0;
        \\a/./**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "", null);
}

test "TestGetOccurrencesReturn" {
    const content =
        \\function f(a: number) {
        \\    if (a > 0) {
        \\        [|ret/**/urn|] (function () {
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
        \\    var unusued = [1, 2, 3, 4].map(x => { return 4 })
        \\
        \\    [|return|];
        \\    [|return|] true;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestInlayHintsNoParameterHints" {
    const content =
        \\function foo (a: number, b: number) {}
        \\foo(1, 2);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayParameterNameHints = lsutil.IncludeInlayParameterNameHintsNone}});
}

test "TestJsdocTypedefTag1" {
    const content =
        \\// @lib: es2015
        \\// @allowNonTsExtensions: true
        \\// @Filename: jsdocCompletion_typedef.js
        \\/**
        \\ * @typedef {Object} MyType
        \\ * @property {string} yes
        \\ */
        \\function foo() { }
        \\/**
        \\ * @param {MyType} my
        \\ */
        \\function a(my) {
        \\    my.yes./*1*/
        \\}
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
//                 "charAt",
//             },
//         },
//     });
}

test "TestFormattingInDestructuring3" {
    const content =
        \\/*1*/const {
        \\/*2*/    a,
        \\/*3*/    b,
        \\/*4*/} = {a: 1, b: 2};
        \\/*5*/const {a: c} = {a: 1, b: 2};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "const {");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "    a,");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "    b,");
    _ = f.GoToMarker(undefined, "4");
    _ = f.VerifyCurrentLineContent(undefined, "} = { a: 1, b: 2 };");
    _ = f.GoToMarker(undefined, "5");
    _ = f.VerifyCurrentLineContent(undefined, "const { a: c } = { a: 1, b: 2 };");
}

test "TestCompletionListInUnclosedObjectTypeLiteralInSignature02" {
    const content =
        \\interface I<TString, TNumber> {
        \\    [s: string]: TString;
        \\    [s: number]: TNumber;
        \\}
        \\
        \\declare function foo<TString, TNumber>(obj: I<TString, TNumber>): { str: TStr/*1*/
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
//                 "I",
//                 "TString",
//                 "TNumber",
//             },
//             .Excludes = &.{
//                 "foo",
//                 "obj",
//             },
//         },
//     });
}

test "TestFindReferencesBindingPatternInJsdocNoCrash2" {
    const content =
        \\// @moduleResolution: bundler
        \\// @Filename: node_modules/use-query/package.json
        \\{
        \\  "name": "use-query",
        \\  "types": "index.d.ts"
        \\}
        \\// @Filename: node_modules/use-query/index.d.ts
        \\declare function useQuery(): {
        \\  data: string[];
        \\};
        \\// @Filename: node_modules/use-query/package.json
        \\{
        \\  "name": "other",
        \\  "types": "index.d.ts"
        \\}
        \\// @Filename: node_modules/other/index.d.ts
        \\interface BottomSheetModalProps {
        \\  /**
        \\   * A scrollable node or normal view.
        \\   * @type null | (({ data: any }?) => any)
        \\   */
        \\  children: null | (({ data: any }?) => any);
        \\}
        \\// @Filename: src/index.ts
        \\import { useQuery } from "use-query";
        \\const { /*1*/data } = useQuery();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestJsSignature_41059" {
    const content =
        \\// @lib: esnext
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\a.next(/**/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifySignatureHelp(undefined, .{.Text = "Generator.next(): IteratorResult<T, TReturn>", .OverloadsCount = 2});
}

test "TestFormatAfterWhitespace" {
    const content =
        \\function foo()
        \\{
        \\    var bar;
        \\    /*1*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.InsertLine(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "function foo()\n{\n    var bar;\n\n\n}");
}

test "TestJavascriptModulesTypeImportAsValue" {
    const content =
        \\// @allowJs: true
        \\// @Filename: types.js
        \\/**
        \\ * @typedef {Object} Pet
        \\ * @prop {string} name
        \\ */
        \\module.exports = { a: 1 };
        \\// @Filename: app.js
        \\import { /**/ } from "./types"
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
//             .Excludes = &.{
//                 "Pet",
//             },
//         },
//     });
}

test "TestSignatureHelpOnDeclaration" {
    const content =
        \\function f</**/
        \\x
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyNoSignatureHelpForMarkers(undefined, "");
}

test "TestCodeFixInferFromUsageOptionalParam" {
    const content =
        \\// @strict: false
        \\// @noImplicitAny: true
        \\function f([|a? |]){
        \\    a;
        \\}
        \\f();
        \\f(1);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "a?: number", false, 0, 0);
}

test "TestFormatNoSpaceBeforeCloseBrace3" {
    const content =
        \\foo( 
        \\ 1, /* comment */    );
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "foo(\n    1, /* comment */);");
}

test "TestJsdocDeprecated_suggestion10" {
    const content =
        \\// @filename: foo.ts
        \\export namespace foo {
        \\    /** @deprecated */
        \\    export const bar = 1;
        \\    [|bar|];
        \\}
        \\foo.[|bar|];
        \\foo[[|"bar"|]];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "foo.ts");
    // f.VerifySuggestionDiagnostics(undefined, []*.{
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'bar' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[0].LSRange,
//         },
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'bar' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[1].LSRange,
//         },
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'bar' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[2].LSRange,
//         },
//     });
}

test "TestQuickInfoSignatureRestParameterFromUnion3" {
    const content =
        \\declare const fn:
        \\  | ((a: { x: number }, b: { x: number }) => number)
        \\  | ((...a: { y: number }[]) => number);
        \\
        \\/**/fn();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "const fn: (a: {\n    x: number;\n} & {\n    y: number;\n}, b: {\n    x: number;\n} & {\n    y: number;\n}, ...args: {\n    y: number;\n}[]) => number", "");
}

test "TestIncrementalResolveFunctionPropertyAssignment" {
    const content =
        \\function bar(indexer: { getLength(): number; getTypeAtIndex(index: number): string; }): string {
        \\    return indexer.getTypeAtIndex(indexer.getLength() - 1);
        \\}
        \\function foo(a: string[]) {
        \\    return bar({
        \\        getLength(): number {
        \\            return "a.length";
        \\        },
        \\        getTypeAtIndex(index: number) {
        \\            switch (index) {
        \\                case 0: return a[0];
        \\                case 1: return a[1];
        \\                case 2: return a[2];
        \\                default: return "invalid";
        \\            }
        \\        }
        \\    });
        \\}
        \\var val = foo(["myString1", "myString2"]);
        \\/*1*/val;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var val: string", "");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestCompletionsForSelfTypeParameterInConstraint1" {
    const content =
        \\type StateMachine<Config> = {
        \\  initial?: "states" extends keyof Config ? keyof Config["states"] : never;
        \\  states?: Record<string, {}>;
        \\};
        \\declare function createMachine<Config extends StateMachine</*1*/>>(
        \\  config: Config,
        \\): void;
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
//                 "Config",
//             },
//         },
//     });
}

test "TestJsdocDeprecated_suggestion12" {
    const content =
        \\// @filename: foo.ts
        \\/**
        \\ * @deprecated
        \\ */
        \\function foo() {};
        \\function bar(fn: () => void) {
        \\    fn();
        \\}
        \\bar([|foo|]);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "foo.ts");
    // f.VerifySuggestionDiagnostics(undefined, []*.{
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'foo' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[0].LSRange,
//         },
//     });
}

test "TestImportNameCodeFix_importType2" {
    const content =
        \\// @verbatimModuleSyntax: true
        \\// @module: es2015
        \\// @Filename: /exports1.ts
        \\export default interface SomeType {}
        \\export interface OtherType {}
        \\export interface OtherOtherType {}
        \\export const someValue = 0;
        \\// @Filename: /a.ts
        \\import type SomeType from "./exports1.js";
        \\someValue/*a*/
        \\// @Filename: /b.ts
        \\import { someValue } from "./exports1.js";
        \\const b: SomeType/*b*/ = someValue;
        \\// @Filename: /c.ts
        \\import type SomeType from "./exports1.js";
        \\const x: OtherType/*c*/
        \\// @Filename: /d.ts
        \\import type { OtherType } from "./exports1.js";
        \\const x: OtherOtherType/*d*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "a");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import type SomeType from \"./exports1.js\";\nimport { someValue } from \"./exports1.js\";\nsomeValue",
    }, null );
    _ = f.GoToMarker(undefined, "b");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import type SomeType from \"./exports1.js\";\nimport { someValue } from \"./exports1.js\";\nconst b: SomeType = someValue;",
    }, null );
    _ = f.GoToMarker(undefined, "c");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import type { OtherType } from \"./exports1.js\";\nimport type SomeType from \"./exports1.js\";\nconst x: OtherType",
    }, null );
    _ = f.GoToMarker(undefined, "d");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import type { OtherOtherType, OtherType } from \"./exports1.js\";\nconst x: OtherOtherType",
    }, null );
}

test "TestQuickInfoDisplayPartsClassDefaultAnonymous" {
    const content =
        \\/*1*/export /*2*/default /*3*/class /*4*/ {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestFindAllReferencesLinkTag2" {
    const content =
        \\namespace NPR/*5*/ {
        \\    export class Consider/*4*/ {
        \\        This/*3*/ = class {
        \\            show/*2*/() { }
        \\        }
        \\        m/*1*/() { }
        \\    }
        \\    /**
        \\     * @see {Consider.prototype.m}
        \\     * {@link Consider#m}
        \\     * @see {Consider#This#show}
        \\     * {@link Consider.This.show}
        \\     * @see {NPR.Consider#This#show}
        \\     * {@link NPR.Consider.This#show}
        \\     * @see {NPR.Consider#This.show} # doesn't parse trailing .
        \\     * @see {NPR.Consider.This.show}
        \\     */
        \\    export function ref() { }
        \\}
        \\/**
        \\ * {@link NPR.Consider#This#show hello hello}
        \\ * {@link NPR.Consider.This#show}
        \\ * @see {NPR.Consider#This.show} # doesn't parse trailing .
        \\ * @see {NPR.Consider.This.show}
        \\ */
        \\export function outerref() { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5");
}

test "TestTsxGoToDefinitionIntrinsics" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        /*dt*/div: {
        \\            /*pt*/name?: string;
        \\            isOpen?: boolean;
        \\        };
        \\        /*st*/span: { n: string; };
        \\    }
        \\}
        \\var x = <[|di/*ds*/v|] />;
        \\var y = <[|s/*ss*/pan|] />;
        \\var z = <div [|na/*ps*/me|]='hello' />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "ds", "ss", "ps");
}

test "TestCallHierarchyFile" {
    const content =
        \\foo();
        \\function /**/foo() {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyBaselineCallHierarchy(undefined);
}

test "TestGoToTypeDefinition3" {
    const content =
        \\type /*definition*/T = string;
        \\const x: /*reference*/T;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToTypeDefinition(undefined, "reference");
}

test "TestGetOccurrencesIsDefinitionOfEnum" {
    const content =
        \\/*1*/enum /*2*/E {
        \\    First,
        \\    Second
        \\}
        \\let first = /*3*/E.First;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestImportNameCodeFix_require_importVsRequire_moduleTarget" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @module: es2015
        \\// @Filename: a.js
        \\export const x = 0;
        \\// @Filename: index.js
        \\x
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "index.js");
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add import from \"./a\"",
        .NewFileContent = "import { x } from \"./a\";\n\nx",
        .Index = 0,
    });
    _ = f.GoToPosition(undefined, 0);
    _ = f.InsertLine(undefined, "const fs = require('fs');\n");
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add import from \"./a\"",
        .NewFileContent = "const fs = require('fs');\nconst { x } = require('./a');\n\nx",
        .Index = 0,
    });
}

test "TestQuickInfoWidenedTypes" {
    const content =
        \\// @strict: false
        \\var /*1*/a = null;                   // var a: any
        \\var /*2*/b = undefined;              // var b: any
        \\var /*3*/c = { x: 0, y: null };    // var c: { x: number, y: any }
        \\var /*4*/d = [null, undefined];      // var d: any[]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var a: any", "");
    // f.VerifyQuickInfoAt(undefined, "2", "var b: any", "");
    // f.VerifyQuickInfoAt(undefined, "3", "var c: {\n    x: number;\n    y: any;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "4", "var d: any[]", "");
}

test "TestTransitiveExportImports" {
    const content =
        \\// @module: commonjs
        \\// @Filename: a.ts
        \\[|class /*1*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 0 |}A|] {
        \\}|]
        \\[|export = [|{| "contextRangeIndex": 2 |}A|];|]
        \\// @Filename: b.ts
        \\[|export import /*2*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 4 |}b|] = require('./a');|]
        \\// @Filename: c.ts
        \\[|import /*3*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 6 |}b|] = require('./b');|]
        \\var a = new /*4*/[|b|]./**/[|b|]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyQuickInfoExists(undefined);
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[3]);
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[5], f.Ranges()[9]);
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[7], f.Ranges()[8]);
}

test "TestGetJSXOutliningSpans" {
    const content =
        \\import React, { Component } from 'react';
        \\
        \\export class Home extends Component[| {
        \\  render()[| {
        \\    return [|(
        \\    [|<div>
        \\      [|<h1>Hello, world!</h1>|]
        \\      [|<ul>
        \\        [|<li>
        \\          [|<a [|href='https://get.asp.net/'|]>
        \\            ASP.NET Core
        \\          </a>|]
        \\        </li>|]
        \\        [|<li>[|<a [|href='https://facebook.github.io/react/'|]>React</a>|] for client-side code</li>|]
        \\        [|<li>[|<a [|href='http://getbootstrap.com/'|]>Bootstrap</a>|] for layout and styling</li>|]
        \\      </ul>|]
        \\      <div
        \\        [|accesskey="test"
        \\        class="active"
        \\        dir="auto"|] />
        \\      <PageHeader [|title="Log in"
        \\        {...[|{
        \\          item: true,
        \\          xs: 9,
        \\          md: 5
        \\        }|]}|]
        \\      />
        \\      [|<>
        \\          text 
        \\      </>|]
        \\    </div>|]
        \\    )|];
        \\  }|]
        \\}|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOutliningSpans(undefined);
}

test "TestQuickInfoOfLablledForStatementIterator" {
    const content =
        \\label1: for(var /**/i = 0; i < 1; i++) { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyQuickInfoExists(undefined);
}

test "TestRenameJsDocTypeLiteral" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @filename: /a.js
        \\/**
        \\ * @param {Object} options
        \\ * @param {string} options.foo
        \\ * @param {number} options.bar
        \\ */
        \\function foo(/**/options) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.js");
    // f.VerifyBaselineRename(undefined, null , "");
}

test "TestGenericCombinators1" {
    const content =
        \\interface Collection<T> {
        \\    length: number;
        \\    add(x: T): void;
        \\    remove(x: T): boolean;
        \\}
        \\interface Combinators {
        \\    map<T, U>(c: Collection<T>, f: (x: T) => U): Collection<U>;
        \\    map<T>(c: Collection<T>, f: (x: T) => any): Collection<any>;
        \\}
        \\class A {
        \\    foo<T>() { return this; }
        \\}
        \\class B<T> {
        \\    foo(x: T): T { return null; }
        \\}
        \\var c2: Collection<number>;
        \\var c3: Collection<Collection<number>>;
        \\var c4: Collection<A>;
        \\var c5: Collection<B<any>>;
        \\var _: Combinators;
        \\var rf1 = (x: number) => { return x.toFixed() };
        \\var rf2 = (x: Collection<number>) => { return x.length };
        \\var rf3 = (x: A) => { return x.foo() };
        \\var /*9*/r1a = _.map(c2, (/*1*/x) => { return x.toFixed() });
        \\var /*10*/r1b = _.map(c2, rf1);
        \\var /*11*/r2a = _.map(c3, (/*2*/x: Collection<number>) => { return x.length });
        \\var /*12*/r2b = _.map(c3, rf2);
        \\var /*13*/r3a = _.map(c4, (/*3*/x) => { return x.foo() });
        \\var /*14*/r3b = _.map(c4, rf3);
        \\var /*15*/r4a = _.map(c5, (/*4*/x) => { return x.foo(1) });
        \\var /*17*/r5a = _.map<number, string>(c2, (/*5*/x) => { return x.toFixed() });
        \\var /*18*/r5b = _.map<number, string>(c2, rf1);
        \\var /*19*/r6a = _.map<Collection<number>, number>(/*6*/c3, (x: Collection<number>) => { return x.length });
        \\var /*20*/r6b = _.map<Collection<number>, number>(c3, rf2);
        \\var /*21*/r7a = _.map<A, A>(c4, (/*7*/x: A) => { return x.foo() });
        \\var /*22*/r7b = _.map<A, A>(c4, rf3);
        \\var /*23*/r8a = _.map</*error1*/B/*error2*/, string>(c5, (/*8*/x) => { return x.foo() });
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(parameter) x: number", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(parameter) x: Collection<number>", "");
    // f.VerifyQuickInfoAt(undefined, "3", "(parameter) x: A", "");
    // f.VerifyQuickInfoAt(undefined, "4", "(parameter) x: B<any>", "");
    // f.VerifyQuickInfoAt(undefined, "5", "(parameter) x: number", "");
    // f.VerifyQuickInfoAt(undefined, "6", "var c3: Collection<Collection<number>>", "");
    // f.VerifyQuickInfoAt(undefined, "7", "(parameter) x: A", "");
    // f.VerifyQuickInfoAt(undefined, "8", "(parameter) x: any", "");
    // f.VerifyQuickInfoAt(undefined, "9", "var r1a: Collection<string>", "");
    // f.VerifyQuickInfoAt(undefined, "10", "var r1b: Collection<string>", "");
    // f.VerifyQuickInfoAt(undefined, "11", "var r2a: Collection<number>", "");
    // f.VerifyQuickInfoAt(undefined, "12", "var r2b: Collection<number>", "");
    // f.VerifyQuickInfoAt(undefined, "13", "var r3a: Collection<A>", "");
    // f.VerifyQuickInfoAt(undefined, "14", "var r3b: Collection<A>", "");
    // f.VerifyQuickInfoAt(undefined, "15", "var r4a: Collection<any>", "");
    // f.VerifyQuickInfoAt(undefined, "17", "var r5a: Collection<string>", "");
    // f.VerifyQuickInfoAt(undefined, "18", "var r5b: Collection<string>", "");
    // f.VerifyQuickInfoAt(undefined, "19", "var r6a: Collection<number>", "");
    // f.VerifyQuickInfoAt(undefined, "20", "var r6b: Collection<number>", "");
    // f.VerifyQuickInfoAt(undefined, "21", "var r7a: Collection<A>", "");
    // f.VerifyQuickInfoAt(undefined, "22", "var r7b: Collection<A>", "");
    // f.VerifyQuickInfoAt(undefined, "23", "var r8a: Collection<string>", "");
    _ = f.VerifyErrorExistsBetweenMarkers(undefined, "error1", "error2");
}

test "TestFindAllRefsForRest" {
    const content =
        \\interface Gen {
        \\    x: number
        \\    /*1*/parent: Gen;
        \\    millenial: string;
        \\}
        \\let t: Gen;
        \\var { x, ...rest } = t;
        \\rest./*2*/parent;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestGetJavaScriptSyntacticDiagnostics17" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\function F(a: number) { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestJsxAttributeSnippetCompletionClosed" {
    const content =
        \\// @strict: false
        \\//@Filename: file.tsx
        \\interface NestedInterface {
        \\    Foo: NestedInterface;
        \\    (props: {className?: string, onClick?: () => void}): any;
        \\}
        \\
        \\declare const Foo: NestedInterface;
        \\
        \\function fn1() {
        \\    return <Foo>
        \\        <Foo /*1*/ />
        \\    </Foo>
        \\}
        \\function fn2() {
        \\    return <Foo>
        \\        <Foo.Foo /*2*/ />
        \\    </Foo>
        \\}
        \\function fn3() {
        \\    return <Foo>
        \\        <Foo.Foo cla/*3*/ />
        \\    </Foo>
        \\}
        \\function fn4() {
        \\    return <Foo>
        \\        <Foo.Foo cla/*4*/ something />
        \\    </Foo>
        \\}
        \\function fn5() {
        \\    return <Foo>
        \\        <Foo.Foo something /*5*/ />
        \\    </Foo>
        \\}
        \\function fn6() {
        \\    return <Foo>
        \\        <Foo.Foo something cla/*6*/ />
        \\    </Foo>
        \\}
        \\function fn7() {
        \\    return <Foo /*7*/ />
        \\}
        \\function fn8() {
        \\    return <Foo cla/*8*/ />
        \\}
        \\function fn9() {
        \\    return <Foo cla/*9*/ something />
        \\}
        \\function fn10() {
        \\    return <Foo something /*10*/ />
        \\}
        \\function fn11() {
        \\    return <Foo something cla/*11*/ />
        \\}
        \\function fn12() {
        \\    return <Foo something={false} cla/*12*/ />
        \\}
        \\function fn13() {
        \\    return <Foo something={false} /*13*/ foo />
        \\}
        \\function fn14() {
        \\    return <Foo something={false} cla/*14*/ foo />
        \\}
        \\function fn15() {
        \\    return <Foo onC/*15*/="" />
        \\}
        \\function fn16() {
        \\    return <Foo something={false} onC/*16*/="" foo />
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
    // f.VerifyCompletions(undefined, "12", &.{
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
    // f.VerifyCompletions(undefined, "13", &.{
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
    // f.VerifyCompletions(undefined, "14", &.{
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
    // f.VerifyCompletions(undefined, "15", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =      "onClick?",
//                     .InsertText = undefined("onClick"),
//                     .FilterText = undefined("onClick"),
//                     .Detail =     undefined("(property) onClick?: () => void"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "16", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =      "onClick?",
//                     .InsertText = undefined("onClick"),
//                     .FilterText = undefined("onClick"),
//                     .Detail =     undefined("(property) onClick?: () => void"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
}

test "TestFindReferencesAfterEdit" {
    const content =
        \\// @Filename: a.ts
        \\interface A {
        \\    /*1*/foo: string;
        \\}
        \\// @Filename: b.ts
        \\///<reference path='a.ts'/>
        \\/**/
        \\function foo(x: A) {
        \\    x./*2*/foo
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "\n");
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestImportCompletionsPackageJsonImportsLength2" {
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
        \\// @Filename: /a.ts
        \\import {} from "/*1*/";
        \\import {} from "#a//*2*/";
        \\import {} from "#a/b//*3*/";
        \\import {} from "#a/b/c//*4*/";
        \\import {} from "#a/b/c/something//*5*/";
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
//                 "#a",
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
//             .Exact = &.{
//                 "c",
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
//             .Exact = &.{
//                 "something",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"5"}, &.{
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

test "TestGoToDefinitionSameFile" {
    const content =
        \\var /*localVariableDefinition*/localVariable;
        \\function /*localFunctionDefinition*/localFunction() { }
        \\class /*localClassDefinition*/localClass { }
        \\interface /*localInterfaceDefinition*/localInterface{ }
        \\module /*localModuleDefinition*/localModule{ export var foo = 1;}
        \\
        \\
        \\/*localVariableReference*/localVariable = 1;
        \\/*localFunctionReference*/localFunction();
        \\var foo = new /*localClassReference*/localClass();
        \\class fooCls implements /*localInterfaceReference*/localInterface { }
        \\var fooVar = /*localModuleReference*/localModule.foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, false, "localVariableReference", "localFunctionReference", "localClassReference", "localInterfaceReference", "localModuleReference");
}

test "TestGetOccurrencesConst04" {
    const content =
        \\export const class C {
        \\    private static c/*1*/onst f/*2*/oo;
        \\    constructor(public con/*3*/st foo) {
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , "1", "2", "3");
}

test "TestFindAllRefsForVariableInExtendsClause01" {
    const content =
        \\/*1*/var /*2*/Base = class { };
        \\class C extends /*3*/Base { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}



