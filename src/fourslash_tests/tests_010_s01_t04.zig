const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestAutoImportProvider_exportMap7" {
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
        \\// @Filename: /home/src/workspaces/project/src/bar.ts
        \\import { fooFromIndex } from "dependency";
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

test "TestCodeFixMissingTypeAnnotationOnExports17_unique_symbol" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @lib: es2019
        \\export const a = Symbol();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description =    "Add annotation of type 'unique symbol'",
        .NewFileContent = "export const a: unique symbol = Symbol();",
        .Index =          0,
    });
}

test "TestRenameAlias" {
    const content =
        \\namespace SomeModule { export class SomeClass { } }
        \\[|import [|{| "contextRangeIndex": 0 |}M|] = SomeModule;|]
        \\import C = [|M|].SomeClass;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "M");
}

test "TestRenameDeclarationKeywords" {
    const content =
        \\[|{| "id": "baseDecl" |}class [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "baseDecl" |}Base|] {}|]
        \\[|{| "id": "implemented1Decl" |}interface [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "implemented1Decl" |}Implemented1|] {}|]
        \\[|{| "id": "classDecl1" |}[|class|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "classDecl1" |}C1|] [|extends|] [|Base|] [|implements|] [|Implemented1|] {
        \\    [|{| "id": "getDecl" |}[|get|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "getDecl" |}e|]() { return 1; }|]
        \\    [|{| "id": "setDecl" |}[|set|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "setDecl" |}e|](v) {}|]
        \\}|]
        \\[|{| "id": "interfaceDecl1" |}[|interface|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "interfaceDecl1" |}I1|] [|extends|] [|Base|] { }|]
        \\[|{| "id": "typeDecl" |}[|type|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "typeDecl" |}T|] = { }|]
        \\[|{| "id": "enumDecl" |}[|enum|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "enumDecl" |}E|] { }|]
        \\[|{| "id": "namespaceDecl" |}[|namespace|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "namespaceDecl" |}N|] { }|]
        \\[|{| "id": "moduleDecl" |}[|module|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "moduleDecl" |}M|] { }|]
        \\[|{| "id": "functionDecl" |}[|function|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "functionDecl" |}fn|]() {}|]
        \\[|{| "id": "varDecl" |}[|var|] [|{| "isWriteAccess": false, "isDefinition": true, "contextRangeId": "varDecl" |}x|];|]
        \\[|{| "id": "letDecl" |}[|let|] [|{| "isWriteAccess": false, "isDefinition": true, "contextRangeId": "letDecl" |}y|];|]
        \\[|{| "id": "constDecl" |}[|const|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "constDecl" |}z|] = 1;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[5], f.Ranges()[7], f.Ranges()[9], f.Ranges()[12], f.Ranges()[15], f.Ranges()[18], f.Ranges()[20], f.Ranges()[23], f.Ranges()[26], f.Ranges()[29], f.Ranges()[32], f.Ranges()[35], f.Ranges()[38], f.Ranges()[41], f.Ranges()[44]);
}

test "TestJsdocTemplatePrototypeCompletions" {
    const content =
        \\// @checkJs: true
        \\// @filename: index.js
        \\https://github.com/microsoft/TypeScript/issues/11492
        \\/** @constructor */
        \\function Foo() {}
        \\/**
        \\ * @template T
        \\ * @param {T} bar
        \\ * @returns {T}
        \\ */
        \\Foo.prototype.foo = function (bar) {};
        \\new Foo().foo({ id: 1234 })./**/
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
//             },
//         },
//     });
}

test "TestCompletionsOverridingMethod14" {
    const content =
        \\// @Filename: a.ts
        \\// @strictNullChecks: true
        \\// @newline: LF
        \\interface IFoo {
        \\    foo?(arg: string): number;
        \\}
        \\class Foo implements IFoo {
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
//                 &.{
//                     .Label =      "foo",
//                     .InsertText = undefined("foo(arg: string): number {\n}"),
//                     .FilterText = undefined("foo"),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                 },
//             },
//         },
//     });
}

test "TestAutoImportProvider_exportMap8" {
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
        \\    "./lol": {
        \\      "import": "./lib/index.js",
        \\      "require": "./lib/lol.js"
        \\    }
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/dependency/lib/index.d.ts
        \\export function fooFromIndex(): void;
        \\// @Filename: /home/src/workspaces/project/node_modules/dependency/lib/lol.d.ts
        \\export function fooFromLol(): void;
        \\// @Filename: /home/src/workspaces/project/src/bar.ts
        \\import { fooFromIndex } from "dependency";
        \\// @Filename: /home/src/workspaces/project/src/foo.cts
        \\fooFrom/*cts*/
        \\// @Filename: /home/src/workspaces/project/src/foo.mts
        \\fooFrom/*mts*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "cts");
    // f.VerifyCompletions(undefined, "cts", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
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
//             .Excludes = &.{
//                 "fooFromIndex",
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "mts");
    // f.VerifyCompletions(undefined, "mts", &.{
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
//                             .ModuleSpecifier = "dependency/lol",
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

test "TestCodeFixMissingTypeAnnotationOnExports29_inline" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\function getString() {
        \\    return ""
        \\}
        \\export const exp = {
        \\    prop: getString()
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add satisfies and an inline type assertion with 'string'",
        .NewFileContent = "function getString() {\n    return \"\"\n}\nexport const exp = {\n    prop: getString() satisfies string as string\n};",
        .Index = 1,
    });
}

test "TestOrganizeImports_removeOnly" {
    const content =
        \\import { c, b, a } from "foo";
        \\import d, { e } from "bar";
        \\import * as f from "baz";
        \\import { g } from "foo";
        \\
        \\export { g, e, b, c };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "import { c, b } from \"foo\";\nimport { e } from \"bar\";\nimport { g } from \"foo\";\n\nexport { g, e, b, c };",
//         lsproto.CodeActionKindSourceRemoveUnusedImports,
//         null,
//     );
}

test "TestCompletionsImport_multipleWithSameName" {
    const content =
        \\// @module: esnext
        \\// @noLib: true
        \\// @Filename: /global.d.ts
        \\declare var foo: number;
        \\// @Filename: /a.ts
        \\export const foo = 0;
        \\// @Filename: /b.ts
        \\export const foo = 1;
        \\// @Filename: /c.ts
        \\fo/**/
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
//                         .Label =    "foo",
//                         .Detail =   undefined("var foo: number"),
//                         .Kind =     undefined(lsproto.CompletionItemKindVariable),
//                         .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                     },
//                     &.{
//                         .Label = "foo",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "./a",
//                             },
//                         },
//                         .Detail =              undefined("const foo: 0"),
//                         .Kind =                undefined(lsproto.CompletionItemKindVariable),
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                     &.{
//                         .Label = "foo",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "./b",
//                             },
//                         },
//                         .Detail =              undefined("const foo: 1"),
//                         .Kind =                undefined(lsproto.CompletionItemKindVariable),
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                 }, true,
//             ),
//         },
//     });
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "foo",
//         .Source =      "./b",
//         .Description = "Add import from \"./b\"",
//         .NewFileContent = undefined("import { foo } from \"./b\";\n\nfo"),
//     });
}

