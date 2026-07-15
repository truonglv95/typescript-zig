const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionsOnImportIdentifierWithFromOnNextLine" {
    const content =
        \\import something/*1*/
        \\from
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        fourslashUtil.Ignored,
//         },
//         .Items = &.{},
//     });
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        fourslashUtil.Ignored,
//         },
//         .Items = &.{},
//     });
}

test "TestFormatDocumentNoCrashJsxNamespacedName2" {
    const content =
        \\// @Filename: /a.tsx
        \\const x = <A my-ns:attr="val" />;
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "const x = <A my-ns:attr=\"val\" />;\n");
}

test "TestGoToImplementationReexportedTypeOnlyNamespace1" {
    const content =
        \\
        \\// @Filename: /node_modules/@typescript-eslint/types/index.d.ts
        \\export * as TSESTree from './generated/ast-spec';
        \\
        \\// @Filename: /node_modules/@typescript-eslint/types/generated/ast-spec.d.ts
        \\export interface BaseNode {}
        \\
        \\// @Filename: /node_modules/@typescript-eslint/utils/index.d.ts
        \\export { TSESTree } from '@typescript-eslint/types';
        \\
        \\// @Filename: /src/check-license.ts
        \\import type {TSE/*impl*/STree} from '@typescript-eslint/utils';
        \\
        \\let node: TSESTree.Node | undefined;
        \\export default node;
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "impl");
}

test "TestPrivatePropertyOfUndefinedThis1" {
    const content =
        \\
        \\// @strict: true
        \\this.#a = {};
        \\export {};
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineNonSuggestionDiagnostics(undefined);
    // f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestCompletionFilterText4" {
    const content =
        \\declare const x: [number, number];
        \\x[|.|]/**/;
        \\
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
//                     .Label =      "0",
//                     .Kind =       undefined(lsproto.CompletionItemKindField),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                     .InsertText = undefined("[0]"),
//                     .FilterText = undefined(".0"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "[0]",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestGoToSourceAliasedImportExport" {
    const content =
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/package.json
        \\{ "name": "pkg", "main": "./index.js", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.d.ts
        \\export declare const foo: number;
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.js
        \\exports./*target*/foo = 1;
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { foo as /*importAlias*/bar } from "pkg";
        \\bar;
        \\// @Filename: /home/src/workspaces/project/reexport.ts
        \\export { foo as /*reExportAlias*/bar } from "pkg";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importAlias", "reExportAlias");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "aliasedImport");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "constructorCall", "methodCall");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "start");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "reExportFoo", "reExportBar", "moduleSpecifier");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "reExportSpecifier");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importName", "start");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "usage", "reExport");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "usage");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importName", "callSite");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "namedImport", "enumImport", "call", "enumAccess");
}

test "TestGoToSourceScopedPackage" {
    const content =
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/@myscope/mylib/package.json
        \\{ "name": "@myscope/mylib", "main": "./index.js", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/@myscope/mylib/index.d.ts
        \\export declare function scopedHelper(): string;
        \\// @Filename: /home/src/workspaces/project/node_modules/@myscope/mylib/index.js
        \\export function /*target*/scopedHelper() { return "scoped"; }
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { /*importName*/scopedHelper } from "@myscope/mylib";
        \\scopedHelper/*usage*/();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importName", "usage");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "usage");
}

test "TestQuickInfoJSDocCodefenceAtSign" {
    const content =
        \\/**
        \\ * text
        \\ * @example Foo
        \\ * 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestAutoImportReexportOfCrossPackageAugmentation" {
    const content =
        \\// @Filename: /node_modules/vitest/package.json
        \\{ "name": "vitest", "version": "1.0.0", "types": "index.d.ts" }
        \\// @Filename: /node_modules/vitest/index.d.ts
        \\export { AugmentedInterface, uniqueFunction } from "@vitest/expect";
        \\// @Filename: /node_modules/vitest/augmentation.d.ts
        \\export {};
        \\declare module "@vitest/expect" {
        \\    interface AugmentedInterface {
        \\        bar: string;
        \\    }
        \\        function uniqueFunction(): void;
        \\}
        \\// @Filename: /node_modules/@vitest/expect/package.json
        \\{ "name": "@vitest/expect", "version": "1.0.0", "types": "index.d.ts" }
        \\// @Filename: /node_modules/@vitest/expect/index.d.ts
        \\export interface AugmentedInterface {
        \\    baz: number;
        \\}
        \\// @Filename: /tsconfig.json
        \\{ "compilerOptions": { "module": "commonjs", "strict": true } }
        \\// @Filename: /package.json
        \\{ "name": "test", "dependencies": { "vitest": "*" } }
        \\// @Filename: /index.ts
        \\uniqueFunction/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.Configure(undefined, prefs);
    _ = f.GoToMarker(undefined, "");
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
}

test "TestOutliningSpansForImportTagJSDoc" {
    const content =
        \\
        \\// @allowJs: true
        \\// @checkJs: true    
        \\// @Filename: /a.js
        \\[|/**
        \\ * @import {b} from "./b.js";
        \\ * @import {c} from "./c.js";
        \\ */|]
        \\
        \\ [|/**
        \\ * @import {d} from "./d.js";
        \\ */|]
        \\
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOutliningSpans(undefined);
}

test "TestCompletionJSDocNoCrash" {
    const content =
        \\
        \\// @allowJs: true
        \\// @filename: file.js
        \\class ErrorMap {
        \\  /**
        \\   * @type {string}
        \\   *//*1*/
        \\  errorMap;
        \\}
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

test "TestSemanticClassificationJSX" {
    const content =
        \\// @Filename: /a.tsx
        \\const Component = () => <div>Hello</div>;
        \\const afterJSX = 42;
        \\const alsoAfterJSX = "test";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.tsx");
    // f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "function.declaration.readonly", .Text = "Component"},
//         .{.Type = "variable.declaration.readonly", .Text = "afterJSX"},
//         .{.Type = "variable.declaration.readonly", .Text = "alsoAfterJSX"},
//     });
}

test "TestDestructuredIntersectionJSDoc" {
    const content =
        \\
        \\type X = {
        \\    /** Description of a. */
        \\    a: {}
        \\}
        \\
        \\type Y = X & { a: {} }
        \\
        \\declare function f({ /*1*/a }: Y): void
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
    _ = f.VerifyBaselineHover(undefined);
}

test "TestQuickInfoJSDocParamWithTrailingAtBeforeCommentEnd" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\/** @param {string} x trailing @/*at*/*/
        \\function /*fn*/foo(/*x*/x) {}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "fn", "function foo(x: string): void", "\n\n*@param* `x` — trailing @");
    // f.VerifyQuickInfoAt(undefined, "x", "(parameter) x: string", "trailing @");
    // f.VerifyCompletions(undefined, "at", &.{
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

test "TestDocumentHighlightRequirePropertyDestructure1" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\const { a } = require("m").f;
        \\a/*m*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , "m");
}

test "TestCompletionFilterText1" {
    const content =
        \\
        \\class Foo1 {
        \\    #bar: number;
        \\    constructor(bar: number) {
        \\        this.[|b|]/*1*/
        \\    }
        \\}
        \\
        \\class Foo5 {
        \\    #bar: number;
        \\    constructor(bar: number) {
        \\        this./*5*/
        \\    }
        \\}
        \\
        \\class Foo2 {
        \\    #bar: number;
        \\    constructor(bar: number) {
        \\        this.[|#b|]/*2*/
        \\    }
        \\}
        \\
        \\class Foo6 {
        \\    #bar: number;
        \\    constructor(bar: number) {
        \\        this.[|#|]/*6*/
        \\    }
        \\}
        \\
        \\class Foo3 {
        \\    #bar: number;
        \\    constructor(bar: number) {
        \\       [|b|]/*3*/
        \\    }
        \\}
        \\
        \\class Foo7 {
        \\    #bar: number;
        \\    constructor(bar: number) {
        \\       /*7*/
        \\    }
        \\}
        \\
        \\class Foo4 {
        \\    #bar: number;
        \\    constructor(bar: number) {
        \\       [|#b|]/*4*/
        \\    }
        \\}
        \\
        \\class Foo8 {
        \\    #bar: number;
        \\    constructor(bar: number) {
        \\       [|#|]/*8*/
        \\    }
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange = &.{
//                 .Insert =  f.Ranges()[0],
//                 .Replace = f.Ranges()[0],
//             },
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =      "#bar",
//                     .Kind =       undefined(lsproto.CompletionItemKindField),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                     .FilterText = undefined("bar"),
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
//                     .Label =      "#bar",
//                     .Kind =       undefined(lsproto.CompletionItemKindField),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                     .FilterText = undefined("bar"),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange = &.{
//                 .Insert =  f.Ranges()[1],
//                 .Replace = f.Ranges()[1],
//             },
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "#bar",
//                     .Kind =     undefined(lsproto.CompletionItemKindField),
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "6", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange = &.{
//                 .Insert =  f.Ranges()[2],
//                 .Replace = f.Ranges()[2],
//             },
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "#bar",
//                     .Kind =     undefined(lsproto.CompletionItemKindField),
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
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
//                     .Label =      "#bar",
//                     .Kind =       undefined(lsproto.CompletionItemKindField),
//                     .SortText =   undefined(string(ls.SortTextSuggestedClassMembers)),
//                     .FilterText = undefined("bar"),
//                     .TextEdit = &.{
//                         .InsertReplaceEdit = &.{
//                             .NewText = "this.#bar",
//                             .Insert =  f.Ranges()[3].LSRange,
//                             .Replace = f.Ranges()[3].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "7", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =      "#bar",
//                     .Kind =       undefined(lsproto.CompletionItemKindField),
//                     .SortText =   undefined(string(ls.SortTextSuggestedClassMembers)),
//                     .FilterText = undefined("bar"),
//                     .InsertText = undefined("this.#bar"),
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
//                     .Label =    "#bar",
//                     .Kind =     undefined(lsproto.CompletionItemKindField),
//                     .SortText = undefined(string(ls.SortTextSuggestedClassMembers)),
//                     .TextEdit = &.{
//                         .InsertReplaceEdit = &.{
//                             .NewText = "this.#bar",
//                             .Insert =  f.Ranges()[4].LSRange,
//                             .Replace = f.Ranges()[4].LSRange,
//                         },
//                     },
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
//                     .Label =    "#bar",
//                     .Kind =     undefined(lsproto.CompletionItemKindField),
//                     .SortText = undefined(string(ls.SortTextSuggestedClassMembers)),
//                     .TextEdit = &.{
//                         .InsertReplaceEdit = &.{
//                             .NewText = "this.#bar",
//                             .Insert =  f.Ranges()[5].LSRange,
//                             .Replace = f.Ranges()[5].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestBasicEdit" {
    const content =
        \\export {};
        \\interface Point {
        \\    x: number;
        \\    y: number;
        \\}
        \\declare const p: Point;
        \\p/*a*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "a");
    _ = f.Insert(undefined, ".");
    _ = f.GoToEOF(undefined);
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =    "x",
//                     .Kind =     undefined(lsproto.CompletionItemKindField),
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//                 "y",
//             },
//         },
//     });
}

test "TestCallHierarchyIncomingCallsObjectLiteralMethodInStringLiteralComputedProperty" {
    const content =
        \\const obj = {
        \\  ["x"]: {
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

test "TestGoToSourceAliasedImportAtUsageSite" {
    const content =
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/package.json
        \\{ "name": "pkg", "main": "./index.js", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.d.ts
        \\export declare function unrelated(): void;
        \\export declare function original(): string;
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.js
        \\export function unrelated() {}
        \\export function /*target*/original() { return "ok"; }
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { original as renamed } from "pkg";
        \\renamed/*usage*/();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "usage");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "usage");
}

test "TestDocumentHighlightImportPath" {
    const content =
        \\// @Filename: /a.ts
        \\export const x = 0;
        \\
        \\// @Filename: /b.ts
        \\import { x } from "[|./a|]";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , f.Ranges()[0]);
}

test "TestCompletionClassMemberAfterJSDocWithInvalidJSDocTagInTheComment1" {
    const content =
        \\export class NeedsPrefix {
        \\  private _prefixes: {
        \\    add: Record<string, any>;
        \\    browsers: {selected: string[]};
        \\  };
        \\
        \\  constructor(browsers: string[]) {
        \\  }
        \\
        \\  /** Checks whether an @-rule needs to be prefixed. */
        \\  /**/atRule(identifier: string): boolean {
        \\    return true;
        \\  }
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
//         .Items = &.{},
//     });
}

test "TestDocumentSymbolPrivateName" {
    const content =
        \\// @Filename: first.ts
        \\class A {
        \\  #foo() {
        \\    class B {
        \\      #bar() {   
        \\         function baz () {
        \\         }
        \\      }
        \\    }
        \\  }
        \\}
        \\
        \\class B {
        \\    constructor(private prop: string) {}
        \\}
        \\
        \\// @Filename: second.ts
        \\class Foo {
        \\    #privateProp: string;
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
    _ = f.GoToFile(undefined, "second.ts");
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestKeywordShadowsAutoImport" {
    const content =
        \\
        \\// @Filename: /mod.ts
        \\const value = 1;
        \\export { value as function }
        \\
        \\// @Filename: /index.ts
        \\function/**/
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "", &.{
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
//             .Includes = &.{
//                 &.{
//                     .Label =    "function",
//                     .Kind =     undefined(lsproto.CompletionItemKindKeyword),
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//             // After Includes consumes the keyword entry, no other "function" item should remain.
//             .Excludes = &.{"function"},
//         },
//     });
}

test "TestDocumentHighlightYield" {
    const content =
        \\
        \\// @Filename: /a.ts
        \\class C {
        \\  async *[Symbol.asyncIterator]() {
        \\    [|yield|] {
        \\        type: 'type',
        \\    };
        \\  }
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , f.Ranges()[0]);
}

test "TestQuickInfoIndexSignatureMappedType" {
    const content =
        \\
        \\// @strict: true
        \\// @filename: main.ts
        \\declare const record: Record<string, string>;
        \\record.fo/*1*/o;
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "string", "");
}

test "TestGoToImplementationReexportedTypeOnlyNamespace2" {
    const content =
        \\
        \\// @Filename: /node_modules/@typescript-eslint/types/index.d.ts
        \\export type * as TSESTree from './generated/ast-spec';
        \\
        \\// @Filename: /node_modules/@typescript-eslint/types/generated/ast-spec.d.ts
        \\export interface BaseNode {}
        \\
        \\// @Filename: /node_modules/@typescript-eslint/utils/index.d.ts
        \\export { TSESTree } from '@typescript-eslint/types';
        \\
        \\// @Filename: /src/check-license.ts
        \\import type {TSE/*impl*/STree} from '@typescript-eslint/utils';
        \\
        \\let node: TSESTree.Node | undefined;
        \\export default node;
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "impl");
}

test "TestSemanticClassificationClassExpressionMethod" {
    const content =
        \\var x = class C {
        \\  equals(other: C) { return this == other; }
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "class.declaration", .Text = "x"},
//         .{.Type = "class.declaration", .Text = "C"},
//         .{.Type = "method.declaration", .Text = "equals"},
//         .{.Type = "parameter.declaration", .Text = "other"},
//         .{.Type = "class", .Text = "C"},
//         .{.Type = "parameter", .Text = "other"},
//     });
}

test "TestExhaustiveCaseCompletionsUntitledLocalEnum" {
    const content =
        \\// @newline: LF
        \\// @filename: ^/untitled/ts-nul-authority/Untitled-1.ts
        \\enum E {
        \\    A = "A",
        \\    B = "B",
        \\    C = "C",
        \\}
        \\declare const e: E;
        \\switch (e) {
        \\    case/**/
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
//                     .Label =            "case E.A: ...",
//                     .InsertText =       undefined("case E.A:$1\ncase E.B:$2\ncase E.C:$3"),
//                     .SortText =         undefined(string(ls.SortTextGlobalsOrKeywords)),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =            "case Direction.Up: ...",
//                     .InsertText =       undefined("case Direction.Up:$1\ncase Direction.Down:$2\ncase Direction.Left:$3\ncase Direction.Right:$4"),
//                     .SortText =         undefined(string(ls.SortTextGlobalsOrKeywords)),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =            "case \"error\": ...",
//                     .InsertText =       undefined("case \"error\":$1"  ++  "\n"  ++  "case \"pending\":$2"  ++  "\n"  ++  "case \"success\":$3"),
//                     .SortText =         undefined(string(ls.SortTextGlobalsOrKeywords)),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =            "case Status.Active: ...",
//                     .InsertText =       undefined("case Status.Active:$1\ncase Status.Inactive:$2\ncase Status.Pending:$3"),
//                     .SortText =         undefined(string(ls.SortTextGlobalsOrKeywords)),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                 },
//             },
//         },
//     });
}

test "TestAutoImportCompletion1" {
    const content =
        \\// @Filename: a.ts
        \\export const someVar = 10;
        \\
        \\// @Filename: b.ts
        \\export const anotherVar = 10;
        \\
        \\// @Filename: c.ts
        \\import {someVar} from "./a.ts";
        \\someVar;
        \\a/**/
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "", &.{
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
//             .Includes = &.{"someVar", "anotherVar"},
//         },
//     });
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
    // f.VerifyCompletions(undefined, "", &.{
//         .UserPreferences = &.{
//             // completion autoimport preferences off; this tests if fourslash server communication correctly registers changes in user preferences
//             .IncludeCompletionsForModuleExports =    core.TSFalse,
//             .IncludeCompletionsForImportStatements = core.TSFalse,
//         },
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Excludes = &.{"anotherVar"},
//         },
//     });
    // f.VerifyCompletions(undefined, "", &.{
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
//             .Includes = &.{"someVar", "anotherVar"},
//         },
//     });
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
    // f.VerifyCompletions(undefined, "", &.{
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
//             .Includes = &.{"bb"},
//         },
//     });
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
}

test "TestCodeLensReferencesShowOnAllFunctions" {
    const content =
        \\
        \\export function f1(): void {}
        \\
        \\function f2(): void {}
        \\
        \\export const f3 = () => {};
        \\
        \\const f4 = () => {};
        \\
        \\const f5 = function() {};
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineCodeLens(undefined, &.{
//                 .CodeLens = .{
//                     .ReferencesCodeLensEnabled =            core.TSTrue,
//                     .ReferencesCodeLensShowOnAllFunctions = value,
//                 },
//             });
}

test "TestFormatDocumentNoCrashJsxAttrUnterminatedString" {
    const content =
        \\// @Filename: /a.tsx
        \\const x = <HangupButton customClass = 'ha
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "const x = <HangupButton customClass= 'ha\n");
}

test "TestGetEditsForFileRename_cssImport4" {
    const content =
        \\
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
        \\import styles from ".//*rename*/app.css";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyRename(undefined, "rename", "app2.css", .{
//         .@"/a.ts" = "import styles from \"./app2.css\";",
//         .@"/app2.d.css.ts" = "declare const css: {\n  cookieBanner: string;\n};\nexport default css;",
//         .@"/app2.css" = ".cookie-banner {\n  display: none;\n}",
//     });
}

test "TestSignatureHelpBindingPattern" {
    const content =
        \\
        \\/**
        \\ * @param options An empty object binding pattern.
        \\ */
        \\function emptyObj({}) {}
        \\emptyObj(/*emptyObj*/)
        \\
        \\/**
        \\ * @param items An empty array binding pattern.
        \\ */
        \\function emptyArr([]) {}
        \\emptyArr(/*emptyArr*/)
        \\
        \\/**
        \\ * @param param An object with a and b properties.
        \\ */
        \\function nonEmptyObj({a, b}: {a: number, b: string}) {}
        \\nonEmptyObj(/*nonEmptyObj*/)
        \\
        \\/**
        \\ * @param tuple A tuple with two elements.
        \\ */
        \\function nonEmptyArr([x, y]: [number, string]) {}
        \\nonEmptyArr(/*nonEmptyArr*/)
        \\
        \\/**
        \\ * @param first The first number parameter.
        \\ * @param second An object with a and b properties.
        \\ */
        \\function idLeading(first: number, {a, b}: {a: number, b: string}) {}
        \\idLeading(123/*idLeading*/, { a: 1, b: 2 }/*bindingTrailing*/)
        \\
        \\/**
        \\ * @param first An object with a and b properties.
        \\ * @param last The last number parameter.
        \\ */
        \\function bindingLeading({a, b}: {a: number, b: string}, last: number) {}
        \\bindingLeading(/*bindingLeading*/{ a: 1, b: 2 }, 123 /*idTrailing*/)
        \\
        \\/**
        \\ * @param param1 {Object} The first parameter
        \\ * @param param1.a {number} Comment a
        \\ * @param param1.b {string} Comment b
        \\ * @param param2 {Object} The second parameter
        \\ * @param param2.c {boolean} Comment c
        \\ * @param param2.d {unknown} Comment d
        \\ */
        \\function multipleBindings({ a, b }, { c, d }) {}
        \\multipleBindings({ a: 0, b: "" }/*firstObjParam*/, { c: true, d: "" }/*secondObjParam*/)
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSignatureHelp(undefined);
}

test "TestGoToImplementationNoCrashTripleSlashRef2" {
    const content =
        \\// @Filename: /node_modules/@types/react/index.d.ts
        \\export type JSX = {};
        \\
        \\// @Filename: /node_modules/excalidraw/index.d.ts
        \\/// <reference types="react" />
        \\
        \\// @Filename: /index.ts
        \\import type {JSX} from '/*m*/react';
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "m");
}

test "TestQuickInfoJSDocLinkBackticks" {
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
    _ = f.VerifyQuickInfoIs(undefined, "function f(x: string): string", "`{@link foo}` initial at-param is OK in title comment\n\n*@param* `x` — hi there `{@link foo}`");
    _ = f.GoToMarker(undefined, "x");
    _ = f.VerifyQuickInfoIs(undefined, "(parameter) x: string", "hi there `{@link foo}`");
}

test "TestQuickInfoDestructuredBinding" {
    const content =
        \\
        \\function f({ /*1*/x }: { x: number }) {}
        \\function g([/*2*/y]: number[]) {}
        \\function h({ a: { /*3*/b } }: { a: { b: string } }) {}
        \\const { /*4*/c } = { c: 42 };
        \\let { /*5*/d } = { d: "hello" };
        \\var { /*6*/e } = { e: true };
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(parameter) x: number", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(parameter) y: number", "");
    // f.VerifyQuickInfoAt(undefined, "3", "(parameter) b: string", "");
    // f.VerifyQuickInfoAt(undefined, "4", "const c: number", "");
    // f.VerifyQuickInfoAt(undefined, "5", "let d: string", "");
    // f.VerifyQuickInfoAt(undefined, "6", "var e: boolean", "");
}

test "TestFindAllRefsExportStringRename" {
    const content =
        \\const foo = 123;
        \\export { foo as /**/"bar" };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestCompletionsForContextualConstraintTypeInJsDoc" {
    const content =
        \\
        \\// @allowJs: true
        \\// @filename: a.ts
        \\export interface Blah<T extends { a: "hello" | "world" }> {
        \\}
        \\
        \\// @filename: b.js
        \\/** @import * as a from "./a" */
        \\
        \\/** @type {a.Blah<{ a: /*1*/ }>} */
        \\let x;
        \\
        \\// @filename: c.js
        \\/** @import * as a from "./a" */
        \\
        \\/** @type {a.Blah<{ a: /*2*/ }>} */
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, f.Markers(), &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{.CommitCharacters = &&.{".", ",", ";"}},
//         .Items = &.{
//             .Includes = &.{
//                 "\"hello\"",
//                 "\"world\"",
//             },
//         },
//     });
}

test "TestCompletionDetailSignature" {
    const content =
        \\
        \\
        \\/*a*/
        \\
        \\function foo(x: string): string;
        \\function foo(x: number): number;
        \\function foo(x: any): any {
        \\    return x;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "a", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "foo",
//                     .Kind =     undefined(lsproto.CompletionItemKindFunction),
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                     .Detail =   undefined("function foo(x: string): string\nfunction foo(x: number): number"),
//                 },
//             },
//         },
//     });
}

test "TestHoverOptionalMembers" {
    const content =
        \\
        \\type Foo1 = {
        \\    x?: string;
        \\    f?: (x: number) => void;
        \\    g?: { (x: number): void; (x: string): void; }
        \\    h?: ((x: number) => void) & ((x: string) => void);
        \\    m?(x: number): void;
        \\    m?(x: string): void;
        \\}
        \\
        \\interface Foo2 {
        \\    x?: string;
        \\    f?: (x: number) => void;
        \\    g?: { (x: number): void; (x: string): void; }
        \\    h?: ((x: number) => void) & ((x: string) => void);
        \\    m?(x: number): void;
        \\    m?(x: string): void;
        \\}
        \\
        \\class Foo3 {
        \\    x?: string;
        \\    f?: (x: number) => void;
        \\    g?: { (x: number): void; (x: string): void; }
        \\    h?: ((x: number) => void) & ((x: string) => void);
        \\    m?(x: number): void;
        \\    m?(x: string): void;
        \\}
        \\
        \\declare const foo1: Foo1;
        \\declare const foo2: Foo2;
        \\declare const foo3: Foo3;
        \\
        \\foo1./*1*/x
        \\foo1./*1a*/f
        \\foo1./*1b*/f?.(42)
        \\foo1./*1c*/g
        \\foo1./*1d*/g?.(42)
        \\foo1./*1e*/g?.("abc")
        \\foo1./*1f*/h
        \\foo1./*1g*/h?.(42)
        \\foo1./*1h*/h?.("abc")
        \\foo1./*1i*/m
        \\foo1./*1j*/m?.(42)
        \\foo1./*1k*/m?.("abc")
        \\
        \\foo2./*2*/x
        \\foo2./*2a*/f
        \\foo2./*2b*/f?.(42)
        \\foo2./*2c*/g
        \\foo2./*2d*/g?.(42)
        \\foo2./*2e*/g?.("abc")
        \\foo2./*2f*/h
        \\foo2./*2g*/h?.(42)
        \\foo2./*2h*/h?.("abc")
        \\foo2./*2i*/m
        \\foo2./*2j*/m?.(42)
        \\foo2./*2k*/m?.("abc")
        \\
        \\foo3./*3*/x
        \\foo3./*3a*/f
        \\foo3./*3b*/f?.(42)
        \\foo3./*3c*/g
        \\foo3./*3d*/g?.(42)
        \\foo3./*3e*/g?.("abc")
        \\foo3./*3f*/h
        \\foo3./*3g*/h?.(42)
        \\foo3./*3h*/h?.("abc")
        \\foo3./*3i*/m
        \\foo3./*3j*/m?.(42)
        \\foo3./*3k*/m?.("abc")
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestAutoImportCrossProjectNodeModules" {
    const content =
        \\// @Filename: /node_modules/pkg-listed/package.json
        \\{ "name": "pkg-listed", "version": "1.0.0" }
        \\// @Filename: /node_modules/pkg-listed/index.d.ts
        \\export declare const pkg_listed_value: number;
        \\// @Filename: /node_modules/pkg-unlisted/package.json
        \\{ "name": "pkg-unlisted", "version": "1.0.0" }
        \\// @Filename: /node_modules/pkg-unlisted/index.d.ts
        \\export declare const pkg_unlisted_value: string;
        \\// @Filename: /project-a/tsconfig.json
        \\{ "compilerOptions": { "module": "commonjs", "strict": true } }
        \\// @Filename: /project-a/package.json
        \\{ "name": "project-a", "dependencies": { "pkg-listed": "*" } }
        \\// @Filename: /project-a/index.ts
        \\import { pkg_unlisted_value } from "pkg-unlisted";
        \\console.log(pkg_unlisted_value);
        \\// @Filename: /project-b/tsconfig.json
        \\{ "compilerOptions": { "module": "commonjs", "strict": true } }
        \\// @Filename: /project-b/package.json
        \\{ "name": "project-b", "dependencies": { "pkg-listed": "*" } }
        \\// @Filename: /project-b/index.ts
        \\pkg_/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/project-a/index.ts");
    _ = f.GoToMarker(undefined, "");
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
}

test "TestBasicGlobalCompletions" {
    const content =
        \\// @lib: es5
        \\/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobals,
//         },
//     });
}

test "TestCompletionsPathUnknownExtension" {
    const content =
        \\// @filename: src/some-file.ruhroh
        \\/* This is just a test file that needs to exist. */
        \\
        \\// @filename: package.json
        \\{
        \\    "imports": {
        \\        "#/*": "./src/*"
        \\    }
        \\}
        \\
        \\// @filename: src/globals.d.ts
        \\declare module "*.ruhroh";
        \\
        \\// @filename: src/a.mts
        \\import "#//*$*/"
        \\
        \\// @filename: tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "module": "preserve",
        \\        "moduleResolution": "bundler",
        \\        "rootDir": "src"
        \\    },
        \\    "include": ["src"]
        \\}
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
//             .Includes = &.{
//                 "some-file.ruhroh",
//             },
//         },
//     });
}

test "TestGoToDefinitionGetterReturningCallableInterface" {
    const content =
        \\// @Filename: /home/src/workspaces/project/type.d.ts
        \\export interface DidChangeContentEvent {
        \\    (): void;
        \\}
        \\
        \\export declare class TextDocuments {
        \\    get onDidChangeContent(): DidChangeContentEvent;
        \\}
        \\
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { TextDocuments } from "./type";
        \\
        \\declare const documents: TextDocuments | undefined;
        \\
        \\documents!./*usage*/onDidChangeContent()
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, false , "usage");
}

test "TestGoToImplementationNoCrashTripleSlashRef" {
    const content =
        \\// @Filename: /node_modules/@types/mymod/index.d.ts
        \\export declare function foo(): void;
        \\// @Filename: /main.d.ts
        \\/// <reference types="/*m*/mymod" />
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "m");
}

test "TestAutoImportTypedefMissingName" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /utils.js
        \\/** @typedef {{ x: number }} */
        \\
        \\export function doSomething() {}
        \\// @Filename: /index.ts
        \\doSomething/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
}

test "TestGoToDefinitionOnInvalidParameterDecorator" {
    const content =
        \\function f(@/*1*/f) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestCodeLensInterface01" {
    const content =
        \\
        \\// @module: preserve
        \\
        \\// @filename: ./pointable.ts
        \\export interface Pointable {
        \\  getX(): number;
        \\  getY(): number;
        \\}
        \\
        \\// @filename: ./classPointable.ts
        \\import { Pointable } from "./pointable";
        \\
        \\class Point implements Pointable {
        \\  getX(): number {
        \\    return 0;
        \\  }
        \\  getY(): number {
        \\    return 0;
        \\  }
        \\}
        \\
        \\// @filename: ./objectPointable.ts
        \\import { Pointable } from "./pointable";
        \\
        \\let x = 0;
        \\let y = 0;
        \\const p: Pointable = {
        \\  getX(): number {
        \\    return x;
        \\  },
        \\  getY(): number {
        \\    return y;
        \\  },
        \\};
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

test "TestCallHierarchyInPropDeclarationOfExportedDefaultClass1" {
    const content =
        \\// @Filename: /main.ts
        \\export default class {
        \\  onSave = () => {
        \\    const values = [];
        \\    values./*m1*/push(1);
        \\  };
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "m1");
    // f.VerifyBaselineCallHierarchy(undefined);
}

test "TestQuickinfoVerbosityNamespacePrivateTypes" {
    const content =
        \\
        \\declare namespace API/*1*/ {
        \\    interface InternalConfig {
        \\        secret: string;
        \\        timeout: number;
        \\    }
        \\    function configure(config: InternalConfig): void;
        \\    const defaultConfig: InternalConfig;
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{0, 1}});
}

test "TestCompletionImportKeywordNoCrash" {
    const content =
        \\import super/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "1", &.{
//             .IsIncomplete = false,
//             .ItemDefaults = &.{
//                 .CommitCharacters = &emptyCommitChars,
//             },
//             .Items = &.{
//                 .Includes = &.{
//                     "type",
//                 },
//             },
//         });
    // f.VerifyCompletions(undefined, "1", &.{
//             .IsIncomplete = false,
//             .ItemDefaults = &.{
//                 .CommitCharacters = &emptyCommitChars,
//             },
//             .Items = &.{
//                 .Includes = &.{
//                     "type",
//                 },
//             },
//         });
}

test "TestCompletionsJSDocTrivia" {
    const content =
        \\// @noLib: true
        \\/**
        \\ * @type {{
        \\ * 'string-property': boolean;
        \\ */*$*/ identifierProperty: boolean;
        \\ * }}
        \\ */
        \\var someVariable;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "$");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{".", ",", ";"},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{},
//     });
}

test "TestGoToSourceAliasedImportWithPrecedingExports" {
    const content =
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/package.json
        \\{ "name": "pkg", "main": "./index.js", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.d.ts
        \\export declare function unrelated(): void;
        \\export declare function original(): string;
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.js
        \\export function unrelated() {}
        \\export function /*target*/original() { return "ok"; }
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { original as /*aliasedImport*/renamed } from "pkg";
        \\renamed();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "aliasedImport");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "reExportAlias");
}

test "TestGoToDefinitionPreferSourceDefinition" {
    const content =
        \\// @Filename: /home/src/workspaces/project/a.js
        \\export const /*sourceTarget*/a = "a";
        \\// @Filename: /home/src/workspaces/project/a.d.ts
        \\export declare const /*dtsTarget*/a: string;
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { a } from "./a";
        \\a/*start*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, false , "start");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "start");
    // f.Configure(undefined, .{.PreferGoToSourceDefinition = true});
    // f.VerifyBaselineGoToDefinition(undefined, false , "start");
    // f.Configure(undefined, .{.PreferGoToSourceDefinition = true});
    // f.VerifyBaselineGoToDefinition(undefined, false , "start");
}

test "TestDocumentHighlightTypeParameterConstraintExpressionNoCrash1" {
    const content =
        \\// @Filename: /a.ts
        \\const v/*m*/alue = 1;
        \\type Box<T extends +value> = typeof value
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , "m");
}

test "TestQuickinfoVerbosityNamespaceTypeAliases" {
    const content =
        \\
        \\type BaseConfig = { host: string; port: number };
        \\
        \\declare namespace Config/*1*/ {
        \\    type Readonly<T> = { readonly [K in keyof T]: T[K] };
        \\    type Optional<T> = { [K in keyof T]?: T[K] };
        \\    type ServerConfig = Readonly<BaseConfig>;
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{0, 1}});
}

test "TestCompletionFilterText2" {
    const content =
        \\// @strict: true
        \\declare const foo1: { bar: string } | undefined;
        \\if (true) {
        \\    foo1[|.|]/*1*/
        \\}
        \\else {
        \\    foo1?./*2*/
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
//                     .Label =      "bar",
//                     .Kind =       undefined(lsproto.CompletionItemKindField),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                     .InsertText = undefined("?.bar"),
//                     .FilterText = undefined(".bar"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "?.bar",
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
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "bar",
//                     .Kind =     undefined(lsproto.CompletionItemKindField),
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//             },
//         },
//     });
}

test "TestDecoratorCompletionOnPrivateMethod" {
    const content =
        \\
        \\// @experimentalDecorators: true
        \\declare function dec(target: any, key: string): void;
        \\class C {
        \\    @dec/**/
        \\    #method() {}
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
//                 "dec",
//             },
//         },
//     });
}

test "TestGoToImplementationNoCrashUMDWithDynamicImport" {
    const content =
        \\// @Filename: /lib.d.ts
        \\export as namespace Lib;
        \\export interface /*1*/IFoo {}
        \\// @Filename: /user.ts
        \\const p = import('./lib');
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "1");
}

test "TestDocumentHighlightJSDocThisFunctionExpressionParameter" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\/**@this{A}*/x=function(/*m*/a){};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , "m");
}

test "TestQuickinfoVerbosityNamespaceErrorClassHeritage1" {
    const content =
        \\
        \\namespace NS/*1*/ {
        \\    export class Derived extends NonExistentClass {
        \\        derivedField: number;
        \\    }
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{0, 1}});
}

test "TestCodeFixPromoteTypeOnlyImportJsxTag" {
    const content =
        \\// @module: preserve
        \\// @verbatimModuleSyntax: true
        \\// @jsx: react
        \\// @Filename: /react.ts
        \\const React: any = {};
        \\export default React;
        \\// @Filename: /bar.tsx
        \\import type React from "./react";
        \\
        \\<Foo/**/ />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import React from \"./react\";\n\n<Foo />;",
    }, null );
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import type React from \"./react\";\nimport { Foo } from \"./foo\";\n\n<Foo />;",
        "import React from \"./react\";\nimport type { Foo } from \"./foo\";\n\n<Foo />;",
    }, null );
}

test "TestQuickinfoVerbosityNamespaceInterfaceHeritageIntersectionCrash" {
    const content =
        \\
        \\declare namespace NS/*1*/ {
        \\    type Mixin = { a: string } & { b: number };
        \\    interface Config extends Mixin {}
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{0, 1}});
}

test "TestCompletionInArrayLiteralAfterInvalidToken1" {
    const content =
        \\const pairs: Record<string, [string, string]> = {
        \\  a: ["x",:/*m1*/]
        \\};
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "m1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//         },
//         .Items = &.{},
//     });
}

test "TestGoToSourceNestedScopeShadowing" {
    const content =
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/package.json
        \\{ "name": "pkg", "main": "./index.js", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.d.ts
        \\export declare function helper(): string;
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.js
        \\export function /*targetHelper*/helper() { return "ok"; }
        \\function unrelated() {
        \\    const helper = "shadow";
        \\    return helper;
        \\}
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { /*importHelper*/helper } from "pkg";
        \\helper/*usage*/();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importHelper", "usage");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importWidget");
}

test "TestBasicQuickInfo" {
    const content =
        \\
        \\/**
        \\ * Some var
        \\ */
        \\var someVar/*1*/ = 123;
        \\
        \\/**
        \\ * Other var
        \\ * See {@link someVar}
        \\ */
        \\var otherVar/*2*/ = someVar;
        \\
        \\class Foo/*3*/ {
        \\    #bar: string;
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var someVar: number", "Some var");
    // f.VerifyQuickInfoAt(undefined, "2", "var otherVar: number", "Other var\nSee [someVar](file:///basicQuickInfo.ts#5,5-5,12)");
}

test "TestExportAssignmentMissingName" {
    const content =
        \\export = 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCompletionsSelfDeclaring2" {
    const content =
        \\// @lib: es5
        \\function f1<T>(x: T) {}
        \\f1({ [|abc|]/*1*/ });
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange = &.{
//                 .Insert =  f.Ranges()[0],
//                 .Replace = f.Ranges()[0],
//             },
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalsPlus(&.{
//                 "f1",
//             }, false ),
//         },
//     });
}

test "TestCallHierarchyIncomingCallsObjectLiteralMethodInExpressionComputedProperty" {
    const content =
        \\const obj = {
        \\  [1 + 2]: {
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

test "TestHoverThenDiagnosticsJsxIntrinsic" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{ "compilerOptions": { "strict": true, "jsx": "preserve" } }
        \\// @Filename: /jsx.d.ts
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        div: any;
        \\    }
        \\}
        \\// @Filename: /file.tsx
        \\export default function Home() {
        \\    return <di/*1*/v>hi</div>;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(property) JSX.IntrinsicElements.div: any", "");
    _ = f.VerifyNoErrors(undefined);
}

test "TestFoldingRangeJSXPropertyAccess" {
    const content =
        \\// @jsx: preserve
        \\// @Filename: /a.tsx
        \\const Components =[| {
        \\  Nested: () => null
        \\}|];
        \\
        \\export const Test = () =>[| {
        \\  return [|<Components.Nested></Components.Nested>|];
        \\}|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOutliningSpans(undefined);
}

test "TestSignatureHelpJsxTextLessThanTrigger" {
    const content =
        \\//@Filename: test.tsx
        \\//@jsx: react
        \\declare var React: any;
        \\declare function Text(props: { children?: any }): any;
        \\
        \\const text = () => {
        \\    return <Text>/*m*/</Text>;
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "m");
    _ = f.Insert(undefined, "<");
    // f.VerifyNoSignatureHelpWithContext(undefined, &.{
//         .TriggerKind =      lsproto.SignatureHelpTriggerKindTriggerCharacter,
//         .TriggerCharacter = undefined("<"),
//         .IsRetrigger =      false,
//     });
}

test "TestGoToSourceFindImplementationNonNodeModules" {
    const content =
        \\// @moduleResolution: bundler
        \\// @declaration: true
        \\// @Filename: /home/src/workspaces/project/lib/helper.d.ts
        \\export declare function helper(): string;
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { /*usage*/helper } from "./lib/helper";
        \\helper();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "usage");
}

test "TestJSDocSnippetCompletionForFunction" {
    const content =
        \\/*completion*/ */
        \\function abcdef(x, y) { }
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "completion");
    _ = f.Insert(undefined, "/**");
    // f.GetCompletions(undefined, null );
    _ = f.GoToMarker(undefined, "completion");
    _ = f.Insert(undefined, "/**");
    // f.GetCompletions(undefined, null );
    _ = f.GoToMarker(undefined, "completion");
    _ = f.Insert(undefined, "/**");
    // f.GetCompletions(undefined, &userPreferences);
    _ = f.GoToMarker(undefined, "completion");
    _ = f.Insert(undefined, "/**");
    // f.GetCompletions(undefined, &userPreferences);
    _ = f.GoToMarker(undefined, "completion");
    _ = f.Insert(undefined, "/**");
    // f.GetCompletions(undefined, &userPreferences);
    _ = f.GoToMarker(undefined, "completion");
    _ = f.Insert(undefined, "/**");
    // f.GetCompletions(undefined, null );
    _ = f.VerifyCompletions(undefined, "completion", null);
}

test "TestCodeLensFunctionsAndConstants01" {
    const content =
        \\
        \\// @module: preserve
        \\
        \\// @filename: ./exports.ts
        \\
        \\let callCount = 0;
        \\export function foo(n: number): void {
        \\  callCount++;
        \\  if (n > 0) {
        \\    foo(n - 1);
        \\  }
        \\  else {
        \\    console.log("function was called " + callCount + " times");
        \\  }
        \\}
        \\
        \\foo(5);
        \\
        \\export const bar = 123;
        \\
        \\// @filename: ./importer.ts
        \\import { foo, bar } from "./exports";
        \\
        \\foo(5);
        \\console.log(bar);
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

test "TestAutoImportSymlinkedMonorepoProjectReferencesNoPkgExports" {
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
        \\  "main": "dist/index.js",
        \\  "types": "dist/index.d.ts"
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

test "TestCallHierarchyAnonymousFunctionNoCrash1" {
    const content =
        \\// @Filename: /main.ts
        \\func/*1*/tion() {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifyBaselineCallHierarchy(undefined);
}

test "TestAutoImportNodeBuiltinNodenext" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{ "compilerOptions": { "module": "nodenext", "types": ["node"] } }
        \\// @Filename: /package.json
        \\{ "type": "module" }
        \\// @Filename: /node_modules/@types/node/package.json
        \\{ "name": "@types/node", "version": "22.0.0" }
        \\// @Filename: /node_modules/@types/node/index.d.ts
        \\declare module "fs" {
        \\    export function existsSync(path: string): boolean;
        \\    export function mkdirSync(path: string, options?: { recursive?: boolean }): void;
        \\}
        \\declare module "node:fs" { export * from "fs"; }
        \\// @Filename: /index.ts
        \\existsSync/**/
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
//                     .Label = "existsSync",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "node:fs",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
}

test "TestSignatureHelpContextualConstructSignatureNoCrash" {
    const content =
        \\
        \\type Obj = {
        \\    foo: new () => object
        \\}
        \\
        \\let obj: Obj = {
        \\    foo(/*constructOnly*/) {}
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "constructOnly");
    // f.VerifyNoSignatureHelp(undefined);
}

test "TestRenameNamedImportUseAliasesForRenames" {
    const content =
        \\// @Filename: /a.ts
        \\import { /*import*/MyTypeA } from "./b";
        \\const type: MyTypeA = { foo: "bar" };
        \\// @Filename: /b.ts
        \\export interface MyTypeA {
        \\    foo: string;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, &.{.UseAliasesForRename = core.TSFalse}, "import");
    // f.VerifyBaselineRename(undefined, &.{.UseAliasesForRename = core.TSTrue}, "import");
    // f.VerifyBaselineRename(undefined, null , "fooImport");
    // f.VerifyBaselineRename(undefined, &.{.UseAliasesForRename = core.TSTrue}, "fooImport");
    _ = f.GoToMarker(undefined, "fooImport");
    // f.VerifyRenameFailed(undefined, &.{.UseAliasesForRename = core.TSFalse});
}

test "TestQuickinfoVerbosityNamespaceClassHeritage" {
    const content =
        \\
        \\declare class Base {
        \\    id: number;
        \\}
        \\
        \\declare namespace Shapes/*1*/ {
        \\    class Circle extends Base {
        \\        radius: number;
        \\    }
        \\    class Square extends Base {
        \\        side: number;
        \\    }
        \\    interface Drawable {
        \\        draw(): void;
        \\    }
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{0, 1}});
}

test "TestQuickinfoVerbosityNamespaceMembers" {
    const content =
        \\
        \\declare namespace NS/*1*/ {
        \\    type StringAlias = string;
        \\    type Pair<T> = { first: T; second: T };
        \\
        \\    enum Color { Red, Green, Blue }
        \\
        \\    class MyClass {
        \\        name: string;
        \\        greet(): void;
        \\    }
        \\
        \\    interface MyInterface {
        \\        id: number;
        \\        label: string;
        \\    }
        \\
        \\    const value: number;
        \\    function doSomething(x: string): boolean;
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{0, 1}});
}

test "TestOrganizeImports_sortModuleSpecifiers_nonRelativeVsNonRelative" {
    const content =
        \\import x from "lib2";
        \\import y from "lib1";
        \\x; y;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(
//         undefined,
//         "import y from \"lib1\";\nimport x from \"lib2\";\nx; y;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "import y from \"./lib1\";\nimport x from \"./lib2\";\nx; y;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "import y from \"lib\";\nimport x from \"./lib\";\nx; y;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "import y from \"a\";\nimport x from \"Z\";\nx; y;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "import y from \"A\";\nimport x from \"z\";\nx; y;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
}

test "TestAutoImportSpecifierExcludeRegexes" {
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
//         .AutoImportSpecifierExcludeRegexes =     &.{".*ignoreme.*"},
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

test "TestExhaustiveCaseCompletions10" {
    const content =
        \\
        \\declare const u: "$1" | "2";
        \\switch (u) {
        \\    case/*1*/
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
//                     .Label =      "case \"$1\": ...",
//                     .InsertText = undefined("case \"$1\":\ncase \"2\":"),
//                     .SortText =   undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestAutoImportQuoteDetection" {
    const content =
        \\// @module: esnext
        \\// @Filename: /a.ts
        \\export const foo = 0;
        \\// @Filename: /b.ts
        \\import {} from 'node:path';
        \\
        \\fo/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "foo",
//         .Source =      "./a",
//         .Description = "Add import from \"./a\"",
//         .NewFileContent = undefined("import {} from 'node:path';\nimport { foo } from './a';\n\nfo"),
//     });
}

test "TestCompletionWithUnterminatedJSDocEndingWithAt1" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /atOnNewLineAtEOF.js
        \\function foo(x) {}
        \\/**
        \\ * @/*1*/
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

test "TestTsxFindAllReferences1VS" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        /*1*/div: {
        \\            name?: string;
        \\            isOpen?: boolean;
        \\        };
        \\        span: { n: string; };
        \\    }
        \\}
        \\var x = /*2*/</*3*/div />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineVSFindAllReferences(undefined, "1", "2", "3");
}

test "TestDocumentHighlightReferenceDirective" {
    const content =
        \\// @Filename: /a.ts
        \\/// <reference path="[|./b.ts|]" />
        \\
        \\const x = 1;
        \\
        \\// @filename: b.ts
        \\export type Foo = number;
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , f.Ranges()[0]);
}

test "TestQuickInfoJSDocTypedefPropertyWithInvalidTag" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\/**
        \\ * @typedef {Object} MyType1
        \\ * @property {string} name
        \\ * @-rule
        \\ * @property {number} age
        \\ */
        \\
        \\/**
        \\ * @typedef {Object} MyType2
        \\ * @property {string} name
        \\ * some comment
        \\ * @property {number} age
        \\ */
        \\
        \\/**
        \\ * @typedef {Object} MyType3
        \\ * @property {string} name
        \\ * @*stars
        \\ * @property {number} age
        \\ */
        \\
        \\/**
        \\ * @typedef {Object} MyType4
        \\ * @property {string} name
        \\ * @(parens)
        \\ * @property {number} age
        \\ */
        \\
        \\/**
        \\ * @typedef {Object} MyType5
        \\ * @property {string} name
        \\ * @foo*bar
        \\ * @property {number} age
        \\ */
        \\
        \\/** @type {/*t1*/MyType1} */
        \\const obj1 = { /*1n*/name: "", /*1a*/age: 10 };
        \\
        \\/** @type {/*t2*/MyType2} */
        \\const obj2 = { /*2n*/name: "", /*2a*/age: 10 };
        \\
        \\/** @type {/*t3*/MyType3} */
        \\const obj3 = { /*3n*/name: "", /*3a*/age: 10 };
        \\
        \\/** @type {/*t4*/MyType4} */
        \\const obj4 = { /*4n*/name: "", /*4a*/age: 10 };
        \\
        \\/** @type {/*t5*/MyType5} */
        \\const obj5 = { /*5n*/name: "", /*5a*/age: 10 };
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "t1", "type MyType1 = {\n    name: string;\n    age: number;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "t2", "type MyType2 = {\n    name: string;\n    age: number;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "t3", "type MyType3 = {\n    name: string;\n    age: number;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "t4", "type MyType4 = {\n    name: string;\n    age: number;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "t5", "type MyType5 = {\n    name: string;\n}", "" ++ 
//         "\n\n*@foo* — *bar" ++ 
//         "\n\n*@property* — {number} age");
    // f.VerifyQuickInfoAt(undefined, "1n", "(property) name: string", "@-rule");
    // f.VerifyQuickInfoAt(undefined, "2n", "(property) name: string", "some comment");
    // f.VerifyQuickInfoAt(undefined, "3n", "(property) name: string", "@*stars");
    // f.VerifyQuickInfoAt(undefined, "4n", "(property) name: string", "@(parens)");
    // f.VerifyQuickInfoAt(undefined, "5n", "(property) name: string", "");
    // f.VerifyQuickInfoAt(undefined, "1a", "(property) age: number", "");
    // f.VerifyQuickInfoAt(undefined, "2a", "(property) age: number", "");
    // f.VerifyQuickInfoAt(undefined, "3a", "(property) age: number", "");
    // f.VerifyQuickInfoAt(undefined, "4a", "(property) age: number", "");
    // f.VerifyQuickInfoAt(undefined, "5a", "(property) age: number", "");
}

test "TestQuickinfoVerbosityNamespaceAnonymousClassHeritage1" {
    const content =
        \\
        \\namespace NS/*1*/ {
        \\    export class Derived extends class {
        \\        baseField: string;
        \\    } {
        \\        derivedField: number;
        \\    }
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{0, 1}});
}

test "TestFindAllRefsConst" {
    const content =
        \\// @Filename: a.ts
        \\/**/const const
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestInlayHintsElementAccess" {
    const content =
        \\interface MySymbol {
        \\    readonly "my dispose": unique symbol
        \\}
        \\
        \\declare var mySymbol: MySymbol;
        \\
        \\let foo = {
        \\    [mySymbol["my dispose"]]: () => {}
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{
//         .IncludeInlayVariableTypeHints = core.TSTrue,
//     }});
}

test "TestFindAllRefsTripleSlashRef1" {
    const content =
        \\// @Filename: /node_modules/@types/react/index.d.ts
        \\export type JSX = {};
        \\
        \\// @Filename: /node_modules/excalidraw/index.d.ts
        \\/// <reference types="react" />
        \\
        \\// @Filename: /index.ts
        \\import type {JSX} from '/*m*/react';
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "m");
}

test "TestHoverNilBaseSymbolIntersection" {
    const content =
        \\
        \\// @strict: true
        \\// @filename: main.ts
        \\
        \\class Base {}
        \\
        \\declare const BaseFactory: new() => Base & { c: string };
        \\
        \\class Derived extends BaseFactory {
        \\  static /*1*/idField = "id" as const;
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestAutoImportPackageJsonImportsHashSlashNodenext" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "nodenext",
        \\    "rootDir": "./",
        \\    "outDir": "build"
        \\  }
        \\}
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#/*": {
        \\      "types": "./src/*",
        \\      "default": "./src/*"
        \\    }
        \\  }
        \\}
        \\// @Filename: /src/domain/entities/entity.ts
        \\export const entity = 1;
        \\// @Filename: /src/features/deep/consumer.ts
        \\entit/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
}

test "TestQuickInfoConstAssertion" {
    const content =
        \\const foo = 42 as /*1*/const
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "type const = 42", "");
}

test "TestDiagnosticsDefaultImportMergedWithJSDocTypeAlias1" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /lib/types.d.ts
        \\export interface RunnerOptions {
        \\  dryRun?: boolean;
        \\}
        \\
        \\// @Filename: /lib/runner.js
        \\"use strict";
        \\
        \\/**
        \\ * @typedef {import('./types.d.ts').RunnerOptions} RunnerOptions
        \\ */
        \\
        \\var EventEmitter = require("node:events").EventEmitter;
        \\
        \\class Runner extends EventEmitter {
        \\  constructor() { super(); }
        \\}
        \\
        \\module.exports = Runner;
        \\
        \\// @Filename: /lib/stats-collector.mjs
        \\/** @typedef {import('./runner.js')} Runner */
        \\
        \\import Runner from "./runner.js";
        \\
        \\const createStatsCollector = (runner) => runner && Runner;
        \\
        \\export { createStatsCollector };
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/lib/stats-collector.mjs");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 2);
}

test "TestQuickInfoGenericTypePath" {
    const content =
        \\
        \\function f<T>(x: T) {
        \\  class C {
        \\    value = x
        \\  }
        \\  return new C()
        \\}
        \\
        \\class Box<T> {
        \\  public value: T;
        \\  constructor(value: T) {
        \\    this.value = value;
        \\  }
        \\}
        \\
        \\const instance = f/*callF*/("hello");
        \\const b1/*b1*/ = new Box/*newBox*/(instance);
        \\declare const b2/*b2*/: Box<typeof instance>;
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestHoverAliasInImportedFile" {
    const content =
        \\
        \\// @filename: other2.ts
        \\export type SomeAliasType<T> = { value: T };
        \\
        \\// @filename: other.ts
        \\import { SomeAliasType } from './other2';
        \\
        \\declare function isSomeAliasType(x: any): x is SomeAliasType<any>;
        \\
        \\export { isSomeAliasType };
        \\
        \\// @filename: main.ts
        \\import { isSomeAliasType } from './other';
        \\
        \\export function processValue(value: any) {
        \\  if (/*1*/isSomeAliasType(value)) {
        \\    console.log("ok");
        \\  }
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(alias) function isSomeAliasType(x: any): x is SomeAliasType<any>", "");
}

test "TestQuickinfoVerbosityNamespaceMergedInterfaceHeritage" {
    const content =
        \\
        \\declare namespace NS/*1*/ {
        \\    interface Config extends A {
        \\        a: string;
        \\    }
        \\
        \\    interface Config extends B {
        \\        b: number;
        \\    }
        \\
        \\    interface A {
        \\        a: string;
        \\    }
        \\
        \\    interface B {
        \\        b: number;
        \\    }
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{0, 1}});
}

test "TestAutoImportErrorMixedExportKinds" {
    const content =
        \\// @Filename: a.ts
        \\export function foo(): number {
        \\    return 10
        \\}
        \\
        \\const bar = 20;
        \\export { bar as foo };
        \\
        \\// @Filename: b.ts
        \\foo/**/
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
}

test "TestQuickInfoJsxNamespacedIntrinsic" {
    const content =
        \\// @jsx: react
        \\// @Filename: /a.tsx
        \\declare const React: any;
        \\declare namespace JSX {
        \\    interface Element {}
        \\    interface IntrinsicElements {
        \\        /** Element docs */
        \\        "foo:bar": {
        \\            /** Foo docs */
        \\            foo: boolean
        \\            /** Bar docs */
        \\            bar: string
        \\        }
        \\    }
        \\}
        \\<foo:ba/*tag*/r fo/*attr*/o />
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "tag", "(property) JSX.IntrinsicElements[\"foo:bar\"]: {\n    foo: boolean;\n    bar: string;\n}", "Element docs");
    // f.VerifyQuickInfoAt(undefined, "attr", "(property) foo: boolean", "Foo docs");
}

test "TestCompletionAfterExtendsL10nInJs" {
    const content =
        \\
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /interfaces.d.ts
        \\export interface IL10n {}
        \\
        \\// @Filename: /genericl10n.js
        \\/** @typedef {import("./interfaces").IL10n} IL10n */
        \\
        \\class L10n {
        \\    constructor(options) {
        \\        this.options = options;
        \\    }
        \\}
        \\
        \\/**
        \\ * @implements {IL10n}
        \\ */
        \\class GenericL10n extends L10n/*1*/ {
        \\    constructor(lang) {
        \\        super({ lang });
        \\    }
        \\}
        \\
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.GetCompletions(undefined, null );
}

test "TestGoToSourcePropertyAccessNoDeclaration" {
    const content =
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/package.json
        \\{ "name": "pkg", "main": "./index.js", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.d.ts
        \\type Keys = "alpha" | "beta";
        \\export declare const config: { [K in Keys]: string };
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.js
        \\export const config = { /*targetAlpha*/alpha: "a", /*targetBeta*/beta: "b" };
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { config } from "pkg";
        \\config./*accessAlpha*/alpha;
        \\config./*accessBeta*/beta;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "accessAlpha", "accessBeta");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "accessValue");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "accessX", "accessY");
}

test "TestSignatureHelpTokenCrash2" {
    const content =
        \\
        \\function foo<T, U>(x: string, y: T, z: U) {
        \\
        \\}
        \\
        \\foo<number,number>/*1*/("hello", 123,456)
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifySignatureHelpWithCases(undefined, &.{
//         .MarkerInput = "1",
//         .Expected =    null,
//         .Context = &.{
//             .IsRetrigger =      false,
//             .TriggerCharacter = undefined("("),
//             .TriggerKind =      lsproto.SignatureHelpTriggerKindTriggerCharacter,
//         },
//     });
}

test "TestBasicMultifileCompletions" {
    const content =
        \\// @Filename: /a.ts
        \\export const foo = { bar: 'baz' };
        \\
        \\// @Filename: /b.ts
        \\import { foo } from './a';
        \\const test = foo./*1*/
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
//                     .Label =    "bar",
//                     .Kind =     undefined(lsproto.CompletionItemKindField),
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//             },
//         },
//     });
}

test "TestGoToImplementationReexportedTypeOnlyNamespace3" {
    const content =
        \\
        \\// @Filename: /node_modules/@typescript-eslint/types/index.d.ts
        \\export * as TSESTree from './generated/ast-spec';
        \\export type * as TSESTree from './generated/ast-spec';
        \\
        \\// @Filename: /node_modules/@typescript-eslint/types/generated/ast-spec.d.ts
        \\export interface BaseNode {}
        \\
        \\// @Filename: /node_modules/@typescript-eslint/utils/index.d.ts
        \\export { TSESTree } from '@typescript-eslint/types';
        \\
        \\// @Filename: /src/check-license.ts
        \\import type {TSE/*impl*/STree} from '@typescript-eslint/utils';
        \\
        \\let node: TSESTree.Node | undefined;
        \\export default node;
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "impl");
}

test "TestCompletionImportAttributes" {
    const content =
        \\
        \\// @target: esnext
        \\// @module: esnext
        \\// @filename: main.ts
        \\import yadda1 from "yadda" with {/*attr*/}
        \\import yadda2 from "yadda" with {attr/*attrEnd1*/: true}
        \\import yadda3 from "yadda" with {attr: /*attrValue*/}
        \\
        \\// @filename: yadda
        \\export default {};
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GoToEachMarker(undefined, null, func(marker *fourslash.Marker, index int) .{
//         f.VerifyCompletions(undefined, marker, null)
//     });
}

test "TestDocumentHighlightNestedRequireDestructureNoCrash1" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /bar.js
        \\const { a: { b } } = require('./foo');
        \\/**/b;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , "");
}

test "TestInlayHintsUsing" {
    const content =
        \\// @target: esnext
        \\using _defer = {
        \\    [Symbol.dispose]() {},
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{
//         .IncludeInlayVariableTypeHints = core.TSTrue,
//     }});
}

test "TestOrganizeImports_dtsUnusedImportWithAugmentation" {
    const content =
        \\// @Filename: /styled-patch.d.ts
        \\import * as styledComponents from 'styled-components';
        \\
        \\declare module 'styled-components' {
        \\    interface ThemedStyledComponentsModule {
        \\        keyframes(): Keyframes;
        \\    }
        \\}
        \\// @Filename: /node_modules/styled-components/index.d.ts
        \\export interface Keyframes {}
        \\export interface ThemedStyledComponentsModule {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(
//         undefined,
//         "import 'styled-components';\n\ndeclare module 'styled-components' {\n    interface ThemedStyledComponentsModule {\n        keyframes(): Keyframes;\n    }\n}",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestInlayHintsIdentifierLocation" {
    const content =
        \\interface Foo {}
        \\const p = (a: Foo[]) => a;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayVariableTypeHints = core.TSTrue}});
}

test "TestQuickinfoVerbosityInterfaceMemberOrdering" {
    const content =
        \\
        \\interface Callable/*1*/ {
        \\    (x: string): boolean;
        \\    new (x: string): Callable;
        \\    [key: string]: any;
        \\    name: string;
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{0, 1}});
}

test "TestCompletionAfterCallExpression" {
    const content =
        \\let x = someCall() /**/
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
//                 "satisfies",
//                 "as",
//             },
//         },
//     });
}

test "TestCompletionListAlreadyImportedNamespaceExportAlias" {
    const content =
        \\// @module: node18
        \\// @Filename: /values.ts
        \\export const A = 1;
        \\export const B = 2;
        \\
        \\// @Filename: /namespace.ts
        \\import * as Group from "./values.js";
        \\type Group = (typeof Group)[keyof typeof Group];
        \\export { Group };
        \\
        \\// @Filename: /index.ts
        \\import { Group } from "./namespace.js";
        \\
        \\console.log(Grou/**/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "", &.{
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{.Label = "Group"},
//             },
//         },
//     });
}

test "TestDocumentHighlightTypeofThis" {
    const content =
        \\
        \\// @Filename: /a.ts
        \\interface Foo {
        \\  bar(): typeof [|this|];
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , f.Ranges()[0]);
}

test "TestCompletionsInJsxTag" {
    const content =
        \\// @jsx: preserve
        \\// @Filename: /a.tsx
        \\declare namespace JSX {
        \\    interface Element {}
        \\    interface IntrinsicElements {
        \\        div: {
        \\            /** Doc */
        \\            foo: string
        \\            /** Label docs */
        \\            "aria-label": string
        \\        }
        \\    }
        \\}
        \\class Foo {
        \\    render() {
        \\        <div /*1*/ ></div>;
        \\        <div  /*2*/ />
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "2"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "aria-label",
//                     .Kind =   undefined(lsproto.CompletionItemKindField),
//                     .Detail = undefined("(property) \"aria-label\": string"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "Label docs",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "foo",
//                     .Kind =   undefined(lsproto.CompletionItemKindField),
//                     .Detail = undefined("(property) foo: string"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "Doc",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"1", "2"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "bar",
//                     .Kind =   undefined(lsproto.CompletionItemKindField),
//                     .Detail = undefined("(property) bar: string"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "Bar docs",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "foo",
//                     .Kind =   undefined(lsproto.CompletionItemKindField),
//                     .Detail = undefined("(property) foo: boolean"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "Foo docs",
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestCompletionsFromUntitledFile" {
    const content =
        \\// @filename: /home/src/project/utils.ts
        \\export function helper() {}
        \\
        \\// @filename: ^/untitled/ts-nul-authority/Untitled-1.ts
        \\/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//         },
//         .Items = &.{
//             // We don'undefined care about the exact completions, just that it doesn'undefined crash
//             .Includes = null,
//         },
//     });
}

test "TestCodeFixMissingTypeAnnotationOnExports_arrowParensParamOnly" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\export const func = /*a*/x/*b*/ => 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "a");
    _ = f.VerifyCodeFix(undefined, .{
        .Description =    "Add annotation of type 'any'",
        .NewFileContent = "export const func = (x: any) => 0;",
        .ApplyChanges =   true,
    });
}

test "TestImportHelpersAfterScriptBecomesDecoratedModule" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "target": "es2015",
        \\        "module": "commonjs",
        \\        "experimentalDecorators": true,
        \\        "importHelpers": true
        \\    },
        \\    "files": ["foo.ts"]
        \\}
        \\
        \\// @Filename: /foo.ts
        \\declare function dec(value: Function): void;
        \\/*insert*/class C {}
        \\
        \\// @Filename: /node_modules/tslib/package.json
        \\{ "name": "tslib", "typings": "tslib.d.ts" }
        \\
        \\// @Filename: /node_modules/tslib/tslib.d.ts
        \\export declare function __decorate(...args: any[]): any;
        \\
        \\// @Filename: /node_modules/tslib/tslib.js
        \\exports.__decorate = function () {};
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/foo.ts");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 0);
    // f.Replace(undefined, f.MarkerByName(undefined, "insert").Position, 0, "@dec\nexport ");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 0);
}

test "TestCodeLensFunctionExpressions01" {
    const content =
        \\
        \\// @filename: anonymousFunctionExpressions.ts
        \\export let anonFn1 = function () {};
        \\export const anonFn2 = function () {};
        \\
        \\let anonFn3 = function () {};
        \\const anonFn4 = function () {};
        \\
        \\// @filename: arrowFunctions.ts
        \\export let arrowFn1 = () => {};
        \\export const arrowFn2 = () => {};
        \\
        \\let arrowFn3 = () => {};
        \\const arrowFn4 = () => {};
        \\
        \\// @filename: namedFunctions.ts
        \\export let namedFn1 = function namedFn1() {
        \\    namedFn1();
        \\}
        \\namedFn1();
        \\
        \\export const namedFn2 = function namedFn2() {
        \\    namedFn2();
        \\}
        \\namedFn2();
        \\
        \\let namedFn3 = function namedFn3() {};
        \\const namedFn4 = function namedFn4() {};
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

test "TestGoToImplementationNoCrashMultiSourceDts" {
    const content =
        \\
        \\// @Filename: /a.ts
        \\export {};
        \\// @Filename: /b.ts
        \\export {};
        \\// @Filename: /combined.d.ts
        \\export declare class Bar {
        \\    method(): void;
        \\}
        \\//# sourceMappingURL=combined.d.ts.map
        \\// @Filename: /combined.d.ts.map
        \\{"version":3,"file":"combined.d.ts","sourceRoot":"","sources":["a.ts","b.ts"],"names":[],"mappings":";IAAA,OCAA;AAAA"}
        \\// @Filename: /user.ts
        \\import { Bar } from './combined';
        \\declare const bar: Bar;
        \\bar./*impl*/method();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "impl");
}

test "TestGetEditsForFileRenameWithSolutionConfigFile" {
    const content =
        \\
        \\// @Filename: /tsconfig.json
        \\{
        \\  "files": [],
        \\  "references": [
        \\    { "path": "./src/tsconfig.json" }
        \\  ]
        \\}
        \\
        \\// @Filename: /src/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "composite": true
        \\  },
        \\  "files": ["./a.ts", "./b.ts"]
        \\}
        \\
        \\// @Filename: /src/a.ts
        \\import { b } from "./b";
        \\b;
        \\
        \\// @Filename: /src/b.ts
        \\export const b = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyWillRenameFilesEdits(undefined, "/src/b.ts", "/src/c.ts", .{
//         .@"/src/a.ts" = "import { b } from \"./c\";\nb;\n",
//     }, null );
}

test "TestCompletionResolveKeyword" {
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
//             .Includes = &.{
//                 &.{
//                     .Label =    "abstract",
//                     .Kind =     undefined(lsproto.CompletionItemKindKeyword),
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                     .Detail =   undefined("abstract"),
//                 },
//             },
//         },
//     });
}

test "TestGoToSourceNodeModulesWithTypes" {
    const content =
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
    // f.VerifyBaselineGoToSourceDefinition(undefined, "start");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "identifier", "moduleSpecifier");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "usage");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importName", "callSite");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "usage");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "usage");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "valueUsage");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "refPath");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importName");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importName");
}

test "TestAllowRenameOfImportPath" {
    const content =
        \\// @Filename: /a.ts
        \\export const x = 0;
        \\// @Filename: /dir/index.ts
        \\export const x = 0;
        \\// @Filename: /b.ts
        \\import * as a from "./[|a|]";
        \\import * as dir from "./[|dir|]";
        \\import * as dir2 from "./dir/[|index|]";
        \\// @Filename: /c.js
        \\const a = require("./[|a|]");
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.Configure(undefined, prefsTrue);
    // f.GoToEachMarker(undefined, markers, func(marker *fourslash.Marker, index int) .{
//         f.VerifyRenameSucceeded(undefined, &prefsTrue)
//     });
    // f.Configure(undefined, prefsFalse);
    // f.GoToEachMarker(undefined, markers, func(marker *fourslash.Marker, index int) .{
//         f.VerifyRenameFailed(undefined, &prefsFalse)
//     });
}

test "TestCompletionInJSDocPropertyWithLinkNoCrash1" {
    const content =
        \\
        \\// @allowJs: true
        \\// @filename: /file.js
        \\export function foo() {}
        \\
        \\/**
        \\ * @typedef MyType
        \\ * @property {number} [timeout] - The /*1*/timeout; defaults to {@linkcode DEFAULT}
        \\ */
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

test "TestQuickCatchInfo" {
    const content =
        \\try {} catch(/*1*/error) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var error: unknown", "");
}

test "TestCompletionListDefaultTypeArgumentPositionTypeOnly" {
    const content =
        \\// @lib: es5
        \\const foo = "foo";
        \\function test1<T = /*1*/>() {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalTypes,
//         },
//     });
}

test "TestSignatureHelpTokenCrash" {
    const content =
        \\
        \\function foo(a: any, b: any) {
        \\
        \\}
        \\
        \\foo((/*1*/
        \\
        \\/** This is a JSDoc comment */
        \\foo/** More comments*/((/*2*/
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifySignatureHelpWithCases(undefined, &.{
//         .MarkerInput = "1",
//         .Expected =    null,
//         .Context = &.{
//             .IsRetrigger =      false,
//             .TriggerCharacter = undefined("("),
//             .TriggerKind =      lsproto.SignatureHelpTriggerKindTriggerCharacter,
//         },
//     });
    // f.VerifySignatureHelpWithCases(undefined, &.{
//         .MarkerInput = "2",
//         .Expected =    null,
//         .Context = &.{
//             .IsRetrigger =      false,
//             .TriggerCharacter = undefined("("),
//             .TriggerKind =      lsproto.SignatureHelpTriggerKindTriggerCharacter,
//         },
//     });
}

test "TestQuickinfoVerbosityClassWithMixinBase" {
    const content =
        \\
        \\class Base {}
        \\
        \\declare const Mixin: new () => Base & { mixed: string };
        \\
        \\class Derived/*1*/ extends Mixin {}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{0, 1}});
}

test "TestAutoImportNewLine" {
    const content =
        \\// @Filename: /a.ts
        \\export function readFileSync() {}
        \\
        \\// @Filename: /b.ts
        \\import {} from "./other1";
        \\import {} from "./other2";
        \\
        \\
        \\readFileSync/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
}

test "TestPreferTypeOnlyAutoImports" {
    const content =
        \\// @Filename: types.ts
        \\export type MyType = { x: number };
        \\export const MyValue = 123;
        \\// @Filename: main.ts
        \\let x: MyT/*type*/;
        \\let y = MyV/*value*/;
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.Configure(undefined, .{
//         .IncludeCompletionsForModuleExports =    core.TSTrue,
//         .IncludeCompletionsForImportStatements = core.TSTrue,
//         .PreferTypeOnlyAutoImports =             core.TSTrue,
//     });
    // f.BaselineAutoImportsCompletions(undefined, &.{"type", "value"});
}

test "TestDocumentHighlightsExportEqualsInMergedNamespace" {
    const content =
        \\
        \\class C {}
        \\namespace C {
        \\    /*marker*/export = C;
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , "marker");
}

test "TestCompletionsInJsxTagDifferentSpreadElementTypes" {
    const content =
        \\
        \\// @Filename: /completionsWithDifferentSpreadTypes.tsx
        \\// @strict: true
        \\
        \\// A reasonable type to spread.
        \\export function ComponentObjectX(props: { x: string }) {
        \\    return <SomeComponent {...props} /*objectX*//>;
        \\}
        \\
        \\// A questionable but valid type to spread.
        \\export function ComponentObjectXOrY(props: { x: string } | { y: string }) {
        \\    return <SomeComponent {...props} /*objectXOrY*//>;
        \\}
        \\
        \\// A very unexpected type to spread (a union containing a primitive).
        \\export function ComponentNumberOrObjectX(props: number | { x: string }) {
        \\    return <SomeComponent {...props} /*numberOrObjectX*//>;
        \\}
        \\
        \\// Very unexpected, but still structured (union) types.
        \\// 'boolean' is 'true | false' and an optional 'null' is really 'null | undefined'.
        \\export function ComponentBoolean(props: boolean) {
        \\    return <SomeComponent {...props} /*boolean*//>;
        \\}
        \\export function ComponentOptionalNull(props?: null) {
        \\    return <SomeComponent {...props} /*optNull*//>;
        \\}
        \\
        \\// Primitive types (non-structured).
        \\export function ComponentAny(props: any) {
        \\    return <SomeComponent {...props} /*any*//>;
        \\}
        \\export function ComponentUnknown(props: unknown) {
        \\    return <SomeComponent {...props} /*unknown*//>;
        \\}
        \\export function ComponentNever(props: never) {
        \\    return <SomeComponent {...props} /*never*//>;
        \\}
        \\export function ComponentUndefined(props: undefined) {
        \\    return <SomeComponent {...props} /*undefined*//>;
        \\}
        \\export function ComponentNumber(props: number) {
        \\    return <SomeComponent {...props} /*number*//>;
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GoToEachMarker(undefined, null, func(marker *fourslash.Marker, index int) .{
//         f.VerifyCompletions(undefined, marker, null)
//     });
}

test "TestAutoImportCJSWithNodeModuleKind" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "allowJs": true,
        \\    "module": "node20",
        \\    "checkJs": true,
        \\    "noEmit": true
        \\  }
        \\}
        \\// @Filename: /package.json
        \\{ "type": "commonjs" }
        \\// @Filename: /lib.js
        \\module.exports = { LIB_VERSION: 1 };
        \\// @Filename: /main.js
        \\module.exports.foo = 0;
        \\LIB_VERSION/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "const { LIB_VERSION } = require(\"./lib\");\n\nmodule.exports.foo = 0;\nLIB_VERSION",
    }, null );
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "const { LIB_VERSION } = require(\"./lib\");\n\nLIB_VERSION",
    }, null );
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "const path = require(\"path\");\nconst { LIB_VERSION } = require(\"./lib\");\nLIB_VERSION",
    }, null );
}

test "TestBasicInterfaceMembers" {
    const content =
        \\export {};
        \\interface Point {
        \\    x: number;
        \\    y: number;
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
//             .Exact = &.{
//                 &.{
//                     .Label =    "x",
//                     .Kind =     undefined(lsproto.CompletionItemKindField),
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//                 "y",
//             },
//         },
//     });
}

test "TestCodeLensReferencesShowOnAllClassMethods" {
    const content =
        \\
        \\export abstract class ABC {
        \\  abstract methodA(): void;
        \\  methodB(): void {}
        \\  #methodC(): void {}
        \\  protected methodD(): void {}
        \\  private methodE(): void {}
        \\  protected abstract methodG(): void;
        \\  public methodH(): void {}
        \\
        \\  static methodStaticA(): void {}
        \\  protected static methodStaticB(): void {}
        \\  private static methodStaticC(): void {}
        \\  static #methodStaticD(): void {}
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineCodeLens(undefined, &.{
//                 .CodeLens = .{
//                     .ImplementationsCodeLensEnabled =               core.TSTrue,
//                     .ImplementationsCodeLensShowOnAllClassMethods = value,
//                 },
//             });
}

test "TestFindAllRefsForDefaultExportVS" {
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
    // f.VerifyBaselineVSFindAllReferences(undefined, "def", "deg");
}

test "TestHoverCallSignatureDocumentation" {
    const content =
        \\
        \\type X = {
        \\    /** Description of invoking. */
        \\    (): string
        \\
        \\    /** Description of constructor. */
        \\    new (): number
        \\}
        \\
        \\declare const x: X
        \\
        \\/*1*/x()
        \\new /*2*/x()
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "const x: () => string", "Description of invoking.");
    // f.VerifyQuickInfoAt(undefined, "2", "const x: new () => number", "Description of constructor.");
}

test "TestDeclarationMapsOpeningOriginalLocationProject" {
    const content =
        \\
        \\// @Filename: /src/index.ts
        \\export function a() {}
        \\export function b() {}
        \\// @Filename: /src/indexdef.d.ts.map
        \\{
        \\    "version": 3,
        \\    "file": "indexdef.d.ts",
        \\    "sourceRoot": "",
        \\    "sources": ["index.ts"],
        \\    "names": [],
        \\    "mappings": "AACA,wBAAgB,CADhB;AAAA,wBAAgB"
        \\}
        \\// @Filename: /src/indexdef.d.ts
        \\export declare function b(): void;
        \\export declare function a(): void;
        \\//# sourceMappingURL=indexdef.d.ts.map
        \\// @Filename: /src/user.ts
        \\import { a, b } from "./indexdef";
        \\/*1*/a();
        \\/*2*/b();
        \\// @Filename: /src/tsconfig.json
        \\{}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1", "2");
}

test "TestRenameBuiltinTypes" {
    const content =
        \\
        \\const arr: /*1*/Array<number> = [];
        \\const map1: /*2*/Map<string, number> = new Map();
        \\const prom: /*3*/Promise<void> = Promise.resolve();
        \\const str: /*4*/string = "hello";
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GoToMarker(undefined, marker);
    // f.VerifyRenameFailed(undefined, null );
}

test "TestRenameImportSpecifierNoResourceOperations" {
    const content =
        \\
        \\// @Filename: /a.ts
        \\export const x = 0;
        \\// @Filename: /b.ts
        \\import * as a from ".//*rename*/a";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "rename");
    // f.VerifyRenameFailed(undefined, null );
}

test "TestQuickInfoDefaultTypeParameter1" {
    const content =
        \\type /*1*/X</*2*/T = string> = T
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "type X<T = string> = T", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(type parameter) T in type X<T = string>", "");
}

test "TestFindAllRefsJSDocNamespacedTypedef" {
    const content =
        \\
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /index.js
        \\// Namespaced typedef
        \\/** @typedef {string} [|NS|].[|T|] */
        \\
        \\// Namespaced typedef aliased to qualified namespaced typedef.
        \\/** @typedef {NS.T} NS.[|U|] */
        \\
        \\// Namespaced typedef aliased to implicitly-resolved typedef.
        \\/** @typedef {U} NS.[|V|] */
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined);
}

test "TestCodeLensReferencesShowOnInterfaceMethods" {
    const content =
        \\
        \\export interface I {
        \\  methodA(): void;
        \\}
        \\export interface I {
        \\  methodB(): void;
        \\}
        \\
        \\interface J extends I {
        \\  methodB(): void;
        \\  methodC(): void;
        \\}
        \\
        \\class C implements J {
        \\  methodA(): void {}
        \\  methodB(): void {}
        \\  methodC(): void {}
        \\}
        \\
        \\class AbstractC implements J {
        \\  abstract methodA(): void;
        \\  methodB(): void {}
        \\  abstract methodC(): void;
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineCodeLens(undefined, &.{
//                 .CodeLens = .{
//                     .ImplementationsCodeLensEnabled =                core.TSTrue,
//                     .ImplementationsCodeLensShowOnInterfaceMethods = value,
//                 },
//             });
}

test "TestCallHierarchyIncomingCallsNoCrashArrayPush" {
    const content =
        \\function splitNames(name: string) {
        \\  return (name || "").split(",").filter(Boolean);
        \\}
        \\
        \\async function trim(packageNames: string[]) {
        \\  const nameOrPkgs = packageNames.filter(Boolean);
        \\  const names = [];
        \\  for (const nameOrPkg of nameOrPkgs) {
        \\    try {
        \\      names./*push*/push(nameOrPkg);
        \\    } catch (error) {
        \\    }
        \\  }
        \\  return names;
        \\}
        \\    
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "push");
    // f.VerifyBaselineCallHierarchy(undefined);
}

test "TestCodeLensAcrossProjects" {
    const content =
        \\
        \\// @filename: ./a/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "composite": true,
        \\    "declaration": true,
        \\    "declarationMaps": true,
        \\    "outDir": "./dist",
        \\    "rootDir": "src"
        \\  },
        \\  "include": ["./src"]
        \\}
        \\
        \\// @filename: ./a/src/foo.ts
        \\export function aaa() {}
        \\aaa();
        \\
        \\// @filename: ./b/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "composite": true,
        \\    "declaration": true,
        \\    "declarationMaps": true,
        \\    "outDir": "./dist",
        \\    "rootDir": "src"
        \\  },
        \\  "references": [{ "path": "../a" }],
        \\  "include": ["./src"]
        \\}
        \\
        \\// @filename: ./b/src/bar.ts
        \\import * as foo from '../../a/dist/foo.js';
        \\foo.aaa();
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineCodeLens(undefined, &.{
//         .CodeLens = .{
//             .ReferencesCodeLensEnabled = core.TSTrue,
//         },
//     });
}

test "TestQuickinfoVerbosityNamespaceDefaultExport" {
    const content =
        \\
        \\declare namespace ns/*1*/ {
        \\    interface Shape {
        \\        sides: number;
        \\    }
        \\    const circle: Shape;
        \\    export default circle;
        \\    export { Shape };
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{0, 1}});
}

test "TestWorkspaceSymbolMultiProjectNonExistentRef" {
    const content =
        \\
        \\// @Filename: /home/src/projects/project-a/tsconfig.json
        \\{
        \\  "compilerOptions": { "composite": true },
        \\  "references": [{ "path": "../project-nonexistent" }]
        \\}
        \\
        \\// @Filename: /home/src/projects/project-a/index.ts
        \\export const [|myValueA|]: number = 1;
        \\
        \\// @Filename: /home/src/projects/project-b/tsconfig.json
        \\{
        \\  "compilerOptions": { "composite": true },
        \\  "references": [{ "path": "../project-a" }]
        \\}
        \\
        \\// @Filename: /home/src/projects/project-b/index.ts
        \\export const [|myValueB|]: string = "hello";
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyWorkspaceSymbol(undefined, []*.{
//         .{
//             .Pattern = "myValue",
//             .Includes = undefined([]*.{
//                 .{
//                     .Name =     "myValueA",
//                     .Kind =     lsproto.SymbolKindVariable,
//                     .Location = f.Ranges()[0].LSLocation(),
//                 },
//                 .{
//                     .Name =     "myValueB",
//                     .Kind =     lsproto.SymbolKindVariable,
//                     .Location = f.Ranges()[1].LSLocation(),
//                 },
//             }),
//         },
//     });
}

test "TestAutoImportSymlinkedMonorepoReexport" {
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
        \\  "main": "dist/index.js",
        \\  "types": "dist/index.d.ts"
        \\}
        \\// @Filename: /packages/project-b/src/utils/foo.ts
        \\export function projectBFunction(): string { return "hello"; }
        \\// @Filename: /packages/project-b/src/index.ts
        \\export * from './utils/foo';
        \\export const projectBValue: number = 42;
        \\// @Filename: /packages/project-b/dist/utils/foo.d.ts
        \\export declare function projectBFunction(): string;
        \\// @Filename: /packages/project-b/dist/index.d.ts
        \\export * from './utils/foo';
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
        \\projectBFunction/**/
        \\// @link: /packages/project-b -> /packages/project-a/node_modules/project-b
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.Configure(undefined, prefs);
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { projectBFunction, projectBValue } from \"project-b\";\nconsole.log(projectBValue);\nprojectBFunction",
        "import { projectBValue } from \"project-b\";\nimport { projectBFunction } from \"project-b/src/utils/foo\";\nconsole.log(projectBValue);\nprojectBFunction",
    }, null );
}

test "TestDestructuredInterfaceJSDoc" {
    const content =
        \\
        \\interface FooBar {
        \\    /** foo comment */
        \\    foo: number;
        \\    /** bar comment */
        \\    bar: string;
        \\    /** baz comment */
        \\    baz: string;
        \\}
        \\
        \\declare const fubar: FooBar;
        \\
        \\const {/*1*/foo, /*2*/bar, /*3*/baz: /*4*/biz} = fubar;
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
    _ = f.VerifyBaselineHover(undefined);
    _ = f.VerifyBaselineHover(undefined);
}

test "TestSignatureHelpNestedCallTrailingComma" {
    const content =
        \\declare function outer<T>(range: T): T;
        \\declare function inner(a: any): any;
        \\
        \\outer(inner/*1*/(undefined,),);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifySignatureHelpPresent(undefined, &.{
//         .IsRetrigger = false,
//         .TriggerKind = lsproto.SignatureHelpTriggerKindInvoked,
//     });
}

test "TestRenameUnresolvedReexport1" {
    const content =
        \\// @Filename: /a.ts
        \\export { [|jsonSchema|] } from "@internal/ai-sdk-v4";
        \\// @Filename: /b.ts
        \\import { jsonSchema } from "./a";
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[0]);
}

test "TestSignatureHelpNestedCalls" {
    const content =
        \\function foo(s: string) { return s; }
        \\function bar(s: string) { return s; }
        \\let s = foo(/*a*/ /*b*/bar/*c*/(/*d*/"hello"/*e*/)/*f*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "a");
    // f.VerifySignatureHelp(undefined, .{.Text = "foo(s: string): string"});
    _ = f.GoToMarker(undefined, "b");
    // f.VerifySignatureHelp(undefined, .{.Text = "foo(s: string): string"});
    _ = f.GoToMarker(undefined, "c");
    // f.VerifySignatureHelp(undefined, .{.Text = "foo(s: string): string"});
    _ = f.GoToMarker(undefined, "d");
    // f.VerifySignatureHelp(undefined, .{.Text = "bar(s: string): string"});
    _ = f.GoToMarker(undefined, "e");
    // f.VerifySignatureHelp(undefined, .{.Text = "bar(s: string): string"});
    _ = f.GoToMarker(undefined, "f");
    // f.VerifySignatureHelp(undefined, .{.Text = "foo(s: string): string"});
    _ = f.GoToMarker(undefined, "a");
    // f.VerifySignatureHelp(undefined, .{.Text = "bar(s: string): string"});
}

test "TestBasicReplaceLine" {
    const content =
        \\export {};
        \\interface Point {
        \\    x: number;
        \\    y: number;
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
    _ = f.ReplaceLine(undefined, 3, "\tz: number;");
    // f.VerifyCompletions(undefined, "a", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//         },
//         .Items = &.{
//             .Excludes = &.{"y"},
//             .Includes = &.{"z"},
//         },
//     });
}

test "TestGoToSourceDefinitionEmptyJsFile" {
    const content =
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/package.json
        \\{ "name": "pkg", "main": "./index.js", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.d.ts
        \\export declare function foo(): void;
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.js
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { foo } from /*specifier*/"pkg";
        \\foo();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "specifier");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importDefault");
}

test "TestSignatureHelpNestedTypeArgumentGTBalance" {
    const content =
        \\declare function f<T, U>(): void;
        \\type A<T> = T;
        \\type B<T> = T;
        \\type C<T> = T;
        \\f<A<B<C<number>>>, /*nested*/;
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "nested");
    // f.VerifySignatureHelp(undefined, .{
//         .Text =           "f<T, U>(): void",
//         .ParameterName =  "U",
//         .ParameterSpan =  "U",
//         .ParameterCount = 2,
//     });
}

test "TestGoToSourceAccessExpressionProperty" {
    const content =
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/package.json
        \\{ "name": "pkg", "main": "./index.js", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.d.ts
        \\export declare const obj: { greet(name: string): string; count: number; };
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.js
        \\export const /*targetObj*/obj = { /*targetGreet*/greet(name) { return name; }, /*targetCount*/count: 42 };
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { obj } from "pkg";
        \\obj./*propAccess*/greet("world");
        \\obj./*propAccess2*/count;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "propAccess", "propAccess2");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "start");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "propAccess");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "propAccess");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "start");
}

test "TestOrganizeImportsWithTraceResolution1" {
    const content =
        \\// @Filename: /project/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "traceResolution": true
        \\  }
        \\}
        \\// @Filename: /project/main.ts
        \\import "./dep.js";
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/project/main.ts");
    // f.VerifyOrganizeImports(
//         undefined,
//         "import \"./dep.js\";\n",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestBasicJSDocCompletions" {
    const content =
        \\
        \\// @filename: file.js
        \\// @allowJs: true
        \\/**
        \\ * @/*1*/
        \\ */
        \\function foo(x) {
        \\  return x + 1;
        \\}
        \\  
        \\/**
        \\ * /*2*/
        \\ */
        \\function bar(x, { y }) {
        \\  return x + y;
        \\}
        \\
        \\/**
        \\ * @param {number} x
        \\ * /*3*/
        \\ */
        \\function baz(x, { y }) {
        \\  return x + y;
        \\}
        \\
        \\/**
        \\ * @param {number} x
        \\ * @param {object} param1 
        \\ * @param {n/*4*/} param1.y 
        \\ */
        \\function baz(x, { y }) {
        \\  return x + y;
        \\}
        \\
        \\/**
        \\ * @/*5*/
        \\ */
        \\function baz(x = 0) {
        \\  return x * 2;
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
//                     .Label =  "link",
//                     .Kind =   undefined(lsproto.CompletionItemKindKeyword),
//                     .Detail = undefined("link"),
//                 },
//                 "param",
//                 "returns",
//                 "param {*} x ",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "@param",
//                 "@param {*} x ",
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
//                 "@param",
//                 "@param {object} param1 \n* @param {*} param1.y ",
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
//                 "number",
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
//                 "param {number} [x=0] ",
//             },
//         },
//     });
}

test "TestCompletionsAtTopLevelImportAssignmentNoCrash1" {
    const content =
        \\// @filename: /a.ts
        \\import x =/*1*/
        \\class Foo {}
        \\// @filename: /b.ts
        \\import x = /*2*/
        \\class Foo {}
        \\// @filename: /c.ts
        \\import x =/*3*/
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "2", "3"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//         },
//         .Items = &.{},
//     });
}

test "TestCallHierarchyAcrossProject" {
    const content =
        \\
        \\// @stateBaseline: true
        \\// @Filename: /projects/temp/temp.ts
        \\/*temp*/let x = 10
        \\// @Filename: /projects/temp/tsconfig.json
        \\{}
        \\// @Filename: /projects/container/lib/tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "composite": true,
        \\    },
        \\    references: [],
        \\    files: [
        \\        "index.ts",
        \\        "bar.ts",
        \\        "baz.ts"
        \\    ],
        \\}
        \\// @Filename: /projects/container/lib/index.ts
        \\export function /*call*/createModelReference() {}
        \\// @Filename: /projects/container/lib/bar.ts
        \\import { createModelReference } from "./index";
        \\function openElementsAtEditor() {
        \\  createModelReference();
        \\}
        \\// @Filename: /projects/container/lib/baz.ts
        \\import { createModelReference } from "./index";
        \\function registerDefaultLanguageCommand() {
        \\  createModelReference();
        \\}
        \\// @Filename: /projects/container/exec/tsconfig.json
        \\{
        \\    "files": ["./index.ts"],
        \\    "references": [
        \\        { "path": "../lib" },
        \\    ],
        \\}
        \\// @Filename: /projects/container/exec/index.ts
        \\import { createModelReference } from "../lib";
        \\function openElementsAtEditor1() {
        \\  createModelReference();
        \\}
        \\// @Filename: /projects/container/compositeExec/tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "composite": true,
        \\    },
        \\    "files": ["./index.ts"],
        \\    "references": [
        \\        { "path": "../lib" },
        \\    ],
        \\}
        \\// @Filename: /projects/container/compositeExec/index.ts
        \\import { createModelReference } from "../lib";
        \\function openElementsAtEditor2() {
        \\  createModelReference();
        \\}
        \\// @Filename: /projects/container/tsconfig.json
        \\{
        \\    "files": [],
        \\    "include": [],
        \\    "references": [
        \\        { "path": "./exec" },
        \\        { "path": "./compositeExec" },
        \\    ],
        \\}
        \\// @Filename: /projects/container/tsconfig.json
        \\{
        \\    "files": [],
        \\    "include": [],
        \\    "references": [
        \\        { "path": "./exec" },
        \\        { "path": "./compositeExec" },
        \\    ],
        \\}
        \\// @Filename: /projects/container/tsconfig.json
        \\{
        \\    "files": [],
        \\    "include": [],
        \\    "references": [
        \\        { "path": "./exec" },
        \\        { "path": "./compositeExec" },
        \\    ],
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "call");
    _ = f.GoToMarker(undefined, "temp");
    _ = f.GoToMarker(undefined, "call");
    // f.VerifyBaselineCallHierarchy(undefined);
    _ = f.CloseFileOfMarker(undefined, "temp");
    _ = f.GoToMarker(undefined, "temp");
    _ = f.CloseFileOfMarker(undefined, "call");
    _ = f.CloseFileOfMarker(undefined, "temp");
    _ = f.GoToMarker(undefined, "temp");
}

test "TestGoToSourceDefaultImportUsageSiteChecker" {
    const content =
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/package.json
        \\{ "name": "pkg", "main": "./index.js", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.d.ts
        \\export default class Widget {
        \\    render(): void;
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.js
        \\export default class /*targetWidget*/Widget {
        \\    /*targetRender*/render() {}
        \\}
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import Widget from "pkg";
        \\const w = new Widget/*constructUsage*/("test");
        \\w./*methodUsage*/render();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "constructUsage", "methodUsage");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "callUsage");
}

test "TestQuickInfoVerbosityNamespaceBindingWithDefaultExportedFunction1" {
    const content =
        \\// @module: esnext
        \\// @filename: /a.ts
        \\export default function fn() {}
        \\export { fn as default };
        \\// @filename: /b.ts
        \\import * as ns from "./a";
        \\
        \\ns/*1*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{0, 1}});
}

test "TestCompletionJSDocNoCrash2" {
    const content =
        \\
        \\// @allowJs: true
        \\// @filename: file.js
        \\/**
        \\ * @param {Object} obj
        \\ * @param {string} obj.first The first property
        \\ * @param {string} obj.second The second property
        \\ * @param {string} obj.third The {@link foo} third property
        \\ */
        \\/*1*/function foo(obj) {}
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

test "TestQuickinfoVerbosityConstEnum" {
    const content =
        \\
        \\const enum Direction/*1*/ {
        \\    Up = "UP",
        \\    Down = "DOWN",
        \\    Left = "LEFT",
        \\    Right = "RIGHT",
        \\}
        \\
        \\enum NumericEnum/*2*/ {
        \\    A,
        \\    B = 10,
        \\    C,
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{
//         .@"1" = .{0, 1},
//         .@"2" = .{0, 1},
//     });
}

test "TestGetEditsForFileRename_cssImport3" {
    const content =
        \\
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
        \\import styles from ".//*rename*/app.css";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyRename(undefined, "rename", "app2.css", .{
//         .@"/a.ts" = "import styles from \"./app2.css\";",
//         .@"/app2.d.css.ts" = "declare const css: {\n  cookieBanner: string;\n};\nexport default css;",
//         .@"/app2.css" = ".cookie-banner {\n  display: none;\n}",
//     });
}

test "TestGoToDefinitionObjectBindingPattern" {
    const content =
        \\
        \\interface SomeType {
        \\    targetProperty: number;
        \\}
        \\
        \\function foo(callback: (p: SomeType) => void) {}
        \\
        \\foo(({ /*1*/targetProperty }) => {
        \\    /*4*/targetProperty
        \\});
        \\
        \\let { /*2*/targetProperty }: SomeType = { /*3*/targetProperty: 42 };
        \\
        \\let { /*5*/targetProperty: /*6*/alias_1 }: SomeType = { targetProperty: 42 };
        \\
        \\let { x: { /*7*/targetProperty: /*8*/{} } }: { x: SomeType } = { x: { targetProperty: 42 } };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, f.MarkerNames());
    // f.VerifyBaselineGoToDefinition(undefined, true, f.MarkerNames());
}

test "TestOrganizeImports_coalesceImports_sortSpecifiersCaseInsensitive" {
    const content =
        \\import { default as M, a as n, B, y, Z as O } from "lib";
        \\M; n; B; y; O;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(
//         undefined,
//         "import { B, default as M, a as n, Z as O, y } from \"lib\";\nM; n; B; y; O;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "import \"lib\";\nvoid 0;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "import { z } from \"aaa\";\nimport * as x from \"lib\";\nimport * as y from \"lib\";\nx; y; z;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "import { default as x, default as y } from \"lib\";\nx; y;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "import { x, y as z } from \"lib\";\nx; z;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "import { z } from \"aaa\";\nimport \"lib\";\nimport * as x from \"lib\";\nx; z;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "import { z } from \"aaa\";\nimport \"lib\";\nimport x from \"lib\";\nx; z;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "import { z } from \"aaa\";\nimport \"lib\";\nimport { x } from \"lib\";\nx; z;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "import y, * as x from \"lib\";\nx; y;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "import { z } from \"aaa\";\nimport * as x from \"lib\";\nimport { y } from \"lib\";\nx; y; z;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "import x, { y } from \"lib\";\nx; y;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "import \"lib\";\nimport * as x from \"lib\";\nimport * as y from \"lib\";\nimport { a, b, default as w, default as z } from \"lib\";\nw; x; y; z; a; b;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "import { w } from \"aaa\";\nimport * as x from \"lib\";\nimport * as y from \"lib\";\nimport z from \"lib\";\nx; y; z; w;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "import type { x, y } from \"lib\";\nimport { z } from \"lib\";\nx; y; z;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "import type * as y from \"lib\";\nimport type z from \"lib\";\nimport type { x } from \"lib\";\nx; y; z;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{.OrganizeImportsSort = lsutil.OrganizeImportsSortOrdinalIgnoreCase},
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "import { a, type b, c, type x, y, type z } from \"lib\";\nz; y; x; c; b; a;",
//         lsproto.CodeActionKindSourceSortImports,
//         &.{
//             .OrganizeImportsSort =      lsutil.OrganizeImportsSortOrdinalIgnoreCase,
//             .OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderInline,
//         },
//     );
}

test "TestAutoCloseTagsWithTriviaAndComplexNames" {
    const content =
        \\// @noLib: true
        \\
        \\// @Filename: /0.tsx
        \\// JSDoc
        \\const x = <
        \\    /** hello world! */
        \\    div /** hello world! */
        \\    >/*0*/
        \\
        \\// @Filename: /1.tsx
        \\// Single-line comments
        \\const x =
        \\    <
        \\    // hello world!
        \\    div // hello world!
        \\    >/*1*/
        \\
        \\// @Filename: /2.tsx
        \\// Namespaced tag
        \\const x =
        \\    <ns:sometag>/*2*/
        \\
        \\// @Filename: /3.tsx
        \\// Namespace with single-line comments
        \\const x = <
        \\    // pre-ns    
        \\    ns
        \\    // pre-colon
        \\    :
        \\    // post-colon
        \\    sometag
        \\    // post-id
        \\    >/*3*/
        \\
        \\// @Filename: /4.tsx
        \\// UppercaseComponent-named tag
        \\const x = <SomeComponent>/*4*/
        \\
        \\// @Filename: /5.tsx
        \\// propertyAccess.Component-named tag
        \\const x = <
        \\    someModule
        \\    .
        \\    SomeComponent
        \\>/*5*/
        \\
        \\// @Filename: /6.tsx
        \\// propertyAccess.Component-named tag with single-line comments
        \\const x =
        \\    <
        \\    // pre-object
        \\    someModule
        \\    // pre-dot
        \\    .
        \\    // post-dot
        \\    SomeComponent
        \\    // post-id
        \\    >/*6*/;
        \\
        \\// @Filename: /7.tsx
        \\// Generic propertyAccess.Component-named tag
        \\const x =
        \\    <
        \\    someModule.SomeComponent<string>
        \\    prop="stringValue"
        \\    >/*7*/;
        \\
        \\// @Filename: /8.tsx
        \\// Namespaced tag with hyphens
        \\const x =
        \\    <my-namespace:my-tag>/*8*/
        \\
        \\// @Filename: /9.tsx
        \\// Generic tag with no attributes
        \\const x = <SomeComponent<number>>/*9*/
        \\
        \\// @Filename: /10.tsx
        \\// Tag name containing $ (must be snippet-escaped)
        \\const x = <$Foo>/*10*/
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineClosingTags(undefined);
}

test "TestGoToTypeWithTupleTypes1" {
    const content =
        \\
        \\export let x/*1*/: [number, number] = [1, 2];
        \\
        \\type DoubleTupleTrouble<T> = [T, T];
        \\
        \\export let y/*2*/: DoubleTupleTrouble<number> = [1, 2];
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToTypeDefinition(undefined, f.MarkerNames());
}

test "TestGoToSourceMergedDeclarationDedup" {
    const content =
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/package.json
        \\{ "name": "pkg", "main": "./index.js", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.d.ts
        \\export declare class /*dtsClass*/Util {
        \\    run(): void;
        \\}
        \\export declare namespace Util {
        \\    export const version: string;
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.js
        \\export class /*targetUtil*/Util {
        \\    run() {}
        \\}
        \\Util.version = "1.0";
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { /*importUtil*/Util } from "pkg";
        \\const u: /*typeRef*/Util = new Util();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importUtil", "typeRef");
}

test "TestOrganizeImports_Shebang_PreserveAndSort" {
    const content =
        \\#!/usr/bin/env node
        \\import Foo from "foo";
        \\import Bar from "bar";
        \\
        \\import Foobar from "foobar";
        \\
        \\console.log(Foo, Bar, Foobar);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(
//         undefined,
//         "#!/usr/bin/env node\nimport Bar from \"bar\";\nimport Foo from \"foo\";\n\nimport Foobar from \"foobar\";\n\nconsole.log(Foo, Bar, Foobar);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestSignatureHelpApplicableRange" {
    const content =
        \\let obj = {
        \\    foo(s: string): string {
        \\        return s;
        \\    }
        \\};
        \\
        \\let s =/*a*/ obj.foo("Hello, world!")/*b*/  
        \\  /*c*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyNoSignatureHelpForMarkers(undefined, "a", "b", "c");
}

test "TestHoverMixinOverrideDocumentation" {
    const content =
        \\
        \\// @strict: true
        \\// @filename: main.ts
        \\
        \\declare class BaseClass {
        \\    /** some documentation */
        \\    static method(): number;
        \\}
        \\
        \\type AnyConstructor = abstract new (...args: any[]) => object
        \\
        \\class MixinClass {}
        \\declare function Mix<T extends AnyConstructor>(BaseClass: T): typeof MixinClass & T;
        \\
        \\declare class Mixed extends Mix(BaseClass) {
        \\    static method(): number;
        \\}
        \\
        \\Mixed./*1*/method;
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(method) Mixed.method(): number", "some documentation");
}

test "TestConstructorFindAllReferences1VS" {
    const content =
        \\export class C {
        \\    /**/public constructor() { }
        \\    public foo() { }
        \\}
        \\
        \\new C().foo();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineVSFindAllReferences(undefined, "");
}

test "TestQuickInfoGenericPropertyAccessor" {
    const content =
        \\
        \\declare const o: {
        \\    f: <T>(x: T) => T
        \\    get g(): <T>(x: T) => T
        \\}
        \\
        \\declare const x: number
        \\
        \\o.f/*1*/(x)
        \\o.g/*2*/(x)
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(property) f: <number>(x: number) => number", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(accessor) g: <number>(x: number) => number", "");
}

test "TestCallHierarchyAnonymousFunctionNoCrash3" {
    const content =
        \\// @Filename: /main.ts
        \\import bar from "./other";
        \\
        \\function foo() {
        \\    /*1*/bar();
        \\}
        \\// @Filename: /other.ts
        \\export default function() {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifyBaselineCallHierarchy(undefined);
}

test "TestQuickInfoJSDocParamWithInvalidTagInComment" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\/**
        \\ * @param {string} x Checks @-rule here
        \\ * @param {string} a see @foo*bar here
        \\ * @param {string} b see @test(something) here
        \\ * @param {string} c see @*not-ident here
        \\ * @param {string} d see @(paren) here
        \\ */
        \\function /*fn*/foo(/**/x, /*a*/a, /*b*/b, /*c*/c, /*d*/d) {}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "fn", "function foo(x: string, a: string, b: string, c: string, d: string): void", "" ++ 
//         "\n\n*@param* `x` — Checks @-rule here\n" ++ 
//         "\n*@param* `a` — see" ++ 
//         "\n\n*@foo* — *bar here\n" ++ 
//         "\n*@param* `b` — see" ++ 
//         "\n\n*@test* — (something) here" ++ 
//         "\n\n*@param* `c` — see @*not-ident here" ++ 
//         "\n\n*@param* `d` — see @(paren) here");
    // f.VerifyQuickInfoAt(undefined, "", "(parameter) x: string", "Checks @-rule here");
    // f.VerifyQuickInfoAt(undefined, "a", "(parameter) a: string", "see");
    // f.VerifyQuickInfoAt(undefined, "b", "(parameter) b: string", "see");
    // f.VerifyQuickInfoAt(undefined, "c", "(parameter) c: string", "see @*not-ident here");
    // f.VerifyQuickInfoAt(undefined, "d", "(parameter) d: string", "see @(paren) here");
}

test "TestGoToSourceNestedNodeModules" {
    const content =
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/outer/package.json
        \\{ "name": "outer", "main": "./index.js", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/outer/index.d.ts
        \\export { inner } from "./node_modules/inner/index";
        \\// @Filename: /home/src/workspaces/project/node_modules/outer/index.js
        \\export { inner } from "./node_modules/inner/index.js";
        \\// @Filename: /home/src/workspaces/project/node_modules/outer/node_modules/inner/package.json
        \\{ "name": "inner", "main": "./index.js", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/outer/node_modules/inner/index.d.ts
        \\export declare function inner(): string;
        \\// @Filename: /home/src/workspaces/project/node_modules/outer/node_modules/inner/index.js
        \\export function /*target*/inner() { return "ok"; }
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { /*importName*/inner } from "outer";
        \\inner/*usage*/();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importName", "usage");
}

test "TestGoToSourceForwardedReExportChain" {
    const content =
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/package.json
        \\{ "name": "pkg", "main": "./index.js", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.d.ts
        \\export declare function helper(): string;
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.js
        \\export { helper } from './impl.js';
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/impl.js
        \\export function /*targetHelper*/helper() { return "ok"; }
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { /*importHelper*/helper } from "pkg";
        \\helper();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importHelper");
}

test "TestGoToImplementationInterfaceObjectLiteral" {
    const content =
        \\
        \\// @Filename: /file1.ts
        \\export interface MyInterface { P: number; }
        \\
        \\// @Filename: /file2.ts
        \\import { MyInterface } from "./file1";
        \\
        \\const x: /*impl*/MyInterface = { P: 2 };
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "impl");
}

test "TestClassMembersAfterConstAssertionInitializer" {
    const content =
        \\
        \\interface A {
        \\    a: number
        \\    def: string
        \\}
        \\
        \\class B implements A {
        \\    a = 1 as const
        \\    /**/
        \\}
        \\
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
//             .Exact = append(&.{
//                 &.{
//                     .Label =    "def",
//                     .Kind =     undefined(lsproto.CompletionItemKindField),
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//             }, CompletionClassElementKeywords),
//         },
//     });
}

test "TestQuickinfoVerbosityEmptyEnum" {
    const content =
        \\
        \\enum Degree {}
        \\
        \\declare const e/*0*/: Degree;
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"0" = .{0, 1}});
}

test "TestOrganizeImports_importKindOrder" {
    const content =
        \\// @module: commonjs
        \\// @Filename: /main.ts
        \\import { foo } from './package';
        \\import type { Foo } from './package';
        \\import './package';
        \\import Default from './package';
        \\import * as ns from './package';
        \\
        \\const x: Foo = foo;
        \\console.log(x, Default, ns);
        \\// @Filename: /package.d.ts
        \\export type Foo = string;
        \\export declare const foo: Foo;
        \\export declare function fn(): void;
        \\export default class Default {}
        \\export as namespace Package;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(
//         undefined,
//         "import './package';\nimport type { Foo } from './package';\nimport * as ns from './package';\nimport Default, { foo } from './package';\n\nconst x: Foo = foo;\nconsole.log(x, Default, ns);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
    // f.VerifyOrganizeImports(
//         undefined,
//         "import './a';\nimport type { TypeA } from './a';\nimport { a } from './a';\nimport './b';\nimport type { TypeB } from './b';\nimport { b } from './b';\n\nconst x: TypeA = a;\nconst y: TypeB = b;\nconsole.log(x, y);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestImportFixFromAtTypesWithRealPackage" {
    const content =
        \\// @Filename: /node_modules/myLib/package.json
        \\{"name":"myLib","version":"1.0.0","main":"index.js"}
        \\// @Filename: /node_modules/myLib/index.js
        \\module.exports = {};
        \\// @Filename: /node_modules/@types/myLib/package.json
        \\{"name":"@types/myLib","version":"1.0.0","types":"index.d.ts"}
        \\// @Filename: /node_modules/@types/myLib/index.d.ts
        \\export function f1(): void;
        \\export function f2(): void;
        \\// @Filename: /package.json
        \\{"dependencies":{"myLib":"*"}}
        \\// @Filename: /other.ts
        \\import { f1 } from "myLib";
        \\f1();
        \\// @Filename: /index.ts
        \\[|f2/*0*/();|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyImportFixModuleSpecifiers(undefined, "0", &.{"myLib"}, null );
    // f.VerifyImportFixModuleSpecifiers(undefined, "0", &.{"myLib"}, null );
}

test "TestGoToImplementationReachingNonExistentExport3" {
    const content =
        \\
        \\// @allowJs: true
        \\// @checkJs: true
        \\
        \\// @Filename: /github.js
        \\export { transformRecordedData };
        \\
        \\// @Filename: /gitGateway.js
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

test "TestQuickinfoVerbosityConstMergedWithNamespace" {
    const content =
        \\
        \\declare function create/*1*/(x: string): number;
        \\declare namespace create/*2*/ {
        \\    var version: string;
        \\    function reset(): void;
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{
//         .@"1" = .{0, 1},
//         .@"2" = .{0, 1},
//     });
}

test "TestCodeFixMissingTypeAnnotationOnExports_jsxWhitespaceText" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @module: preserve
        \\// @Filename: /test.tsx
        \\export const /**/elem = <div>
        \\    <span />
        \\</div>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyCodeFixAvailable(undefined, null);
}

test "TestGoToDefinitionShorthandObjectLiteralWithInterface" {
    const content =
        \\interface Something {
        \\    [|foo|]: string;
        \\}
        \\
        \\function makeSomething([|foo|]: string): Something {
        \\    return { [|f/*1*/oo|] };
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestExhaustiveCaseCompletions11" {
    const content =
        \\
        \\declare const u: "$1" | "2";
        \\switch (u) {
        \\    case/*1*/
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
//                     .Label =            "case \"$1\": ...",
//                     .InsertText =       undefined("case \"\\$1\":$1\ncase \"2\":$2"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .SortText =         undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestAutoImportCompletionsForArbitraryNonIdentifierExports" {
    const content =
        \\
        \\// @module: esnext
        \\// @Filename: /a.ts
        \\const foo = 0;
        \\export { foo as "foo-bar" };
        \\export const fooBar = 1;
        \\
        \\// @Filename: /b.ts
        \\foo/**/
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "", &.{
//         .Items = &.{
//             .Excludes = &.{"foo-bar"},
//             .Includes = &.{"fooBar"},
//         },
//         .ItemDefaults = &.{
//             .CommitCharacters = &util.DefaultCommitCharacters,
//             .EditRange =        util.Ignored,
//         },
//     });
}

test "TestQuickInfoObjectTypeMultiline" {
    const content =
        \\
        \\type X/*1*/ = {
        \\    a: number
        \\    b: string
        \\    c: C
        \\}
        \\type C = {}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{0, 1}});
}

test "TestGoToSourceRequireCall" {
    const content =
        \\// @moduleResolution: bundler
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/package.json
        \\{ "name": "pkg", "main": "./index.js", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.d.ts
        \\export declare function helper(): string;
        \\// @Filename: /home/src/workspaces/project/node_modules/pkg/index.js
        \\exports./*target*/helper = function() { return "ok"; };
        \\// @Filename: /home/src/workspaces/project/index.js
        \\const { /*importName*/helper } = require("pkg");
        \\helper/*usage*/();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "importName", "usage");
    // f.VerifyBaselineGoToSourceDefinition(undefined, "usage");
}

test "TestCodeFixMissingTypeAnnotationOnExports_arrowParens" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\export const func = x => x.substring("foo");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFixAll(undefined, .{
        .FixID =          "fixMissingTypeAnnotationOnExports",
        .NewFileContent = "export const func = (x: any): any => x.substring(\"foo\");",
    });
}

test "TestInlayHintsTupleTypeCrash" {
    const content =
        \\function iterateTuples(tuples: [string][]): void {
        \\  tuples.forEach((l) => {})
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{
//         .InlayHints = .{
//             .IncludeInlayFunctionParameterTypeHints = core.TSTrue,
//         },
//     });
}

test "TestAutoImportModuleAugmentation" {
    const content =
        \\// @Filename: /a.ts
        \\export interface Foo {
        \\    x: number;
        \\}
        \\
        \\// @Filename: /b.ts
        \\export {};
        \\declare module "./a" {
        \\    export const Foo: any;
        \\}
        \\
        \\// @Filename: /c.ts
        \\Foo/**/
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.BaselineAutoImportsCompletions(undefined, &.{""});
}

test "TestCompletionColonToken" {
    const content =
        \\
        \\// @filename: /a.ts
        \\:/*a*/
        \\
        \\// @filename: /b.ts
        \\function b(class: /*b*/) {}
        \\
        \\// @filename: /c.ts
        \\function c(enum: /*c*/) {}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.Ranges();
    // f.VerifyCompletions(undefined, marker, &.{
//             .IsIncomplete = false,
//             .ItemDefaults = &.{
//                 .CommitCharacters = &DefaultCommitCharacters,
//                 .EditRange =        Ignored,
//             },
//             .Items = &.{
//                 .Includes = CompletionGlobals,
//             },
//         });
}

