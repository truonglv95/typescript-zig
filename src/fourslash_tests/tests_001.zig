const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestArgumentCompletions" {
    const content =
        \\
        \\function foo(a: "a", b: "b") {}
        \\foo("a", /*1*/);
        \\
        \\
        \\const t3 = ['x', 'y', 'z'] as const;
        \\const x: [string, string, string, 'a' | 'b'] = [...t3, /*2*/];
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "1", &.{
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//         },
//         .Items = &.{
//             .Includes = &.{"\"b\""},
//         },
//     });
    // f.VerifyCompletions(undefined, "2", &.{
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//         },
//         .Items = &.{
//             .Includes = &.{"\"b\""},
//         },
//     });
}

test "TestQuickinfoVerbosityNestedNamespace" {
    const content =
        \\
        \\declare namespace Outer/*1*/ {
        \\    namespace Inner {
        \\        const x: number;
        \\        function f(): string;
        \\    }
        \\    const outerVal: boolean;
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{0, 1}});
}

test "TestGetEditsForFileRename_jsRename" {
    const content =
        \\
        \\// @Filename: /tsconfig.json
        \\{ "compilerOptions": { "module": "nodenext" } }
        \\// @Filename: /a.ts
        \\export const a = 1;
        \\// @Filename: /b.ts
        \\import { a } from ".//*rename*/a.js";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyRename(undefined, "rename", "c.js", .{
//         .@"/c.ts" = "export const a = 1;",
//         .@"/b.ts" = "import { a } from \"./c.js\";",
//     });
}

test "TestQuickinfoVerbosityNamespaceInterfaceHeritageCrash" {
    const content =
        \\
        \\declare namespace NS/*1*/ {
        \\    interface Config extends Record<string, any> {}
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{0, 1}});
}

test "TestCodeFixMissingTypeAnnotationOnExports_expandoNoDuplicates" {
    const content =
        \\// @declaration: true
        \\// @isolatedDeclarations: true
        \\// @Filename: /foo.mts
        \\export function foo(): void {
        \\}
        \\
        \\foo.blah = 123;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFixAvailableExact(undefined, &.{
        "Annotate types of properties expando function in a namespace",
    });
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Annotate types of properties expando function in a namespace",
        .NewFileContent = "export function foo(): void {\n}\nexport declare namespace foo {\n    export var blah: number;\n}\n\nfoo.blah = 123;",
    });
}

test "TestDocumentHighlightMalformedAmbientModuleExportEquals" {
    const content =
        \\// @Filename: /a.d.ts
        \\declare moduleu "m" {
        \\  interface A { x: 1 }
        \\  function f(): A[];
        \\  /*m*/export = f;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , "m");
}

test "TestFormattingOverrideKeyword" {
    const content =
        \\class MyClass {
        \\  override     myMethod() { };/*1*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "    override myMethod() { };");
}

test "TestCodeFixPromoteTypeOnlyOrderingCrash" {
    const content =
        \\// @module: node18
        \\// @verbatimModuleSyntax: true
        \\// @Filename: /bar.ts
        \\export interface AAA {}
        \\export class BBB {}
        \\// @Filename: /foo.ts
        \\import type {
        \\    AAA,
        \\    BBB,
        \\} from "./bar";
        \\
        \\let x: AAA = new BBB()
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/foo.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import {\n    BBB,\n    type AAA,\n} from \"./bar\";\n\nlet x: AAA = new BBB()",
    }, null );
}

test "TestGoToSourceReferenceTypesToJS" {
    const content =
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/foo/package.json
        \\{ "name": "@types/foo", "version": "1.0.0" }
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/foo/index.d.ts
        \\export declare function bar(): string;
        \\// @Filename: /home/src/workspaces/project/node_modules/foo/package.json
        \\{ "name": "foo", "version": "1.0.0", "main": "./index.js" }
        \\// @Filename: /home/src/workspaces/project/node_modules/foo/index.js
        \\export function /*target*/bar() { return "hello"; }
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\/// <reference types="[|foo/*refTypes*/|]" />
        \\import { bar } from "foo";
        \\bar();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "refTypes");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "refPath");
}

test "TestCallHierarchyAnonymousClassNoCrash2" {
    const content =
        \\// @Filename: /main.ts
        \\(class {
        \\    con/*1*/structor() {}
        \\})
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifyBaselineCallHierarchy(undefined);
}

test "TestBasicClassElementKeywords" {
    const content =
        \\class C {
        \\    /*a*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "a", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//         },
//         .Items = &.{
//             .Exact = CompletionClassElementKeywords,
//         },
//     });
}

test "TestGoToSourceAtTypesPackage" {
    const content =
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/foo/package.json
        \\{ "name": "@types/foo", "version": "1.0.0" }
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/foo/index.d.ts
        \\export declare function bar(): string;
        \\// @Filename: /home/src/workspaces/project/node_modules/foo/package.json
        \\{ "name": "foo", "version": "1.0.0", "main": "./index.js" }
        \\// @Filename: /home/src/workspaces/project/node_modules/foo/index.js
        \\export function /*target*/bar() { return "hello"; }
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { bar } from "foo";
        \\bar/*usage*/();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "usage");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "usage");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "usage");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "usage");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "usage");
}

test "TestAutoImportSymlinkedMonorepo" {
    const content =
        \\// @Filename: /packages/project-b/package.json
        \\{ "name": "project-b", "version": "1.0.0", "main": "index.js", "types": "index.d.ts" }
        \\// @Filename: /packages/project-b/index.d.ts
        \\export declare const projectBValue: number;
        \\export declare function projectBFunction(): string;
        \\// @Filename: /packages/project-a/tsconfig.json
        \\{ "compilerOptions": { "module": "commonjs", "strict": true } }
        \\// @Filename: /packages/project-a/package.json
        \\{ "name": "project-a", "dependencies": { "project-b": "*" } }
        \\// @Filename: /packages/project-a/index.ts
        \\import { projectBValue } from "project-b";
        \\console.log(projectBValue);
        \\projectBFunc/**/
        \\// @link: /packages/project-b -> /packages/project-a/node_modules/project-b
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
}

test "TestGoToDefinitionDecoratorNoCrashOnFunctionDeclaration1" {
    const content =
        \\function dec(target: any) { return target; }
        \\
        \\@/*1*/dec
        \\function foo() {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestCompletionAfterTrailingAtInJSDoc1" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /atTagPosition.js
        \\/**
        \\ * @/*1*/
        \\ */
        \\function foo(x) {}
        \\
        \\// @Filename: /atAfterExistingParam.js
        \\/**
        \\ * @param {string} x ok
        \\ * @/*2*/
        \\ */
        \\function bar(x, y) {}
        \\
        \\// @Filename: /atMidLine.js
        \\/**
        \\ * some text @/*3*/
        \\ */
        \\function baz(y) {}
        \\
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
//             .Includes = &.{
//                 &.{
//                     .Label = "param",
//                     .Kind =  undefined(lsproto.CompletionItemKindKeyword),
//                 },
//             },
//         },
//     });
}

test "TestFormatDocumentNoCrashJsxNamespacedName1" {
    const content =
        \\// @Filename: /a.tsx
        \\const x = <foo:bar />;
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "const x = <foo:bar />;\n");
}

test "TestQuickInfoVerbosityJSDocNamespacedTypedef" {
    const content =
        \\
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /index.js
        \\// Namespaced typedef
        \\/** @typedef {string} /*ns*/NS./*t*/T */
        \\
        \\// Namespaced typedef aliased to qualified namespaced typedef.
        \\/** @typedef {NS.T} NS./*u*/U */
        \\
        \\// Namespaced typedef aliased to implicitly-resolved typedef.
        \\/** @typedef {U} NS./*v*/V */
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{
//         .@"ns" = .{0, 1},
//         .@"t" =  .{0, 1},
//         .@"u" =  .{0, 1},
//         .@"v" =  .{0, 1},
//     });
}

test "TestCompletionsJSDocSignature" {
    const content =
        \\// @noLib: true
        \\// @checkJs: true
        \\// @allowJs: true
        \\// @filename: index.js
        \\/**
        \\ * @type {{
        \\ *   (input: string):/*1*/ X|Y/*2*/
        \\ * }}
        \\ */
        \\let x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{".", ",", ";"},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{},
//     });
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{".", ",", ";"},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{},
//     });
}

test "TestAutoImportDefaultPascalCase" {
    const content =
        \\// @jsx: react
        \\// @module: esnext
        \\// @moduleResolution: bundler
        \\
        \\// @Filename: /src/components/ChargerHeader.tsx
        \\export default function ChargerHeader() {
        \\  return null;
        \\}
        \\
        \\// @Filename: /src/screens/SomeScreen.tsx
        \\export function SomeScreen() {
        \\  return <ChargerHeader/*1*/
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "1", &.{
//         .UserPreferences = &.{
//             .IncludeCompletionsForModuleExports =    core.TSTrue,
//             .IncludeCompletionsForImportStatements = core.TSTrue,
//         },
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{"ChargerHeader"},
//         },
//     });
    // f.BaselineAutoImportsCompletions(undefined, &.{"1"});
    // f.VerifyCompletions(undefined, "1", &.{
//         .UserPreferences = &.{
//             .IncludeCompletionsForModuleExports =    core.TSTrue,
//             .IncludeCompletionsForImportStatements = core.TSTrue,
//         },
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{"ChargerHeader"},
//         },
//     });
    // f.BaselineAutoImportsCompletions(undefined, &.{"1"});
    // f.VerifyCompletions(undefined, "1", &.{
//         .UserPreferences = &.{
//             .IncludeCompletionsForModuleExports =    core.TSTrue,
//             .IncludeCompletionsForImportStatements = core.TSTrue,
//         },
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{"ChargerHeader"},
//         },
//     });
    // f.BaselineAutoImportsCompletions(undefined, &.{"1"});
    // f.VerifyCompletions(undefined, "1", &.{
//         .UserPreferences = &.{
//             .IncludeCompletionsForModuleExports =    core.TSTrue,
//             .IncludeCompletionsForImportStatements = core.TSTrue,
//         },
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{"ChargerHeader"},
//         },
//     });
    // f.BaselineAutoImportsCompletions(undefined, &.{"1"});
    // f.VerifyCompletions(undefined, "1", &.{
//         .UserPreferences = &.{
//             .IncludeCompletionsForModuleExports =    core.TSTrue,
//             .IncludeCompletionsForImportStatements = core.TSTrue,
//         },
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{"ChargerHeader"},
//         },
//     });
    // f.BaselineAutoImportsCompletions(undefined, &.{"1"});
    // f.VerifyCompletions(undefined, "1", &.{
//         .UserPreferences = &.{
//             .IncludeCompletionsForModuleExports =    core.TSTrue,
//             .IncludeCompletionsForImportStatements = core.TSTrue,
//         },
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{"ChargerHeader"},
//         },
//     });
    // f.BaselineAutoImportsCompletions(undefined, &.{"1"});
}

test "TestFindReferencesAcrossMultipleProjectsVS" {
    const content =
        \\//@Filename: a.ts
        \\/*1*/var /*2*/x: number;
        \\//@Filename: b.ts
        \\/// <reference path="a.ts" />
        \\/*3*/x++;
        \\//@Filename: c.ts
        \\/// <reference path="a.ts" />
        \\/*4*/x++;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineVSFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestCompletionsDeprecatedTags" {
    const content =
        \\const o = {
        \\    /** @deprecated */
        \\    a: 1,
        \\    b: 2,
        \\    c: 3,
        \\}
        \\o./**/
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
//                     .Label =    "a",
//                     .Kind =     undefined(lsproto.CompletionItemKindField),
//                     .Tags =     &&.{lsproto.CompletionItemTagDeprecated},
//                     .SortText = undefined(string(ls.DeprecateSortText(ls.SortTextLocationPriority))),
//                 },
//             },
//         },
//     });
}

test "TestFormatJsxDottedTagName" {
    const content =
        \\//@Filename: file.tsx
        \\const x = (
        \\<a-b.c>
        \\<a-b.c></a-b.c>
        \\</a-b.c>
        \\);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "const x = (\n    <a-b.c>\n        <a-b.c></a-b.c>\n    </a-b.c>\n);");
}

test "TestQuickinfoVerbosityIncreaseDecrease" {
    const content =
        \\export const JOB_STATES = ["created", "active", "completed", "failed", "retry", "cancelled", "archive"] as const
        \\export type JobState = (typeof JOB_STATES)[number]
        \\type Color = "default" | "primary" | "secondary" | "success" | "warning" | "danger"
        \\const JobsStateToColor/*a*/: Record<
        \\  JobState,
        \\  {
        \\    color: Color
        \\    label: string
        \\    labelPlural: string
        \\  }
        \\> = {
        \\  created: {
        \\    color: "success",
        \\    label: "Направљен",
        \\    labelPlural: "Направљени",
        \\  },
        \\  active: {
        \\    color: "success",
        \\    label: "Активан",
        \\    labelPlural: "Активни",
        \\  },
        \\  completed: {
        \\    color: "success",
        \\    label: "Успешан",
        \\    labelPlural: "Успешни",
        \\  },
        \\  cancelled: {
        \\    color: "default",
        \\    label: "Отаказан",
        \\    labelPlural: "Отаказни",
        \\  },
        \\  failed: {
        \\    color: "danger",
        \\    label: "Пао",
        \\    labelPlural: "Пали",
        \\  },
        \\  archive: {
        \\    color: "default",
        \\    label: "Архивиран",
        \\    labelPlural: "Архивирани",
        \\  },
        \\  retry: {
        \\    color: "warning",
        \\    label: "Понавља се",
        \\    labelPlural: "Понављају се",
        \\  },
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"a" = .{0, 1, 0}});
}

test "TestGoToImplementationReachingNonExistentExport2" {
    const content =
        \\
        \\// @allowJs: true
        \\// @checkJs: true
        \\
        \\// @Filename: /github.js
        \\module.exports = { transformRecordedData };
        \\
        \\// @Filename: /gitGateway.js
        \\const { transformRecordedData: transformGitHub } = require('./github');
        \\
        \\const methods = { github: {
        \\    transformData: /*impl*/transformGitHub,
        \\}};
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "impl");
}

test "TestCompletionFilterText3" {
    const content =
        \\// @strict: true
        \\declare const foo1: { b: number; "a bc": string; };
        \\if (true) {
        \\    foo1[|.|]/*1*/
        \\} 
        \\else {
        \\    foo1[|.a|]/*2*/
        \\}
        \\
        \\declare const foo2: { b: number; "a bc": string; } | undefined;
        \\if (true) {
        \\    foo2[|.|]/*3*/
        \\} else if (false) {
        \\    foo2[|.a|]/*4*/
        \\} else {
        \\    foo2[|?.|]/*5*/
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =      "a bc",
//                     .Kind =       undefined(lsproto.CompletionItemKindField),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                     .InsertText = undefined("[\"a bc\"]"),
//                     .FilterText = undefined(".a bc"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "[\"a bc\"]",
//                             .Range =   f.Ranges()[0].LSRange,
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
//                     .Label =      "a bc",
//                     .Kind =       undefined(lsproto.CompletionItemKindField),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                     .InsertText = undefined("[\"a bc\"]"),
//                     .FilterText = undefined(".a bc"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "[\"a bc\"]",
//                             .Range =   f.Ranges()[1].LSRange,
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
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =      "a bc",
//                     .Kind =       undefined(lsproto.CompletionItemKindField),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                     .InsertText = undefined("?.[\"a bc\"]"),
//                     .FilterText = undefined(".a bc"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "?.[\"a bc\"]",
//                             .Range =   f.Ranges()[2].LSRange,
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
//                     .Label =      "a bc",
//                     .Kind =       undefined(lsproto.CompletionItemKindField),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                     .InsertText = undefined("?.[\"a bc\"]"),
//                     .FilterText = undefined(".a bc"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "?.[\"a bc\"]",
//                             .Range =   f.Ranges()[3].LSRange,
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
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =      "a bc",
//                     .Kind =       undefined(lsproto.CompletionItemKindField),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                     .InsertText = undefined("?.[\"a bc\"]"),
//                     .FilterText = undefined("?.a bc"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "?.[\"a bc\"]",
//                             .Range =   f.Ranges()[4].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestCallHierarchyAnonymousFunctionNoCrash2" {
    const content =
        \\// @Filename: /main.ts
        \\(func/*1*/tion() {})
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifyBaselineCallHierarchy(undefined);
}

test "TestBasicBackspace" {
    const content =
        \\export {};
        \\interface Point {
        \\    x: number;
        \\    y: number;/*b*/
        \\}
        \\declare const p: Point;
        \\p./*a*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "a", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//         },
//         .Items = &.{
//             .Includes = &.{"y"},
//         },
//     });
    _ = f.GoToMarker(undefined, "b");
    _ = f.Backspace(undefined, 10);
    // f.VerifyCompletions(undefined, "a", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//         },
//         .Items = &.{
//             .Excludes = &.{"y"},
//         },
//     });
}

test "TestQuickinfoVerbosityClassInterfaceMerge" {
    const content =
        \\
        \\declare class Foo/*1*/ {
        \\    x: number;
        \\}
        \\declare interface Foo {
        \\    y: string;
        \\}
        \\const f: Foo/*2*/ = { x: 1, y: "hello" };
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{
//         .@"1" = .{0, 1},
//         .@"2" = .{0, 1},
//     });
}

test "TestAutoImportExportEqualsOfImportStar" {
    const content =
        \\// @module: commonjs
        \\// @Filename: /node_modules/mdx/package.json
        \\{ "name": "mdx", "version": "1.0.0", "types": "index.d.ts" }
        \\// @Filename: /node_modules/mdx/index.d.ts
        \\import * as mdx from './lib/index.js'
        \\
        \\export = mdx
        \\// @Filename: /node_modules/mdx/lib/index.d.ts
        \\export * from './core.js'
        \\export * from './compile.js'
        \\// @Filename: /node_modules/mdx/lib/core.d.ts
        \\export declare function core(): void
        \\// @Filename: /node_modules/mdx/lib/compile.d.ts
        \\export declare function compile(): void
        \\// @Filename: /package.json
        \\{ "dependencies": { "mdx": "*" } }
        \\// @Filename: /index.ts
        \\mdx/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
}

test "TestUnreachableCodeDiagnostics" {
    const content =
        \\// @allowUnreachableCode: false
        \\throw new Error();
        \\    
        \\(() => {})();
        \\    
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestStringCompletionDetails" {
    const content =
        \\const a: "aa" | "bb" = "/**/";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "aa",
//                     .Kind =   undefined(lsproto.CompletionItemKindConstant),
//                     .Detail = undefined("aa"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .Range = .{
//                                 .Start = .{.Line = 0, .Character = 24},
//                                 .End =   .{.Line = 0, .Character = 24},
//                             },
//                             .NewText = "aa",
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestAutoImportSymlinkedMonorepoProjectReferences" {
    const content =
        \\// @Filename: /packages/project-b/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "composite": true,
        \\    "outDir": "./dist",
        \\    "rootDir": "./src",
        \\    "declaration": true,
        \\    "module": "commonjs",
        \\    "strict": true
        \\  },
        \\  "include": ["src"]
        \\}
        \\// @Filename: /packages/project-b/package.json
        \\{
        \\  "name": "project-b",
        \\  "version": "1.0.0",
        \\  "exports": {
        \\    ".": {
        \\      "types": "./dist/index.d.ts",
        \\      "default": "./dist/index.js"
        \\    }
        \\  }
        \\}
        \\// @Filename: /packages/project-b/src/index.ts
        \\export const projectBValue: number = 42;
        \\export function projectBFunction(): string { return "hello"; }
        \\// @Filename: /packages/project-b/dist/index.d.ts
        \\export declare const projectBValue: number;
        \\export declare function projectBFunction(): string;
        \\// @Filename: /packages/project-a/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "commonjs",
        \\    "strict": true,
        \\    "outDir": "./dist",
        \\    "rootDir": "./src"
        \\  },
        \\  "include": ["src"],
        \\  "references": [{ "path": "../project-b" }]
        \\}
        \\// @Filename: /packages/project-a/package.json
        \\{ "name": "project-a", "dependencies": { "project-b": "*" } }
        \\// @Filename: /packages/project-a/src/index.ts
        \\import { projectBValue } from "project-b";
        \\console.log(projectBValue);
        \\projectBFunc/**/
        \\// @link: /packages/project-b -> /packages/project-a/node_modules/project-b
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
}

test "TestGoToImplementationReachingNonExistentExport1" {
    const content =
        \\
        \\// @Filename: /github.ts
        \\export { transformRecordedData };
        \\
        \\// @Filename: /gitGateway.ts
        \\import { transformRecordedData as transformGitHub } from './github';
        \\
        \\const methods = { github: {
        \\    transformData: /*impl*/transformGitHub,
        \\}};
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "impl");
}

test "TestImportModuleSpecifierPreferenceShortest" {
    const content =
        \\// @Filename: /project/src/utils/helper.ts
        \\export const helperFunc = () => {};
        \\// @Filename: /project/src/index.ts
        \\helper/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.Configure(undefined, .{
//         .IncludeCompletionsForModuleExports =    core.TSTrue,
//         .IncludeCompletionsForImportStatements = core.TSTrue,
//         .ImportModuleSpecifierPreference =       modulespecifiers.ImportModuleSpecifierPreferenceShortest,
//     });
    // f.VerifyCompletions(undefined, "", &.{
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{"helperFunc"},
//         },
//     });
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
    // f.Configure(undefined, .{
//         .IncludeCompletionsForModuleExports =    core.TSTrue,
//         .IncludeCompletionsForImportStatements = core.TSTrue,
//         .ImportModuleSpecifierPreference =       modulespecifiers.ImportModuleSpecifierPreferenceProjectRelative,
//     });
    // f.VerifyCompletions(undefined, "", &.{
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{"helperFunc"},
//         },
//     });
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
    // f.Configure(undefined, .{
//         .IncludeCompletionsForModuleExports =    core.TSTrue,
//         .IncludeCompletionsForImportStatements = core.TSTrue,
//         .ImportModuleSpecifierPreference =       modulespecifiers.ImportModuleSpecifierPreferenceRelative,
//     });
    // f.VerifyCompletions(undefined, "", &.{
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{"helperFunc"},
//         },
//     });
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
    // f.Configure(undefined, .{
//         .IncludeCompletionsForModuleExports =    core.TSTrue,
//         .IncludeCompletionsForImportStatements = core.TSTrue,
//         .ImportModuleSpecifierPreference =       modulespecifiers.ImportModuleSpecifierPreferenceProjectRelative,
//     });
    // f.VerifyCompletions(undefined, "", &.{
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{"helperFunc"},
//         },
//     });
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
    // f.Configure(undefined, .{
//         .IncludeCompletionsForModuleExports =    core.TSTrue,
//         .IncludeCompletionsForImportStatements = core.TSTrue,
//         .ImportModuleSpecifierPreference =       modulespecifiers.ImportModuleSpecifierPreferenceNonRelative,
//     });
    // f.VerifyCompletions(undefined, "", &.{
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{"helperFunc"},
//         },
//     });
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
}

test "TestCodeLensOverloads01" {
    const content =
        \\
        \\export function foo(x: number): number;
        \\export function foo(x: string): string;
        \\export function foo(x: string | number): string | number {
        \\    return x;
        \\}
        \\
        \\foo(1);
        \\
        \\foo("hello");
        \\
        \\// This one isn't expected to match any overload,
        \\// but is really just here to test how it affects how code lens.
        \\foo(Math.random() ? 1 : "hello");
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineCodeLens(undefined, &.{
//         .CodeLens = .{
//             .ReferencesCodeLensEnabled =            core.TSTrue,
//             .ReferencesCodeLensShowOnAllFunctions = core.TSTrue,
// 
//             .ImplementationsCodeLensEnabled =                core.TSTrue,
//             .ImplementationsCodeLensShowOnInterfaceMethods = core.TSTrue,
//             .ImplementationsCodeLensShowOnAllClassMethods =  core.TSTrue,
//         },
//     });
}

test "TestHoverQualifiedGenericNames" {
    const content =
        \\
        \\function f<T>(x: T) {
        \\    class C {
        \\        value = x
        \\    }
        \\    return new C()
        \\}
        \\
        \\class A<T> {
        \\    foo() {}
        \\}
        \\class B extends A<string> {}
        \\
        \\let t1/*1*/ = f("hello")
        \\const t2/*2*/ = new B()
        \\t2./*3*/foo()
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "let t1: f<string>.C", "");
    // f.VerifyQuickInfoAt(undefined, "2", "const t2: B", "");
    // f.VerifyQuickInfoAt(undefined, "3", "(method) A<string>.foo(): void", "");
}

test "TestFormatDocumentZeroTabSize" {
    const content =
        \\function foo() {
        \\    if (true) {
        \\        var x = 1;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts);
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "function foo() {\nif (true) {\nvar x = 1;\n}\n}");
}

test "TestInlayHintsPropertyDeclarationComputedName1" {
    const content =
        \\function foo() {
        \\  const sym = Symbol();
        \\  class C {
        \\    [sym] = 123;
        \\  }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{
//         .InlayHints = .{
//             .IncludeInlayPropertyDeclarationTypeHints = core.TSTrue,
//         },
//     });
}

test "TestQuickinfoVerbosityAbstractClass" {
    const content =
        \\
        \\declare abstract class Shape/*1*/ {
        \\    abstract area(): number;
        \\    abstract perimeter(): number;
        \\    toString(): string;
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{0, 1}});
}

test "TestSignatureHelpOnTypeArgumentsWithUnresolvedTarget" {
    const content =
        \\
        \\/*1*/un/*2*/resolvedVal/*3*/</*4*/Un/*5*/resolvedType/*6*/>/*7*/(/*8*/un/*9*/resolvedVal/*10*/);
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GoToEachMarker(undefined, null, func(marker *fourslash.Marker, index int) .{
//         f.VerifyNoSignatureHelp(undefined)
//     });
}

test "TestSourceFixAllImports" {
    const content =
        \\// @Filename: /a.ts
        \\export const a: number = 1;
        \\// @Filename: /b.ts
        \\export const b: number = 2;
        \\// @Filename: /main.ts
        \\a;
        \\b;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/main.ts");
    _ = f.VerifyCodeFixAll(undefined, .{
        .FixID = "fixMissingImport",
        .NewFileContent = "import { a } from \"./a\";\nimport { b } from \"./b\";\n\na;\nb;",
    });
    _ = f.GoToFile(undefined, "/main.ts");
    _ = f.VerifySourceFixAll(undefined, "import { a } from \"./a\";\nimport { b } from \"./b\";\n\na;\nb;");
}

test "TestCompletionListInUnclosedTypeArguments" {
    const content =
        \\let x = 10;
        \\type Type = void;
        \\declare function f<T>(): void;
        \\declare function f2<T, U>(): void;
        \\f</*1a*/T/*2a*/y/*3a*/
        \\f</*1b*/T/*2b*/y/*3b*/;
        \\f</*1c*/T/*2c*/y/*3c*/>
        \\f</*1d*/T/*2d*/y/*3d*/>
        \\f</*1e*/T/*2e*/y/*3e*/>();
        \\
        \\f2</*1k*/T/*2k*/y/*3k*/,
        \\f2</*1l*/T/*2l*/y/*3l*/,{| "newId": true |}T{| "newId": true |}y{| "newId": true |}
        \\f2</*1m*/T/*2m*/y/*3m*/,{| "newId": true |}T{| "newId": true |}y{| "newId": true |};
        \\f2</*1n*/T/*2n*/y/*3n*/,{| "newId": false |}T{| "newId": false |}y{| "newId": false |}>
        \\f2</*1o*/T/*2o*/y/*3o*/,{| "newId": false |}T{| "newId": false |}y{| "newId": false |}>
        \\f2</*1p*/T/*2p*/y/*3p*/,{| "newId": true, "typeOnly": true |}T{| "newId": true, "typeOnly": true |}y{| "newId": true, "typeOnly": true |}>();
        \\
        \\f2<typeof /*1uValueOnly*/x, {| "newId": true |}T{| "newId": true |}y{| "newId": true |}
        \\
        \\f2</*1x*/T/*2x*/y/*3x*/, () =>/*4x*/T/*5x*/y/*6x*/
        \\f2<() =>/*1y*/T/*2y*/y/*3y*/, () =>/*4y*/T/*5y*/y/*6y*/
        \\f2<any, () =>/*1z*/T/*2z*/y/*3z*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GoToEachMarker(undefined, null, func(marker *fourslash.Marker, index int) .{
//         .markerName == marker.Name
//         .valueOnly == markerName != null && strings.HasSuffix(*markerName, "ValueOnly")
//         .commitCharacters == &DefaultCommitCharacters
//         if marker.Data != null .{
//             .newId == marker.Data["newId"]
//             .typeOnly == marker.Data["typeOnly"]
//             if newId != null && newId.(bool) && !(typeOnly != null && typeOnly.(bool)) .{
//                 commitCharacters = &&.{".", ";"}
//             }
//         }
//         var includes []fourslash.CompletionsExpectedItem
//         var excludes []string
//         if valueOnly .{
//             includes = &.{
//                 "x",
//             }
//             excludes = &.{
//                 "Type",
//             }
//         } else .{
//             includes = &.{
//                 "Type",
//             }
//             excludes = &.{
//                 "x",
//             }
//         }
//         f.VerifyCompletions(undefined, marker, &.{
//             .IsIncomplete = false,
//             .ItemDefaults = &.{
//                 .CommitCharacters = commitCharacters,
//                 .EditRange =        Ignored,
//             },
//             .Items = &.{
//                 .Includes = includes,
//                 .Excludes = excludes,
//             },
//         })
//     });
}

test "TestCallHierarchyAnonymousClassNoCrash1" {
    const content =
        \\// @Filename: /main.ts
        \\class {
        \\    con/*1*/structor() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifyBaselineCallHierarchy(undefined);
}

test "TestQuickInfoFunction" {
    const content =
        \\/**/function foo() { return "hi"; }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "function foo(): string", "");
}

test "TestCallHierarchyIncomingCallsObjectLiteralMethodInIdentifierComputedProperty" {
    const content =
        \\const key = "x";
        \\const obj = {
        \\  [key]: {
        \\    method() {
        \\      return ""./*split*/split(",");
        \\    }
        \\  }
        \\};
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "split");
    // f.VerifyBaselineCallHierarchy(undefined);
}

test "TestFoldingRangeLineFoldingOnly" {
    const content =
        \\if (EMPTY_TAGs.has(tag)) {
        \\  output += "/>";
        \\} else {
        \\  output += ">";
        \\
        \\  if (!html && kidcount > 0) {
        \\    //
        \\  }
        \\}
        \\
        \\export function use<T>(ctx: any): T | undefined {
        \\  //
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyFoldingRangeLines(undefined, &.{
        .{.StartLine = 0, .EndLine = 1},   // if .block = end adjusted from line 2 to 1
        .{.StartLine = 2, .EndLine = 7},   // else .block = end adjusted from line 8 to 7
        .{.StartLine = 5, .EndLine = 6},   // inner if .block = end adjusted from line 7 to 6
        .{.StartLine = 10, .EndLine = 11}, // .function = end adjusted from line 12 to 11
    });
    _ = f.VerifyFoldingRangeLines(undefined, &.{
        .{.StartLine = 0, .EndLine = 5},  // #region .MyRegion = NOT adjusted (ends with "n", not a closing pair)
        .{.StartLine = 2, .EndLine = 3},  // function foo() .block = end adjusted from line 4 to 3
        .{.StartLine = 7, .EndLine = 12}, // #region .Outer = NOT adjusted
        .{.StartLine = 9, .EndLine = 11}, // #region .Inner = NOT adjusted
    });
}

test "TestFindAllRefsParameterPropertyWithConflictingMember" {
    const content =
        \\
        \\// @filename: c1.ts
        \\class C1 {
        \\  [|x|]() {}
        \\  constructor(public [|x|]: number) {
        \\    [|x|]++;
        \\  }
        \\}
        \\new C1(1).[|x|];
        \\
        \\// @filename: c2.ts
        \\interface C2 {
        \\  get [|x|](): void
        \\}
        \\class C2 {
        \\  constructor(public [|x|]: number) {
        \\    [|x|]++;
        \\  }
        \\}
        \\new C2(1).[|x|];
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined);
}

test "TestSignatureHelpAnonymousType" {
    const content =
        \\const comparers: Array<(a: any, b: any) => boolean> = [];
        \\
        \\comparers.push((a,/**/ b) => true);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSignatureHelp(undefined);
}

test "TestCompletionResolveAfterEdit" {
    const content =
        \\
        \\// @filename: /index.ts
        \\interface Point {
        \\    x: number;
        \\    y: number;
        \\}
        \\declare const p: Point;
        \\/*a*/
        \\
        \\// @filename: /foo.ts
        \\/*b*/
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "a");
    // f.GetCompletions(undefined, null );
    _ = f.GoToMarker(undefined, "b");
    _ = f.Insert(undefined, "1");
    // f.ResolveCompletionItem(undefined, firstItem);
}

test "TestCompletionWithUnterminatedJSDocEndingWithAt2" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /atInTextAtEOF.js
        \\function foo(x) {}
        \\/** some text @/*1*/
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
//                     .Label = "param",
//                     .Kind =  undefined(lsproto.CompletionItemKindKeyword),
//                 },
//             },
//         },
//     });
}

test "TestOrganizeImports_coalesceExports_sortSpecifiersCaseInsensitive" {
    const content =
        \\export { default as M, a as n, B, y, Z as O } from "lib";
        \\void 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(
//         undefined,
//         "export { B, default as M, a as n, Z as O, y } from \"lib\";\nvoid 0;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "export * from \"lib\";\nvoid 0;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "const x = 1, z = 2;\nexport { x, z as y };\nvoid 0;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "export { x, y as z } from \"lib\";\nvoid 0;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "export { z } from \"aaa\";\nexport * from \"lib\";\nexport { y } from \"lib\";\nvoid 0;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "const x = 1, w = 2, z = 3, q = 4;\nexport { z as default, q as w, x, w as y };\nvoid 0;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "export * from \"lib\";\nexport { x as a, z as b, y } from \"lib\";\nvoid 0;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "const x = 1;\ntype y = string;\nexport { z } from \"aaa\";\nexport { x };\nexport type { y };\nvoid 0;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "type x = string;\ntype y = number;\nexport type { x, y };\nvoid 0;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
}

test "TestAutoImportSymlinkedMonorepoGranularUpdate" {
    const content =
        \\// @Filename: /packages/project-b/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "composite": true,
        \\    "outDir": "./dist",
        \\    "rootDir": "./src",
        \\    "declaration": true,
        \\    "module": "commonjs",
        \\    "strict": true
        \\  },
        \\  "include": ["src"]
        \\}
        \\// @Filename: /packages/project-b/package.json
        \\{
        \\  "name": "project-b",
        \\  "version": "1.0.0",
        \\  "exports": {
        \\    ".": {
        \\      "types": "./dist/index.d.ts",
        \\      "default": "./dist/index.js"
        \\    }
        \\  }
        \\}
        \\// @Filename: /packages/project-b/src/index.ts
        \\export const projectBValue: number = 42;
        \\/*projectBEdit*/
        \\// @Filename: /packages/project-b/dist/index.d.ts
        \\export declare const projectBValue: number;
        \\// @Filename: /packages/project-a/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "commonjs",
        \\    "strict": true,
        \\    "outDir": "./dist",
        \\    "rootDir": "./src"
        \\  },
        \\  "include": ["src"],
        \\  "references": [{ "path": "../project-b" }]
        \\}
        \\// @Filename: /packages/project-a/package.json
        \\{ "name": "project-a", "dependencies": { "project-b": "*" } }
        \\// @Filename: /packages/project-a/src/index.ts
        \\import { projectBValue } from "project-b";
        \\console.log(projectBValue);
        \\newlyAdded/*projectACompletion*/
        \\// @link: /packages/project-b -> /packages/project-a/node_modules/project-b
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "projectACompletion");
    // f.BaselineAutoImportsCompletions(undefined, &.{"projectACompletion"});
    _ = f.GoToMarker(undefined, "projectBEdit");
    _ = f.Insert(undefined, "\nexport function newlyAddedFunction(): void {}");
    _ = f.GoToMarker(undefined, "projectACompletion");
    // f.BaselineAutoImportsCompletions(undefined, &.{"projectACompletion"});
}

test "TestAutoImportCssModule" {
    const content =
        \\
        \\// @Filename: /tsconfig.json
        \\{ "compilerOptions": { "module": "nodenext", "moduleResolution": "nodenext" } }
        \\
        \\// @Filename: /package.json
        \\{ "type": "module" }
        \\
        \\// @Filename: /augmentations.ts
        \\export {};
        \\declare module "./styles.css" {
        \\    export const myClass: string;
        \\}
        \\
        \\// @Filename: /index.ts
        \\myClass/**/
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
//                 &.{
//                     .Label = "myClass",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./styles.css",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
}

test "TestCallHierarchyAnonymousClassNoCrash3" {
    const content =
        \\// @Filename: /main.ts
        \\import Bar from "./other";
        \\
        \\function foo() {
        \\    new /*1*/Bar();
        \\}
        \\// @Filename: /other.ts
        \\export default class {
        \\    constructor() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifyBaselineCallHierarchy(undefined);
}

test "TestRenameFilePackageJson" {
    const content =
        \\// @Filename: /src/example.ts
        \\import brushPackageJson from './visx-brush//*rename*/package.json';
        \\// @Filename: /src/visx-brush/package.json
        \\{ "name": "brush" }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyRename(undefined, "rename", "package2.json", .{
//         .@"/src/example.ts" =               "import brushPackageJson from './visx-brush/package2.json';",
//         .@"/src/visx-brush/package2.json" = "{ \"name\": \"brush\" }",
//     });
}

test "TestChineseCharacterDisplayInHover" {
    const content =
        \\
        \\interface 中文界面 {
        \\    上居中: string;
        \\    下居中: string;
        \\}
        \\
        \\class 中文类 {
        \\    获取中文属性(): 中文界面 {
        \\        return {
        \\            上居中: "上居中",
        \\            下居中: "下居中"
        \\        };
        \\    }
        \\}
        \\
        \\let /*instanceHover*/实例 = new 中文类();
        \\let 属性对象 = 实例./*methodHover*/获取中文属性();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "instanceHover", "let 实例: 中文类", "");
    // f.VerifyQuickInfoAt(undefined, "methodHover", "(method) 中文类.获取中文属性(): 中文界面", "");
    // f.VerifyQuickInfoAt(undefined, "method", "(method) TSLine.setLengthTextPositionPreset(preset: \"上居中\" | \"下居中\" | \"右居中\" | \"左居中\"): void", "");
}

test "TestCompletionJsxNoCrash" {
    const content =
        \\
        \\// @filename: file.tsx
        \\<Foo/>/*1*/
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{.CommitCharacters = &&.{".", ",", ";"}},
//         .Items =        &.{},
//     });
}

test "TestGoToSourceMappedTypePropertyWithMatch" {
    const content =
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/package.json
        \\{ "name": "pkg", "main": "./index.js", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.d.ts
        \\export declare const obj: { a: number; b: number };
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.js
        \\export const obj = { /*targetA*/a: 1, /*targetB*/b: 2 };
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { obj } from "pkg";
        \\obj./*propA*/a;
        \\obj./*propB*/b;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "propA", "propB");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "helperAccess", "valueAccess");
}

test "TestQuickInfoContextualObjectMethodJSDoc" {
    const content =
        \\
        \\interface I {
        \\    /**
        \\     * Description of func.
        \\     * @param arg Description of arg.
        \\     */
        \\    func(arg: number): void
        \\}
        \\
        \\class Foo {
        \\    constructor(i: I) {}
        \\}
        \\
        \\new Foo({ func/*1*/() {} })
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(method) I.func(arg: number): void", "Description of func.\n\n*@param* `arg` — Description of arg.");
}

test "TestGoToSourceDefinitionUnresolvedTripleSlash" {
    const content =
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\/// <reference /*marker*/path="nonexistent.ts" />
        \\export {};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "marker");
}

test "TestQuickInfoAmbientModule" {
    const content =
        \\declare module "*.css"/*1*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "module \"*.css\"", "");
}

test "TestOrganizeImports_removeUnused_preservesMultiline" {
    const content =
        \\import {
        \\    a,
        \\    b,
        \\    c,
        \\} from "module";
        \\
        \\export { a, b, c };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(
//         undefined,
//         "import {\n    a,\n    b,\n    c,\n} from \"module\";\n\nexport { a, b, c };",
//         lsproto.CodeActionKindSourceRemoveUnusedImports,
//         null,
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "import {\n    a,\n    c\n} from \"module\";\n\nexport { a, c };",
//         lsproto.CodeActionKindSourceRemoveUnusedImports,
//         null,
//     );
}

test "TestCompletionsUnterminatedLiteral" {
    const content =
        \\// @noLib: true
        \\function foo(a"/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "1", &.{
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//         },
//         .Items = &.{},
//     });
}

test "TestQuickInfoMergedAlias" {
    const content =
        \\// @filename: /a.ts
        \\/**
        \\ * A function
        \\ */
        \\export function foo/*1*/() {}
        \\// @filename: /b.ts
        \\import { foo/*2*/ } from './a';
        \\export { foo/*3*/ };
        \\
        \\/**
        \\ * A type
        \\ */
        \\type foo/*4*/ = number;
        \\
        \\foo/*5*/()
        \\let x1: foo/*6*/;
        \\// @filename: /c.ts
        \\import { foo/*7*/ } from './b';
        \\
        \\/**
        \\ * A namespace
        \\ */
        \\namespace foo/*8*/ {
        \\    export type bar = string[];
        \\}
        \\
        \\foo/*9*/()
        \\let x1: foo/*10*/;
        \\let x2: foo/*11*/.bar;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestAutoImportFileExcludePatterns" {
    const content =
        \\// @Filename: foo.ts
        \\export const mySymbol = 1;
        \\// @Filename: ignoreme.ts
        \\export const ignoredSymbol = 2;
        \\// @Filename: bar.ts
        \\mySym/*1*/
        \\ignoredSym/*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.Configure(undefined, .{
//         .AutoImportFileExcludePatterns =         &.{"*ignoreme.ts"},
//         .IncludeCompletionsForModuleExports =    core.TSTrue,
//         .IncludeCompletionsForImportStatements = core.TSTrue,
//     });
    // f.VerifyCompletions(undefined, "1", &.{
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{"mySymbol"},
//         },
//     });
    // f.VerifyCompletions(undefined, "2", &.{
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Excludes = &.{"ignoredSymbol"},
//         },
//     });
    // f.BaselineAutoImportsCompletions(undefined, &.{"1", "2"});
}

test "TestGoToSourceDefinitionTypeOnlyImportFallsBackToDeclaration" {
    const content =
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/package.json
        \\{ "name": "pkg", "main": "./index.js", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.d.ts
        \\export interface /*targetDecl*/Config {
        \\    name: string;
        \\    value: number;
        \\}
        \\export declare function create(config: Config): void;
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.js
        \\export function create(config) { return config; }
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { /*importConfig*/Config, create } from "pkg";
        \\const c: Config = { name: "test", value: 1 };
        \\create(c);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importConfig");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "usageSite");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importCreate");
}

test "TestPathCompletionsPartialPathRelativeImport" {
    const content =
        \\// @Filename: /src/main.ts
        \\import { } from "./foo//*$*/";
        \\// @Filename: /src/foo/async.ts
        \\export const asyncApi = "async";
        \\// @Filename: /src/foo/fs.ts
        \\export const fsApi = "fs";
        \\// @Filename: /src/foo/sync.ts
        \\export const syncApi = "sync";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "$", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "async",
//                 "fs",
//                 "sync",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "$", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "async",
//                 "fs",
//                 "sync",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "$", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "async",
//                 "fs",
//                 "sync",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "$", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "async",
//                 "fs",
//                 "sync",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "$", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "_async/api",
//                 "_fs/api",
//                 "_sync/api",
//             },
//         },
//     });
}

test "TestImportModuleSpecifierEndingAuto" {
    const content =
        \\// @Filename: /project/helper/index.ts
        \\export const helperFunc = () => {};
        \\// @Filename: /project/index.ts
        \\helper/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.Configure(undefined, .{
//         .IncludeCompletionsForModuleExports =    core.TSTrue,
//         .IncludeCompletionsForImportStatements = core.TSTrue,
//         .ImportModuleSpecifierEnding =           modulespecifiers.ImportModuleSpecifierEndingPreferenceAuto,
//     });
    // f.VerifyCompletions(undefined, "", &.{
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{"helperFunc"},
//         },
//     });
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
    // f.Configure(undefined, .{
//         .IncludeCompletionsForModuleExports =    core.TSTrue,
//         .IncludeCompletionsForImportStatements = core.TSTrue,
//         .ImportModuleSpecifierEnding =           modulespecifiers.ImportModuleSpecifierEndingPreferenceMinimal,
//     });
    // f.VerifyCompletions(undefined, "", &.{
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{"helperFunc"},
//         },
//     });
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
    // f.Configure(undefined, .{
//         .IncludeCompletionsForModuleExports =    core.TSTrue,
//         .IncludeCompletionsForImportStatements = core.TSTrue,
//         .ImportModuleSpecifierEnding =           modulespecifiers.ImportModuleSpecifierEndingPreferenceIndex,
//     });
    // f.VerifyCompletions(undefined, "", &.{
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{"helperFunc"},
//         },
//     });
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
    // f.Configure(undefined, .{
//         .IncludeCompletionsForModuleExports =    core.TSTrue,
//         .IncludeCompletionsForImportStatements = core.TSTrue,
//         .ImportModuleSpecifierEnding =           modulespecifiers.ImportModuleSpecifierEndingPreferenceJs,
//     });
    // f.VerifyCompletions(undefined, "", &.{
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{"helperFunc"},
//         },
//     });
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
}

test "TestGetEditsForFileRename_cssImport2" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{ "compilerOptions": { "allowArbitraryExtensions": true } }
        \\// @Filename: /app.css
        \\.cookie-banner {
        \\  display: none;
        \\}
        \\// @Filename: /app.d.css.ts
        \\declare const css: {
        \\  cookieBanner: string;
        \\};
        \\export default css;
        \\// @Filename: /a.ts
        \\import styles from "./app.css";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyWillRenameFilesEdits(undefined, "/app.d.css.ts", "/app2.d.css.ts", .{
//         .@"/a.ts" = "import styles from \"./app2.css\";",
//         .@"/app2.css" = ".cookie-banner {\n  display: none;\n}",
//         .@"/app2.d.css.ts" = "declare const css: {\n  cookieBanner: string;\n};\nexport default css;",
//     }, null );
}

test "TestGoToSourceNamedAndDefaultExport" {
    const content =
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/package.json
        \\{ "name": "pkg", "main": "./index.js", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.d.ts
        \\export default class Widget {}
        \\export declare function helper(): void;
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.js
        \\export default class /*targetWidget*/Widget {}
        \\export function /*targetHelper*/helper() {}
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import /*importDefault*/Widget, { /*importHelper*/helper } from "pkg";
        \\Widget;
        \\helper();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importDefault", "importHelper");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importDefault");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importDefault", "usage");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "defaultImport");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "usage");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importName");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "defaultName", "callDefault");
}

test "TestGoToSourceFallbacksToDefinitionForInterface" {
    const content =
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/package.json
        \\{ "name": "pkg", "main": "./index.js", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.d.ts
        \\export interface /*target*/Config {
        \\    enabled: boolean;
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.js
        \\exports.makeConfig = () => ({ enabled: true });
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import type { /*importName*/Config } from "pkg";
        \\let value: /*typeRef*/Config;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importName", "typeRef");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "typeRef", "callRef");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importName");
}

test "TestFindAllRefsInheritedProperties1VS" {
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
    // f.VerifyBaselineVSFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestDocCommentTemplateWithMultipleJSDoc1" {
    const content =
        \\/** */
        \\/*/**/
        \\function foo() {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyJSDocCompletion(undefined, "", 3, "/** */", null);
}

test "TestFindAllRefsForImportCallType" {
    const content =
        \\// @Filename: /app.ts
        \\export function he/**/llo() {};
        \\// @Filename: /re-export.ts
        \\export type app = typeof import("./app")
        \\// @Filename: /indirect-use.ts
        \\import type { app } from "./re-export";
        \\declare const app: app
        \\app.hello();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestCallHierarchyClassStaticBlock" {
    const content =
        \\class C {
        \\    static {
        \\        function foo() {
        \\            bar();
        \\        }
        \\
        \\        function /**/bar() {
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

test "TestGoToDefinitionImportedNames4" {
    const content =
        \\// @Filename: b.ts
        \\import {Class as [|/*classAliasDefinition*/ClassAlias|]} from "./a";
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

test "TestCompletionsImport_weirdDefaultSynthesis" {
    const content =
        \\// @module: commonjs
        \\// @esModuleInterop: false
        \\// @allowSyntheticDefaultImports: false
        \\// @Filename: /collection.ts
        \\class Collection {
        \\  public static readonly default: typeof Collection = Collection;
        \\}
        \\export = Collection as typeof Collection & { default: typeof Collection };
        \\// @Filename: /index.ts
        \\Colle/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "Collection",
//         .Source =      "./collection",
//         .Description = "Add import from \"./collection\"",
//         .NewFileContent = undefined("import Collection = require(\"./collection\");\n\nColle"),
//     });
}

test "TestGoToDefinitionVariableAssignment2" {
    const content =
        \\// @filename: foo.ts
        \\const Bar;
        \\const Foo = /*def*/Bar = function () {}
        \\Foo.prototype.bar = function() {}
        \\new [|Foo/*ref*/|]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "foo.ts");
    // f.VerifyBaselineGoToDefinition(undefined, true, "ref");
}

test "TestReferencesForLabel" {
    const content =
        \\/*1*/label: while (true) {
        \\    if (false) /*2*/break /*3*/label;
        \\    if (true) /*4*/continue /*5*/label;
        \\}
        \\
        \\/*6*/label: while (false) { }
        \\var label = "label";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6");
}

test "TestSignatureHelpExplicitTypeArguments" {
    const content =
        \\declare function f<T = boolean, U = string>(x: T, y: U): T;
        \\f<number, string>(/*1*/);
        \\f(/*2*/);
        \\f<number>(/*3*/);
        \\f<number, string, boolean>(/*4*/);
        \\interface A { a: number }
        \\interface B extends A { b: string }
        \\declare function g<T, U, V extends A = B>(x: T, y: U, z: V): T;
        \\declare function h<T, U, V extends A>(x: T, y: U, z: V): T;
        \\declare function j<T, U, V = B>(x: T, y: U, z: V): T;
        \\g(/*5*/);
        \\h(/*6*/);
        \\j(/*7*/);
        \\g<number>(/*8*/);
        \\h<number>(/*9*/);
        \\j<number>(/*10*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifySignatureHelp(undefined, .{.Text = "f(x: number, y: string): number"});
    _ = f.GoToMarker(undefined, "2");
    // f.VerifySignatureHelp(undefined, .{.Text = "f(x: boolean, y: string): boolean"});
    _ = f.GoToMarker(undefined, "3");
    // f.VerifySignatureHelp(undefined, .{.Text = "f(x: number, y: string): number"});
    _ = f.GoToMarker(undefined, "4");
    // f.VerifySignatureHelp(undefined, .{.Text = "f(x: number, y: string): number"});
    _ = f.GoToMarker(undefined, "5");
    // f.VerifySignatureHelp(undefined, .{.Text = "g(x: unknown, y: unknown, z: B): unknown"});
    _ = f.GoToMarker(undefined, "6");
    // f.VerifySignatureHelp(undefined, .{.Text = "h(x: unknown, y: unknown, z: A): unknown"});
    _ = f.GoToMarker(undefined, "7");
    // f.VerifySignatureHelp(undefined, .{.Text = "j(x: unknown, y: unknown, z: B): unknown"});
    _ = f.GoToMarker(undefined, "8");
    // f.VerifySignatureHelp(undefined, .{.Text = "g(x: number, y: unknown, z: B): number"});
    _ = f.GoToMarker(undefined, "9");
    // f.VerifySignatureHelp(undefined, .{.Text = "h(x: number, y: unknown, z: A): number"});
    _ = f.GoToMarker(undefined, "10");
    // f.VerifySignatureHelp(undefined, .{.Text = "j(x: number, y: unknown, z: B): number"});
}

test "TestCodeFixClassImplementInterfaceInNamespace" {
    const content =
        \\namespace N1 {
        \\    export interface I1 {
        \\        f1():string;
        \\    }
        \\}
        \\interface I1 {
        \\    f1();
        \\}
        \\
        \\class C1 implements N1.I1 {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'N1.I1'",
        .NewFileContent = "namespace N1 {\n    export interface I1 {\n        f1():string;\n    }\n}\ninterface I1 {\n    f1();\n}\n\nclass C1 implements N1.I1 {\n    f1(): string {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestGetJavaScriptSyntacticDiagnostics01" {
    const content =
        \\// @lib: es5
        \\// @allowJs: true
        \\// @Filename: a.js
        \\var ===;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestCodeFixInferFromUsageBindingElement" {
    const content =
        \\function f([car, cdr]) {
        \\    return car + cdr + 1
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifySuggestionDiagnostics(undefined, null);
}

test "TestOrganizeImportsAttributes4" {
    const content =
        \\import { A } from "./a" with { foo: "foo", bar: "bar" };
        \\import { B } from "./a" with { bar: "bar", foo: "foo" };
        \\import { D } from "./a" with { bar: "foo", foo: "bar" };
        \\import { E } from "./a" with { foo: 'bar', bar: "foo" };
        \\import { C } from "./a" with { foo: "bar", bar: "foo" };
        \\import { F } from "./a" with { foo: "42" };
        \\import { Y } from "./a" with { foo: 42 };
        \\import { Z } from "./a" with { foo: "42" };
        \\
        \\export type G = A | B | C | D | E | F | Y | Z;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(undefined,
//         "import { A, B } from \"./a\" with { foo: \"foo\", bar: \"bar\" };\nimport { C, D, E } from \"./a\" with { bar: \"foo\", foo: \"bar\" };\nimport { F, Z } from \"./a\" with { foo: \"42\" };\nimport { Y } from \"./a\" with { foo: 42 };\n\nexport type G = A | B | C | D | E | F | Y | Z;",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestCompletionJSDocNamePath" {
    const content =
        \\// @noLib: true
        \\/**
        \\ * @returns {modu/*1*/le:ControlFlow}
        \\ */
        \\export function cargo() {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Excludes = &.{
//                 "module",
//                 "ControlFlow",
//             },
//         },
//     });
}

test "TestGoToDefinitionBuiltInTypes" {
    const content =
        \\var n: /*number*/number;
        \\var s: /*string*/string;
        \\var b: /*boolean*/boolean;
        \\var v: /*void*/void;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, f.MarkerNames());
}

test "TestSignatureHelpWithInterfaceAsIdentifier" {
    const content =
        \\interface C {
        \\    (): void;
        \\}
        \\C(/*1*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyNoSignatureHelpForMarkers(undefined, "1");
}

test "TestGoToDefinitionDynamicImport4" {
    const content =
        \\// @Filename: foo.ts
        \\export function /*Destination*/bar() { return "bar"; }
        \\import('./foo').then(({ [|ba/*1*/r|] }) => undefined);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestSmartSelection_function3" {
    const content =
        \\const f3 = function () {
        \\    /**/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSelectionRanges(undefined);
}

test "TestImportNameCodeFixNewImportBaseUrl1" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "baseUrl": "./a"
        \\    }
        \\}
        \\// @Filename: /a/b/x.ts
        \\export function f1() { };
        \\// @Filename: /a/b/y.ts
        \\[|f1/*0*/();|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a/b/y.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from \"./x\";\n\nf1();",
    }, null );
    // f.VerifyImportFixAtPosition(undefined, &.{
//         "import { f1 } from \"b/x\";\n\nf1();",
//     }, &.{.ImportModuleSpecifierPreference = "non-relative"});
}

test "TestFormatAfterMultilineComment" {
    const content =
        \\/*foo
        \\*/"123123";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "/*foo\n*/\"123123\";");
}

test "TestDocCommentTemplateVariableStatements02" {
    const content =
        \\/*a*/
        \\var a1 = 10, a2 = 20;
        \\
        \\/*b*/
        \\let b1 = "", b2 = true;
        \\
        \\/*c*/
        \\const c1 = 30, c2 = 40;
        \\
        \\/*d*/
        \\let d1 = function d(x, y, z) {
        \\    return +(x + y + z);
        \\}, d2 = 50;
        \\
        \\/*e*/
        \\let e1 = class E {
        \\    constructor(a, b, c) {
        \\        this.a = a;
        \\        this.b = b || (this.c = c);
        \\    }
        \\}, e2 = () => 100;
        \\
        \\/*f*/
        \\let f1 = {
        \\    foo: 10,
        \\    bar: "20"
        \\}, f2 = null;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyJSDocCompletion(undefined, varName, 3, "/** */", null);
}

test "TestCodeFixMissingTypeAnnotationOnExports48" {
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
    _ = f.VerifyCodeFix(undefined, .{
        .Description =    "Add satisfies and an inline type assertion with 'JSX.Element'",
        .NewFileContent = "export const x = (<div aria-label=\"label text\" />) satisfies JSX.Element as JSX.Element;",
        .Index =          1,
    });
}

test "TestCodeFixTopLevelAwait_target_compatibleCompilerOptionsInTsConfig" {
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
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestJsxTagNameCompletionClosed" {
    const content =
        \\//@Filename: file.tsx
        \\interface NestedInterface {
        \\    Foo: NestedInterface;
        \\    (props: {}): any;
        \\}
        \\
        \\declare const Foo: NestedInterface;
        \\
        \\function fn1() {
        \\    return <Foo>
        \\        </*1*/ />
        \\    </Foo>
        \\}
        \\function fn2() {
        \\    return <Foo>
        \\        <Fo/*2*/ />
        \\    </Foo>
        \\}
        \\function fn3() {
        \\    return <Foo>
        \\        <Foo./*3*/ />
        \\    </Foo>
        \\}
        \\function fn4() {
        \\    return <Foo>
        \\        <Foo.F/*4*/ />
        \\    </Foo>
        \\}
        \\function fn5() {
        \\    return <Foo>
        \\        <Foo.Foo./*5*/ />
        \\    </Foo>
        \\}
        \\function fn6() {
        \\    return <Foo>
        \\        <Foo.Foo.F/*6*/ />
        \\    </Foo>
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
//                     .Label =  "Foo",
//                     .Detail = undefined("const Foo: NestedInterface"),
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
//                     .Label =  "Foo",
//                     .Detail = undefined("const Foo: NestedInterface"),
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
//                     .Label =  "Foo",
//                     .Detail = undefined("(property) NestedInterface.Foo: NestedInterface"),
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
//                     .Label =  "Foo",
//                     .Detail = undefined("(property) NestedInterface.Foo: NestedInterface"),
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
//                     .Label =  "Foo",
//                     .Detail = undefined("(property) NestedInterface.Foo: NestedInterface"),
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
//                     .Label =  "Foo",
//                     .Detail = undefined("(property) NestedInterface.Foo: NestedInterface"),
//                 },
//             },
//         },
//     });
}

test "TestFormatParameter" {
    const content =
        \\function foo(
        \\    first:
        \\    number,/*first*/
        \\    second: (
        \\    string/*second*/
        \\    ),
        \\    third:
        \\    (
        \\    boolean/*third*/
        \\    )
        \\) {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "first");
    _ = f.VerifyCurrentLineContent(undefined, "        number,");
    _ = f.GoToMarker(undefined, "second");
    _ = f.VerifyCurrentLineContent(undefined, "        string");
    _ = f.GoToMarker(undefined, "third");
    _ = f.VerifyCurrentLineContent(undefined, "            boolean");
}

test "TestQuickInfoForGenericTaggedTemplateExpression" {
    const content =
        \\interface T1 {}
        \\class T2 {}
        \\type T3 = "a" | "b";
        \\
        \\declare function foo<T>(strings: TemplateStringsArray, ...values: T[]): void;
        \\
        \\/*1*/foo<number>
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "function foo<number>(strings: TemplateStringsArray, ...values: number[]): void", "");
    // f.VerifyQuickInfoAt(undefined, "2", "function foo<string | number>(strings: TemplateStringsArray, ...values: (string | number)[]): void", "");
    // f.VerifyQuickInfoAt(undefined, "3", "function foo<{\n    a: number;\n}>(strings: TemplateStringsArray, ...values: {\n    a: number;\n}[]): void", "");
    // f.VerifyQuickInfoAt(undefined, "4", "function foo<T1>(strings: TemplateStringsArray, ...values: T1[]): void", "");
    // f.VerifyQuickInfoAt(undefined, "5", "function foo<T2>(strings: TemplateStringsArray, ...values: T2[]): void", "");
    // f.VerifyQuickInfoAt(undefined, "6", "function foo<T3>(strings: TemplateStringsArray, ...values: T3[]): void", "");
    // f.VerifyQuickInfoAt(undefined, "7", "function foo<unknown>(strings: TemplateStringsArray, ...values: unknown[]): void", "");
}

test "TestTsxRename4" {
    const content =
        \\// @jsx: preserve
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element {}
        \\    interface IntrinsicElements {
        \\        div: {};
        \\    }
        \\}
        \\[|class [|{| "contextRangeIndex": 0 |}MyClass|] {}|]
        \\
        \\[|<[|{| "contextRangeIndex": 2 |}MyClass|]></[|{| "contextRangeIndex": 2 |}MyClass|]>|];
        \\[|<[|{| "contextRangeIndex": 5 |}MyClass|]/>|];
        \\
        \\[|<[|{| "contextRangeIndex": 7 |}div|]> </[|{| "contextRangeIndex": 7 |}div|]>|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "MyClass", "div");
}

test "TestAutoImportCrossProject_paths_toDist2" {
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
        \\    "paths": {
        \\      "@common/*": ["../common/dist/src/*"]
        \\    }
        \\  },
        \\  "include": ["src"],
        \\  "references": [{ "path": "../common" }]
        \\}
        \\// @Filename: /home/src/workspaces/project/web/src/MyApp.ts
        \\import { square } from "@common/MyModule";
        \\// @Filename: /home/src/workspaces/project/web/src/Helper.ts
        \\export function saveMe() {
        \\  square/**/(2);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToFile(undefined, "/home/src/workspaces/project/web/src/Helper.ts");
    // f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"@common/MyModule"}, &.{.ImportModuleSpecifierPreference = "non-relative"});
}

test "TestCallHierarchyContainerNameServer" {
    const content =
        \\// @lib: es5
        \\function /**/f() {}
        \\
        \\class A {
        \\  static sameName() {
        \\    f();
        \\  }
        \\}
        \\
        \\class B {
        \\  sameName() {
        \\    A.sameName();
        \\  }
        \\}
        \\
        \\const Obj = {
        \\  get sameName() {
        \\    return new B().sameName;
        \\  }
        \\};
        \\
        \\namespace Foo {
        \\  function sameName() {
        \\    return Obj.sameName;
        \\  }
        \\
        \\  export class C {
        \\    constructor() {
        \\      sameName();
        \\    }
        \\  }
        \\}
        \\
        \\namespace Foo.Bar {
        \\  const sameName = () => new Foo.C();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyBaselineCallHierarchy(undefined);
}

test "TestQuickInfoLink2" {
    const content =
        \\// @checkJs: true
        \\// @Filename: quickInfoLink2.js
        \\/**
        \\ * @typedef AdditionalWallabyConfig/**/ Additional valid Wallaby config properties
        \\ * that aren't defined in {@link IWallabyConfig}.
        \\ * @property {boolean} autoDetect
        \\ */
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCompletionsTuple" {
    const content =
        \\declare const x: [number, number];
        \\x[|./**/|];
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
//                     .Label =      "0",
//                     .InsertText = undefined("[0]"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "0",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =      "1",
//                     .InsertText = undefined("[1]"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "1",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 "length",
//             },
//             .Excludes = &.{
//                 "2",
//             },
//         },
//     });
}

test "TestRenameDefaultImport" {
    const content =
        \\// @Filename: B.ts
        \\[|export default class /*1*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 0 |}B|] {
        \\    test() {
        \\    }
        \\}|]
        \\// @Filename: A.ts
        \\[|import /*2*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 2 |}B|] from "./B";|]
        \\let b = new [|B|]();
        \\b.test();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[3], f.Ranges()[4]);
    // f.VerifyBaselineDocumentHighlights(undefined, null , "1");
}

test "TestCompletionListInUnclosedFunction14" {
    const content =
        \\interface MyType {
        \\}
        \\
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string = "hello", c: typeof x = "hello") {
        \\        var v = (p: MyType) => /*1*/
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
//         },
//     });
}

test "TestFindAllRefsForComputedProperties" {
    const content =
        \\interface I {
        \\    ["/*0*/prop1"]: () => void;
        \\}
        \\
        \\class C implements I {
        \\    ["/*1*/prop1"]: any;
        \\}
        \\
        \\var x: I = {
        \\    ["/*2*/prop1"]: function () { },
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2");
}

test "TestCompletionsImport_jsModuleExportsAssignment" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{ "compilerOptions": { "module": "commonjs", "allowJs": true, "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/third_party/marked/src/defaults.js
        \\function getDefaults() {
        \\  return {
        \\    baseUrl: null,
        \\  };
        \\}
        \\
        \\function changeDefaults(newDefaults) {
        \\  module.exports.defaults = newDefaults;
        \\}
        \\
        \\module.exports = {
        \\  defaults: getDefaults(),
        \\  getDefaults,
        \\  changeDefaults
        \\};
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.GetOptions();
    // f.Configure(undefined, opts666);
    _ = f.GoToMarker(undefined, "");
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{},
//     });
    _ = f.Insert(undefined, "d");
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "defaults",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./third_party/marked/src/defaults",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//             .Excludes = &.{
//                 "newDefaults",
//             },
//         },
//     });
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "defaults",
//         .Source =      "./third_party/marked/src/defaults",
//         .Description = "Add import from \"./third_party/marked/src/defaults\"",
//         .AutoImportFix = &.{
//             .ModuleSpecifier = "./third_party/marked/src/defaults",
//         },
//         .NewFileContent = undefined("import { defaults } from \"./third_party/marked/src/defaults\";\n\nd"),
//     });
}

test "TestCompletionsGenericIndexedAccess4" {
    const content =
        \\interface CustomElements {
        \\  'component-one': {
        \\      foo?: string;
        \\  },
        \\  'component-two': {
        \\      bar?: string;
        \\  }
        \\}
        \\
        \\interface Options<T extends keyof CustomElements> {
        \\  props: CustomElements[T];
        \\}
        \\
        \\declare function create<T extends 'hello' | 'goodbye'>(name: T, options: Options<T extends 'hello' ? 'component-one' : 'component-two'>): void;
        \\declare function create<T extends keyof CustomElements>(name: T, options: Options<T>): void;
        \\
        \\create('hello', { props: { /*1*/ } })
        \\create('goodbye', { props: { /*2*/ } })
        \\create('component-one', { props: { /*3*/ } });
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
//                     .Label =      "foo?",
//                     .InsertText = undefined("foo"),
//                     .FilterText = undefined("foo"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
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
//                     .Label =      "bar?",
//                     .InsertText = undefined("bar"),
//                     .FilterText = undefined("bar"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
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
//             .Exact = &.{
//                 &.{
//                     .Label =      "foo?",
//                     .InsertText = undefined("foo"),
//                     .FilterText = undefined("foo"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
}

test "TestCompletionForStringLiteralRelativeImportAllowJSTrue" {
    const content =
        \\// @allowJs: true
        \\// @Filename: test0.ts
        \\import * as foo1 from ".//*import_as0*/
        \\import * as foo2 from "./f/*import_as1*/
        \\import foo3 = require(".//*import_equals0*/
        \\import foo4 = require("./f/*import_equals1*/
        \\var foo5 = require(".//*require0*/
        \\var foo6 = require("./f/*require1*/
        \\// @Filename: f1.ts
        \\
        \\// @Filename: f2.js
        \\
        \\// @Filename: f3.d.ts
        \\
        \\// @Filename: f4.tsx
        \\
        \\// @Filename: f5.js
        \\
        \\// @Filename: f6.jsx
        \\
        \\// @Filename: g1.ts
        \\
        \\// @Filename: g2.js
        \\
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
//                 "f1",
//                 "f2",
//                 "f3",
//                 "f4",
//                 "f5",
//                 "f6",
//                 "g1",
//                 "g2",
//             },
//         },
//     });
}

test "TestCompletionForStringLiteral_quotePreference7" {
    const content =
        \\// @filename: /a.ts
        \\export const a = null;
        \\// @filename: /b.ts
        \\import { a } from './a';
        \\
        \\const foo = { '#': null };
        \\foo[|./**/|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "#",
//                     .InsertText = undefined("['#']"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "#",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//         .UserPreferences = &.{.QuotePreference = lsutil.QuotePreference("auto")},
//     });
}

test "TestJsDocFunctionSignatures3" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\var someObject = {
        \\    /**
        \\     * @param {string} param1 Some string param.
        \\     * @param {number} parm2  Some number param.
        \\     */
        \\    someMethod: function(param1, param2) {
        \\        console.log(param1/*1*/);
        \\        return false;
        \\    },
        \\    /**
        \\     * @param {number} p1  Some number param.
        \\     */
        \\    otherMethod(p1) {
        \\        p1/*2*/
        \\    }
        \\
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
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
//                 &.{
//                     .Label = "substring",
//                     .Kind =  undefined(lsproto.CompletionItemKindMethod),
//                 },
//             },
//         },
//     });
    _ = f.Backspace(undefined, 1);
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
//                 &.{
//                     .Label = "toFixed",
//                     .Kind =  undefined(lsproto.CompletionItemKindMethod),
//                 },
//             },
//         },
//     });
    _ = f.Backspace(undefined, 1);
}

test "TestQuickinfoVerbosityToplevelTruncation2" {
    const content =
        \\export enum LargeEnum/*1*/ {
        \\    Member1,
        \\    Member2,
        \\    Member3,
        \\    Member4,
        \\    Member5,
        \\    Member6,
        \\    Member7,
        \\    Member8,
        \\    Member9,
        \\    Member10,
        \\    Member11,
        \\    Member12,
        \\    Member13,
        \\    Member14,
        \\    Member15,
        \\    Member16,
        \\    Member17,
        \\    Member18,
        \\    Member19,
        \\    Member20,
        \\    Member21,
        \\    Member22,
        \\    Member23,
        \\    Member24,
        \\    Member25,
        \\}
        \\export interface LargeInterface/*2*/ {
        \\    property1: string;
        \\    property2: number;
        \\    property3: boolean;
        \\    property4: Date;
        \\    property5: string[];
        \\    property6: number[];
        \\    property7: boolean[];
        \\    property8: { [key: string]: unknown };
        \\    property9: string | null;
        \\    property10: number | null;
        \\    property11: boolean | null;
        \\    property12: Date | null;
        \\    property13: string | number;
        \\    property14: number | boolean;
        \\    property15: string | boolean;
        \\    property16: Array<{ id: number; name: string }>;
        \\    property17: Array<{ key: string; value: unknown }>;
        \\    property18: { nestedProp1: string; nestedProp2: number };
        \\    property19: { nestedProp3: boolean; nestedProp4: Date };
        \\    property20: () => void;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{1}, .@"2" = .{1}});
}

test "TestRenameJsPropertyAssignment3" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\var C = class  {
        \\}
        \\[|C.[|{| "contextRangeIndex": 0 |}staticProperty|] = "string";|]
        \\console.log(C.[|staticProperty|]);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "staticProperty");
}

test "TestCompletionsPrivateProperties_Js" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.d.ts
        \\declare namespace A {
        \\    class Foo {
        \\        constructor();
        \\
        \\        private m1(): void;
        \\        protected m2(): void;
        \\
        \\        m3(): void;
        \\    }
        \\}
        \\// @filename: b.js
        \\let foo = new A.Foo();
        \\foo./**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{""}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "m3",
//             },
//             .Excludes = &.{
//                 "m1",
//                 "m2",
//             },
//         },
//     });
}

test "TestCompletionsJSDocNoCrash2" {
    const content =
        \\// @lib: es5
        \\// @strict: true
        \\// @filename: index.ts
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
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalTypes,
//         },
//     });
}

test "TestInlayHintsInteractiveAnyParameter2" {
    const content =
        \\function foo (v: any) {}
        \\foo(1);
        \\foo('');
        \\foo(true);
        \\foo(() => 1);
        \\foo(function () { return 1 });
        \\foo({});
        \\foo({ a: 1 });
        \\foo([]);
        \\foo([1]);
        \\foo(foo);
        \\foo((1));
        \\foo(foo(1));
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayParameterNameHints = lsutil.IncludeInlayParameterNameHintsAll}});
}

test "TestGoToImplementationInterfaceMethod_03" {
    const content =
        \\interface Foo {
        \\    hello (): void;
        \\}
        \\
        \\class Bar extends SuperBar {
        \\    [|hello|]() {}
        \\}
        \\
        \\class SuperBar implements Foo {
        \\    hello() {} // should not show up
        \\}
        \\
        \\class OtherBar implements Foo {
        \\    hello() {} // should not show up
        \\}
        \\
        \\new Bar().hel/*function_call*/lo();
        \\new Bar()["hello"]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "function_call");
}

test "TestSyntaxErrorAfterImport1" {
    const content =
        \\declare module "extmod" {
        \\  namespace IntMod {
        \\    class Customer {
        \\      constructor(name: string);
        \\    }
        \\  }
        \\}
        \\import ext = require('extmod');
        \\import int = ext.IntMod;
        \\var x = new int/*0*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "0");
    _ = f.Insert(undefined, ".");
}

test "TestSemanticClassificationWithUnionTypes" {
    const content =
        \\module /*0*/M {
        \\    export interface /*1*/I {
        \\    }
        \\}
        \\
        \\interface /*2*/I {
        \\}
        \\class /*3*/C {
        \\}
        \\
        \\var M: /*4*/M./*5*/I | /*6*/I | /*7*/C;
        \\var I: typeof M | typeof /*8*/C;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "variable", .Text = "M"},
//         .{.Type = "interface.declaration", .Text = "I"},
//         .{.Type = "interface.declaration", .Text = "I"},
//         .{.Type = "class.declaration", .Text = "C"},
//         .{.Type = "variable.declaration", .Text = "M"},
//         .{.Type = "variable", .Text = "M"},
//         .{.Type = "interface", .Text = "I"},
//         .{.Type = "interface", .Text = "I"},
//         .{.Type = "class", .Text = "C"},
//         .{.Type = "class.declaration", .Text = "I"},
//         .{.Type = "variable", .Text = "M"},
//         .{.Type = "class", .Text = "C"},
//     });
}

test "TestQuickInfoJsDocTags13" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @filename: ./a.js
        \\/**
        \\ * First overload
        \\ * @overload
        \\ * @param {number} a
        \\ * @returns {void}
        \\ */
        \\
        \\/**
        \\ * Second overload
        \\ * @overload
        \\ * @param {string} a
        \\ * @returns {void}
        \\ */
        \\
        \\/**
        \\ * @param {string | number} a
        \\ * @returns {void}
        \\ */
        \\function f(a) {}
        \\
        \\f(/*a*/1);
        \\f(/*b*/"");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSignatureHelp(undefined);
}

test "TestCodeFixAddMissingAwait_topLevel" {
    const content =
        \\declare function getPromise(): Promise<string>;
        \\const p = getPromise();
        \\while (true) {
        \\  p/*0*/.toLowerCase();
        \\  getPromise()/*1*/.toLowerCase();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined, "addMissingAwait");
    // f.VerifyCodeFixNotAvailable(undefined, "addMissingAwaitToInitializer");
}

test "TestImportNameCodeFixNewImportDefault0" {
    const content =
        \\[|f1/*0*/();|]
        \\// @Filename: module.ts
        \\export default function f1() { };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import f1 from \"./module\";\n\nf1();",
    }, null );
}

test "TestCompletionsJSDocImportTagAttributesErrorModuleSpecifier1" {
    const content =
        \\// @strict: true
        \\// @checkJs: true
        \\// @allowJs: true
        \\// @filename: global.d.ts
        \\interface ImportAttributes { 
        \\  type: "json";
        \\}
        \\// @filename: index.js
        \\/** @import * as ns from () with { type: "/**/" } */
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

test "TestQuickInfoCommentsClass" {
    const content =
        \\/** This is class c2 without constructor*/
        \\class c/*1*/2 {
        \\}
        \\var i/*2*/2 = new c/*28*/2();
        \\var i2/*4*/_c = c/*5*/2;
        \\class c/*6*/3 {
        \\    /** Constructor comment*/
        \\    constructor() {
        \\    }
        \\}
        \\var i/*7*/3 = new c/*29*/3();
        \\var i3/*9*/_c = c/*10*/3;
        \\/** Class comment*/
        \\class c/*11*/4 {
        \\    /** Constructor comment*/
        \\    constructor() {
        \\    }
        \\}
        \\var i/*12*/4 = new c/*30*/4();
        \\var i4/*14*/_c = c/*15*/4;
        \\/** Class with statics*/
        \\class c/*16*/5 {
        \\    static s1: number;
        \\}
        \\var i/*17*/5 = new c/*31*/5();
        \\var i5_/*19*/c = c/*20*/5;
        \\/** class with statics and constructor*/
        \\class c/*21*/6 {
        \\    /** s1 comment*/
        \\    static s1: number;
        \\    /** constructor comment*/
        \\    constructor() {
        \\    }
        \\}
        \\var i/*22*/6 = new c/*32*/6();
        \\var i6/*24*/_c = c/*25*/6;
        \\
        \\class a {
        \\    /**
        \\    constructor for a
        \\    @param a this is my a
        \\    */
        \\    constructor(a: string) {
        \\    }
        \\}
        \\new a("Hello");
        \\namespace m {
        \\    export namespace m2 {
        \\        /** class comment */
        \\        export class c1 {
        \\            /** constructor comment*/
        \\            constructor() {
        \\            }
        \\        }
        \\    }
        \\}
        \\var myVar = new m.m2.c/*33*/1();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestQuickinfoVerbosityRecursiveType" {
    const content =
        \\// @lib: es5
        \\type Node/*N*/<T> = {
        \\    value: T;
        \\    left: Node<T> | undefined;
        \\    right: Node<T> | undefined;
        \\}
        \\const n/*n*/: Node<number> = {
        \\    value: 1,
        \\    left: undefined,
        \\    right: undefined,
        \\}
        \\interface Orange {
        \\    name: string;
        \\}
        \\type TreeNode/*t*/<T> = {
        \\    value: T;
        \\    left: TreeNode<T> | undefined;
        \\    right: TreeNode<T> | undefined;
        \\    orange?: Orange;
        \\}
        \\const m/*m*/: TreeNode<number> = {
        \\    value: 1,
        \\    left: undefined,
        \\    right: undefined,
        \\    orange: { name: "orange" },
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"N" = .{0}, .@"n" = .{0, 1}, .@"t" = .{0, 1}, .@"m" = .{0, 1, 2}});
}

test "TestAutoImportProvider_namespaceSameNameAsIntrinsic" {
    const content =
        \\// @Filename: /home/src/workspaces/project/node_modules/fp-ts/package.json
        \\{ "name": "fp-ts", "version": "0.10.4" }
        \\// @Filename: /home/src/workspaces/project/node_modules/fp-ts/index.d.ts
        \\export * as string from "./lib/string";
        \\// @Filename: /home/src/workspaces/project/node_modules/fp-ts/lib/string.d.ts
        \\export declare const fromString: (s: string) => string;
        \\export type SafeString = string;
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{ "dependencies": { "fp-ts": "^0.10.4" } }
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{ "compilerOptions": { "module": "commonjs", "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\type A = { name: string/**/ }
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
//                     .Label =    "string",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//                 &.{
//                     .Label =    "string",
//                     .SortText = undefined(string(ls.SortTextAutoImportSuggestions)),
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "fp-ts",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                 },
//             },
//         },
//     });
}

test "TestGetJavaScriptCompletions13" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: file1.js
        \\var file1Identifier = 1;
        \\interface Foo { FooProp: number };
        \\// @Filename: file2.js
        \\var file2Identifier1 = 2;
        \\var file2Identifier2 = 2;
        \\/*1*/
        \\file2Identifier2./*2*/
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
//                 "file2Identifier1",
//                 "file2Identifier2",
//                 &.{
//                     .Label =    "file1Identifier",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//             .Excludes = &.{
//                 "FooProp",
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
//                     .Label =    "file2Identifier1",
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//                 &.{
//                     .Label =    "file2Identifier2",
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//             },
//             .Excludes = &.{
//                 "file1Identifier",
//                 "FooProp",
//             },
//         },
//     });
}

test "TestCompletionListNewIdentifierFunctionDeclaration" {
    const content =
        \\// @noLib: true
        \\function F(pref: (a/*1*/
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
//             .Exact = CompletionTypeKeywords,
//         },
//     });
}

test "TestFormattingSpacesAfterConstructor" {
    const content =
        \\/*1*/class test { constructor                   () { } }
        \\/*2*/class test { constructor                   () { } }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "class test { constructor() { } }");
    // f.GetOptions();
    // f.Configure(undefined, opts319);
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "class test { constructor () { } }");
}

test "TestCodeFixClassImplementInterfaceComments" {
    const content =
        \\// @lib: es2017
        \\namespace N {
        \\    /**enum prefix */
        \\    export enum /**enum identifier prefix */ E /**open-brace prefix*/ {
        \\    /* literal prefix */ a /** comma prefix */,
        \\    /* literal prefix */ b /** comma prefix */,
        \\    /* literal prefix */ c
        \\    /** close brace prefix */ }
        \\    /** interface prefix */
        \\    export interface /**interface name prefix */ I /**open-brace prefix*/ {
        \\    /** property prefix */ a /** colon prefix */: /** enum literal prefix 1*/ E /** dot prefix */. /** enum literal prefix 2*/a;
        \\    /** property prefix */ b /** colon prefix */: /** enum prefix */ E;
        \\    /**method signature prefix */foo /**open angle prefix */< /**type parameter name prefix */ X /** closing angle prefix */> /**open paren prefix */(/** parameter prefix */ a/** colon prefix */: /** parameter type prefix */ X /** close paren prefix */) /** colon prefix */: /** return type prefix */ string /** semicolon prefix */;
        \\        /**close-brace prefix*/ }
        \\/**close-brace prefix*/ }
        \\class C implements N.I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'N.I'",
        .NewFileContent = "namespace N {\n    /**enum prefix */\n    export enum /**enum identifier prefix */ E /**open-brace prefix*/ {\n    /* literal prefix */ a /** comma prefix */,\n    /* literal prefix */ b /** comma prefix */,\n    /* literal prefix */ c\n    /** close brace prefix */ }\n    /** interface prefix */\n    export interface /**interface name prefix */ I /**open-brace prefix*/ {\n    /** property prefix */ a /** colon prefix */: /** enum literal prefix 1*/ E /** dot prefix */. /** enum literal prefix 2*/a;\n    /** property prefix */ b /** colon prefix */: /** enum prefix */ E;\n    /**method signature prefix */foo /**open angle prefix */< /**type parameter name prefix */ X /** closing angle prefix */> /**open paren prefix */(/** parameter prefix */ a/** colon prefix */: /** parameter type prefix */ X /** close paren prefix */) /** colon prefix */: /** return type prefix */ string /** semicolon prefix */;\n        /**close-brace prefix*/ }\n/**close-brace prefix*/ }\nclass C implements N.I {\n    a: N.E.a;\n    b: N.E;\n    foo<X /** closing angle prefix */>(a: X /** close paren prefix */): string /** semicolon prefix */ {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestCodefixEnableJsxFlag_noTsconfig" {
    const content =
        \\// @Filename: /dir/a.tsx
        \\export const Component = () => <></>
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/dir/a.tsx");
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestGetEditsForFileRename_renameFromIndex" {
    const content =
        \\// @Filename: /a.ts
        \\/// <reference path="./src/index.ts" />
        \\import old from "./src";
        \\import old2 from "./src/index";
        \\// @Filename: /src/a.ts
        \\/// <reference path="./index.ts" />
        \\import old from ".";
        \\import old2 from "./index";
        \\// @Filename: /src/foo/a.ts
        \\/// <reference path="../index.ts" />
        \\import old from "..";
        \\import old2 from "../index";
        \\// @Filename: /src/index.ts
        \\
        \\// @Filename: /tsconfig.json
        \\{ "files": ["a.ts", "src/a.ts", "src/foo/a.ts", "src/index.ts"] }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyWillRenameFilesEdits(undefined, "/src/index.ts", "/src/new.ts", .{
//         .@"/a.ts" = "/// <reference path=\"./src/new.ts\" />\nimport old from \"./src/new\";\nimport old2 from \"./src/new\";",
//         .@"/src/a.ts" = "/// <reference path=\"./new.ts\" />\nimport old from \"./new\";\nimport old2 from \"./new\";",
//         .@"/src/foo/a.ts" = "/// <reference path=\"../new.ts\" />\nimport old from \"../new\";\nimport old2 from \"../new\";",
//         .@"/tsconfig.json" = "{ \"files\": [\"a.ts\", \"src/a.ts\", \"src/foo/a.ts\", \"src/new.ts\"] }",
//     }, null );
}

test "TestReferencesForStringLiteralPropertyNames2" {
    const content =
        \\class Foo {
        \\    /*1*/"/*2*/blah"() { return 0; }
        \\}
        \\
        \\var x: Foo;
        \\x./*3*/blah;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestIsDefinitionInterfaceImplementation" {
    const content =
        \\interface I {
        \\    /*1*/M(): void;
        \\}
        \\
        \\class C implements I {
        \\    /*2*/M() { }
        \\}
        \\
        \\({} as I).M();
        \\({} as C).M();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestCompletionListInImportClause01" {
    const content =
        \\// @Filename: m1.ts
        \\export var foo: number = 1;
        \\export function bar() { return 10; }
        \\export function baz() { return 10; }
        \\// @Filename: m2.ts
        \\import {/*1*/, /*2*/ from "./m1"
        \\import {/*3*/} from "./m1"
        \\import {foo,/*4*/ from "./m1"
        \\import {bar as /*5*/, /*6*/ from "./m1"
        \\import {foo, bar, baz as b,/*7*/} from "./m1"
        \\import { type /*8*/ } from "./m1";
        \\import { type b/*9*/ } from "./m1";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"8", "9"}, &.{
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

test "TestMemberListOfModuleBeforeKeyword" {
    const content =
        \\namespace TypeModule1 {
        \\    export class C1 { }
        \\    export class C2 { }
        \\}
        \\var x: TypeModule1./*namedType*/
        \\namespace TypeModule2 {
        \\    export class Test3 {}
        \\}
        \\
        \\TypeModule1./*dottedExpression*/
        \\namespace TypeModule3 {
        \\    export class Test3 {}
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
//                 "C1",
//                 "C2",
//             },
//         },
//     });
}

test "TestReferencesForFunctionOverloads" {
    const content =
        \\/*1*/function /*2*/foo(x: string);
        \\/*3*/function /*4*/foo(x: string, y: number) {
        \\    /*5*/foo('', 43);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5");
}

test "TestFindAllReferencesJsOverloadedFunctionParameter" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: foo.js
        \\/**
        \\ * @overload
        \\ * @param {number} x
        \\ * @returns {number}
        \\ *
        \\ * @overload
        \\ * @param {string} x
        \\ * @returns {string} 
        \\ *
        \\ * @param {unknown} x
        \\ * @returns {unknown} 
        \\ */
        \\function foo(x/*1*/) {
        \\  return x;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestReferencesForMergedDeclarations6" {
    const content =
        \\interface Foo { }
        \\/*1*/module /*2*/Foo {
        \\    export interface Bar { }
        \\    export namespace Bar { export interface Baz { } }
        \\    export function Bar() { }
        \\}
        \\
        \\// module
        \\import a1 = /*3*/Foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestImportNameCodeFixNewImportRootDirs0" {
    const content =
        \\// @Filename: a/f1.ts
        \\[|foo/*0*/();|]
        \\// @Filename: b/c/f2.ts
        \\export function foo() {};
        \\// @Filename: tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "rootDirs": [
        \\            "a",
        \\            "b/c"
        \\        ]
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { foo } from \"./f2\";\n\nfoo();",
    }, null );
}

test "TestQuickInfoDisplayPartsClass" {
    const content =
        \\class /*1*/c {
        \\}
        \\var /*2*/cInstance = new /*3*/c();
        \\var /*4*/cVal = /*5*/c;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestRenameUMDModuleAlias2" {
    const content =
        \\// @Filename: 0.d.ts
        \\export function doThing(): string;
        \\export function doTheOtherThing(): void;
        \\export as namespace /**/[|myLib|];
        \\// @Filename: 1.ts
        \\/// <reference path="0.d.ts" />
        \\myLib.doThing();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyRenameSucceeded(undefined, null );
}

test "TestImportNameCodeFixNewImportFromAtTypes" {
    const content =
        \\[|f1/*0*/();|]
        \\// @Filename: node_modules/@types/myLib/index.d.ts
        \\export function f1() {}
        \\export var v1 = 5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from \"myLib\";\n\nf1();",
    }, null );
}

test "TestSmartSelection_JSDocTags10" {
    const content =
        \\/**
        \\ * @template T
        \\ * @extends {/**/Set<T>}
        \\ */
        \\class A extends B {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSelectionRanges(undefined);
}

test "TestQuickInfoSignatureRestParameterFromUnion2" {
    const content =
        \\// @strict: false
        \\declare const rest:
        \\  | ((a?: { a: true }, ...rest: string[]) => unknown)
        \\  | ((b?: { b: true }) => unknown);
        \\
        \\/**/rest({ a: true, b: true }, "foo", "bar");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "const rest: (arg0?: {\n    a: true;\n} & {\n    b: true;\n}, ...rest: string[]) => unknown", "");
}

test "TestAddAllMissingImportsNoCrash" {
    const content =
        \\// @Filename: file1.ts
        \\export interface Test1 {}
        \\export interface Test2 {}
        \\export interface Test3 {}
        \\export interface Test4 {}
        \\// @Filename: file2.ts
        \\import { Test1, Test4 } from './file1';
        \\interface Testing {
        \\    test1: Test1;
        \\    test2: Test2;
        \\    test3: Test3;
        \\    test4: Test4;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "file2.ts");
    _ = f.VerifyCodeFixAll(undefined, .{
        .FixID = "fixMissingImport",
        .NewFileContent = "import { Test1, Test2, Test3, Test4 } from './file1';\ninterface Testing {\n    test1: Test1;\n    test2: Test2;\n    test3: Test3;\n    test4: Test4;\n}",
    });
}

test "TestGetOccurrencesReturnBroken" {
    const content =
        \\ret/*1*/urn;
        \\retu/*2*/rn;
        \\function f(a: number) {
        \\    if (a > 0) {
        \\        return (function () {
        \\            () => [|return|];
        \\            [|return|];
        \\            [|return|];
        \\
        \\            if (false) {
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
        \\
        \\class A {
        \\    ret/*3*/urn;
        \\    r/*4*/eturn 8675309;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Markers()));
}

test "TestCompletionsMergedDeclarations2" {
    const content =
        \\class point {
        \\    constructor(public x: number, public y: number) { }
        \\}
        \\namespace point {
        \\    export var origin = new point(0, 0);
        \\    export function equals(p1: point, p2: point) {
        \\        return p1.x == p2.x && p1.y == p2.y;
        \\    }
        \\}
        \\var p1 = new point(0, 0);
        \\var p2 = point./*1*/origin;
        \\var b = point./*2*/equals(p1, p2);
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
//                 "origin",
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
//                 "equals",
//             },
//         },
//     });
}

test "TestGoToDefinitionShorthandProperty01" {
    const content =
        \\// @lib: es5
        \\var /*valueDeclaration1*/name = "hello";
        \\var /*valueDeclaration2*/id = 100000;
        \\declare var /*valueDeclaration3*/id;
        \\var obj = {[|/*valueDefinition1*/name|], [|/*valueDefinition2*/id|]};
        \\obj.[|/*valueReference1*/name|];
        \\obj.[|/*valueReference2*/id|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "valueDefinition1", "valueDefinition2", "valueReference1", "valueReference2");
}

test "TestAutoImportCrossProject_paths_toSrc" {
    const content =
        \\// @Filename: /home/src/workspaces/project/packages/app/package.json
        \\{ "name": "app", "dependencies": { "dep": "*" } }
        \\// @Filename: /home/src/workspaces/project/packages/app/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "lib": ["es5"],
        \\    "module": "commonjs",
        \\    "outDir": "dist",
        \\    "rootDir": "src",
        \\    "baseUrl": ".",
        \\    "paths": {
        \\      "dep": ["../dep/src/main"],
        \\      "dep/*": ["../dep/*"]
        \\    }
        \\  }
        \\  "references": [{ "path": "../dep" }]
        \\}
        \\// @Filename: /home/src/workspaces/project/packages/app/src/index.ts
        \\dep1/*1*/;
        \\// @Filename: /home/src/workspaces/project/packages/app/src/utils.ts
        \\dep2/*2*/;
        \\// @Filename: /home/src/workspaces/project/packages/app/src/a.ts
        \\import "dep";
        \\// @Filename: /home/src/workspaces/project/packages/dep/package.json
        \\{ "name": "dep", "main": "dist/main.js", "types": "dist/main.d.ts" }
        \\// @Filename: /home/src/workspaces/project/packages/dep/tsconfig.json
        \\{
        \\  "compilerOptions": { "lib": ["es5"], "outDir": "dist", "rootDir": "src", "module": "commonjs" }
        \\}
        \\// @Filename: /home/src/workspaces/project/packages/dep/src/main.ts
        \\import "./sub/folder";
        \\export const dep1 = 0;
        \\// @Filename: /home/src/workspaces/project/packages/dep/src/sub/folder/index.ts
        \\export const dep2 = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { dep1 } from \"dep\";\n\ndep1;",
    }, null );
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { dep2 } from \"dep/src/sub/folder\";\n\ndep2;",
    }, null );
}

test "TestRenameForDefaultExport09" {
    const content =
        \\// @Filename: foo.ts
        \\function /**/[|f|]() {
        \\    return 100;
        \\}
        \\
        \\export default f;
        \\
        \\var x: typeof f;
        \\
        \\var y = f();
        \\
        \\/**
        \\ *  Commenting f
        \\ */
        \\namespace f {
        \\    var local = 100;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyRenameSucceeded(undefined, null );
}

test "TestFindAllRefsClassWithStaticThisAccess" {
    const content =
        \\[|class /*0*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 0 |}C|] {
        \\    static s() {
        \\        /*1*/[|this|];
        \\    }
        \\    static get f() {
        \\        return /*2*/[|this|];
        \\
        \\        function inner() { this; }
        \\        class Inner { x = this; }
        \\    }
        \\}|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2");
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1]);
}

test "TestInlayHintsTypeParameterModifiers1" {
    const content =
        \\function test1() {
        \\  return function <const T>(a: T) {};
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayFunctionLikeReturnTypeHints = core.TSTrue}});
}

test "TestCompletionListAfterSpreadOperator01" {
    const content =
        \\let v = [1,2,3,4];
        \\let x = [.../**/
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

test "TestEmptyExportFindReferences" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\/**/module.exports = {
        \\
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , "");
}

test "TestCompletionForStringLiteralRelativeImport5" {
    const content =
        \\// @rootDirs: /repo/src1,/repo/src2/,/repo/generated1,/repo/generated2/
        \\// @Filename: /dir/secret_file.ts
        \\/*secret_file*/
        \\// @Filename: /repo/src1/dir/test1.ts
        \\import * as foo1 from ".//*import_as1*/
        \\import foo2 = require(".//*import_equals1*/
        \\var foo3 = require(".//*require1*/
        \\// @Filename: /repo/src2/dir/test2.ts
        \\import * as foo1 from "..//*import_as2*/
        \\import foo2 = require("..//*import_equals2*/
        \\var foo3 = require("..//*require2*/
        \\// @Filename: /repo/src2/index.ts
        \\import * as foo1 from ".//*import_as3*/
        \\import foo2 = require(".//*import_equals3*/
        \\var foo3 = require(".//*require3*/
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
//             .Unsorted = &.{
//                 "f1",
//                 "f2",
//                 "test2",
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
//             .Unsorted = &.{
//                 "dir",
//                 "index",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"import_as3", "import_equals3", "require3"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "dir",
//             },
//         },
//     });
}

test "TestRenameAliasExternalModule2" {
    const content =
        \\// @Filename: a.ts
        \\[|module [|{| "contextRangeIndex": 0 |}SomeModule|] { export class SomeClass { } }|]
        \\[|export = [|{| "contextRangeIndex": 2 |}SomeModule|];|]
        \\// @Filename: b.ts
        \\[|import [|{| "contextRangeIndex": 4 |}M|] = require("./a");|]
        \\import C = [|M|].SomeClass;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[3], f.Ranges()[5], f.Ranges()[6]);
}

test "TestCodeFixMissingTypeAnnotationOnExports18" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\function foo() { return 42; }
        \\export class A {
        \\    readonly a = () => foo();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFixAvailable(undefined, &.{"Add return type 'number'"});
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add return type 'number'",
        .NewFileContent = "function foo() { return 42; }\nexport class A {\n    readonly a = (): number => foo();\n}",
        .Index = 0,
    });
}

test "TestGetEditsForFileRename_unresolvableNodeModule" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /modules/@app/something/index.js
        \\import "doesnt-exist";
        \\// @Filename: /modules/@local/foo.js
        \\import "doesnt-exist"; 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyWillRenameFilesEdits(undefined, "/modules/@app/something", "/modules/@app/something-2", .{}, null );
}

test "TestJsdocDeprecated_suggestion5" {
    const content =
        \\// @checkJs: true
        \\// @allowJs: true
        \\// @Filename: jsdocDeprecated_suggestion5.js
        \\/** @typedef {{ email: string, nickName?: string }} U2 */
        \\/** @type {U2} */
        \\const u2 = { email: "" }
        \\/**
        \\ * @callback K
        \\ * @param {any} ctx
        \\ * @return {void}
        \\ */
        \\/** @type {K} */
        \\const cc = _k => {}
        \\/** @enum {number} */
        \\const DOOM = { e: 1, m: 1 }
        \\/** @type {DOOM} */
        \\const kneeDeep = DOOM.e
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifySuggestionDiagnostics(undefined, null);
}

test "TestRenameInheritedProperties1" {
    const content =
        \\class class1 extends class1 {
        \\   [|[|{| "contextRangeIndex": 0 |}propName|]: string;|]
        \\}
        \\
        \\var v: class1;
        \\v.[|propName|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "propName");
}

test "TestQuickInfoDisplayPartsTypeParameterInTypeAlias" {
    const content =
        \\type /*0*/List</*1*/T> = /*2*/T[]
        \\type /*3*/List2</*4*/T extends string> = /*5*/T[];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestNavigationBarItemsPropertiesDefinedInConstructors" {
    const content =
        \\class List<T> {
        \\    constructor(public a: boolean, private b: T, readonly c: string, d: number) {
        \\        var local = 0;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCodeFixClassImplementInterfaceQualifiedName" {
    const content =
        \\namespace N {
        \\    export interface I { y: I; }
        \\}
        \\class C1 implements N.I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'N.I'",
        .NewFileContent = "namespace N {\n    export interface I { y: I; }\n}\nclass C1 implements N.I {\n    y: N.I;\n}",
        .Index = 0,
    });
}

test "TestCompletionEntryForPropertyConstrainedToString" {
    const content =
        \\declare function test<P extends "a" | "b">(p: { type: P }): void;
        \\
        \\test({ type: /*ts*/ })
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
//             .Includes = &.{
//                 "\"a\"",
//                 "\"b\"",
//             },
//         },
//     });
}

test "TestRenamePrivateFields" {
    const content =
        \\class Foo {
        \\   [|/**/#foo|] = 1;
        \\
        \\   getFoo() {
        \\       return this.#foo;
        \\   }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyRenameSucceeded(undefined, null );
}

test "TestDocCommentTemplateClassDecl01" {
    const content =
        \\/*decl*/class C {
        \\    private p;
        \\    constructor(a, b, c, d);
        \\    constructor(public a, private b, protected c, d, e?) {
        \\    }
        \\
        \\    foo();
        \\    foo(a?, b?, ...args) {
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyJSDocCompletion(undefined, "decl", 3, "/** */", null);
}

test "TestGetOccurrencesTryCatchFinally4" {
    const content =
        \\try/*1*/ {
        \\    try/*2*/ {
        \\    }
        \\    catch/*3*/ (x) {
        \\    }
        \\
        \\    try/*4*/ {
        \\    }
        \\    finally/*5*/ {/*8*/
        \\    }
        \\}
        \\catch/*6*/ (e) {
        \\}
        \\finally/*7*/ {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Markers()));
}

test "TestIncrementalParsingTopLevelAwait1" {
    const content =
        \\// @target: esnext
        \\// @module: esnext
        \\// @Filename: ./foo.ts
        \\await(1);
        \\/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "export {};");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 0);
    _ = f.ReplaceLine(undefined, 1, "");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestSignatureHelp_unionType" {
    const content =
        \\declare const a: (fn?: ((x: string) => string) | ((y: number) => number)) => void;
        \\declare const b: (x: string | number) => void;
        \\
        \\interface Callback {
        \\    (x: string): string;
        \\    (x: number): number;
        \\    (x: string | number): string | number;
        \\}
        \\declare function c(callback: Callback): void;
        \\a((/*1*/) => {
        \\    return undefined;
        \\});
        \\
        \\b(/*2*/);
        \\
        \\c((/*3*/) => {});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSignatureHelp(undefined);
}

test "TestQuickInfoForObjectBindingElementName06" {
    const content =
        \\type Foo = {
        \\    /**
        \\     * Thing is a bar
        \\     */
        \\    isBar: boolean
        \\
        \\    /**
        \\     * Thing is a baz
        \\     */
        \\    isBaz: boolean
        \\}
        \\
        \\function f(): Foo {
        \\    return undefined as any
        \\}
        \\
        \\const { isBaz: isBar } = f();
        \\isBar/**/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestQuickInfoForObjectBindingElementPropertyName04" {
    const content =
        \\interface Recursive {
        \\    next?: Recursive;
        \\    value: any;
        \\}
        \\
        \\function f ({ /*1*/next: { /*2*/next: x} }) {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(property) next: {\n    next: any;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(property) next: any", "");
}

test "TestAutoImportCompletionAmbientMergedModule1" {
    const content =
        \\// @strict: true
        \\// @module: commonjs
        \\// @filename: /node_modules/@types/vscode/index.d.ts
        \\declare module "vscode" {
        \\  export class Position {
        \\    readonly line: number;
        \\    readonly character: number;
        \\  }
        \\}
        \\// @filename: src/motion.ts
        \\import { Position } from "vscode";
        \\
        \\export abstract class MoveQuoteMatch {
        \\  public override async execActionWithCount(
        \\    position: Position,
        \\  ): Promise<void> {}
        \\}
        \\
        \\declare module "vscode" {
        \\  interface Position {
        \\    toString(): string;
        \\  }
        \\}
        \\// @filename: src/smartQuotes.ts
        \\import { MoveQuoteMatch } from "./motion";
        \\
        \\export class MoveInsideNextQuote extends MoveQuoteMatch {/*1*/
        \\  keys = ["i", "n", "q"];
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
//                     .Label =               "execActionWithCount",
//                     .InsertText =          undefined("public execActionWithCount(position: Position): Promise<void> {\n}"),
//                     .FilterText =          undefined("execActionWithCount"),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .Data = &.{
//                         .Source = "ClassMemberSnippet/",
//                     },
//                 },
//             },
//         },
//     });
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined("1"), &.{
//         .Name =        "execActionWithCount",
//         .Source =      "ClassMemberSnippet/",
//         .Description = "Includes imports of types referenced by 'execActionWithCount'",
//         .NewFileContent = undefined("import { Position } from \"vscode\";\nimport { MoveQuoteMatch } from \"./motion\";\n\nexport class MoveInsideNextQuote extends MoveQuoteMatch {\n  keys = [\"i\", \"n\", \"q\"];\n}"),
//     });
}

test "TestDeleteClassWithEnumPresent" {
    const content =
        \\enum Foo { a, b, c }
        \\/**/class Bar { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.DeleteAtCaret(undefined, 13);
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestFindAllRefsTypeParameterInMergedInterface" {
    const content =
        \\interface I</*1*/T> { a: /*2*/T }
        \\interface I</*3*/T> { b: /*4*/T }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestCallHierarchyCrossFile" {
    const content =
        \\// @filename: /a.ts
        \\export function /**/createModelReference() {}
        \\// @filename: /b.ts
        \\import { createModelReference } from "./a";
        \\function openElementsAtEditor() {
        \\  createModelReference();
        \\}
        \\// @filename: /c.ts
        \\import { createModelReference } from "./a";
        \\function registerDefaultLanguageCommand() {
        \\  createModelReference();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyBaselineCallHierarchy(undefined);
}

test "TestSignatureHelpJSDocCallbackTag" {
    const content =
        \\// @lib: es5
        \\// @allowNonTsExtensions: true
        \\// @Filename: jsdocCallbackTag.js
        \\/**
        \\ * @callback FooHandler - A kind of magic
        \\ * @param {string} eventName - So many words
        \\ * @param eventName2 {number | string} - Silence is golden
        \\ * @param eventName3 - Osterreich mos def
        \\ * @return {number} - DIVEKICK
        \\ */
        \\/**
        \\ * @type {FooHandler} callback
        \\ */
        \\var t;
        \\
        \\/**
        \\ * @callback FooHandler2 - What, another one?
        \\ * @param {string=} eventName - it keeps happening
        \\ * @param {string} [eventName2] - i WARNED you dog
        \\ */
        \\/**
        \\ * @type {FooHandler2} callback
        \\ */
        \\var t2;
        \\t(/*4*/"!", /*5*/12, /*6*/false);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.VerifyBaselineSignatureHelp(undefined);
}

test "TestCompletionListInTypeLiteralInTypeParameter16" {
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
        \\(<T extends Foo>() => {})<{/*0*/}>;
        \\
        \\(class <T extends Foo>{})<{/*1*/}>;
        \\
        \\declare const a: {
        \\    new <T extends Foo>(): {};
        \\    <T extends Bar>(): {};
        \\}
        \\a<{/*2*/}>;
        \\
        \\declare const b: {
        \\    new <T extends { one: true }>(): {};
        \\    <T extends { one: false }>(): {};
        \\}
        \\b<{/*3*/}>;
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
//             .Unsorted = &.{},
//         },
//     });
}

test "TestImportNameCodeFixExistingImport8" {
    const content =
        \\import [|{v1, v2, v3,}|] from "./module";
        \\v4/*0*/();
        \\// @Filename: module.ts
        \\export function v4() {}
        \\export var v1 = 5;
        \\export var v2 = 5;
        \\export var v3 = 5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "{v1, v2, v3, v4,}",
    }, null );
}

test "TestCodeFixAddMissingAttributes10" {
    const content =
        \\// @jsx: preserve
        \\// @filename: foo.tsx
        \\type A = 'a' | 'b' | 'c' | 'd' | 'e';
        \\type B = 1 | 2 | 3;
        \\type C = '@' | '!';
        \\type D = 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined, "fixMissingAttributes");
}

test "TestAutoImportProvider_exportMap9" {
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
        \\    "./lol": ["./lib/index.js", "./lib/lol.js"]
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

test "TestFormattingOnTabAfterCloseCurly" {
    const content =
        \\namespace Tools {/*1*/
        \\    export enum NodeType {/*2*/
        \\        Error,/*3*/
        \\        Comment,/*4*/
        \\    }   /*5*/
        \\    export enum foob/*6*/
        \\    {
        \\        Blah=1, Bleah=2/*7*/
        \\    }/*8*/
        \\}/*9*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "namespace Tools {");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "    export enum NodeType {");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "        Error,");
    _ = f.GoToMarker(undefined, "4");
    _ = f.VerifyCurrentLineContent(undefined, "        Comment,");
    _ = f.GoToMarker(undefined, "5");
    _ = f.VerifyCurrentLineContent(undefined, "    }");
    _ = f.GoToMarker(undefined, "6");
    _ = f.VerifyCurrentLineContent(undefined, "    export enum foob {");
    _ = f.GoToMarker(undefined, "7");
    _ = f.VerifyCurrentLineContent(undefined, "        Blah = 1, Bleah = 2");
    _ = f.GoToMarker(undefined, "8");
    _ = f.VerifyCurrentLineContent(undefined, "    }");
    _ = f.GoToMarker(undefined, "9");
    _ = f.VerifyCurrentLineContent(undefined, "}");
}

test "TestAutoImportFileExcludePatterns8" {
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
        \\import { Event } from './workbench2';
        \\export { Event };
        \\// @Filename: /src/vs/workbench/workbench2.ts
        \\import { Event } from '../event/event';
        \\export { Event };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'Parts'",
        .NewFileContent = "import { Event } from '../event/event';\nimport { Parts } from './parts';\nexport class EditorParts implements Parts {\n    options: Event;\n}",
        .Index =           0,
        .UserPreferences = &.{.AutoImportFileExcludePatterns = &.{"src/vs/workbench/workbench*"}},
    });
}

test "TestCompletionsImportModuleAugmentationWithJS" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @noEmit: true
        \\// @Filename: /test.js
        \\class Abcde {
        \\    x
        \\}
        \\
        \\module.exports = {
        \\    Abcde
        \\};
        \\// @Filename: /index.ts
        \\export {};
        \\declare module "./test" {
        \\    interface Abcde { b: string }
        \\}
        \\
        \\Abcde/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "Abcde",
//         .Source =      "./test",
//         .Description = "Add import from \"./test\"",
//         .NewFileContent = undefined("import { Abcde } from \"./test\";\n\nexport {};\ndeclare module \"./test\" {\n    interface Abcde { b: string }\n}\n\nAbcde"),
//     });
}

test "TestGetOccurrencesThis2" {
    const content =
        \\this;
        \\this;
        \\
        \\function f() {
        \\    [|this|];
        \\    [|this|];
        \\    () => [|this|];
        \\    () => {
        \\        if ([|this|]) {
        \\            [|this|];
        \\        }
        \\        else {
        \\            [|t/**/his|].this;
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
        \\    private method2() {
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

test "TestCompletionListAfterRegularExpressionLiteral01" {
    const content =
        \\// @lib: es5
        \\let v = 100;
        \\/a/./**/
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
//                 "exec",
//                 "test",
//                 "source",
//                 "global",
//                 "ignoreCase",
//                 "multiline",
//                 "lastIndex",
//                 &.{
//                     .Label =    "compile",
//                     .SortText = undefined(string(ls.DeprecateSortText(ls.SortTextLocationPriority))),
//                     .Tags =     &&.{lsproto.CompletionItemTagDeprecated},
//                 },
//             },
//         },
//     });
}

test "TestGoToDefinitionOverriddenMember20" {
    const content =
        \\// @strict: true
        \\// @target: esnext
        \\// @lib: esnext
        \\const prop = "foo" as const;
        \\
        \\abstract class A {
        \\  readonly /*2*/[prop] = "A";
        \\}
        \\
        \\export class B extends A {
        \\  [|/*1*/override|] readonly [prop] = "B";
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestCompletionListStaticProtectedMembers3" {
    const content =
        \\// @lib: es5
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
        \\}
        \\
        \\class C3 extends Base {
        \\    protected static protectedOverriddenMethod() { }
        \\    protected static protectedOverriddenProperty;
        \\}
        \\
        \\Base./*1*/;
        \\C3./*2*/;
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
//             .Exact = CompletionFunctionMembersPlus(
//                 &.{
//                     &.{
//                         .Label =    "publicMethod",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "publicProperty",
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

test "TestFormatInsertSpaceAfterCloseBraceBeforeCloseBracket" {
    const content =
        \\[{}]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts122);
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "[ {} ]");
}

test "TestJsdocParam_suggestion1" {
    const content =
        \\// @Filename: a.ts
        \\/**
        \\ * @param options - whatever
        \\ * @param options.zone - equally bad
        \\ */
        \\declare function bad(options: any): void
        \\
        \\/**
        \\ * @param {number} obtuse
        \\ */
        \\function worse(): void {
        \\    arguments
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "a.ts");
    _ = f.VerifySuggestionDiagnostics(undefined, null);
}

test "TestReferencesForInheritedProperties8" {
    const content =
        \\interface C extends D {
        \\    /*d*/propD: number;
        \\}
        \\interface D extends C {
        \\    propD: string;
        \\    /*c*/propC: number;
        \\}
        \\var d: D;
        \\d.propD;
        \\d.propC;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "d", "c");
}

test "TestImportFixes_quotePreferenceDouble_importHelpers" {
    const content =
        \\// @importHelpers: true
        \\// @filename: /a.ts
        \\export default () => {};
        \\// @filename: /b.ts
        \\export default () => {};
        \\// @filename: /test.ts
        \\import a from "./a";
        \\[|b|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/test.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import b from \"./b\";\nb",
    }, null );
}

test "TestQuickInfoJSExport" {
    const content =
        \\// @Filename: a.js
        \\// @allowJs: true
        \\/**
        \\ * @enum {string}
        \\ */
        \\const testString = {
        \\    one: "1",
        \\    two: "2"
        \\};
        \\
        \\export { test/**/String };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "(alias) type testString = string\n(alias) const testString: {\n    one: string;\n    two: string;\n}\nexport testString", "");
}

test "TestCompletionListInUnclosedSpreadExpression02" {
    const content =
        \\var x;
        \\var y = (p) => [1,2,.../*1*/
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
//                 "p",
//                 "x",
//             },
//         },
//     });
}

test "TestIncrementalParsingDynamicImport1" {
    const content =
        \\// @lib: es6
        \\// @module: commonjs
        \\// @Filename: ./foo.ts
        \\export function bar() { return 1; }
        \\var x1 = import("./foo");
        \\x1.then(foo => {
        \\   var s: string = foo.bar();
        \\})
        \\/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "  ");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestImportNameCodeFixNewImportNodeModules6" {
    const content =
        \\[|f1/*0*/('');|]
        \\// @Filename: package.json
        \\{ "dependencies": { "package-name": "latest" } }
        \\// @Filename: node_modules/package-name/bin/lib/index.d.ts
        \\export function f1(text: string): string;
        \\// @Filename: node_modules/package-name/bin/lib/index.js
        \\function f1(text) { }
        \\exports.f1 = f1;
        \\// @Filename: node_modules/package-name/package.json
        \\{
        \\  "main": "bin/lib/index.js",
        \\  "types": "bin/lib/index.d.ts"
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from \"package-name\";\n\nf1('');",
    }, null );
}

test "TestQuickInfoModuleVariables" {
    const content =
        \\var x = 1;
        \\namespace M {
        \\    export var x = 2;
        \\    console.log(/*1*/x); // 2
        \\}
        \\namespace M {
        \\    console.log(/*2*/x); // 2
        \\}
        \\namespace M {
        \\    var x = 3;
        \\    console.log(/*3*/x); // 3
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var M.x: number", "");
    // f.VerifyQuickInfoAt(undefined, "2", "var M.x: number", "");
    // f.VerifyQuickInfoAt(undefined, "3", "var x: number", "");
}

test "TestGoToSource2_nodeModulesWithTypes" {
    const content =
        \\// @lib: es5
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/foo/package.json
        \\{ "name": "foo", "version": "1.0.0", "main": "./lib/main.js", "types": "./types/main.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/foo/lib/main.js
        \\export const /*end*/a = "a";
        \\// @Filename: /home/src/workspaces/project/node_modules/foo/types/main.d.ts
        \\export declare const a: string;
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { a } from "foo";
        \\[|a/*start*/|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "start");
}

test "TestQuickinfoVerbosityClass2" {
    const content =
        \\interface Apple {
        \\    color: string;
        \\}
        \\class Foo/*1*/<T> {
        \\    constructor(public x: T) { }
        \\    public y!: T;
        \\    static whatever(): void { }
        \\    private foo(): Apple { return { color: "green" }; }
        \\    static {
        \\        const a = class { x?: Apple; };
        \\    }
        \\    protected z = true;
        \\}
        \\type Whatever/*2*/ = Foo<string>;
        \\const a/*3*/ = Foo;
        \\const c/*4*/ = Foo<string>;
        \\[1].forEach(class/*5*/ <T> {
        \\    constructor(public x: T) { }
        \\    public y!: T;
        \\    static whatever(): void { }
        \\    private foo(): Apple { return { color: "green" }; }
        \\    static {
        \\        const a = class { x?: Apple; };
        \\    }
        \\    protected z = true;
        \\});
        \\const b/*6*/ = Bar<number>;
        \\@random()
        \\abstract class Animal/*7*/ {
        \\    name!: string;
        \\    abstract makeSound(): void;
        \\}
        \\class Dog/*8*/ {
        \\    what(this: this, that: Dog) { }
        \\    #bones: string[];
        \\}
        \\const d/*9*/ = new Dog();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{0, 1, 2}, .@"2" = .{0, 1, 2}, .@"3" = .{0, 1}, .@"4" = .{0}, .@"5" = .{0, 1, 2}, .@"6" = .{0}, .@"7" = .{0, 1}, .@"8" = .{0, 1}, .@"9" = .{0, 1}});
}

test "TestTslibFindAllReferencesOnRuntimeImportWithPaths1" {
    const content =
        \\// @Filename: project/src/foo.ts
        \\import * as x from /**/"tslib";
        \\// @Filename: project/src/bar.ts
        \\export default "";
        \\// @Filename: project/src/bal.ts
        \\
        \\// @Filename: project/src/dir/tslib.d.ts
        \\export function __importDefault(...args: any): any;
        \\export function __importStar(...args: any): any;
        \\// @Filename: project/tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "moduleResolution": "node",
        \\        "module": "es2020",
        \\        "importHelpers": true,
        \\        "moduleDetection": "force",
        \\        "paths": {
        \\            "tslib": ["./src/dir/tslib"]
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestRenameCommentsAndStrings1" {
    const content =
        \\///<reference path="./Bar.ts" />
        \\[|function [|{| "contextRangeIndex": 0 |}Bar|]() {
        \\    // This is a reference to Bar in a comment.
        \\    "this is a reference to Bar in a string"
        \\}|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "Bar");
}

