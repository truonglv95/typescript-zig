const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestQuickInfoOnExpandoLikePropertyWithSetterDeclarationJs2" {
    const content =
        \\// @strict: true
        \\// @checkJs: true
        \\// @filename: index.js
        \\const obj = {};
        \\let val = 10;
        \\Object.defineProperty(obj, "a", {
        \\  configurable: true,
        \\  enumerable: true,
        \\  set(v) {
        \\    val = v;
        \\  },
        \\});
        \\
        \\obj.a/**/ = 100;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "(property) obj.a: any", "");
}

test "TestIssue57429" {
    const content =
        \\// @strict: true
        \\function Builder<I>(def: I) {
        \\  return def;
        \\}
        \\
        \\interface IThing {
        \\  doThing: (args: { value: object }) => string
        \\  doAnotherThing: () => void
        \\}
        \\
        \\Builder<IThing>({
        \\  doThing(args: { value: object }) {
        \\    const { v/*1*/alue } = this.[|args|]
        \\    return 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "const value: any", "");
    // f.VerifyNonSuggestionDiagnostics(undefined, []*.{
//         .{
//             .Message = .{.String = undefined("Property 'args' does not exist on type 'IThing'.")},
//             .Code =    &.{.Integer = undefined(int32(2339))},
//         },
//     });
}

test "TestFindAllRefsOnPrivateParameterProperty1" {
    const content =
        \\class ABCD {
        \\    constructor(private x: number, public y: number, /*1*/private /*2*/z: number) {
        \\    }
        \\
        \\    func() {
        \\        return this./*3*/z;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestRenameLabel5" {
    const content =
        \\loop1: for (let i = 0; i <= 10; i++) {
        \\    loop2: for (let j = 0; j <= 10; j++) {
        \\        if (i === 5) continue /**/loop1;
        \\        if (j === 5) break loop2;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , "");
}

test "TestCompletionsImport_uriStyleNodeCoreModules1" {
    const content =
        \\// @lib: es5
        \\// @module: commonjs
        \\// @Filename: /node_modules/@types/node/index.d.ts
        \\declare module "fs" { function writeFile(): void }
        \\declare module "fs/promises" { function writeFile(): Promise<void> }
        \\declare module "node:fs" { export * from "fs"; }
        \\declare module "node:fs/promises" { export * from "fs/promises"; }
        \\// @Filename: /index.ts
        \\write/**/
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
//                         .Label = "writeFile",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "fs",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                     &.{
//                         .Label = "writeFile",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "node:fs",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                     &.{
//                         .Label = "writeFile",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "fs/promises",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                     &.{
//                         .Label = "writeFile",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "node:fs/promises",
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

test "TestQuickInfoJsdocEnum" {
    const content =
        \\// @allowJs: true
        \\// @noLib: true
        \\// @Filename: /a.js
        \\/**
        \\ * Doc
        \\ * @enum {number}
        \\ */
        \\const E = {
        \\    A: 0,
        \\}
        \\
        \\/** @type {/*type*/E} */
        \\const x = /*value*/E.A;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyQuickInfoAt(undefined, "type", "type E = number", "Doc");
    // f.VerifyQuickInfoAt(undefined, "value", "const E: {\n    A: number;\n}", "Doc");
}

test "TestAutoImportFileExcludePatterns11" {
    const content =
        \\// @Filename: /src/vs/test.ts
        \\import { Parts } from './parts';
        \\export class /**/Extended implements Parts {
        \\}
        \\// @Filename: /src/vs/parts.ts
        \\import { Event } from '../thing';
        \\export interface Parts {
        \\    readonly options: Event;
        \\}
        \\// @Filename: /src/event/event.ts
        \\export interface Event {
        \\    (): string;
        \\}
        \\// @Filename: /src/thing.ts
        \\import { Event } from './event/event';
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

test "TestCompletionListAtEOF" {
    const content =
        \\var a;
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
//                 "a",
//             },
//         },
//     });
    _ = f.InsertLine(undefined, "");
    // f.VerifyCompletions(undefined, null, &.{
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
    _ = f.InsertLine(undefined, "");
    // f.VerifyCompletions(undefined, null, &.{
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

test "TestCompletionListAtBeginningOfFile01" {
    const content =
        \\/*1*/
        \\var x = 0, y = 1, z = 2;
        \\enum E {
        \\    A, B, C
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
//                 "E",
//             },
//         },
//     });
}

test "TestFormattingOnCommaOperator" {
    const content =
        \\var v1 = ((1, 2, 3), 4, 5, (6, 7));/*1*/
        \\function f1() {
        \\    var a = 1;
        \\    return a, v1, a;/*2*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "var v1 = ((1, 2, 3), 4, 5, (6, 7));");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "    return a, v1, a;");
}

