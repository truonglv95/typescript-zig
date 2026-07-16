const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionListInClosedObjectTypeLiteralInSignature01" {
    const content =
        \\interface I<TString, TNumber> {
        \\    [s: string]: TString;
        \\    [s: number]: TNumber;
        \\}
        \\
        \\declare function foo<TString, TNumber>(obj: I<TString, TNumber>): { str: T/*1*/ }
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
//                 "I",
//                 "TString",
//                 "TNumber",
//             },
//             .Excludes = &.{
//                 "foo",
//                 "obj",
//             },
//         },
//     });
}

test "TestUnusedFunctionInNamespace3" {
    const content =
        \\// @noUnusedLocals: true
        \\// @noUnusedParameters:true
        \\ [| namespace Validation {
        \\    function function1() {
        \\    }
        \\} |]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "namespace Validation {\n}", false, 0, 0);
}

test "TestCodeFixClassImplementInterfaceWithAmbientSignatures2" {
    const content =
        \\declare class A {
        \\    method(): void;
        \\}
        \\class B implements A {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'A'",
        .NewFileContent = "declare class A {\n    method(): void;\n}\nclass B implements A {\n    method(): void {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestRenameFunctionParameter1" {
    const content =
        \\function Foo() {
        \\    /**
        \\     * @param {number} p
        \\     */
        \\    this.foo = function foo(p/**/) {
        \\        return p;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , "");
}

test "TestCompletionListNewIdentifierVariableDeclaration" {
    const content =
        \\var y : (s:string, list/*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "2", null);
}

test "TestOrganizeImports3" {
    const content =
        \\import {
        \\    Bar   
        \\    , Foo   
        \\  } from "foo"
        \\
        \\console.log(Foo, Bar);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "import {\n    Bar,\n    Foo\n} from \"foo\";\n\nconsole.log(Foo, Bar);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestFindAllRefsPropertyContextuallyTypedByTypeParam01" {
    const content =
        \\interface IFoo {
        \\    /*1*/a: string;
        \\}
        \\class C<T extends IFoo> {
        \\    method() {
        \\        var x: T = {
        \\            a: ""
        \\        };
        \\        x.a;
        \\    }
        \\}
        \\
        \\
        \\var x: IFoo = {
        \\    a: "ss"
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestCompletionEntryForShorthandPropertyAssignment" {
    const content =
        \\var person: {name:string; id:number} = {n/**/
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
//                     .Label = "name",
//                     .Kind =  undefined(lsproto.CompletionItemKindField),
//                 },
//             },
//         },
//     });
}

test "TestGetOccurrencesOfDecorators" {
    const content =
        \\// @Filename: b.ts
        \\@/*1*/decorator
        \\class C {
        \\    @decorator
        \\    method() {}
        \\}
        \\function decorator(target) {
        \\    return target;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , "1");
}

test "TestJsdocLink6" {
    const content =
        \\// @filename: /a.ts
        \\export default function A() { }
        \\export function B() { };
        \\// @Filename: /b.ts
        \\import A, { B } from "./a";
        \\/**
        \\ * {@link A}
        \\ * {@link B}
        \\ */
        \\export default function /**/f() { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

