const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionsJSDocNoCrash3" {
    const content =
        \\// @strict: true
        \\// @filename: index.ts
        \\class MssqlClient {
        \\  /**
        \\   *
        \\   * @param {Object} - args
        \\   * @param {String} - args.parentTable
        \\   * @returns {Promise<{upStatement/**/, downStatement}>}
        \\   */
        \\  async relationCreate(args) {}
        \\}
        \\
        \\export default MssqlClient;
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
//                     .Label =    "readonly",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestAddDeclareToFunction" {
    const content =
        \\/*1*/function parseInt(s/*2*/:string):number;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "2");
    _ = f.DeleteAtCaret(undefined, 7);
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "declare ");
}

test "TestFormatSelectionWithTrivia6" {
    const content =
        \\/*begin*/    // test comment
        \\/*end*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatSelection(undefined, "begin", "end");
    try f.VerifyCurrentFileContent(undefined, "// test comment\n");
}

test "TestCalledUnionsOfDissimilarTyeshaveGoodDisplay" {
    const content =
        \\declare const callableThing1:
        \\    | ((o1: {x: number}) => void)
        \\    | ((o1: {y: number}) => void)
        \\    ;
        \\
        \\callableThing1(/*1*/);
        \\
        \\declare const callableThing2:
        \\    | ((o1: {x: number}) => void)
        \\    | ((o2: {y: number}) => void)
        \\    ;
        \\
        \\callableThing2(/*2*/);
        \\
        \\declare const callableThing3:
        \\    | ((o1: {x: number}) => void)
        \\    | ((o2: {y: number}) => void)
        \\    | ((o3: {z: number}) => void)
        \\    | ((o4: {u: number}) => void)
        \\    | ((o5: {v: number}) => void)
        \\    ;
        \\
        \\callableThing3(/*3*/);
        \\
        \\declare const callableThing4:
        \\    | ((o1: {x: number}) => void)
        \\    | ((o2: {y: number}) => void)
        \\    | ((o3: {z: number}) => void)
        \\    | ((o4: {u: number}) => void)
        \\    | ((o5: {v: number}) => void)
        \\    | ((o6: {w: number}) => void)
        \\    ;
        \\
        \\callableThing4(/*4*/);
        \\
        \\declare const callableThing5: 
        \\    | (<U>(a1: U) => void)
        \\    | (() => void) 
        \\    ;
        \\
        \\callableThing5(/*5*/1)
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "callableThing1(o1: { x: number; } & { y: number; }): void"});
    _ = f.GoToMarker(undefined, "2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "callableThing2(arg0: { x: number; } & { y: number; }): void"});
    _ = f.GoToMarker(undefined, "3");
    // try f.VerifySignatureHelp(undefined, .{.Text = "callableThing3(arg0: { x: number; } & { y: number; } & { z: number; } & { u: number; } & { v: number; }): void"});
    _ = f.GoToMarker(undefined, "4");
    // try f.VerifySignatureHelp(undefined, .{.Text = "callableThing4(arg0: { x: number; } & { y: number; } & { z: number; } & { u: number; } & { v: number; } & { w: number; }): void"});
    _ = f.GoToMarker(undefined, "5");
    // try f.VerifySignatureHelp(undefined, .{.Text = "callableThing5(a1: number): void"});
}

test "TestSmartSelection_JSDocTags6" {
    const content =
        \\/**
        \\ * @template T
        \\ * @param {/**/T} x
        \\ * @return {T}
        \\ */
        \\function foo(x) {
        \\    return x;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSelectionRanges(undefined);
}

test "TestJsdocImplementsTagCompletion" {
    const content =
        \\// @lib: es5
        \\/** @implements {/**/} */
        \\class A {}
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
//             .Exact = CompletionGlobalTypesPlus(
//                 &.{
//                     "A",
//                 },
//             ),
//         },
//     });
}

test "TestFormattingInMultilineComments" {
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
    try f.VerifyCurrentLineContent(undefined, "    } else {");
}

test "TestJsxElementExtendsNoCrash1" {
    const content =
        \\// @filename: index.tsx
        \\<const T extends/>
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifySuggestionDiagnostics(undefined, null);
}

test "TestCompletionForStringLiteral_quotePreference4" {
    const content =
        \\type T = 0 | 1;
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
//                     .Label = "0",
//                 },
//                 &.{
//                     .Label = "1",
//                 },
//             },
//         },
//     });
}

test "TestCompletionPropertyShorthandForObjectLiteral4" {
    const content =
        \\// @lib: es5
        \\const foo = 1;
        \\const bar = 2;
        \\const obj: any = {
        \\  foo b/*1*/
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
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     "bar",
//                     "foo",
//                 }, false,
//             ),
//         },
//     });
}

test "TestGoToDefinitionYield1" {
    const content =
        \\function* /*end1*/gen() {
        \\    [|/*start1*/yield|] 0;
        \\}
        \\
        \\const /*end2*/genFunction = function*() {
        \\    [|/*start2*/yield|] 0;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "start1", "start2");
}

test "TestOrganizeImportsPathsUnicode1" {
    const content =
        \\import * as Ab from "./Ab";
        \\import * as _aB from "./_aB";
        \\import * as aB from "./aB";
        \\import * as _Ab from "./_Ab";
        \\
        \\console.log(_aB, _Ab, aB, Ab);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "import * as Ab from \"./Ab\";\nimport * as _Ab from \"./_Ab\";\nimport * as _aB from \"./_aB\";\nimport * as aB from \"./aB\";\n\nconsole.log(_aB, _Ab, aB, Ab);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSFalse,
//             .OrganizeImportsCollation =  lsutil.OrganizeImportsCollationOrdinal,
//         },
//     );
    // try f.VerifyOrganizeImports(undefined,
//         "import * as _aB from \"./_aB\";\nimport * as _Ab from \"./_Ab\";\nimport * as aB from \"./aB\";\nimport * as Ab from \"./Ab\";\n\nconsole.log(_aB, _Ab, aB, Ab);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSFalse,
//             .OrganizeImportsCollation =  lsutil.OrganizeImportsCollationUnicode,
//         },
//     );
}

test "TestReferenceToEmptyObject" {
    const content =
        \\// @lib: es5
        \\const obj = {}/*1*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestCompletionListInTypedObjectLiteralsWithPartialPropertyNames" {
    const content =
        \\interface MyPoint {
        \\    x1: number;
        \\    y1: number;
        \\}
        \\var p15: MyPoint = {
        \\    /**/
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
    _ = f.Insert(undefined, "x");
    // f.VerifyCompletions(undefined, null, &.{
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
    _ = f.Insert(undefined, "1");
    // f.VerifyCompletions(undefined, null, &.{
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
    _ = f.Insert(undefined, ": null,");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "y1",
//             },
//         },
//     });
}

test "TestImportNameCodeFix_require_UMD" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @module: commonjs
        \\// @esModuleInterop: false
        \\// @allowSyntheticDefaultImports: false
        \\// @Filename: umd.d.ts
        \\namespace Foo { function f() {} }
        \\export = Foo;
        \\export as namespace Foo;
        \\// @Filename: index.js
        \\Foo;
        \\module.exports = {};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "index.js");
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add import from \"./umd\"",
        .NewFileContent = "const Foo = require(\"./umd\");\n\nFoo;\nmodule.exports = {};",
        .Index = 0,
    });
}

test "TestCompletionEntryClassMembersWithInferredFunctionReturnType1" {
    const content =
        \\// @filename: /tokenizer.ts
        \\export default abstract class Tokenizer {
        \\  errorBuilder() {
        \\    return (pos: number, lineStart: number, curLine: number) => {};
        \\  }
        \\}
        \\// @filename: /expression.ts
        \\import Tokenizer from "./tokenizer.js";
        \\
        \\export default abstract class ExpressionParser extends Tokenizer {
        \\  /**/
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
//                 &.{
//                     .Label =      "errorBuilder",
//                     .InsertText = undefined("errorBuilder(): (pos: number, lineStart: number, curLine: number) => void {\n}"),
//                     .FilterText = undefined("errorBuilder"),
//                 },
//             },
//         },
//     });
}

test "TestGetOccurrencesAbstract01" {
    const content =
        \\[|abstract|] class Animal {
        \\    [|abstract|] prop1; // Does not compile
        \\    [|abstract|] abstract();
        \\    [|abstract|] walk(): void;
        \\    [|abstract|] makeSound(): void;
        \\}
        \\// Abstract class below should not get highlighted
        \\abstract class Foo {
        \\    abstract foo(): void;
        \\    abstract bar(): void;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestCompletionsDiscriminatedUnion" {
    const content =
        \\interface A { kind: "a"; a: number; }
        \\interface B { kind: "b"; b: number; }
        \\const c: A | B = { kind: "a", /**/ };
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
//             },
//         },
//     });
}

test "TestCodeFixClassImplementInterfaceAutoImports" {
    const content =
        \\// @Filename: types1.ts
        \\type A = {};
        \\export default A;
        \\// @Filename: types2.ts
        \\export type B = {};
        \\export type C = {};
        \\export type D<T> = {};
        \\// @Filename: interface.ts
        \\import A from './types1';
        \\import { B, C, D } from './types2';
        \\
        \\export interface Base {
        \\  a: Readonly<A> & { kind: "a"; };
        \\  b<T extends B = B>(p1: C): D<C>;
        \\}
        \\// @Filename: index.ts
        \\import { Base } from './interface';
        \\
        \\export class C implements Base {[| |]}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "index.ts");
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'Base'",
        .NewFileContent = "import { Base } from './interface';\nimport A from './types1';\nimport { B, C, D } from './types2';\n\nexport class C implements Base {\n    a: Readonly<A> & { kind: 'a'; };\n    b<T extends B = B>(p1: C): D<C> {\n        throw new Error('Method not implemented.');\n    }\n}",
        .Index = 0,
    });
}

test "TestAutoImportProvider9" {
    const content =
        \\// @lib: es5
        \\// @module: preserve
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\Lib1/**/
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{
        \\  "dependencies": {
        \\    "lib1": "*",
        \\    "lib2": "*",
        \\    "lib3": "*",
        \\    "lib4": "*",
        \\    "lib5": "*",
        \\    "lib6": "*",
        \\    "lib7": "*",
        \\    "lib8": "*",
        \\    "lib9": "*",
        \\    "lib10": "*",
        \\    "lib11": "*"
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/lib1/package.json
        \\{ "name": "lib1", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/lib1/index.d.ts
        \\export class Lib1 {}
        \\// @Filename: /home/src/workspaces/project/node_modules/lib2/package.json
        \\{ "name": "lib2", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/lib2/index.d.ts
        \\export class Lib2 {}
        \\// @Filename: /home/src/workspaces/project/node_modules/lib3/package.json
        \\{ "name": "lib3", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/lib3/index.d.ts
        \\export class Lib3 {}
        \\// @Filename: /home/src/workspaces/project/node_modules/lib4/package.json
        \\{ "name": "lib4", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/lib4/index.d.ts
        \\export class Lib4 {}
        \\// @Filename: /home/src/workspaces/project/node_modules/lib5/package.json
        \\{ "name": "lib5", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/lib5/index.d.ts
        \\export class Lib5 {}
        \\// @Filename: /home/src/workspaces/project/node_modules/lib6/package.json
        \\{ "name": "lib6", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/lib6/index.d.ts
        \\export class Lib6 {}
        \\// @Filename: /home/src/workspaces/project/node_modules/lib7/package.json
        \\{ "name": "lib7", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/lib7/index.d.ts
        \\export class Lib7 {}
        \\// @Filename: /home/src/workspaces/project/node_modules/lib8/package.json
        \\{ "name": "lib8", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/lib8/index.d.ts
        \\export class Lib8 {}
        \\// @Filename: /home/src/workspaces/project/node_modules/lib9/package.json
        \\{ "name": "lib9", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/lib9/index.d.ts
        \\export class Lib9 {}
        \\// @Filename: /home/src/workspaces/project/node_modules/lib10/package.json
        \\{ "name": "lib10", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/lib10/index.d.ts
        \\export class Lib10 {}
        \\// @Filename: /home/src/workspaces/project/node_modules/lib11/package.json
        \\{ "name": "lib11", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/lib11/index.d.ts
        \\export class Lib11 {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{}, null );
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{}, null );
    _ = f.InsertLine(undefined, "import {} from 'lib2';");
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"lib1"}, null );
}

test "TestCodeFixUnusedLabel_noSuggestionIfDisabled" {
    const content =
        \\// @allowUnusedLabels: true
        \\[|foo|]: while (true) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifySuggestionDiagnostics(undefined, null);
}

test "TestCompletionListClassThisJS" {
    const content =
        \\// @Filename: completionListClassThisJS.js
        \\// @allowJs: true
        \\/** @typedef {number} CallbackContext */
        \\class Foo {
        \\    bar() {
        \\       this/**/
        \\    }
        \\    /** @param {function (this: CallbackContext): any} cb */
        \\    baz(cb) {
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
//             .Includes = &.{
//                 &.{
//                     .Label =    "this",
//                     .Kind =     undefined(lsproto.CompletionItemKindKeyword),
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestAutoImportProvider_importsMap3" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "nodenext",
        \\    "lib": ["es5"],
        \\    "rootDir": "src",
        \\    "outDir": "dist"
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{
        \\  "type": "module",
        \\  "imports": {
        \\    "#internal/": "./dist/internal/"
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/src/internal/foo.ts
        \\export function something(name: string) {}
        \\// @Filename: /home/src/workspaces/project/src/a.ts
        \\something/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"#internal/foo.js"}, null );
}

test "TestInlayHintsVariableTypes1" {
    const content =
        \\class C {}
        \\namespace N { export class Foo {} }
        \\interface Foo {}
        \\const a = "a";
        \\const b = 1;
        \\const c = true;
        \\const d = {} as Foo;
        \\const e = <Foo>{};
        \\const f = {} as const;
        \\const g = (({} as const));
        \\const h = new C();
        \\const i = new N.C();
        \\const j = ((((new C()))));
        \\const k = { a: 1, b: 1 };
        \\const l = ((({ a: 1, b: 1 })));
        \\ const m = () => 123;
        \\ const n;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayVariableTypeHints = core.TSTrue}});
}

test "TestReturnRecursiveType" {
    const content =
        \\interface MyInt {
        \\    (): void;
        \\}
        \\function MyFn() { return <MyInt>MyFn; }
        \\var My/**/Var = MyFn();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "var MyVar: MyInt", "");
}

test "TestNavigationBarItemsClass4" {
    const content =
        \\// @allowJs: true
        \\// @filename: /foo.js
        \\class Foo {}
        \\function Foo() {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestRenameDefaultLibDontWork" {
    const content =
        \\// @Filename: file1.ts
        \\[|var [|{| "contextRangeIndex": 0 |}test|] = "foo";|]
        \\console.log([|test|]);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1]);
}

test "TestFindAllRefsForDefaultExport02" {
    const content =
        \\/*1*/export default function /*2*/DefaultExportedFunction() {
        \\    return /*3*/DefaultExportedFunction;
        \\}
        \\
        \\var x: typeof /*4*/DefaultExportedFunction;
        \\
        \\var y = /*5*/DefaultExportedFunction();
        \\
        \\/*6*/namespace /*7*/DefaultExportedFunction {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7");
}

test "TestRenameForDefaultExport07" {
    const content =
        \\// @Filename: foo.ts
        \\export default function /**/[|DefaultExportedFunction|]() {
        \\    return DefaultExportedFunction
        \\}
        \\/**
        \\ *  Commenting DefaultExportedFunction
        \\ */
        \\
        \\var x: typeof DefaultExportedFunction;
        \\
        \\var y = DefaultExportedFunction();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyRenameSucceeded(undefined, null );
}

test "TestInlayHintsInteractiveImportType1" {
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
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayVariableTypeHints = core.TSTrue}});
}

test "TestQuickInfoTypeOfThisInStatics" {
    const content =
        \\class C {
        \\    static foo() {
        \\        var /*1*/r = this;
        \\    }
        \\    static get x() {
        \\        var /*2*/r = this;
        \\        return 1;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(local var) r: typeof C", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(local var) r: typeof C", "");
}

test "TestRenameDestructuringDeclarationInForOf" {
    const content =
        \\interface I {
        \\    [|[|{| "contextRangeIndex": 0 |}property1|]: number;|]
        \\    property2: string;
        \\}
        \\var elems: I[];
        \\
        \\for ([|let { [|{| "contextRangeIndex": 2 |}property1|] } of elems|]) {
        \\    [|property1|]++;
        \\}
        \\for ([|let { [|{| "contextRangeIndex": 5 |}property1|]: p2 } of elems|]) {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[6], f.Ranges()[3], f.Ranges()[4]);
}

test "TestReferencesForContextuallyTypedUnionProperties2" {
    const content =
        \\interface A {
        \\    a: number;
        \\    common: string;
        \\}
        \\
        \\interface B {
        \\    /*1*/b: number;
        \\    common: number;
        \\}
        \\
        \\// Assignment
        \\var v1: A | B = { a: 0, common: "" };
        \\var v2: A | B = { b: 0, common: 3 };
        \\
        \\// Function call
        \\function consumer(f:  A | B) { }
        \\consumer({ a: 0, b: 0, common: 1 });
        \\
        \\// Type cast
        \\var c = <A | B> { common: 0, b: 0 };
        \\
        \\// Array literal
        \\var ar: Array<A|B> = [{ a: 0, common: "" }, { b: 0, common: 0 }];
        \\
        \\// Nested object literal
        \\var ob: { aorb: A|B } = { aorb: { b: 0, common: 0 } };
        \\
        \\// Widened type
        \\var w: A|B = { b:undefined, common: undefined };
        \\
        \\// Untped -- should not be included
        \\var u1 = { a: 0, b: 0, common: "" };
        \\var u2 = { b: 0, common: 0 };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestGoToDefinitionOverriddenMember26" {
    const content =
        \\// @strict: true
        \\// @target: esnext
        \\// @lib: esnext
        \\const prop: symbol = Symbol();
        \\
        \\abstract class A {}
        \\
        \\export class B extends A {
        \\  [|/*1*/override|] [prop]() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestMemberCompletionFromFunctionCall" {
    const content =
        \\declare interface ifoo {
        \\    text: (value: any) => ifoo;
        \\}
        \\declare var foo: ifoo;
        \\foo.text(function() { })/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, ".");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "text",
//             },
//         },
//     });
}

test "TestPromiseTyping1" {
    const content =
        \\interface IPromise<T> {
        \\    then<U>(success: (value: T) => IPromise<U>, error?: (error: any) => IPromise<U>, progress?: (progress: any) => void ): IPromise<U>;
        \\    then<U>(success: (value: T) => IPromise<U>, error?: (error: any) => U, progress?: (progress: any) => void ): IPromise<U>;
        \\    then<U>(success: (value: T) => U, error?: (error: any) => IPromise<U>, progress?: (progress: any) => void ): IPromise<U>;
        \\    then<U>(success: (value: T) => U, error?: (error: any) => U, progress?: (progress: any) => void ): IPromise<U>;
        \\    done? <U>(success: (value: T) => any, error?: (error: any) => any, progress?: (progress: any) => void ): void;
        \\}
        \\var p1: IPromise<string>;
        \\var p/*1*/2 = p1.then(function (x/*2*/x) {
        \\    return xx;
        \\});
        \\p2.then(function (x/*3*/x) {
        \\} );
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "var p2: IPromise<string>", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(parameter) xx: string", "");
    try f.VerifyQuickInfoAt(undefined, "3", "(parameter) xx: string", "");
}

test "TestGoToImplementation_satisfies" {
    const content =
        \\// @filename: /a.ts
        \\interface /*def*/I {
        \\    foo: string;
        \\}
        \\
        \\function f() {
        \\    const foo = { foo: '' } satisfies [|I|];
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "def");
}

test "TestUnusedConstantInFunction1" {
    const content =
        \\// @noUnusedLocals: true
        \\[| function f1 () {
        \\    const x: string = "x";
        \\} |]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "function f1 () {\n}", false, 0, 0);
}

test "TestFormatTypeAnnotation2" {
    const content =
        \\function foo(x : number, y ?: string) : number {}
        \\interface Foo {
        \\    x : number;
        \\    y ?: number;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "function foo(x: number, y?: string): number { }\ninterface Foo {\n    x: number;\n    y?: number;\n}");
}

test "TestQuickInfoMeaning" {
    const content =
        \\// @lib: es5
        \\// @module: commonjs
        \\// @Filename: foo.d.ts
        \\declare const [|/*foo_value_declaration*/foo: number|];
        \\[|declare module "foo_module" {
        \\    interface /*foo_type_declaration*/I { x: number; y: number }
        \\    export = I;
        \\}|]
        \\// @Filename: foo_user.ts
        \\///<reference path="foo.d.ts" />
        \\[|import foo = require("foo_module");|]
        \\const x = foo/*foo_value*/;
        \\const i: foo/*foo_type*/ = { x: 1, y: 2 };
        \\// @Filename: bar.d.ts
        \\[|declare interface /*bar_type_declaration*/bar { x: number; y: number }|]
        \\[|declare module "bar_module" {
        \\    const /*bar_value_declaration*/x: number;
        \\    export = x;
        \\}|]
        \\// @Filename: bar_user.ts
        \\///<reference path="bar.d.ts" />
        \\[|import bar = require("bar_module");|]
        \\const x = bar/*bar_value*/;
        \\const i: bar/*bar_type*/ = { x: 1, y: 2 };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    // try f.VerifyWorkspaceSymbol(undefined, []*.{
//         .{
//             .Pattern =     "foo",
//             .Preferences = null,
//             .Exact = undefined([]*.{
//                 .{
//                     .Name =     "foo",
//                     .Kind =     lsproto.SymbolKindVariable,
//                     .Location = f.Ranges()[0].LSLocation(),
//                 },
//                 .{
//                     .Name =     "foo",
//                     .Kind =     lsproto.SymbolKindVariable,
//                     .Location = f.Ranges()[2].LSLocation(),
//                 },
//                 .{
//                     .Name =     "foo_module",
//                     .Kind =     lsproto.SymbolKindNamespace,
//                     .Location = f.Ranges()[1].LSLocation(),
//                 },
//             }),
//         },
//     });
    _ = f.GoToMarker(undefined, "foo_value");
    try f.VerifyQuickInfoIs(undefined, "const foo: number", "");
    _ = f.GoToMarker(undefined, "foo_type");
    try f.VerifyQuickInfoIs(undefined, "(alias) interface foo\nimport foo = require(\"foo_module\")", "");
    // try f.VerifyWorkspaceSymbol(undefined, []*.{
//         .{
//             .Pattern =     "bar",
//             .Preferences = null,
//             .Exact = undefined([]*.{
//                 .{
//                     .Name =     "bar",
//                     .Kind =     lsproto.SymbolKindInterface,
//                     .Location = f.Ranges()[3].LSLocation(),
//                 },
//                 .{
//                     .Name =     "bar",
//                     .Kind =     lsproto.SymbolKindVariable,
//                     .Location = f.Ranges()[5].LSLocation(),
//                 },
//                 .{
//                     .Name =     "bar_module",
//                     .Kind =     lsproto.SymbolKindNamespace,
//                     .Location = f.Ranges()[4].LSLocation(),
//                 },
//             }),
//         },
//     });
    _ = f.GoToMarker(undefined, "bar_value");
    try f.VerifyQuickInfoIs(undefined, "(alias) const bar: number\nimport bar = require(\"bar_module\")", "");
    _ = f.GoToMarker(undefined, "bar_type");
    try f.VerifyQuickInfoIs(undefined, "interface bar", "");
    // try f.VerifyBaselineGoToDefinition(undefined, false, "foo_value", "foo_type", "bar_value", "bar_type");
}

test "TestGetOccurrencesIsDefinitionOfNumberNamedProperty" {
    const content =
        \\let o = { /*1*/1: 12 };
        \\let y = o[/*2*/1];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestGoToDefinitionConstructorOverloads" {
    const content =
        \\class ConstructorOverload {
        \\    [|/*constructorOverload1*/constructor|]();
        \\    /*constructorOverload2*/constructor(foo: string);
        \\    /*constructorDefinition*/constructor(foo: any)  { }
        \\}
        \\
        \\var constructorOverload = new [|/*constructorOverloadReference1*/ConstructorOverload|]();
        \\var constructorOverload = new [|/*constructorOverloadReference2*/ConstructorOverload|]("foo");
        \\
        \\class Extended extends ConstructorOverload {
        \\    readonly name = "extended";
        \\}
        \\var extended1 = new [|/*extendedRef1*/Extended|]();
        \\var extended2 = new [|/*extendedRef2*/Extended|]("foo");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "constructorOverloadReference1", "constructorOverloadReference2", "constructorOverload1", "extendedRef1", "extendedRef2");
}

test "TestSyntacticClassificationsForOfKeyword" {
    const content =
        \\for (var of of of) { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "variable.declaration", .Text = "of"},
//         .{.Type = "variable", .Text = "of"},
//     });
}

test "TestTsxCompletion3" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        div: { one; two; }
        \\    }
        \\}
        \\<div one={1} /**//>;
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
//                 "two",
//             },
//         },
//     });
}

test "TestReferencesForUnionProperties" {
    const content =
        \\interface One {
        \\    common: { /*one*/a: number; };
        \\}
        \\
        \\interface Base {
        \\    /*base*/a: string;
        \\    b: string;
        \\}
        \\
        \\interface HasAOrB extends Base {
        \\    a: string;
        \\    b: string;
        \\}
        \\
        \\interface Two {
        \\    common: HasAOrB;
        \\}
        \\
        \\var x : One | Two;
        \\
        \\x.common./*x*/a;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "one", "base", "x");
}

test "TestOrganizeImports10" {
    const content =
        \\// @Filename: /module.ts
        \\import type { ZodType } from './declaration';
        \\
        \\/** Intended to be used in combination with {@link ZodType} */
        \\export function fun() { /* ... */ }
        \\// @Filename: /declaration.ts
        \\ type ZodType = {};
        \\ export type { ZodType }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "import type { ZodType } from './declaration';\n\n/** Intended to be used in combination with {@link ZodType} */\nexport function fun() { /* ... */ }",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestCodeFixClassImplementInterfaceWithNegativeNumber" {
    const content =
        \\interface X { value: -1 | 0 | 1; }
        \\class Y implements X { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFixAvailable(undefined, &.{"Implement interface 'X'"});
}

test "TestSignatureHelpJSMissingIdentifier" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: test.js
        \\log(/**/)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyNoSignatureHelpForMarkers(undefined, "");
}

test "TestSpecialIntersectionsOrderIndependent" {
    const content =
        \\declare function a(arg: 'test' | (string & {})): void
        \\a('/*1*/')
        \\declare function b(arg: 'test' | ({} & string)): void
        \\b('/*2*/')
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
//                 "test",
//             },
//         },
//     });
}

test "TestAutoImportReExportFromAmbientModule" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "commonjs",
        \\    "types": ["*"],
        \\    "lib": ["es5"]
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/node/index.d.ts
        \\declare module "fs" {
        \\  export function accessSync(path: string): void;
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/fs-extra/index.d.ts
        \\export * from "fs";
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\access/**/
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
//                     .Label = "accessSync",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "fs",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//                 &.{
//                     .Label = "accessSync",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "fs-extra",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "accessSync",
//         .Source =      "fs-extra",
//         .Description = "Add import from \"fs-extra\"",
//         .NewFileContent = undefined("import { accessSync } from \"fs-extra\";\n\naccess"),
//         .AutoImportFix = &.{
//             .ModuleSpecifier = "fs-extra",
//         },
//     });
}

test "TestSemicolonFormattingAfterArrayLiteral" {
    const content =
        \\[1,2]/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, ";");
    try f.VerifyCurrentLineContent(undefined, "[1, 2];");
}

test "TestCodeFixAddOptionalParam18" {
    const content =
        \\[|function f(a: number, c: string) {}|]
        \\f(1, 1, "");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined, "addOptionalParam");
}

test "TestQuickInfoOnUnResolvedBaseConstructorSignature" {
    const content =
        \\class baseClassWithConstructorParameterSpecifyingType {
        \\    constructor(loading?: boolean) {
        \\    }
        \\}
        \\class genericBaseClassInheritingConstructorFromBase<TValue> extends baseClassWithConstructorParameterSpecifyingType {
        \\}
        \\class classInheritingSpecializedClass extends genericBaseClassInheritingConstructorFromBase<string> {
        \\}
        \\new class/*1*/InheritingSpecializedClass();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyQuickInfoExists(undefined);
}

test "TestExplainFilesNodeNextWithTypesReference" {
    const content =
        \\// @Filename: /node_modules/react-hook-form/package.json
        \\{
        \\  "name": "react-hook-form",
        \\  "main": "dist/index.cjs.js",
        \\  "module": "dist/index.esm.js",
        \\  "types": "dist/index.d.ts",
        \\  "exports": {
        \\    "./package.json": "./package.json",
        \\    ".": {
        \\      "import": "./dist/index.esm.js",
        \\      "require": "./dist/index.cjs.js",
        \\      "types": "./dist/index.d.ts"
        \\    }
        \\  }
        \\}
        \\// @Filename: /node_modules/react-hook-form/dist/index.cjs.js
        \\module.exports = {};
        \\// @Filename: /node_modules/react-hook-form/dist/index.esm.js
        \\export function useForm() {}
        \\// @Filename: /node_modules/react-hook-form/dist/index.d.ts
        \\/// <reference types="react/**/" />
        \\export type Foo = React.Whatever;
        \\export function useForm(): any;
        \\// @Filename: /node_modules/react/index.d.ts
        \\declare namespace JSX {}
        \\declare namespace React { export interface Whatever {} }
        \\// @Filename: /tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "module": "nodenext",
        \\        "explainFiles": true
        \\    }
        \\    "files": ["./index.ts"]
        \\}
        \\// @Filename: /index.ts
        \\import { useForm } from "react-hook-form";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestCrossFileQuickInfoExportedTypeDoesNotUseImportType" {
    const content =
        \\// @Filename: b.ts
        \\export interface B {}
        \\export function foob(): {
        \\    x: B,
        \\    y: B
        \\} {
        \\    return null as any;
        \\}
        \\// @Filename: a.ts
        \\import { foob } from "./b";
        \\const thing/*1*/ = foob(/*2*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "const thing: {\n    x: B;\n    y: B;\n}", "");
    _ = f.GoToMarker(undefined, "2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "foob(): { x: B; y: B; }"});
}

test "TestCompletionsPathsJsonModuleWithoutResolveJsonModule" {
    const content =
        \\// @resolveJsonModule: false
        \\// @Filename: /project/test.json
        \\not read
        \\// @Filename: /project/index.ts
        \\import { } from ".//**/";
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

test "TestGetJavaScriptSyntacticDiagnostics02" {
    const content =
        \\// @lib: es5
        \\// @allowJs: true
        \\// @Filename: b.js
        \\var a = "a";
        \\var b: boolean = true;
        \\function foo(): string { }
        \\var var = "c";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestGoToDefinition_mappedType" {
    const content =
        \\interface I { /*def*/m(): void; };
        \\declare const i: { [K in "m"]: I[K] };
        \\i.[|/*ref*/m|]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "ref");
}

test "TestAutoImportPackageJsonImports_ts" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#thing": "./src/something.ts"
        \\  }
        \\}
        \\// @Filename: /src/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /a.ts
        \\something/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"#thing"}, null );
}

test "TestCodeFixMissingTypeAnnotationOnExports" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\function foo() { return 42; }
        \\export const g = foo();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add annotation of type 'number'",
        .NewFileContent = "function foo() { return 42; }\nexport const g: number = foo();",
        .Index = 0,
    });
}

test "TestRenameLabel2" {
    const content =
        \\/**/foo: {
        \\    break foo;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , "");
}

test "TestQuickinfoVerbosityTruncation1" {
    const content =
        \\type Str = string | {};
        \\type FooType = Str | number;
        \\type Sym = symbol | (() => void);
        \\type BarType = Sym | boolean;
        \\interface LotsOfProps {
        \\    someLongPropertyName1: Str;
        \\    someLongPropertyName2: FooType;
        \\    someLongPropertyName3: Sym;
        \\    someLongPropertyName4: BarType;
        \\    someLongPropertyName5: Str;
        \\    someLongPropertyName6: FooType;
        \\    someLongPropertyName7: Sym;
        \\    someLongPropertyName8: BarType;
        \\    someLongMethodName1(a: FooType, b: BarType): Sym;
        \\    someLongPropertyName9: Str;
        \\    someLongPropertyName10: FooType;
        \\    someLongPropertyName11: Sym;
        \\    someLongPropertyName12: BarType;
        \\    someLongPropertyName13: Str;
        \\    someLongPropertyName14: FooType;
        \\    someLongPropertyName15: Sym;
        \\    someLongPropertyName16: BarType;
        \\    someLongMethodName2(a: FooType, b: BarType): Sym;
        \\}
        \\const obj1/*o1*/: LotsOfProps = undefined as any as LotsOfProps;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"o1" = .{0, 1}});
}

test "TestJavascriptModules25" {
    const content =
        \\// @allowJs: true
        \\// @Filename: mod.js
        \\function foo() { return {a: true}; }
        \\module.exports.a = foo;
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
//             .Includes = &.{
//                 "a",
//             },
//         },
//     });
}

test "TestConstructorFindAllReferences3" {
    const content =
        \\export class C {
        \\    /**/constructor() { }
        \\    public foo() { }
        \\}
        \\
        \\new C().foo();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestQuickInfoForShorthandProperty" {
    const content =
        \\// @strict: false
        \\var name1 = undefined, id1 = undefined;
        \\var /*obj1*/obj1 = {/*name1*/name1, /*id1*/id1};
        \\var name2 = "Hello";
        \\var id2 = 10000;
        \\var /*obj2*/obj2 = {/*name2*/name2, /*id2*/id2};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "obj1", "var obj1: {\n    name1: any;\n    id1: any;\n}", "");
    try f.VerifyQuickInfoAt(undefined, "name1", "(property) name1: any", "");
    try f.VerifyQuickInfoAt(undefined, "id1", "(property) id1: any", "");
    try f.VerifyQuickInfoAt(undefined, "obj2", "var obj2: {\n    name2: string;\n    id2: number;\n}", "");
    try f.VerifyQuickInfoAt(undefined, "name2", "(property) name2: string", "");
    try f.VerifyQuickInfoAt(undefined, "id2", "(property) id2: number", "");
}

test "TestQuickInfoOnMergedInterfacesWithIncrementalEdits" {
    const content =
        \\// @strict: false
        \\namespace MM {
        \\    interface B<T> {
        \\        foo: number;
        \\    }
        \\    interface B<T> {
        \\        bar: string;
        \\    }
        \\    var b: B<string>;
        \\    var r3 = b.foo; // number
        \\    var r/*2*/4 = b.b/*1*/ar; // string
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyQuickInfoIs(undefined, "(property) B<string>.bar: string", "");
    _ = f.DeleteAtCaret(undefined, 1);
    _ = f.Insert(undefined, "z");
    try f.VerifyQuickInfoIs(undefined, "any", "");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
    _ = f.Backspace(undefined, 1);
    _ = f.Insert(undefined, "a");
    try f.VerifyQuickInfoIs(undefined, "(property) B<string>.bar: string", "");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyQuickInfoIs(undefined, "var r4: string", "");
    try f.VerifyNoErrors(undefined);
}

test "TestTsxQuickInfo1" {
    const content =
        \\//@Filename: file.tsx
        \\var x1 = <di/*1*/v></di/*2*/v>
        \\class MyElement {}
        \\var z = <My/*3*/Element></My/*4*/Element>
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "any", "");
    try f.VerifyQuickInfoAt(undefined, "2", "any", "");
    try f.VerifyQuickInfoAt(undefined, "3", "class MyElement", "");
    try f.VerifyQuickInfoAt(undefined, "4", "class MyElement", "");
}

test "TestGetOutliningSpansForUnbalancedRegion" {
    const content =
        \\// top-heavy region balance
        \\// #region unmatched
        \\
        \\[|// #region matched
        \\
        \\// #endregion matched|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOutliningSpans(undefined, lsproto.FoldingRangeKindRegion);
}

test "TestGoToTypeDefinitionAliases" {
    const content =
        \\// @Filename: goToTypeDefinitioAliases_module1.ts
        \\interface /*definition*/I {
        \\    p;
        \\}
        \\export {I as I2};
        \\// @Filename: goToTypeDefinitioAliases_module2.ts
        \\import {I2 as I3} from "./goToTypeDefinitioAliases_module1";
        \\var v1: I3;
        \\export {v1 as v2};
        \\// @Filename: goToTypeDefinitioAliases_module3.ts
        \\import {/*reference1*/v2 as v3} from "./goToTypeDefinitioAliases_module2";
        \\/*reference2*/v3;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToTypeDefinition(undefined, "reference1", "reference2");
}

test "TestFindAllReferencesOfConstructor_badOverload" {
    const content =
        \\class C {
        \\    /*1*/constructor(n: number);
        \\    /*2*/constructor(){}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestCompletionsAtGenericTypeArguments" {
    const content =
        \\// @lib: es5
        \\class Foo<T1, T2> {}
        \\const foo = new Foo</*1*/, /*2*/,
        \\
        \\function foo<T1, T2>() {}
        \\const f = foo</*3*/, /*4*/,
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
//             .Exact = CompletionGlobalTypesPlus(
//                 &.{
//                     "Foo",
//                 },
//             ),
//         },
//     });
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalTypesPlus(
//                 &.{
//                     "Foo",
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
//             .Exact = CompletionGlobalTypesPlus(
//                 &.{
//                     "Foo",
//                 },
//             ),
//         },
//     });
    // f.VerifyCompletions(undefined, "4", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalTypesPlus(
//                 &.{
//                     "Foo",
//                 },
//             ),
//         },
//     });
}

test "TestImportNameCodeFix_noDestructureNonObjectLiteral" {
    const content =
        \\// @lib: es5
        \\// @target: es2015
        \\// @strict: true
        \\// @esModuleInterop: true
        \\// @Filename: /array.ts
        \\declare const arr: number[];
        \\export = arr;
        \\// @Filename: /class-instance-member.ts
        \\class C { filter() {} }
        \\export = new C();
        \\// @Filename: /object-literal.ts
        \\declare function filter(): void;
        \\export = { filter };
        \\// @Filename: /jquery.d.ts
        \\interface JQueryStatic {
        \\  filter(): void;
        \\}
        \\declare const $: JQueryStatic;
        \\export = $;
        \\// @Filename: /jquery.js
        \\module.exports = {};
        \\// @Filename: /index.ts
        \\filter/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"./object-literal", "./jquery"}, null );
}

test "TestImportStatementCompletions_noSnippet" {
    const content =
        \\// @Filename: /mod.ts
        \\export const foo = 0;
        \\// @Filename: /index0.ts
        \\[|import f/**/|]
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
//                     .Label =      "foo",
//                     .InsertText = undefined("import { foo } from \"./mod\";"),
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./mod",
//                         },
//                     },
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "foo",
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

test "TestCompletionsImport_default_exportDefaultIdentifier" {
    const content =
        \\// @module: esnext
        \\// @Filename: /a.ts
        \\const foo = 0;
        \\export default foo;
        \\// @Filename: /b.ts
        \\f/**/;
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
//             .Includes = &.{
//                 &.{
//                     .Label = "foo",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./a",
//                         },
//                     },
//                     .Detail =              undefined("(alias) const foo: 0\nexport default foo"),
//                     .Kind =                undefined(lsproto.CompletionItemKindVariable),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "foo",
//         .Source =      "./a",
//         .Description = "Add import from \"./a\"",
//         .NewFileContent = undefined("import foo from \"./a\";\n\nf;"),
//     });
}

test "TestDocumentHighlights_filesToSearch" {
    const content =
        \\// @Filename: /a.ts
        \\export const [|x|] = 0;
        \\// @Filename: /b.ts
        \\import { [|x|] } from "./a";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestGoToImplementationEnum_01" {
    const content =
        \\enum [|Foo|] {
        \\    Foo1 = function initializer() { return 5 } (),
        \\    Foo2 = 6
        \\}
        \\
        \\Fo/*reference*/o;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "reference");
}

test "TestOutliningSpansForImportsAndExports" {
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
    // try f.VerifyOutliningSpans(undefined);
}

test "TestGetOccurrencesAbstract02" {
    const content =
        \\// Not valid TS (abstract methods can only appear in abstract classes)
        \\class Animal {
        \\    [|abstract|] walk(): void;
        \\    [|abstract|] makeSound(): void;
        \\}
        \\// abstract cannot appear here, won't get highlighted
        \\let c = /*1*/abstract class Foo {
        \\    /*2*/abstract foo(): void;
        \\    abstract bar(): void;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , "1", "2");
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestSideEffectImportsSuggestion1" {
    const content =
        \\// @allowJs: true
        \\// @noEmit: true
        \\// @module: commonjs
        \\// @noUncheckedSideEffectImports: true
        \\// @filename: moduleA/a.js
        \\import "b";
        \\import "c";
        \\// @filename: node_modules/b.ts
        \\var a = 10;
        \\// @filename: node_modules/c.js
        \\exports.a = 10;
        \\c = 10;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifySuggestionDiagnostics(undefined, null);
}

test "TestQuickInfoSalsaMethodsOnAssignedFunctionExpressions" {
    const content =
        \\// @allowJs: true
        \\// @Filename: something.js
        \\var C = function () { }
        \\/**
        \\ * The prototype method.
        \\ * @param {string} a Parameter definition.
        \\ */
        \\function f(a) {}
        \\C.prototype.m = f;
        \\
        \\var x = new C();
        \\x/*1*/.m();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestFormattingArrayLiteral" {
    const content =
        \\/*1*/x= [];
        \\y = [
        \\/*2*/           1,
        \\/*3*/  2
        \\/*4*/ ];
        \\
        \\z = [[
        \\/*5*/  1,
        \\/*6*/             2
        \\/*7*/      ]  ];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "x = [];");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "    1,");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "    2");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "];");
    _ = f.GoToMarker(undefined, "5");
    try f.VerifyCurrentLineContent(undefined, "    1,");
    _ = f.GoToMarker(undefined, "6");
    try f.VerifyCurrentLineContent(undefined, "    2");
    _ = f.GoToMarker(undefined, "7");
    try f.VerifyCurrentLineContent(undefined, "]];");
}

test "TestTsxCompletion5" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        div: { ONE: string; TWO: number; }
        \\    }
        \\}
        \\var x = <div ONE/**//>;
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
//                 "ONE",
//                 "TWO",
//             },
//         },
//     });
}

test "TestImportCompletions_importsMap4" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "nodenext",
        \\    "lib": ["es5"],
        \\    "rootDir": "src",
        \\    "outDir": "dist"
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{
        \\  "type": "module",
        \\  "imports": {
        \\    "#is-browser": {
        \\      "types": "./dist/env/browser.d.ts",
        \\      "default": "./dist/env/browser.js"
        \\    }
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/src/env/browser.ts
        \\export const isBrowser = true;
        \\// @Filename: /home/src/workspaces/project/src/a.ts
        \\import {} from "/*1*/";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyCompletions(undefined, &.{"1"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "#is-browser",
//             },
//         },
//     });
}

test "TestPromiseTyping2" {
    const content =
        \\interface IPromise<T> {
        \\    then<U>(success?: (value: T) => IPromise<U>, error?: (error: any) => IPromise<U>, progress?: (progress: any) => void ): IPromise<U>;
        \\    then<U>(success?: (value: T) => IPromise<U>, error?: (error: any) => U, progress?: (progress: any) => void ): IPromise<U>;
        \\    then<U>(success?: (value: T) => U, error?: (error: any) => IPromise<U>, progress?: (progress: any) => void ): IPromise<U>;
        \\    then<U>(success?: (value: T) => U, error?: (error: any) => U, progress?: (progress: any) => void ): IPromise<U>;
        \\    done? <U>(success?: (value: T) => any, error?: (error: any) => any, progress?: (progress: any) => void ): void;
        \\}
        \\var p1: IPromise<number> = null;
        \\p/*1*/1.then(function (x/*2*/x) { }); 
        \\var p/*3*/2 = p1.then(function (x/*4*/x) { return "hello"; })
        \\var p/*5*/3 = p2.then(function (x/*6*/x) {
        \\    return x/*7*/x;
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "var p1: IPromise<number>", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(parameter) xx: number", "");
    try f.VerifyQuickInfoAt(undefined, "3", "var p2: IPromise<string>", "");
    try f.VerifyQuickInfoAt(undefined, "4", "(parameter) xx: number", "");
    try f.VerifyQuickInfoAt(undefined, "5", "var p3: IPromise<string>", "");
    try f.VerifyQuickInfoAt(undefined, "6", "(parameter) xx: string", "");
    try f.VerifyQuickInfoAt(undefined, "7", "(parameter) xx: string", "");
}

test "TestCompletionListKeywords" {
    const content =
        \\// @noLib: true
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
//                 &.{}, true,
//             ),
//         },
//     });
}

test "TestTsxCompletion10" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        div: { ONE: string; TWO: number; }
        \\    }
        \\}
        \\var x1 = <div><//**/
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
//                 "div>",
//             },
//         },
//     });
}

test "TestJsDocPropertyDescription10" {
    const content =
        \\class MultipleClass {
        \\    /** Something generic */
        \\    [key: number | symbol | 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "multipleClass", "any", "");
}

test "TestCodeFixInferFromFunctionUsage" {
    const content =
        \\// @stableTypeOrdering: true
        \\// @noImplicitAny: true
        \\function wrap( [| arr |] ) {
        \\     arr.other(function (a: number, b: number) { return a < b ? -1 : 1 });
        \\ }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "arr: { other: (arg0: (a: number, b: number) => -1 | 1) => void; }", false, 0, 0);
}

test "TestQuickInfoForObjectBindingElementName05" {
    const content =
        \\interface A {
        \\    /**
        \\     * A description of a
        \\     */
        \\    a: number;
        \\}
        \\interface B {
        \\    a: string;
        \\}
        \\
        \\function f({ a }: A | B) {
        \\    a/**/;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestQuickInfoForContextuallyTypedParameters" {
    const content =
        \\declare function foo1<T>(obj: T, settings: (row: T) => { value: string, func?: Function }): void;
        \\
        \\foo1(new Error(),
        \\    o/*1*/ => ({
        \\        value: o.name,
        \\        func: x => 'foo'
        \\    })
        \\);
        \\
        \\declare function foo2<T>(settings: (row: T) => { value: string, func?: Function }, obj: T): void;
        \\
        \\foo2(o/*2*/ => ({
        \\        value: o.name,
        \\        func: x => 'foo'
        \\    }),
        \\    new Error(),
        \\);
        \\
        \\declare function foof<T extends { name: string }, U extends keyof T>(settings: (row: T) => { value: T[U], func?: Function }, obj: T, key: U): U;
        \\
        \\function q<T extends { name: string }>(x: T): T["name"] {
        \\    return foof/*3*/(o => ({ value: o.name, func: x => 'foo' }), x, "name");
        \\}
        \\
        \\foof/*4*/(o => ({ value: o.name, func: x => 'foo' }), new Error(), "name");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(parameter) o: Error", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(parameter) o: Error", "");
    try f.VerifyQuickInfoAt(undefined, "3", "function foof<T, \"name\">(settings: (row: T) => {\n    value: T[\"name\"];\n    func?: Function;\n}, obj: T, key: \"name\"): \"name\"", "");
    try f.VerifyQuickInfoAt(undefined, "4", "function foof<Error, \"name\">(settings: (row: Error) => {\n    value: string;\n    func?: Function;\n}, obj: Error, key: \"name\"): \"name\"", "");
}

test "TestUnclosedCommentsInConstructor" {
    const content =
        \\class Foo {
        \\    constructor(/* /**/) { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "", null);
}

test "TestQuickInfoForRequire" {
    const content =
        \\//@Filename: AA/BB.ts
        \\export class a{}
        \\//@Filename: quickInfoForRequire_input.ts
        \\import a = require("./AA/B/*1*/B");
        \\import b = require(
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyQuickInfoIs(undefined, "module a", "");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyQuickInfoIs(undefined, "module a", "");
}

test "TestCompletionListOnPrivateVariableInModule" {
    const content =
        \\namespace Foo {     var testing = "";     test/**/ }
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
//                     .Label =  "testing",
//                     .Detail = undefined("var testing: string"),
//                 },
//             },
//         },
//     });
}

test "TestGoToTypeDefinition_returnType" {
    const content =
        \\interface /*I*/I { x: number; }
        \\interface /*J*/J { y: number; }
        \\
        \\function f0(): I { return { x: 0 }; }
        \\
        \\type T = /*T*/(i: I) => I;
        \\const f1: T = i => ({ x: i.x + 1 });
        \\
        \\const f2 = (i: I): I => ({ x: i.x + 1 });
        \\
        \\const f3 = (i: I) => (/*f3Def*/{ x: i.x + 1 });
        \\
        \\const f4 = (i: I) => i;
        \\
        \\const f5 = /*f5Def*/(i: I): I | J => ({ x: i.x + 1 });
        \\
        \\const f6 = (i: I, j: J, b: boolean) => b ? i : j;
        \\
        \\const /*f7Def*/f7 = (i: I) => {};
        \\
        \\function f8(i: I): I;
        \\function f8(j: J): J;
        \\function /*f8Def*/f8(ij: any): any { return ij; }
        \\
        \\/*f0*/f0();
        \\/*f1*/f1();
        \\/*f2*/f2();
        \\/*f3*/f3();
        \\/*f4*/f4();
        \\/*f5*/f5();
        \\/*f6*/f6();
        \\/*f7*/f7();
        \\/*f8*/f8();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToTypeDefinition(undefined, "f0", "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8");
}

test "TestQuickInfoGenericTypeArgumentInference1" {
    const content =
        \\// @strict: false
        \\namespace Underscore {
        \\    export interface Iterator<T, U> {
        \\        (value: T, index: any, list: any): U;
        \\    }
        \\
        \\    export interface Static {
        \\        all<T>(list: T[], iterator?: Iterator<T, boolean>, context?: any): T;
        \\        identity<T>(value: T): T;
        \\    }
        \\}
        \\
        \\declare var _: Underscore.Static;
        \\var /*1*/r = _./*11*/all([true, 1, null, 'yes'], x => !x);
        \\var /*2*/r2 = _./*21*/all([true], _.identity);
        \\var /*3*/r3 = _./*31*/all([], _.identity);
        \\var /*4*/r4 = _./*41*/all([<any>true], _.identity);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "var r: string | number | boolean", "");
    try f.VerifyQuickInfoAt(undefined, "11", "(method) Underscore.Static.all<string | number | boolean>(list: (string | number | boolean)[], iterator?: Underscore.Iterator<string | number | boolean, boolean>, context?: any): string | number | boolean", "");
    try f.VerifyQuickInfoAt(undefined, "2", "var r2: boolean", "");
    try f.VerifyQuickInfoAt(undefined, "21", "(method) Underscore.Static.all<boolean>(list: boolean[], iterator?: Underscore.Iterator<boolean, boolean>, context?: any): boolean", "");
    try f.VerifyQuickInfoAt(undefined, "3", "var r3: any", "");
    try f.VerifyQuickInfoAt(undefined, "31", "(method) Underscore.Static.all<any>(list: any[], iterator?: Underscore.Iterator<any, boolean>, context?: any): any", "");
    try f.VerifyQuickInfoAt(undefined, "4", "var r4: any", "");
    try f.VerifyQuickInfoAt(undefined, "41", "(method) Underscore.Static.all<any>(list: any[], iterator?: Underscore.Iterator<any, boolean>, context?: any): any", "");
    try f.VerifyNoErrors(undefined);
}

test "TestRenameJsPrototypeProperty02" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\function bar() {
        \\}
        \\[|bar.prototype.[|{| "contextRangeIndex": 0 |}x|] = 10;|]
        \\var t = new bar();
        \\[|t.[|{| "contextRangeIndex": 2 |}x|] = 11;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "x");
}

test "TestFindAllRefsRedeclaredPropertyInDerivedInterface" {
    const content =
        \\// @noLib: true
        \\interface A {
        \\    readonly /*0*/x: number | string;
        \\}
        \\interface B extends A {
        \\    readonly /*1*/x: number;
        \\}
        \\const a: A = { /*2*/x: 0 };
        \\const b: B = { /*3*/x: 0 };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2", "3");
}

test "TestLocalFunction" {
    const content =
        \\function /*1*/foo() {
        \\    function /*2*/bar2() {
        \\    }
        \\    var y = function /*3*/bar3() {
        \\    }
        \\}
        \\var x = function /*4*/bar4() {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "function foo(): void", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(local function) bar2(): void", "");
    try f.VerifyQuickInfoAt(undefined, "3", "(local function) bar3(): void", "");
    try f.VerifyQuickInfoAt(undefined, "4", "(local function) bar4(): void", "");
}

test "TestQuickInfo_notInsideComment" {
    const content =
        \\a/* /**/ */.b
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyNotQuickInfoExists(undefined);
}

test "TestFormatArrayLiteralExpression" {
    const content =
        \\export let Things = [{
        \\    Hat: 'hat', /*1*/
        \\    Glove: 'glove',
        \\    Umbrella: 'umbrella'
        \\},{/*2*/
        \\        Salad: 'salad', /*3*/
        \\        Burrito: 'burrito',
        \\        Pie: 'pie'
        \\    }];/*4*/
        \\
        \\export let Things2 = [
        \\{
        \\    Hat: 'hat', /*5*/
        \\    Glove: 'glove',
        \\    Umbrella: 'umbrella'
        \\}/*6*/,
        \\    {
        \\        Salad: 'salad', /*7*/
        \\        Burrito: ['burrito', 'carne asada', 'tinga de res', 'tinga de pollo'], /*8*/
        \\        Pie: 'pie'
        \\    }];/*9*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "    Hat: 'hat',");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "}, {");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "    Salad: 'salad',");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "}];");
    _ = f.GoToMarker(undefined, "5");
    try f.VerifyCurrentLineContent(undefined, "        Hat: 'hat',");
    _ = f.GoToMarker(undefined, "6");
    try f.VerifyCurrentLineContent(undefined, "    },");
    _ = f.GoToMarker(undefined, "7");
    try f.VerifyCurrentLineContent(undefined, "        Salad: 'salad',");
    _ = f.GoToMarker(undefined, "8");
    try f.VerifyCurrentLineContent(undefined, "        Burrito: ['burrito', 'carne asada', 'tinga de res', 'tinga de pollo'],");
    _ = f.GoToMarker(undefined, "9");
    try f.VerifyCurrentLineContent(undefined, "    }];");
}

test "TestGetOccurrencesSuper" {
    const content =
        \\class SuperType {
        \\    superMethod() {
        \\    }
        \\
        \\    static superStaticMethod() {
        \\        return 10;
        \\    }
        \\}
        \\
        \\class SubType extends SuperType {
        \\    public  prop1 = [|s/**/uper|].superMethod;
        \\    private prop2 = [|super|].superMethod;
        \\
        \\    constructor() {
        \\        [|super|]();
        \\    }
        \\
        \\    public method1() {
        \\        return [|super|].superMethod();
        \\    }
        \\
        \\    private method2() {
        \\        return [|super|].superMethod();
        \\    }
        \\
        \\    public method3() {
        \\        var x = () => [|super|].superMethod();
        \\
        \\        // Bad but still gets highlighted
        \\        function f() {
        \\            [|super|].superMethod();
        \\        }
        \\    }
        \\
        \\    // Bad but still gets highlighted.
        \\    public static statProp1 = super.superStaticMethod;
        \\
        \\    public static staticMethod1() {
        \\        return super.superStaticMethod();
        \\    }
        \\
        \\    private static staticMethod2() {
        \\        return super.superStaticMethod();
        \\    }
        \\
        \\    // Are not actually 'super' keywords.
        \\    super = 10;
        \\    static super = 20;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestExportDefaultFunction" {
    const content =
        \\export default function func() {
        \\    /*1*/
        \\}
        \\ /*2*/
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
//                     .Label =  "func",
//                     .Detail = undefined("function func(): void"),
//                     .Kind =   undefined(lsproto.CompletionItemKindFunction),
//                 },
//             },
//         },
//     });
}

test "TestRenameForAliasingExport02" {
    const content =
        \\// @Filename: foo.ts
        \\let x = 1;
        \\
        \\export { x as /**/[|y|] };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyRenameSucceeded(undefined, null );
}

test "TestEditLambdaArgToTypeParameter1" {
    const content =
        \\class C<T> {
        \\    foo(x: T) {
        \\        return (a: number/*1*/) => x;
        \\    }
        \\}
        \\/*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Backspace(undefined, 6);
    _ = f.Insert(undefined, "T");
    try f.VerifyNoErrors(undefined);
    _ = f.GoToMarker(undefined, "2");
    _ = f.InsertLine(undefined, "");
    try f.VerifyNoErrors(undefined);
}

test "TestGetJavaScriptCompletions8" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\/**
        \\ * @type {function(): number}
        \\ */
        \\var v;
        \\v()./**/
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

test "TestDeclareFunction" {
    const content =
        \\// @filename: index.ts
        \\declare function
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyWorkspaceSymbol(undefined, []*.{
//         .{
//             .Pattern =     "",
//             .Preferences = null,
//             .Exact =       undefined([]*.{}),
//         },
//     });
}

test "TestConstructorFindAllReferences2" {
    const content =
        \\export class C {
        \\    /**/private constructor() { }
        \\    public foo() { }
        \\}
        \\
        \\new C().foo();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestCompletionsImport_named_didNotExistBefore" {
    const content =
        \\// @noLib: true
        \\// @Filename: /a.ts
        \\export function Test1() {}
        \\export function Test2() {}
        \\// @Filename: /b.ts
        \\import { Test2 } from "./a";
        \\t/**/
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
//                         .Label =  "Test2",
//                         .Detail = undefined("(alias) function Test2(): void\nimport Test2"),
//                         .Kind =   undefined(lsproto.CompletionItemKindVariable),
//                     },
//                     &.{
//                         .Label = "Test1",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "./a",
//                             },
//                         },
//                         .Detail =              undefined("function Test1(): void"),
//                         .Kind =                undefined(lsproto.CompletionItemKindFunction),
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                         .LabelDetails = &.{
//                             .Description = undefined("./a"),
//                         },
//                     },
//                 }, true,
//             ),
//         },
//     });
}

test "TestQuickInfoOnObjectLiteralWithOnlySetter" {
    const content =
        \\function /*1*/makePoint(x: number) {
        \\    return {
        \\        b: 10,
        \\        set x(a: number) { this.b = a; }
        \\    };
        \\};
        \\var /*3*/point = makePoint(2);
        \\point./*2*/x = 30;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "b",
//                     .Detail = undefined("(property) b: number"),
//                 },
//                 &.{
//                     .Label =  "x",
//                     .Detail = undefined("(property) x: number"),
//                 },
//             },
//         },
//     });
    try f.VerifyQuickInfoAt(undefined, "1", "function makePoint(x: number): {\n    b: number;\n    x: number;\n}", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(property) x: number", "");
    try f.VerifyQuickInfoAt(undefined, "3", "var point: {\n    b: number;\n    x: number;\n}", "");
}

test "TestQuickinfoVerbosityIntersection1" {
    const content =
        \\{
        \\    type Foo = { a: "a" | "c" };
        \\    type Bar = { a: "a" | "b" };
        \\    const obj/*o1*/: Foo & Bar = { a: "a" };
        \\}
        \\{
        \\    type Foo = { a: "c" };
        \\    type Bar = { a: "b" };
        \\    const obj/*o2*/: Foo & Bar = { a: "" };
        \\}
        \\{
        \\    type Foo = { a: "c" };
        \\    type Bar = { a: "b" };
        \\    type Never = Foo & Bar;
        \\    const obj/*o3*/: Never = { a: "" };
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"o1" = .{0, 1}, .@"o2" = .{0}, .@"o3" = .{0}});
}

test "TestFormatAnyTypeLiteral" {
    const content =
        \\function foo(x: { } /*objLit*/){
        \\/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "}");
    _ = f.GoToMarker(undefined, "objLit");
    try f.VerifyCurrentLineContent(undefined, "function foo(x: {}) {");
}

test "TestSmartSelection_JSDoc" {
    const content =
        \\// Not a JSDoc comment
        \\/**
        \\ * @param {number} x The number to square
        \\ */
        \\function /**/square(x) {
        \\  return x * x;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSelectionRanges(undefined);
}

test "TestGetOccurrencesAfterEdit" {
    const content =
        \\/*0*/
        \\interface A {
        \\    foo: string;
        \\}
        \\function foo(x: A) {
        \\    x.f/*1*/oo
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , "1");
    _ = f.GoToMarker(undefined, "0");
    _ = f.Insert(undefined, "\n");
    // try f.VerifyBaselineDocumentHighlights(undefined, null , "1");
}

test "TestCompletionInTypeOf1" {
    const content =
        \\namespace m1c {
        \\    export interface I { foo(): void; }
        \\}
        \\var x: typeof m1c./*1*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "1", null);
}

test "TestGenericCallSignaturesInNonGenericTypes2" {
    const content =
        \\interface WrappedArray<T> { }
        \\interface Underscore {
        \\    <T>(list: T[]): WrappedArray<T>;
        \\}
        \\var _: Underscore;
        \\var a: number[];
        \\var /**/b = _(a);  // WrappedArray<any>, should be WrappedArray<number>
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "var b: WrappedArray<number>", "");
}

test "TestCompletionsQuotedObjectLiteralUnion" {
    const content =
        \\interface A {
        \\  "a-prop": string;
        \\}
        \\
        \\interface B {
        \\  "b-prop": string;
        \\}
        \\
        \\const obj: A | B = {
        \\  "/*1*/"
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
//             .Exact = &.{
//                 "a-prop",
//                 "b-prop",
//             },
//         },
//     });
}

test "TestCompletionListClassMembersWithSuperClassFromUnknownNamespace" {
    const content =
        \\class Child extends Namespace.Parent {
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
//             .Includes = CompletionClassElementKeywords,
//         },
//     });
}

test "TestSignatureHelpForSuperCalls1" {
    const content =
        \\class A { }
        \\class B extends A { }
        \\class C extends B {
        \\    constructor() {
        \\        super(/*1*/ // sig help here?
        \\    }
        \\}
        \\class A2 { }
        \\class B2 extends A2 {
        \\    constructor(x:number) {}
        \\ }
        \\class C2 extends B2 {
        \\    constructor() {
        \\        super(/*2*/ // sig help here?
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "B(): B"});
    _ = f.GoToMarker(undefined, "2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "B2(x: number): B2"});
}

test "TestImportNameCodeFixExistingImport11" {
    const content =
        \\import [|{
        \\    v1, v2,
        \\    v3
        \\}|] from "./module";
        \\f1/*0*/();
        \\// @Filename: module.ts
        \\ export function f1() {}
        \\ export var v1 = 5;
        \\ export var v2 = 5;
        \\ export var v3 = 5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "{\n    f1,\n    v1, v2,\n    v3\n}",
    }, null );
}

test "TestGetOccurrencesIsDefinitionOfNamespace" {
    const content =
        \\/*1*/namespace /*2*/Numbers {
        \\    export var n = 12;
        \\}
        \\let x = /*3*/Numbers.n + 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestSignatureHelpTrailingRestTuple" {
    const content =
        \\export function leading(allCaps: boolean, ...names: string[]): void {
        \\}
        \\
        \\leading(/*1*/);
        \\leading(false, /*2*/);
        \\leading(false, "ok", /*3*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "leading(allCaps: boolean, ...names: string[]): void", .ParameterCount = 2, .ParameterName = "allCaps", .ParameterSpan = "allCaps: boolean", .OverloadsCount = 1, .IsVariadic = true, .IsVariadicSet = true});
    _ = f.GoToMarker(undefined, "2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "leading(allCaps: boolean, ...names: string[]): void", .ParameterCount = 2, .ParameterName = "names", .ParameterSpan = "...names: string[]", .OverloadsCount = 1, .IsVariadic = true, .IsVariadicSet = true});
    _ = f.GoToMarker(undefined, "3");
    // try f.VerifySignatureHelp(undefined, .{.Text = "leading(allCaps: boolean, ...names: string[]): void", .ParameterCount = 2, .ParameterName = "names", .ParameterSpan = "...names: string[]", .OverloadsCount = 1, .IsVariadic = true, .IsVariadicSet = true});
}

test "TestUnusedFunctionInNamespace5" {
    const content =
        \\// @noUnusedLocals: true
        \\// @noUnusedParameters:true
        \\namespace Validation {
        \\    var function1 = function() {
        \\    }
        \\
        \\    export function function2() {
        \\
        \\    }
        \\
        \\    [| function function3() {
        \\        function1();
        \\    }
        \\
        \\    function function4() {
        \\
        \\    }
        \\
        \\    export let a = function3; |]
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "function function3() {\n        function1();\n    }\n\n    export let a = function3;", false, 0, 0);
}

test "TestImportNameCodeFix_all_promoteType" {
    const content =
        \\// @Filename: /a.ts
        \\export class A {}
        \\export class B {}
        \\export class C {}
        \\export class D {}
        \\export class E {}
        \\export class F {}
        \\export class G {}
        \\// @Filename: /b.ts
        \\import type { A, C, D, E, G } from './a';
        \\type Z = B | A;
        \\new F;
        \\// @Filename: /c.ts
        \\import type { A, C, D, E, G } from './a';
        \\type Z = B | A;
        \\type Y = F;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    try f.VerifyCodeFixAll(undefined, .{
        .FixID = "fixMissingImport",
        .NewFileContent = "import { B, F, type A, type C, type D, type E, type G } from './a';\ntype Z = B | A;\nnew F;",
    });
    _ = f.GoToFile(undefined, "/c.ts");
    try f.VerifyCodeFixAll(undefined, .{
        .FixID = "fixMissingImport",
        .NewFileContent = "import type { A, B, C, D, E, F, G } from './a';\ntype Z = B | A;\ntype Y = F;",
    });
}

test "TestQuickInfoDisplayPartsInterface" {
    const content =
        \\interface /*1*/i {
        \\}
        \\var /*2*/iInstance: /*3*/i;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestQuickInfoJsDocTags2" {
    const content =
        \\// @Filename: quickInfoJsDocTags2.ts
        \\/** Doc   */
        \\const /**/x = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "const x: 0", "Doc");
}

test "TestGetOccurrencesIfElseBroken" {
    const content =
        \\[|if|] (true) {
        \\    var x = 1;
        \\}
        \\[|else     if|] ()
        \\[|else if|]
        \\[|else|]  /*  whar garbl   */   [|if|] (i/**/f (true) { } else { })
        \\else
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
    // try f.VerifyBaselineDocumentHighlights(undefined, null , "");
}

test "TestFormattingAfterMultiLineString" {
    const content =
        \\class foo {
        \\    stop() {
        \\        var s = "hello\/*1*/
        \\"/*2*/
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "2");
    _ = f.InsertLine(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "        var s = \"hello\\");
}

test "TestQualifyModuleTypeNames" {
    const content =
        \\namespace m { export class c { } };
        \\function x(arg: m.c) { return arg; }
        \\x(/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifySignatureHelp(undefined, .{.Text = "x(arg: m.c): m.c"});
}

test "TestFormatColonAndQMark" {
    const content =
        \\class foo {/*1*/
        \\    constructor (n?: number, m = 5, o?: string) { }/*2*/
        \\    x:number = 1?2:3;/*3*/
        \\}/*4*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "class foo {");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "    constructor(n?: number, m = 5, o?: string) { }");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "    x: number = 1 ? 2 : 3;");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "}");
}

test "TestGenericCombinatorWithConstraints1" {
    const content =
        \\function apply<T, U extends Date>(source: T[], selector: (x: T) => U) {
        \\    var /*1*/xs = source.map(selector); // any[]
        \\    var /*2*/xs2 = source.map((x: T, a, b): U => { return null }); // any[] 
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(local var) xs: U[]", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(local var) xs2: U[]", "");
}

test "TestAliasMergingWithNamespace" {
    const content =
        \\namespace bar { }
        \\import bar = bar/**/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "namespace bar\nimport bar = bar", "");
}

test "TestCompletionListInObjectLiteral8" {
    const content =
        \\declare function test<
        \\  Variants extends Partial<Record<'hover' | 'pressed', string>>,
        \\>(v: Variants): void
        \\
        \\test({
        \\  hover: "",
        \\  /**/
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
//                     .Label =      "pressed?",
//                     .InsertText = undefined("pressed"),
//                     .FilterText = undefined("pressed"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
}

test "TestInlayHintsInteractiveFunctionParameterTypes3" {
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
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayFunctionParameterTypeHints = core.TSTrue}});
}

test "TestDocumentHighlightAtInheritedProperties1" {
    const content =
        \\// @Filename: file1.ts
        \\interface interface1 extends interface1 {
        \\   [|doStuff|](): void;
        \\   [|propName|]: string;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestDefaultParamsAndContextualTypes" {
    const content =
        \\// @strict: false
        \\interface FooOptions {
        \\    text?: string;
        \\}
        \\interface Foo {
        \\    bar(xy: string, options?: FooOptions): void;
        \\}
        \\var o: Foo = {
        \\    bar: function (x/*1*/y, opt/*2*/ions = {}) {
        \\        // expect xy to have type string, and options to have type FooOptions in here
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(parameter) xy: string", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(parameter) options: FooOptions", "");
}

test "TestQuickInfoCommentsFunctionExpression" {
    const content =
        \\/** lambdaFoo var comment*/
        \\var lamb/*1*/daFoo = /** this is lambda comment*/ (/**param a*/a: number, /**param b*/b: number) => a + b;
        \\var lambddaN/*3*/oVarComment = /** this is lambda multiplication*/ (/**param a*/a: number, /**param b*/b: number) => a * b;
        \\lambdaFoo(10, 20);
        \\function /*7*/anotherFunc(a: number) {
        \\    /** documentation
        \\        @param b {string} inner parameter */
        \\    var /*8*/lambdaVar = /** inner docs */(/*9*/b: string) => {
        \\        var /*10*/localVar = "Hello ";
        \\        return /*11*/localVar + /*12*/b;
        \\    }
        \\    return lamb/*13*/daVar("World") + a;
        \\}
        \\/**
        \\ * On variable
        \\ * @param s the first parameter!
        \\ * @returns the parameter's length
        \\ */
        \\var assi/*14*/gned = /**
        \\                * Summary on expression
        \\                * @param s param on expression
        \\                * @returns return on expression
        \\                */function(/** On parameter */s: string) {
        \\  return s.length;
        \\}
        \\assig/*16*/ned("hey");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestContextualTypingOfGenericCallSignatures1" {
    const content =
        \\var f24: {
        \\   <T, U>(x: T): U
        \\};
        \\// x should not be contextually typed 
        \\var f24 = (/**/x) => { return 1 };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "(parameter) x: any", "");
}

test "TestReferencesForStringLiteralPropertyNames4" {
    const content =
        \\var x = { "/*1*/someProperty": 0 }
        \\x[/*2*/"someProperty"] = 3;
        \\x.someProperty = 5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestCompletionReturnConstAssertion" {
    const content =
        \\type T = {
        \\    foo1: 1;
        \\    foo2: 2;
        \\}
        \\function F(x: ()=>T) {}
        \\F(()=>({/*1*/} as const))
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
//                     .Label =  "foo1",
//                     .Detail = undefined("(property) foo1: 1"),
//                 },
//                 &.{
//                     .Label =  "foo2",
//                     .Detail = undefined("(property) foo2: 2"),
//                 },
//             },
//         },
//     });
}

test "TestCompletionListAtEOF1" {
    const content =
        \\if(0 === ''.
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToEOF(undefined);
    // f.VerifyCompletions(undefined, null, &.{
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

test "TestCompletionListInImportClause02" {
    const content =
        \\declare module "M1" {
        \\    export var V;
        \\}
        \\
        \\declare module "M2" {
        \\    import { /**/ } from "M1"
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

test "TestQuickInfoForContextuallyTypedArrowFunctionInSuperCall" {
    const content =
        \\class A<T1, T2> {
        \\    constructor(private map: (value: T1) => T2) {
        \\
        \\    }
        \\}
        \\
        \\class B extends A<number, string> {
        \\    constructor() { super(va/*1*/lue => String(va/*2*/lue.toExpone/*3*/ntial())); }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(parameter) value: number", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(parameter) value: number", "");
    try f.VerifyQuickInfoAt(undefined, "3", "(method) Number.toExponential(fractionDigits?: number): string", "Returns a string containing a number represented in exponential notation.");
}

test "TestReferencesIsAvailableThroughGlobalNoCrash" {
    const content =
        \\// @Filename: /packages/playwright-core/bundles/utils/node_modules/@types/debug/index.d.ts
        \\declare var debug: debug.Debug & { debug: debug.Debug; default: debug.Debug };
        \\export = debug;
        \\export as namespace debug;
        \\declare namespace debug {
        \\    interface Debug {
        \\       coerce: (val: any) => any;
        \\    }
        \\}
        \\// @Filename: /packages/playwright-core/bundles/utils/node_modules/@types/debug/package.json
        \\{ "types": "index.d.ts" }
        \\// @Filename: /packages/playwright-core/src/index.ts
        \\export const debug: typeof import('../bundles/utils/node_modules//*1*/@types/debug') = require('./utilsBundleImpl').debug;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestCompletionsOverridingMethod10" {
    const content =
        \\// @Filename: a.ts
        \\// @newline: LF
        \\interface Base {
        \\    a: string;
        \\    b(a: string): void;
        \\    c(a: string): string;
        \\    c(a: number): number;
        \\}
        \\class Sub implements Base {
        \\   /*a*/
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
//                     .Label =      "a",
//                     .InsertText = undefined("a: string;"),
//                     .FilterText = undefined("a"),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                 },
//                 &.{
//                     .Label =      "b",
//                     .InsertText = undefined("b(a: string): void {\n}"),
//                     .FilterText = undefined("b"),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                 },
//                 &.{
//                     .Label =      "c",
//                     .InsertText = undefined("c(a: string): string;\nc(a: number): number;\nc(a: unknown): string | number {\n}"),
//                     .FilterText = undefined("c"),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                 },
//             },
//         },
//     });
}

test "TestCompletionsImport_details_withMisspelledName" {
    const content =
        \\// @Filename: /a.ts
        \\export const abc = 0;
        \\// @Filename: /b.ts
        \\acb/*1*/;
        \\// @Filename: /c.ts
        \\acb/*2*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined("1"), &.{
//         .Name =        "abc",
//         .Source =      "./a",
//         .Description = "Add import from \"./a\"",
//         .NewFileContent = undefined("import { abc } from \"./a\";\n\nacb;"),
//     });
    _ = f.GoToMarker(undefined, "2");
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined("2"), &.{
//         .Name =   "abc",
//         .Source = "./a",
//         .AutoImportFix = &.{
//             .ModuleSpecifier = "./a",
//         },
//         .Description = "Add import from \"./a\"",
//         .NewFileContent = undefined("import { abc } from \"./a\";\n\nacb;"),
//     });
}

test "TestCallHierarchyAccessor" {
    const content =
        \\function foo() {
        \\    new C().bar;
        \\}
        \\
        \\class C {
        \\    get /**/bar() {
        \\        return baz();
        \\    }
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

test "TestFindAllRefsUnresolvedSymbols2" {
    const content =
        \\import { /*a0*/Bar } from "does-not-exist";
        \\
        \\let a: /*a1*/Bar;
        \\let b: /*a2*/Bar<string>;
        \\let c: /*a3*/Bar<string, number>;
        \\let d: /*a4*/Bar./*b0*/X;
        \\let e: /*a5*/Bar./*b1*/X<string>;
        \\let f: /*a6*/Bar./*c0*/X./*d0*/Y;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "a0", "a1", "a2", "a3", "a4", "a5", "a6", "b0", "b1", "c0", "d0");
}

test "TestCompletionListAtIdentifierDefinitionLocations_properties" {
    const content =
        \\var aa = 1;
        \\class A1 {
        \\    /*property1*/
        \\}
        \\class A2 {
        \\    p/*property2*/
        \\}
        \\class A3 {
        \\    public s/*property3*/
        \\}
        \\class A4 {
        \\    a/*property4*/
        \\}
        \\class A5 {
        \\    public a/*property5*/
        \\}
        \\class A6 {
        \\    protected a/*property6*/
        \\}
        \\class A7 {
        \\    private a/*property7*/
        \\}
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
//             .Exact = CompletionClassElementKeywords,
//         },
//     });
}

test "TestCompletionSatisfiesKeyword" {
    const content =
        \\const x = { a: 1 } /*1*/
        \\function foo() {
        \\    const x = { a: 1 } /*2*/
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
//                     .Label =    "satisfies",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestSyntacticClassificationsDocComment2" {
    const content =
        \\/** @param foo { function(x): string } */
        \\var v;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "variable.declaration", .Text = "v"},
//     });
}

test "TestGoToImplementationLocal_02" {
    const content =
        \\const x = { [|hello|]: () => {} };
        \\
        \\x.he/*function_call*/llo();
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "function_call");
}

test "TestCompletionListInStringLiterals1" {
    const content =
        \\"/*1*/       /*2*/\/*3*/
        \\ /*4*/   \\/*5*/
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
//             .Exact = &.{},
//         },
//     });
}

test "TestRenameAliasExternalModule" {
    const content =
        \\// @Filename: a.ts
        \\namespace SomeModule { export class SomeClass { } }
        \\export = SomeModule;
        \\// @Filename: b.ts
        \\[|import [|{| "contextRangeIndex": 0 |}M|] = require("./a");|]
        \\import C = [|M|].SomeClass;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "M");
}

test "TestStringLiteralCompletionsForTypeIndexedAccess" {
    const content =
        \\type Foo = { a: string; b: number; c: boolean; };
        \\type A = Foo["/*1*/"];
        \\type AorB = Foo["a" | "/*2*/"];
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
//             .Exact = &.{
//                 "a",
//                 "b",
//                 "c",
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
//             .Exact = &.{
//                 "b",
//                 "c",
//             },
//         },
//     });
}

test "TestNavigationBarVariables" {
    const content =
        \\var x = 0;
        \\let y = 1;
        \\const z = 2;
        \\// @Filename: file2.ts
        \\var {a} = 0;
        \\let {a: b} = 0;
        \\const [c] = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
    _ = f.GoToFile(undefined, "file2.ts");
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestImportNameCodeFix_require_importVsRequire_addToExistingWins" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: blah.js
        \\export default class Blah {}
        \\export const Named1 = 0;
        \\export const Named2 = 1;
        \\// @Filename: index.js
        \\var path = require('path')
        \\  , { promisify } = require('util')
        \\  , { Named1 } = require('./blah')
        \\
        \\import fs from 'fs'
        \\
        \\new Blah
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "index.js");
    try f.VerifyCodeFix(undefined, .{
        .Description = "Update import from \"./blah\"",
        .NewFileContent = "var path = require('path')\n  , { promisify } = require('util')\n  , { Named1, default: Blah } = require('./blah')\n\nimport fs from 'fs'\n\nnew Blah",
        .Index = 0,
    });
}

test "TestNavigationBarItemsComputedNames" {
    const content =
        \\const enum E {
        \\    A = 'A',
        \\}
        \\const a = '';
        \\
        \\class C {
        \\    [a]() {
        \\        return 1;
        \\    }
        \\
        \\    [E.A]() {
        \\        return 1;
        \\    }
        \\
        \\    [1]() {
        \\        return 1;
        \\    },
        \\
        \\    ["foo"]() {
        \\        return 1;
        \\    },
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestRenameImportOfReExport2" {
    const content =
        \\declare module "a" {
        \\    [|export class /*1*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 0 |}C|] {}|]
        \\}
        \\declare module "b" {
        \\    [|export { [|{| "contextRangeIndex": 2 |}C|] as /*2*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 2 |}D|] } from "a";|]
        \\}
        \\declare module "c" {
        \\    [|import { /*3*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 5 |}D|] } from "b";|]
        \\    export function f(c: [|D|]): void;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
    // try f.VerifyBaselineRename(undefined, null , ToAny(f.GetRangesByText().Get("C")));
    // try f.VerifyBaselineRename(undefined, null , f.GetRangesByText().Get("D")[0]);
    // try f.VerifyBaselineRename(undefined, null , f.GetRangesByText().Get("D")[1], f.GetRangesByText().Get("D")[2]);
}

test "TestGotoDefinitionLinkTag2" {
    const content =
        \\enum E {
        \\    /** {@link /*1*/[|A|]} */
        \\    [|/*2*/A|]
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, false, "1");
}

test "TestSignatureHelp01" {
    const content =
        \\// @lib: es5
        \\function foo(data: number) {
        \\}
        \\
        \\function bar {
        \\    foo(/*1*/)
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "", .ParameterCount = 1});
}

test "TestCodeFixClassImplementInterfaceMultipleSignaturesRest2" {
    const content =
        \\interface I {
        \\    method(a: number, ...b: string[]): boolean;
        \\    method(a: string, b: number): Function;
        \\    method(a: string): Function;
        \\}
        \\
        \\class C implements I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "interface I {\n    method(a: number, ...b: string[]): boolean;\n    method(a: string, b: number): Function;\n    method(a: string): Function;\n}\n\nclass C implements I {\n    method(a: number, ...b: string[]): boolean;\n    method(a: string, b: number): Function;\n    method(a: string): Function;\n    method(a: unknown, b?: unknown, ...rest?: unknown[]): boolean | Function {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestGetOccurrencesPublic2" {
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
        \\            [|public|] pub1;
        \\            private priv1;
        \\            protected prot1;
        \\
        \\            protected constructor([|public|] public, protected protected, private private) {
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
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestFormattingOnSingleLineBlocks" {
    const content =
        \\class C
        \\{}
        \\if (true)
        \\{}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "class C { }\nif (true) { }");
}

test "TestImportNameCodeFixNewImportAmbient3" {
    const content =
        \\let a = "I am a non-trivial statement that appears before imports";
        \\import d from "other-ambient-module"
        \\import * as ns from "yet-another-ambient-module"
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
    try f.VerifyImportFixAtPosition(undefined, &.{
        "let a = \"I am a non-trivial statement that appears before imports\";\nimport { v1 } from \"ambient-module\";\nimport d from \"other-ambient-module\"\nimport * as ns from \"yet-another-ambient-module\"\nvar x = v1 + 5;",
    }, null );
}

test "TestCompletionListOnParam" {
    const content =
        \\namespace Bar {
        \\    export class Blah { }
        \\}
        \\
        \\class Point {
        \\    public Foo(x: Bar./**/Blah, y: Bar.Blah) { }
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
//                 "Blah",
//             },
//         },
//     });
}

test "TestStringLiteralCompletionsWithinInferredObjectWhenItsKeysAreUsedOutsideOfIt" {
    const content =
        \\// @strict: true
        \\declare function createMachine<T>(config: {
        \\  initial: keyof T;
        \\  states: {
        \\    [K in keyof T]: {
        \\      on?: Record<string, keyof T>;
        \\    };
        \\  };
        \\}): void;
        \\
        \\createMachine({
        \\  initial: "a",
        \\  states: {
        \\    a: {
        \\      on: {
        \\        NEXT: "/*1*/",
        \\      },
        \\    },
        \\    b: {
        \\      on: {
        \\        NEXT: "/*2*/",
        \\      },
        \\    },
        \\  },
        \\});
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
//                 "a",
//                 "b",
//             },
//         },
//     });
}

test "TestSyntacticClassificationsForOfKeyword3" {
    const content =
        \\for (var of; of; of) { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "variable.declaration", .Text = "of"},
//         .{.Type = "variable", .Text = "of"},
//         .{.Type = "variable", .Text = "of"},
//     });
}

test "TestFindAllRefsClassExpression1" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\module.exports = class /*0*/A {};
        \\// @Filename: /b.js
        \\import /*1*/A = require("./a");
        \\/*2*/A;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2");
}

test "TestFormatV8Directive" {
    const content =
        \\// @Filename: foo.js
        \\function foo() {}
        \\/*1*/%PrepareFunctionForOptimization(foo)/*2*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatSelection(undefined, "1", "2");
}

test "TestRenameJsExports03" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\class /*1*/A {
        \\    /*2*/constructor() { }
        \\}
        \\module.exports = A;
        \\// @Filename: b.js
        \\const /*3*/A = require("./a");
        \\new /*4*/A;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestCompletionForStringLiteral13" {
    const content =
        \\// @lib: es5
        \\interface SymbolConstructor {
        \\    readonly species: symbol;
        \\}
        \\var Symbol: SymbolConstructor;
        \\interface PromiseConstructor {
        \\  [Symbol.species]: PromiseConstructor;
        \\}
        \\var Promise: PromiseConstructor;
        \\Promise["/*1*/"];
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
//             .Exact = &.{},
//         },
//     });
}

test "TestGoToDefinitionTaggedTemplateOverloads" {
    const content =
        \\function /*defFNumber*/f(strs: TemplateStringsArray, x: number): void;
        \\function /*defFBool*/f(strs: TemplateStringsArray, x: boolean): void;
        \\function f(strs: TemplateStringsArray, x: number | boolean) {}
        \\
        \\[|/*useFNumber*/f|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "useFNumber", "useFBool");
}

test "TestQuickInfoForObjectBindingElementPropertyName01" {
    const content =
        \\interface I {
        \\    property1: number;
        \\    property2: string;
        \\}
        \\
        \\var foo: I;
        \\var { /**/property1: prop1 } = foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "(property) I.property1: number", "");
}

test "TestDocumentHighlights01" {
    const content =
        \\// @lib: es5
        \\// @Filename: a.ts
        \\function [|f|](x: typeof [|f|]) {
        \\    [|f|]([|f|]);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestFormatTypeParameters" {
    const content =
        \\/**/type Bar<T extends any[]= any[]> = T
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "");
    try f.VerifyCurrentLineContent(undefined, "type Bar<T extends any[] = any[]> = T");
}

test "TestQuickInfoForDerivedGenericTypeWithConstructor" {
    const content =
        \\class A<T> {
        \\    foo() { }
        \\}
        \\class B<T> extends A<T> {
        \\    bar() { }
        \\    constructor() { super() }
        \\}
        \\class B2<T> extends A<T> {
        \\    bar() { }
        \\}
        \\var /*1*/b: B<number>;
        \\var /*2*/b2: B<number>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "var b: B<number>", "");
    try f.VerifyQuickInfoAt(undefined, "2", "var b2: B<number>", "");
}

test "TestCompletionEntryForUnionProperty2" {
    const content =
        \\// @lib: es5
        \\interface One {
        \\    commonProperty: string;
        \\    commonFunction(): number;
        \\    anotherProperty: Record<string, number>;
        \\}
        \\
        \\interface Two {
        \\    commonProperty: number;
        \\    commonFunction(): number;
        \\    anotherProperty: { foo: number }
        \\}
        \\
        \\var x : One | Two;
        \\
        \\x.commonProperty./*1*/;
        \\x.anotherProperty./*2*/;
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
//                     .Label =  "toLocaleString",
//                     .Detail = undefined("(method) toLocaleString(): string (+1 overload)"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "Returns a date converted to a string using the current locale.",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "toString",
//                     .Detail = undefined("(method) toString(): string (+1 overload)"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "Returns a string representation of a string.",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "valueOf",
//                     .Detail = undefined("(method) valueOf(): string | number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "Returns the primitive value of the specified object.",
//                         },
//                     },
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
//                     .Label = "foo",
//                 },
//             },
//         },
//     });
}

test "TestCompletionListInObjectBindingPattern14" {
    const content =
        \\const { b/**/ } = new class {
        \\    private ab;
        \\    protected bc;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "", null);
}

test "TestFormattingQMark" {
    const content =
        \\interface A {
        \\/*1*/    foo?     ();
        \\/*2*/    foo?             <T>();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "    foo?();");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "    foo?<T>();");
}

test "TestFindAllRefsReExports2" {
    const content =
        \\// @Filename: /a.ts
        \\export function /*1*/foo(): void {}
        \\// @Filename: /b.ts
        \\import { foo as oof } from "./a";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestFormattingSkippedTokens" {
    const content =
        \\/*1*/foo(): Bar { }
        \\/*2*/function Foo      () #   { }
        \\/*3*/4+:5
        \\ namespace M {
        \\function a(
        \\/*4*/    : T) { }
        \\}
        \\/*5*/var x       =
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "foo(): Bar { }");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "function Foo() #   { }");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "4 +: 5");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "    : T) { }");
    _ = f.GoToMarker(undefined, "5");
    try f.VerifyCurrentLineContent(undefined, "var x =");
}

test "TestGoToDefinitionObjectLiteralProperties1" {
    const content =
        \\interface PropsBag {
        \\   /*first*/propx: number
        \\}
        \\function foo(arg: PropsBag) {}
        \\foo({
        \\   [|pr/*p1*/opx|]: 10
        \\})
        \\function bar(firstarg: boolean, secondarg: PropsBag) {}
        \\bar(true, {
        \\   [|pr/*p2*/opx|]: 10
        \\})
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "p1", "p2");
}

test "TestTsxParsing" {
    const content =
        \\var x = <div id="foo" master="bar"></div>;
        \\var y = /**/x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyQuickInfoExists(undefined);
}

test "TestCompletionListInClosedFunction06" {
    const content =
        \\interface MyType {
        \\}
        \\
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string = "hello", c: typeof x = "hello") {
        \\        var v = (x: /*1*/);
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
//             .Excludes = &.{
//                 "x",
//             },
//         },
//     });
}

test "TestTypeOfKeywordCompletion" {
    const content =
        \\export type A = typ/**/
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
//                     .Label =    "typeof",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestCompletionListInFunctionDeclaration" {
    const content =
        \\// @lib: es5
        \\var a = 0;
        \\function foo(/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "", null);
    _ = f.Insert(undefined, "a");
    _ = f.VerifyCompletions(undefined, null, null);
    _ = f.Insert(undefined, " , ");
    _ = f.VerifyCompletions(undefined, null, null);
    _ = f.Insert(undefined, "b");
    _ = f.VerifyCompletions(undefined, null, null);
    _ = f.Insert(undefined, ":");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalTypes,
//         },
//     });
    _ = f.Insert(undefined, "number, ");
    _ = f.VerifyCompletions(undefined, null, null);
}

test "TestStringCompletionsVsEscaping" {
    const content =
        \\type Value<P extends string> = 
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
//                 "var(--\\\\\\\\, one)",
//                 "var(--\\\\\\\\, two)",
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
//                 "\\ntest\\n",
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
//                 "\"double-quoted\"",
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
//                 "\\\"double-quoted\\\"",
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
//                 "'single-quoted'",
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
//                 "\\'single-quoted\\'",
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
//                 "`backtick-quoted`",
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
//             .Exact = &.{
//                 "\\`backtick-quoted\\`",
//             },
//         },
//     });
}

test "TestQuickInfoOnPropertyAccessInWriteLocation1" {
    const content =
        \\// @strict: true
        \\// @exactOptionalPropertyTypes: true
        \\declare const xx: { prop?: number };
        \\xx.prop/*1*/ = 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(property) prop?: number", "");
}

test "TestCompletionListInTypeLiteralInTypeParameter10" {
    const content =
        \\interface Foo {
        \\    one: string;
        \\    two: number;
        \\}
        \\interface Bar {
        \\    three: boolean;
        \\    four: {
        \\        five: unknown;
        \\    };
        \\}
        \\
        \\function a<T extends Foo>() {}
        \\a<{/*0*/}>();
        \\
        \\var b = () => <T extends Foo>() => {};
        \\b()<{/*1*/}>();
        \\
        \\declare function c<T extends Foo>(): void
        \\declare function c<T extends Bar>(): void
        \\c<{/*2*/}>();
        \\
        \\function d<T extends Foo, U extends Bar>() {}
        \\d<{/*3*/}, {/*4*/}>();
        \\d<Foo, { four: {/*5*/} }>();
        \\
        \\(<T extends Foo>() => {})<{/*6*/}>();
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
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "one",
//                 "two",
//                 "three",
//                 "four",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "3", &.{
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
    // f.VerifyCompletions(undefined, "4", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "three",
//                 "four",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "5", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "five",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "6", &.{
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

test "TestGenericFunctionReturnType" {
    const content =
        \\function foo<T, U>(x: T, y: U): (a: U) => T {
        \\    var z = y;
        \\    return (z) => x;
        \\}
        \\var /*2*/r = foo(/*1*/1, "");
        \\var /*4*/r2 = r(/*3*/"");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "foo(x: number, y: string): (a: string) => number"});
    try f.VerifyQuickInfoAt(undefined, "2", "var r: (a: string) => number", "");
    _ = f.GoToMarker(undefined, "3");
    // try f.VerifySignatureHelp(undefined, .{.Text = "r(a: string): number"});
    try f.VerifyQuickInfoAt(undefined, "4", "var r2: number", "");
}

test "TestFindAllRefsForStaticInstancePropertyInheritance" {
    const content =
        \\class X{
        \\    /*0*/foo:any
        \\}
        \\
        \\class Y extends X{
        \\    static /*1*/foo:any
        \\}
        \\
        \\class Z extends Y{
        \\    static /*2*/foo:any
        \\    /*3*/foo:any
        \\}
        \\
        \\const x = new X();
        \\const y = new Y();
        \\const z = new Z();
        \\x./*4*/foo;
        \\y./*5*/foo;
        \\z./*6*/foo;
        \\Y./*7*/foo;
        \\Z./*8*/foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2", "3", "4", "5", "6", "7", "8");
}

test "TestRenameLocationsForFunctionExpression02" {
    const content =
        \\function f() {
        \\
        \\}
        \\var x = [|function [|{| "contextRangeIndex": 0 |}f|](g: any, h: any) {
        \\
        \\    let helper = function f(): any { f(); }
        \\
        \\    let foo = () => [|f|]([|f|], g);
        \\}|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "f");
}

test "TestQuickInfoJsDoc" {
    const content =
        \\// @target: esnext
        \\/**
        \\ * A constant
        \\ * @deprecated
        \\ */
        \\var foo = "foo";
        \\
        \\/**
        \\ * A function
        \\ * @deprecated
        \\ */
        \\function fn() { }
        \\
        \\/**
        \\ * A class
        \\ * @deprecated
        \\ */
        \\class C {
        \\    /**
        \\     * A field
        \\     * @deprecated
        \\     */
        \\    field = "field";
        \\
        \\    /**
        \\     * A getter
        \\     * @deprecated
        \\     */
        \\    get getter() {
        \\        return;
        \\    }
        \\
        \\    /**
        \\     * A method
        \\     * @deprecated
        \\     */
        \\    m() { }
        \\
        \\    get a() {
        \\        this.field/*0*/;
        \\        this.getter/*1*/;
        \\        this.m/*2*/;
        \\        foo/*3*/;
        \\        C/*4*//;
        \\        fn()/*5*/;
        \\
        \\        return 1;
        \\    }
        \\
        \\    set a(value: number) {
        \\        this.field/*6*/;
        \\        this.getter/*7*/;
        \\        this.m/*8*/;
        \\        foo/*9*/;
        \\        C/*10*/;
        \\        fn/*11*/();
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestCodeFixImportNonExportedMember5" {
    const content =
        \\// @moduleResolution: bundler
        \\// @module: esnext
        \\// @filename: /node_modules/foo/index.js
        \\function bar() {}
        \\// @filename: /b.ts
        \\import { bar } from "./foo";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    // try f.VerifyCodeFixNotAvailable(undefined, "fixImportNonExportedMember");
}

test "TestDocCommentTemplateInMultiLineComment" {
    const content =
        \\// @Filename: justAComment.ts
        \\/* /*0*/ */
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyNoJSDocCompletion(undefined, "0");
}

test "TestReferencesForNumericLiteralPropertyNames" {
    const content =
        \\class Foo {
        \\    public /*1*/12: any;
        \\}
        \\
        \\var x: Foo;
        \\x[12];
        \\x = { "12": 0 };
        \\x = { 12: 0 };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestGoToImplementationInterfaceMethod_11" {
    const content =
        \\interface Foo {
        \\   hel/*reference*/lo(): void;
        \\}
        \\
        \\var x = <Foo> { [|hello|]: () => {} };
        \\var y = <Foo> (((({ [|hello|]: () => {} }))));
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "reference");
}

test "TestAutoImportCompletionExportListAugmentation4" {
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
        \\export { Piece as Alias, type Container };
        \\// @Filename: /node_modules/@sapphire/framework/index.d.ts
        \\import { Alias } from "@sapphire/pieces";
        \\
        \\declare class Command extends Alias {}
        \\
        \\declare module "@sapphire/pieces" {
        \\  interface Container {
        \\    client: unknown;
        \\  }
        \\}
        \\
        \\export { Command as CommandAlias };
        \\// @Filename: /index.ts
        \\import "@sapphire/pieces";
        \\import { CommandAlias } from "@sapphire/framework";
        \\class PingCommand extends CommandAlias {
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
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined("1"), &.{
//         .Name =        "container",
//         .Source =      "ClassMemberSnippet/",
//         .Description = "Includes imports of types referenced by 'container'",
//         .NewFileContent = undefined("import \"@sapphire/pieces\";\nimport { CommandAlias } from \"@sapphire/framework\";\nimport { Container } from \"@sapphire/pieces\";\nclass PingCommand extends CommandAlias {\n  \n}"),
//     });
}

test "TestCompletionForMetaProperty" {
    const content =
        \\import./*1*/;
        \\new./*2*/;
        \\function test() { new./*3*/ }
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
//                     .Label =  "meta",
//                     .Detail = undefined("(property) ImportMetaExpression.meta: ImportMeta"),
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
//             .Exact = &.{},
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
//                 &.{
//                     .Label =  "target",
//                     .Detail = undefined("(property) NewTargetExpression.target: () => void"),
//                 },
//             },
//         },
//     });
}

test "TestGetOccurrencesIsDefinitionOfInterface" {
    const content =
        \\/*1*/interface /*2*/I {
        \\    p: number;
        \\}
        \\let i: /*3*/I = { p: 12 };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

