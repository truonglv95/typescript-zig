const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestImportNameCodeFixNewImportTypeRoots0" {
    const content =
        \\// @Filename: a/f1.ts
        \\[|foo/*0*/();|]
        \\// @Filename: types/random/index.ts
        \\export function foo() {};
        \\// @Filename: tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "typeRoots": [
        \\            "./types"
        \\        ]
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { foo } from \"../types/random\";\n\nfoo();",
    }, null );
}

test "TestFindAllRefsObjectBindingElementPropertyName07" {
    const content =
        \\let p, b;
        \\
        \\p, [{ /*1*/a: p, b }] = [{ a: 10, b: true }];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestFormatDebuggerStatement" {
    const content =
        \\if(false){debugger;}
        \\  if    (   false   )   {    debugger  ;   }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToBOF(undefined);
    _ = f.VerifyCurrentLineContent(undefined, "if (false) { debugger; }");
    _ = f.GoToEOF(undefined);
    _ = f.VerifyCurrentLineContent(undefined, "if (false) { debugger; }");
}

test "TestGoToTypeDefinition_typeReference" {
    const content =
        \\type User = { name: string };
        \\type Box<T> = { value: T };
        \\declare const boxedUser: Box<User>
        \\/*reference*/boxedUser
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToTypeDefinition(undefined, "reference");
}

test "TestGoToDefinitionConstructorOfClassWhenClassIsPrecededByNamespace01" {
    const content =
        \\namespace Foo {
        \\    export var x;
        \\}
        \\
        \\class Foo {
        \\    /*definition*/constructor() {
        \\    }
        \\}
        \\
        \\var x = new [|/*usage*/Foo|]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "usage");
}

test "TestIncrementalParsingDynamicImport2" {
    const content =
        \\// @lib: es2015
        \\// @Filename: ./foo.ts
        \\export function bar() { return 1; }
        \\// @Filename: ./0.ts
        \\/*1*/ import { bar } from "./foo"
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 0);
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "var x = ");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestCompletionsStringsWithTriggerCharacter" {
    const content =
        \\type A = "a/b" | "b/a";
        \\const a: A = "[|a/*1*/|]";
        \\
        \\type B = "a@b" | "b@a";
        \\const a: B = "[|a@/*2*/|]";
        \\
        \\type C = "a.b" | "b.a";
        \\const c: C = "[|a./*3*/|]";
        \\
        \\type D = "a'b" | "b'a";
        \\const d: D = "[|a'/*4*/|]";
        \\
        \\type E = "a
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
//                     .Label = "a/b",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "a/b",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "b/a",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "b/a",
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
//             .Exact = &.{
//                 &.{
//                     .Label = "a@b",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "a@b",
//                             .Range =   f.Ranges()[1].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "b@a",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "b@a",
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
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "a.b",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "a.b",
//                             .Range =   f.Ranges()[2].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "b.a",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "b.a",
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
//             .Exact = &.{
//                 &.{
//                     .Label = "a'b",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "a'b",
//                             .Range =   f.Ranges()[3].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "b'a",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "b'a",
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
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "a`b",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "a`b",
//                             .Range =   f.Ranges()[4].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "b`a",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "b`a",
//                             .Range =   f.Ranges()[4].LSRange,
//                         },
//                     },
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
//             .Exact = &.{
//                 &.{
//                     .Label = "a\"b",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "a\"b",
//                             .Range =   f.Ranges()[5].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "b\"a",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "b\"a",
//                             .Range =   f.Ranges()[5].LSRange,
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
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "a<b",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "a<b",
//                             .Range =   f.Ranges()[6].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "b<a",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "b<a",
//                             .Range =   f.Ranges()[6].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestOrganizeImportsPathsUnicode2" {
    const content =
        \\import * as a2 from "./a2";
        \\import * as a100 from "./a100";
        \\import * as a1 from "./a1";
        \\
        \\console.log(a1, a2, a100);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(undefined,
//         "import * as a1 from \"./a1\";\nimport * as a100 from \"./a100\";\nimport * as a2 from \"./a2\";\n\nconsole.log(a1, a2, a100);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase =       core.TSFalse,
//             .OrganizeImportsCollation =        lsutil.OrganizeImportsCollationUnicode,
//             .OrganizeImportsNumericCollation = core.TSFalse,
//         },
//     );
    // f.VerifyOrganizeImports(undefined,
//         "import * as a1 from \"./a1\";\nimport * as a2 from \"./a2\";\nimport * as a100 from \"./a100\";\n\nconsole.log(a1, a2, a100);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase =       core.TSFalse,
//             .OrganizeImportsCollation =        lsutil.OrganizeImportsCollationUnicode,
//             .OrganizeImportsNumericCollation = core.TSTrue,
//         },
//     );
}

test "TestInlayHintsInteractiveOverloadCall" {
    const content =
        \\interface Call {
        \\    (a: number): void
        \\    (b: number, c: number): void
        \\    new (d: number): Call
        \\}
        \\declare const call: Call;
        \\call(1);
        \\call(1, 2);
        \\new call(1);
        \\declare function foo(w: number): void
        \\declare function foo(a: number, b: number): void;
        \\declare function foo(a: number | undefined, b: number | undefined): void;
        \\foo(1)
        \\foo(1, 2)
        \\class Class {
        \\    constructor(a: number);
        \\    constructor(b: number, c: number);
        \\    constructor(b: number, c?: number) { }
        \\}
        \\new Class(1)
        \\new Class(1, 2)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayParameterNameHints = lsutil.IncludeInlayParameterNameHintsLiterals}});
}

test "TestCompletionPropertyShorthandForObjectLiteral3" {
    const content =
        \\// @lib: es5
        \\const foo = 1;
        \\const bar = 2;
        \\const obj = {
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

