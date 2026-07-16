const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCodeFixClassImplementInterface_quotePreferenceAuto2" {
    const content =
        \\// @filename: a.ts
        \\export interface I {
        \\    a(): void;
        \\    b(x: 'x', y: 'a' | 'b'): 'b';
        \\
        \\    c: 'c';
        \\    d: { e: 'e'; };
        \\}
        \\// @filename: b.ts
        \\import { I } from './a';
        \\class Foo implements I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "b.ts");
    // try f.VerifyCodeFix(undefined, .{
//         .Description = "Implement interface 'I'",
//         .NewFileContent = "import { I } from './a';\nclass Foo implements I {\n    a(): void {\n        throw new Error('Method not implemented.');\n    }\n    b(x: 'x', y: 'a' | 'b'): 'b' {\n        throw new Error('Method not implemented.');\n    }\n    c: 'c';\n    d: { e: 'e'; };\n}",
//         .Index =           0,
//         .UserPreferences = &.{.QuotePreference = lsutil.QuotePreference("auto")},
//     });
}

test "TestRenameStringLiteralTypes1" {
    const content =
        \\interface AnimationOptions {
        \\    deltaX: number;
        \\    deltaY: number;
        \\    easing: "ease-in" | "ease-out" | "[|ease-in-out|]";
        \\}
        \\
        \\function animate(o: AnimationOptions) { }
        \\
        \\animate({ deltaX: 100, deltaY: 100, easing: "[|ease-in-out|]" });
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "ease-in-out");
}

test "TestQuickInfoForConstDeclaration" {
    const content =
        \\const /**/c = 0 ;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "const c: 0", "");
}

test "TestCodeFixRemoveUnnecessaryAwait_notAvailableOnReturn" {
    const content =
        \\// @target: esnext
        \\async function fn(): Promise<number> {
        \\  return 0;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifySuggestionDiagnostics(undefined, null);
}

test "TestOrganizeImportsGroup_MultiNewlines" {
    const content =
        \\import c from "C";
        \\
        \\
        \\import d from "D";
        \\import a from "A";
        \\import b from "B";
        \\
        \\console.log(a, b, c, d)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "import c from \"C\";\n\n\nimport a from \"A\";\nimport b from \"B\";\nimport d from \"D\";\n\nconsole.log(a, b, c, d)",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestQuickInfoLink3" {
    const content =
        \\class Foo<T> {
        \\    /**
        \\     * {@link Foo}
        \\     * {@link Foo<T>}
        \\     * {@link Foo<Array<X>>}
        \\     * {@link Foo<>}
        \\     * {@link Foo>}
        \\     * {@link Foo<}
        \\     */
        \\    bar/**/(){}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    try f.VerifyBaselineHover(undefined);
}

test "TestGoToDefinitionReturn6" {
    const content =
        \\function foo() {
        \\    return /*end*/function () {
        \\        [|/*start*/return|] 10;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "start");
}

test "TestDocumentHighlightInTypeExport" {
    const content =
        \\// @Filename: /1.ts
        \\type [|A|] = 1;
        \\export { [|A|] as [|B|] };
        \\// @Filename: /2.ts
        \\type [|A|] = 1;
        \\let [|A|]: [|A|] = 1;
        \\export { [|A|] as [|B|] };
        \\// @Filename: /3.ts
        \\type [|A|] = 1;
        \\let [|A|]: [|A|] = 1;
        \\export type { [|A|] as [|B|] };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestFormattingJsxTexts2" {
    const content =
        \\//@Filename: file.tsx
        \\const a = (
        \\    <div>
        \\  foo
        \\          </div>
        \\);
        \\
        \\const b = (
        \\    <div>
        \\  {     foo  }
        \\          </div>
        \\);
        \\
        \\const c = (
        \\    <div>
        \\    foo
        \\  {     foobar  }
        \\  bar
        \\          </div>
        \\);
        \\
        \\const d = 
        \\    <div>
        \\  foo
        \\          </div>;
        \\
        \\const e = 
        \\    <div>
        \\  {     foo  }
        \\          </div>
        \\
        \\const f = 
        \\    <div>
        \\    foo
        \\  {     foobar  }
        \\  bar
        \\          </div>
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "const a = (\n    <div>\n        foo\n    </div>\n);\n\nconst b = (\n    <div>\n        {foo}\n    </div>\n);\n\nconst c = (\n    <div>\n        foo\n        {foobar}\n        bar\n    </div>\n);\n\nconst d =\n    <div>\n        foo\n    </div>;\n\nconst e =\n    <div>\n        {foo}\n    </div>\n\nconst f =\n    <div>\n        foo\n        {foobar}\n        bar\n    </div>");
}

test "TestImportNameCodeFixNewImportPaths0" {
    const content =
        \\[|foo/*0*/();|]
        \\// @Filename: folder_a/f2.ts
        \\export function foo() {};
        \\// @Filename: tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "baseUrl": ".",
        \\        "paths": {
        \\            "a": [ "folder_a/f2" ]
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { foo } from \"a\";\n\nfoo();",
    }, null );
}

