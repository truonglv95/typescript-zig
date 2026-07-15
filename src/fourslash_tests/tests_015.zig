const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestImportNameCodeFixExistingImport6" {
    const content =
        \\import [|{ v1 }|] from "fake-module";
        \\f1/*0*/();
        \\// @Filename: ../package.json
        \\{ "dependencies": { "fake-module": "latest" } }
        \\// @Filename: ../node_modules/fake-module/index.ts
        \\export var v1 = 5;
        \\export function f1();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "{ f1, v1 }",
    }, null );
}

test "TestTripleSlashReferenceResolutionMode" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\ { "compilerOptions": { "lib": ["es5"], "module": "nodenext", "declaration": true, "strict": true, "outDir": "out" }, "files": ["./index.ts"] }
        \\// @Filename: /home/src/workspaces/project/package.json
        \\ { "private": true, "type": "commonjs" }
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/package.json
        \\{ "name": "pkg", "version": "0.0.1", "exports": { "require": "./require.cjs", "default": "./import.js" }, "type": "module" }
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/require.d.cts
        \\export {};
        \\export interface PkgRequireInterface { member: any; }
        \\declare global { const pkgRequireGlobal: PkgRequireInterface; }
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/import.d.ts
        \\export {};
        \\export interface PkgImportInterface { field: any; }
        \\declare global { const pkgImportGlobal: PkgImportInterface; }
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\/// <reference types="pkg" resolution-mode="import" />
        \\pkgImportGlobal;
        \\export {};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToFile(undefined, "/home/src/workspaces/project/index.ts");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 0);
}

test "TestGoToDefinitionMultipleDefinitions" {
    const content =
        \\// @Filename: a.ts
        \\interface /*interfaceDefinition1*/IFoo {
        \\    instance1: number;
        \\}
        \\// @Filename: b.ts
        \\interface /*interfaceDefinition2*/IFoo {
        \\    instance2: number;
        \\}
        \\
        \\interface /*interfaceDefinition3*/IFoo {
        \\    instance3: number;
        \\}
        \\
        \\var ifoo: [|IFo/*interfaceReference*/o|];
        \\// @Filename: c.ts
        \\module /*moduleDefinition1*/Module {
        \\    export class c1 { }
        \\}
        \\// @Filename: d.ts
        \\module /*moduleDefinition2*/Module {
        \\    export class c2 { }
        \\}
        \\// @Filename: e.ts
        \\[|Modul/*moduleReference*/e|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "interfaceReference", "moduleReference");
}

test "TestInlayHintsQuotePreference2" {
    const content =
        \\const a1: "'" = "'";
        \\const b1: "\\" = "\\";
        \\export function fn(a = a1, b = b1) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.QuotePreference = lsutil.QuotePreference("single"), .InlayHints = .{.IncludeInlayFunctionParameterTypeHints = core.TSTrue}});
}

test "TestFormattingCrash" {
    const content =
        \\/**/module Default{ 
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts131);
    // f.GetOptions();
    // f.Configure(undefined, opts199);
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyCurrentLineContent(undefined, "module Default");
}

test "TestCodeFixCorrectQualifiedNameToIndexedAccessType01" {
    const content =
        \\export interface Foo {
        \\  bar: string;
        \\}
        \\export const x: [|Foo.bar|] = ""
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "Foo[\"bar\"]", false, 0, 0);
}

test "TestCodeFixMissingTypeAnnotationOnExports57_generics_doesnt_drop_trailing_unknown" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @lib: es2015
        \\
        \\let x: unknown;
        \\export const s = new Set([x]);
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add annotation of type 'Set<unknown>'",
        .NewFileContent = "\nlet x: unknown;\nexport const s: Set<unknown> = new Set([x]);\n",
        .Index = 0,
    });
}

test "TestGoToImplementationInterfaceProperty_01" {
    const content =
        \\interface Foo { hello: number }
        \\
        \\class Bar implements Foo {
        \\    [|hello|] = 5 * 9;
        \\}
        \\
        \\function whatever(foo: Foo) {
        \\    foo.he/*reference*/llo;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "reference");
}

test "TestQuickInfoDisplayPartsTypeAlias" {
    const content =
        \\class /*1*/c {
        \\}
        \\type /*2*/t1 = /*3*/c;
        \\var /*4*/cInstance: /*5*/t1 = new /*6*/c();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCompletionsImport_quoteStyle" {
    const content =
        \\// @module: esnext
        \\// @Filename: /a.ts
        \\export const foo = 0;
        \\// @Filename: /b.ts
        \\fo/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "foo",
//         .Source =      "./a",
//         .Description = "Add import from \"./a\"",
//         .NewFileContent = undefined("import { foo } from './a';\n\nfo"),
//     });
}

test "TestCompletionsRecommended_union" {
    const content =
        \\// @strictNullChecks: true
        \\const enum E { A = "A", B = "B" }
        \\const enum E2 { X = "X", Y = "Y" }
        \\const e: E | undefined = /*a*/
        \\const e2: E | E2 = /*b*/
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
//                     .Label =     "E",
//                     .Preselect = undefined(true),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "b", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =     "E",
//                     .Preselect = undefined(true),
//                 },
//                 &.{
//                     .Label = "E2",
//                 },
//             },
//         },
//     });
}

test "TestSpaceAfterConstructor" {
    const content =
        \\export class myController {
        \\    private _processId;
        \\    constructor (processId: number) {/*1*/
        \\        this._processId = processId;
        \\    }/*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "2");
    _ = f.Insert(undefined, "}");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "    constructor(processId: number) {");
}

test "TestNavbar_let" {
    const content =
        \\let c = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestStringLiteralCompletionsForOpenEndedTemplateLiteralType" {
    const content =
        \\// @stableTypeOrdering: true
        \\function conversionTest(groupName: | "downcast" | "dataDowncast" | "editingDowncast" | 
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
//                 "dataDowncast",
//                 "downcast",
//                 "editingDowncast",
//             },
//         },
//     });
}

test "TestPackageJsonImportsFailedLookups" {
    const content =
        \\// @Filename: /a/b/c/d/e/tsconfig.json
        \\{ "compilerOptions": { "lib": ["es5"], "module": "nodenext" } }
        \\// @Filename: /a/b/c/d/e/package.json
        \\{
        \\  "name": "app",
        \\  "imports": {
        \\    "#utils": "lodash"
        \\  }
        \\}
        \\// @Filename: /a/b/node_modules/lodash/index.d.ts
        \\export function add(a: number, b: number): number;
        \\// @Filename: /a/b/c/d/e/index.ts
        \\import { add } from "#utils";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToFile(undefined, "/a/b/c/d/e/index.ts");
}

test "TestCodeFixMissingTypeAnnotationOnExports58_genercs_doesnt_drop_trailing_unknown_2" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @lib: es2015
        \\
        \\export const s = new Set<unknown>();
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add annotation of type 'Set<unknown>'",
        .NewFileContent = "\nexport const s: Set<unknown> = new Set<unknown>();\n",
        .Index = 0,
    });
}

test "TestQuickInfoOnNarrowedType" {
    const content =
        \\// @strictNullChecks: true
        \\function foo(strOrNum: string | number) {
        \\    if (typeof /*1*/strOrNum === "number") {
        \\        return /*2*/strOrNum;
        \\    }
        \\    else {
        \\        return /*3*/strOrNum.length;
        \\    }
        \\}
        \\function bar() {
        \\   let s: string | undefined;
        \\   /*4*/s;
        \\   /*5*/s = "abc";
        \\   /*6*/s;
        \\}
        \\class Foo {
        \\    #privateProperty: string[] | null;
        \\    constructor() {
        \\        this.#privateProperty = null;
        \\    }
        \\    testMethod() {
        \\        if (this.#privateProperty === null)
        \\            return;
        \\        this./*7*/#privateProperty;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(parameter) strOrNum: string | number", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(parameter) strOrNum: number", "");
    // f.VerifyQuickInfoAt(undefined, "3", "(parameter) strOrNum: string", "");
    // f.VerifyQuickInfoAt(undefined, "4", "let s: string | undefined", "");
    // f.VerifyQuickInfoAt(undefined, "5", "let s: string | undefined", "");
    // f.VerifyQuickInfoAt(undefined, "6", "let s: string", "");
    // f.VerifyQuickInfoAt(undefined, "7", "(property) Foo.#privateProperty: string[]", "");
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
    // f.VerifyCompletions(undefined, &.{"4", "5"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "s",
//                     .Detail = undefined("let s: string | undefined"),
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
//                     .Label =  "s",
//                     .Detail = undefined("let s: string"),
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
//                     .Label =  "#privateProperty",
//                     .Detail = undefined("(property) Foo.#privateProperty: string[]"),
//                 },
//             },
//         },
//     });
}

test "TestGetOccurrencesStringLiterals" {
    const content =
        \\var x = "[|string|]";
        \\function f(a = "[|initial value|]") { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestEditJsdocType" {
    const content =
        \\// @allowJs: true
        \\// @noLib: true
        \\// @Filename: /a.js
        \\/** @type/**/ */
        \\const x = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyQuickInfoIs(undefined, "", "");
    _ = f.Insert(undefined, " ");
    _ = f.VerifyQuickInfoIs(undefined, "", "");
}

test "TestAutoImportPackageJsonImportsPattern_ts" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#*": "./src/*.ts"
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

test "TestRenameReferenceFromLinkTag1" {
    const content =
        \\enum E {
        \\    /** {@link /**/A} */
        \\    A
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , "");
}

test "TestCodeFixClassImplementInterfaceCallback" {
    const content =
        \\interface IFoo1 {
        \\    parse(reviver: () => any): void;
        \\}
        \\
        \\class Foo1 implements IFoo1 {
        \\}
        \\
        \\interface IFoo2 {
        \\    parse(reviver: { (): any }): void;
        \\}
        \\
        \\class Foo2 implements IFoo2 {
        \\}
        \\
        \\interface IFoo3 {
        \\    parse(reviver: new () => any): void;
        \\}
        \\
        \\class Foo3 implements IFoo3 {
        \\}
        \\
        \\interface IFoo4 {
        \\    parse(reviver: { new (): any }): void;
        \\}
        \\
        \\class Foo4 implements IFoo4 {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixAll(undefined, .{
//         .FixID = "fixClassIncorrectlyImplementsInterface",
//         .NewFileContent = "interface IFoo1 {\n    parse(reviver: () => any): void;\n}\n\nclass Foo1 implements IFoo1 {\n    parse(reviver: () => any): void {\n        throw new Error(\"Method not implemented.\");\n    }\n}\n\ninterface IFoo2 {\n    parse(reviver: { (): any }): void;\n}\n\nclass Foo2 implements IFoo2 {\n    parse(reviver: { (): any; }): void {\n        throw new Error(\"Method not implemented.\");\n    }\n}\n\ninterface IFoo3 {\n    parse(reviver: new () => any): void;\n}\n\nclass Foo3 implements IFoo3 {\n    parse(reviver: new () => any): void {\n        throw new Error(\"Method not implemented.\");\n    }\n}\n\ninterface IFoo4 {\n    parse(reviver: { new (): any }): void;\n}\n\nclass Foo4 implements IFoo4 {\n    parse(reviver: { new(): any; }): void {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
//     });
}

test "TestRefactorConvertToEsModule_module_node12" {
    const content =
        \\// @allowJs: true
        \\// @target: esnext
        \\// @module: node16
        \\// @Filename: /a.js
        \\module.exports = 0;
        \\// @Filename: /b.ts
        \\module.exports = 0;
        \\// @Filename: /c.cjs
        \\module.exports = 0;
        \\// @Filename: /d.cts
        \\module.exports = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.js");
    // f.VerifyCodeFixNotAvailable(undefined);
    _ = f.GoToFile(undefined, "/b.ts");
    // f.VerifyCodeFixNotAvailable(undefined);
    _ = f.GoToFile(undefined, "/c.cjs");
    // f.VerifyCodeFixNotAvailable(undefined);
    _ = f.GoToFile(undefined, "/d.cts");
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestImportNameCodeFixNewImportAllowSyntheticDefaultImports2" {
    const content =
        \\// @AllowSyntheticDefaultImports: false
        \\// @Module: system
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
        "import * as bar from \"./foo\";\n\nexport var x = 0;\nbar();",
    }, null );
}

test "TestForwardReference" {
    const content =
        \\function f() {
        \\    var x = new t();
        \\    x./**/
        \\}
        \\class t {
        \\    public n: number;
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
//                 "n",
//             },
//         },
//     });
}

test "TestRenameInheritedProperties4" {
    const content =
        \\interface interface1 extends interface1 {
        \\   [|[|{| "contextRangeIndex": 0 |}doStuff|](): string;|]
        \\}
        \\
        \\var v: interface1;
        \\v.[|doStuff|]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "doStuff");
}

test "TestGotoDefinitionThrowsTag" {
    const content =
        \\class [|/*def*/E|] extends Error {}
        \\
        \\/**
        \\ * @throws {/*use*/[|E|]}
        \\ */
        \\function f() {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, false, "use");
}

test "TestTsxFindAllReferences7" {
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
        \\interface OptionPropBag {
        \\    /*1*/propx: number
        \\    propString: string
        \\    optional?: boolean
        \\}
        \\declare function Opt(attributes: OptionPropBag): JSX.Element;
        \\let opt = <Opt />;
        \\let opt1 = <Opt propx={100} propString />;
        \\let opt2 = <Opt propx={100} optional/>;
        \\let opt3 = <Opt wrong />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestCompletionsImportDeclarationAttributesErrorModuleSpecifier1" {
    const content =
        \\// @strict: true
        \\// @filename: global.d.ts
        \\interface ImportAttributes { 
        \\  type: "json";
        \\}
        \\// @filename: index.ts
        \\import * as ns from () with { type: "/**/" };
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

test "TestCompletionForStringLiteral_quotePreference1" {
    const content =
        \\enum A {
        \\    A,
        \\    B,
        \\    C
        \\}
        \\interface B {
        \\    a: keyof typeof A;
        \\}
        \\const b: B = {
        \\    a: /**/
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
//                     .Label = "\"A\"",
//                 },
//                 &.{
//                     .Label = "\"B\"",
//                 },
//                 &.{
//                     .Label = "\"C\"",
//                 },
//             },
//         },
//         .UserPreferences = &.{.QuotePreference = lsutil.QuotePreference("double")},
//     });
}

test "TestCallHierarchyClassPropertyArrowFunction" {
    const content =
        \\class C {
        \\    caller = () => {
        \\        this.callee();
        \\    }
        \\
        \\    /**/callee = () => {
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyBaselineCallHierarchy(undefined);
}

test "TestSmartSelection_JSDocTags9" {
    const content =
        \\/** @enum {/**/number} */
        \\const Foo = {
        \\    x: 0,
        \\    y: 1,
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSelectionRanges(undefined);
}

test "TestQuickInfoForContextuallyTypedFunctionInReturnStatement" {
    const content =
        \\interface Accumulator {
        \\    clear(): void;
        \\    add(x: number): void;
        \\    result(): number;
        \\}
        \\
        \\function makeAccumulator(): Accumulator {
        \\    var sum = 0;
        \\    return {
        \\        clear: function () { sum = 0; },
        \\        add: function (val/**/ue) { sum += value; },
        \\        result: function () { return sum; }
        \\    };
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "(parameter) value: number", "");
}

test "TestJsDocFunctionSignatures4" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\/** @param {function ({OwnerID:string,AwayID:string}):void} x
        \\  * @param {function (string):void} y */
        \\function fn(x, y) { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
}

test "TestImportNameCodeFix_jsCJSvsESM3" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: types/dep.d.ts
        \\export declare class Dep {}
        \\// @Filename: index.js
        \\import fs from 'fs';
        \\const path = require('path');
        \\
        \\Dep/**/
        \\// @Filename: util2.js
        \\export {};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import fs from 'fs';\nimport { Dep } from './types/dep';\nconst path = require('path');\n\nDep",
    }, null );
}

test "TestGetOutliningForObjectsInArray" {
    const content =
        \\const x =[| [
        \\    [|{ a: 0 }|],
        \\    [|{ b: 1 }|],
        \\    [|{ c: 2 }|]
        \\]|];
        \\
        \\const y =[| [
        \\    [|{
        \\        a: 0
        \\    }|],
        \\    [|{
        \\        b: 1
        \\    }|],
        \\    [|{
        \\        c: 2
        \\    }|]
        \\]|];
        \\
        \\const w =[| [
        \\    [|[ 0 ]|],
        \\    [|[ 1 ]|],
        \\    [|[ 2 ]|]
        \\]|];
        \\
        \\const z =[| [
        \\    [|[
        \\        0
        \\    ]|],
        \\    [|[
        \\        1
        \\    ]|],
        \\    [|[
        \\        2
        \\    ]|]
        \\]|];
        \\
        \\const z =[| [
        \\    [|[
        \\        [|{ hello: 0 }|]
        \\    ]|],
        \\    [|[
        \\        [|{ hello: 3 }|]
        \\    ]|],
        \\    [|[
        \\        [|{ hello: 5 }|],
        \\        [|{ hello: 7 }|]
        \\    ]|]
        \\]|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOutliningSpans(undefined);
}

test "TestCompletionsClassMemberImportTypeNodeParameter1" {
    const content =
        \\// @module: node18
        \\// @Filename: /generation.d.ts
        \\export type GenerationConfigType = { max_length?: number };
        \\// @FileName: /index.d.ts
        \\export declare class PreTrainedModel {
        \\  _get_generation_config(
        \\    param: import("./generation.js").GenerationConfigType,
        \\  ): import("./generation.js").GenerationConfigType;
        \\}
        \\
        \\export declare class BlenderbotSmallPreTrainedModel extends PreTrainedModel {
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
//                     .Label =               "_get_generation_config",
//                     .InsertText =          undefined("_get_generation_config(param: import(\"./generation.js\").GenerationConfigType): import(\"./generation.js\").GenerationConfigType;"),
//                     .FilterText =          undefined("_get_generation_config"),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                 },
//             },
//         },
//     });
}

test "TestGenericTypeWithMultipleBases1MultiFile" {
    const content =
        \\// @Filename: genericTypeWithMultipleBases_0.ts
        \\interface iBaseScope {
        \\    watch: () => void;
        \\}
        \\// @Filename: genericTypeWithMultipleBases_1.ts
        \\interface iMover {
        \\    moveUp: () => void;
        \\}
        \\// @Filename: genericTypeWithMultipleBases_2.ts
        \\interface iScope<TModel> extends iBaseScope, iMover {
        \\    family: TModel;
        \\}
        \\// @Filename: genericTypeWithMultipleBases_3.ts
        \\var x: iScope<number>;
        \\// @Filename: genericTypeWithMultipleBases_4.ts
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
//             .Includes = &.{
//                 &.{
//                     .Label =  "watch",
//                     .Detail = undefined("(property) iBaseScope.watch: () => void"),
//                 },
//                 &.{
//                     .Label =  "moveUp",
//                     .Detail = undefined("(property) iMover.moveUp: () => void"),
//                 },
//                 &.{
//                     .Label =  "family",
//                     .Detail = undefined("(property) iScope<number>.family: number"),
//                 },
//             },
//         },
//     });
}

test "TestMemberListInFunctionCall2" {
    const content =
        \\type T = {
        \\    a: 1;
        \\    b: 2;
        \\}
        \\function F(x: T) {
        \\}
        \\F({/*1*/} as const)
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
//                     .Label =  "a",
//                     .Detail = undefined("(property) a: 1"),
//                 },
//                 &.{
//                     .Label =  "b",
//                     .Detail = undefined("(property) b: 2"),
//                 },
//             },
//         },
//     });
}

test "TestFormattingForLoopSemicolons" {
    const content =
        \\/*1*/for (;;) { }
        \\/*2*/for (var x;x<0;x++) { }
        \\/*3*/for (var x ;x<0 ;x++) { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "for (; ;) { }");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "for (var x; x < 0; x++) { }");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "for (var x; x < 0; x++) { }");
    // f.GetOptions();
    // f.Configure(undefined, opts444);
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "for (;;) { }");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "for (var x;x < 0;x++) { }");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "for (var x;x < 0;x++) { }");
}

test "TestCodeFixTopLevelForAwait_target_noTsConfig" {
    const content =
        \\// @filename: /dir/a.ts
        \\declare const p: number[];
        \\for await (const _ of p);
        \\export {};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestAutoImportProvider_wildcardExports1" {
    const content =
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/package.json
        \\{
        \\    "name": "pkg",
        \\    "version": "1.0.0",
        \\    "exports": {
        \\        "./*": "./a/*.js",
        \\        "./b/*.js": "./b/*.js",
        \\        "./c/*": "./c/*",
        \\        "./d/*": {
        \\            "import": "./d/*.mjs"
        \\        }
        \\    }
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/a/a1.d.ts
        \\export const a1: number;
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/b/b1.d.ts
        \\export const b1: number;
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/b/b2.d.mts
        \\export const NOT_REACHABLE: number;
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/c/c1.d.ts
        \\export const c1: number;
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/c/subfolder/c2.d.mts
        \\export const c2: number;
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/d/d1.d.mts
        \\export const d1: number;
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
//                     .Label = "a1",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "pkg/a1",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//                 &.{
//                     .Label = "b1",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "pkg/b/b1.js",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//                 &.{
//                     .Label = "c1",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "pkg/c/c1.js",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//                 &.{
//                     .Label = "c2",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "pkg/c/subfolder/c2.mjs",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//                 &.{
//                     .Label = "d1",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "pkg/d/d1",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//             .Excludes = &.{
//                 "NOT_REACHABLE",
//             },
//         },
//     });
}

test "TestWhiteSpaceBeforeReturnTypeFormatting" {
    const content =
        \\var x: () =>     string/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, ";");
    _ = f.VerifyCurrentLineContent(undefined, "var x: () => string;");
}

test "TestReferencesForLabel2" {
    const content =
        \\var label = "label";
        \\while (true) {
        \\    if (false) break /**/label;
        \\    if (true) continue label;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestTsxIncrementalServer" {
    const content =
        \\// @lib: es5
        \\/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "<");
    _ = f.Insert(undefined, "div");
    _ = f.Insert(undefined, " ");
    _ = f.Insert(undefined, " id");
    _ = f.Insert(undefined, "=");
    _ = f.Insert(undefined, "\"foo");
    _ = f.Insert(undefined, "\"");
    _ = f.Insert(undefined, ">");
}

test "TestQuickInfoOnUndefined" {
    const content =
        \\function foo(a: string) {
        \\}
        \\foo(/*1*/undefined);
        \\var x = {
        \\    undefined: 10
        \\};
        \\x./*2*/undefined = 30;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var undefined", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(property) undefined: number", "");
}

test "TestRenameReferenceFromLinkTag4" {
    const content =
        \\enum E {
        \\    /** {@link /**/B} */
        \\    A,
        \\    B
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , "");
}

test "TestCodeFixExpectedComma03" {
    const content =
        \\class C {
        \\    const example = [|{ one: 1 one }|]
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined, "fixExpectedComma");
}

test "TestJsDocDontBreakWithNamespaces" {
    const content =
        \\// @allowJs: true
        \\// @Filename: jsDocDontBreakWithNamespaces.js
        \\/**
        \\ * @returns {module:@nodefuel/web~Webserver~wsServer#hello} Websocket server object
        \\ */
        \\function foo() { }
        \\foo(''/*foo*/);
        \\
        \\/**
        \\ * @type {module:xxxxx} */
        \\ */
        \\function bar() { }
        \\bar(''/*bar*/);
        \\
        \\/** @type {function(module:xxxx, module:xxxx): module:xxxxx} */
        \\function zee() { }
        \\zee(''/*zee*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSignatureHelp(undefined);
}

test "TestCallHierarchyFunctionAmbiguity4" {
    const content =
        \\// @filename: a.d.ts
        \\declare function foo(x?: number): void;
        \\// @filename: b.d.ts
        \\declare function foo(x?: string): void;
        \\declare function /**/foo(x?: boolean): void;
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

test "TestGoToDefinitionPrimitives" {
    const content =
        \\var x: st/*primitive*/ring;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "primitive");
}

test "TestFindAllRefsForStringLiteral" {
    const content =
        \\// @filename: /a.ts
        \\interface Foo {
        \\    property: /**/"foo";
        \\}
        \\/**
        \\ * @type {{ property: "foo"}}
        \\ */
        \\const obj: Foo = {
        \\    property: "foo",
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestCodeFixClassImplementInterface_noUndefinedOnOptionalParameter" {
    const content =
        \\interface IFoo {
        \\    bar(x?: number | string): void;
        \\}
        \\
        \\class Foo implements IFoo {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'IFoo'",
        .NewFileContent = "interface IFoo {\n    bar(x?: number | string): void;\n}\n\nclass Foo implements IFoo {\n    bar(x?: number | string): void {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestCompletionsInterfaceElement" {
    const content =
        \\const foo = 0;
        \\interface I {
        \\    m(): void;
        \\    fo/*i*/
        \\}
        \\interface J { /*j*/ }
        \\interface K { f; /*k*/ }
        \\type T = { fo/*t*/ };
        \\type U = { /*u*/ };
        \\interface EndOfFile { f; /*e*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, f.Markers(), &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =    "readonly",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestQuickInfoOnGenericWithConstraints1" {
    const content =
        \\interface Fo/*1*/o<T/*2*/T extends Date> {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "interface Foo<TT extends Date>", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(type parameter) TT in Foo<TT extends Date>", "");
}

test "TestRenameImportOfExportEquals" {
    const content =
        \\[|declare namespace /*N*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 0 |}N|] {
        \\    [|export var /*x*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 2 |}x|]: number;|]
        \\}|]
        \\declare module "mod" {
        \\    [|export = [|{| "contextRangeIndex": 4 |}N|];|]
        \\}
        \\declare module "a" {
        \\    [|import * as /*a*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 6 |}N|] from "mod";|]
        \\    [|export { [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 8 |}N|] };|] // Renaming N here would rename
        \\}
        \\declare module "b" {
        \\    [|import { /*b*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 10 |}N|] } from "a";|]
        \\    export const y: typeof [|N|].[|x|];
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "N", "a", "b", "x");
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[5]);
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[7]);
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[9]);
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[11], f.Ranges()[12]);
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[3], f.Ranges()[13]);
}

test "TestImportFixesGlobalTypingsCache" {
    const content =
        \\// @Filename: /project/tsconfig.json
        \\ { "compilerOptions": { "allowJs": true, "checkJs": true, "module": "commonjs" } }
        \\// @Filename: /home/src/Library/Caches/typescript/node_modules/@types/react-router-dom/package.json
        \\ { "name": "@types/react-router-dom", "version": "16.8.4", "types": "index.d.ts" }
        \\// @Filename: /home/src/Library/Caches/typescript/node_modules/@types/react-router-dom/index.d.ts
        \\export class BrowserRouter {}
        \\// @Filename: /project/node_modules/react-router-dom/package.json
        \\ { "name": "react-router-dom", "version": "16.8.4", "main": "index.js" }
        \\// @Filename: /project/node_modules/react-router-dom/index.js
        \\ export const BrowserRouter = () => null;
        \\// @Filename: /project/index.js
        \\BrowserRouter/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/project/index.js");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "const { BrowserRouter } = require(\"react-router-dom\");\n\nBrowserRouter",
    }, null );
}

test "TestProtoVarInContextualObjectLiteral" {
    const content =
        \\var o1 : {
        \\    __proto__: number;
        \\    p: number;
        \\} = {
        \\        /*1*/
        \\    };
        \\var o2: {
        \\    __proto__: number;
        \\    p: number;
        \\} = {
        \\        /*2*/
        \\    };
        \\var o3: {
        \\    "__proto__": number;
        \\    p: number;
        \\} = {
        \\        /*3*/
        \\    };
        \\var o4: {
        \\    "__proto__": number;
        \\    p: number;
        \\} = {
        \\        /*4*/
        \\    };
        \\var o5: {
        \\    __proto__: number;
        \\    ___proto__: string;
        \\    p: number;
        \\} = {
        \\        /*5*/
        \\    };
        \\var o6: {
        \\    __proto__: number;
        \\    ___proto__: string;
        \\    p: number;
        \\} = {
        \\        /*6*/
        \\    };
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
//                 &.{
//                     .Label =  "__proto__",
//                     .Detail = undefined("(property) __proto__: number"),
//                 },
//                 &.{
//                     .Label =  "p",
//                     .Detail = undefined("(property) p: number"),
//                 },
//             },
//         },
//     });
    _ = f.Insert(undefined, "__proto__: 10,");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "p",
//                     .Detail = undefined("(property) p: number"),
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
//             .Unsorted = &.{
//                 &.{
//                     .Label =  "__proto__",
//                     .Detail = undefined("(property) __proto__: number"),
//                 },
//                 &.{
//                     .Label =  "p",
//                     .Detail = undefined("(property) p: number"),
//                 },
//             },
//         },
//     });
    _ = f.Insert(undefined, "\"__proto__\": 10,");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "p",
//                     .Detail = undefined("(property) p: number"),
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
//             .Unsorted = &.{
//                 &.{
//                     .Label =  "__proto__",
//                     .Detail = undefined("(property) \"__proto__\": number"),
//                 },
//                 &.{
//                     .Label =  "p",
//                     .Detail = undefined("(property) p: number"),
//                 },
//             },
//         },
//     });
    _ = f.Insert(undefined, "__proto__: 10,");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "p",
//                     .Detail = undefined("(property) p: number"),
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
//             .Unsorted = &.{
//                 &.{
//                     .Label =  "__proto__",
//                     .Detail = undefined("(property) \"__proto__\": number"),
//                 },
//                 &.{
//                     .Label =  "p",
//                     .Detail = undefined("(property) p: number"),
//                 },
//             },
//         },
//     });
    _ = f.Insert(undefined, "\"__proto__\": 10,");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "p",
//                     .Detail = undefined("(property) p: number"),
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
//             .Unsorted = &.{
//                 &.{
//                     .Label =  "__proto__",
//                     .Detail = undefined("(property) __proto__: number"),
//                 },
//                 &.{
//                     .Label =  "___proto__",
//                     .Detail = undefined("(property) ___proto__: string"),
//                 },
//                 &.{
//                     .Label =  "p",
//                     .Detail = undefined("(property) p: number"),
//                 },
//             },
//         },
//     });
    _ = f.Insert(undefined, "__proto__: 10,");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 &.{
//                     .Label =  "___proto__",
//                     .Detail = undefined("(property) ___proto__: string"),
//                 },
//                 &.{
//                     .Label =  "p",
//                     .Detail = undefined("(property) p: number"),
//                 },
//             },
//         },
//     });
    _ = f.Insert(undefined, "\"___proto__\": \"10\",");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "p",
//                     .Detail = undefined("(property) p: number"),
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
//             .Unsorted = &.{
//                 &.{
//                     .Label =  "__proto__",
//                     .Detail = undefined("(property) __proto__: number"),
//                 },
//                 &.{
//                     .Label =  "___proto__",
//                     .Detail = undefined("(property) ___proto__: string"),
//                 },
//                 &.{
//                     .Label =  "p",
//                     .Detail = undefined("(property) p: number"),
//                 },
//             },
//         },
//     });
    _ = f.Insert(undefined, "___proto__: \"10\",");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 &.{
//                     .Label =  "__proto__",
//                     .Detail = undefined("(property) __proto__: number"),
//                 },
//                 &.{
//                     .Label =  "p",
//                     .Detail = undefined("(property) p: number"),
//                 },
//             },
//         },
//     });
    _ = f.Insert(undefined, "\"__proto__\": 10,");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "p",
//                     .Detail = undefined("(property) p: number"),
//                 },
//             },
//         },
//     });
}

test "TestGetOccurrencesProtected2" {
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
        \\        export class C2 {
        \\            public pub1;
        \\            private priv1;
        \\            [|protected|] prot1;
        \\
        \\            [|protected|] constructor(public public, [|protected|] protected, private private) {
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

test "TestCloduleAsBaseClass2" {
    const content =
        \\// @module: commonjs
        \\// @strict: false
        \\// @Filename: cloduleAsBaseClass2_0.ts
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
        \\export = A;
        \\// @Filename: cloduleAsBaseClass2_1.ts
        \\import B = require('./cloduleAsBaseClass2_0');
        \\class D extends B {
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
//             .Includes = &.{
//                 &.{
//                     .Label =    "bar",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//                 &.{
//                     .Label =    "bar2",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//                 &.{
//                     .Label =    "baz",
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//                 &.{
//                     .Label =    "x",
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//             },
//             .Excludes = &.{
//                 "foo",
//                 "foo2",
//             },
//         },
//     });
    _ = f.Insert(undefined, "bar()");
    _ = f.VerifyNoErrors(undefined);
}

test "TestQuickInfoOnVarInArrowExpression" {
    const content =
        \\interface IMap<T> {
        \\    [key: string]: T;
        \\}
        \\var map: IMap<string[]>;
        \\var categories: string[];
        \\each(categories, category => {
        \\    var /*1*/changes = map[category];
        \\    return each(changes, change => {
        \\    });
        \\});
        \\function each<T>(items: T[], handler: (item: T) => void) { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(local var) changes: string[]", "");
}

test "TestQuickInfoOnPropertyAccessInWriteLocation3" {
    const content =
        \\// @strict: true
        \\// @exactOptionalPropertyTypes: true
        \\declare const xx: { prop?: number };
        \\xx.prop/*1*/ ??= 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(property) prop?: number", "");
}

test "TestFindAllRefsInheritedProperties5" {
    const content =
        \\class C extends D {
        \\    /*0*/prop0: string;
        \\    /*1*/prop1: number;
        \\}
        \\
        \\class D extends C {
        \\    /*2*/prop0: string;
        \\}
        \\
        \\var d: D;
        \\d./*3*/prop0;
        \\d./*4*/prop1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2", "3", "4");
}

test "TestSmartSelection_comment2" {
    const content =
        \\const a = 1; //a b/**/c d
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSelectionRanges(undefined);
}

test "TestQuickInfoDisplayPartsEnum1" {
    const content =
        \\enum /*1*/E {
        \\    /*2*/e1,
        \\    /*3*/e2 = 10,
        \\    /*4*/e3
        \\}
        \\var /*5*/eInstance: /*6*/E;
        \\/*7*/eInstance = /*8*/E./*9*/e1;
        \\/*10*/eInstance = /*11*/E./*12*/e2;
        \\/*13*/eInstance = /*14*/E./*15*/e3;
        \\const enum /*16*/constE {
        \\    /*17*/e1,
        \\    /*18*/e2 = 10,
        \\    /*19*/e3
        \\}
        \\var /*20*/eInstance1: /*21*/constE;
        \\/*22*/eInstance1 = /*23*/constE./*24*/e1;
        \\/*25*/eInstance1 = /*26*/constE./*27*/e2;
        \\/*28*/eInstance1 = /*29*/constE./*30*/e3;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCompletionListInTypedObjectLiterals2" {
    const content =
        \\interface Foo {
        \\    x: { a: number };
        \\}
        \\var aaa: Foo;
        \\aaa = { /*9*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "9", &.{
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

test "TestOrganizeImports19" {
    const content =
        \\const a = 1;
        \\export { a };
        \\
        \\const b = 1;
        \\export { b };
        \\
        \\const c = 1;
        \\export { c };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(undefined,
//         "const a = 1;\nexport { a };\n\nconst b = 1;\nexport { b };\n\nconst c = 1;\nexport { c };\n",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestQuickInfoDisplayPartsInterfaceMembers" {
    const content =
        \\interface I {
        \\    /*1*/property: string;
        \\    /*2*/method(): string;
        \\    (): string;
        \\    new (): I;
        \\}
        \\var iInstance: I;
        \\/*3*/iInstance./*4*/property = /*5*/iInstance./*6*/method();
        \\/*7*/iInstance();
        \\var /*8*/anotherInstance = new /*9*/iInstance();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestReferencesForPropertiesOfGenericType" {
    const content =
        \\interface IFoo<T> {
        \\    /*1*/doSomething(v: T): T;
        \\}
        \\
        \\var x: IFoo<string>;
        \\x./*2*/doSomething("ss");
        \\
        \\var y: IFoo<number>;
        \\y./*3*/doSomething(12);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestQuickInfoOnThis5" {
    const content =
        \\// @noImplicitThis: true
        \\const foo = {
        \\    num: 0,
        \\    f() {
        \\        type Y = typeof th/*1*/is;
        \\        type Z = typeof th/*2*/is.num;
        \\    },
        \\    g(this: number) {
        \\        type X = typeof th/*3*/is;
        \\    }
        \\}
        \\class Foo {
        \\    num = 0;
        \\    f() {
        \\        type Y = typeof th/*4*/is;
        \\        type Z = typeof th/*5*/is.num;
        \\    }
        \\    g(this: number) {
        \\        type X = typeof th/*6*/is;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestRenameImportAndShorthand" {
    const content =
        \\[|import [|{| "contextRangeIndex": 0 |}foo|] from 'bar';|]
        \\const bar = { [|foo|] };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[2]);
}

test "TestAutoImportFileExcludePatterns3" {
    const content =
        \\// @lib: es5
        \\// @module: commonjs
        \\// @Filename: /ambient1.d.ts
        \\declare module "foo" {
        \\   export const x = 1;
        \\}
        \\// @Filename: /ambient2.d.ts
        \\declare module "foo" {
        \\   export const y = 2;
        \\}
        \\// @Filename: /index.ts
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
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     &.{
//                         .Label = "x",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "foo",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                     &.{
//                         .Label = "y",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "foo",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                 }, false,
//             ),
//         },
//         .UserPreferences = &.{.AutoImportFileExcludePatterns = &.{"/**/ambient1.d.ts"}},
//     });
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobals,
//         },
//         .UserPreferences = &.{.AutoImportFileExcludePatterns = &.{"/**/ambient*"}},
//     });
}

test "TestFormattingMultilineTemplateLiterals" {
    const content =
        \\/*1*/new Error(
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "new Error(`Failed to expand glob: ${projectSpec.filesGlob}");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "                at projectPath : ${projectFile}");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "                with error: ${ex.message}`)");
}

test "TestInlayHintsInteractiveReturnType" {
    const content =
        \\function foo1 () {
        \\    return 1
        \\}
        \\function foo2 (): number {
        \\    return 1
        \\}
        \\class C {
        \\    foo() {
        \\        return 1
        \\    }
        \\    bar() {
        \\        return this
        \\    }
        \\}
        \\const a = () => 1
        \\const b = function () { return 1 }
        \\const c = (b) => 1
        \\const d = b => 1
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayFunctionLikeReturnTypeHints = core.TSTrue}});
}

test "TestCompletionListAfterStringLiteral1" {
    const content =
        \\// @lib: es5
        \\"a"./**/
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
//                 "toString",
//                 "charAt",
//                 "charCodeAt",
//                 "concat",
//                 "indexOf",
//                 "lastIndexOf",
//                 "localeCompare",
//                 "match",
//                 "replace",
//                 "search",
//                 "slice",
//                 "split",
//                 "substring",
//                 "toLowerCase",
//                 "toLocaleLowerCase",
//                 "toUpperCase",
//                 "toLocaleUpperCase",
//                 "trim",
//                 "length",
//                 &.{
//                     .Label =    "substr",
//                     .SortText = undefined(string(ls.DeprecateSortText(ls.SortTextLocationPriority))),
//                     .Tags =     &&.{lsproto.CompletionItemTagDeprecated},
//                 },
//                 "valueOf",
//             },
//         },
//     });
}

test "TestDocumentHighlightsInvalidGlobalThis" {
    const content =
        \\declare global {
        \\    export { globalThis as [|global|] }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestGetRenameInfoTests2" {
    const content =
        \\class C /**/extends null {
        \\
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyRenameFailed(undefined, null );
}

test "TestQuickInfoLink4" {
    const content =
        \\type A = 1 | 2;
        \\
        \\switch (0 as A) {
        \\    /** {@link /**/A} */
        \\    case 1:
        \\    case 2:
        \\    break;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    _ = f.VerifyBaselineHover(undefined);
}

test "TestJavascriptModules23" {
    const content =
        \\// @Filename: mod.ts
        \\var foo = {a: "test"};
        \\export = foo;
        \\// @Filename: app.ts
        \\import {a} from "./mod"
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
//                 "toString",
//             },
//         },
//     });
}

test "TestFindAllRefsUnresolvedSymbols1" {
    const content =
        \\let a: /*a0*/Bar;
        \\let b: /*a1*/Bar<string>;
        \\let c: /*a2*/Bar<string, number>;
        \\let d: /*b0*/Bar./*c0*/X;
        \\let e: /*b1*/Bar./*c1*/X<string>;
        \\let f: /*b2*/Bar./*d0*/X./*e0*/Y;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "a0", "a1", "a2", "b0", "b1", "b2", "c0", "c1", "d0", "e0");
}

test "TestSignatureHelpLeadingRestTuple" {
    const content =
        \\export function leading(...args: [...names: string[], allCaps: boolean]): void {
        \\}
        \\
        \\leading(/*1*/);
        \\leading("ok", /*2*/);
        \\leading("ok", "ok", /*3*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifySignatureHelp(undefined, .{.Text = "leading(...names: string[], allCaps: boolean): void", .ParameterCount = 2, .OverloadsCount = 1, .IsVariadic = true, .IsVariadicSet = true});
    _ = f.GoToMarker(undefined, "2");
    // f.VerifySignatureHelp(undefined, .{.Text = "leading(...names: string[], allCaps: boolean): void", .ParameterCount = 2, .OverloadsCount = 1, .IsVariadic = true, .IsVariadicSet = true});
    _ = f.GoToMarker(undefined, "3");
    // f.VerifySignatureHelp(undefined, .{.Text = "leading(...names: string[], allCaps: boolean): void", .ParameterCount = 2, .OverloadsCount = 1, .IsVariadic = true, .IsVariadicSet = true});
}

test "TestGoToDefinitionImportedNames2" {
    const content =
        \\// @Filename: b.ts
        \\import {[|/*classAliasDefinition*/Class|]} from "./a";
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

test "TestDocCommentTemplateEmptyFile" {
    const content =
        \\// @Filename: emptyFile.ts
        \\/*0*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyNoJSDocCompletion(undefined, "0");
}

test "TestUnusedFunctionInNamespace2" {
    const content =
        \\// @noUnusedLocals: true
        \\ [| namespace greeter {
        \\    export function function2() {
        \\    }
        \\    function function1() {
        \\    }
        \\} |]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "namespace greeter {\n    export function function2() {\n    }\n}", false, 0, 0);
}

test "TestCompletionForStringLiteral11" {
    const content =
        \\// @stableTypeOrdering: true
        \\type As = 'arf' | 'abacus' | 'abaddon';
        \\let a: As;
        \\switch (a) {
        \\    case '[|/**/|]
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
//                 "abacus",
//                 "abaddon",
//                 "arf",
//             },
//         },
//     });
}

test "TestJsdocDeprecated_suggestion21" {
    const content =
        \\// @module: esnext
        \\// @filename: /a.ts
        \\export const a = 1;
        \\export const b = 1;
        \\// @filename: /b.ts
        \\export {
        \\    /** @deprecated a is deprecated */
        \\    a
        \\} from "./a";
        \\// @filename: /c.ts
        \\export {
        \\    a
        \\} from "./b";
        \\// @filename: /d.ts
        \\import * as _ from "./c";
        \\_.[|a|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/d.ts");
    // f.VerifySuggestionDiagnostics(undefined, []*.{
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'a' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[0].LSRange,
//         },
//     });
}

test "TestInlayHintsPropertyDeclarations2" {
    const content =
        \\// @strict: true
        \\// @target: esnext
        \\class C {
        \\    accessor a = 1
        \\    accessor b: number = 2
        \\    accessor c;
        \\    accessor d;
        \\
        \\    constructor(value: number) {
        \\        this.d = value;
        \\        if (value <= 0) {
        \\            this.d = null;
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayPropertyDeclarationTypeHints = core.TSTrue}});
}

test "TestMemberListAfterSingleDot" {
    const content =
        \\./**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "", null);
}

test "TestFindAllRefsModuleAugmentation" {
    const content =
        \\// @Filename: /node_modules/foo/index.d.ts
        \\/*1*/export type /*2*/T = number;
        \\// @Filename: /a.ts
        \\import * as foo from "foo";
        \\declare module "foo" {
        \\    export const x: /*3*/T;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestImportCompletionsPackageJsonImportsPattern_capsInPath1" {
    const content =
        \\// @module: node18
        \\// @Filename: /Dev/package.json
        \\{
        \\  "imports": {
        \\    "#thing": "./src/something.js"
        \\  }
        \\}
        \\// @Filename: /Dev/src/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /Dev/a.ts
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
//                 "#thing",
//             },
//         },
//     });
}

test "TestFormattingOnNestedDoWhileByEnter" {
    const content =
        \\/*2*/do{
        \\/*3*/do/*1*/{
        \\/*4*/do{
        \\/*5*/}while(a!==b)
        \\/*6*/}while(a!==b)
        \\/*7*/}while(a!==b)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "\n");
    _ = f.VerifyCurrentLineContent(undefined, "    {");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "do{");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "    do");
    _ = f.GoToMarker(undefined, "4");
    _ = f.VerifyCurrentLineContent(undefined, "do{");
    _ = f.GoToMarker(undefined, "5");
    _ = f.VerifyCurrentLineContent(undefined, "}while(a!==b)");
    _ = f.GoToMarker(undefined, "6");
    _ = f.VerifyCurrentLineContent(undefined, "}while(a!==b)");
    _ = f.GoToMarker(undefined, "7");
    _ = f.VerifyCurrentLineContent(undefined, "}while(a!==b)");
}

test "TestCodeFixInferFromUsageCall" {
    const content =
        \\// @noImplicitAny: true
        \\function wat([|b |]) {
        \\    b();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "b: () => void", false, 0, 0);
}

test "TestQuickInfoDisplayPartsExternalModules" {
    const content =
        \\export namespace /*1*/m {
        \\    var /*2*/namespaceElemWithoutExport = 10;
        \\    export var /*3*/namespaceElemWithExport = 10;
        \\}
        \\export var /*4*/a = /*5*/m;
        \\export var /*6*/b: typeof /*7*/m;
        \\export namespace /*8*/m1./*9*/m2 {
        \\    var /*10*/namespaceElemWithoutExport = 10;
        \\    export var /*11*/namespaceElemWithExport = 10;
        \\}
        \\export var /*12*/x = /*13*/m1./*14*/m2;
        \\export var /*15*/y: typeof /*16*/m1./*17*/m2;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestImportNameCodeFixUMDGlobal0" {
    const content =
        \\// @AllowSyntheticDefaultImports: false
        \\// @Module: es2015
        \\// @Filename: a/f1.ts
        \\[|export function test() { };
        \\bar1/*0*/.bar;|]
        \\// @Filename: a/foo.d.ts
        \\export declare function bar(): number;
        \\export as namespace bar1; 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import * as bar1 from \"./foo\";\n\nexport function test() { };\nbar1.bar;",
    }, null );
}

test "TestCodeFixSpellingShortName2" {
    const content =
        \\export let ab = 1;
        \\abc;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestQuickInfoInWithBlock" {
    const content =
        \\with (x) {
        \\    function /*1*/f() { }
        \\    var /*2*/b = /*3*/f;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "any", "");
    // f.VerifyQuickInfoAt(undefined, "2", "any", "");
    // f.VerifyQuickInfoAt(undefined, "3", "any", "");
}

test "TestCodeFixSpelling4" {
    const content =
        \\export declare const despite: { the: any };
        \\
        \\[|dispite.the|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "despite.the", false, 0, 0);
}

test "TestInlayHintsNoHintWhenArgumentMatchesName" {
    const content =
        \\function foo (a: number, b: number) {}
        \\declare const a: 1;
        \\foo(a, 2);
        \\declare const v: any;
        \\foo(v.a, v.a);
        \\foo(v.b, v.b);
        \\foo(v.c, v.c);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayParameterNameHints = lsutil.IncludeInlayParameterNameHintsAll, .IncludeInlayParameterNameHintsWhenArgumentMatchesName = core.TSFalse}});
}

test "TestCompletionListFunctionMembers" {
    const content =
        \\// @lib: es5
        \\function fnc1() {
        \\    var bar = 1;
        \\    function foob(){ }
        \\}
        \\
        \\fnc1./**/
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
//             .Exact = CompletionFunctionMembersWithPrototype,
//         },
//     });
}

test "TestReferencesInEmptyFileWithMultipleProjects" {
    const content =
        \\// @Filename: /home/src/workspaces/project/a/tsconfig.json
        \\{ "files": ["a.ts"], "compilerOptions": { "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/a/a.ts
        \\/// <reference path="../b/b.ts" />
        \\/*1*/;
        \\// @Filename: /home/src/workspaces/project/b/tsconfig.json
        \\{ "files": ["b.ts"], "compilerOptions": { "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/b/b.ts
        \\/*2*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestQuickInfoJsDocTags5" {
    const content =
        \\// @noEmit: true
        \\// @allowJs: true
        \\// @Filename: quickInfoJsDocTags5.js
        \\class Foo {
        \\    /**
        \\     * comment
        \\     * @author Me <me@domain.tld>
        \\     * @see x (the parameter)
        \\     * @param {number} x - x comment
        \\     * @param {number} y - y comment
        \\     * @returns The result
        \\     */
        \\    method(x, y) {
        \\       return x + y;
        \\    }
        \\}
        \\
        \\class Bar extends Foo {
        \\    /**/method(x, y) {
        \\        const res = super.method(x, y) + 100;
        \\        return res;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCodeFixAddMissingImportForReactJsx2" {
    const content =
        \\// @jsx: react-jsxdev
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

test "TestOrganizeImports9" {
    const content =
        \\import { a as a, b, c, d as d, e as e } from "foo";
        \\a(b, d);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(undefined,
//         "import { a, b, d } from \"foo\";\na(b, d);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestFormattingCommentsBeforeErrors" {
    const content =
        \\namespace A {
        \\    interface B {
        \\        // a
        \\        // b
        \\        baz();
        \\/*0*/        // d /*1*/asd a
        \\        // e
        \\        foo();
        \\        // f asd
        \\        // g as
        \\        bar();
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "\n");
    _ = f.GoToMarker(undefined, "0");
    _ = f.VerifyCurrentLineContent(undefined, "        // d ");
}

test "TestFormatSatisfiesExpression" {
    const content =
        \\type Foo = "a" | "b" | "c";
        \\const foo1 = ["a"] satisfies Foo[];
        \\const foo2 = ["a"]satisfies Foo[];
        \\const foo3 = ["a"]  satisfies Foo[];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "type Foo = \"a\" | \"b\" | \"c\";\nconst foo1 = [\"a\"] satisfies Foo[];\nconst foo2 = [\"a\"] satisfies Foo[];\nconst foo3 = [\"a\"] satisfies Foo[];");
}

test "TestQuickinfoForUnionProperty" {
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
        \\var /*1*/x : One | Two;
        \\
        \\x./*2*/commonProperty;
        \\x./*3*/commonFunction;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var x: One | Two", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(property) commonProperty: string | number", "");
    // f.VerifyQuickInfoAt(undefined, "3", "(method) commonFunction(): number", "");
}

test "TestJsDocPropertyDescription7" {
    const content =
        \\class StringClass {
        \\    /** Something generic */
        \\    static [p: string]: any;
        \\}
        \\function stringClass(e: typeof StringClass) {
        \\    console.log(e./*stringClass*/anything);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "stringClass", "(index) StringClass[string]: any", "Something generic");
}

test "TestGetJavaScriptGlobalCompletions1" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\function f() {
        \\    // helloWorld leaks from here into the global space?
        \\    if (helloWorld) {
        \\        return 3;
        \\    }
        \\    return 5;
        \\}
        \\
        \\hello/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "helloWorld",
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//             },
//         },
//     });
}

test "TestAutoImportPackageJsonImportsPattern" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#*": "./src/*"
        \\  }
        \\}
        \\// @Filename: /src/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /a.ts
        \\something/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"#something.js"}, null );
}

test "TestRenameDestructuringAssignmentNestedInForOf" {
    const content =
        \\// @strict: false
        \\interface MultiRobot {
        \\    name: string;
        \\    skills: {
        \\        [|[|{| "contextRangeIndex": 0 |}primary|]: string;|]
        \\        secondary: string;
        \\    };
        \\}
        \\let multiRobots: MultiRobot[];
        \\let [|[|{| "contextRangeIndex": 2 |}primary|]: string|], secondary: string, primaryA: string, secondaryA: string;
        \\for ([|{ skills: { [|{| "contextRangeIndex": 4 |}primary|]: primaryA, secondary: secondaryA } } of multiRobots|]) {
        \\    primaryA;
        \\}
        \\for ([|{ skills: { [|{| "contextRangeIndex": 6 |}primary|], secondary } } of multiRobots|]) {
        \\    [|primary|];
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[5], f.Ranges()[3], f.Ranges()[7], f.Ranges()[8]);
}

test "TestCompletionListInNamedFunctionExpression1" {
    const content =
        \\var x = function foo() {
        \\   /*1*/
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
//                     .Label =  "foo",
//                     .Detail = undefined("(local function) foo(): void"),
//                     .Kind =   undefined(lsproto.CompletionItemKindFunction),
//                 },
//             },
//         },
//     });
}

test "TestImportNameCodeFixNewImportFile3" {
    const content =
        \\[|let t: XXX/*0*/.I;|]
        \\// @Filename: ./module.ts
        \\export namespace XXX {
        \\   export interface I {
        \\   }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { XXX } from \"./module\";\n\nlet t: XXX.I;",
    }, null );
}

test "TestQuickInfoCommentsClassMembers" {
    const content =
        \\/** This is comment for c1*/
        \\class c/*1*/1 {
        \\    /** p1 is property of c1*/
        \\    public p/*2*/1: number;
        \\    /** sum with property*/
        \\    public p/*3*/2(/** number to add*/b: number) {
        \\        return this.p1 + b;
        \\    }
        \\    /** getter property 1*/
        \\    public get p/*6*/3() {
        \\        return this.p/*8q*/2(this.p1);
        \\    }
        \\    /** setter property 1*/
        \\    public set p/*10*/3(/** this is value*/value: number) {
        \\        this.p1 = this.p/*13q*/2(value);
        \\    }
        \\    /** pp1 is property of c1*/
        \\    private p/*14*/p1: number;
        \\    /** sum with property*/
        \\    private p/*15*/p2(/** number to add*/b: number) {
        \\        return this.p1 + b;
        \\    }
        \\    /** getter property 2*/
        \\    private get p/*18*/p3() {
        \\        return this.p/*20q*/p2(this.pp1);
        \\    }
        \\    /** setter property 2*/
        \\    private set p/*22*/p3( /** this is value*/value: number) {
        \\        this.pp1 = this.p/*25q*/p2(value);
        \\    }
        \\    /** Constructor method*/
        \\    constru/*26*/ctor() {
        \\    }
        \\    /** s1 is static property of c1*/
        \\    static s/*27*/1: number;
        \\    /** static sum with property*/
        \\    static s/*28*/2(/** number to add*/b: number) {
        \\        return c1.s1 + b;
        \\    }
        \\    /** static getter property*/
        \\    static get s/*32*/3() {
        \\        return c1.s/*35q*/2(c1.s1);
        \\    }
        \\    /** setter property 3*/
        \\    static set s/*37*/3( /** this is value*/value: number) {
        \\        c1.s1 = c1.s/*42q*/2(value);
        \\    }
        \\    public nc_/*43*/p1: number;
        \\    public nc_/*44*/p2(b: number) {
        \\        return this.nc_p1 + b;
        \\    }
        \\    public get nc_/*46*/p3() {
        \\        return this.nc/*47q*/_p2(this.nc_p1);
        \\    }
        \\    public set nc/*48*/_p3(value: number) {
        \\        this.nc_p1 = this.nc/*49q*/_p2(value);
        \\    }
        \\    private nc/*50*/_pp1: number;
        \\    private nc_/*51*/pp2(b: number) {
        \\        return this.nc_pp1 + b;
        \\    }
        \\    private get nc/*53*/_pp3() {
        \\        return this.nc_/*54q*/pp2(this.nc_pp1);
        \\    }
        \\    private set nc_p/*55*/p3(value: number) {
        \\        this.nc_pp1 = this./*56q*/nc_pp2(value);
        \\    }
        \\    static nc/*57*/_s1: number;
        \\    static nc/*58*/_s2(b: number) {
        \\        return c1.nc_s1 + b;
        \\    }
        \\    static get nc/*60*/_s3() {
        \\        return c1.nc/*61q*/_s2(c1.nc_s1);
        \\    }
        \\    static set nc/*62*/_s3(value: number) {
        \\        c1.nc_s1 = c1.nc_/*63q*/s2(value);
        \\    }
        \\}
        \\var i/*64*/1 = new c/*65q*/1();
        \\var i1/*66*/_p = i1.p1;
        \\var i1/*68*/_f = i1.p/*69*/2;
        \\var i1/*70*/_r = i1.p/*71q*/2(20);
        \\var i1_p/*72*/rop = i1./*73*/p3;
        \\i1./*74*/p3 = i1_/*75*/prop;
        \\var i1_/*76*/nc_p = i1.n/*77*/c_p1;
        \\var i1/*78*/_ncf = i1.nc_/*79*/p2;
        \\var i1_/*80*/ncr = i1.nc/*81q*/_p2(20);
        \\var i1_n/*82*/cprop = i1.n/*83*/c_p3;
        \\i1.nc/*84*/_p3 = i1_/*85*/ncprop;
        \\var i1_/*86*/s_p = /*87*/c1./*88*/s1;
        \\var i1_s/*89*/_f = c1./*90*/s2;
        \\var i1_/*91*/s_r = c1.s/*92q*/2(20);
        \\var i1_s/*93*/_prop = c1.s/*94*/3;
        \\c1.s/*95*/3 = i1_s/*96*/_prop;
        \\var i1_s/*97*/_nc_p = c1.n/*98*/c_s1;
        \\var i1_s_/*99*/ncf = c1.nc/*100*/_s2;
        \\var i1_s_/*101*/ncr = c1.n/*102q*/c_s2(20);
        \\var i1_s_n/*103*/cprop = c1.nc/*104*/_s3;
        \\c1.nc/*105*/_s3 = i1_s_nc/*106*/prop;
        \\var i1/*107*/_c = c/*108*/1;
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
        \\cProperties_i./*110*/p2 = cProperties_i.p/*111*/1;
        \\cProperties_i.nc/*112*/_p2 = cProperties_i.nc/*113*/_p1;
        \\class cWithConstructorProperty {
        \\    /**
        \\    * this is class cWithConstructorProperty's constructor
        \\    * @param a this is first parameter a
        \\    */
        \\    /*119*/constructor(/**more info about a*/public a: number) {
        \\        var b/*118*/bbb = 10;
        \\        th/*116*/is./*114*/a = /*115*/a + 2 + bb/*117*/bb;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestGenericWithSpecializedProperties1" {
    const content =
        \\interface Foo<T> {
        \\    x: Foo<string>;
        \\    y: Foo<number>;
        \\}
        \\var f: Foo<number>;
        \\var /*1*/xx = f.x;
        \\var /*2*/yy = f.y;
        \\var f2: Foo<string>;
        \\var /*3*/x2 = f2.x;
        \\var /*4*/y2 = f2.y;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var xx: Foo<string>", "");
    // f.VerifyQuickInfoAt(undefined, "2", "var yy: Foo<number>", "");
    // f.VerifyQuickInfoAt(undefined, "3", "var x2: Foo<string>", "");
    // f.VerifyQuickInfoAt(undefined, "4", "var y2: Foo<number>", "");
}

test "TestNavigationBarItemsItems2" {
    const content =
        \\/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.InsertLine(undefined, "module A");
    _ = f.Insert(undefined, "export class ");
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCompletionsImport_filteredByInvalidPackageJson_direct" {
    const content =
        \\//@noEmit: true
        \\//@Filename: /package.json
        \\{
        \\  "mod"
        \\  "dependencies": {
        \\    "react": "*"
        \\  }
        \\}
        \\//@Filename: /node_modules/react/index.d.ts
        \\export declare var React: any;
        \\//@Filename: /node_modules/react/package.json
        \\{
        \\  "name": "react",
        \\  "types": "./index.d.ts"
        \\}
        \\//@Filename: /node_modules/fake-react/index.d.ts
        \\export declare var ReactFake: any;
        \\//@Filename: /node_modules/fake-react/package.json
        \\{
        \\  "name": "fake-react",
        \\  "types": "./index.d.ts"
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
//                 &.{
//                     .Label =               "ReactFake",
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "fake-react",
//                         },
//                     },
//                     .SortText = undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
}

test "TestGoToDefinitionOverriddenMember14" {
    const content =
        \\// @noImplicitOverride: true
        \\class A {
        \\    /*2*/m() {}
        \\}
        \\class B extends A {}
        \\class C extends B {
        \\    [|/*1*/override|] m() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestAutoImportAllowImportingTsExtensionsPackageJsonImports1" {
    const content =
        \\// @lib: es5
        \\// @module: node18
        \\// @allowImportingTsExtensions: true
        \\// @Filename: /node_modules/pkg/package.json
        \\{
        \\  "name": "pkg",
        \\  "type": "module",
        \\  "exports": {
        \\    "./*": {
        \\      "types": "./types/*",
        \\      "default": "./dist/*"
        \\    }
        \\  }
        \\}
        \\// @Filename: /node_modules/pkg/types/external.d.ts
        \\export declare function external(name: string): any;
        \\// @Filename: /package.json
        \\{
        \\  "name": "self",
        \\  "type": "module",
        \\  "imports": {
        \\    "#*": "./src/*"
        \\  },
        \\  "dependencies": {
        \\    "pkg": "*"
        \\  }
        \\}
        \\// @Filename: /src/add.ts
        \\export function add(a: number, b: number) {}
        \\// @Filename: /src/index.ts
        \\add/*imports*/;
        \\external/*exports*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyImportFixModuleSpecifiers(undefined, "imports", &.{"#add.ts"}, null );
    // f.VerifyImportFixModuleSpecifiers(undefined, "exports", &.{"pkg/external.js"}, null );
}

test "TestCompletionListInUnclosedIndexSignature02" {
    const content =
        \\class C {
        \\    [foo: /*1*/
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
//                 "C",
//             },
//             .Excludes = &.{
//                 "foo",
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
//                 "C",
//                 "foo",
//             },
//         },
//     });
}

test "TestInlayHintsInteractiveFunctionParameterTypes2" {
    const content =
        \\class C {}
        \\namespace N { export class Foo {} }
        \\interface Foo {}
        \\function f1(a = 1) {}
        \\function f2(a = "a") {}
        \\function f3(a = true) {}
        \\function f4(a = { } as Foo) {}
        \\function f5(a = <Foo>{}) {}
        \\function f6(a = {} as const) {}
        \\function f7(a = (({} as const))) {}
        \\function f8(a = new C()) {}
        \\function f9(a = new N.C()) {}
        \\function f10(a = ((((new C()))))) {}
        \\function f11(a = { a: 1, b: 1 }) {}
        \\function f12(a = ((({ a: 1, b: 1 })))) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayFunctionParameterTypeHints = core.TSTrue}});
}

test "TestGoToImplementationLocal_07" {
    const content =
        \\declare function [|someFunction|](): () => void;
        \\someFun/*reference*/ction();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "reference");
}

test "TestSatisfiesOperatorCompletion" {
    const content =
        \\type T = number;
        \\var x;
        \\var y = x satisfies /**/
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

test "TestGetJavaScriptQuickInfo4" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\/** @param {[number,string]} [a] */
        \\function /**/f(a) { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "function f(a?: [number, string]): void", "");
}

test "TestQuickInfoDisplayPartsVarWithStringTypes01" {
    const content =
        \\let /*1*/hello: "hello" | 'hello' = "hello";
        \\let /*2*/world: 'world' = "world";
        \\let /*3*/helloOrWorld: "hello" | 'world';
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCompletionsImport_filteredByPackageJson_nested" {
    const content =
        \\//@noEmit: true
        \\//@Filename: /package.json
        \\{
        \\  "dependencies": {
        \\    "react": "*"
        \\  }
        \\}
        \\//@Filename: /node_modules/react/index.d.ts
        \\export declare var React: any;
        \\//@Filename: /node_modules/react/package.json
        \\{
        \\  "name": "react",
        \\  "types": "./index.d.ts"
        \\}
        \\//@Filename: /dir/package.json
        \\{
        \\  "dependencies": {
        \\    "redux": "*"
        \\  }
        \\}
        \\//@Filename: /dir/node_modules/redux/package.json
        \\{
        \\  "name": "redux",
        \\  "types": "./index.d.ts"
        \\}
        \\//@Filename: /dir/node_modules/redux/index.d.ts
        \\export declare var Redux: any;
        \\//@Filename: /dir/index.ts
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
//         },
//     });
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =               "Redux",
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "redux",
//                         },
//                     },
//                     .SortText = undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
}

test "TestSignatureHelpInAdjacentBlockBody" {
    const content =
        \\declare function foo(...args);
        \\
        \\foo(() => {/*1*/}/*2*/)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifySignatureHelpPresent(undefined, &.{.TriggerKind = lsproto.SignatureHelpTriggerKindInvoked});
    _ = f.GoToMarker(undefined, "2");
    // f.VerifySignatureHelpPresent(undefined, &.{.TriggerKind = lsproto.SignatureHelpTriggerKindInvoked});
}

test "TestFormattingAwait" {
    const content =
        \\async function f() {
        \\    for          await (const x of g()) {
        \\        console.log(x);
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "async function f() {\n    for await (const x of g()) {\n        console.log(x);\n    }\n}");
}

test "TestCompletionsImport_filteredByPackageJson_typesImplicit" {
    const content =
        \\//@noEmit: true
        \\//@Filename: /package.json
        \\{
        \\  "dependencies": {
        \\    "react": "*"
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

test "TestStringCompletionsImportOrExportSpecifier" {
    const content =
        \\// @Filename: exports.ts
        \\export let foo = 1;
        \\let someValue = 2;
        \\let someType = 3;
        \\export {
        \\  someValue as "__some value",
        \\  someType as "__some type",
        \\};
        \\// @Filename: values.ts
        \\import { "/*valueImport0*/" } from "./exports";
        \\import { "/*valueImport1*/" as valueImport1 } from "./exports";
        \\import { foo as "/*valueImport2*/" } from "./exports";
        \\import { foo, "/*valueImport3*/" as valueImport3 } from "./exports";
        \\
        \\export { "/*valueExport0*/" } from "./exports";
        \\export { "/*valueExport1*/" as valueExport1 } from "./exports";
        \\export { foo as "/*valueExport2*/" } from "./exports";
        \\export { foo, "/*valueExport3*/" } from "./exports";
        \\// @Filename: types.ts
        \\import { type "/*typeImport0*/" } from "./exports";
        \\import { type "/*typeImport1*/" as typeImport1 } from "./exports";
        \\import { type foo as "/*typeImport2*/" } from "./exports";
        \\import { type foo, type "/*typeImport3*/" as typeImport3 } from "./exports";
        \\
        \\export { type "/*typeExport0*/" } from "./exports";
        \\export { type "/*typeExport1*/" as typeExport1 } from "./exports";
        \\export { type foo as "/*typeExport2*/" } from "./exports";
        \\export { type foo, type "/*typeExport3*/" } from "./exports";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "valueImport0", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "__some type",
//                 "__some value",
//                 "foo",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "valueImport1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "__some type",
//                 "__some value",
//                 "foo",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "valueImport2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{},
//         },
//     });
    // f.VerifyCompletions(undefined, "valueImport3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "__some type",
//                 "__some value",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "valueExport0", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "__some type",
//                 "__some value",
//                 "foo",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "valueExport1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "__some type",
//                 "__some value",
//                 "foo",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "valueExport2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{},
//         },
//     });
    // f.VerifyCompletions(undefined, "valueExport3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "__some type",
//                 "__some value",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "typeImport0", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "__some type",
//                 "__some value",
//                 "foo",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "typeImport1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "__some type",
//                 "__some value",
//                 "foo",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "typeImport2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{},
//         },
//     });
    // f.VerifyCompletions(undefined, "typeImport3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "__some type",
//                 "__some value",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "typeExport0", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "__some type",
//                 "__some value",
//                 "foo",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "typeExport1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "__some type",
//                 "__some value",
//                 "foo",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "typeExport2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{},
//         },
//     });
    // f.VerifyCompletions(undefined, "typeExport3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "__some type",
//                 "__some value",
//             },
//         },
//     });
}

test "TestDocumentHighlightDefaultInKeyword" {
    const content =
        \\[|case|]
        \\[|default|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestCompletionsForRecursiveGenericTypesMember" {
    const content =
        \\export class TestBase<T extends TestBase<T>>
        \\{
        \\    public publicMethod(p: any): void {}
        \\    private privateMethod(p: any): void {}
        \\    protected protectedMethod(p: any): void {}
        \\    public test(t: T): void
        \\    {
        \\        t./**/
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
//                 "privateMethod",
//                 "protectedMethod",
//                 "publicMethod",
//                 "test",
//             },
//         },
//     });
}

test "TestGoToDefinitionExternalModuleName7" {
    const content =
        \\// @Filename: b.ts
        \\import {Foo, Bar} from [|'e/*1*/'|];
        \\// @Filename: a.ts
        \\declare module /*2*/"e" {
        \\    class Foo { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestCompletionListPrivateMembers3" {
    const content =
        \\class Other {
        \\    public p;
        \\    protected p2
        \\    private p3;
        \\}
        \\
        \\class Self {
        \\    private other: Other;
        \\
        \\    method() {
        \\        this.other./*1*/;
        \\
        \\        this.other.p/*2*/;
        \\
        \\        this.other.p/*3*/.toString();
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "2", "3"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "p",
//             },
//         },
//     });
}

test "TestGetOccurrencesThis4" {
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
        \\            this.this;
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
        \\                this.this;
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
        \\    public b = [|this|].method1;
        \\
        \\    public method1() {
        \\        [|this|];
        \\        [|this|];
        \\        () => [|this|];
        \\        () => {
        \\            if ([|this|]) {
        \\                [|this|];
        \\            }
        \\            else {
        \\                [|this|].this;
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
        \\        [|this|];
        \\        [|this|];
        \\        () => [|t/**/his|];
        \\        () => {
        \\            if ([|this|]) {
        \\                [|this|];
        \\            }
        \\            else {
        \\                [|this|].this;
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
        \\                this.this;
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
        \\                this.this;
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
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestJavaScriptModules18" {
    const content =
        \\// @allowJs: true
        \\// @Filename: myMod.js
        \\var x = require('fs');
        \\// @Filename: other.js
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
//             .Excludes = &.{
//                 "x",
//             },
//         },
//     });
}

test "TestCompletionListInUnclosedIndexSignature03" {
    const content =
        \\class C {
        \\    [foo: string]: { x: typeof /*1*/
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

test "TestFindAllRefsClassStaticBlocks" {
    const content =
        \\class ClassStaticBocks {
        \\    static x;
        \\    [|[|/*classStaticBocks1*/static|] {}|]
        \\    static y;
        \\    [|[|/*classStaticBocks2*/static|] {}|]
        \\    static y;
        \\    [|[|/*classStaticBocks3*/static|] {}|]
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "classStaticBocks1", "classStaticBocks2", "classStaticBocks3");
}

test "TestFormatonkey01" {
    const content =
        \\// @lib: es5
        \\switch (1) {
        \\    case 1:
        \\        {
        \\            /*1*/
        \\        break;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "}");
    _ = f.VerifyCurrentLineContent(undefined, "        }");
}

test "TestImportNameCodeFixExistingImport0" {
    const content =
        \\import [|{ v1 }|] from "./module";
        \\f1/*0*/();
        \\// @Filename: module.ts
        \\export function f1() {}
        \\export var v1 = 5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "{ f1, v1 }",
    }, null );
}

test "TestFormattingChainingMethods" {
    const content =
        \\ z$ = this.store.select(this.fake())
        \\     .ofType(
        \\      'ACTION',
        \\      'ACTION-2'
        \\     )
        \\     .pipe(
        \\         filter(x => !!x),
        \\         switchMap(() =>
        \\          this.store.select(this.menuSelector.getAll('x'))
        \\           .pipe(
        \\             tap(x => {
        \\             this.x = !x;
        \\             })
        \\           )
        \\         )
        \\     );
        \\
        \\1
        \\    .toFixed(
        \\        2);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "z$ = this.store.select(this.fake())\n    .ofType(\n        'ACTION',\n        'ACTION-2'\n    )\n    .pipe(\n        filter(x => !!x),\n        switchMap(() =>\n            this.store.select(this.menuSelector.getAll('x'))\n                .pipe(\n                    tap(x => {\n                        this.x = !x;\n                    })\n                )\n        )\n    );\n\n1\n    .toFixed(\n        2);");
}

test "TestGenericFunctionReturnType2" {
    const content =
        \\class C<T> {
        \\    constructor(x: T) { }
        \\    foo(x: T) {
        \\        return (a: T) => x;
        \\    }
        \\}
        \\var x = new C(1);
        \\var /*2*/r = x.foo(/*1*/3);
        \\var /*4*/r2 = r(/*3*/4);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifySignatureHelp(undefined, .{.Text = "foo(x: number): (a: number) => number"});
    // f.VerifyQuickInfoAt(undefined, "2", "var r: (a: number) => number", "");
    _ = f.GoToMarker(undefined, "3");
    // f.VerifySignatureHelp(undefined, .{.Text = "r(a: number): number"});
    // f.VerifyQuickInfoAt(undefined, "4", "var r2: number", "");
}

test "TestFindAllRefsForStaticInstanceMethodInheritance" {
    const content =
        \\class X{
        \\    /*0*/foo(): void{}
        \\}
        \\
        \\class Y extends X{
        \\    static /*1*/foo(): void{}
        \\}
        \\
        \\class Z extends Y{
        \\    static /*2*/foo(): void{}
        \\    /*3*/foo(): void{}
        \\}
        \\
        \\const x = new X();
        \\const y = new Y();
        \\const z = new Z();
        \\x.foo();
        \\y.foo();
        \\z.foo();
        \\Y.foo();
        \\Z.foo();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2", "3");
}

test "TestUnusedImports13FS" {
    const content =
        \\// @noUnusedLocals: true
        \\// @Filename: file2.ts
        \\[| import A, { x } from './a'; |]
        \\console.log(A);
        \\// @Filename: file1.ts
        \\export default 10;
        \\export var x = 10;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "import A from './a';", false, 0, 0);
}

test "TestImportNameCodeFixExistingImport1" {
    const content =
        \\import d, [|{ v1 }|] from "./module";
        \\f1/*0*/();
        \\// @Filename: module.ts
        \\export function f1() {}
        \\export var v1 = 5;
        \\export default var d1 = 6;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "{ f1, v1 }",
    }, null );
}

test "TestCodeFixMissingTypeAnnotationOnExports31_inline_import_default" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @Filename: /person-code.ts
        \\export type Person = { x: string; }
        \\export function getPerson() : Person {
        \\  return null!
        \\}
        \\// @Filename: /code.ts
        \\import { getPerson } from "./person-code";
        \\export default {
        \\  person: getPerson()
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/code.ts");
    _ = f.VerifyCodeFixAvailable(undefined, &.{"Extract default export to variable", "Add satisfies and an inline type assertion with 'Person'", "Extract to variable and replace with 'newLocal as typeof newLocal'"});
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add satisfies and an inline type assertion with 'Person'",
        .NewFileContent = "import { getPerson, Person } from \"./person-code\";\nexport default {\n  person: getPerson() satisfies Person as Person\n};",
        .Index = 1,
    });
}

test "TestCompletionListInObjectLiteral3" {
    const content =
        \\interface IASTNode {
        \\    name: string;
        \\    children: IASTNode[];
        \\}
        \\var ast2: IASTNode = {
        \\    /**/
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
//                 "children",
//                 "name",
//             },
//         },
//     });
}

test "TestEditTemplateConstraint" {
    const content =
        \\/**
        \\ * @template {/**/
        \\ */
        \\function f() {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "n");
    _ = f.Insert(undefined, "u");
}

test "TestRecursiveGenerics2" {
    const content =
        \\class S18<B, B, A, B> extends S18<A[], { S19: A; (): A }[]> { }
        \\/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "(new S18()).S18 = 0;");
}

test "TestGetOccurrencesSwitchCaseDefaultBroken" {
    const content =
        \\swi/*1*/tch(10) {
        \\    case 1:
        \\    case 2:
        \\    c/*2*/ase 4:
        \\    case 8:
        \\    case 0xBEEF:
        \\    de/*4*/fult:
        \\        break;
        \\    /*5*/cas 16:
        \\    c/*3*/ase 12:
        \\        function f() {
        \\            br/*11*/eak;
        \\            /*12*/break;
        \\        }
        \\}
        \\
        \\sw/*6*/itch (10) {
        \\    de/*7*/fault
        \\    case 1:
        \\    case 2
        \\
        \\    c/*8*/ose 4:
        \\    case 8:
        \\    case 0xBEEF:
        \\        bre/*9*/ak;
        \\    case 16:
        \\        () => bre/*10*/ak;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Markers()));
}

test "TestGoToDefinitionScriptImport" {
    const content =
        \\// @filename: scriptThing.ts
        \\/*1d*/console.log("woooo side effects")
        \\// @filename: stylez.css
        \\/*2d*/div {
        \\  color: magenta;
        \\}
        \\// @filename: moduleThing.ts
        \\import [|/*1*/"./scriptThing"|];
        \\import [|/*2*/"./stylez.css"|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1", "2");
}

test "TestArityErrorAfterStringCompletions" {
    const content =
        \\// @strict: true
        \\
        \\interface Events {
        \\  click: any;
        \\  drag: any;
        \\}
        \\
        \\declare function addListener<K extends keyof Events>(type: K, listener: (ev: Events[K]) => any): void;
        \\
        \\/*1*/addListener/*2*/("/*3*/")
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"3"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "click",
//                 "drag",
//             },
//         },
//     });
    _ = f.VerifyErrorExistsBetweenMarkers(undefined, "1", "2");
}

test "TestGoToDefinitionReturn3" {
    const content =
        \\class C {
        \\    /*end*/m() {
        \\        [|/*start*/return|] 1;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "start");
}

test "TestOrganizeImportsAttributes2" {
    const content =
        \\import { A } from "./a";
        \\import { C } from "./a" with { type: "a" };
        \\import { Z } from "./z";
        \\import { A as D } from "./a" with { type: "b" };
        \\import { E } from "./a" with { type: "a" };
        \\import { F } from "./a" with { type: "a" };
        \\import { B } from "./a";
        \\
        \\export type G = A | B | C | D | E | F | Z;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(undefined,
//         "import { A, B } from \"./a\";\nimport { C, E, F } from \"./a\" with { type: \"a\" };\nimport { A as D } from \"./a\" with { type: \"b\" };\nimport { Z } from \"./z\";\n\nexport type G = A | B | C | D | E | F | Z;",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestReferencesForInheritedProperties4" {
    const content =
        \\class class1 extends class1 {
        \\   /*1*/doStuff() { }
        \\   /*2*/propName: string;
        \\}
        \\
        \\var c: class1;
        \\c./*3*/doStuff();
        \\c./*4*/propName;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestAutoImportProvider_pnpm" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{ "compilerOptions": { "module": "commonjs", "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{ "dependencies": { "mobx": "*" } }
        \\// @Filename: /home/src/workspaces/project/node_modules/.pnpm/mobx@6.0.4/node_modules/mobx/package.json
        \\{ "types": "dist/mobx.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/.pnpm/mobx@6.0.4/node_modules/mobx/dist/mobx.d.ts
        \\export declare function autorun(): void;
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\autorun/**/
        \\// @link: /home/src/workspaces/project/node_modules/.pnpm/mobx@6.0.4/node_modules/mobx -> /home/src/workspaces/project/node_modules/mobx
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { autorun } from \"mobx\";\n\nautorun",
    }, null );
}

test "TestCodeFixClassImplementClassMultipleSignatures2" {
    const content =
        \\class A {
        \\    method(a: any, b: string): boolean;
        \\    method(a: string, b: number): Function;
        \\    method(a: string): Function;
        \\    method(a: string | number, b?: string | number): boolean | Function { return a + b as any; }
        \\}
        \\class C implements A { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'A'",
        .NewFileContent = "class A {\n    method(a: any, b: string): boolean;\n    method(a: string, b: number): Function;\n    method(a: string): Function;\n    method(a: string | number, b?: string | number): boolean | Function { return a + b as any; }\n}\nclass C implements A {\n    method(a: any, b: string): boolean;\n    method(a: string, b: number): Function;\n    method(a: string): Function;\n    method(a: string | number, b?: string | number): boolean | Function {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestJavascriptModules20" {
    const content =
        \\// @allowJs: true
        \\// @Filename: mod.js
        \\function foo() { return {a: true}; }
        \\module.exports = foo();
        \\// @Filename: app.js
        \\import * as mod from "./mod"
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

test "TestSignatureHelpAtEOF2" {
    const content =
        \\console.log()
        \\/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyNoSignatureHelpForMarkersWithContext(undefined, &.{.TriggerKind = lsproto.SignatureHelpTriggerKindInvoked}, "");
}

test "TestCompletionListForShorthandPropertyAssignment2" {
    const content =
        \\var person: {name:string; id: number} = { n/**/
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
//                 "id",
//                 "name",
//             },
//         },
//     });
}

test "TestGoToDefinitionVariableAssignment" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @filename: foo.js
        \\const Bar;
        \\const Foo = /*def*/Bar = function () {}
        \\Foo.prototype.bar = function() {}
        \\new [|Foo/*ref*/|]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "foo.js");
    // f.VerifyBaselineGoToDefinition(undefined, true, "ref");
}

test "TestCompletionsLiteralFromInferenceWithinInferredType2" {
    const content =
        \\// @Filename: /a.tsx
        \\type Values<T> = T[keyof T];
        \\
        \\type GetStates<T> = T extends { states: object } ? T["states"] : never;
        \\
        \\type IsNever<T> = [T] extends [never] ? 1 : 0;
        \\
        \\type GetIds<T, Gathered extends string = never> = IsNever<T> extends 1
        \\  ? Gathered
        \\  : "id" extends keyof T
        \\  ? GetIds<Values<GetStates<T>>, Gathered | 
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
//                 "#wow_deep_id",
//                 ".child",
//             },
//         },
//     });
}

test "TestAutoImportRelativePathToMonorepoPackage" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "nodenext",
        \\    "lib": ["es5"]
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/packages/app/dist/index.d.ts
        \\import {} from "utils";
        \\export const app: number;
        \\// @Filename: /home/src/workspaces/project/packages/utils/package.json
        \\{ "name": "utils", "version": "1.0.0", "main": "dist/index.js" }
        \\// @Filename: /home/src/workspaces/project/packages/utils/dist/index.d.ts
        \\export const x: number;
        \\// @link: /home/src/workspaces/project/packages/utils -> /home/src/workspaces/project/packages/app/node_modules/utils
        \\// @Filename: /home/src/workspaces/project/script.ts
        \\import {} from "./packages/app/dist/index.js";
        \\x/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"./packages/utils/dist/index.js"}, null );
}

test "TestCodeFixClassImplementInterfaceDuplicateMember2" {
    const content =
        \\// @strict: false
        \\interface I1 {
        \\    x: number;
        \\}
        \\interface I2 {
        \\    x: number;
        \\}
        \\
        \\class C implements I1,I2 {
        \\    x: number;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestQuickInfoInInvalidIndexSignature" {
    const content =
        \\function method() { var /**/dictionary = <{ [index]: string; }>{}; }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "(local var) dictionary: {\n    [x: number]: string;\n}", "");
}

test "TestCompletionListInferKeyword" {
    const content =
        \\type Bar<T> = T extends { a: (x: in/**/) => void }
        \\   ? U
        \\   : never;
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
//                     .Label =    "infer",
//                     .Kind =     undefined(lsproto.CompletionItemKindKeyword),
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestImportNameCodeFixUMDGlobalJavaScript" {
    const content =
        \\// @AllowSyntheticDefaultImports: false
        \\// @Module: commonjs
        \\// @CheckJs: true
        \\// @AllowJs: true
        \\// @Filename: a/f1.js
        \\[|export function test() { };
        \\bar1/*0*/.bar;|]
        \\// @Filename: a/foo.d.ts
        \\export declare function bar(): number;
        \\export as namespace bar1; 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import * as bar1 from \"./foo\";\n\nexport function test() { };\nbar1.bar;",
    }, null );
}

test "TestAutoImportFileExcludePatterns13" {
    const content =
        \\// @Filename: /src/vs/test.ts
        \\import { Parts } from './parts';
        \\export class /**/Extended implements Parts {
        \\}
        \\// @Filename: /src/vs/parts.ts
        \\import { Event } from '../event/event';
        \\
        \\export interface Parts {
        \\    readonly options: Event;
        \\}
        \\// @Filename: /src/event/event.ts
        \\export interface Event {
        \\    (): string;
        \\}
        \\// @Filename: /src/thing.ts
        \\import { Event } from '../event/event';
        \\export { Event };
        \\// @Filename: /src/a.ts
        \\import './thing'
        \\declare module './thing' {
        \\    interface Event {
        \\        c: string;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'Parts'",
        .NewFileContent = "import { Event } from '../event/event';\nimport { Parts } from './parts';\nexport class Extended implements Parts {\n    options: Event;\n}",
        .Index =           0,
        .UserPreferences = &.{.AutoImportFileExcludePatterns = &.{"src/thing.ts"}},
    });
}

test "TestGoToDefinitionDynamicImport3" {
    const content =
        \\// @Filename: foo.ts
        \\export function /*Destination*/bar() { return "bar"; }
        \\import('./foo').then(({ [|ba/*1*/r|] }) => undefined);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestJsDocGenerics1" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: ref.d.ts
        \\namespace Thing {
        \\    export interface Thung {
        \\        a: number;
        \\    ]
        \\]
        \\// @Filename: Foo.js
        \\
        \\/** @type {Array<number>} */
        \\var v;
        \\v[0]./*1*/
        \\
        \\/** @type {{x: Array<Array<number>>}} */
        \\var w;
        \\w.x[0][0]./*2*/
        \\
        \\/** @type {Array<Thing.Thung>} */
        \\var x;
        \\x[0].a./*3*/
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
//             .Includes = &.{
//                 &.{
//                     .Label = "toFixed",
//                     .Kind =  undefined(lsproto.CompletionItemKindMethod),
//                 },
//             },
//         },
//     });
}

test "TestCodeFixSpellingJs8" {
    const content =
        \\// @allowjs: true
        \\// @noEmit: true
        \\// @filename: a.js
        \\var locals = {}
        \\// @ts-expect-error
        \\Object.keys(locale)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
}

test "TestJsDocTypeTagQuickInfo2" {
    const content =
        \\// @lib: es5
        \\// @strict: true
        \\// @allowJs: true
        \\// @Filename: jsDocTypeTag2.js
        \\/** @type {string} */
        \\var /*1*/s;
        \\/** @type {number} */
        \\var /*2*/n;
        \\/** @type {boolean} */
        \\var /*3*/b;
        \\/** @type {void} */
        \\var /*4*/v;
        \\/** @type {undefined} */
        \\var /*5*/u;
        \\/** @type {null} */
        \\var /*6*/nl;
        \\/** @type {array} */
        \\var /*7*/a;
        \\/** @type {promise} */
        \\var /*8*/p;
        \\/** @type {?number} */
        \\var /*9*/nullable;
        \\/** @type {function} */
        \\var /*10*/func;
        \\/** @type {function (number): number} */
        \\var /*11*/func1;
        \\/** @type {string | number} */
        \\var /*12*/sOrn;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCompletionListInComments3" {
    const content =
        \\// @lib: es5
        \\ /*{| "name": "1" |}
        \\ /*  {| "name": "2" |}
        \\ /*  *{| "name": "3" |}
        \\ /*  */{| "name": "4" |}
        \\ {| "name": "5" |}/*  */
        \\/* {| "name": "6" |}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, &.{"1", "2", "3", "6"}, null);
    // f.VerifyCompletions(undefined, &.{"4", "5"}, &.{
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

test "TestAutoImportPackageJsonImportsPreference1" {
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
        \\something/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"./src/a/b/c/something"}, &.{.ImportModuleSpecifierPreference = "relative"});
}

test "TestDocCommentTemplateNamespacesAndModules02" {
    const content =
        \\/*top*/
        \\namespace n1.
        \\    /*n2*/ n2.
        \\    /*n3*/ n3 {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyJSDocCompletion(undefined, "top", 3, "/** */", null);
    // f.VerifyNoJSDocCompletion(undefined, "n2");
    // f.VerifyNoJSDocCompletion(undefined, "n3");
}

test "TestPropertyDuplicateIdentifierError" {
    const content =
        \\export class C {
        \\    x: number;
        \\    get x(): number { return 1; }
        \\}/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "/n");
}

test "TestGenericsFormattingMultiline" {
    const content =
        \\
        \\class Foo   <   
        \\ T1   extends unknown,
        \\  T2   
        \\    > {
        \\    public method    <  
        \\ T3,
        \\    >   (a: T1,   b: Array    < 
        \\     string 
        \\     > ):   Map <
        \\          T1 ,
        \\      Array < T3    >  
        \\          > { throw new Error(); } 
        \\}
        \\
        \\interface IFoo<
        \\       T, 
        \\  > {
        \\    new < T
        \\      > ( a: T);
        \\    op?< 
        \\   T,
        \\      M
        \\    > (a: T, b : M );
        \\    <
        \\     T,
        \\      >(x: T): T;
        \\}
        \\
        \\type foo<
        \\  T
        \\   > = Foo   <
        \\  number, Array <   number  >  > ;
        \\
        \\function bar <
        \\T, U extends T
        \\ >  () {
        \\    return class  < 
        \\       T2,
        \\  > {
        \\    }
        \\}
        \\
        \\bar<
        \\string, 
        \\     "s"
        \\     > ();
        \\
        \\declare const func: <
        \\T   extends number[], 
        \\                       > (x: T) => new <
        \\       U
        \\                          > () => U;
        \\
        \\class A < T > extends bar <  
        \\        T,number
        \\ >( )  <  T
        \\     > {
        \\}
        \\
        \\function s<T, U>(x: TemplateStringsArray, ...args: any[]) { return x.join(); }
        \\
        \\const t = s<
        \\      number , 
        \\  string[] & ArrayLike<any>
        \\      >
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "\nclass Foo<\n    T1 extends unknown,\n    T2\n> {\n    public method<\n        T3,\n    >(a: T1, b: Array<\n        string\n    >): Map<\n        T1,\n        Array<T3>\n    > { throw new Error(); }\n}\n\ninterface IFoo<\n    T,\n> {\n    new <T\n    >(a: T);\n    op?<\n        T,\n        M\n    >(a: T, b: M);\n    <\n        T,\n    >(x: T): T;\n}\n\ntype foo<\n    T\n> = Foo<\n    number, Array<number>>;\n\nfunction bar<\n    T, U extends T\n>() {\n    return class <\n        T2,\n    > {\n    }\n}\n\nbar<\n    string,\n    \"s\"\n>();\n\ndeclare const func: <\n    T extends number[],\n> (x: T) => new <\n    U\n> () => U;\n\nclass A<T> extends bar<\n    T, number\n>()<T\n> {\n}\n\nfunction s<T, U>(x: TemplateStringsArray, ...args: any[]) { return x.join(); }\n\nconst t = s<\n    number,\n    string[] & ArrayLike<any>\n>`abc${1}def`;\n");
}

test "TestGetJavaScriptCompletions19" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: file.js
        \\function fn() {
        \\    if (foo) {
        \\        return 0;
        \\    } else {
        \\        return '0';
        \\    }
        \\}
        \\let x = fn();
        \\if(typeof x === 'string') {
        \\    x/*str*/
        \\} else {
        \\    x/*num*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "str");
    _ = f.Insert(undefined, ".");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "substring",
//                     .Kind =  undefined(lsproto.CompletionItemKindMethod),
//                 },
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "num");
    _ = f.Insert(undefined, ".");
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

test "TestCodeFixImportNonExportedMember4" {
    const content =
        \\// @module: esnext
        \\// @filename: /a.d.ts
        \\declare function foo(): any;
        \\declare function bar(): any;
        \\// @filename: /b.ts
        \\import { bar } from "./a";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    // f.VerifyCodeFixNotAvailable(undefined, "fixImportNonExportedMember");
}

test "TestGetJavaScriptSyntacticDiagnostics24" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\function Person(age) {
        \\    if (age >= 18) {
        \\        this.canVote = true;
        \\    } else {
        \\        this.canVote = 23;
        \\    }
        \\}
        \\let x = new Person(100);
        \\x.canVote/**/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "(property) Person.canVote: number | boolean", "");
}

test "TestCompletionListInEmptyFile" {
    const content =
        \\var a = 0;
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
//                 "a",
//             },
//         },
//     });
}

test "TestFindAllRefsForModuleGlobal" {
    const content =
        \\// @Filename: /node_modules/foo/index.d.ts
        \\export const x = 0;
        \\// @Filename: /b.ts
        \\/// <reference types="foo" />
        \\import { x } from "/*1*/foo";
        \\declare module "foo" {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestGoToDefinitionOverriddenMember5" {
    const content =
        \\// @noImplicitOverride: true
        \\class Foo extends (class {
        \\    /*2*/m() {}
        \\}) {
        \\    [|/*1*/override|] m() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestCompletionForStringLiteral8" {
    const content =
        \\// @stableTypeOrdering: true
        \\type As = 'arf' | 'abacus' | 'abaddon';
        \\let a: As;
        \\if (a === '/**/
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
//                 "abacus",
//                 "abaddon",
//                 "arf",
//             },
//         },
//     });
}

test "TestWhiteSpaceTrimming3" {
    const content =
        \\let t = "foo \
        \\bar     \   
        \\"/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, ";");
    _ = f.VerifyCurrentFileContent(undefined, "let t = \"foo \\\nbar     \\   \n\";");
}

test "TestAutoImportSpecifierExcludeRegexes3" {
    const content =
        \\// @module: preserve
        \\// @Filename: /node_modules/pkg/package.json
        \\{
        \\    "name": "pkg",
        \\    "version": "1.0.0",
        \\    "exports": {
        \\        ".": "./index.js",
        \\        "./utils": "./utils.js"
        \\    }
        \\}
        \\// @Filename: /node_modules/pkg/utils.d.ts
        \\export function add(a: number, b: number) {}
        \\// @Filename: /node_modules/pkg/index.d.ts
        \\export * from "./utils";
        \\// @Filename: /src/index.ts
        \\add/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"pkg", "pkg/utils"}, null );
    // f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"pkg/utils"}, &.{.AutoImportSpecifierExcludeRegexes = &.{"^pkg$"}});
}

test "TestGoToDefinitionScriptImportServer" {
    const content =
        \\// @lib: es5
        \\// @Filename: /home/src/workspaces/project/scriptThing.ts
        \\/*1d*/console.log("woooo side effects")
        \\// @Filename: /home/src/workspaces/project/stylez.css
        \\/*2d*/div {
        \\  color: magenta;
        \\}
        \\// @Filename: /home/src/workspaces/project/moduleThing.ts
        \\import [|/*1*/"./scriptThing"|];
        \\import [|/*2*/"./stylez.css"|];
        \\import [|/*3*/"./foo.txt"|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1", "2", "3");
}

test "TestNavigationBarPropertyDeclarations" {
    const content =
        \\class A {
        \\    public A1 = class {
        \\        public x = 1;
        \\        private y() {}
        \\        protected z() {}
        \\    }
        \\
        \\    public A2 = {
        \\        x: 1,
        \\        y() {},
        \\        z() {}
        \\    }
        \\
        \\    public A3 = function () {}
        \\    public A4 = () => {}
        \\    public A5 = 1;
        \\    public A6 = "A6";
        \\
        \\    public ["A7"] = class {
        \\        public x = 1;
        \\        private y() {}
        \\        protected z() {}
        \\    }
        \\
        \\    public [1] = {
        \\        x: 1,
        \\        y() {},
        \\        z() {}
        \\    }
        \\
        \\    public [1 + 1] = 1;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestFindAllRefsForDefaultExport" {
    const content =
        \\// @Filename: a.ts
        \\export default function /*def*/f() {}
        \\// @Filename: b.ts
        \\import /*deg*/g from "./a";
        \\[|/*ref*/g|]();
        \\// @Filename: c.ts
        \\import { f } from "./a";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "def", "deg");
    // f.VerifyBaselineGoToDefinition(undefined, true, "ref");
}

test "TestCompletionListInObjectBindingPattern01" {
    const content =
        \\interface I {
        \\    property1: number;
        \\    property2: string;
        \\}
        \\
        \\var foo: I;
        \\var { /**/ } = foo;
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
//                 "property1",
//                 "property2",
//             },
//         },
//     });
}

test "TestFindAllRefsForDefaultExport_reExport_allowSyntheticDefaultImports" {
    const content =
        \\// @allowSyntheticDefaultImports: true
        \\// @module: commonjs
        \\// @Filename: /export.ts
        \\const /*0*/foo = 1;
        \\export = /*1*/foo;
        \\// @Filename: /re-export.ts
        \\export { /*2*/default } from "./export";
        \\// @Filename: /re-export-dep.ts
        \\import /*3*/fooDefault from "./re-export";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2", "3");
}

test "TestFormattingInDestructuring4" {
    const content =
        \\/*1*/const { 
        \\/*2*/    a,
        \\/*3*/    b,
        \\/*4*/} = { a: 1, b: 2 };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts198);
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "const {");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "    a,");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "    b,");
    _ = f.GoToMarker(undefined, "4");
    _ = f.VerifyCurrentLineContent(undefined, "} = {a: 1, b: 2};");
}

test "TestRenameStringLiteralOk1" {
    const content =
        \\declare function f(): '[|foo|]' | 'bar'
        \\class Foo {
        \\    f = f()
        \\}
        \\const d: 'foo' = 'foo'
        \\declare const ff: Foo
        \\ff.f = '[|foo|]'
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "foo");
}

test "TestImportNameCodeFix_jsx7" {
    const content =
        \\// @jsx: react
        \\// @module: esnext
        \\// @esModuleInterop: true
        \\// @moduleResolution: bundler
        \\// @Filename: /node_modules/react/index.d.ts
        \\// React was not defined
        \\// @Filename: /a.tsx
        \\<[|Text|]></Text>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.tsx");
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestRenameImportAndExport" {
    const content =
        \\[|import [|{| "contextRangeIndex": 0 |}a|] from "module";|]
        \\[|export { [|{| "contextRangeIndex": 2 |}a|] };|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[3]);
}

test "TestImportTypeCompletions2" {
    const content =
        \\// @target: esnext
        \\// @filename: /foo.ts
        \\export const Foo = {};
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
//             .Exact = &.{},
//         },
//     });
}

test "TestConstructorQuickInfo" {
    const content =
        \\class SS<T>{}
        \\
        \\var x/*1*/1 = new SS<number>();
        \\var x/*2*/2 = new SS();
        \\var x/*3*/3 = new SS;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var x1: SS<number>", "");
    // f.VerifyQuickInfoAt(undefined, "2", "var x2: SS<unknown>", "");
    // f.VerifyQuickInfoAt(undefined, "3", "var x3: SS<unknown>", "");
}

test "TestCompletionsWithDeprecatedTag6" {
    const content =
        \\namespace Foo {
        \\    /** @deprecated foo */
        \\    export var foo: number;
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
//             .Exact = &.{
//                 &.{
//                     .Label =    "foo",
//                     .Kind =     undefined(lsproto.CompletionItemKindVariable),
//                     .SortText = undefined(string(ls.DeprecateSortText(ls.SortTextLocationPriority))),
//                     .Tags =     &&.{lsproto.CompletionItemTagDeprecated},
//                 },
//             },
//         },
//     });
}

test "TestCodeFixClassImplementInterfaceHeritageClauseAlreadyHaveMember" {
    const content =
        \\// @strict: false
        \\class Base {
        \\    foo: number;
        \\}
        \\
        \\class D extends Base {
        \\    bar: number;
        \\}
        \\
        \\interface I {
        \\    foo: number;
        \\    bar: number;
        \\    baz: number;
        \\}
        \\
        \\class C extends D implements I { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "class Base {\n    foo: number;\n}\n\nclass D extends Base {\n    bar: number;\n}\n\ninterface I {\n    foo: number;\n    bar: number;\n    baz: number;\n}\n\nclass C extends D implements I {\n    baz: number;\n}",
        .Index = 0,
    });
}

test "TestGetOccurrencesReadonly2" {
    const content =
        \\type T = {
        \\  [|readonly|] prop: string;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestOrganizeImportsAttributes3" {
    const content =
        \\import { A } from "./a";
        \\import { C } from "./a" with {      type: "a" };
        \\import { Z } from "./z";
        \\import { A as D } from "./a" with    { type: "b" };
        \\import { E } from "./a" with { type: /* comment*/ "a"              };
        \\import { F } from "./a" with     {type: "a" };
        \\import { Y } from "./a"   with{ type: "b" /* comment*/};
        \\import { B } from "./a";
        \\
        \\export type G = A | B | C | D | E | F | Y | Z;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(undefined,
//         "import { A, B } from \"./a\";\nimport { C, E, F } from \"./a\" with { type: \"a\" };\nimport { A as D, Y } from \"./a\" with { type: \"b\" };\nimport { Z } from \"./z\";\n\nexport type G = A | B | C | D | E | F | Y | Z;",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

