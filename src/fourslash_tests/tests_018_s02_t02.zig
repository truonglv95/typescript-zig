const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestSignatureHelpInCallback" {
    const content =
        \\declare function forEach(f: () => void);
        \\forEach(/*1*/() => {
        \\    /*2*/
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "forEach(f: () => void): any"});
    // try f.VerifyNoSignatureHelpForMarkers(undefined, "2");
}

test "TestCompletionsImport_default_addToNamedImports" {
    const content =
        \\// @Filename: /a.ts
        \\export default function foo() {}
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
//         .NewFileContent = undefined("import foo, { x } from \"./a\";\nf;"),
//     });
}

test "TestProcessInvalidSyntax1" {
    const content =
        \\// @allowJs: true
        \\// @Filename: decl.js
        \\var obj = {};
        \\// @Filename: unicode1.js
        \\obj.𝒜 ;
        \\// @Filename: unicode2.js
        \\obj.¬ ;
        \\// @Filename: unicode3.js
        \\obj¬
        \\// @Filename: forof.js
        \\for (obj/**/.prop of arr) {
        \\
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , "");
}

test "TestCompletionsWithOverride2" {
    const content =
        \\interface I {
        \\    baz () {}
        \\}
        \\class A {
        \\    foo () {} 
        \\    bar () {}
        \\}
        \\class B extends A implements I {
        \\    override /*1*/
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
//                 "foo",
//                 "bar",
//             },
//             .Excludes = &.{
//                 "baz",
//             },
//         },
//     });
}

test "TestAutoImportProvider_exportMap2" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "lib": ["es5"],
        \\    "module": "commonjs",
        \\    "moduleResolution": "node10"
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
        \\  "types": "./lib/index.d.ts",
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
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     &.{
//                         .Label = "fooFromIndex",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "dependency",
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

test "TestCompletionListInImportClause03" {
    const content =
        \\declare module "M1" {
        \\    export var abc: number;
        \\    export var def: string;
        \\}
        \\
        \\declare module "M2" {
        \\    import { abc/**/ } from "M1";
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
//                 "abc",
//                 "def",
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestGetOccurrencesLoopBreakContinueNegatives" {
    const content =
        \\var arr = [1, 2, 3, 4];
        \\label1: for (var n in arr) {
        \\    break;
        \\    continue;
        \\    break label1;
        \\    continue label1;
        \\
        \\    label2: for (var i = 0; i < arr[n]; i++) {
        \\        break label1;
        \\        continue label1;
        \\
        \\        break;
        \\        continue;
        \\        break label2;
        \\        continue label2;
        \\
        \\        function foo() {
        \\            label3: while (true) {
        \\                break;
        \\                continue;
        \\                break label3;
        \\                continue label3;
        \\
        \\                // these cross function boundaries
        \\                br/*1*/eak label1;
        \\                cont/*2*/inue label1;
        \\                bre/*3*/ak label2;
        \\                c/*4*/ontinue label2;
        \\
        \\                label4: do {
        \\                    break;
        \\                    continue;
        \\                    break label4;
        \\                    continue label4;
        \\
        \\                    break label3;
        \\                    continue label3;
        \\
        \\                    switch (10) {
        \\                        case 1:
        \\                        case 2:
        \\                            break;
        \\                            break label4;
        \\                        default:
        \\                            continue;
        \\                    }
        \\
        \\                    // these cross function boundaries
        \\                    br/*5*/eak label1;
        \\                    co/*6*/ntinue label1;
        \\                    br/*7*/eak label2;
        \\                    con/*8*/tinue label2;
        \\                    () => { b/*9*/reak; }
        \\                } while (true)
        \\            }
        \\        }
        \\    }
        \\}
        \\
        \\label5: while (true) break label5;
        \\
        \\label7: while (true) co/*10*/ntinue label5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Markers()));
}

test "TestCompletionListInTypeParameterOfTypeAlias1" {
    const content =
        \\type List1</*0*/
        \\type List2</*1*/T> = T[];
        \\type List4<T> = /*2*/T[];
        \\type List3<T1> = /*3*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, &.{"0", "1"}, null);
    // f.VerifyCompletions(undefined, "2", &.{
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
    // f.VerifyCompletions(undefined, "3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "T1",
//             },
//             .Excludes = &.{
//                 "T",
//             },
//         },
//     });
}

test "TestGetOutliningSpansForTemplateLiteral" {
    const content =
        \\declare function tag(...args: any[]): void
        \\const a = [|
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOutliningSpans(undefined);
}

test "TestRenameImportOfReExport" {
    const content =
        \\// @noLib: true
        \\declare module "a" {
        \\    [|export class /*1*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 0 |}C|] {}|]
        \\}
        \\declare module "b" {
        \\    [|export { /*2*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 2 |}C|] } from "a";|]
        \\}
        \\declare module "c" {
        \\    [|import { /*3*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 4 |}C|] } from "b";|]
        \\    export function f(c: [|C|]): void;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1]);
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[3]);
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[5], f.Ranges()[6]);
}

