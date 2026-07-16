const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestRewriteRelativeImportExtensionsProjectReferences3" {
    const content =
        \\// @Filename: src/tsconfig-base.json
        \\{
        \\    "compilerOptions": {
        \\        "lib": ["es5"],
        \\        "module": "nodenext",
        \\        "composite": true,
        \\        "rewriteRelativeImportExtensions": true,
        \\    }
        \\}
        \\// @Filename: src/compiler/tsconfig.json
        \\{
        \\    "extends": "../tsconfig-base.json",
        \\    "compilerOptions": {
        \\        "lib": ["es5"],
        \\        "rootDir": ".",
        \\        "outDir": "../../dist/compiler",
        \\}
        \\// @Filename: src/compiler/parser.ts
        \\export {};
        \\// @Filename: src/services/tsconfig.json
        \\{
        \\    "extends": "../tsconfig-base.json",
        \\    "compilerOptions": {
        \\        "lib": ["es5"],
        \\        "rootDir": ".",
        \\        "outDir": "../../dist/services",
        \\    },
        \\    "references": [
        \\        { "path": "../compiler" }
        \\    ]
        \\}
        \\// @Filename: src/services/services.ts
        \\import {} from "../compiler/parser.ts";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToFile(undefined, "/src/services/services.ts");
    // try f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestCompletionsNamespaceName" {
    const content =
        \\{ namespace /*0*/ }
        \\namespace N/*1*/ {}
        \\namespace N.M {}
        \\namespace N./*2*/
        \\
        \\namespace N1.M/*3*/ {}
        \\namespace N2.M {}
        \\namespace N2.M/*4*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"0", "1"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{},
//     });
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "M",
//             },
//         },
//     });
    _ = f.VerifyCompletions(undefined, "3", null);
    // f.VerifyCompletions(undefined, "4", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "M",
//             },
//         },
//     });
}

test "TestCodeFixMissingTypeAnnotationOnExports3" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\const a = 42;
        \\const b = 42;
        \\export class C {
        \\  //making sure comments are not changed
        \\  property =a+b; // comment should stay here
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add annotation of type 'number'",
        .NewFileContent = "const a = 42;\nconst b = 42;\nexport class C {\n  //making sure comments are not changed\n  property: number =a+b; // comment should stay here\n}",
        .Index = 0,
    });
}

test "TestImportNameCodeFix_types_classic" {
    const content =
        \\// @moduleResolution: classic
        \\// @Filename: /node_modules/@types/foo/index.d.ts
        \\export const xyz: number;
        \\// @Filename: /node_modules/bar/index.d.ts
        \\export const qrs: number;
        \\// @Filename: /a.ts
        \\xyz;
        \\qrs;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.ts");
    try f.VerifyCodeFixAll(undefined, .{
        .FixID = "fixMissingImport",
        .NewFileContent = "import { xyz } from \"foo\";\nimport { qrs } from \"./node_modules/bar/index\";\n\nxyz;\nqrs;",
    });
}

test "TestImportNameCodeFix_jsx6" {
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
        \\<[|Text|]></Text>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.tsx");
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add import from \"react-native\"",
        .NewFileContent = "import { Text } from \"react-native\";\n\n<Text></Text>;",
        .Index = 0,
    });
    try f.VerifyCodeFix(undefined, .{
        .Description = "Import 'React' from \"react\"",
        .NewFileContent = "import React from \"react\";\n\n<Text></Text>;",
        .Index = 1,
    });
}

test "TestGetOccurrencesOfUndefinedSymbol" {
    const content =
        \\var obj1: {
        \\    (bar: any): any;
        \\    new (bar: any): any;
        \\    [bar: any]: any;
        \\    bar: any;
        \\    foob(bar: any): any;
        \\};
        \\
        \\class cls3 {
        \\    property zeFunc() {
        \\    super.ceFun/**/c();
        \\}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , "");
}

test "TestCompletionsTypeKeywords" {
    const content =
        \\// @noLib: true
        \\type T = /**/
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
//                     "T",
//                     CompletionGlobalThisItem,
//                 },
//             ),
//         },
//     });
}

test "TestCompletionsImport_named_addToNamedImports" {
    const content =
        \\// @Filename: /a.ts
        \\export function foo() {}
        \\export const x = 0;
        \\// @Filename: /b.ts
        \\import { x } from "./a";
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
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "foo",
//         .Source =      "./a",
//         .Description = "Update import from \"./a\"",
//         .NewFileContent = undefined("import { foo, x } from \"./a\";\nf;"),
//     });
}

test "TestRefactorConvertToEsModule_notInCommonjsProject" {
    const content =
        \\// @allowJs: true
        \\// @target: es5
        \\// @Filename: /a.js
        \\exports.x = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifySuggestionDiagnostics(undefined, null);
}

test "TestImportNameCodeFixNewImportFileQuoteStyleMixed0" {
    const content =
        \\[|import { v2 } from "./module2";
        \\import { v3 } from './module3';
        \\
        \\f1/*0*/();|]
        \\// @Filename: module1.ts
        \\export function f1() {}
        \\// @Filename: module2.ts
        \\export var v2 = 6;
        \\// @Filename: module3.ts
        \\export var v3 = 6;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from \"./module1\";\nimport { v2 } from \"./module2\";\nimport { v3 } from './module3';\n\nf1();",
    }, null );
}

