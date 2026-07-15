const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestGenericArityEnforcementAfterEdit" {
    const content =
        \\interface G<T, U> { }
        \\/**/
        \\var v4: G<G<any>, any>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, " ");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestErrorsAfterResolvingVariableDeclOfMergedVariableAndClassDecl" {
    const content =
        \\namespace M {
        \\    export class C {
        \\        foo() { }
        \\    }
        \\    export namespace C {
        \\        export var /*1*/C = M.C;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    _ = f.GoToMarker(undefined, "1");
    _ = f.Backspace(undefined, 1);
    _ = f.Insert(undefined, " ");
    _ = f.VerifyQuickInfoIs(undefined, "var M.C.C: typeof M.C", "");
    _ = f.VerifyNoErrors(undefined);
}

test "TestFindAllReferencesJsRequireDestructuring1" {
    const content =
        \\// @allowJs: true
        \\// @noEmit: true
        \\// @checkJs: true
        \\// @Filename: /X.js
        \\module.exports = { x: 1 };
        \\// @Filename: /Y.js
        \\const { /*1*/x: { y } } = require("./X");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestCodeFixMissingTypeAnnotationOnExports43_expando_functions_2" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @lib: es2019
        \\// @Filename: /code.ts
        \\const foo = () => {}
        \\foo/*a*/["a"] = "A";
        \\foo["b"] = "C"
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add annotation of type '{ (): void; a: string; b: string; }'",
        .NewFileContent = "const foo: {\n    (): void;\n    a: string;\n    b: string;\n} = () => {}\nfoo[\"a\"] = \"A\";\nfoo[\"b\"] = \"C\"",
        .Index = 1,
    });
}

test "TestImportNameCodeFixNewImportBaseUrl0" {
    const content =
        \\[|f1/*0*/();|]
        \\// @Filename: tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "baseUrl": "./a"
        \\    }
        \\}
        \\// @Filename: a/b.ts
        \\export function f1() { };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from \"b\";\n\nf1();",
    }, null );
}

test "TestCodeFixMissingTypeAnnotationOnExports32_inline_short_hand" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @Filename: /code.ts
        \\const x = 1;
        \\export default {
        \\  x
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add satisfies and an inline type assertion with 'number'",
        .NewFileContent = "const x = 1;\nexport default {\n  x: x as number\n};",
        .Index = 1,
    });
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add satisfies and an inline type assertion with 'typeof x'",
        .NewFileContent = "const x = 1;\nexport default {\n  x: x as typeof x\n};",
        .Index = 2,
    });
}

test "TestJsxAttributeCompletionStyleAuto" {
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
        \\            prop_string_literal_union?: 'input' | 'password' | (string & {})
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
//                     .Label =            "prop_b",
//                     .InsertText =       undefined("prop_b=\"$1\""),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                 },
//                 &.{
//                     .Label =            "prop_c",
//                     .InsertText =       undefined("prop_c={$1}"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                 },
//                 &.{
//                     .Label =            "prop_d",
//                     .InsertText =       undefined("prop_d={$1}"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                 },
//                 &.{
//                     .Label =            "prop_e",
//                     .InsertText =       undefined("prop_e=\"$1\""),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                 },
//                 &.{
//                     .Label = "prop_f",
//                 },
//                 &.{
//                     .Label =            "prop_g",
//                     .InsertText =       undefined("prop_g={$1}"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                 },
//                 &.{
//                     .Label =            "prop_h?",
//                     .InsertText =       undefined("prop_h=\"$1\""),
//                     .FilterText =       undefined("prop_h"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .SortText =         undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =      "prop_i?",
//                     .InsertText = undefined("prop_i"),
//                     .FilterText = undefined("prop_i"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =            "prop_j?",
//                     .InsertText =       undefined("prop_j={$1}"),
//                     .FilterText =       undefined("prop_j"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .SortText =         undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =            "prop_string_literal_union?",
//                     .InsertText =       undefined("prop_string_literal_union=\"$1\""),
//                     .FilterText =       undefined("prop_string_literal_union"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .SortText =         undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
}

test "TestGetOccurrencesAsyncAwait3" {
    const content =
        \\a/**/wait 100;
        \\async function f() {
        \\    await 300;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , "");
}

test "TestFindAllRefsWithLeadingUnderscoreNames9" {
    const content =
        \\(/*1*/function /*2*/___foo() {
        \\    /*3*/___foo();
        \\})
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestCodeFixInferFromPrimitiveUsage" {
    const content =
        \\// @noImplicitAny: true
        \\function wrap( [| s |] ) {
        \\    return s.length + s.indexOf('hi')
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "s: string | string[]", false, 0, 0);
}

