const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestQuickInfoJsDocInheritage" {
    const content =
        \\interface A {
        \\    /**
        \\     * @description A.foo1
        \\     */
        \\    foo1: number;
        \\    /**
        \\     * @description A.foo2
        \\     */
        \\    foo2: (para1: string) => number;
        \\}
        \\
        \\interface B {
        \\    /**
        \\     * @description B.foo1
        \\     */
        \\    foo1: number;
        \\    /**
        \\     * @description B.foo2
        \\     */
        \\    foo2: (para2: string) => number;
        \\}
        \\
        \\// implement multi interfaces with duplicate name
        \\// method for function signature
        \\class C implements A, B {
        \\    /*1*/foo1: number = 1;
        \\    /*2*/foo2(q: string) { return 1 }
        \\}
        \\
        \\// implement multi interfaces with duplicate name
        \\// property for function signature
        \\class D implements A, B {
        \\    /*3*/foo1: number = 1;
        \\    /*4*/foo2 = (q: string) => { return 1 }
        \\}
        \\
        \\new C()./*5*/foo1;
        \\new C()./*6*/foo2;
        \\new D()./*7*/foo1;
        \\new D()./*8*/foo2;
        \\
        \\class Base1 {
        \\    /**
        \\     * @description Base1.foo1 
        \\     */
        \\    foo1: number = 1;
        \\
        \\    /**
        \\     * 
        \\     * @param q Base1.foo2 parameter
        \\     * @returns Base1.foo2 return
        \\     */
        \\     foo2(q: string) { return 1 }
        \\}
        \\
        \\// extends class and implement interfaces with duplicate name
        \\// property override method
        \\class Drived1 extends Base1 implements A {
        \\    /*9*/foo1: number = 1;
        \\    /*10*/foo2(para1: string) { return 1 };
        \\}
        \\
        \\// extends class and implement interfaces with duplicate name
        \\// method override method
        \\class Drived2 extends Base1 implements B {
        \\    /*11*/foo1: number = 1;
        \\    /*12*/foo2 = (para1: string) => { return 1; };
        \\}
        \\
        \\class Base2 {
        \\    /**
        \\     * @description Base2.foo1 
        \\     */
        \\    foo1: number = 1;
        \\    /**
        \\     * 
        \\     * @param q Base2.foo2 parameter
        \\     * @returns Base2.foo2 return
        \\     */
        \\    foo2(q: string) { return 1 }
        \\}
        \\
        \\// extends class and implement interfaces with duplicate name
        \\// property override method
        \\class Drived3 extends Base2 implements A {
        \\    /*13*/foo1: number = 1;
        \\    /*14*/foo2(para1: string) { return 1 };
        \\}
        \\
        \\// extends class and implement interfaces with duplicate name
        \\// method override method
        \\class Drived4 extends Base2 implements B {
        \\    /*15*/foo1: number = 1;
        \\    /*16*/foo2 = (para1: string) => { return 1; };
        \\}
        \\
        \\new Drived1()./*17*/foo1;
        \\new Drived1()./*18*/foo2;
        \\new Drived2()./*19*/foo1;
        \\new Drived2()./*20*/foo2;
        \\new Drived3()./*21*/foo1;
        \\new Drived3()./*22*/foo2;
        \\new Drived4()./*23*/foo1;
        \\new Drived4()./*24*/foo2;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestAllowLateBoundSymbolsOverwriteEarlyBoundSymbols" {
    const content =
        \\export {};
        \\const prop = "abc";
        \\function foo(): void {};
        \\foo.abc = 10;
        \\foo[prop] = 10;
        \\interface T0 {
        \\    [prop]: number;
        \\    abc: number;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
}

test "TestMemberListErrorRecovery" {
    const content =
        \\class Foo { static fun() { }; }
        \\
        \\Foo./**/;
        \\/*1*/var bar;
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
//                     .Label =    "fun",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//             },
//         },
//     });
}

test "TestCompletionListInUnclosedFunction07" {
    const content =
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string = /*1*/, c: typeof x = "hello"
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
//             },
//         },
//     });
}

test "TestGoToDefinitionExpandoClass2" {
    const content =
        \\// @strict: true
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @filename: index.js
        \\const Core = {}
        \\
        \\Core.Test = class {
        \\  constructor() { }
        \\}
        \\
        \\Core.Test.prototype.foo = 10
        \\
        \\new Core.Tes/*1*/t()
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestImportNameCodeFix_withJson" {
    const content =
        \\// @Filename: /a.ts
        \\export const a = 'a';
        \\// @Filename: /b.ts
        \\import "./anything.json";
        \\
        \\a/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { a } from \"./a\";\nimport \"./anything.json\";\n\na",
    }, null );
}

test "TestOrganizeImportsType5" {
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
//         "import {\n    type A,\n    a,\n    b,\n    b as B,\n    type c,\n    c as C,\n    d,\n    type d as D\n} from './foo';\nconsole.log(A, a, B, b, c, C, d, D);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSUnknown,
//             .OrganizeImportsTypeOrder =  lsutil.OrganizeImportsTypeOrderInline,
//         },
//     );
    // f.VerifyOrganizeImports(undefined,
//         "import {\n    type A,\n    a,\n    b,\n    b as B,\n    type c,\n    c as C,\n    d,\n    type d as D\n} from './foo';\nconsole.log(A, a, B, b, c, C, d, D);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSUnknown,
//             .OrganizeImportsTypeOrder =  lsutil.OrganizeImportsTypeOrderInline,
//         },
//     );
}

test "TestGenericInterfaceWithInheritanceEdit1" {
    const content =
        \\interface ChainedObject<T> {
        \\    values(): ChainedArray<any>;
        \\    pairs(): ChainedArray<any[]>;
        \\    extend(...sources: any[]): ChainedObject<T>;
        \\
        \\    value(): T;
        \\}
        \\interface ChainedArray<T> extends ChainedObject<Array<T>> {
        \\
        \\    extend(...sources: any[]): ChainedArray<T>;
        \\}
        \\ /*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, " ");
    _ = f.VerifyNoErrors(undefined);
}

test "TestCompletionListStaticMembers" {
    const content =
        \\// @lib: es5
        \\class Foo {
        \\    static a() {}
        \\    static b() {}
        \\}
        \\Foo./**/
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
//             .Exact = CompletionFunctionMembersPlus(
//                 &.{
//                     &.{
//                         .Label =    "a",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "b",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "prototype",
//                         .SortText = undefined(string(ls.SortTextLocationPriority)),
//                     },
//                 },
//             ),
//         },
//     });
}

test "TestJsDocFunctionSignatures13" {
    const content =
        \\/**
        \\ * @template {string} K/**/ a golden opportunity
        \\ */
        \\function Multimap(iv) {
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyQuickInfoIs(undefined, "any", "");
}

test "TestReferencesForInheritedProperties3" {
    const content =
        \\interface interface1 extends interface1 {
        \\   /*1*/doStuff(): void;
        \\   /*2*/propName: string;
        \\}
        \\
        \\var v: interface1;
        \\v./*3*/propName;
        \\v./*4*/doStuff();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestCodeFixMissingTypeAnnotationOnExports28_long_types" {
    const content =
        \\// @strict: false
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\export const sessionLoader = {
        \\    async loadSession() {
        \\        if (Math.random() > 0.5) {
        \\            return {
        \\                PROP_1: {
        \\                    name: false,
        \\                },
        \\                PROPERTY_2: {
        \\                    name: 1,
        \\                },
        \\                PROPERTY_3: {
        \\                    name: 1
        \\                },
        \\                PROPERTY_4: {
        \\                    name: 315,
        \\                },
        \\            };
        \\        }
        \\
        \\        return {
        \\            PROP_1: {
        \\                name: false,
        \\            },
        \\            PROPERTY_2: {
        \\                name: undefined,
        \\            },
        \\            PROPERTY_3: {
        \\            },
        \\            PROPERTY_4: {
        \\                name: 576,
        \\            },
        \\        };
        \\    },
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFixAvailable(undefined, &.{"Add return type 'Promise<{\n    PROP_1: {\n        name: boolean;\n    };\n    PROPERTY_2: {\n        name: number;\n    };\n    PROPERTY_3: {\n        name: number;\n    };\n    PROPE...'"});
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add return type 'Promise<{\n    PROP_1: {\n        name: boolean;\n    };\n    PROPERTY_2: {\n        name: number;\n    };\n    PROPERTY_3: {\n        name: number;\n    };\n    PROPE...'",
        .NewFileContent = "export const sessionLoader = {\n    async loadSession(): Promise<{\n        PROP_1: {\n            name: boolean;\n        };\n        PROPERTY_2: {\n            name: number;\n        };\n        PROPERTY_3: {\n            name: number;\n        };\n        PROPERTY_4: {\n            name: number;\n        };\n    } | {\n        PROP_1: {\n            name: boolean;\n        };\n        PROPERTY_2: {\n            name: any;\n        };\n        PROPERTY_3: {\n            name?: undefined;\n        };\n        PROPERTY_4: {\n            name: number;\n        };\n    }> {\n        if (Math.random() > 0.5) {\n            return {\n                PROP_1: {\n                    name: false,\n                },\n                PROPERTY_2: {\n                    name: 1,\n                },\n                PROPERTY_3: {\n                    name: 1\n                },\n                PROPERTY_4: {\n                    name: 315,\n                },\n            };\n        }\n\n        return {\n            PROP_1: {\n                name: false,\n            },\n            PROPERTY_2: {\n                name: undefined,\n            },\n            PROPERTY_3: {\n            },\n            PROPERTY_4: {\n                name: 576,\n            },\n        };\n    },\n};",
        .Index = 0,
    });
}

test "TestJsDocFunctionSignatures8" {
    const content =
        \\// @allowJs: true
        \\// @Filename: Foo.js
        \\/**
        \\ * Represents a person
        \\ * a b multiline test
        \\ * @constructor
        \\ * @param {string} name The name of the person
        \\ * @param {number} age The age of the person
        \\ */
        \\function Person(name, age) {
        \\    this.name = name;
        \\    this.age = age;
        \\}
        \\var p = new Pers/**/on();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyQuickInfoIs(undefined, "constructor Person(name: string, age: number): Person", "Represents a person\na b multiline test");
}

test "TestGetOccurrencesIfElse5" {
    const content =
        \\if/*1*/ (true) {
        \\    if/*2*/ (false) {
        \\    }
        \\    else/*3*/ {
        \\    }
        \\    if/*4*/ (true) {
        \\    }
        \\    else/*5*/ {
        \\        if/*6*/ (false)
        \\            if/*7*/ (true)
        \\                var x = undefined;
        \\    }
        \\}
        \\else/*8*/            if (null) {
        \\}
        \\else/*9*/ /* whar garbl */ if/*10*/ (undefined) {
        \\}
        \\else/*11*/
        \\if/*12*/ (false) {
        \\}
        \\else/*13*/ { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Markers()));
}

test "TestGetJavaScriptCompletions12" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\/**
        \\ * @param {number} input
        \\ * @param {string} currency
        \\ * @returns {number}
        \\ */
        \\var convert = function(input, currency) {
        \\    switch(currency./*1*/) {
        \\            case "USD":
        \\            input./*2*/;
        \\            case "EUR":
        \\                return "" + rateToUsd.EUR;
        \\            case "CNY":
        \\                return {} + rateToUsd.CNY;
        \\    }
        \\}
        \\convert(1, "")./*3*/
        \\/**
        \\ * @param {number} x
        \\ */
        \\var test1 = function(x) { return x./*4*/ }, test2 = function(a) { return a./*5*/ };
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
//                     .Label = "charCodeAt",
//                     .Kind =  undefined(lsproto.CompletionItemKindMethod),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"2", "3", "4"}, &.{
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
    // f.VerifyCompletions(undefined, "5", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "test1",
//                     .Kind =     undefined(lsproto.CompletionItemKindText),
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//             },
//         },
//     });
}

test "TestFormatSelectionWithTrivia8" {
    const content =
        \\/*begin*/;
        \\    
        \\/*end*/console.log();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatSelection(undefined, "begin", "end");
    _ = f.VerifyCurrentFileContent(undefined, ";\n\nconsole.log();");
}

test "TestPartialUnionPropertyCacheInconsistentErrors" {
    const content =
        \\// @strict: true
        \\// @lib: esnext
        \\interface ComponentOptions<Props> {
        \\  setup?: (props: Props) => void;
        \\  name?: string;
        \\}
        \\
        \\interface FunctionalComponent<P> {
        \\  (props: P): void;
        \\}
        \\
        \\type ConcreteComponent<Props> =
        \\  | ComponentOptions<Props>
        \\  | FunctionalComponent<Props>;
        \\
        \\type Component<Props = {}> = ConcreteComponent<Props>;
        \\
        \\type WithInstallPlugin = { _prefix?: string };
        \\
        \\
        \\/**/
        \\export function withInstall<C extends Component, T extends WithInstallPlugin>(
        \\  component: C | C[],
        \\  target?: T,
        \\): string {
        \\  const componentWithInstall = (target ?? component) as T;
        \\  const components = Array.isArray(component) ? component : [component];
        \\
        \\  const { name } = components[0];
        \\  if (name) {
        \\    return name;
        \\  }
        \\
        \\  return "";
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "type C = Component['name']");
    _ = f.VerifyNoErrors(undefined);
}

test "TestFormatMultilineTypesWithMapped" {
    const content =
        \\type Z = 'z'
        \\type A = {
        \\  a: 'a'
        \\} | {
        \\      [index in Z]: string
        \\  }
        \\type B = {
        \\  b: 'b'
        \\} & {
        \\      [index in Z]: string
        \\  }
        \\
        \\const c = {
        \\  c: 'c'
        \\} as const satisfies {
        \\    [index in Z]: string
        \\  }
        \\
        \\const d = {
        \\  d: 'd'
        \\} as const satisfies {
        \\  [index: string]: string
        \\}
        \\
        \\const e = {
        \\  e: 'e'
        \\} satisfies {
        \\    [index in Z]: string
        \\  }
        \\
        \\const f = {
        \\  f: 'f'
        \\} satisfies {
        \\  [index: string]: string
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "type Z = 'z'\ntype A = {\n    a: 'a'\n} | {\n    [index in Z]: string\n}\ntype B = {\n    b: 'b'\n} & {\n    [index in Z]: string\n}\n\nconst c = {\n    c: 'c'\n} as const satisfies {\n    [index in Z]: string\n}\n\nconst d = {\n    d: 'd'\n} as const satisfies {\n    [index: string]: string\n}\n\nconst e = {\n    e: 'e'\n} satisfies {\n    [index in Z]: string\n}\n\nconst f = {\n    f: 'f'\n} satisfies {\n    [index: string]: string\n}");
}

test "TestCodeFixInferFromUsageRestParam2" {
    const content =
        \\// @strict: false
        \\// @noImplicitAny: true
        \\function f(a: number, [|...rest |]){
        \\    a; rest;
        \\}
        \\f(1);
        \\f(2, "s1");
        \\f(3, false, "s2");
        \\f(4, "s1", "s2", false, "s4");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "...rest: (string | boolean)[]", false, 0, 0);
}

test "TestTsxQuickInfo7" {
    const content =
        \\//@Filename: file.tsx
        \\// @jsx: preserve
        \\// @noLib: true
        \\declare function OverloadComponent<U>(attr: {b: U, a?: string, "ignore-prop": boolean}): JSX.Element;
        \\declare function OverloadComponent<T, U>(attr: {b: U, a: T}): JSX.Element;
        \\declare function OverloadComponent(): JSX.Element; // effective argument type of 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "function OverloadComponent<number>(attr: {\n    b: number;\n    a?: string;\n    \"ignore-prop\": boolean;\n}): JSX.Element (+2 overloads)", "");
    // f.VerifyQuickInfoAt(undefined, "2", "function OverloadComponent<boolean, string>(attr: {\n    b: string;\n    a: boolean;\n}): JSX.Element (+2 overloads)", "");
    // f.VerifyQuickInfoAt(undefined, "3", "function OverloadComponent<boolean, string>(attr: {\n    b: string;\n    a: boolean;\n}): JSX.Element (+2 overloads)", "");
    // f.VerifyQuickInfoAt(undefined, "4", "function OverloadComponent(): JSX.Element (+2 overloads)", "");
    // f.VerifyQuickInfoAt(undefined, "5", "function OverloadComponent(): JSX.Element (+2 overloads)", "");
    // f.VerifyQuickInfoAt(undefined, "6", "function OverloadComponent<boolean, never>(attr: {\n    b: never;\n    a: boolean;\n}): JSX.Element (+2 overloads)", "");
    // f.VerifyQuickInfoAt(undefined, "7", "function OverloadComponent<boolean, never>(attr: {\n    b: never;\n    a: boolean;\n}): JSX.Element (+2 overloads)", "");
}

test "TestGoToDefinitionNewExpressionTargetNotClass" {
    const content =
        \\class C2 {
        \\}
        \\let /*I*/I: {
        \\    /*constructSignature*/new(): C2;
        \\};
        \\new [|/*invokeExpression1*/I|]();
        \\let /*symbolDeclaration*/I2: {
        \\};
        \\new [|/*invokeExpression2*/I2|]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "invokeExpression1", "invokeExpression2");
}

test "TestFindAllRefsInheritedProperties1" {
    const content =
        \\class class1 extends class1 {
        \\   /*1*/doStuff() { }
        \\   /*2*/propName: string;
        \\}
        \\
        \\var v: class1;
        \\v./*3*/doStuff();
        \\v./*4*/propName;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestQuickInfoOnThis4" {
    const content =
        \\interface ContextualInterface {
        \\    m: number;
        \\    method(this: this, n: number);
        \\}
        \\let o: ContextualInterface = {
        \\    m: 12,
        \\    method(n) {
        \\        let x = this/*1*/.m;
        \\    }
        \\}
        \\interface ContextualInterface2 {
        \\    (this: void, n: number): void;
        \\}
        \\let contextualInterface2: ContextualInterface2 = function (th/*2*/is, n) { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "this: ContextualInterface", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(parameter) this: void", "");
}

test "TestGetJavaScriptQuickInfo1" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\/** @type {function(new:string,number)} */
        \\var /**/v;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "var v: new (arg1: number) => string", "");
}

test "TestCompletionsJsdocTag" {
    const content =
        \\/**
        \\ * @typedef {object} T
        \\ * /**/
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
//                 &.{
//                     .Label =  "@property",
//                     .Detail = undefined("@property"),
//                     .Kind =   undefined(lsproto.CompletionItemKindKeyword),
//                 },
//             },
//         },
//     });
}

test "TestGoToDefinitionSourceUnit" {
    const content =
        \\// @Filename: a.ts
        \\ //MyFile Comments
        \\ //more comments
        \\ /// <reference path="so/*unknownFile*/mePath.ts" />
        \\ /// <reference path="[|b/*knownFile*/.ts|]" />
        \\
        \\ class clsInOverload {
        \\     static fnOverload();
        \\     static fnOverload(foo: string);
        \\     static fnOverload(foo: any) { }
        \\ }
        \\
        \\// @Filename: b.ts
        \\/*fileB*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "unknownFile", "knownFile");
}

test "TestFindReferencesJSXTagName3" {
    const content =
        \\// @jsx: preserve
        \\// @Filename: /a.tsx
        \\namespace JSX {
        \\    export interface Element { }
        \\    export interface IntrinsicElements {
        \\        [|[|/*1*/div|]: any;|]
        \\    }
        \\}
        \\
        \\[|const [|/*6*/Comp|] = () =>
        \\    [|<[|/*2*/div|]>
        \\        Some content
        \\        [|<[|/*3*/div|]>More content</[|/*4*/div|]>|]
        \\    </[|/*5*/div|]>|];|]
        \\
        \\const x = [|<[|/*7*/Comp|]>
        \\    Content
        \\</[|/*8*/Comp|]>|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8");
    // f.VerifyBaselineDocumentHighlights(undefined, null , f.Ranges()[1], f.Ranges()[5], f.Ranges()[7], f.Ranges()[8], f.Ranges()[9]);
    // f.VerifyBaselineDocumentHighlights(undefined, null , f.Ranges()[3], f.Ranges()[11], f.Ranges()[12]);
}

test "TestSignatureHelpSimpleSuperCall" {
    const content =
        \\class SuperCallBase {
        \\    constructor(b: boolean) {
        \\    }
        \\}
        \\class SuperCall extends SuperCallBase {
        \\    constructor() {
        \\        super(/*superCall*/);
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "superCall");
    // f.VerifySignatureHelp(undefined, .{.Text = "SuperCallBase(b: boolean): SuperCallBase", .ParameterName = "b", .ParameterSpan = "b: boolean"});
}

test "TestImportNameCodeFixNewImportAllowSyntheticDefaultImports4" {
    const content =
        \\// @AllowSyntheticDefaultImports: false
        \\// @Module: amd
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
        "import bar = require(\"./foo\");\n\nexport var x = 0;\nbar();",
    }, null );
}

test "TestCompletionsUniqueSymbol_import" {
    const content =
        \\// @noLib: true
        \\// @Filename: /globals.d.ts
        \\declare const Symbol: () => symbol;
        \\// @Filename: /a.ts
        \\const privateSym = Symbol();
        \\export const publicSym = Symbol();
        \\export interface I {
        \\    [privateSym]: number;
        \\    [publicSym]: number;
        \\    [defaultPublicSym]: number;
        \\    n: number;
        \\}
        \\export const i: I;
        \\// @Filename: /user.ts
        \\import { i } from "./a";
        \\i[|./**/|];
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
//                 "n",
//                 &.{
//                     .Label =      "publicSym",
//                     .InsertText = undefined("[publicSym]"),
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./a",
//                         },
//                     },
//                     .SortText =            undefined(string(ls.SortTextGlobalsOrKeywords)),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "publicSym",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "publicSym",
//         .Source =      "./a",
//         .Description = "Update import from \"./a\"",
//         .NewFileContent = undefined("import { i, publicSym } from \"./a\";\ni.;"),
//     });
}

test "TestSignatureHelpEmptyList" {
    const content =
        \\function Foo(arg1: string, arg2: string) {
        \\}
        \\
        \\Foo(/*1*/);
        \\function Bar<T>(arg1: string, arg2: string) { }
        \\Bar</*2*/>();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifySignatureHelp(undefined, .{.Text = "Foo(arg1: string, arg2: string): void", .ParameterCount = 2, .ParameterName = "arg1", .ParameterSpan = "arg1: string"});
    _ = f.GoToMarker(undefined, "2");
    // f.VerifySignatureHelp(undefined, .{.Text = "Bar<T>(arg1: string, arg2: string): void"});
}

test "TestCompletionListInClosedFunction07" {
    const content =
        \\interface MyType {
        \\}
        \\
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string = "hello", c: typeof x = "hello") {
        \\        var v = (p: MyType) => /*1*/;
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
//             .Excludes = &.{
//                 "MyType",
//             },
//         },
//     });
}

test "TestFormattingOnEnter" {
    const content =
        \\class foo { }
        \\class bar {/**/ }
        \\// new line here
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.InsertLine(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "class foo { }\nclass bar {\n}\n// new line here");
}

test "TestQuickinfoVerbosity1" {
    const content =
        \\type FooType = string | number;
        \\const foo/*a*/: FooType = 1;
        \\type BarType = FooType | boolean;
        \\const bar/*b*/: BarType = 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"a" = .{0, 1}, .@"b" = .{0, 1, 2}});
}

test "TestQuickinfoVerbosityInterface2" {
    const content =
        \\{
        \\    interface Foo/*1*/ {
        \\        a: "a" | "c";
        \\    }
        \\}
        \\{
        \\    interface Bar {
        \\        b: "b" | "d";
        \\    }
        \\    interface Foo/*2*/ extends Bar {
        \\        a: "a" | "c";
        \\    }
        \\}
        \\{
        \\    type BarParam = "b" | "d";
        \\    interface Bar {
        \\        bar(b: BarParam): string;
        \\    }
        \\    type FooType = "a" | "c";
        \\    interface FooParam {
        \\        param: FooType;
        \\    }
        \\    interface Foo/*3*/ extends Bar {
        \\        a: FooType;
        \\        foo: (a: FooParam) => number;
        \\    }
        \\}
        \\{
        \\    interface Bar/*4*/<B> {
        \\        bar(b: B): string;
        \\    }
        \\    interface FooParam {
        \\        param: "a" | "c";
        \\    }
        \\    interface Foo/*5*/ extends Bar<FooParam> {
        \\        a: "a" | "c";
        \\        foo: (a: FooParam) => number;
        \\    }
        \\}
        \\{
        \\    interface Foo {
        \\        a: "a";
        \\    }
        \\    interface Foo/*6*/ {
        \\        b: "b";
        \\    }
        \\}
        \\interface Foo/*7*/ {
        \\    a: "a";
        \\}
        \\namespace Foo/*8*/ {
        \\    export const bar: string;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{0, 1}, .@"2" = .{0, 1}, .@"3" = .{0, 1, 2}, .@"4" = .{0, 1}, .@"5" = .{0, 1, 2}, .@"6" = .{0, 1}, .@"7" = .{0, 1}, .@"8" = .{0, 1}});
}

test "TestGetJavaScriptSyntacticDiagnostics23" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\function Person(age) {
        \\    if (age >= 18) {
        \\        this.canVote = true;
        \\    } else {
        \\        this.canVote = false;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNonSuggestionDiagnostics(undefined, null);
    _ = f.VerifyNonSuggestionDiagnostics(undefined, null);
}

test "TestCompletionsSelfDeclaring3" {
    const content =
        \\function f<T extends { x: number }>(p: T & (T extends { hello: string } ? { goodbye: number } : {})) {}
        \\f({ x/*x*/: 0, hello/*hello*/: "", goodbye/*goodbye*/: 0, abc/*abc*/: "" })
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
//                 "x",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "hello", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{},
//         },
//     });
    // f.VerifyCompletions(undefined, "goodbye", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "goodbye",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "abc", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{},
//         },
//     });
}

test "TestJsRequireQuickInfo" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\const /**/x = require("./b");
        \\// @Filename: b.js
        \\exports.x = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "import x", "");
}

test "TestFormattingOnChainedCallbacksAndPropertyAccesses" {
    const content =
        \\var x = 1;
        \\x
        \\/*1*/.toFixed
        \\x
        \\/*2*/.toFixed()
        \\x
        \\/*3*/.toFixed()
        \\/*4*/.length
        \\/*5*/.toString();
        \\x
        \\/*6*/.toFixed
        \\/*7*/.toString()
        \\/*8*/.length;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "    .toFixed");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "    .toFixed()");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "    .toFixed()");
    _ = f.GoToMarker(undefined, "4");
    _ = f.VerifyCurrentLineContent(undefined, "    .length");
    _ = f.GoToMarker(undefined, "5");
    _ = f.VerifyCurrentLineContent(undefined, "    .toString();");
    _ = f.GoToMarker(undefined, "6");
    _ = f.VerifyCurrentLineContent(undefined, "    .toFixed");
    _ = f.GoToMarker(undefined, "7");
    _ = f.VerifyCurrentLineContent(undefined, "    .toString()");
    _ = f.GoToMarker(undefined, "8");
    _ = f.VerifyCurrentLineContent(undefined, "    .length;");
}

test "TestJsDocAliasQuickInfo" {
    const content =
        \\// @Filename: /jsDocAliasQuickInfo.ts
        \\/**
        \\ * Comment
        \\ * @type {number}
        \\ */
        \\export /*1*/default 10;
        \\// @Filename: /test.ts
        \\export { /*2*/default as /*3*/test } from "./jsDocAliasQuickInfo";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestGenericWithSpecializedProperties3" {
    const content =
        \\interface Foo<T, U> {
        \\    x: Foo<T, U>;
        \\    y: Foo<U, U>;
        \\}
        \\var f: Foo<number, string>;
        \\var /*1*/xx = f.x;
        \\var /*2*/yy = f.y;
        \\var f2: Foo<string, number>;
        \\var /*3*/x2 = f2.x;
        \\var /*4*/y2 = f2.y;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var xx: Foo<number, string>", "");
    // f.VerifyQuickInfoAt(undefined, "2", "var yy: Foo<string, string>", "");
    // f.VerifyQuickInfoAt(undefined, "3", "var x2: Foo<string, number>", "");
    // f.VerifyQuickInfoAt(undefined, "4", "var y2: Foo<number, number>", "");
}

test "TestRenameInheritedProperties2" {
    const content =
        \\class class1 extends class1 {
        \\   [|[|{| "contextRangeIndex": 0 |}doStuff|]() { }|]
        \\}
        \\
        \\var v: class1;
        \\v.[|doStuff|]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "doStuff");
}

test "TestImportCompletionsPackageJsonImportsPattern_js_ts" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#*.js": "./src/*.ts"
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
//                 "#something.js",
//             },
//         },
//     });
}

test "TestCompletions01" {
    const content =
        \\// @lib: es5
        \\var x: string[] = [];
        \\x.forEach(function (y) { y/*1*/
        \\x.forEach(y => y/*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, ".");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "trim",
//             },
//         },
//     });
    _ = f.Insert(undefined, "});");
    _ = f.GoToMarker(undefined, "2");
    _ = f.Insert(undefined, ".");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "trim",
//             },
//         },
//     });
}

test "TestQuickInfoDisplayPartsInternalModuleAlias" {
    const content =
        \\namespace m.m1 {
        \\    export class c {
        \\    }
        \\}
        \\namespace m2 {
        \\    import /*1*/a1 = m;
        \\    new /*2*/a1.m1.c();
        \\    import /*3*/a2 = m.m1;
        \\    new /*4*/a2.c();
        \\    export import /*5*/a3 = m;
        \\    new /*6*/a3.m1.c();
        \\    export import /*7*/a4 = m.m1;
        \\    new /*8*/a4.c();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestGetOccurrencesNonStringImportAttributes" {
    const content =
        \\// @module: node18
        \\import * as react from "react" with { cache: /**/0 };
        \\react.Children;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , "");
}

test "TestFindAllReferencesDynamicImport2" {
    const content =
        \\// @Filename: foo.ts
        \\[|export function /*1*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 0 |}bar|]() { return "bar"; }|]
        \\var x = import("./foo");
        \\x.then(foo => {
        \\    foo./*2*/[|bar|]();
        \\})
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "bar");
}

test "TestRegexDetection" {
    const content =
        \\ /*1*/15 / /*2*/Math.min(61 / /*3*/42, 32 / 15) / /*4*/15;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyNotQuickInfoExists(undefined);
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyQuickInfoIs(undefined, "var Math: Math", "An intrinsic object that provides basic mathematics functionality and constants.");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyNotQuickInfoExists(undefined);
    _ = f.GoToMarker(undefined, "4");
    _ = f.VerifyNotQuickInfoExists(undefined);
}

test "TestRemoteGetReferences" {
    const content =
        \\// @Filename: remoteGetReferences_1.ts
        \\// Comment Refence Test: globalVar
        \\var globalVar: number = 2;
        \\
        \\class fooCls {
        \\    static clsSVar = 1;
        \\    //Declare
        \\    clsVar = 1;
        \\
        \\    constructor (public clsParam: number) {
        \\        //Increments
        \\        globalVar++;
        \\        this.clsVar++;
        \\        fooCls.clsSVar++;
        \\        this.clsParam++;
        \\        modTest.modVar++;
        \\    }
        \\}
        \\
        \\function foo(x: number) {
        \\    //Declare
        \\    var fnVar = 1;
        \\
        \\    //Increments
        \\    fooCls.clsSVar++;
        \\    globalVar++;
        \\    modTest.modVar++;
        \\    fnVar++;
        \\
        \\    //Return
        \\    return x++;
        \\}
        \\
        \\namespace modTest {
        \\    //Declare
        \\    export var modVar:number;
        \\
        \\    //Increments
        \\    globalVar++;
        \\    fooCls.clsSVar++;
        \\    modVar++;
        \\
        \\    class testCls {
        \\        static boo = foo;
        \\    }
        \\
        \\    function testFn(){
        \\        static boo = foo;
        \\
        \\        //Increments
        \\        globalVar++;
        \\        fooCls.clsSVar++;
        \\        modVar++;
        \\    }
        \\
        \\    namespace testMod {
        \\        var boo = foo;
        \\    }
        \\}
        \\
        \\//Type test
        \\var clsTest: fooCls;
        \\
        \\//Arguments
        \\clsTest = new fooCls(globalVar);
        \\foo(globalVar);
        \\
        \\//Increments
        \\fooCls.clsSVar++;
        \\modTest.modVar++;
        \\globalVar = globalVar + globalVar;
        \\
        \\//ETC - Other cases
        \\globalVar = 3;
        \\foo = foo + 1;
        \\err = err++;
        \\
        \\//Shadowed fn Parameter
        \\function shdw(globalVar: number) {
        \\    //Increments
        \\    globalVar++;
        \\    return globalVar;
        \\}
        \\
        \\//Remotes
        \\//Type test
        \\var remoteclsTest: /*1*/remotefooCls;
        \\
        \\//Arguments
        \\remoteclsTest = new /*2*/remotefooCls(/*3*/remoteglobalVar);
        \\remotefoo(/*4*/remoteglobalVar);
        \\
        \\//Increments
        \\/*5*/remotefooCls./*6*/remoteclsSVar++;
        \\remotemodTest.remotemodVar++;
        \\/*7*/remoteglobalVar = /*8*/remoteglobalVar + /*9*/remoteglobalVar;
        \\
        \\//ETC - Other cases
        \\/*10*/remoteglobalVar = 3;
        \\
        \\//Find References misses method param
        \\var
        \\
        \\
        \\
        \\ array = ["f", "o", "o"];
        \\
        \\array.forEach(
        \\
        \\
        \\function(str) {
        \\
        \\
        \\
        \\   return str + " ";
        \\
        \\});
        \\// @Filename: remoteGetReferences_2.ts
        \\/*11*/var /*12*/remoteglobalVar: number = 2;
        \\
        \\/*13*/class /*14*/remotefooCls {
        \\    //Declare
        \\    /*15*/remoteclsVar = 1;
        \\    /*16*/static /*17*/remoteclsSVar = 1;
        \\
        \\    constructor(public remoteclsParam: number) {
        \\        //Increments
        \\        /*18*/remoteglobalVar++;
        \\        this./*19*/remoteclsVar++;
        \\        /*20*/remotefooCls./*21*/remoteclsSVar++;
        \\        this.remoteclsParam++;
        \\        remotemodTest.remotemodVar++;
        \\    }
        \\}
        \\
        \\function remotefoo(remotex: number) {
        \\    //Declare
        \\    var remotefnVar = 1;
        \\
        \\    //Increments
        \\    /*22*/remotefooCls./*23*/remoteclsSVar++;
        \\    /*24*/remoteglobalVar++;
        \\    remotemodTest.remotemodVar++;
        \\    remotefnVar++;
        \\
        \\    //Return
        \\    return remotex++;
        \\}
        \\
        \\namespace remotemodTest {
        \\    //Declare
        \\    export var remotemodVar: number;
        \\
        \\    //Increments
        \\    /*25*/remoteglobalVar++;
        \\    /*26*/remotefooCls./*27*/remoteclsSVar++;
        \\    remotemodVar++;
        \\
        \\    class remotetestCls {
        \\        static remoteboo = remotefoo;
        \\    }
        \\
        \\    function remotetestFn(){
        \\        static remoteboo = remotefoo;
        \\
        \\        //Increments
        \\        /*28*/remoteglobalVar++;
        \\        /*29*/remotefooCls./*30*/remoteclsSVar++;
        \\        remotemodVar++;
        \\    }
        \\
        \\    namespace remotetestMod {
        \\        var remoteboo = remotefoo;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30");
}

test "TestImportNameCodeFixDefaultExport1" {
    const content =
        \\// @Filename: /foo-bar.ts
        \\export default function fooBar();
        \\// @Filename: /b.ts
        \\[|import * as fb from "./foo-bar";
        \\foo/**/Bar|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import fooBar, * as fb from \"./foo-bar\";\nfooBar",
    }, null );
}

test "TestGoToDefinitionJsDocImportTag1" {
    const content =
        \\// @allowJS: true
        \\// @checkJs: true
        \\// @Filename: /b.ts
        \\/*2*/export interface A { }
        \\// @Filename: /a.js
        \\/**
        \\ * @import { A } from      [|"./b/*1*/"|]
        \\ */
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestTsxQuickInfo6" {
    const content =
        \\//@Filename: file.tsx
        \\// @jsx: preserve
        \\// @noLib: true
        \\declare function ComponentSpecific<U>(l: {prop: U}): JSX.Element;
        \\declare function ComponentSpecific1<U>(l: {prop: U, "ignore-prop": number}): JSX.Element;
        \\function Bar<T extends {prop: number}>(arg: T) {
        \\    let a1 = <Compone/*1*/ntSpecific {...arg} ignore-prop="hi" />;  // U is number
        \\    let a2 = <ComponentSpecific1 {...arg} ignore-prop={10} />;  // U is number
        \\    let a3 = <Component/*2*/Specific {...arg} prop="hello" />;   // U is "hello"
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "function ComponentSpecific<number>(l: {\n    prop: number;\n}): JSX.Element", "");
    // f.VerifyQuickInfoAt(undefined, "2", "function ComponentSpecific<never>(l: {\n    prop: never;\n}): JSX.Element", "");
}

test "TestSignatureHelpObjectLiteral" {
    const content =
        \\var objectLiteral = { n: 5, s: "", f: (a: number, b: string) => "" };
        \\objectLiteral.f(/*objectLiteral1*/4, /*objectLiteral2*/"");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "objectLiteral1");
    // f.VerifySignatureHelp(undefined, .{.Text = "f(a: number, b: string): string", .ParameterCount = 2, .ParameterName = "a", .ParameterSpan = "a: number"});
    _ = f.GoToMarker(undefined, "objectLiteral2");
    // f.VerifySignatureHelp(undefined, .{.Text = "f(a: number, b: string): string", .ParameterName = "b", .ParameterSpan = "b: string"});
}

test "TestAutoImportCompletionExportListAugmentation2" {
    const content =
        \\// @module: node18
        \\// @Filename: /node_modules/@sapphire/pieces/index.d.ts
        \\interface Container {
        \\  stores: unknown;
        \\}
        \\
        \\declare class Piece {
        \\  get container(): Container;
        \\}
        \\
        \\declare class AliasPiece extends Piece {}
        \\
        \\export { AliasPiece, type Container };
        \\// @Filename: /node_modules/@sapphire/framework/index.d.ts
        \\import { AliasPiece } from "@sapphire/pieces";
        \\
        \\declare class Command extends AliasPiece {}
        \\
        \\declare module "@sapphire/pieces" {
        \\  interface Container {
        \\    client: unknown;
        \\  }
        \\}
        \\
        \\export { Command };
        \\// @Filename: /index.ts
        \\import "@sapphire/pieces";
        \\import { Command } from "@sapphire/framework";
        \\class PingCommand extends Command {
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
//                     .InsertText =          undefined("get container(): Container {\n}"),
//                     .FilterText =          undefined("container"),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .Data = &.{
//                         .Source = "ClassMemberSnippet/",
//                     },
//                 },
//             },
//         },
//     });
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined("1"), &.{
//         .Name =        "container",
//         .Source =      "ClassMemberSnippet/",
//         .Description = "Includes imports of types referenced by 'container'",
//         .NewFileContent = undefined("import \"@sapphire/pieces\";\nimport { Command } from \"@sapphire/framework\";\nimport { Container } from \"@sapphire/pieces\";\nclass PingCommand extends Command {\n  \n}"),
//     });
}

test "TestQuickInfoTypeOnlyNamespaceAndClass" {
    const content =
        \\// @Filename: /a.ts
        \\export namespace ns {
        \\  export class Box<T> {}
        \\}
        \\// @Filename: /b.ts
        \\import type { ns } from './a';
        \\let x: /*1*/ns./*2*/Box<string>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(alias) namespace ns\nimport ns", "");
    // f.VerifyQuickInfoAt(undefined, "2", "class ns.Box<T>", "");
}

test "TestGoToSource5_sameAsGoToDef1" {
    const content =
        \\// @lib: es5
        \\// @Filename: /home/src/workspaces/project/a.ts
        \\export const /*end*/a = 'a';
        \\// @Filename: /home/src/workspaces/project/a.d.ts
        \\export declare const a: string;
        \\// @Filename: /home/src/workspaces/project/a.js
        \\export const a = 'a';
        \\// @Filename: /home/src/workspaces/project/b.ts
        \\import { a } from './a';
        \\[|a/*start*/|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "start");
    // f.VerifyBaselineGoToDefinition(undefined, true, "start");
}

test "TestGoToTypeDefinition_arrayType" {
    const content =
        \\// @lib: es5
        \\type User = { name: string };
        \\declare const users: User[]
        \\/*reference*/users
        \\
        \\type UsersArr = Array<User>
        \\declare const users2: UsersArr
        \\/*reference2*/users2
        \\
        \\class CustomArray<T> extends Array<T> { immutableReverse() { return [...this].reverse() } }
        \\declare const users3: CustomArray<User>
        \\/*reference3*/users3
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToTypeDefinition(undefined, "reference", "reference2", "reference3");
}

test "TestQuickInfoJsDocTagsFunctionOverload01" {
    const content =
        \\// @Filename: quickInfoJsDocTagsFunctionOverload01.ts
        \\/**
        \\ * Doc foo
        \\ */
        \\declare function /*1*/foo(): void;
        \\
        \\/**
        \\ * Doc foo overloaded
        \\ * @tag Tag text
        \\ */
        \\declare function /*2*/foo(x: number): void
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCodeFixClassImplementInterfaceGlobal" {
    const content =
        \\// @Filename: /src/globals.d.ts
        \\export {}; // Make this a module
        \\declare global {
        \\    interface Disposable {
        \\        [Symbol.dispose](): void;
        \\    }
        \\}
        \\// @Filename: /src/test.ts
        \\import { Service } from './lifecycle';
        \\export class [|EditingService|] implements Service { }
        \\// @Filename: /src/lifecycle.ts
        \\export interface Disposable {
        \\    (): string;
        \\}
        \\export interface Service {
        \\    d: Disposable;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/src/test.ts");
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'Service'",
        .NewFileContent = "import { Disposable, Service } from './lifecycle';\nexport class EditingService implements Service {\n    d: Disposable;\n}",
        .Index = 0,
    });
}

test "TestQuickInfoForObjectBindingElementPropertyName02" {
    const content =
        \\interface I {
        \\    property1: number;
        \\    property2: string;
        \\}
        \\
        \\var foo: I;
        \\var { /**/property1: {} } = foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "(property) I.property1: number", "");
}

test "TestSignatureHelpNoArguments" {
    const content =
        \\function foo(n: number): string {
        \\}
        \\
        \\foo(/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifySignatureHelp(undefined, .{.Text = "foo(n: number): string", .ParameterName = "n", .ParameterSpan = "n: number"});
}

test "TestQuickInfoJsDocTags7" {
    const content =
        \\// @noEmit: true
        \\// @allowJs: true
        \\// @Filename: quickInfoJsDocTags7.js
        \\/**
        \\ * @typedef {{ [x: string]: any, y: number }} Foo
        \\ */
        \\
        \\/**
        \\ * @type {(t: T) => number}
        \\ * @template T
        \\ */
        \\const /**/foo = t => t.y;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestQuickinfoVerbosityTypeParameter" {
    const content =
        \\type Str = string | {};
        \\type FooType = Str | number;
        \\function fn<T extends FooType>(x: T) {
        \\    x/*x*/;
        \\}
        \\const y/*y*/: <T extends FooType>(x: T) => void = fn;
        \\type MixinCtor<A> = new () => A/*a*/ & { constructor: MixinCtor<A> };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"x" = .{0, 1, 2}, .@"y" = .{0, 1, 2}, .@"a" = .{0}});
}

test "TestImportNameCodeFixDefaultExport" {
    const content =
        \\// @Filename: /foo-bar.ts
        \\export default 0;
        \\// @Filename: /b.ts
        \\[|foo/**/Bar|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import fooBar from \"./foo-bar\";\n\nfooBar",
    }, null );
}

test "TestJsdocDeprecated_suggestion11" {
    const content =
        \\// @filename: /foo.ts
        \\/** @deprecated */
        \\export function foo() {}
        \\// @filename: /test.ts
        \\import { [|foo|] } from "./foo";
        \\[|foo|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/test.ts");
    // f.VerifySuggestionDiagnostics(undefined, []*.{
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'foo' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[0].LSRange,
//         },
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'foo' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[1].LSRange,
//         },
//     });
}

test "TestQuickInfoJsDocTags3" {
    const content =
        \\// @Filename: quickInfoJsDocTags3.ts
        \\interface Foo {
        \\    /**
        \\     * comment
        \\     * @author Me <me@domain.tld>
        \\     * @see x (the parameter)
        \\     * @param {number} x - x comment
        \\     * @param {number} y - y comment
        \\     * @throws {Error} comment
        \\     */
        \\    method(x: number, y: number): void;
        \\}
        \\
        \\class Bar implements Foo {
        \\    /**/method(): void {
        \\        throw new Error("Method not implemented.");
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCompletionsLiteralOverload" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.tsx
        \\interface Events {
        \\  "": any;
        \\  drag: any;
        \\  dragenter: any;
        \\}
        \\declare function addListener<K extends keyof Events>(type: K, listener: (ev: Events[K]) => any): void;
        \\
        \\declare function ListenerComponent<K extends keyof Events>(props: { type: K, onWhatever: (ev: Events[K]) => void }): JSX.Element;
        \\
        \\addListener("/*ts*/");
        \\(<ListenerComponent type="/*tsx*/" />);
        \\// @Filename: /b.js
        \\addListener("/*js*/");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"ts", "tsx", "js"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "",
//                 "drag",
//                 "dragenter",
//             },
//         },
//     });
    _ = f.Insert(undefined, "drag");
    // f.VerifyCompletions(undefined, &.{"ts", "tsx", "js"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "",
//                 "drag",
//                 "dragenter",
//             },
//         },
//     });
}

test "TestSyntacticClassificationWithErrors" {
    const content =
        \\class A {
        \\    a:
        \\}
        \\c =
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "class.declaration", .Text = "A"},
//         .{.Type = "property.declaration", .Text = "a"},
//     });
}

test "TestCallHierarchyConstNamedArrowFunction" {
    const content =
        \\function foo() {
        \\    bar();
        \\}
        \\
        \\const /**/bar = () => {
        \\    baz();
        \\}
        \\
        \\function baz() {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyBaselineCallHierarchy(undefined);
}

test "TestDocumentHighlightAtInheritedProperties4" {
    const content =
        \\// @Filename: file1.ts
        \\class class1 extends class1 {
        \\   [|doStuff|]() { }
        \\   [|propName|]: string;
        \\}
        \\
        \\var c: class1;
        \\c.[|doStuff|]();
        \\c.[|propName|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestReferencesForGlobals4" {
    const content =
        \\// @Filename: referencesForGlobals_1.ts
        \\/*1*/module /*2*/globalModule {
        \\     export f() { };
        \\}
        \\// @Filename: referencesForGlobals_2.ts
        \\var m = /*3*/globalModule;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestJsdocLink_findAllReferences1" {
    const content =
        \\interface A/**/ {}
        \\/**
        \\ * {@link A()} is ok
        \\ */
        \\declare const a: A
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestImportNameCodeFix_getCanonicalFileName" {
    const content =
        \\// @Filename: /howNow/node_modules/brownCow/index.d.ts
        \\export const foo: number;
        \\// @Filename: /howNow/a.ts
        \\foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/howNow/a.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { foo } from \"brownCow\";\n\nfoo;",
    }, null );
}

test "TestGoToTypeDefinition_typedef" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\/**
        \\ * /*def*/@typedef {object} I
        \\ * @property {number} x
        \\ */
        \\
        \\/** @type {I} */
        \\const /*ref*/i = { x: 0 };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToTypeDefinition(undefined, "ref");
}

test "TestAutoImportTypeOnlyPreferred3" {
    const content =
        \\// @module: esnext
        \\// @moduleResolution: bundler
        \\// @Filename: /a.ts
        \\export class A {}
        \\export class B {}
        \\// @Filename: /b.ts
        \\let x: A/*b*/;
        \\// @Filename: /c.ts
        \\import { A } from "./a";
        \\new A();
        \\let x: B/*c*/;
        \\// @Filename: /d.ts
        \\new A();
        \\let x: B;
        \\// @Filename: /ns.ts
        \\export * as default from "./a";
        \\// @Filename: /e.ts
        \\let x: /*e*/ns.A;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "b");
    // f.VerifyImportFixAtPosition(undefined, &.{
//         "import type { A } from \"./a\";\n\nlet x: A;",
//     }, &.{.PreferTypeOnlyAutoImports = core.TSTrue});
    _ = f.GoToMarker(undefined, "c");
    // f.VerifyImportFixAtPosition(undefined, &.{
//         "import { A, type B } from \"./a\";\nnew A();\nlet x: B;",
//     }, &.{.PreferTypeOnlyAutoImports = core.TSTrue});
    _ = f.GoToFile(undefined, "/d.ts");
    _ = f.VerifyCodeFixAll(undefined, .{
        .FixID = "fixMissingImport",
        .NewFileContent = "import { A, type B } from \"./a\";\n\nnew A();\nlet x: B;",
    });
    _ = f.GoToMarker(undefined, "e");
    // f.VerifyImportFixAtPosition(undefined, &.{
//         "import type ns from \"./ns\";\n\nlet x: ns.A;",
//     }, &.{.PreferTypeOnlyAutoImports = core.TSTrue});
}

test "TestCompletionListInObjectLiteral4" {
    const content =
        \\// @strictNullChecks: true
        \\interface Thing {
        \\    hello: number;
        \\    world: string;
        \\}
        \\
        \\declare function funcA(x : Thing): void;
        \\declare function funcB(x?: Thing): void;
        \\declare function funcC(x : Thing | null): void;
        \\declare function funcD(x : Thing | undefined): void;
        \\declare function funcE(x : Thing | null | undefined): void;
        \\declare function funcF(x?: Thing | null | undefined): void;
        \\
        \\funcA({ /*A*/ });
        \\funcB({ /*B*/ });
        \\funcC({ /*C*/ });
        \\funcD({ /*D*/ });
        \\funcE({ /*E*/ });
        \\funcF({ /*F*/ });
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
//                 "hello",
//                 "world",
//             },
//         },
//     });
}

test "TestCompletionsKeywordsExtends" {
    const content =
        \\class C/*a*/ /*b*/ { }
        \\class C e/*c*/ {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "a", null);
    // f.VerifyCompletions(undefined, &.{"b", "c"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "extends",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestQuickInfoJsDocTags4" {
    const content =
        \\// @Filename: quickInfoJsDocTags4.ts
        \\class Foo {
        \\    /**
        \\     * comment
        \\     * @author Me <me@domain.tld>
        \\     * @see x (the parameter)
        \\     * @param {number} x - x comment
        \\     * @param {number} y - y comment
        \\     * @returns The result
        \\     */
        \\    method(x: number, y: number): number {
        \\       return x + y;
        \\    }
        \\}
        \\
        \\class Bar extends Foo {
        \\    /**/method(x: number, y: number): number {
        \\        const res = super.method(x, y) + 100;
        \\        return res;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestJsdocCallbackTagRename01" {
    const content =
        \\// @lib: es5
        \\// @allowNonTsExtensions: true
        \\// @Filename: jsDocCallback.js
        \\
        \\/**
        \\ * [|@callback [|{| "contextRangeIndex": 0 |}FooCallback|]
        \\ * @param {string} eventName - Rename should work
        \\ |]*/
        \\
        \\/** @type {/*1*/[|FooCallback|]} */
        \\var t;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1]);
}

test "TestSemanticModernClassificationCallableVariables" {
    const content =
        \\class A { onEvent: () => void; }
        \\const x = new A().onEvent;
        \\const match = (s: any) => x();
        \\const other = match;
        \\match({ other });
        \\interface B = { (): string; }; var b: B
        \\var s: String;
        \\var t: { (): string; foo: string};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "class.declaration", .Text = "A"},
//         .{.Type = "method.declaration", .Text = "onEvent"},
//         .{.Type = "function.declaration.readonly", .Text = "x"},
//         .{.Type = "class", .Text = "A"},
//         .{.Type = "method", .Text = "onEvent"},
//         .{.Type = "function.declaration.readonly", .Text = "match"},
//         .{.Type = "parameter.declaration", .Text = "s"},
//         .{.Type = "function.readonly", .Text = "x"},
//         .{.Type = "function.declaration.readonly", .Text = "other"},
//         .{.Type = "function.readonly", .Text = "match"},
//         .{.Type = "function.readonly", .Text = "match"},
//         .{.Type = "method.declaration", .Text = "other"},
//         .{.Type = "interface.declaration", .Text = "B"},
//         .{.Type = "variable.declaration", .Text = "b"},
//         .{.Type = "interface", .Text = "B"},
//         .{.Type = "variable.declaration", .Text = "s"},
//         .{.Type = "interface.defaultLibrary", .Text = "String"},
//         .{.Type = "variable.declaration", .Text = "t"},
//         .{.Type = "property.declaration", .Text = "foo"},
//     });
}

test "TestQuickInfoPropertyTag" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\/**
        \\ * @typedef I
        \\ * @property {number} x Doc
        \\ *                      More doc
        \\ */
        \\
        \\/** @type {I} */
        \\const obj = { /**/x: 10 };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "(property) x: number", "Doc\nMore doc");
}

test "TestJsxTagNameCompletionUnderElementUnclosed" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface IntrinsicElements {
        \\        button: any;
        \\        div: any;
        \\    }
        \\}
        \\function fn() {
        \\    return <>
        \\        <butto/*1*/
        \\    </>;
        \\}
        \\function fn2() {
        \\    return <>
        \\        preceding junk <butto/*2*/
        \\    </>;
        \\}
        \\function fn3() {
        \\    return <>
        \\        <butto/*3*/ style=""
        \\    </>;
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
//                     .Label =  "button",
//                     .Detail = undefined("(property) JSX.IntrinsicElements.button: any"),
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
//                     .Label =  "button",
//                     .Detail = undefined("(property) JSX.IntrinsicElements.button: any"),
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
//                     .Label =  "button",
//                     .Detail = undefined("(property) JSX.IntrinsicElements.button: any"),
//                 },
//             },
//         },
//     });
}

test "TestTsxGoToDefinitionStatelessFunction2" {
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
        \\declare function /*firstSource*/MainButton(buttonProps: ButtonProps): JSX.Element;
        \\declare function /*secondSource*/MainButton(linkProps: LinkProps): JSX.Element;
        \\declare function /*thirdSource*/MainButton(props: ButtonProps | LinkProps): JSX.Element;
        \\let opt = <[|Main/*firstTarget*/Button|] />;
        \\let opt = <[|Main/*secondTarget*/Button|] children="chidlren" />;
        \\let opt = <[|Main/*thirdTarget*/Button|] onClick={()=>{}} />;
        \\let opt = <[|Main/*fourthTarget*/Button|] onClick={()=>{}} ignore-prop />;
        \\let opt = <[|Main/*fifthTarget*/Button|] goTo="goTo" />;
        \\let opt = <[|Main/*sixthTarget*/Button|] wrong />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "firstTarget", "secondTarget", "thirdTarget", "fourthTarget", "fifthTarget", "sixthTarget");
}

test "TestGoToImplementationInterface_09" {
    const content =
        \\// @Filename: def.d.ts
        \\export interface Interface { P: number }
        \\// @Filename: ref.ts
        \\import { Interface } from "./def";
        \\const c: I/*ref*/nterface = [|{ P: 2 }|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "ref");
}

test "TestFormattingReadonly" {
    const content =
        \\class C {
        \\  readonly    property1: {};/*1*/
        \\  public readonly   property2: {};/*2*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "    readonly property1: {};");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "    public readonly property2: {};");
}

test "TestImportNameCodeFix_preferBaseUrl" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{ "compilerOptions": { "baseUrl": "./src" } }
        \\// @Filename: /src/d0/d1/d2/file.ts
        \\foo/**/;
        \\// @Filename: /src/d0/a.ts
        \\export const foo = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/src/d0/d1/d2/file.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { foo } from \"d0/a\";\n\nfoo;",
    }, null );
}

test "TestTypeArgCompletion" {
    const content =
        \\class Base {
        \\}
        \\class Derived extends Base {
        \\}
        \\interface I1<T extends Base>{
        \\}
        \\var x1: I1<Deri/**/>;
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
//                 "Derived",
//             },
//         },
//     });
}

test "TestFormatArrayOrObjectLiteralsInVariableList" {
    const content =
        \\var v30 = [1, 2], v31, v32, v33 = [0], v34 = {'a': true}, v35;/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyCurrentLineContent(undefined, "var v30 = [1, 2], v31, v32, v33 = [0], v34 = { 'a': true }, v35;");
}

test "TestCodeFixInferFromCallInAssignment" {
    const content =
        \\// @noImplicitAny: true
        \\function inferAny( [| app |] ) {
        \\    const result = app.use('hi')
        \\    return result
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "app: { use: (arg0: string) => any }", false, 0, 0);
}

test "TestCompletionListBuilderLocations_Modules" {
    const content =
        \\// @lib: es5
        \\module A/*moduleName1*/
        \\module A./*moduleName2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "moduleName1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobals,
//         },
//     });
    // f.VerifyCompletions(undefined, "moduleName2", &.{
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

test "TestNavigationBarItemsClass6" {
    const content =
        \\function Z() { }
        \\
        \\Z.foo = 42
        \\
        \\class Z { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestSemanticClassificationModules" {
    const content =
        \\module /*0*/M {
        \\    export var v;
        \\    export interface /*1*/I {
        \\    }
        \\}
        \\
        \\var x: /*2*/M./*3*/I = /*4*/M.v;
        \\var y = /*5*/M;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "namespace.declaration", .Text = "M"},
//         .{.Type = "variable.declaration.local", .Text = "v"},
//         .{.Type = "interface.declaration", .Text = "I"},
//         .{.Type = "variable.declaration", .Text = "x"},
//         .{.Type = "namespace", .Text = "M"},
//         .{.Type = "interface", .Text = "I"},
//         .{.Type = "namespace", .Text = "M"},
//         .{.Type = "variable.local", .Text = "v"},
//         .{.Type = "variable.declaration", .Text = "y"},
//         .{.Type = "namespace", .Text = "M"},
//     });
}

test "TestGotoDefinitionInObjectBindingPattern1" {
    const content =
        \\function bar<T>(onfulfilled: (value: T) => void) {
        \\  return undefined;
        \\}
        \\interface Test {
        \\  /*destination*/prop2: number
        \\}
        \\bar<Test>(({[|pr/*goto*/op2|]})=>{});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "goto");
}

test "TestCompletionListInUnclosedDeleteExpression02" {
    const content =
        \\var x;
        \\var y = (p) => delete /*1*/
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
//                 "p",
//             },
//         },
//     });
}

test "TestQuickinfoVerbosityObjectType1" {
    const content =
        \\type Str = string | {};
        \\type FooType = Str | number;
        \\type Sym = symbol | (() => void);
        \\type BarType = Sym | boolean;
        \\type Obj = { foo: FooType, bar: BarType, str: Str };
        \\const obj1/*o1*/: Obj = { foo: 1, bar: true, str: "3"};
        \\const obj2/*o2*/: { foo: FooType, bar: BarType, str: Str } = { foo: 1, bar: true, str: "3"};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"o1" = .{0, 1, 2, 3}, .@"o2" = .{0, 1, 2}});
}

test "TestFindAllRefsDefinition" {
    const content =
        \\const /*1*/x = 0;
        \\/*2*/x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestQuickInfoOnClosingJsx" {
    const content =
        \\// @Filename: foo.tsx
        \\let x = <div>
        \\    /*$*/</div >
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "$");
    _ = f.VerifyNotQuickInfoExists(undefined);
}

test "TestFindAllRefsForImportCall" {
    const content =
        \\// @Filename: /app.ts
        \\export function he/**/llo() {};
        \\// @Filename: /re-export.ts
        \\export const services = { app: setup(() => import('./app')) }
        \\function setup<T>(importee: () => Promise<T>): T { return {} as any }
        \\// @Filename: /indirect-use.ts
        \\import("./re-export").then(mod => mod.services.app.hello());
        \\// @Filename: /direct-use.ts
        \\async function main() {
        \\    const mod = await import("./app")
        \\    mod.hello();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestQuickInfoForTypeParameterInTypeAlias2" {
    const content =
        \\type Call<AA> = { (): A/*1*/A };
        \\type Index<AA> = {[foo: string]: A/*2*/A};
        \\type GenericMethod<AA> = { method<BB>(): A/*3*/A & B/*4*/B }
        \\type Nesting<TT> = { method<UU>(): new <WW>() => T/*5*/T & U/*6*/U & W/*7*/W };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(type parameter) AA in type Call<AA>", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(type parameter) AA in type Index<AA>", "");
    // f.VerifyQuickInfoAt(undefined, "3", "(type parameter) AA in type GenericMethod<AA>", "");
    // f.VerifyQuickInfoAt(undefined, "4", "(type parameter) BB in method<BB>(): AA & BB", "");
    // f.VerifyQuickInfoAt(undefined, "5", "(type parameter) TT in type Nesting<TT>", "");
    // f.VerifyQuickInfoAt(undefined, "6", "(type parameter) UU in method<UU>(): new <WW>() => TT & UU & WW", "");
    // f.VerifyQuickInfoAt(undefined, "7", "(type parameter) WW in <WW>(): TT & UU & WW", "");
}

test "TestParameterlessSetter" {
    const content =
        \\class foo {
        \\    get getterOnly() {
        \\        return undefined;
        \\    }
        \\    set setterOnly() { }
        \\}
        \\var obj = new foo();
        \\obj.setterOnly = obj./**/getterOnly;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyQuickInfoExists(undefined);
}

test "TestSignatureHelpJSDocTags" {
    const content =
        \\/**
        \\ * This is class Foo.
        \\ * @mytag comment1 comment2
        \\ */
        \\class Foo {
        \\    /**
        \\     * This is the constructor.
        \\     * @myjsdoctag this is a comment
        \\     */
        \\    constructor(value: number) {}
        \\    /**
        \\     * method1 documentation
        \\     * @mytag comment1 comment2
        \\     */
        \\    static method1() {}
        \\    /**
        \\     * @mytag
        \\     */
        \\    method2() {}
        \\    /**
        \\     * @mytag comment1 comment2
        \\     */
        \\    property1: string;
        \\    /**
        \\     * @mytag1 some comments
        \\     * some more comments about mytag1
        \\     * @mytag2
        \\     * here all the comments are on a new line
        \\     * @mytag3
        \\     * @mytag
        \\     */
        \\    property2: number;
        \\    /**
        \\     * @returns {number} a value
        \\     */
        \\    method3(): number { return 3; }
        \\    /**
        \\     * @param {string} foo A value.
        \\     * @returns {number} Another value
        \\     * @mytag
        \\     */
        \\    method4(foo: string): number { return 3; }
        \\    /** @mytag */
        \\    method5() {}
        \\    /** method documentation
        \\     *  @mytag a JSDoc tag
        \\     */
        \\    newMethod() {}
        \\}
        \\var foo = new Foo(/*10*/4);
        \\Foo.method1(/*11*/);
        \\foo.method2(/*12*/);
        \\foo.method3(/*13*/);
        \\foo.method4();
        \\foo.property1;
        \\foo.property2;
        \\foo.method5();
        \\foo.newMet
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSignatureHelp(undefined);
}

test "TestCodeFixMissingTypeAnnotationOnExports21_params_and_return" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @lib: es2019
        \\/**
        \\ * Test
        \\ */
        \\export function foo(): number { return 0; }
        \\/**
        \\* Docs
        \\*/
        \\export const bar = (a = foo()) =>
        \\   a;
        \\// Trivia
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add return type 'number'",
        .NewFileContent = "/**\n * Test\n */\nexport function foo(): number { return 0; }\n/**\n* Docs\n*/\nexport const bar = (a = foo()): number =>\n   a;\n// Trivia",
        .Index =        0,
        .ApplyChanges = true,
    });
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add annotation of type 'number'",
        .NewFileContent = "/**\n * Test\n */\nexport function foo(): number { return 0; }\n/**\n* Docs\n*/\nexport const bar = (a: number = foo()): number =>\n   a;\n// Trivia",
        .Index =        0,
        .ApplyChanges = true,
    });
}

test "TestCompletionForStringLiteral12" {
    const content =
        \\function foo(x: "bla"): void;
        \\function foo(x: "bla"): void;
        \\function foo(x: string) {}
        \\foo("[|/**/|]")
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
//                     .Label = "bla",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "bla",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestCompletionPreferredSuggestions1" {
    const content =
        \\declare let v1: string & {} | "a" | "b" | "c";
        \\v1 = "/*1*/";
        \\declare let v2: number & {} | 0 | 1 | 2;
        \\v2 = /*2*/;
        \\declare let v3: string & Record<never, never> | "a" | "b" | "c";
        \\v3 = "/*3*/";
        \\type LiteralUnion1<T extends U, U> = T | U & {};
        \\type LiteralUnion2<T extends U, U> = T | U & Record<never, never>;
        \\declare let v4: LiteralUnion1<"a" | "b" | "c", string>;
        \\v4 = "/*4*/";
        \\declare let v5: LiteralUnion2<"a" | "b" | "c", string>;
        \\v5 = "/*5*/";
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
//                 "a",
//                 "b",
//                 "c",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "0",
//                 "1",
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
//                 "a",
//                 "b",
//                 "c",
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
//             .Exact = &.{},
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
//                 "a",
//                 "b",
//                 "c",
//             },
//         },
//     });
}

test "TestCodeFixMissingTypeAnnotationOnExports55_generator_return" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @lib: es2015
        \\export function *foo() {
        \\    yield 5;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add return type 'Generator<number, void, unknown>'",
        .NewFileContent = "export function *foo(): Generator<number, void, unknown> {\n    yield 5;\n}",
        .Index = 0,
    });
}

test "TestCodeFixClassSuperMustPrecedeThisAccess" {
    const content =
        \\class Base{
        \\}
        \\class C extends Base{
        \\    private a:number;
        \\    constructor() {[|
        \\        this.a = 12;
        \\        super();
        \\    |]}
        \\    m() { this.a; } // avoid unused 'a'
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "\n        super();\n        this.a = 12;\n    ", true, 0, 0);
}

test "TestSmartSelection_complex" {
    const content =
        \\type X<T, P> = IsExactlyAny<P> extends true ? T : ({ [K in keyof P]: IsExactlyAny<P[K]> extends true ? K extends keyof T ? T[K] : P[/**/K] : P[K]; } & Pick<T, Exclude<keyof T, keyof P>>)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSelectionRanges(undefined);
}

test "TestGetJavaScriptSyntacticDiagnostics21" {
    const content =
        \\// @allowJs: true
        \\// @experimentalDecorators: true
        \\// @Filename: a.js
        \\@internal class C {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNonSuggestionDiagnostics(undefined, null);
}

test "TestReferencesForModifiers" {
    const content =
        \\// @lib: es5
        \\[|/*declareModifier*/declare /*abstractModifier*/abstract class C1 {
        \\    [|/*staticModifier*/static a;|]
        \\    [|/*readonlyModifier*/readonly b;|]
        \\    [|/*publicModifier*/public c;|]
        \\    [|/*protectedModifier*/protected d;|]
        \\    [|/*privateModifier*/private e;|]
        \\}|]
        \\[|/*constModifier*/const enum E {
        \\}|]
        \\[|/*asyncModifier*/async function fn() {}|]
        \\[|/*exportModifier*/export /*defaultModifier*/default class C2 {}|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "declareModifier", "abstractModifier", "staticModifier", "readonlyModifier", "publicModifier", "protectedModifier", "privateModifier", "constModifier", "asyncModifier", "exportModifier", "defaultModifier");
}

test "TestCompletionsUnionStringLiteralProperty" {
    const content =
        \\type Foo = { a: 0, b: 'x' } | { a: 0, b: 'y' } | { a: 1, b: 'z' };
        \\const foo: Foo = { a: 0, b: '/*1*/' }
        \\
        \\type Bar = { a: 0, b: 'fx' } | { a: 0, b: 'fy' } | { a: 1, b: 'fz' };
        \\const bar: Bar = { a: 0, b: 'f/*2*/' }
        \\
        \\type Baz = { x: 0, y: 0, z: 'a' } | { x: 0, y: 1, z: 'b' } | { x: 1, y: 0, z: 'c' } | { x: 1, y: 1, z: 'd' };
        \\const baz1: Baz = { z: '/*3*/' };
        \\const baz2: Baz = { x: 0, z: '/*4*/' };
        \\const baz3: Baz = { x: 0, y: 1, z: '/*5*/' };
        \\const baz4: Baz = { x: 2, y: 1, z: '/*6*/' };
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
//             },
//             .Excludes = &.{
//                 "z",
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
//                 "fx",
//                 "fy",
//             },
//             .Excludes = &.{
//                 "fz",
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
//                 "a",
//                 "b",
//                 "c",
//                 "d",
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
//                 "a",
//                 "b",
//             },
//             .Excludes = &.{
//                 "c",
//                 "d",
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
//                 "b",
//             },
//             .Excludes = &.{
//                 "a",
//                 "c",
//                 "d",
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
//                 "b",
//                 "d",
//             },
//             .Excludes = &.{
//                 "a",
//                 "c",
//             },
//         },
//     });
}

test "TestAugmentedTypesModule6" {
    const content =
        \\declare class m3f { foo(x: number): void }
        \\namespace m3f { export interface I { foo(): void } }
        \\var x: m3f./*1*/
        \\var /*4*/r = new /*2*/m3f(/*3*/);
        \\r./*5*/
        \\var r2: m3f.I = r;
        \\r2./*6*/
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
//             },
//             .Excludes = &.{
//                 "foo",
//             },
//         },
//     });
    _ = f.Insert(undefined, "I;");
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "m3f",
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "3");
    // f.VerifySignatureHelp(undefined, .{.Text = "m3f(): m3f"});
    // f.VerifyQuickInfoAt(undefined, "4", "var r: m3f", "");
    // f.VerifyCompletions(undefined, "5", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "foo",
//             },
//         },
//     });
    _ = f.Insert(undefined, "foo(1)");
    // f.VerifyCompletions(undefined, "6", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "foo",
//             },
//         },
//     });
    _ = f.Insert(undefined, "foo(");
    // f.VerifySignatureHelp(undefined, .{.Text = "foo(): void"});
}

test "TestCompletionsGenericIndexedAccess1" {
    const content =
        \\interface Sample {
        \\  addBook: { name: string, year: number }
        \\}
        \\
        \\export declare function testIt<T>(method: T[keyof T]): any
        \\testIt<Sample>({ /**/ });
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
//                     .Label = "name",
//                 },
//                 &.{
//                     .Label = "year",
//                 },
//             },
//         },
//     });
}

test "TestQuickInfoClassKeyword" {
    const content =
        \\[1].forEach(cla/*1*/ss {});
        \\[1].forEach(cla/*2*/ss OK{});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(local class) (Anonymous class)", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(local class) OK", "");
}

test "TestGenericParameterHelp" {
    const content =
        \\interface IFoo { }
        \\
        \\function testFunction<T extends IFoo, U, M extends IFoo>(a: T, b: U, c: M): M {
        \\    return null;
        \\}
        \\
        \\// Function calls
        \\testFunction</*1*/
        \\testFunction<any, /*2*/
        \\testFunction<any, any, any>(/*3*/
        \\testFunction<any, any,/*4*/ any>(null, null, null);
        \\testFunction<, ,/*5*/>(null, null, null);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifySignatureHelp(undefined, .{.Text = "testFunction<T extends IFoo, U, M extends IFoo>(a: T, b: U, c: M): M", .ParameterCount = 3, .ParameterName = "T", .ParameterSpan = "T extends IFoo"});
    _ = f.GoToMarker(undefined, "2");
    // f.VerifySignatureHelp(undefined, .{.ParameterName = "U", .ParameterSpan = "U"});
    _ = f.GoToMarker(undefined, "3");
    // f.VerifySignatureHelp(undefined, .{.ParameterName = "a", .ParameterSpan = "a: any"});
    _ = f.GoToMarker(undefined, "4");
    // f.VerifySignatureHelp(undefined, .{.ParameterName = "M", .ParameterSpan = "M extends IFoo"});
    _ = f.GoToMarker(undefined, "5");
    // f.VerifySignatureHelp(undefined, .{.ParameterName = "M", .ParameterSpan = "M extends IFoo"});
}

test "TestCompletionListAtIdentifierDefinitionLocations_infers" {
    const content =
        \\type UType = 1;
        \\type Bar<T> = T extends { a: (x: infer /*1*/) => void; b: (x: infer U/*2*/) => void }
        \\   ? U
        \\   : never;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, f.Markers(), null);
}

test "TestRenameAlias2" {
    const content =
        \\[|module [|{| "contextRangeIndex": 0 |}SomeModule|] { export class SomeClass { } }|]
        \\import M = [|SomeModule|];
        \\import C = M.SomeClass;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "SomeModule");
}

test "TestNavbar01" {
    const content =
        \\// @lib: es5
        \\// Interface
        \\interface IPoint {
        \\    getDist(): number;
        \\    new(): IPoint;
        \\    (): any;
        \\    [x:string]: number;
        \\    prop: string;
        \\}
        \\
        \\/// Module
        \\namespace Shapes {
        \\    // Class
        \\    export class Point implements IPoint {
        \\        constructor (public x: number, public y: number) { }
        \\
        \\        // Instance member
        \\        getDist() { return Math.sqrt(this.x * this.x + this.y * this.y); }
        \\
        \\        // Getter
        \\        get value(): number { return 0; }
        \\
        \\        // Setter
        \\        set value(newValue: number) { return; }
        \\
        \\        // Static member
        \\        static origin = new Point(0, 0);
        \\
        \\        // Static method
        \\        private static getOrigin() { return Point.origin;}
        \\    }
        \\
        \\    enum Values { value1, value2, value3 }
        \\}
        \\
        \\// Local variables
        \\var p: IPoint = new Shapes.Point(3, 4);
        \\var dist = p.getDist();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestJsxAttributeCompletionStyleNoSnippet" {
    const content =
        \\// @Filename: foo.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        foo: {
        \\            prop_a: boolean;
        \\            prop_b: string;
        \\            prop_c: any;
        \\            prop_d: { p1: string; }
        \\            prop_e: string | undefined;
        \\            prop_f: boolean | undefined | { p1: string; };
        \\            prop_g: { p1: string; } | undefined;
        \\            prop_h?: string;
        \\            prop_i?: boolean;
        \\            prop_j?: { p1: string; };
        \\        }
        \\    }
        \\}
        \\
        \\<foo [|prop_/**/|] />
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
//                     .Label = "prop_a",
//                 },
//                 &.{
//                     .Label = "prop_b",
//                 },
//                 &.{
//                     .Label = "prop_c",
//                 },
//                 &.{
//                     .Label = "prop_d",
//                 },
//                 &.{
//                     .Label = "prop_e",
//                 },
//                 &.{
//                     .Label = "prop_f",
//                 },
//                 &.{
//                     .Label = "prop_g",
//                 },
//                 &.{
//                     .Label =      "prop_h?",
//                     .InsertText = undefined("prop_h"),
//                     .FilterText = undefined("prop_h"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =      "prop_i?",
//                     .InsertText = undefined("prop_i"),
//                     .FilterText = undefined("prop_i"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =      "prop_j?",
//                     .InsertText = undefined("prop_j"),
//                     .FilterText = undefined("prop_j"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
}

test "TestCompletionListForTransitivelyExportedMembers03" {
    const content =
        \\// @Filename: A.ts
        \\export interface I1 { one: number }
        \\export interface I2 { two: string }
        \\export type I1_OR_I2 = I1 | I2;
        \\
        \\export class C1 {
        \\    one: string;
        \\}
        \\
        \\export namespace Inner {
        \\    export interface I3 {
        \\        three: boolean
        \\    }
        \\
        \\    export var varVar = 100;
        \\    export let letVar = 200;
        \\    export const constVar = 300;
        \\}
        \\// @Filename: B.ts
        \\export var bVar = "bee!";
        \\// @Filename: C.ts
        \\export var cVar = "see!";
        \\export * from "./A";
        \\export * from "./B"
        \\// @Filename: D.ts
        \\import * as c from "./C";
        \\var x: c./**/
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
//                 "I1",
//                 "I2",
//                 "I1_OR_I2",
//                 "C1",
//             },
//         },
//     });
}

test "TestCompletionsClassMemberImportTypeNodeParameter4" {
    const content =
        \\// @module: node18
        \\// @FileName: /other/cls.d.ts
        \\export declare class Cls {
        \\  method(
        \\    param: import("./doesntexist.js").Foo,
        \\  ): import("./doesntexist.js").Foo;
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
//                     .InsertText =          undefined("method(param: import(\"./doesntexist.js\").Foo);"),
//                     .FilterText =          undefined("method"),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                 },
//             },
//         },
//     });
}

test "TestNavigationBarItemsMultilineStringIdentifiers3" {
    const content =
        \\declare module 'MoreThanOneHundredAndFiftyCharacters\
        \\MoreThanOneHundredAndFiftyCharacters\
        \\MoreThanOneHundredAndFiftyCharacters\
        \\MoreThanOneHundredAndFiftyCharacters\
        \\MoreThanOneHundredAndFiftyCharacters\
        \\MoreThanOneHundredAndFiftyCharacters\
        \\MoreThanOneHundredAndFiftyCharacters' { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestGetEditsForFileRename_renameToIndex" {
    const content =
        \\// @Filename: /a.ts
        \\/// <reference path="./src/old.ts" />
        \\import old from "./src/old";
        \\// @Filename: /src/a.ts
        \\/// <reference path="./old.ts" />
        \\import old from "./old";
        \\// @Filename: /src/foo/a.ts
        \\/// <reference path="../old.ts" />
        \\import old from "../old";
        \\// @Filename: /src/old.ts
        \\
        \\// @Filename: /tsconfig.json
        \\{ "files": ["a.ts", "src/a.ts", "src/foo/a.ts", "src/old.ts"] }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyWillRenameFilesEdits(undefined, "/src/old.ts", "/src/index.ts", .{
//         .@"/a.ts" = "/// <reference path=\"./src/index.ts\" />\nimport old from \"./src\";",
//         .@"/src/a.ts" = "/// <reference path=\"./index.ts\" />\nimport old from \".\";",
//         .@"/src/foo/a.ts" = "/// <reference path=\"../index.ts\" />\nimport old from \"..\";",
//         .@"/tsconfig.json" = "{ \"files\": [\"a.ts\", \"src/a.ts\", \"src/foo/a.ts\", \"src/index.ts\"] }",
//     }, null );
}

test "TestFindAllRefsClassExpression0" {
    const content =
        \\// @Filename: /a.ts
        \\export = class /*0*/A {
        \\    m() { /*1*/A; }
        \\};
        \\// @Filename: /b.ts
        \\import /*2*/A = require("./a");
        \\/*3*/A;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2", "3");
}

test "TestJsdocDeprecated_suggestion17" {
    const content =
        \\// @filename: foo.ts
        \\interface Foo {
        \\    /** @deprecated */
        \\    [k: string]: any;
        \\    /** @deprecated please use 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifySuggestionDiagnostics(undefined, []*.{
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'x' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[0].LSRange,
//         },
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'z' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[2].LSRange,
//         },
//     });
}

test "TestCompletionNoAutoInsertQuestionDotWithUserPreferencesOff" {
    const content =
        \\// @strict: true
        \\interface User {
        \\    address?: {
        \\        city: string;
        \\        "postal code": string;
        \\    }
        \\};
        \\declare const user: User;
        \\user.address[|./**/|]
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
//             .Exact = &.{},
//         },
//     });
}

test "TestCompletionsImportFromJSXTag" {
    const content =
        \\// @jsx: react
        \\// @Filename: /types.d.ts
        \\declare namespace JSX {
        \\  interface IntrinsicElements { a }
        \\}
        \\// @Filename: /Box.tsx
        \\export function Box(props: any) { return null; }
        \\// @Filename: /App.tsx
        \\export function App() {
        \\  return (
        \\    <div className="App">
        \\      <Box/**/
        \\    </div>
        \\  )
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "Box",
//         .Source =      "./Box",
//         .Description = "Add import from \"./Box\"",
//         .NewFileContent = undefined("import { Box } from \"./Box\";\n\nexport function App() {\n  return (\n    <div className=\"App\">\n      <Box\n    </div>\n  )\n}"),
//     });
}

test "TestSignatureHelpRestArgs3" {
    const content =
        \\// @target: esnext
        \\// @lib: esnext
        \\const layers = Object.assign({}, /*1*/...[]);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSignatureHelp(undefined);
}

test "TestFormatNoSpaceBetweenClosingParenAndTemplateString" {
    const content =
        \\foo() 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "foo()`abc`;\nbar()`def`;\nbaz()`a${x}b`;");
}

test "TestCodeFixClassImplementInterface_all" {
    const content =
        \\interface I { i(): void; }
        \\interface J { j(): void; }
        \\class C implements I, J {}
        \\class D implements J {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFixAll(undefined, .{
        .FixID = "fixClassIncorrectlyImplementsInterface",
        .NewFileContent = "interface I { i(): void; }\ninterface J { j(): void; }\nclass C implements I, J {\n    i(): void {\n        throw new Error(\"Method not implemented.\");\n    }\n    j(): void {\n        throw new Error(\"Method not implemented.\");\n    }\n}\nclass D implements J {\n    j(): void {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
    });
}

test "TestGetEditsForFileRename_nodeModuleDirectoryCase" {
    const content =
        \\// @Filename: /a/b/file1.ts
        \\import { foo } from "foo";
        \\// @Filename: /a/node_modules/foo/index.d.ts
        \\export const foo = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyWillRenameFilesEdits(undefined, "/a/b", "/a/B", .{}, null );
}

test "TestAutoImportProvider_exportMap1" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "lib": ["es5"],
        \\    "module": "nodenext"
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
        \\    ".": {
        \\      "types": "./lib/index.d.ts"
        \\    },
        \\    "./lol": {
        \\      "types": "./lib/lol.d.ts"
        \\    }
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

test "TestGetEditsForFileRename_tsconfig_include_noChange" {
    const content =
        \\// @Filename: /src/tsconfig.json
        \\{
        \\    "include": ["dir"],
        \\}
        \\// @Filename: /src/dir/a.ts
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyWillRenameFilesEdits(undefined, "/src/dir/a.ts", "/src/dir/b.ts", .{}, null );
}

test "TestCompletionsObjectLiteralModuleExports" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: index.js
        \\const almanac = 0;
        \\module.exports = {
        \\  a/**/
        \\};
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
//                 "almanac",
//             },
//             .Excludes = &.{
//                 "a",
//             },
//         },
//     });
}

test "TestCompletionForQuotedPropertyInPropertyAssignment4" {
    const content =
        \\export interface ConfigFiles {
        \\  jspm: string;
        \\  'jspm:browser': string;
        \\}
        \\function foo(c: ConfigFiles) {}
        \\foo({
        \\    j/*0*/: "",
        \\    "[|/*1*/|]": "",
        \\})
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
//             .Exact = &.{
//                 "\"jspm:browser\"",
//                 "jspm",
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
//             .Exact = &.{
//                 &.{
//                     .Label = "jspm",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "jspm",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "jspm:browser",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "jspm:browser",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestCompletionInChecks1" {
    const content =
        \\// @target: esnext
        \\declare const obj: {
        \\  a?: string;
        \\  b: number;
        \\};
        \\
        \\if ("/*1*/" in obj) {}
        \\if (((("/*2*/"))) in obj) {}
        \\if ("/*3*/" in (((obj)))) {}
        \\if (((("/*4*/"))) in (((obj)))) {}
        \\
        \\type MyUnion = { missing: true } | { result: string };
        \\declare const u: MyUnion;
        \\if ("/*5*/" in u) {}
        \\
        \\class Cls1 { foo = ''; #bar = 0; }
        \\declare const c1: Cls1;
        \\if ("/*6*/" in c1) {}
        \\
        \\class Cls2 { foo = ''; private bar = 0; }
        \\declare const c2: Cls2;
        \\if ("/*7*/" in c2) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "2", "3", "4"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "a",
//                 "b",
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
//             .Exact = &.{
//                 "missing",
//                 "result",
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
//             .Exact = &.{
//                 "foo",
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
//             .Exact = &.{
//                 "bar",
//                 "foo",
//             },
//         },
//     });
}

test "TestGetSemanticDiagnosticForNoDeclaration" {
    const content =
        \\// @module: CommonJS
        \\interface privateInterface {}
        \\export class Bar implements /*1*/privateInterface/*2*/{ }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
}

test "TestQuickInfoShowsGenericSpecialization" {
    const content =
        \\class A<T> { }
        \\var /**/foo = new A<number>();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "var foo: A<number>", "");
}

test "TestReferences01" {
    const content =
        \\// @lib: es5
        \\// @Filename: /home/src/workspaces/project/referencesForGlobals_1.ts
        \\class /*0*/globalClass {
        \\    public f() { }
        \\}
        \\// @Filename: /home/src/workspaces/project/referencesForGlobals_2.ts
        \\///<reference path="referencesForGlobals_1.ts" />
        \\var c = /*1*/globalClass();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestCompletionNoAutoInsertQuestionDotForThis" {
    const content =
        \\// @strict: true
        \\class Address {
        \\    city: string = "";
        \\    "postal code": string = "";
        \\    method() {
        \\        this[|./**/|]
        \\    }
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
//                     .Label = "method",
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

test "TestGoToDefinitionImportMeta" {
    const content =
        \\// @module: esnext
        \\// @Filename: foo.ts
        \\/// <reference path='./bar.d.ts' />
        \\import.me/*reference*/ta;
        \\//@Filename: bar.d.ts
        \\interface ImportMeta {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "reference");
    _ = f.VerifyNoErrors(undefined);
}

test "TestCompletionListAtIdentifierDefinitionLocations_destructuring" {
    const content =
        \\// @Filename: a.ts
        \\var [x/*variable1*/
        \\// @Filename: b.ts
        \\var [x, y/*variable2*/
        \\// @Filename: c.ts
        \\var [./*variable3*/
        \\// @Filename: d.ts
        \\var [x, ...z/*variable4*/
        \\// @Filename: e.ts
        \\var {x/*variable5*/
        \\// @Filename: f.ts
        \\var {x, y/*variable6*/
        \\// @Filename: g.ts
        \\function func1({ a/*parameter1*/
        \\// @Filename: h.ts
        \\function func2({ a, b/*parameter2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, f.Markers(), null);
}

test "TestGetSemanticDiagnosticForDeclaration1" {
    const content =
        \\// @declaration: true
        \\// @Filename: File.d.ts
        \\declare var v: string;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
}

test "TestQuickInfoInJsdocInTsFile1" {
    const content =
        \\/** @type {() => { /*1*/data: string[] }} */
        \\function test(): { data: string[] } {
        \\  return {
        \\    data: [],
        \\  };
        \\}
        \\
        \\/** @returns {{ /*2*/data: string[] }} */
        \\function test2(): { data: string[] } {
        \\  return {
        \\    data: [],
        \\  };
        \\}
        \\
        \\/** @type {{ /*3*/bar: string; }} */
        \\const test3 = { bar: '' };
        \\
        \\type SomeObj = { bar: string; };
        \\/** @type {SomeObj/*4*/} */
        \\const test4 = { bar: '' }
        \\
        \\/**
        \\ * @param/*5*/ stuff/*6*/ Stuff to do stuff with
        \\ */
        \\function doStuffWithStuff(stuff: { quantity: number }) {}
        \\
        \\declare const stuff: { quantity: number };
        \\/** @see {doStuffWithStuff/*7*/} */
        \\if (stuff.quantity) {}
        \\
        \\/** @type {(a/*8*/: string) => void} */
        \\function test2(a: string) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "", "");
    // f.VerifyQuickInfoAt(undefined, "2", "", "");
    // f.VerifyQuickInfoAt(undefined, "3", "", "");
    // f.VerifyQuickInfoAt(undefined, "4", "type SomeObj = {\n    bar: string;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "5", "(parameter) stuff: {\n    quantity: number;\n}", "Stuff to do stuff with");
    // f.VerifyQuickInfoAt(undefined, "6", "(parameter) stuff: {\n    quantity: number;\n}", "Stuff to do stuff with");
    // f.VerifyQuickInfoAt(undefined, "7", "function doStuffWithStuff(stuff: {\n    quantity: number;\n}): void", "");
    // f.VerifyQuickInfoAt(undefined, "8", "", "");
}

test "TestQuickInfoCircularInstantiationExpression" {
    const content =
        \\declare function foo<T>(t: T): typeof foo<T>;
        \\/**/foo("");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestNavigationBarItemsModules1" {
    const content =
        \\declare module "X.Y.Z" {}
        \\
        \\declare module 'X2.Y2.Z2' {}
        \\
        \\declare module "foo";
        \\
        \\namespace A.B.C {
        \\    export var x;
        \\}
        \\
        \\namespace A.B {
        \\    export var y;
        \\}
        \\
        \\namespace A {
        \\    export var z;
        \\}
        \\
        \\namespace A {
        \\    namespace B {
        \\        namespace C {
        \\            declare var x;
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestImportMetaCompletionDetails" {
    const content =
        \\// @filename: index.mts
        \\// @module: Node16
        \\// @strict: true
        \\let x = import.meta/**/;
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
//                     .Label =  "meta",
//                     .Detail = undefined("(property) ImportMetaExpression.meta: ImportMeta"),
//                 },
//             },
//         },
//     });
    _ = f.VerifyNoErrors(undefined);
}

test "TestJsdocLink4" {
    const content =
        \\declare class I {
        \\  /** {@link I} */
        \\  bar/*1*/(): void
        \\}
        \\/** {@link I} */
        \\var n/*2*/ = 1
        \\/**
        \\ * A real, very serious {@link I to an interface}. Right there.
        \\ * @param x one {@link Pos here too}
        \\ */
        \\function f(x) {
        \\}
        \\f/*3*/()
        \\type Pos = [number, number]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCompletionListInClosedFunction03" {
    const content =
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string, c: typeof x = /*1*/) {
        \\
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

test "TestConstructorFindAllReferences4" {
    const content =
        \\export class C {
        \\    /**/protected constructor() { }
        \\    public foo() { }
        \\}
        \\
        \\new C().foo();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestFindAllRefsCatchClause" {
    const content =
        \\try { }
        \\catch (/*1*/err) {
        \\    /*2*/err;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestJsdocTypedefTagSemanticMeaning1" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\/** @typedef {number} */
        \\/*1*/const /*2*/T = 1;
        \\/** @type {/*3*/T} */
        \\const n = /*4*/T;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestGoToDefinitionOverriddenMember9" {
    const content =
        \\// @noImplicitOverride: true
        \\interface I {
        \\    m(): void;
        \\}
        \\class A {
        \\    /*2*/m() {};
        \\}
        \\class B extends A implements I {
        \\   [|/*1*/override|] m() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestCompletionsWithOptionalPropertiesGenericPartial2" {
    const content =
        \\// @strict: true
        \\interface Foo {
        \\    a: boolean;
        \\}
        \\function partialFoo<T extends Partial<Foo>>(x: T, y: T) {return t}
        \\partialFoo({ a: true, b: true }, { /*1*/ });
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

test "TestCompletionsImportBaseUrl" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "baseUrl": ".",
        \\        "module": "esnext"
        \\    }
        \\}
        \\// @Filename: /src/a.ts
        \\export const foo = 0;
        \\// @Filename: /src/b.ts
        \\fo/**/
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
//                     .Detail =              undefined("const foo: 0"),
//                     .Kind =                undefined(lsproto.CompletionItemKindVariable),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
}

test "TestImportNameCodeFixNewImportPaths_withExtension" {
    const content =
        \\// @Filename: /src/a.ts
        \\[|foo|]
        \\// @Filename: /src/thisHasPathMapping.ts
        \\export function foo() {};
        \\// @Filename: /tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "baseUrl": ".",
        \\        "paths": {
        \\            "foo": ["src/thisHasPathMapping.ts"]
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { foo } from \"foo\";\n\nfoo",
    }, null );
}

test "TestCompletionForQuotedPropertyInPropertyAssignment1" {
    const content =
        \\export interface Configfiles {
        \\  jspm: string;
        \\  'jspm:browser': string;
        \\}
        \\let files: Configfiles;
        \\files = {
        \\   /*0*/: '',
        \\   '[|/*1*/|]': ''
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
//             .Exact = &.{
//                 "\"jspm:browser\"",
//                 "jspm",
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
//             .Exact = &.{
//                 &.{
//                     .Label = "jspm",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "jspm",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "jspm:browser",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "jspm:browser",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestGoToDefinitionReturn1" {
    const content =
        \\function /*end*/foo() {
        \\    [|/*start*/return|] 10;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "start");
}

test "TestImportCompletionsPackageJsonImportsLength1" {
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
//                 "d",
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

test "TestFindAllRefsForStringLiteralTypes" {
    const content =
        \\type Options = "/*1*/option 1" | "option 2";
        \\let myOption: Options = "/*2*/option 1";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestAsConstRefsNoErrors3" {
    const content =
        \\// @checkJs: true
        \\// @Filename: file.js
        \\class Tex {
        \\    type = (/** @type {/**/const} */'Text');
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "");
    _ = f.VerifyNoErrors(undefined);
}

test "TestInlayHintsInteractiveParameterNamesWithComments" {
    const content =
        \\const fn = (x: any) => { }
        \\fn(/* nobody knows exactly what this param is */ 42);
        \\function foo (aParameter: number, bParameter: number, cParameter: number) { }
        \\foo(
        \\    /** aParameter */
        \\    1,
        \\    // bParameter
        \\    2,
        \\    /* cParameter */
        \\    3
        \\)
        \\foo(
        \\    /** multiple comments */
        \\    /** aParameter */
        \\    1,
        \\    /** bParameter */
        \\    /** multiple comments */
        \\    2,
        \\    // cParameter
        \\    /** multiple comments */
        \\    3
        \\)
        \\foo(
        \\    /** wrong name */
        \\    1,
        \\    2,
        \\    /** multiple */
        \\    /** wrong */
        \\    /** name */
        \\    3
        \\)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayParameterNameHints = lsutil.IncludeInlayParameterNameHintsLiterals}});
}

test "TestNavigationBarMerging_grandchildren" {
    const content =
        \\// Should not merge grandchildren with property assignments
        \\const o = {
        \\    a: {
        \\        m() {},
        \\    },
        \\    b: {
        \\        m() {},
        \\    },
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCompletionListInReturnWithContextualThis" {
    const content =
        \\interface Ctx {
        \\    foo(): {
        \\        x: number
        \\    };
        \\}
        \\
        \\declare function wrap(cb: (this: Ctx) => any): void;
        \\
        \\wrap(function () {
        \\    const xs = this.foo();
        \\    return xs./*inReturn*/
        \\});
        \\
        \\wrap(function () {
        \\    const xs = this.foo();
        \\    const y = xs./*involvedInReturn*/
        \\    return y;
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "inReturn", &.{
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
    // f.VerifyCompletions(undefined, "involvedInReturn", &.{
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

test "TestGoToDefinitionShadowVariable" {
    const content =
        \\var shadowVariable = "foo";
        \\function shadowVariableTestModule() {
        \\    var /*shadowVariableDefinition*/shadowVariable;
        \\    /*shadowVariableReference*/shadowVariable = 1;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, false, "shadowVariableReference");
}

test "TestOrganizeImportsUnicode2" {
    const content =
        \\import {
        \\    a2,
        \\    a100,
        \\    a1,
        \\} from './foo';
        \\
        \\console.log(a1, a2, a100);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(undefined,
//         "import {\n    a1,\n    a100,\n    a2,\n} from './foo';\n\nconsole.log(a1, a2, a100);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase =       core.TSFalse,
//             .OrganizeImportsCollation =        lsutil.OrganizeImportsCollationUnicode,
//             .OrganizeImportsNumericCollation = core.TSFalse,
//         },
//     );
    // f.VerifyOrganizeImports(undefined,
//         "import {\n    a1,\n    a2,\n    a100,\n} from './foo';\n\nconsole.log(a1, a2, a100);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase =       core.TSFalse,
//             .OrganizeImportsCollation =        lsutil.OrganizeImportsCollationUnicode,
//             .OrganizeImportsNumericCollation = core.TSTrue,
//         },
//     );
}

test "TestCommentsBlocks" {
    const content =
        \\/*1*/// 1
        \\var x,
        \\    /*2*/// 2
        \\    y,
        \\/*3*/     /* %3 */
        \\    z;
        \\
        \\/*4*/ // 4
        \\switch (x) {
        \\/*5*/     // 5
        \\    case 1:
        \\/*6*/         // 6
        \\        break;
        \\/*7*/     // 7
        \\    case 2:
        \\/*8*/     // 8
        \\}
        \\
        \\/*9*/ // 9
        \\if (true)
        \\/*10*/     // 10
        \\    ;
        \\/*11*/ // 11
        \\else {
        \\/*12*/     // 12
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "// 1");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "    // 2");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "    /* %3 */");
    _ = f.GoToMarker(undefined, "4");
    _ = f.VerifyCurrentLineContent(undefined, "// 4");
    _ = f.GoToMarker(undefined, "5");
    _ = f.VerifyCurrentLineContent(undefined, "    // 5");
    _ = f.GoToMarker(undefined, "6");
    _ = f.VerifyCurrentLineContent(undefined, "        // 6");
    _ = f.GoToMarker(undefined, "7");
    _ = f.VerifyCurrentLineContent(undefined, "    // 7");
    _ = f.GoToMarker(undefined, "8");
    _ = f.VerifyCurrentLineContent(undefined, "    // 8");
    _ = f.GoToMarker(undefined, "9");
    _ = f.VerifyCurrentLineContent(undefined, "// 9");
    _ = f.GoToMarker(undefined, "10");
    _ = f.VerifyCurrentLineContent(undefined, "    // 10");
    _ = f.GoToMarker(undefined, "11");
    _ = f.VerifyCurrentLineContent(undefined, "// 11");
    _ = f.GoToMarker(undefined, "12");
    _ = f.VerifyCurrentLineContent(undefined, "    // 12");
}

test "TestGetOccurrencesReturn2" {
    const content =
        \\function f(a: number) {
        \\    if (a > 0) {
        \\        return (function () {
        \\            [|return|];
        \\            [|ret/**/urn|];
        \\            [|return|];
        \\
        \\            while (false) {
        \\                [|return|] true;
        \\            }
        \\        })() || true;
        \\    }
        \\
        \\    var unusued = [1, 2, 3, 4].map(x => { return 4 })
        \\
        \\    return;
        \\    return true;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestIdentifierErrorRecovery" {
    const content =
        \\var /*1*/export/*2*/;
        \\var foo;
        \\var /*3*/class/*4*/;
        \\var bar;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyErrorExistsBetweenMarkers(undefined, "1", "2");
    _ = f.VerifyErrorExistsBetweenMarkers(undefined, "3", "4");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 3);
    _ = f.GoToEOF(undefined);
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "foo",
//                 "bar",
//             },
//         },
//     });
}

test "TestSemanticModernClassificationConstructorTypes" {
    const content =
        \\// @lib: es5
        \\Object.create(null);
        \\const x = Promise.resolve(Number.MAX_VALUE);
        \\if (x instanceof Promise) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "class.defaultLibrary", .Text = "Object"},
//         .{.Type = "method.defaultLibrary", .Text = "create"},
//         .{.Type = "variable.declaration.readonly", .Text = "x"},
//         .{.Type = "class.defaultLibrary", .Text = "Number"},
//         .{.Type = "property.readonly.defaultLibrary", .Text = "MAX_VALUE"},
//         .{.Type = "variable.readonly", .Text = "x"},
//     });
}

test "TestGoToImplementationInterface_10" {
    const content =
        \\// @Filename: /a.ts
        \\interface /*def*/A {
        \\    foo: boolean;
        \\}
        \\interface [|B|] extends A {
        \\    bar: boolean;
        \\}
        \\export class [|C|] implements B {
        \\    foo = true;
        \\    bar = true;
        \\}
        \\export class [|D|] extends C { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "def");
}

test "TestGotoDefinitionLinkTag6" {
    const content =
        \\enum E {
        \\    /** {@link E./*1*/[|A|]} */
        \\    [|/*2*/A|]
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, false, "1");
}

test "TestMemberListOfEnumInModule" {
    const content =
        \\namespace Fixes {
        \\    enum Foo {
        \\        bar,
        \\        baz
        \\    }
        \\    var f: Foo = Foo./**/;
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
//                 "bar",
//                 "baz",
//             },
//         },
//     });
}

test "TestGetOutliningForTupleType" {
    const content =
        \\type A =[| [
        \\    number,
        \\    number,
        \\    number
        \\]|]
        \\
        \\type B =[| [
        \\    [|[
        \\        [|[
        \\            number,
        \\            number,
        \\            number
        \\        ]|]
        \\    ]|]
        \\]|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOutliningSpans(undefined);
}

test "TestQuickInfoForFunctionDeclaration" {
    const content =
        \\interface A<T> { }
        \\
        \\function ma/*makeA*/keA<T>(t: T): A<T> { return null; }
        \\
        \\function /*f*/f<T>(t: T) {
        \\    return makeA(t);
        \\}
        \\
        \\var x = f(0);
        \\var y = makeA(0);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "makeA", "function makeA<T>(t: T): A<T>", "");
    // f.VerifyQuickInfoAt(undefined, "f", "function f<T>(t: T): A<T>", "");
}

test "TestCallHierarchyConstNamedFunctionExpression" {
    const content =
        \\function foo() {
        \\    bar();
        \\}
        \\
        \\const /**/bar = function () {
        \\    baz();
        \\}
        \\
        \\function baz() {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyBaselineCallHierarchy(undefined);
}

test "TestDeleteExtensionInReopenedInterface" {
    const content =
        \\interface A { a: number; }
        \\interface B { b: number; }
        \\
        \\interface I /*del*/extends A { }
        \\interface I extends B { }
        \\
        \\var i: I;
        \\class C /*delImplements*/implements A { }
        \\var c: C;
        \\c.a;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "del");
    _ = f.DeleteAtCaret(undefined, 9);
    _ = f.GoToEOF(undefined);
    _ = f.Insert(undefined, "var a = i.a;");
    _ = f.GoToMarker(undefined, "delImplements");
    _ = f.DeleteAtCaret(undefined, 12);
    _ = f.GoToMarker(undefined, "del");
    _ = f.Insert(undefined, "extends A");
}

test "TestAutoImportSameNameDefaultExported" {
    const content =
        \\// @lib: es5
        \\// @module: commonjs
        \\// @Filename: /node_modules/antd/index.d.ts
        \\declare function Table(): void;
        \\export default Table;
        \\// @Filename: /node_modules/rc-table/index.d.ts
        \\declare function Table(): void;
        \\export default Table;
        \\// @Filename: /index.ts
        \\Table/**/
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
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     &.{
//                         .Label = "Table",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "antd",
//                             },
//                         },
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     },
//                     &.{
//                         .Label = "Table",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "rc-table",
//                             },
//                         },
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     },
//                 }, false,
//             ),
//         },
//     });
}

test "TestCompletionsSymbolMembers" {
    const content =
        \\declare const Symbol: (s: string) => symbol;
        \\const s = Symbol("s");
        \\interface I { [s]: number };
        \\declare const i: I;
        \\i[|./*i*/|];
        \\
        \\namespace N { export const s2 = Symbol("s2"); }
        \\interface J { [N.s2]: number; }
        \\declare const j: J;
        \\j[|./*j*/|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "i", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "s",
//                     .InsertText = undefined("[s]"),
//                     .SortText =   undefined(string(ls.SortTextGlobalsOrKeywords)),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "s",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "j", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "N",
//                     .InsertText = undefined("[N]"),
//                     .SortText =   undefined(string(ls.SortTextGlobalsOrKeywords)),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "N",
//                             .Range =   f.Ranges()[1].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestSmartSelection_JSDocTags3" {
    const content =
        \\/**
        \\ * @param {/**/string} x
        \\ */
        \\function foo(x) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSelectionRanges(undefined);
}

test "TestRemoveExportedClassFromReopenedModule" {
    const content =
        \\namespace multiM { }
        \\
        \\namespace multiM {
        \\    /*1*/export class c { }
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.DeleteAtCaret(undefined, 18);
    _ = f.GoToEOF(undefined);
    _ = f.Insert(undefined, "new multiM.c();");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestNavigationBarItemsMultilineStringIdentifiers1" {
    const content =
        \\declare module "Multiline\r\nMadness" {
        \\}
        \\
        \\declare module "Multiline\
        \\Madness" {
        \\}
        \\declare module "MultilineMadness" {}
        \\
        \\declare module "Multiline\
        \\Madness2" {
        \\}
        \\
        \\interface Foo {
        \\    "a1\\\r\nb";
        \\    "a2\
        \\    \
        \\    b"(): Foo;
        \\}
        \\
        \\class Bar implements Foo {
        \\    'a1\\\r\nb': Foo;
        \\
        \\    'a2\
        \\    \
        \\    b'(): Foo {
        \\        return this;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCompletionListInTypedObjectLiterals3" {
    const content =
        \\interface Foo {
        \\    x: { a: number };
        \\}
        \\var aaa: Foo;
        \\aaa.x = { /*10*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "10", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "a",
//             },
//         },
//     });
}

test "TestGoToDefinitionOverriddenMember12" {
    const content =
        \\// @noImplicitOverride: true
        \\class Foo {
        \\    static /*2*/p = '';
        \\}
        \\class Bar extends Foo {
        \\    static [|/*1*/override|] p = '';
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestGoToDefinitionIndexSignature" {
    const content =
        \\interface I {
        \\    /*defI*/[x: string]: boolean;
        \\}
        \\interface J {
        \\    /*defJ*/[x: string]: number;
        \\}
        \\interface K {
        \\    /*defa*/[x: 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "useI", "useIJ", "usea", "useb", "useab");
}

test "TestAddDeclareToModule" {
    const content =
        \\/**/namespace mAmbient {
        \\    namespace m3 { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "declare ");
}

test "TestUnusedLocalsInFunction3" {
    const content =
        \\// @noUnusedLocals: true
        \\function greeter() {
        \\   [| var x, y = 0,z = 1; |]
        \\    x+1;
        \\    z+1;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "var x,z = 1;", false, 6133, 0);
}

test "TestCodeFixClassImplementInterfaceDuplicateMember1" {
    const content =
        \\interface I1 {
        \\    x: number;
        \\}
        \\interface I2 {
        \\    x: number;
        \\}
        \\
        \\class C implements I1,I2 {[| |]}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFixAvailable(undefined, &.{"Implement interface 'I1'", "Implement interface 'I2'"});
}

test "TestGoToSource1_localJsBesideDts" {
    const content =
        \\// @lib: es5
        \\// @Filename: /home/src/workspaces/project/a.js
        \\export const /*end*/a = "a";
        \\// @Filename: /home/src/workspaces/project/a.d.ts
        \\export declare const a: string;
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { a } from [|"./a"/*moduleSpecifier*/|];
        \\[|a/*identifier*/|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "identifier", "moduleSpecifier");
}

test "TestCompletionsImport_named_exportEqualsNamespace" {
    const content =
        \\// @module: esnext
        \\// @Filename: /a.d.ts
        \\declare namespace N {
        \\    export const foo = 0;
        \\}
        \\export = N;
        \\// @Filename: /b.ts
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
//                     .Detail =              undefined("const N.foo: 0"),
//                     .Kind =                undefined(lsproto.CompletionItemKindVariable),
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
//         .NewFileContent = undefined("import { foo } from \"./a\";\n\nf;"),
//     });
}

test "TestFindAllRefsMissingModulesOverlappingSpecifiers" {
    const content =
        \\// https://github.com/microsoft/TypeScript/issues/5551
        \\import { resolve/*0*/ as resolveUrl } from "idontcare";
        \\import { resolve/*1*/ } from "whatever";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "0", "1");
}

test "TestFormattingSpaceAfterCommaBeforeOpenParen" {
    const content =
        \\foo(a,(b))/*1*/
        \\foo(a,(<b>c).d)/*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, ";");
    _ = f.VerifyCurrentLineContent(undefined, "foo(a, (b));");
    _ = f.GoToMarker(undefined, "2");
    _ = f.Insert(undefined, ";");
    _ = f.VerifyCurrentLineContent(undefined, "foo(a, (<b>c).d);");
}

test "TestGoToDefinitionThis" {
    const content =
        \\function f(/*fnDecl*/this: number) {
        \\    return [|/*fnUse*/this|];
        \\}
        \\class /*cls*/C {
        \\    constructor() { return [|/*clsUse*/this|]; }
        \\    get self(/*getterDecl*/this: number) { return [|/*getterUse*/this|]; }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "fnUse", "clsUse", "getterUse");
}

test "TestGoToDefinitionTypePredicate" {
    const content =
        \\class /*classDeclaration*/A {}
        \\function f(/*parameterDeclaration*/parameter: any): [|/*parameterName*/parameter|] is [|/*typeReference*/A|] {
        \\    return typeof parameter === "string";
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "parameterName", "typeReference");
}

test "TestQuickInfoDisplayPartsTypeParameterInClass" {
    const content =
        \\class /*1*/c</*2*/T> {
        \\    /*3*/constructor(/*4*/a: /*5*/T) {
        \\    }
        \\    /*6*/method</*7*/U>(/*8*/a: /*9*/U, /*10*/b: /*11*/T) {
        \\        return /*12*/a;
        \\    }
        \\}
        \\var /*13*/cInstance = new /*14*/c("Hello");
        \\var /*15*/cVal = /*16*/c;
        \\/*17*/cInstance./*18*/method("hello", "cello");
        \\class /*19*/c2</*20*/T extends /*21*/c<string>> {
        \\    /*22*/constructor(/*23*/a: /*24*/T) {
        \\    }
        \\    /*25*/method</*26*/U extends /*27*/c<string>>(/*28*/a: /*29*/U, /*30*/b: /*31*/T) {
        \\        return /*32*/a;
        \\    }
        \\}
        \\var /*33*/cInstance1 = new /*34*/c2(/*35*/cInstance);
        \\var /*36*/cVal2 = /*37*/c2;
        \\/*38*/cInstance1./*39*/method(/*40*/cInstance, /*41*/cInstance);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCompletionsImport_tsx" {
    const content =
        \\// @noLib: true
        \\// @jsx: preserve
        \\// @Filename: /a.tsx
        \\export type Bar = 0;
        \\export default function Foo() {};
        \\// @Filename: /b.tsx
        \\<Fo/**/ />;
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
//                     .Label = "Foo",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./a",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//             .Excludes = &.{
//                 "Bar",
//             },
//         },
//     });
}

test "TestGetJavaScriptSyntacticDiagnostics14" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\Foo<number>();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestCompletionListInTypedObjectLiteralsWithPartialPropertyNames2" {
    const content =
        \\interface MyPoint {
        \\    x1: number;
        \\    y1: number;
        \\}
        \\var p15: MyPoint = {
        \\    /**/x1: 0,
        \\};
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
//                 "x1",
//                 "y1",
//             },
//         },
//     });
}

test "TestImportNameCodeFix_externalNonRelative1" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.base.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "commonjs",
        \\    "lib": ["es5"],
        \\    "paths": {
        \\      "pkg-1/*": ["./packages/pkg-1/src/*"],
        \\      "pkg-2/*": ["./packages/pkg-2/src/*"]
        \\    }
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/packages/pkg-1/package.json
        \\{ "dependencies": { "pkg-2": "*" } }
        \\// @Filename: /home/src/workspaces/project/packages/pkg-1/tsconfig.json
        \\{
        \\  "extends": "../../tsconfig.base.json",
        \\  "references": [
        \\    { "path": "../pkg-2" }
        \\  ]
        \\}
        \\// @Filename: /home/src/workspaces/project/packages/pkg-1/src/index.ts
        \\Pkg2/*external*/
        \\// @Filename: /home/src/workspaces/project/packages/pkg-2/package.json
        \\{ "types": "dist/index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/packages/pkg-2/tsconfig.json
        \\{
        \\  "extends": "../../tsconfig.base.json",
        \\  "compilerOptions": { "outDir": "dist", "rootDir": "src", "composite": true, "lib": ["es5"] }
        \\}
        \\// @Filename: /home/src/workspaces/project/packages/pkg-2/src/index.ts
        \\import "./utils";
        \\// @Filename: /home/src/workspaces/project/packages/pkg-2/src/utils.ts
        \\export const Pkg2 = {};
        \\// @Filename: /home/src/workspaces/project/packages/pkg-2/src/blah/foo/data.ts
        \\Pkg2/*internal*/
        \\// @link: /home/src/workspaces/project/packages/pkg-2 -> /home/src/workspaces/project/packages/pkg-1/node_modules/pkg-2
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.GetOptions();
    // f.Configure(undefined, opts1534);
    _ = f.GoToMarker(undefined, "external");
    // f.VerifyImportFixAtPosition(undefined, &.{
//         "import { Pkg2 } from \"pkg-2/utils\";\n\nPkg2",
//     }, &.{.ImportModuleSpecifierPreference = "project-relative"});
    _ = f.GoToMarker(undefined, "internal");
    // f.VerifyImportFixAtPosition(undefined, &.{
//         "import { Pkg2 } from \"../../utils\";\n\nPkg2",
//     }, &.{.ImportModuleSpecifierPreference = "project-relative"});
}

test "TestCompletionsJsdocTypeTagCast" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\const x = /** @type {{ s: string }} */ ({ /**/ });
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
//                 "s",
//                 &.{
//                     .Label =    "x",
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//             },
//         },
//     });
}

test "TestIndexSignatureWithoutAnnotation" {
    const content =
        \\interface B {
        \\    1: any;
        \\}
        \\interface C {
        \\    [s]: any;
        \\}
        \\interface D extends B, C /**/ {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, " ");
}

