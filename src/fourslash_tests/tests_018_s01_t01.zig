const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestRenameStringLiteralTypes4" {
    const content =
        \\interface I {
        \\    "Prop 1": string;
        \\}
        \\
        \\declare const fn: <K extends keyof I>(p: K) => void
        \\
        \\fn("Prop 1"/**/)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , "");
}

test "TestDocCommentTemplateInterfacesEnumsAndTypeAliases" {
    const content =
        \\/*interfaceFoo*/
        \\interface Foo {
        \\    /*propertybar*/
        \\    bar: any;
        \\
        \\    /*methodbaz*/
        \\    baz(message: any): void;
        \\
        \\    /*methodUnit*/
        \\    unit(): void;
        \\}
        \\
        \\/*enumStatus*/
        \\const enum Status {
        \\    /*memberOpen*/
        \\    Open,
        \\
        \\    /*memberClosed*/
        \\    Closed
        \\}
        \\
        \\/*aliasBar*/
        \\type Bar = Foo & any;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyJSDocCompletion(undefined, "interfaceFoo", 3, "/** */", null);
    // try f.VerifyJSDocCompletion(undefined, "propertybar", 3, "/** */", null);
    // try f.VerifyJSDocCompletion(undefined, "methodbaz", 11, "/**\n     * \n     * @param message\n     */", null);
    // try f.VerifyJSDocCompletion(undefined, "methodUnit", 3, "/** */", null);
    // try f.VerifyJSDocCompletion(undefined, "enumStatus", 3, "/** */", null);
    // try f.VerifyJSDocCompletion(undefined, "memberOpen", 3, "/** */", null);
    // try f.VerifyJSDocCompletion(undefined, "memberClosed", 3, "/** */", null);
}

test "TestFindAllRefsForDefaultExport_reExport" {
    const content =
        \\// @Filename: /export.ts
        \\const /*0*/foo = 1;
        \\export default /*1*/foo;
        \\// @Filename: /re-export.ts
        \\export { /*2*/default } from "./export";
        \\// @Filename: /re-export-dep.ts
        \\import /*3*/fooDefault from "./re-export";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2", "3");
}

test "TestCodeFixInferFromUsageMember" {
    const content =
        \\// @noImplicitAny: true
        \\class C {
        \\    [|p;|]
        \\    method() {
        \\        this.p.push(10);
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "p: number[];", false, 0, 0);
}

test "TestCompletionsImportPathsConflict" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "module": "esnext",
        \\        "paths": {
        \\          "@reduxjs/toolkit": ["src/index.ts"],
        \\          "@internal/*": ["src/*"]
        \\        }
        \\    }
        \\}
        \\// @Filename: /src/index.ts
        \\export { configureStore } from "./configureStore";
        \\// @Filename: /src/configureStore.ts
        \\export function configureStore() {}
        \\// @Filename: /src/tests/createAsyncThunk.typetest.ts
        \\import {} from "@reduxjs/toolkit";
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
//             .Includes = &.{
//                 &.{
//                     .Label = "configureStore",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "@reduxjs/toolkit",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =   "configureStore",
//         .Source = "@reduxjs/toolkit",
//         .AutoImportFix = &.{
//             .ModuleSpecifier = "@reduxjs/toolkit",
//         },
//         .Description = "Update import from \"@reduxjs/toolkit\"",
//         .NewFileContent = undefined("import { configureStore } from \"@reduxjs/toolkit\";\n"),
//     });
}

test "TestJsDocPropertyDescription3" {
    const content =
        \\interface LiteralExample {
        \\    /** Something generic */
        \\    [key: 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "literal", "any", "");
}

test "TestGetOccurrencesThis" {
    const content =
        \\[|this|];
        \\[|th/**/is|];
        \\
        \\function f() {
        \\    this;
        \\    this;
        \\    () => this;
        \\    () => {
        \\        if (this) {
        \\            this;
        \\        }
        \\        else {
        \\            this.this;
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
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestGoToImplementation_inDifferentFiles" {
    const content =
        \\// @lib: es5
        \\// @Filename: /home/src/workspaces/project/bar.ts
        \\import {Foo} from './foo'
        \\
        \\class [|A|] implements Foo {
        \\    func() {}
        \\}
        \\
        \\class [|B|] implements Foo {
        \\    func() {}
        \\}
        \\// @Filename: /home/src/workspaces/project/foo.ts
        \\export interface /**/Foo {
        \\    func();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineGoToImplementation(undefined, "");
}

test "TestReferencesForIndexProperty2" {
    const content =
        \\var a;
        \\a["/*1*/blah"];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestJsdocDeprecated_suggestion22" {
    const content =
        \\// @filename: /a.ts
        \\const foo: {
        \\    /**
        \\     * @deprecated
        \\     */
        \\    (a: string, b: string): string;
        \\    (a: string, b: number): string;
        \\} = (a: string, b: string | number) => a + b;
        \\
        \\[|foo|](1, 1);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifySuggestionDiagnostics(undefined, null);
}

